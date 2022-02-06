<# @GWBLOK

Using Script to Sync CM Collection of Machines to an AD Group.
 Why?  I'm using the AD Group to target specific group polices.

Set the Collecton you want to get devices from, and the AD Group you want to place them in.

#>

$CollectionID = "MEM000A9" #Physical Machines
$ADGroup = "Physical_WorkStations"

# Site configuration
$SiteCode = "MEM" # Site code 
$ProviderMachineName = "MEMCM.dev.recastsoftware.dev" # SMS Provider machine name

if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}
# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName
}
# Set the current location to be the site code.
Set-Location "$($SiteCode):\"
 
# Script really starts here...

$ADComputerObject = @()

$CMDevices = Get-CMDevice -Fast -CollectionId $CollectionID
ForEach ($CMDevice in $CMDevices){
    $ADComputerObject += Get-ADComputer -Identity $CMDevice.name
    }
Add-ADGroupMember -Identity $ADGroup -Members $ADComputerObject
