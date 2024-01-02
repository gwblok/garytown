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

    2023.03.20 - Added HPIA Offline Repo, so it will create two folders in WIM, Offline w/ INF Drivers for DISM & Online with HPIA Repo
    2023.03.20 - Modified to support Win11 as well as Win10... there is a lot of moving parts on this, so I don't doubt you'll see some errors on random models I haven't tested on.


#>



#Script Vars
#$OS = "Win10"
#$Category = "bios"
$SiteCode = "MCM"
$ScatchLocation = "E:\DedupExclude"
$DismScratchPath = "$ScatchLocation\DISM"
$scriptName = "Get HP Drivers & HPIA Offline Repo"
$CreateWIM = $false

$OSTable = @(
@{ OS = 'win10'; OSVer = '21H2'}
@{ OS = 'win10'; OSVer = '22H2'}
@{ OS = 'win11'; OSVer = '21H2'}
@{ OS = 'win11'; OSVer = '22H2'}
@{ OS = 'win11'; OSVer = '23H2'}
)

try {
    [void][System.IO.Directory]::CreateDirectory($ScatchLocation)
    [void][System.IO.Directory]::CreateDirectory($DismScratchPath)
}
catch {throw}

#Reset Vars
$Driver = $null
$Model = $null
$Stage = $null
$User = $env:USERNAME

#Load CM PowerShell
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

#To Select
if (!($Stage)){$Stage = "Prod", "Pre-Prod" | Out-GridView -Title "Select the Stage you want to update" -PassThru}

$HPModelsSelectTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.Mifname -eq $Stage} |Select-Object -Property "Name","MIFFilename","PackageID", "Version" | Sort-Object $_.MIFFilename | Out-GridView -Title "Select the Models you want to Update" -PassThru
$HPModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.PackageID -in $HPModelsSelectTable.PackageID}



#$HPModelsTable = Get-CMPackage -Fast -Id "PS2004AA"

Set-Location -Path "C:"
Write-Output "Starting Script: $scriptName"
$StartTime = Get-Date

foreach ($Model in $HPModelsTable) #{Write-Host "$($Model.Name)"}
    {
    $StartTimePlatform = Get-Date
    $DriverInfo = $null
    $Prodcode = $Model.Language
    $Name = $Model.MIFFilename
    $LastBuildDate = $Model.MiFVersion
    $Global:DriverPackOSInfo = [ordered]@{
        OS = $null
        OSVer = $null
        OSBuild = $null
    }
    Write-Host "Starting Process for Platform $Prodcode | $Name" -ForegroundColor Green
    $OSList = Get-HPDeviceDetails -platform $Prodcode -oslist
    $MaxOSSupported = ($OSList.OperatingSystem | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| measure -Maximum).Maximum
    if ($MaxOSSupported -Match "11"){$MaxOS = "Win11"; $MaxOSNumber = 11}
    else {$MaxOS = "Win10"; $MaxOSNumber = 10}
    $MaxBuild = (($OSList | Where-Object {$_.OperatingSystem -eq "$MaxOSSupported"}).OperatingSystemRelease | measure -Maximum).Maximum
    $SupportedOSBuilds = $OSList.OperatingSystemRelease | Sort-Object -Descending
    
    #Get Driver pack based on the latest OS supported by Platform... if not, continue back in time until one is found.
    $DriverInfo = Get-SoftpaqList -Platform $Prodcode -Category Driverpack -OsVer $MaxBuild -Os $MaxOS
    Write-Host "Max Supported OS: $(($OSList | Select-Object -Last 1).OperatingSystem) $(($OSList | Select-Object -Last 1).OperatingSYstemRelease) | $(($OSList | Select-Object -Last 1).BuildNumber)" -ForegroundColor Green
    #Win11
    if (!($DriverInfo))
        {
        $SupportedOSBuilds = (Get-HPDeviceDetails -platform $Prodcode -OSList| Where-Object {$_.OperatingSystem -match "11"}).OperatingSystemRelease | Sort-Object -Descending
        if ($SupportedOSBuilds){ $loop_index = 0
        do
                {
                $DriverInfo = Get-SoftpaqList -Platform $Prodcode -Category Driverpack -OsVer $($SupportedOSBuilds[$loop_index]) -Os "Win11" -ErrorAction SilentlyContinue
                if (!($DriverInfo)){$loop_index++;}
                }
            while ($DriverInfo -eq $null -and $loop_index -lt $SupportedOSBuilds.Count)
            if ($DriverInfo){
                write-host "Latest Driver Package is for Windows 11 $($SupportedOSBuilds[$loop_index])" -ForegroundColor Yellow
                $DriverPackOSInfo.OS = 11
                $DriverPackOSInfo.OSVer = $($SupportedOSBuilds[$loop_index])
            }
        }
    }
    #Win10
    if (!($DriverInfo))
        {
        $SupportedOSBuilds = (Get-HPDeviceDetails -platform $Prodcode -OSList| Where-Object {$_.OperatingSystem -match "10"}).OperatingSystemRelease | Sort-Object -Descending
        $loop_index = 0
        do
            {
            $DriverInfo = Get-SoftpaqList -Platform $Prodcode -Category Driverpack -OsVer $($SupportedOSBuilds[$loop_index]) -Os "Win10"
            if (!($DriverInfo)){$loop_index++;}
        }
        while ($DriverInfo -eq $null -and $loop_index -lt $SupportedOSBuilds.Count)
        if ($DriverInfo){
            write-host "Latest Driver Package is for Windows 10 $($SupportedOSBuilds[$loop_index])" -ForegroundColor Yellow
            $DriverPackOSInfo.OS = 10
            $DriverPackOSInfo.OSVer = $($SupportedOSBuilds[$loop_index])
        }
    }
    else
        {
        write-host " Latest Supported Build & Driver Package for $Maxos $MaxBuild" -ForegroundColor Green
        
        $DriverPackOSInfo.OS = $MaxOSNumber
        $DriverPackOSInfo.OSVer = $MaxBuild
    }
    
    #Get OS Build Number for Driver Pack Support - Used in Package Meta Data
    $DriverPackOSListSupport = $OSList | Where-Object {$_.OperatingSystem -match $DriverPackOSInfo.OS -and $_.OperatingSystemRelease -match $DriverPackOSInfo.OSVer}

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
        $PackageInfo = $Model #Model at this point = the Object that has the Package info in it
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
        $TempCabPath = "$env:windir\temp\HPCab"
        if (!(test-path "$TempCabPath")){New-Item -Path $TempCabPath -ItemType Directory | Out-Null}
        $SaveAs = "$($TempCabPath)\$($DriverInfo.Id).exe"
        $ExpandPath = "$($TempCabPath)\Expanded"
        if (test-path "$ExpandPath"){Remove-Item -Path $ExpandPath -Force -Recurse}
        New-Item -Path $ExpandPath -ItemType Directory | Out-Null
        if (!($PackageInfoVersion)){write-host "  $Name package has no previous downloads, downloading: $($DriverInfo.Id)" -ForegroundColor Yellow}
        else{Write-Host "  $Name package is version $($PackageInfoVersion), new version available $($DriverInfo.Id)" -ForegroundColor Yellow}
        Get-Softpaq -Number $($DriverInfo.Id) -SaveAs $saveAs
        $ExtractingFiles = Start-Process -FilePath $SaveAs -ArgumentList "/e /s /f $($ExpandPath)" -Wait
        $DriverRoot = (Get-ChildItem -Path $ExpandPath -Recurse | Where-Object {$_.name -match "wt64_" -or $_.name -match "W11_"}).FullName
        Get-Item -Path $DriverRoot | Rename-Item -NewName "offline"
        
        $CapturePath = (Split-Path $DriverRoot)
        #$null = new-item -path $CapturePath -Name "online" -ItemType Directory -Force

        #copy-item -Path $ExpandPath -Destination $PackageSource -Force -Recurse
        if (Test-Path $($Model.PkgSourcePath)) {Remove-Item $($Model.PkgSourcePath) -Force -Recurse -ErrorAction SilentlyContinue}
        $Null = New-Item -Path $($Model.PkgSourcePath) -ItemType Directory -Force 
        $DriverInfo | Export-Clixml -Path  "$($Model.PkgSourcePath)\$($DriverInfo.Id).xml"
        $AlreadyCurrent = $false

        #WIM Expanded Files
        # Cleanup Previous Runs (Deletes the files)
        if (Test-Path $dismscratchpath) {Remove-Item $DismScratchPath -Force -Recurse -ErrorAction SilentlyContinue}
         
        Set-Location -Path "C:\"  #Reset to default Path

        $DismScratch = New-Item -Path $DismScratchPath -ItemType Directory -Force
        New-WindowsImage -ImagePath "$($Model.PkgSourcePath)\Drivers.wim" -CapturePath "$CapturePath" -Name "$($Model.MIFFilename) - $($Model.Language)"  -LogPath "$env:TEMP\dism-$($Model.MIFFilename).log" -ScratchDirectory $dismscratchpath
        $Date = get-date -Format "yyyyMMdd"
        $ReadmeContents = "Model: $($Model.Name) | Pack Version: $($DriverInfo.Id) From $($DriverInfo.ReleaseDate) | CM PackageID: $($Model.PackageID)"
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
    Set-CMPackage -Id $Model.PackageID -Version "$($DriverInfo.Id) - $($DriverPackOSListSupport.BuildNumber)"
    Set-CMPackage -Id $Model.PackageID -MIFVersion $DriverInfo.ReleaseDate
    Set-CMPackage -id $Model.PackageID -MifPublisher $User
    #Set-CMPackage -Id $Model.PackageID -Description $Description
    $PackageInfo = Get-CMPackage -Id $Model.PackageID -Fast
    Update-CMDistributionPoint -PackageId $Model.PackageID
    Set-Location -Path "C:"
    $FinishTimePlatform = Get-Date
    $TotalTimePlatform = New-TimeSpan -Start $StartTimePlatform -End $FinishTimePlatform
    Write-Host " Process took $TotalTimePlatform"
    Write-Host "Updated Package $($PackageInfo.Name), ID $($Model.PackageID) to $($DriverInfo.Id) which was released $($DriverInfo.ReleaseDate)" -ForegroundColor Gray
     Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    }  

$FinishTime = Get-Date
$TotalTime = New-TimeSpan -Start $StartTime -End $FinishTime
Write-Host " Process took $TotalTime"
Write-Output "Finished Script: $scriptName"
