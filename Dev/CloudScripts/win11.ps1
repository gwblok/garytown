<#
Loads Functions
Creates Setup Complete Files
#>

$ScriptName = 'hope.garytown.com'
$ScriptVersion = '23.12.17.01'

#region functions
function Set-SetupCompleteCreateStartHOPEonUSB {
    
    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $SetupCompletePath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\Config\Scripts\SetupComplete"
    $ScriptsPath = $SetupCompletePath

    if (Test-Path "$SetupCompletePath\SetupComplete.ps1"){Rename-Item "$SetupCompletePath\SetupComplete.ps1" -NewName "$SetupCompletePath\SetupComplete.ps1.bak"}

    if (!(Test-Path -Path $ScriptsPath)){New-Item -Path $ScriptsPath} 

    $RunScript = @(@{ Script = "SetupComplete"; BatFile = 'SetupComplete.cmd'; ps1file = 'SetupComplete.ps1';Type = 'Setup'; Path = "$ScriptsPath"})


    Write-Output "Creating $($RunScript.Script) Files"

    $BatFilePath = "$($RunScript.Path)\$($RunScript.batFile)"
    $PSFilePath = "$($RunScript.Path)\$($RunScript.ps1File)"
            
    #Create Batch File to Call PowerShell File
            
    New-Item -Path $BatFilePath -ItemType File -Force
    $CustomActionContent = New-Object system.text.stringbuilder
    [void]$CustomActionContent.Append('%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File')
    [void]$CustomActionContent.Append(" $PSFilePath")
    Add-Content -Path $BatFilePath -Value $CustomActionContent.ToString()

    #Create PowerShell File to do actions
            
    New-Item -Path $PSFilePath -ItemType File -Force
    Add-Content -path $PSFilePath "Write-Output 'Starting SetupComplete HOPE Script Process'"
    Add-Content -path $PSFilePath "Write-Output 'iex (irm hope.garytown.com)'"
    }

#endregion

function Set-SetupCompleteCleanUpHOPE {
    
    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $SetupCompletePath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\Config\Scripts\SetupComplete"
    if (Test-Path "$SetupCompletePath\SetupComplete.ps1"){
        $FileContent = get-content -Path "$SetupCompletePath\SetupComplete.ps1"
        if ($FileContent -match "hope.garytown.com"){
            Remove-Item -Path "$SetupCompletePath\SetupComplete.ps1"
        }
    }
    if (Test-Path "$SetupCompletePath\SetupComplete.ps1.bak"){
        Rename-Item "$SetupCompletePath\SetupComplete.ps1.bak" -NewName "$SetupCompletePath\SetupComplete.ps1"
    }
}


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


    $OSVersion = 'Windows 11' #Used to Determine Driver Pack
    $OSReleaseID = '22H2' #Used to Determine Driver Pack
    $OSName = 'Windows 11 22H2 x64'
    $OSEdition = 'Pro'
    $OSActivation = 'Retail'
    $OSLanguage = 'en-us'

    #Used to Determine Driver Pack
    $Product = (Get-MyComputerProduct)
    $DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

    #Set OSDCloud Vars
    $Global:MyOSDCloud = [ordered]@{
        Restart = [bool]$False
        RecoveryPartition = [bool]$true
        OEMActivation = [bool]$True
        WindowsUpdate = [bool]$true
        WindowsUpdateDrivers = [bool]$true
        WindowsDefenderUpdate = [bool]$true
        SetTimeZone = [bool]$False
        ClearDiskConfirm = [bool]$False
    }

    if ($DriverPack){
        $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
    }

    #If Drivers are expanded on the USB Drive, disable installing a Driver Pack
    if (Test-DISMFromOSDCloudUSB -eq $true){
        Write-Host "Found Driver Pack Extracted on Cloud USB Flash Drive, disabling Driver Download via OSDCloud" -ForegroundColor Green
        $Global:MyOSDCloud.DriverPackName = "None"
    }

    #Enable HPIA | Update HP BIOS | Update HP TPM
    if (Test-HPIASupport){
        #$Global:MyOSDCloud.DevMode = [bool]$True
        $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
        $Global:MyOSDCloud.HPIAALL = [bool]$true
        $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true

    }



    #write variables to console
    $Global:MyOSDCloud

    #Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
    $ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
    import-module "$ModulePath\OSD.psd1" -Force

    #Launch OSDCloud
    Write-Host "Starting OSDCloud" -ForegroundColor Green
    write-host "Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage"

    Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage

    write-host "OSDCloud Process Complete, Running Custom Actions Before Reboot" -ForegroundColor Green
    if (Test-DISMFromOSDCloudUSB){
        Start-DISMFromOSDCloudUSB
    }





    #Create Custom SetupComplete on USBDrive, this will get copied and run during SetupComplete Phase thanks to OSD Function: Set-SetupCompleteOSDCloudUSB
    Set-SetupCompleteCreateStartHOPEonUSB

    #Create Marker so it knows this is a "HOPE" computer - No longer need thanks to the custom setup complete above.
    #new-item -Path C:\OSDCloud\configs -Name hope.JSON -ItemType file
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

    #Set OEM Activation Code
    Set-WindowsOEMActivation

    #Cleanup SetupComplete Custom USB File
    Set-SetupCompleteCleanUpHOPE

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
