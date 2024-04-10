#to Run, boot OSDCloudUSB, at the PS Prompt: iex (irm win11.garytown.com)
$ScriptName = 'test.garytown.com'
$ScriptVersion = '24.04.10.01'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"


if (-not (Test-Path "C:\ProgramData\WinGet")) {
	New-Item -ItemType Directory -Path "C:\ProgramData\WinGet" | Out-Null
  }

if (-not (Get-Command 'WinGet' -ErrorAction SilentlyContinue)) {

    # Test if Microsoft.DesktopAppInstaller is present and install it
    if (Get-AppxPackage -Name Microsoft.DesktopAppInstaller) {
        Write-Host -ForegroundColor Yellow "[-] Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
    }
}
if (-not (Get-Command 'WinGet' -ErrorAction SilentlyContinue)) {

Write-Output "Latest URL: $URL"
    # Test if Microsoft.DesktopAppInstaller is present and install it
	Write-Output "Download Winget"  
	Start-BitsTransfer -DisplayName "WinGet" -Source "https://aka.ms/getwinget" -Destination "C:\ProgramData\WinGet\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
	if (Test-Path -Path "C:\ProgramData\WinGet\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"){
         	Write-Host -ForegroundColor Yellow "[-] Add-AppxProvisionedPackage -online -packagepath C:\ProgramData\WinGet\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle -SkipLicense"
		Add-AppxProvisionedPackage -online -packagepath "C:\ProgramData\WinGet\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -SkipLicense | Out-null	    
        	Write-Host -ForegroundColor Yellow "[-] Add-AppxPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe"
	    	Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
	}
    else{
        Write-Host -ForegroundColor Red "[F] Failed to download and install WinGet"
    }
}


Write-Output "Download VClibs"
Start-BitsTransfer -DisplayName "VClibs" -Source "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -Destination "C:\ProgramData\WinGet\Microsoft.VCLibs.x64.14.00.Desktop.appx"  
Write-Host -ForegroundColor Green "[+] Install Microsoft.VCLibs.x64.14.00.Desktop.appx" 
Add-AppxProvisionedPackage -online -packagepath C:\ProgramData\WinGet\Microsoft.VCLibs.x64.14.00.Desktop.appx -SkipLicense | Out-null

if (-not (Get-Command 'WinGet' -ErrorAction SilentlyContinue)) {
	Write-Host -ForegroundColor Red "Failed to download and install WinGet"
	}
else{
	Write-Host -ForegroundColor Green "[+] winget upgrade --all --accept-source-agreements --accept-package-agreements"
    	winget upgrade --all --accept-source-agreements --accept-package-agreements
}
