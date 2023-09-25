<#
Loads Functions
Creates Setup Complete Files




#>

$ScriptName = 'hope.garytown.com'
$ScriptVersion = '23.9.25.4'

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"

#Load Functions
if ($env:SystemDrive -ne 'X:') {
    Write-Host -ForegroundColor Yellow "Restart after Script Completes?"
    $Restart = Read-Host "y or n, then Enter"
}

iex (irm functions.garytown.com)
iex (irm functions.osdcloud.com)

#WinPE Stuff


#Non-WinPE
if ($env:SystemDrive -ne 'X:') {
    #Remove Personal Teams
    iex (irm https://raw.githubusercontent.com/suazione/CodeDump/main/Set-ConfigureChatAutoInstall.ps1)
    Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/85ad154fa2964ea4757a458dc5c91aea5bf483c6/HopeForUsedComputers/Hope%20for%20Used%20Computers%20PDF.pdf" -OutFile "C:\Users\Public\Desktop\Hope For Used Computers.pdf" -Verbose
    Enable-AutoZimeZoneUpdate
    #Windows Updates
    Update-DefenderStack
    Run-WindowsUpdate
    Run-WindowsUpdateDriver


}

#Both
#Set Random Stuff
Inject-Win11ReqBypassRegValues
Set-TimeZoneFromIP
if ($Restart -eq "Y"){Restart-Computer}



<# Future version of OSD Module
Set-SetupCompleteCreateStart
Set-SetupCompleteTimeZone
Set-SetupCompleteRunWindowsUpdate
Set-SetupCompleteOSDCloudUSB
Set-SetupCompleteCreateFinish

#>
