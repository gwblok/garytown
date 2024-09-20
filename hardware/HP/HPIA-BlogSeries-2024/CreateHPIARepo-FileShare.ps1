<# Gary Blok - GARYTOWN.COM 
HP Offline Repo for File Share Script

WHAT YOU NEED TO DO:
!! Update $DevicePlatforms with the HP Platform (Product Code) you want to build your repo for
!! Set the $OS & OSVer Variables for the OS you plan to deploy.
!! Set the RepoHostLocation to where you want it built.  Feel free to build locally and copy, or just build it on your share... whatever floats your boat.


Script is defaulted for Example to: Windows 11 23H2 Repo for 4 models with 1 model not supporting that OS to show how it will exclude it.

To get a list of OS's a specifc platform supports:
Get-HPDeviceDetails -oslist -Platform XXXX

#>    


#Change these 4 items to fit your every dream and desire (for the offline repo)
$DevicePlatforms = @('871A','83EF','896D','83F3')

#OS Options
$OS = 'Win11'
$OSVer = '23H2'

#NAS Location of Offline Repo
$RepoHostLocation = "\\nas\osd\HPIARepo\$OSVer\Dev"


# Don't change anything below here (unless you really want to, but you don't need to)

if ($OS = 'Win10'){$OSFull = 'Microsoft Windows 10'}
if ($OS = 'Win11'){$OSFull = 'Microsoft Windows 11'}


#Rebuild Supported Devices based on if they support the OS & OSVer requested
Write-Host "Confirming Model Selections are supported by $OS & $OSVer options" -ForegroundColor Cyan
$SupportedPlatforms = @()
foreach ($Platform in $DevicePlatforms){
    $OSListOSMatch = Get-HPDeviceDetails -Platform $Platform -OSList | Where-Object {$_.OperatingSystem -eq $OSFull}
    if ($OSListOSMatch){
        $OSListOSRMatch = Get-HPDeviceDetails -Platform $Platform -OSList | Where-Object {$_.OperatingSystemRelease -eq $OSVer}
    }
    if ($OSListOSRMatch){
        $SupportedPlatforms += $Platform
    }
    else{
        Write-Host "$Platform does NOT support $OS & $OSVer" -ForegroundColor Red
        Write-Host "To see what $Platform does support, use command | Get-HPDeviceDetails -Platform $Platform -OSList" -ForegroundColor Red
    }
}


if (!(Test-Path -Path $RepoHostLocation)){
    Write-Host "Creating Repo Folder $RepoHostLocation" -ForegroundColor Green
    New-Item -Path $RepoHostLocation -ItemType Directory -Force | Out-Null
}

#Set Location to where the Repo will be created
Set-Location -Path $RepoHostLocation #Setting location to where to build the Offline Repo
write-host "  Creating Offline Repo $RepoHostLocation" -ForegroundColor Green
#Starting Offline Repo Setup
Initialize-Repository #https://developers.hp.com/hp-client-management/doc/initialize-repository
Set-RepositoryConfiguration -setting OfflineCacheMode -Cachevalue Enable #https://developers.hp.com/hp-client-management/doc/set-repositoryconfiguration

#Repo Cleanup of Models
$CurrentFilters = (Get-RepositoryInfo).Filters
if ($CurrentFilters){
    ForEach ($Filter in $CurrentFilters){
        if ($Filter.Platform -notin $SupportedPlatforms){
            $Platform = $Filter.Platform
            $OS = ($Filter.operatingSystem).Split(":")| Select-Object -First 1
            $OSVer = ($Filter.operatingSystem).Split(":")| Select-Object -Last 1
            $Friendly = (Get-HPDeviceDetails -Platform $Platform).Name | Select-Object -First 1
            Write-Host "$($Filter.Platform) | ? $Friendly ?, removing it from the Repository Filter" -ForegroundColor Yellow
            Write-Host "Remove-RepositoryFilter -Platform $Platform -Os $OS -OsVer $OSVer" -ForegroundColor Gray
            Remove-RepositoryFilter -Platform $Platform -Os $OS -OsVer $OSVer -Yes
        }
    }
}

foreach ($Platform in $SupportedPlatforms){

	Write-Host "  Creating Offline Repo Filter to Support: $Platform | $OS | $OSVer" -ForegroundColor Cyan    
    Add-RepositoryFilter -Platform $Platform -Os $OS -OsVer $OSVer #https://developers.hp.com/hp-client-management/doc/Add-RepositoryFilter
}

#Start Building (downloading) Offline Repo Content
    
write-host "  Starting Offline Repo Sync - THIS CAN TAKE AWHILE!!!"  -ForegroundColor Yellow    
Invoke-RepositorySync -quiet #https://developers.hp.com/hp-client-management/doc/Invoke-RepositorySync
write-host "  Starting Offline Cleanup - Removing superseded SPs"  -ForegroundColor Yellow    

Invoke-RepositoryCleanup #https://developers.hp.com/hp-client-management/doc/invoke-repositorycleanup
