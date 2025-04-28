function Connect-CMSite {
#
# Press 'F5' to run this script. Running this script will load the ConfigurationManager
# module for Windows PowerShell and will connect to the site.
#
# This script was auto-generated at '2/19/2025 7:57:07 PM'.

# Site configuration
$SiteCode = "2CM" # Site code 
$ProviderMachineName = "2CM.2P.garytown.com" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams


}


$FailedDeployments = Get-CMDeploymentStatus -DeploymentId 2CM20018 | Where-Object {$_.StatusType -ne 1}
$MachineList = @()
Foreach ($FailedDeployment in $FailedDeployments)
{
    $FailedMachines = Get-CMDeploymentStatusDetails -InputObject $FailedDeployment
    foreach ($FailedMachine in $FailedMachines)
    {
        $DeviceDetailsObject = New-Object PSObject -Property @{
            DeviceName = $FailedMachine.DeviceName
            DeviceID = $FailedMachine.DeviceID
            StatusType = $FailedMachine.StatusType
            StatusDescription = $FailedMachine.StatusDescription
            DeploymentID = $FailedMachine.DeploymentID
            PackageName = $FailedMachine.PackageName
        }
        $MachineList += $DeviceDetailsObject
    }
}
$MachineList