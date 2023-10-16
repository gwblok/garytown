$ScriptName = 'functions.garytown.com'
$ScriptVersion = '23.10.16.1'

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion"
#endregion

Write-Host -ForegroundColor Green "[+] Function Start-DISMFromOSDCloudUSB"
Function Test-DISMFromOSDCloudUSB {
    #region Initialize
    #require OSD Module Installed

    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $ComputerProduct = (Get-MyComputerProduct)
    $ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
    $DriverPath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct"
    if (Test-Path $DriverPath){Return $true}
    else { Return $false}

}
Function Start-DISMFromOSDCloudUSB {
    #region Initialize
    if ($env:SystemDrive -eq 'X:') {
        $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
        $ComputerProduct = (Get-MyComputerProduct)
        $ComputerManufacturer = (Get-MyComputerManufacturer -Brief)
        $DriverPath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\DriverPacks\DISM\$ComputerManufacturer\$ComputerProduct"
        Write-Host "Checking location for Drivers: $DriverPath" -ForegroundColor Green
        if (Test-Path $DriverPath){
            Write-Host "Found Drivers: $DriverPath" -ForegroundColor Green
            Write-Host "Starting DISM of drivers while Offline" -ForegroundColor Green
            $DismPath = "$env:windir\System32\Dism.exe"
            $DismProcess = Start-Process -FilePath $DismPath -ArgumentList "/image:c:\ /Add-Driver /driver:$($DriverPath) /recurse" -Wait -PassThru
            Write-Host "Finished Process with Exit Code: $($DismProcess.ExitCode)"
        }
    }
    else {
        Write-Output "Skipping Run-DISMFromOSDCloudUSB Function, not running in WinPE"
    }
}

Write-Host -ForegroundColor Green "[+] Function Disable-CloudContent"
Function Disable-CloudContent {
    New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name "CloudContent" -Force | out-null
    New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent -Name 'DisableWindowsConsumerFeatures' -Value 1 -PropertyType Dword -Force | out-null
    New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent -Name 'DisableSoftLanding' -Value 1 -PropertyType Dword -Force | out-null
    New-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent -Name 'DisableCloudOptimizedContent' -Value 1 -PropertyType Dword -Force | out-null
}

Write-Host -ForegroundColor Green "[+] Set-Win11ReqBypassRegValues"
Function Set-Win11ReqBypassRegValues {
    if ($env:SystemDrive -eq 'X:') {
    $WindowsPhase = 'WinPE'
    }
    else {
        $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
        if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
        else {$WindowsPhase = 'Windows'}
    }
    
    if ($WindowsPhase -eq 'WinPE'){
        #Insipiration & Some code from: https://github.com/JosephM101/Force-Windows-11-Install/blob/main/Win11-TPM-RegBypass.ps1
    
        # Mount and edit the setup environment's registry
        $REG_System = "C:\Windows\System32\config\system"
        $VirtualRegistryPath_SYSTEM = "HKLM\WinPE_SYSTEM" #Load Command
        $VirtualRegistryPath_Setup = "HKLM:\WinPE_SYSTEM\Setup" #PowerShell Path

        # $VirtualRegistryPath_LabConfig = $VirtualRegistryPath_Setup + "\LabConfig"
        reg unload $VirtualRegistryPath_SYSTEM | Out-Null # Just in case...
        Start-Sleep 1
        reg load $VirtualRegistryPath_SYSTEM $REG_System | Out-Null


       
        New-Item -Path $VirtualRegistryPath_Setup -Name "LabConfig" -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassTPMCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassSecureBootCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassRAMCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassStorageCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\LabConfig" -Name "BypassCPUCheck" -Value 1 -PropertyType DWORD -Force | out-null

        New-Item -Path $VirtualRegistryPath_Setup -Name "MoSetup" -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path "$VirtualRegistryPath_Setup\MoSetup" -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -PropertyType DWORD -Force | out-null


        Start-Sleep 1
        reg unload $VirtualRegistryPath_SYSTEM
    }
    else {
        if (!(Test-Path -Path HKLM:\SYSTEM\Setup\LabConfig)){
            New-Item -Path HKLM:\SYSTEM\Setup -Name "LabConfig" | out-null
        }
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassTPMCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassSecureBootCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassRAMCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassStorageCheck" -Value 1 -PropertyType DWORD -Force | out-null
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassCPUCheck" -Value 1 -PropertyType DWORD -Force | out-null
        if (!(Test-Path -Path HKLM:\SYSTEM\Setup\MoSetup)){
            New-Item -Path HKLM:\SYSTEM\Setup -Name "MoSetup" | out-null
        }
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\MoSetup" -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -PropertyType DWORD -Force | out-null
    }
}

Write-Host -ForegroundColor Green "[+] Start-WindowsUpdate"
function Start-WindowsUpdate{
    <# Control Windows Update via PowerShell
    Gary Blok - GARYTOWN.COM
    NOTE: I'm using this in a RUN SCRIPT, so I hav the Parameters set to STRING, and in the RUN SCRIPT, I Create a list of options (TRUE & FALSE).
    In a normal script, you wouldn't do this... so modify for your deployment method.

    This was also intended to be used with ConfigMgr, if you're not, feel free to remove the $CMReboot & Corrisponding Function

    Installing Updates using this Method does NOT notify the user, and does NOT let the user know that updates need to be applied at the next reboot.  It's 100% hidden.

    HResult Lookup: https://docs.microsoft.com/en-us/windows/win32/wua_sdk/wua-success-and-error-codes-

    #>

    $Results = @(
    @{ ResultCode = '0'; Meaning = "Not Started"}
    @{ ResultCode = '1'; Meaning = "In Progress"}
    @{ ResultCode = '2'; Meaning = "Succeeded"}
    @{ ResultCode = '3'; Meaning = "Succeeded With Errors"}
    @{ ResultCode = '4'; Meaning = "Failed"}
    @{ ResultCode = '5'; Meaning = "Aborted"}
    @{ ResultCode = '6'; Meaning = "No Updates Found"}
    )


    $WUDownloader=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
    $WUInstaller=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
    $WUUpdates=New-Object -ComObject Microsoft.Update.UpdateColl
    ((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search("IsInstalled=0 and Type='Software'")).Updates|%{
        if(!$_.EulaAccepted){$_.EulaAccepted=$true}
        if ($_.Title -notmatch "Preview"){[void]$WUUpdates.Add($_)}
    }

    if ($WUUpdates.Count -ge 1){
        $WUInstaller.ForceQuiet=$true
        $WUInstaller.Updates=$WUUpdates
        $WUDownloader.Updates=$WUUpdates
        $UpdateCount = $WUDownloader.Updates.count
        if ($UpdateCount -ge 1){
            Write-Output "Downloading $UpdateCount Updates"
            foreach ($update in $WUInstaller.Updates){Write-Output "$($update.Title)"}
            $Download = $WUDownloader.Download()
        }
        $InstallUpdateCount = $WUInstaller.Updates.count
        if ($InstallUpdateCount -ge 1){
            Write-Output "Installing $InstallUpdateCount Updates"
            $Install = $WUInstaller.Install()
            $ResultMeaning = ($Results | Where-Object {$_.ResultCode -eq $Install.ResultCode}).Meaning
            Write-Output $ResultMeaning
        } 
    }
    else {Write-Output "No Updates Found"} 
}

Write-Host -ForegroundColor Green "[+] Start-WindowsUpdateDriver"
function Start-WindowsUpdateDriver{
    <# Control Windows Update via PowerShell
    Gary Blok - GARYTOWN.COM
    NOTE: I'm using this in a RUN SCRIPT, so I hav the Parameters set to STRING, and in the RUN SCRIPT, I Create a list of options (TRUE & FALSE).
    In a normal script, you wouldn't do this... so modify for your deployment method.

    This was also intended to be used with ConfigMgr, if you're not, feel free to remove the $CMReboot & Corrisponding Function

    Installing Updates using this Method does NOT notify the user, and does NOT let the user know that updates need to be applied at the next reboot.  It's 100% hidden.

    HResult Lookup: https://docs.microsoft.com/en-us/windows/win32/wua_sdk/wua-success-and-error-codes-

    #>

    $Results = @(
    @{ ResultCode = '0'; Meaning = "Not Started"}
    @{ ResultCode = '1'; Meaning = "In Progress"}
    @{ ResultCode = '2'; Meaning = "Succeeded"}
    @{ ResultCode = '3'; Meaning = "Succeeded With Errors"}
    @{ ResultCode = '4'; Meaning = "Failed"}
    @{ ResultCode = '5'; Meaning = "Aborted"}
    @{ ResultCode = '6'; Meaning = "No Updates Found"}
    )


    $WUDownloader=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateDownloader()
    $WUInstaller=(New-Object -ComObject Microsoft.Update.Session).CreateUpdateInstaller()
    $WUUpdates=New-Object -ComObject Microsoft.Update.UpdateColl
    ((New-Object -ComObject Microsoft.Update.Session).CreateupdateSearcher().Search("IsInstalled=0 and Type='Driver'")).Updates|%{
        if(!$_.EulaAccepted){$_.EulaAccepted=$true}
        if ($_.Title -notmatch "Preview"){[void]$WUUpdates.Add($_)}
    }

    if ($WUUpdates.Count -ge 1){
        $WUInstaller.ForceQuiet=$true
        $WUInstaller.Updates=$WUUpdates
        $WUDownloader.Updates=$WUUpdates
        $UpdateCount = $WUDownloader.Updates.count
        if ($UpdateCount -ge 1){
            Write-Output "Downloading $UpdateCount Updates"
            foreach ($update in $WUInstaller.Updates){Write-Output "$($update.Title)"}
            $Download = $WUDownloader.Download()
        }
        $InstallUpdateCount = $WUInstaller.Updates.count
        if ($InstallUpdateCount -ge 1){
            Write-Output "Installing $InstallUpdateCount Updates"
            $Install = $WUInstaller.Install()
            $ResultMeaning = ($Results | Where-Object {$_.ResultCode -eq $Install.ResultCode}).Meaning
            Write-Output $ResultMeaning
        } 
    }
    else {Write-Output "No Updates Found"} 
}

Write-Host -ForegroundColor Green "[+] Enable-AutoZimeZoneUpdate"
Function Enable-AutoZimeZoneUpdate {

    if ($env:SystemDrive -eq 'X:') {
    $WindowsPhase = 'WinPE'
    }
    else {
        $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
        if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
        elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
        else {$WindowsPhase = 'Windows'}
    }
    
    if ($WindowsPhase -eq 'WinPE'){
    
        # Mount and edit the setup environment's registry
        $REG_System = "C:\Windows\System32\config\system"
        $REG_Software = "C:\Windows\system32\config\SOFTWARE"
        $VirtualRegistryPath_SYSTEM = "HKLM\WinPE_SYSTEM"#Load Command
        $VirtualRegistryPath_SOFTWARE = "HKLM\WinPE_SOFTWARE"#Load Command
        $VirtualRegistryPath_tzautoupdate = "HKLM:\WinPE_SYSTEM\CurrentControlSet\Services\tzautoupdate" #PowerShell Path
        $VirtualRegistryPath_location = "HKLM:\WinPE_SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"#PowerShell Path

        # $VirtualRegistryPath_LabConfig = $VirtualRegistryPath_Setup + "\LabConfig"
        reg unload $VirtualRegistryPath_SYSTEM | Out-Null # Just in case...
        reg unload $VirtualRegistryPath_SOFTWARE | Out-Null # Just in case...
        Start-Sleep 1
        reg load $VirtualRegistryPath_SYSTEM $REG_System | Out-Null
        reg load $VirtualRegistryPath_SOFTWARE $REG_Software | Out-Null

        New-ItemProperty -Path $VirtualRegistryPath_location -Name "Value" -Value "Allow" -PropertyType String -Force
        New-ItemProperty -Path $VirtualRegistryPath_tzautoupdate -Name "start" -Value 3 -PropertyType DWord -Force



        Start-Sleep 1
        reg unload $VirtualRegistryPath_SYSTEM
        reg unload $VirtualRegistryPath_SOFTWARE
    }
    else {
        Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location -Name Value -Value "Allow" -Type String | out-null
        Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate -Name start -Value "3" -Type DWord | out-null
    }
}
Write-Host -ForegroundColor Green "[+] Set-DefaultProfilePersonalPref"
function Set-DefaultProfilePersonalPref {
    #Set Default User Profile to MY PERSONAL preferences.

    $REG_defaultuser = "c:\users\default\ntuser.dat"
    $VirtualRegistryPath_defaultuser = "HKLM\DefUser" #Load Command
    $VirtualRegistryPath_software = "HKLM:\DefUser\Software" #PowerShell Path

    reg unload $VirtualRegistryPath_defaultuser | Out-Null # Just in case...
    Start-Sleep 1
    reg load $VirtualRegistryPath_defaultuser $REG_defaultuser | Out-Null

    #TaskBar Left / Hide Chat / Hide Widgets / Hide TaskView
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    New-ItemProperty -Path $Path -Name "TaskbarAl" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "TaskbarMn" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "TaskbarDa" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "ShowTaskViewButton" -Value 0 -PropertyType Dword -Force | Out-Null

    #Disable Content Delivery
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    New-ItemProperty -Path $Path -Name "SystemPaneSuggestionsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SubscribedContentEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SoftLandingEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SilentInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "PreInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "OemPreInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "FeatureManagementEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "ContentDeliveryAllowed" -Value 0 -PropertyType Dword -Force | Out-Null

    reg unload $VirtualRegistryPath_defaultuser | Out-Null
}
function Set-APEnterprise {
    Install-script -name Get-WindowsAutoPilotInfo -Force
    Set-ExecutionPolicy Bypass -Force
    Get-WindowsAutopilotInfo -Online -GroupTag Enterprise -Assign
}
