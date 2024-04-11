    
#My HP Models (Platforms) that support Windows 11 23H2
#Get-HPDeviceDetails -oslist -Platform XXXX
$SupportedDevices = @('8870','83EF','857F','8711','859C')
$OS = 'Win11'
$OSVer = '23H2'
    
#NAS Location of Offline Repo
$RepoHostLocation = "\\nas\osd\HPIARepo\$OSVer\Dev"
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

    
foreach ($Platform in $SupportedDevices){

	Write-Host "  Creating Offline Repo Filter to Support: $Platform | $OS | $OSVer" -ForegroundColor Cyan    
    Add-RepositoryFilter -Platform $Platform -Os $OS -OsVer $OSVer #https://developers.hp.com/hp-client-management/doc/Add-RepositoryFilter

}

#Start Building (downloading) Offline Repo Content
    
write-host "  Starting Offline Repo Sync - THIS CAN TAKE AWHILE!!!"  -ForegroundColor Yellow    
Invoke-RepositorySync -quiet #https://developers.hp.com/hp-client-management/doc/Invoke-RepositorySync
write-host "  Starting Offline Cleanup - Removing superseded SPs"  -ForegroundColor Yellow    

Invoke-RepositoryCleanup #https://developers.hp.com/hp-client-management/doc/invoke-repositorycleanup
