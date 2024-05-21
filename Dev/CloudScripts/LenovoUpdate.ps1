if (Get-MyComputerManufacturer -match "Lenovo"){
    Install-Module -Name LSUClient
    Import-Module -Name LSUClient
    $updates = Get-LSUpdate | Where-Object { $_.Installer.Unattended }
    $i = 1
    foreach ($update in $updates) {
        Write-Host "Installing update $i of $($updates.Count): $($update.Title)"
        Install-LSUpdate -Package $update -Verbose
        $i++
    }
}
