<#
Contains botht he Detection & Remediation for installing the Dell PS Provider
to be used with the other scripts for setting Dell settings that require the PS Provder (older hardware that doesn't have native WMI bios management

#>
#Detection
$DellProviderInstalled = Get-InstalledModule -Name DellBIOSProvider -ErrorAction SilentlyContinue
if ($DellProviderInstalled){
    $Compliance = "Compliant"
}
else{
    $Compliance = "Non-Compliant"
}
Write-Output $Compliance

#Remediation
$DellProviderInstalled = Get-InstalledModule -Name DellBIOSProvider -ErrorAction SilentlyContinue
if (!($DellProviderInstalled)){
    Install-Module -Name DellBIOSProvider -Force -AcceptLicense -Repository PSGallery -SkipPublisherCheck
}
