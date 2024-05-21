$Manufacturer = (Get-CimInstance -Namespace root/CIMV2 -ClassName Win32_ComputerSystem).Manufacturer
Write-Output "Manufacturer = $Manufacturer"
if ($Manufacturer -match "Lenovo"){
    Write-Host "Device is Lenovo, attempting to install Module LSUClient"
    Install-Module -Name LSUClient -Force
    Import-Module -Name LSUClient
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended }
    $i = 1
    foreach ($update in $updates) {
        Write-Host "Installing update $i of $($updates.Count): $($update.Title)"
        Install-LSUpdate -Package $update -Verbose
        $i++
    }
}
