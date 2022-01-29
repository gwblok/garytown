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

    Future enhancements planed DBA:
     - Intergrate with HPIA to create "Online" section of drivers to update drivers once in Full OS

#>
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage = "Prod"

 	    )




#Script Vars
#$OS = "Win10"
#$Category = "bios"
$SiteCode = "MEM"
$ScatchLocation = "E:\DedupExclude"
$DismScratchPath = "$ScatchLocation\DISM"

#Reset Vars
$Driver = ""
$Model = ""



#Load CM PowerShell
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

#To Select
$HPModelsSelectTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.Mifname -eq $Stage} |Select-Object -Property "Name","MIFFilename","PackageID", "Version" | Sort-Object $_.MIFFilename | Out-GridView -Title "Select the Models you want to Update" -PassThru
$HPModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.PackageID -in $HPModelsSelectTable.PackageID}


#$HPModelsTable = Get-CMPackage -Fast -Id "PS2004AA"

Set-Location -Path "C:"
Write-Output "Starting Script: $scriptName"




foreach ($Model in $HPModelsTable) #{Write-Host "$($Model.Name)"}
    {
    Write-Host "Starting Process for $($Model.MIFFilename)" -ForegroundColor Green
    $DriverInfo = $null
    $Prodcode = $Model.Language
    $Name = $Model.MIFFilename
    $MaxBuild = ((Get-HPDeviceDetails -platform $Prodcode -oslist | Where-Object {$_.OperatingSystem -eq "Microsoft Windows 10"}).OperatingSystemRelease | measure -Maximum).Maximum
    $SupportedOSBuilds = (Get-HPDeviceDetails -platform $Prodcode -OSList).OperatingSystemRelease | Sort-Object -Descending
    $DriverInfo = Get-SoftpaqList -Platform $Prodcode -Category Driverpack -OsVer $MaxBuild -Os Win10
    
    if (!($DriverInfo))
        {
        $loop_index = 0
        do
            {
            $loop_index++;
            $DriverInfo = Get-SoftpaqList -Platform $Prodcode -Category Driverpack -OsVer $($SupportedOSBuilds[$loop_index]) -Os Win10
            }
        while ($DriverInfo -eq $null)
        write-host "Latest Driver Package for Windows Build:$($SupportedOSBuilds[$loop_index]) but max supported build: $MaxBuild" -ForegroundColor Yellow
        }
    else
        {
        write-host " Latest Supported Build & Driver Package for Windows Build: $MaxBuild" -ForegroundColor Gray
        }
    $DriverInfo = $DriverInfo | Where-Object {$_.Name -notmatch "Windows PE"}
    if ($DriverInfo.Count -gt 1)
        {
        $Description = "Had More than 1 Driver Pack for this Product ID, made best Guess"
        $DriverInfo = $DriverInfo[0]
        }
    elseif (!($DriverInfo)){$Description = "NO SOFTPAQ DATA available for this ProductCode" }
    else{$Description = $DriverInfo.ReleaseNotes}
     

       #Get Current Driver CMPackage Version from CM & Setup Download Location

        Set-Location -Path "$($SiteCode):"
        $PackageInfo = $Model
        $PackageInfoVersion = $null
        $PackageInfoVersion = $PackageInfo.Version
        $PackageSource = $PackageInfo.PkgSourcePath
        Set-Location -Path "C:"
        


    if ($PackageInfoVersion -eq $DriverInfo.Id)
        {Write-host "  $Name already current with version $($PackageInfoVersion)" -ForegroundColor Green
        $AlreadyCurrent = $true
        }
    else #Download & Extract
        {
        #Temporary Place to download the softpaq EXE
        $TempCabPath = "$env:TEMP\HPCab"
        if (test-path "$TempCabPath"){Remove-Item -Path $TempCabPath -Force -Recurse}
        New-Item -Path $TempCabPath -ItemType Directory | Out-Null
        $SaveAs = "$($TempCabPath)\$($DriverInfo.Id).exe"
        $ExpandPath = "$($TempCabPath)\Expanded"
        if (!($PackageInfoVersion)){write-host "  $Name package has no previous downloads, downloading: $($DriverInfo.Id)" -ForegroundColor Yellow}
        else{Write-Host "  $Name package is version $($PackageInfoVersion), new version available $($DriverInfo.Id)" -ForegroundColor Yellow}
        Get-Softpaq -Number $($DriverInfo.Id) -SaveAs $saveAs -Extract -DestinationPath $ExpandPath
        $DriverRoot = (Get-ChildItem -Path $ExpandPath -Recurse | Where-Object {$_.name -match "wt64_"}).FullName
        Get-Item -Path $DriverRoot | Rename-Item -NewName "offline"
        $CapturePath = (Split-Path $DriverRoot)
        $null = new-item -path $CapturePath -Name "online" -ItemType Directory -Force

        #copy-item -Path $ExpandPath -Destination $PackageSource -Force -Recurse
        if (Test-Path $($Model.PkgSourcePath)) {Remove-Item $($Model.PkgSourcePath) -Force -Recurse -ErrorAction SilentlyContinue}
        $Null = New-Item -Path $($Model.PkgSourcePath) -ItemType Directory -Force 
        $DriverInfo | Export-Clixml -Path  "$($Model.PkgSourcePath)\$($DriverInfo.Id).xml"
        $AlreadyCurrent = $false

        #WIM Expanded Files
        # Cleanup Previous Runs (Deletes the files)
        if (Test-Path $dismscratchpath) {Remove-Item $DismScratchPath -Force -Recurse -ErrorAction SilentlyContinue}
            
        
        $DismScratch = New-Item -Path $DismScratchPath -ItemType Directory -Force
        New-WindowsImage -ImagePath "$($Model.PkgSourcePath)\Drivers.wim" -CapturePath "$CapturePath" -Name "$($Model.MIFFilename) - $($Model.Language)"  -LogPath "$env:TEMP\dism-$($Model.MIFFilename).log" -ScratchDirectory $dismscratchpath
        $Date = get-date -Format "yyyyMMdd"
        $ReadmeContents = "Model: $($Model.Name) | Pack Version: $TargetVersion | CM PackageID: $($Model.PackageID)"
        $ReadmeContents | Out-File -FilePath "$($Model.PkgSourcePath)\$($DriverInfo.Id)-$($Date).txt"
        Set-Location -Path "$($SiteCode):"
        Update-CMDistributionPoint -PackageId $Model.PackageID
        Set-Location -Path "C:"
        [int]$DriverWIMSize = "{0:N2}" -f ((Get-ChildItem $($Model.PkgSourcePath) -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB)
        [int]$DriverExtractSize = "{0:N2}" -f ((Get-ChildItem $CapturePath -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB)

        Write-Host " Finished Expand & WIM Process, WIM size: $DriverWIMSize vs Expaneded: $DriverExtractSize" -ForegroundColor Green
        Write-Host " WIM Savings: $($DriverExtractSize - $DriverWIMSize) MB | $(100 - $([MATH]::Round($($DriverWIMSize / $DriverExtractSize)*100))) %" -ForegroundColor Green

        Remove-Item -Path $CapturePath -Force -Recurse
        }
   
    Write-Host "  Confirming Package Info in ConfigMgr $($PackageInfo.Name) ID: $($Model.PackageID)" -ForegroundColor yellow
    Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
    Set-Location -Path "$($SiteCode):"         
    Set-CMPackage -Id $Model.PackageID -Version $DriverInfo.Id
    Set-CMPackage -Id $Model.PackageID -MIFVersion $DriverInfo.ReleaseDate
    Set-CMPackage -Id $Model.PackageID -Description $Description
    $PackageInfo = Get-CMPackage -Id $Model.PackageID -Fast
    Update-CMDistributionPoint -PackageId $Model.PackageID
    Set-Location -Path "C:"
    Write-Host "Updated Package $($PackageInfo.Name), ID $($Model.PackageID) to $($DriverInfo.Id) which was released $($DriverInfo.ReleaseDate)" -ForegroundColor Gray
     Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    }  


Write-Output "Finished Script: $scriptName"
