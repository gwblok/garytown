$OSDCloudWorkspace = "d:\OSDCloudWinRE"
$OSDCloudSureRecoverAgent = "$OSDCloudWorkspace\SureRecoverAgent"

try {
    [void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspace)
    [void][System.IO.Directory]::CreateDirectory($OSDCloudSureRecoverAgent)
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\boot")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\efi")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\efi\boot")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\efi\microsoft\boot")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\sources")
}
catch {throw}

Install-Module -Name OSD -Scope AllUsers
Update-Module -name OSD -Force
import-module -name OSD -Force


#Run Once
New-OSDCloudTemplate -Name "OSDCloudWinRE" -WinRE
New-OSDCloudWorkspace -WorkspacePath $OSDCloudWorkspace

#Run Once - Add Custom Wallpaper
Edit-OSDCloudWinPE -Wallpaper "$OSDCloudWorkspace\WinRE.jpg"

#Run Once - Add WinPE Drivers & Install HPCMSL
Edit-OSDCloudWinPE -CloudDriver HP,USB,WiFi -PSModuleInstall HPCMSL

Edit-OSDCloudWinPE -WirelessConnect -StartURL 'https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/OSDCloudStartNet.ps1'

#Run when updates are made to PS Modules OSD or HPCMSL
Edit-OSDCloudWinPE -PSModuleInstall HPCMSL, AzureAD, Az.Accounts, Az.KeyVault, Az.Resources, Az.Storage, Microsoft.Graph.DeviceManagement, Microsoft.Graph.Intune,UEFIv2 -WirelessConnect 

#Custom Files
Mount-WindowsImage -Path D:\mount -ImagePath "$OSDCloudWorkspace\Media\sources\boot.wim" -Index 1
$Folder = Get-ChildItem 'D:\mount\Program Files\WindowsPowerShell\Modules\OSD'
$OSDModule = "$($Folder.FullName)"

copy-item "C:\GitHub\OSD\Public\Functions\OSDCloud\Get-WiFiActiveProfileSSID.ps1"   "$OSDModule\public\functions\OSDCloud\Get-WiFiActiveProfileSSID.ps1" -Force -Verbose
copy-item "C:\GitHub\OSD\Public\Functions\OSDCloud\Get-WiFiProfileKey.ps1"          "$OSDModule\public\functions\OSDCloud\Get-WiFiProfileKey.ps1" -Force -Verbose
copy-item "C:\GitHub\OSD\Public\Functions\OSDCloud\Initialize-OSDCloudStartnet.ps1" "$OSDModule\public\functions\OSDCloud\Initialize-OSDCloudStartnet.ps1" -Force -Verbose
copy-item "C:\GitHub\OSD\Public\Functions\OSDCloud\Test-DCUSupport.ps1"             "$OSDModule\public\functions\OSDCloud\Test-DCUSupport.ps1" -Force -Verbose
copy-item "C:\GitHub\OSD\Public\Functions\OSDCloud\Test-HPIASupport.ps1"            "$OSDModule\public\functions\OSDCloud\Test-HPIASupport.ps1" -Force -Verbose
copy-item "C:\GitHub\OSD\Public\OSDCloud.Setup.ps1"                                 "$OSDModule\public\OSDCloud.Setup.ps1" -Force -Verbose
copy-item "C:\GitHub\OSD\Public\OSDCloud.ps1"                                       "$OSDModule\public\OSDCloud.ps1" -Force -Verbose
copy-item "C:\GitHub\OSD\Public\OSD.WinRE.WiFi.ps1"                                 "$OSDModule\public\OSD.WinRE.WiFi.ps1" -Force -Verbose
copy-item "C:\GitHub\OSD\OSD.psd1"                                                  "$OSDModule\OSD.psd1" -Force -Verbose

Dismount-WindowsImage -Path D:\mount -Save

Copy-Item "$OSDCloudWorkspace\Media\sources\boot.wim" -Destination "\\nas\8TB\TEMP" -Force -Verbose


#Grab Required Files for Sure Recover (Just the 4 files for what we're doing)
Copy-Item "$OSDCloudWorkspace\Media\Boot\boot.sdi" -Destination "$OSDCloudSureRecoverAgent\boot" -Force -Verbose
Copy-Item "$OSDCloudWorkspace\Media\Efi\Boot\bootx64.efi" -Destination "$OSDCloudSureRecoverAgent\Efi\Boot" -Force -Verbose
Copy-Item "$OSDCloudWorkspace\Media\Efi\Microsoft\Boot\BCD" -Destination "$OSDCloudSureRecoverAgent\Efi\Microsoft\Boot\" -Force -Verbose
Copy-Item "$OSDCloudWorkspace\Media\sources\boot.wim" -Destination "$OSDCloudSureRecoverAgent\sources" -Force -Verbose






