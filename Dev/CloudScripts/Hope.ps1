<#
Loads Functions
Creates Setup Complete Files




#>

#Load Functions
$Restart = Read-Host "Please Type Y if you would like to Restart After Process Completes, otherwise press any key"

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

Invoke-WebRequest -UseBasicParsing -Uri "blob:https://github.com/6455bd35-864b-4292-870a-b1298536f755" -OutFile "C:\Users\Public\Desktop\Hope For Used Computers.pdf" -Verbose


if ($Restart = "Y"){Restart-Computer}



<# Future version of OSD Module
Set-SetupCompleteCreateStart
Set-SetupCompleteTimeZone
Set-SetupCompleteRunWindowsUpdate
Set-SetupCompleteOSDCloudUSB
Set-SetupCompleteCreateFinish

#>
