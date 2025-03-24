# Requires the script to be run under an administrative account context.
#https://www.deploymentresearch.com/customizing-configmgr-boot-images-with-wmi-and-powershell/
#Requires -RunAsAdministrator

# ConfigMgr Site Code and SMS Provider
$SiteCode = "2CM"
$SMSProvider = "2CM.2p.garytown.com"

# Specify boot image
#	Win11 22H2 x64 StifleR 2.10 - 2011	22621.5039_25.03.24		2CM0004B	10.0.22621.5039	5.00.9132.1023	

$BootImageID = "2CM0004B"

# Get the boot image via WMI
$CMBootImage = Get-WmiObject -ComputerName $SMSProvider -Namespace "root\SMS\site_$($SiteCode)" -Class SMS_BootImagePackage | Where-Object {$_.PackageID -eq $BootImageID}
$BootImage = [wmi]"$($CMBootImage.__PATH)"

# Add F8 Support in ConfigMgr (needed when ADK version installed is different from Boot Image)
$BootImage.EnableLabShell = $true
$BootImage.Put()

# Add custom background image
$BackgroundUNCPath = "\\src\src$\Pictures\WinPE-2Pint.jpg"
$BootImage.BackgroundBitmapPath = $BackgroundUNCPath 
$BootImage.Put()
