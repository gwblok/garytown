#Gary Blok GWBLOK - Settings and Process taken from 2PintSoftware.com's recommendations. 

Write-Output "Set the BranchCache Port Variable"
Write-Output "the default is 80 so we want to change this to avoid conflicts with other apps that might use that port."
$BCPORT = '1337'

Write-Output "Set the BranchCache  Serve On Battery Variable"
$serveonbattery = 'TRUE'

Write-Output "Set the BranchCache Cache Age Variable"
Write-Output "Sets the age in days for how long untouched data will remain in the cache before being cleaned out."
$TTL = '365'

Write-Output "Stop the BranchCache Service"
Write-Output "Avoids errors in the event log when we reconfigure the port in the next steps"
Stop-Service -Name PeerDistSvc -Force

Write-Output "Set BranchCache ListenPort to $BCPORT"
Write-Output "Sets the port of which BranchCache uses to listen for  other peers requesting data."
New-Item -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PeerDist\DownloadManager\Peers\Connection" -Force
New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\PeerDist\DownloadManager\Peers\Connection" -Name ListenPort -PropertyType DWORD -Value $BCPORT -Force

Write-Output "Set BranchCache Cache Time To Live for cached data"
Write-Output "Sets the threshold for how long data is in the cache before its being removed out."
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PeerDist\Retrieval" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PeerDist\Retrieval" -Name SegmentTTL -PropertyType DWORD -Value $TTL -Force


Write-Output "Enables BranchCache in distributed mode"
Start-Process netsh -ArgumentList "branchcache set service mode=distributed serveonbattery=% serveonbattery%:" -PassThru -Wait

Write-Output "Set BranchCache Cache Size to 50% of disk space"
Write-Output "Can be set high on Windows 10 due to the BranchCache low disk space detection."
Start-Process netsh -ArgumentList "branchcache set cachesize size=50 percent=TRUE" -PassThru -Wait

Write-Output "Set BranchCache service start mode to Automatic"
Write-Output "Sets the starup of the BranchCache service to automatic to enable servicing other clients even if not actively downloading."
Set-Service -Name PeerDistSvc -StartupType Automatic
