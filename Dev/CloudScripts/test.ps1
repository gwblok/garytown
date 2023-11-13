<#
Loads Functions
Creates Setup Complete Files




#>

$ScriptName = 'test.garytown.com'
$ScriptVersion = '23.11.13.01'

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

    


    $Global:MyOSDCloud = [ordered]@{
        PauseSpecialize = [bool]$True
        OSDCloudUnattend = [bool]$True
    }
    
    iex (irm win11.garytown.com)

    #Create Marker so it knows this is a "HOPE" computer
    new-item -Path C:\OSDCloud\configs -Name hope.JSON -ItemType file


    This is now in OSDCloud and controlled by the Vars above
    #Setup Complete (OSDCloud WinPE stage is complete)
    Write-Host "Creating SetupComplete Process" -ForegroundColor Green
    Set-SetupCompleteCreateStart
    Write-Host "  Enable OEM Activation" -ForegroundColor gray
    Set-SetupCompleteOEMActivation
    Write-Host "  Enable Defender Updates" -ForegroundColor gray
    Set-SetupCompleteDefenderUpdate
    Write-Host "  Enable Windows Updates" -ForegroundColor gray
    Set-SetupCompleteStartWindowsUpdate
    Write-Host "  Enable MS Driver Updates" -ForegroundColor gray
    Set-SetupCompleteStartWindowsUpdateDriver
    Write-Host "  Set Time Zone Updates" -ForegroundColor gray
    Set-SetupCompleteTimeZone
    Write-Host "  Check for Setup Complete on CloudUSB Drive" -ForegroundColor gray
    Set-SetupCompleteOSDCloudUSB
    Write-Host "Conclude SetupComplete Process Creation" -ForegroundColor Green
    Set-SetupCompleteCreateFinish
    
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
