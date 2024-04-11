<#  Version 2023.12.15 - Creator @gwblok - GARYTOWN.COM - @HP

    REQUIREMENTS:  HP Client Management Script Library
    Download / Installer: https://ftp.hp.com/pub/caps-softpaq/cmit/hp-cmsl.html  
    Docs: https://developers.hp.com/hp-client-management/doc/client-management-script-library-0
    
    Usage... Stage Prod or Dev
    If you don't do Dev.. just delete that Param section out and set $Stage = Prod or remove all Stage references complete, do whatever you want I guess.

    If you have a Proxy, you'll have to modify for that.


    This script will check your CM environment looking for HP Image Assistant Packages (Created via different script), then ask which ones to update.
    It will then build out the HPIA offline repo based on the Builds you want to include.
     - By Default, this script will attempt to include all HPIA softpaqs for Windows Builds 19045 (Win 10 22H2) and newer.
       - You can reduce the size of your Offline Repo by modifing the filter rules to include specific catigories or less builds.
       - This script was created so you could basically create one offline repo per platform which will work for different OS Build Task Sequences



#>


$SiteCode = "MCM"

#Reset Vars
$Driver = $null
$Model = $null
$Stage = $null
$User = $env:USERNAME
$HPIACMPackageName = "HP Image Assistant Tool"




#Load CM PowerShell
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"


#Update HPIA Package
$HPIAAppInfo = Get-HPImageAssistantUpdateInfo
$HPIACMPackageInfo = Get-CMPackage -Fast -Name $HPIACMPackageName
if ($HPIACMPackageInfo.Version){
    [version]$HPIACMPackageInfoVersion = $HPIACMPackageInfo.Version
}
else{
    [version]$HPIACMPackageInfoVersion = 0.0.0.0
}
if ($HPIAAppInfo.Version -gt $HPIACMPackageInfoVersion){
    Write-Host "Updating HPIA Package in CM" -ForegroundColor Green
    Write-Host " Package Version: $HPIACMPackageInfoVersion | Latest: $($HPIAAppInfo.Version)" -ForegroundColor Yellow
    $PackageSourceParent = $HPIACMPackageInfo.PkgSourcePath | Split-Path
    [String]$VersionNumber = $HPIAAppInfo.Version
    Set-Location -Path "C:\windows\temp"
    New-Item -Path "C:\windows\temp\HPIA-$($VersionNumber)" -ItemType Directory -Force | Out-Null
    New-Item -Path "$PackageSourceParent\$VersionNumber" -ItemType directory -Force | Out-Null
    Install-HPImageAssistant -Extract -DestinationPath "C:\windows\temp\HPIA-$($VersionNumber)"
    Copy-Item -Path "C:\windows\temp\HPIA-$($VersionNumber)\*"  -Destination "$PackageSourceParent\$VersionNumber" -Recurse -Force
    Remove-Item -Path "C:\windows\temp\HPIA-$($VersionNumber)" -Recurse -Force
    Set-Location -Path "$($SiteCode):"
    Set-CMPackage -InputObject $HPIACMPackageInfo -Path "$PackageSourceParent\$VersionNumber"
    Set-CMPackage -InputObject $HPIACMPackageInfo -Version $VersionNumber
    Write-Host " Updated Package $($HPIACMPackageInfo.PackageID) | $($HPIACMPackageInfo.Name)" -ForegroundColor Cyan
    Write-Host "  Updated Source Path = $PackageSourceParent\$VersionNumber" -ForegroundColor Cyan
    Write-Host "  Trigging Content Distribution Update" -ForegroundColor Cyan
    Update-CMDistributionPoint -PackageId $HPIACMPackageInfo.PackageID
}
else {
    Write-Host "HPIA Package Content already Current: $HPIACMPackageInfoVersion, skipping Update" -ForegroundColor Green

}



#To Select
if (!($Stage)){$Stage = "Prod", "Dev" | Out-GridView -Title "Select the Stage you want to update" -PassThru}

$HPModelsSelectTable = Get-CMPackage -Fast -Name "OfflineRepo*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.Mifname -eq $Stage} |Select-Object -Property "Name","MIFFilename","PackageID", "Version","MifVersion" | Sort-Object $_.MIFFilename | Out-GridView -Title "Select the Models you want to Update" -PassThru
$HPModelsTable = Get-CMPackage -Fast -Name "OfflineRepo*" | Where-Object {$_.PackageID -in $HPModelsSelectTable.PackageID}


#$HPModelsTable = Get-CMPackage -Fast -Id "PS2004AA"

Set-Location -Path "C:"

$StartTime = Get-Date
foreach ($Model in $HPModelsTable) #{Write-Host "$($Model.Name)"}
    {
    $StartTimePlatform = Get-Date
    $DriverInfo = $null
    $Prodcode = $Model.Language
    $Name = $Model.MIFFilename
    $LastBuildDate = $Model.MiFVersion

    Write-Host "Starting Process for Platform $Prodcode | $Name" -ForegroundColor Green
    Write-Host " CM Package for Offline Repo last Sycn'd: $LastBuildDate" -ForegroundColor Green
    
    Set-Location -Path "$($SiteCode):"
    $PackageInfo = $Model #Model at this point = the Object that has the Package info in it
    $PackageInfoVersion = $null
    $PackageInfoVersion = $PackageInfo.Version
    $PackageSource = $PackageInfo.PkgSourcePath
    Set-Location -Path "C:"


    #Create Offline HPIA Repo

    Set-Location -Path $PackageSource #Setting location to where to build the Offline Repo
    write-host "  Creating Offline Repo $PackageSource" -ForegroundColor Green
    #Starting Offline Repo Setup
    Initialize-Repository #https://developers.hp.com/hp-client-management/doc/initialize-repository
    Set-RepositoryConfiguration -setting OfflineCacheMode -Cachevalue Enable #https://developers.hp.com/hp-client-management/doc/set-repositoryconfiguration

    #Create Filter for Repo to include Win10 22H2 & Newer (You can modify the build number below if needed)
    #Note, not all devices (especially older ones) will support newer os, so it's good to pay attention to the list being generated
    $OSList = Get-HPDeviceDetails -Platform $Prodcode -OSList | Where-Object {$_.BuildNumber -ge 19045}

    foreach ($OperatingSystem in $OSList.OperatingSystem | Select-Object -Unique){
            
        $OS = switch ($OperatingSystem)
            {
                'Microsoft Windows 10' {"win10"}
                'Microsoft Windows 11' {"win11"}
            }

        foreach ($OSVer in ($OSList | Where-Object {$_.OperatingSystem -eq $OperatingSystem}).OperatingSystemRelease){
	        Write-Host "  Creating Offline Repo Filter to Support: $Platform | $OS | $OSVer" -ForegroundColor Cyan    
            Add-RepositoryFilter -Platform $Prodcode -Os $OS -OsVer $OSVer #https://developers.hp.com/hp-client-management/doc/Add-RepositoryFilter
        }
    }
    #Start Building (downloading) Offline Repo Content
    
    write-host "  Starting Offline Repo Sync - THIS CAN TAKE AWHILE!!!"  -ForegroundColor Yellow    
    Invoke-RepositorySync -quiet #https://developers.hp.com/hp-client-management/doc/Invoke-RepositorySync
    write-host "  Starting Offline Cleanup - Removing superseded SPs"  -ForegroundColor Yellow    

    Invoke-RepositoryCleanup #https://developers.hp.com/hp-client-management/doc/invoke-repositorycleanup

    #Add Readme Info to Package"
    Set-Location -Path "C:\"  #Reset to default Path
    $Date = get-date -Format "yyyy-MM-dd"
    $ReadmeFilePath = "$PackageSource\.ReadMe.txt"
    if (Test-Path -Path $ReadmeFilePath){Remove-Item -Path $ReadmeFilePath -Force}
    "CM Package ID: $($Model.PackageID), Last Modified $Date by $User" | Out-File -FilePath $ReadmeFilePath -Append
    "Supported OS List & Models based on Platform" | Out-File -FilePath $ReadmeFilePath -Append
    $OSList | Out-File -FilePath $ReadmeFilePath -Append
    Get-HPDeviceDetails -Platform $Prodcode | Select-Object -Property "SystemID", "Name"  | Out-File -FilePath $ReadmeFilePath -Append


    
    #Update DPs
    Set-Location -Path "$($SiteCode):"
    Update-CMDistributionPoint -PackageId $Model.PackageID
    
    #Report Size of Offline Repo in Console
    Set-Location -Path "C:"
    [int]$RepoSize = "{0:N2}" -f ((Get-ChildItem $($Model.PkgSourcePath) -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum / 1MB)
    Write-Host " Finished Creating Repo, size: $RepoSize" -ForegroundColor Green

    #Update CM Package Meta Data
    [String]$BuildList = $OSList.BuildNumber
    Write-Host "  Confirming Package Info in ConfigMgr $($PackageInfo.Name) ID: $($Model.PackageID)" -ForegroundColor yellow
    Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
    Set-Location -Path "$($SiteCode):"         
    Set-CMPackage -Id $Model.PackageID -Version $BuildList
    Set-CMPackage -Id $Model.PackageID -MIFVersion $Date
    Set-CMPackage -id $Model.PackageID -MifPublisher $User
    Set-Location -Path "C:"
    $FinishTimePlatform = Get-Date
    $TotalTimePlatform = New-TimeSpan -Start $StartTimePlatform -End $FinishTimePlatform
    Write-Host " Process took $TotalTimePlatform"
    Write-Host "Updated Package $($Model.Name), ID $($Model.PackageID)" -ForegroundColor Gray
     Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    }  

$FinishTime = Get-Date
$TotalTime = New-TimeSpan -Start $StartTime -End $FinishTime
Write-Host " Process took $TotalTime"
Write-Output "Finished Script: $scriptName"
