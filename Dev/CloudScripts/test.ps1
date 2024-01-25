#to Run, boot OSDCloudUSB, at the PS Prompt: iex (irm win11.garytown.com)
$ScriptName = 'test.garytown.com'
$ScriptVersion = '24.01.09.01'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"

Write-Output "Starting Winget Section"
if (-not (Test-Path "C:\ProgramData\WinGet")) {
	New-Item -ItemType Directory -Path "C:\ProgramData\WinGet" | Out-Null
  }
Write-Output "Download Winget"  
Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile "C:\ProgramData\WinGet\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" | Out-null
Write-Output "Download VClibs"  
Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile "C:\ProgramData\WinGet\Microsoft.VCLibs.x64.14.00.Desktop.appx" | Out-null
Write-Output "Install Microsoft.VCLibs.x64.14.00.Desktop.appx" 
Add-AppxProvisionedPackage -online -packagepath C:\ProgramData\WinGet\Microsoft.VCLibs.x64.14.00.Desktop.appx -SkipLicense | Out-null
Write-Output "Install Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" 
Add-AppxProvisionedPackage -online -packagepath C:\ProgramData\WinGet\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle -SkipLicense | Out-null


