$Manufacturer = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem).Manufacturer
Write-Output "Manufacturer = $Manufacturer"
if ($Manufacturer -match "Lenovo"){
    iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudTS/Install-LenovoApps.ps1)
    iex (irm https://sandbox.osdcloud.com)
    Install-LenovoVantage
    Set-LenovoVantage
    Write-Host "Device is Lenovo, attempting to install Module LSUClient"
    Install-Module -Name LSUClient -Force
    Import-Module -Name LSUClient
    Write-Host "Scanning for updates...."
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended }
    $i = 1
    foreach ($update in $updates) {
        Write-Host "Installing update $i of $($updates.Count): $($update.Title)"
        Install-LSUpdate -Package $update -Verbose
        $i++
    }

    $LenovoBackgroundTask = Get-ScheduledTask -TaskName "Background monitor" -ErrorAction SilentlyContinue
    if ($LenovoBackgroundTask){
        Disable-ScheduledTask -TaskName "Background monitor"
    }
}
