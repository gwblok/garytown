<#
Loads Functions
Creates Setup Complete Files




#>

$ScriptName = 'hope.garytown.com'
$ScriptVersion = '23.11.07.01'

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"



<#
if ($env:SystemDrive -ne 'X:') {
    Write-Host -ForegroundColor Yellow "Restart after Script Completes?"
    $Restart = Read-Host "y or n, then Enter"
}
#>


Set-ExecutionPolicy Bypass -Force

#WinPE Stuff
if ($env:SystemDrive -eq 'X:') {
    Write-Host -ForegroundColor Green "Starting win11.garytown.com"
    iex (irm win11.garytown.com)

    #Create Marker so it knows this is a "HOPE" computer
    new-item -Path C:\OSDCloud\configs -Name hope.JSON -ItemType file
    restart-computer
}

#Non-WinPE
if ($env:SystemDrive -ne 'X:') {
    #Remove Personal Teams
    Write-Host -ForegroundColor Gray "**Removing Default Chat Tool**" 
    try {
        iex (irm https://raw.githubusercontent.com/suazione/CodeDump/main/Set-ConfigureChatAutoInstall.ps1)
    }
    catch {}
    # Add Hope PDF to Desktop
    Write-Host -ForegroundColor Gray "**Adding HOPE PDF to Desktop**" 
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/85ad154fa2964ea4757a458dc5c91aea5bf483c6/HopeForUsedComputers/Hope%20for%20Used%20Computers%20PDF.pdf" -OutFile "C:\Users\Public\Desktop\Hope For Used Computers.pdf"
    }
    catch {}
    #Set Time Zone to Automatic Update
    
    Write-Host -ForegroundColor Gray "**Setting Time Zone for Auto Update**" 
    Enable-AutoZimeZoneUpdate
    Write-Host -ForegroundColor Gray "**Setting Default Profile Personal Preferences**" 
    Set-DefaultProfilePersonalPref
    
    #Try to prevent crap from auto installing
    Write-Host -ForegroundColor Gray "**Disabling Cloud Content**" 
    Disable-CloudContent
    
    #Set Win11 Bypasses
    Write-Host -ForegroundColor Gray "**Enabling Win11 Bypasses**" 
    Set-Win11ReqBypassRegValues
    
    #Windows Updates
    Write-Host -ForegroundColor Gray "**Running Defender Updates**"
    Update-DefenderStack
    Write-Host -ForegroundColor Gray "**Running Windows Updates**"
    Start-WindowsUpdate
    Write-Host -ForegroundColor Gray "**Running Driver Updates**"
    Start-WindowsUpdateDriver


}

#Both
#Set Time Zone
Write-Host -ForegroundColor Gray "**Setting TimeZone based on IP**"
Set-TimeZoneFromIP


if ($Restart -eq "Y"){Restart-Computer}



<# Future version of OSD Module
Set-SetupCompleteCreateStart
Set-SetupCompleteTimeZone
Set-SetupCompleteRunWindowsUpdate
Set-SetupCompleteOSDCloudUSB
Set-SetupCompleteCreateFinish

#>
