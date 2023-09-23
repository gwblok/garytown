Function Inject-Win11ReqBypassRegValues {
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
        #Borrowed and then Modified from: https://github.com/JosephM101/Force-Windows-11-Install/blob/main/Win11-TPM-RegBypass.ps1
    
        # Mount and edit the setup environment's registry
        $REG_System = "C:\Windows\System32\config\system"
        $VirtualRegistryPath_SYSTEM = "HKLM\WinPE_SYSTEM"
        $VirtualRegistryPath_Setup = $VirtualRegistryPath_SYSTEM + "\Setup"
        # $VirtualRegistryPath_LabConfig = $VirtualRegistryPath_Setup + "\LabConfig"
        reg unload $VirtualRegistryPath_SYSTEM | Out-Null # Just in case...
        Start-Sleep 1
        reg load $VirtualRegistryPath_SYSTEM $REG_System | Out-Null

        Set-Location -Path Registry::$VirtualRegistryPath_Setup
       
        New-Item -Name "LabConfig"
        New-ItemProperty -Path "LabConfig" -Name "BypassTPMCheck" -Value 1 -PropertyType DWORD -Force
        New-ItemProperty -Path "LabConfig" -Name "BypassSecureBootCheck" -Value 1 -PropertyType DWORD -Force
        New-ItemProperty -Path "LabConfig" -Name "BypassRAMCheck" -Value 1 -PropertyType DWORD -Force
        New-ItemProperty -Path "LabConfig" -Name "BypassStorageCheck" -Value 1 -PropertyType DWORD -Force
        New-ItemProperty -Path "LabConfig" -Name "BypassCPUCheck" -Value 1 -PropertyType DWORD -Force

        New-Item -Name "MoSetup" -ErrorAction SilentlyContinue
        New-ItemProperty -Path "MoSetup" -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -PropertyType DWORD -Force

        Set-Location -Path $ScriptDir
        Start-Sleep 1
        reg unload $VirtualRegistryPath_SYSTEM
        # Start-Sleep 1
    }
    else {
        if (!(Test-Path -Path HKLM:\SYSTEM\Setup\LabConfig)){
            New-Item -Path HKLM:\SYSTEM\Setup -Name "LabConfig"
        }
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassTPMCheck" -Value 1 -PropertyType DWORD -Force
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassSecureBootCheck" -Value 1 -PropertyType DWORD -Force
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassRAMCheck" -Value 1 -PropertyType DWORD -Force
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassStorageCheck" -Value 1 -PropertyType DWORD -Force
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\LabConfig" -Name "BypassCPUCheck" -Value 1 -PropertyType DWORD -Force
        if (!(Test-Path -Path HKLM:\SYSTEM\Setup\MoSetup)){
            New-Item -Path HKLM:\SYSTEM\Setup -Name "MoSetup"
        }
        New-ItemProperty -Path "HKLM:\SYSTEM\Setup\MoSetup" -Name "AllowUpgradesWithUnsupportedTPMOrCPU" -Value 1 -PropertyType DWORD -Force
    }
}
