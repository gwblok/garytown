<#
Loads Functions
Creates Setup Complete Files
#>

$ScriptName1 = 'intunelab.garytown.com'
$ScriptVersion1 = '25.3.17.1'


#region Initialization
function Write-DarkGrayDate {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [System.String]
        $Message
    )
    if ($Message) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) $Message"
    }
    else {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    }
}
function Write-DarkGrayHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message
    )
    Write-Host -ForegroundColor DarkGray $Message
}
function Write-DarkGrayLine {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray '========================================================================='
}
function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [System.String]
        $Message
    )
    Write-DarkGrayLine
    Write-DarkGrayDate
    Write-Host -ForegroundColor Cyan $Message
}
function Write-SectionSuccess {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [System.String]
        $Message = 'Success!'
    )
    Write-DarkGrayDate
    Write-Host -ForegroundColor Green $Message
}
#endregion


iex (irm functions.garytown.com)
#region functions

function New-SetupCompleteOSDCloudFiles{
    [CmdletBinding()]
    param (
        [string]$URL2Call = "IntuneLab.garytown.com"
    )
    
    $SetupCompletePath = "C:\OSDCloud\Scripts\SetupComplete"
    $ScriptsPath = $SetupCompletePath

    if (!(Test-Path -Path $ScriptsPath)){New-Item -Path $ScriptsPath -ItemType Directory -Force | Out-Null}

    $RunScript = @(@{ Script = "SetupComplete"; BatFile = 'SetupComplete.cmd'; ps1file = 'SetupComplete.ps1';Type = 'Setup'; Path = "$ScriptsPath"})

    Write-Output "Creating $($RunScript.Script) Files in $SetupCompletePath"

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
    Add-Content -path $PSFilePath "Write-Output 'iex (irm $URL2Call)'"
    Add-Content -path $PSFilePath 'if ((Test-WebConnection) -ne $true){Write-error "No Internet, Sleeping 2 Minutes" ; start-sleep -seconds 120}'
    Add-Content -path $PSFilePath "iex (irm $URL2Call)"
}
#endregion
if ($env:SystemDrive -eq 'X:') {
    $LogName = "Hope-$((Get-Date).ToString('yyyy-MM-dd-HHmmss')).log"
    Start-Transcript -Path $env:TEMP\$LogName -Append -Force
}
Write-SectionHeader -Message "Starting $ScriptName1 $ScriptVersion1"
write-host "Added Function New-SetupCompleteOSDCloudFiles" -ForegroundColor Green

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
    
    #Doing this now with a new process that will create the files right on C, skipping the need to use a USB Drive... not sure why I was doing that before.
    #Set-SetupCompleteCreateStartHOPEonUSB
    if (Test-Connection -ComputerName wd1tb -ErrorAction SilentlyContinue){
        Write-SectionHeader -Message "Mapping Drive W: to \\WD1TB\OSD"
        net use w: \\wd1tb\osd /user:OSDCloud P@ssw0rd
        start-sleep -s 2
        if (Test-Path -Path W:\OSDCloud){
            Write-Host -ForegroundColor Green "Successfully Mapped Drive"
        }
        else{
            Write-Host -ForegroundColor Red "Failed to Map Drive"
        }
    }
    else{
        Write-Host -ForegroundColor DarkGray "No Connection to WD1TB, Skipping Drive Mapping"
    }
    Write-SectionHeader -Message "Starting win11.garytown.com"
    iex (irm win11.garytown.com)

    #Create Marker so it knows this is a "HOPE" computer - No longer need thanks to the custom setup complete above.
    #new-item -Path C:\OSDCloud\configs -Name hope.JSON -ItemType file
    #Restore-SetupCompleteOriginal
    
    #Just go ahead and create the Setup Complete files on the C Drive in the correct Location now that OSDCloud is done in WinPE
    Write-SectionHeader -Message "Creating Custom SetupComplete Files"
    New-SetupCompleteOSDCloudFiles -URL2Call "IntuneLab.garytown.com"

    #Set Personal Preferences
    Write-SectionHeader -Message "Setting Preferences"
    Write-Host -ForegroundColor Gray "Set-DefaultProfilePersonalPref"
    Set-DefaultProfilePersonalPref
    Set-MyPrefsRegistryValues

    
    #Set-TaskBarStartMenu
    iex (irm 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Dev/FunctionsSnips/Set-TaskBarStartMenu.ps1')
    Write-Host -ForegroundColor Gray "Set-TaskBarStartMenu"
    Set-TaskBarStartMenu -RemoveTaskView -RemoveCopilot -RemoveWidgets -RemoveChat -MoveStartLeft -RemoveSearch -StartMorePins


    if (Test-Path -Path $env:TEMP\$LogName){
        Write-DarkGrayHost -Message "Copying Log to C:\OSDCloud\Logs"
        Stop-Transcript
        Copy-Item -Path $env:TEMP\$LogName -Destination C:\OSDCloud\Logs -Force
    }
    Write-SectionHeader -Message "Completed WinPE Phase of $ScriptName1 $ScriptVersion1"
    Write-Host -ForegroundColor DarkGray "Restarting in 60 Seconds"
    Start-Sleep -Seconds 60
    restart-computer
}

#Non-WinPE
if ($env:SystemDrive -ne 'X:') {


    #Setup Post Actions Scheduled Task
    #iex (irm "https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/PostActionsTask.ps1")

    #Disable Auto Bitlocker
    New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker -Name PreventDeviceEncryption -PropertyType dword -Value 1 -Force
    
    #Remove Personal Teams
    Write-Host -ForegroundColor Gray "**Removing Default Chat Tool**" 
    try {
        iex (irm https://raw.githubusercontent.com/suazione/CodeDump/main/Set-ConfigureChatAutoInstall.ps1)
    }
    catch {}


    #OEM Updates
    if ($Manufacturer -match "Microsoft"){
        if ($ComputerModel -match "Virtual Machine"){
            try {
                Set-HyperVName
            }
            catch {}
        }
    }


    #Trigger Autopilot Enrollment
    Function Invoke-APConnect {
        [CmdletBinding()]
        param (
            [ValidateSet('GARYTOWN', '2PintLab')]
            [string]$Tenant
        )
        if (Test-Connection -ComputerName wd1tb -ErrorAction SilentlyContinue){
            Write-SectionHeader -Message "Mapping Drive W: to \\WD1TB\OSD"
            if (Test-Path -Path W:){
                Write-Host -ForegroundColor Green "Drive W: Already Mapped"
            }
            else{
                Write-Host -ForegroundColor DarkGray "net use w: \\wd1tb\osd /user:OSDCloud [PASSWORD] /persistent:no"
                net use w: \\wd1tb\osd /user:OSDCloud P@ssw0rd /persistent:no
            }
            start-sleep -s 2
            if (Test-Path -Path W:\OSDCloud){
                Write-Host -ForegroundColor Green "Successfully Mapped Drive, triggering Autopilot Enrollment Script"
                
                if ($Tenant -eq "GARYTOWN"){
                        if (Test-Path -Path W:\OSDCloud\Config\Scripts\Set-APEnterpriseViaAppRegistration.ps1){
                        Write-Host -ForegroundColor DarkGray "Starting W:\OSDCloud\Config\Scripts\Set-APEnterpriseViaAppRegistration.ps1"
                    Start-Process powershell.exe -ArgumentList "-File", "W:\OSDCloud\Config\Scripts\Set-APEnterpriseViaAppRegistration.ps1"
                    }
                    else{
                        Write-Host -ForegroundColor Red "Enrollment Script Not Found, Skipping"
                        Write-Host -ForegroundColor DarkGray "Unable to find: W:\OSDCloud\Config\Scripts\Set-APEnterpriseViaAppRegistration.ps1"
                    }
                }
                elseif ($Tenant -eq "2PintLab"){
                    if (Test-Path -Path W:\OSDCloud\Config\Scripts\Set-APEnterpriseViaAppRegistration-2PintLab.ps1){
                        Write-Host -ForegroundColor DarkGray "Starting W:\OSDCloud\Config\Scripts\Set-APEnterpriseViaAppRegistration-2PintLab.ps1"
                        Start-Process powershell.exe -ArgumentList "-File", "W:\OSDCloud\Config\Scripts\Set-APEnterpriseViaAppRegistration-2PintLab.ps1"
                    }
                    else{
                        Write-Host -ForegroundColor Red "Enrollment Script Not Found, Skipping"
                        Write-Host -ForegroundColor DarkGray "Unable to find: W:\OSDCloud\Config\Scripts\Set-APEnterpriseViaAppRegistration-2PintLab.ps1"
                    }
                    <# Action when this condition is true #>
                }
            }
            else{
                Write-Host -ForegroundColor Red "Failed to Map Drive"
            }
        }
        else{
            Write-Host -ForegroundColor DarkGray "No Connection to WD1TB, Skipping Drive Mapping"
        }
    }

    #Do Stuff
    Write-SectionHeader -Message "**Triggering Autopilot Enrollment**"
    $HyperVName = Get-HyperVName
    if ($HyperVName -match "GT"){
        Write-Host -ForegroundColor Green "GARYTOWN Intune Machine, Triggering Enrollment"
        try {
             Invoke-APConnect -Tenant "GARYTOWN"
        }
        catch {
            Write-Host -ForegroundColor Red "Failed to Trigger Enrollment, trying again"
        }
       
    }
    elseif ($HyperVName -match "2P"){ 
        Write-Host -ForegroundColor Green "2Pint Lab Machine, Triggering Enrollment"
        try {
            Invoke-APConnect -Tenant "2PintLab"
        }
        catch {
            Write-Host -ForegroundColor Red "Failed to Trigger Enrollment, trying again"
        }
        Invoke-APConnect -Tenant "2PintLab"
    }
    else{
        Write-Host -ForegroundColor DarkGray "Not an Intune Device, Skipping Enrollment"
    }

    #Install CMTrace
    Install-CMTrace

    Write-SectionHeader -Message "**Installing StifleR**"
    #Install StifleR
    Install-StifleRClient210


    Write-SectionHeader -Message "**Setting Up Windows Update Settings**"

    #Enable Microsoft Other Updates:
    (New-Object -com "Microsoft.Update.ServiceManager").AddService2("7971f918-a847-4430-9279-4a52d1efe18d",7,"")

    #Enable "Notify me when a restart is required to finish updating"
    New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name RestartNotificationsAllowed2 -PropertyType dword -Value 1
    #Enable "Get the latest updates as soon as they are available"
    New-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings -Name IsContinuousInnovationOptedIn -PropertyType dword -Value 1

    Write-SectionHeader -Message  "**Setting Default Profile Personal Preferences**" 
    Set-DefaultProfilePersonalPref
    
    #Try to prevent crap from auto installing
    Write-Host -ForegroundColor Gray "**Disabling Cloud Content**" 
    Disable-CloudContent
    

    #Windows Updates
    Write-SectionHeader -Message "**Running MS Updates**"
    Write-Host -ForegroundColor Gray "**Running Defender Updates**"
    Update-DefenderStack
    Write-Host -ForegroundColor Gray "**Running Windows Updates**"
    Start-WindowsUpdate
    Write-Host -ForegroundColor Gray "**Running Driver Updates**"
    Start-WindowsUpdateDriver

    #Trigger AP Enrollment (Again)
    #Write-SectionHeader -Message "**Triggering Autopilot Enrollment Again**"
    #Invoke-APConnect

    #Store Updates
    Write-Host -ForegroundColor Gray "**Running Winget Updates**"
    Write-Host -ForegroundColor Gray "Invoke-UpdateScanMethodMSStore"
    Invoke-UpdateScanMethodMSStore
    
    #Write-Host -ForegroundColor Gray "winget upgrade --all --accept-package-agreements --accept-source-agreements"
    #winget upgrade --all --accept-package-agreements --accept-source-agreements

    #Modified Version of Andrew's Debloat Script
    Write-SectionHeader -Message "**Running Debloat Script**" 
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/Debloat.ps1)


    $BaseBoard = Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard
    $ComputerSystem = Get-CimInstance -Namespace root/cimv2 -ClassName Win32_ComputerSystem
    $Manufacturer = ($ComputerSystem).Manufacturer
    $ManufacturerBaseBoard = ($BaseBoard).Manufacturer
    $ComputerModel = ($ComputerSystem).Model

    if (($Manufacturer -match "Microsoft" -or $ManufacturerBaseBoard -match "Microsoft") -and $ComputerModel -match "Virtual Machine") {
        Write-Host -ForegroundColor Green "Microsoft Hyper-V Machine Detected, Setting Hyper-V Name"
        Write-SectionHeader -Message "**Setting Hyper-V Name**"
        try {
            Set-HyperVName
        }
        catch {
            Write-Host -ForegroundColor Red "Failed to Set Hyper-V Name, trying again"
            Set-HyperVName
        }
        #Do some Extra Cleanup
        Write-Host -ForegroundColor DarkGray "Backing Up Logs"
        New-Item -Path "C:\OSDCloudLogs" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        Move-Item -Path "C:\OSDCloud\logs" -Destination "C:\OSDCloudLogs" -Force -ErrorAction SilentlyContinue
        Write-Host -ForegroundColor DarkGray "Removing C:\OSDCloud"
        Remove-Item -path "c:\OSDCloud" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host -ForegroundColor DarkGray "Removing C:\Drivers"
        Remove-Item -path "c:\Drivers" -Recurse -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host -ForegroundColor DarkGray "Not a Microsoft Hyper-V Machine, Skipping Hyper-V Name Setting"
    }

    #Set Personal Preferences - Dark Mode
    Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name "AppsUseLightTheme" -Value 0 -Type Dword | out-null
    Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name "SystemUsesLightTheme" -Value 0 -Type Dword | out-null

    #Set Time Zone
    Write-Host -ForegroundColor Gray "**Setting TimeZone based on IP**"
    Set-TimeZoneFromIP

    Write-SectionHeader -Message  "**Completed IntuneLab.garytown.com sub script**" 
}
