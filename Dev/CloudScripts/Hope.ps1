<#
Loads Functions
Creates Setup Complete Files




#>

#Load Functions
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/Functions.ps1)
iex (irm functions.osdcloud.com)

<# Future version of OSD Module
Set-SetupCompleteCreateStart
Set-SetupCompleteTimeZone
Set-SetupCompleteRunWindowsUpdate
Set-SetupCompleteOSDCloudUSB
Set-SetupCompleteCreateFinish

#>
