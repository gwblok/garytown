#This is a Demo for Panasonic PowerShell Stuff
#Gary Blok, 2Pint Software

write-host "Loading Panasonic Demo from panasonic.garytown.com" -ForegroundColor Green
write-host "--------------------------------------------------" -ForegroundColor DarkGray
iex (irm panasonic.garytown.com)

#First thing, load up the Panasonic Modules

Write-Host "Installing Panasonic Modules" -ForegroundColor Green
Write-Host "Install-AllPanasonicModules" -ForegroundColor Gray
Install-AllPanasonicModules
Write-Host "Installed Panasonic Modules" -ForegroundColor Green

Write-Host "Press any key to continue..." -ForegroundColor Green
Read-Host
Write-Host "Lets check out the PC Settings Commands" -ForegroundColor Magenta
Write-Host ""
Read-Host
Get-Command -Module PanasonicCommandPCSettings | Out-Host

$PCSettings = Get-Command -Module PanasonicCommandPCSettings | Where-Object { $_.Name -match "^Get-PPc" }
# Loop through each command and execute it
foreach ($command in $PCSettings) {
    Write-Host "Running command: $($command.Name)"
    Invoke-Expression $command.Name
}

Write-Host "Press any key to continue..." -ForegroundColor Green
Read-Host
Write-Host "Lets check out the BIOS Commands" -ForegroundColor Magenta
Write-Host ""
Read-Host
Get-Command -Module PanasonicCommandPCSettings | Out-Host

$PCSettings = Get-Command -Module PanasonicCommandBIOSSettings | Where-Object { $_.Name -match "^Get-Panasonic" }
# Loop through each command and execute it
foreach ($command in $PCSettings) {
    Write-Host "Running command: $($command.Name)"
    Invoke-Expression $command.Name
}