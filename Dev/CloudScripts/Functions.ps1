Function Inject-Win11ReqBypassRegValuesOffline {
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
