<#
Loads Functions
Creates Setup Complete Files




#>

#Load Functions
iex (irm funtions.garytown.com)
iex (irm functions.osdcloud.com)

#Set Random Stuff
Inject-Win11ReqBypassRegValues
Set-TimeZoneFromIP
Enable-AutoZimeZoneUpdate

#Windows Updates
Update-DefenderStack
Run-WindowsUpdate
Run-WindowsUpdateDriver




<# Future version of OSD Module
Set-SetupCompleteCreateStart
Set-SetupCompleteTimeZone
Set-SetupCompleteRunWindowsUpdate
Set-SetupCompleteOSDCloudUSB
Set-SetupCompleteCreateFinish

#>
