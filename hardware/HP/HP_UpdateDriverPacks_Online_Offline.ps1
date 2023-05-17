<#  Version 2020.04.08 - Creator @gwblok - GARYTOWN.COM
    Used to download BIOS Updates from HP
    Grabs BIOS Files based on your CM Package Structure... based on this: https://github.com/gwblok/garytown/blob/master/hardware/CreateCMPackages_BIOS_Drivers.ps1

    REQUIREMENTS:  HP Client Management Script Library
    Download / Installer: https://ftp.hp.com/pub/caps-softpaq/cmit/hp-cmsl.html  
    Docs: https://developers.hp.com/hp-client-management/doc/client-management-script-library-0
    
    Usage... Stage Prod or Pre-Prod.
    If you don't do Pre-Prod... just delete that Param section out and set $Stage = Prod or remove all Stage references complete, do whatever you want I guess.

    If you have a Proxy, you'll have to modify for that.


    Updates 
    2022.01.28
     - Changed to Support Download and Create WIM files from Driver Packs.
     - Added loop to find the latest driver package available


    2022.02.27 - Major Changes!
     - Levearing new script from HP (New-HPDriverPack.ps1) https://github.com/gwblok/garytown/blob/master/hardware/HP/New-HPDriverPack.ps1
      - This builds a most updated driver pack of inf files that can be DISM'd into the Offline OS
      - AKA - no longer uses the driver pack softpaqs provided by HP, instead it builds one on the fly with updated drivers.
     - Created HPIA Repo in the Online Folder
      - Leveraging HPCMSL commands to create and sync a repository.. currently just set for Drivers and Firmware.


    Future enhancements planed DBA:
     - Intergrate with HPIA to create "Online" section of drivers to update drivers once in Full OS
      - Partly done, the script now creates the Online section in the WIM file, now I just need to build a step in the TS to apply them.
      - I'll update this script with a link to how that can be done.

#>
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage = "Prod"

 	    )




#Script Vars
$SiteCode = "MEM"
$ScatchLocation = "E:\DedupExclude"
$HPStaging = "E:\HPStaging"
$ManifestFolderPath = "$HPStaging\Manifests"
$HPRepoStaging = "$HPStaging\HPRepoStaging"
$DismScratchPath = "$ScatchLocation\DISM"
$Date = (Get-Date -Format "yyyyMMdd")
$scriptName = "HP Driver Pack Creation"

#Reset Vars
$Driver = ""
$Model = ""

#HPCMSL Vars
$OS = 'win10'

#Load CM PowerShell
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

#To Select
$HPModelsSelectTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.Mifname -eq $Stage} |Select-Object -Property "Name","MIFFilename","PackageID", "Version" | Sort-Object $_.MIFFilename | Out-GridView -Title "Select the Models you want to Update" -PassThru
$HPModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.PackageID -in $HPModelsSelectTable.PackageID}


#$HPModelsTable = Get-CMPackage -Fast -Id "PS2004AA"

Set-Location -Path "$env:TEMP"
Write-Output "Starting Script: $scriptName"
if (!(test-path -path $ManifestFolderPath)){New-Item -Path $ManifestFolderPath -ItemType Directory | Out-Null}




foreach ($Model in $HPModelsTable) #{Write-Host "$($Model.Name)"}
    {
    #Reset
    $RequiresUpdate = $false
    
    #Get required Info from CM Package to pass to HPCMSL
    Write-Host "Starting Process for $($Model.MIFFilename)" -ForegroundColor Green
    $PlatformCode = $Model.Language
    $PlatformName =  (Get-HPDeviceDetails -platform $PlatformCode).name
    $MaxBuild = ((Get-HPDeviceDetails -platform $PlatformCode -oslist | Where-Object {$_.OperatingSystem -eq "Microsoft Windows 10"}).OperatingSystemRelease | measure -Maximum).Maximum
    if ($PlatformName.Count -gt 1)
        {
        $NameMatch = ($model.MIFFilename).Split(" ") | Select-Object -First 3
        $PlatformName = $PlatformName | Where-Object {$_ -match $NameMatch}
        } 

    #Create the Driver Package (INF Files / Offline) - uses New-HPDriverPack Script
    Write-Host "Starting script New-HPDriverPack -platform $PlatformName -OS $OS -OSVer $MaxBuild -DownloadPath $HPStaging -LogOnly " -ForegroundColor Green
    & '\\src\SRC$\Scripts\New-HPDriverPack.ps1' -platform $PlatformName -OS $OS -OSVer $MaxBuild -DownloadPath "$HPStaging" -LogOnly  # -ManifestPath "$($ManifestFolderPath)\$($PlatformName)-$($Date).json"

    #Create HPIA Repo & Sync for this Platform (EXE / Online)
    Write-Host "Starting HPCMSL to create HPIA Repo for $platformName" -ForegroundColor Green
    $HPIARepoModelPath = "$HPRepoStaging\$PlatformCode"
    New-Item -Path "$HPIARepoModelPath\$date" -ItemType Directory | Out-Null
    Set-Location -Path "$HPIARepoModelPath\$date"

    Initialize-Repository
    Set-RepositoryConfiguration -Setting OfflineCacheMode -CacheValue Enable
    Add-RepositoryFilter -Platform $PlatformCode -Os $OS -OsVer $MaxBuild -Category Driver, Firmware
    Invoke-RepositorySync



    #Get Current Driver CMPackage Version from CM & Setup Download Location
    Set-Location -Path "$($SiteCode):"
    $PackageInfo = $Model
    $PackageInfoVersion = $null
    $PackageInfoVersion = $PackageInfo.Version
    $PackageSource = $PackageInfo.PkgSourcePath
    Set-Location -Path "$env:TEMP"
        
    
    #Determine Driver Pack (Offline) - If already Current, or if needs updating.
    #Get Folders Info
    $PreviousDP = Get-ChildItem -Path "$HPStaging\DriverPack" | Where-Object {$_.name -match $PlatformCode -and $_.Attributes -eq "Directory" -and $_.Name -notmatch $Date} | Select-Object -Last 1
    $CurrentDP = Get-ChildItem -Path "$HPStaging\DriverPack" | Where-Object {$_.name -match $PlatformCode -and $_.Attributes -eq "Directory" -and $_.Name -match $Date} | Select-Object -Last 1
    
    #Get SoftPaq Info
    $PreviousDPInfo = Get-ChildItem -Path $PreviousDP.FullName | Where-Object {$_.Attributes -eq "Directory"}
    $CurrentDPInfo = Get-ChildItem -Path $CurrentDP.FullName | Where-Object {$_.Attributes -eq "Directory"}

    #Compare Softpaqs from CUrrent & Previous Run
    foreach ($name in $CurrentDPInfo.name){
        if ($name -in $PreviousDPInfo.name){
            #Write-Output "Update was in previous Custom Driver Pack: $name"
            }
        else
            {
            Write-Host "CHANGE! - New Driver: $name" -ForegroundColor Green
            $RequiresUpdate = $true
            }
        }
    

    #Determine HPIA Rep (Online) - If already Current, or if needs updating.
    $PreviousHPIA = Get-ChildItem -Path $HPIARepoModelPath | Where-Object {$_.Attributes -eq "Directory" -and $_.Name -notmatch $Date} | Select-Object -Last 1
    $CurrentHPIA = Get-ChildItem -Path $HPIARepoModelPath | Where-Object {$_.Attributes -eq "Directory" -and $_.Name -match $Date} | Select-Object -Last 1

    #Get SoftPaq Info
    $PreviousHPIAInfo = Get-ChildItem -Path $PreviousHPIA.FullName -Filter "*.exe"
    $CurrentHPIAInfo = Get-ChildItem -Path $CurrentHPIA.FullName -Filter "*.exe"


    foreach ($name in $CurrentHPIAInfo.name){
        if ($name -in $PreviousHPIAInfo.name){
            #Write-Output "Update was in previous Custom Driver Pack: $name"
            
            }
        else
            {
            Write-Host "CHANGE! - New Driver: $name" -ForegroundColor Green
            $RequiresUpdate = $true
            }
        }


    if ($RequiresUpdate -ne $true)#No Updates Available
        {
        #Cleanup the download since it was the same as the last time.
        Write-Host "No changes needed, cleaning up temp file downloads" -ForegroundColor Yellow
        remove-item -Path "$HPStaging\DriverPack\*.zip" -Force
        Remove-Item -Path $CurrentDP.FullName -Recurse -Force
        Remove-Item -Path $CurrentHPIA.FullName -Recurse -Force
        Write-Host "No changes to CM Package for $($PackageInfo.Name)" -ForegroundColor Yellow
        }

    else #Updates Needed to Package
        {
        #Temporary Place to download the softpaq EXE
        $CapturePath = "$HPStaging\HPCustomDriverPack"
        if (test-path "$CapturePath"){Remove-Item -Path $CapturePath -Force -Recurse}
        New-Item -Path $CapturePath -ItemType Directory | Out-Null
        New-Item -Path "$CapturePath\Offline" -ItemType Directory | Out-Null
        New-Item -Path "$CapturePath\Online" -ItemType Directory | Out-Null
        
        #Copy Manifest
        $ManifestFile = Get-ChildItem -Path "$HPStaging\DriverPack" -Filter *.json | Where-Object {$_.name -match $PlatformCode -and  $_.Name -match $Date}
        Copy-Item -Path $ManifestFile -Destination $CapturePath

        #Copy Offline Driver Pack Files    
        Copy-Item -Path $CurrentDP.FullName -Destination "$CapturePath\Offline" -Recurse
        
        #Copy Offline Driver Pack Files
        Copy-Item "$($CurrentHPIA.FullName)\*" -Destination "$CapturePath\Online" -Recurse

        #Cleanup Package Source Folder Contents & Prepare for new WIM File
        if (Test-Path $($Model.PkgSourcePath)) {Remove-Item $($Model.PkgSourcePath) -Force -Recurse -ErrorAction SilentlyContinue}
        $Null = New-Item -Path $($Model.PkgSourcePath) -ItemType Directory -Force 

        # Cleanup Previous Runs (Deletes the files)
        $TargetVersion = $date
        if (Test-Path $dismscratchpath) {Remove-Item $DismScratchPath -Force -Recurse -ErrorAction SilentlyContinue}
        $DismScratch = New-Item -Path $DismScratchPath -ItemType Directory -Force
        Write-Host "Creating WIM file: $($Model.PkgSourcePath)\Drivers.wim" -ForegroundColor Green
        New-WindowsImage -ImagePath "$($Model.PkgSourcePath)\Drivers.wim" -CapturePath "$CapturePath" -Name "$($Model.MIFFilename) - $($Model.Language)"  -LogPath "$env:TEMP\dism-$($Model.MIFFilename).log" -ScratchDirectory $dismscratchpath
        $ReadmeContents = "Model: $($Model.Name) | Pack Version: $TargetVersion | CM PackageID: $($Model.PackageID)"
        $ReadmeContents | Out-File -FilePath "$($Model.PkgSourcePath)\Version-$($Date).txt"
        Set-Location -Path "$($SiteCode):"
        Update-CMDistributionPoint -PackageId $Model.PackageID
        Set-Location -Path "$env:TEMP"
        [int]$DriverWIMSize = "{0:N2}" -f ((Get-ChildItem $($Model.PkgSourcePath) -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB)
        [int]$DriverExtractSize = "{0:N2}" -f ((Get-ChildItem $CapturePath -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB)

        Write-Host " Finished Build Driver WIM Process, WIM size: $DriverWIMSize vs Expaneded: $DriverExtractSize" -ForegroundColor Green
        Write-Host " WIM Savings: $($DriverExtractSize - $DriverWIMSize) MB | $(100 - $([MATH]::Round($($DriverWIMSize / $DriverExtractSize)*100))) %" -ForegroundColor Green

        Write-Host "  Confirming Package Info in ConfigMgr $($PackageInfo.Name) ID: $($Model.PackageID)" -ForegroundColor yellow
        Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
        Set-Location -Path "$($SiteCode):"         
        Set-CMPackage -Id $Model.PackageID -Version $date
        Set-CMPackage -Id $Model.PackageID -MIFVersion ""
        Set-CMPackage -Id $Model.PackageID -Description "Updated Offline & Online Drivers on $Date"
        $PackageInfo = Get-CMPackage -Id $Model.PackageID -Fast
        Update-CMDistributionPoint -PackageId $Model.PackageID
        Set-Location -Path $env:TEMP
        Write-Host "Updated Package $($PackageInfo.Name), ID $($Model.PackageID)" -ForegroundColor Gray
        }
   


    
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
#>
    }  


Write-Output "Finished Script: $scriptName"
