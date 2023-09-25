<#
Loads Functions
Creates Setup Complete Files




#>

$ScriptName = 'hope.garytown.com'
$ScriptVersion = '23.9.25.1'

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"

#Load Functions
$Restart = Read-Host "Please Type Y if you would like to Restart After Process Completes, otherwise press any key"

iex (irm functions.garytown.com)
iex (irm functions.osdcloud.com)



#Set Random Stuff
Inject-Win11ReqBypassRegValues
Set-TimeZoneFromIP
Enable-AutoZimeZoneUpdate

#Windows Updates
Update-DefenderStack
Run-WindowsUpdate
Run-WindowsUpdateDriver

Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/85ad154fa2964ea4757a458dc5c91aea5bf483c6/HopeForUsedComputers/Hope%20for%20Used%20Computers%20PDF.pdf" -OutFile "C:\Users\Public\Desktop\Hope For Used Computers.pdf" -Verbose


if ($Restart = "Y"){Restart-Computer}



<# Future version of OSD Module
Set-SetupCompleteCreateStart
Set-SetupCompleteTimeZone
Set-SetupCompleteRunWindowsUpdate
Set-SetupCompleteOSDCloudUSB
Set-SetupCompleteCreateFinish

#>
