# Create a new PS process to call the "Show-OSUpgradeBackground" script, to avoid blocking the continuation of task sequence

$Process = New-Object System.Diagnostics.Process
$Process.StartInfo.UseShellExecute = $false
$Process.StartInfo.FileName = "PowerShell.exe"
$Process.StartInfo.Arguments = " -File ""$PSScriptRoot\Create-Runspaces.ps1"""
$Process.StartInfo.CreateNoWindow = $true
$Process.Start()
