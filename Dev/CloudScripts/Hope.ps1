<#
Loads Functions
Creates Setup Complete Files
#>

$ScriptName = 'hope.garytown.com'
$ScriptVersion = '24.1.11.1'

iex (irm functions.garytown.com)
#region functions
function Set-SetupCompleteCreateStartHOPEonUSB {
    
    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $SetupCompletePath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\Config\Scripts\SetupComplete"
    $ScriptsPath = $SetupCompletePath

    if (!(Test-Path -Path $ScriptsPath)){New-Item -Path $ScriptsPath} 

    $RunScript = @(@{ Script = "SetupComplete"; BatFile = 'SetupComplete.cmd'; ps1file = 'SetupComplete.ps1';Type = 'Setup'; Path = "$ScriptsPath"})


    Write-Output "Creating $($RunScript.Script) Files"

    $BatFilePath = "$($RunScript.Path)\$($RunScript.batFile)"
    $PSFilePath = "$($RunScript.Path)\$($RunScript.ps1File)"
            
    #Create Batch File to Call PowerShell File
    if (Test-Path -Path $PSFilePath){
        copy-item $PSFilePath -Destination "$ScriptsPath\SetupComplete.ps1.bak"
    }        
    New-Item -Path $BatFilePath -ItemType File -Force
    $CustomActionContent = New-Object system.text.stringbuilder
    [void]$CustomActionContent.Append('%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1')
    Add-Content -Path $BatFilePath -Value $CustomActionContent.ToString()

    #Create PowerShell File to do actions

    New-Item -Path $PSFilePath -ItemType File -Force
    Add-Content -path $PSFilePath "Write-Output 'Starting SetupComplete HOPE Script Process'"
    Add-Content -path $PSFilePath "Write-Output 'iex (irm hope.garytown.com)'"
    Add-Content -path $PSFilePath 'iex (irm hope.garytown.com)'
}

Function Restore-SetupCompleteOriginal {
    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $SetupCompletePath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\Config\Scripts\SetupComplete"
    $ScriptsPath = $SetupCompletePath
    if (Test-Path -Path "$ScriptsPath\SetupComplete.ps1.bak"){
        copy-item -Path "$ScriptsPath\SetupComplete.ps1.bak" -Destination "$ScriptsPath\SetupComplete.ps1"
    }
}
#endregion




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
    #Create Custom SetupComplete on USBDrive, this will get copied and run during SetupComplete Phase thanks to OSD Function: Set-SetupCompleteOSDCloudUSB
    Set-SetupCompleteCreateStartHOPEonUSB
    
    Write-Host -ForegroundColor Green "Starting win11.garytown.com"
    iex (irm win11.garytown.com)

    #Create Marker so it knows this is a "HOPE" computer - No longer need thanks to the custom setup complete above.
    #new-item -Path C:\OSDCloud\configs -Name hope.JSON -ItemType file
    Restore-SetupCompleteOriginal
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

    #Set DO
    #Set-DOPoliciesGPORegistry
    
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

    #Store Updates
    Write-Host -ForegroundColor Gray "**Running Winget Updates**"
    Write-Host -ForegroundColor Gray "Invoke-UpdateScanMethodMSStore"
    Invoke-UpdateScanMethodMSStore
    Write-Host -ForegroundColor Gray "winget upgrade --all --accept-package-agreements --accept-source-agreements"
    winget upgrade --all --accept-package-agreements --accept-source-agreements


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
