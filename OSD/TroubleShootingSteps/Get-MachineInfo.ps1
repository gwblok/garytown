<# Gary Blok - @gwblok - GARYTOWN.COM

Get-MachineInfo

This script is designed to grab basic info about a machine.
Note, Network Status for VPN might not work with your VPN software, tested with Pulse & Global Protect.

I'm using it as a Run Script to get information from devices over CMG, as I can't connect to them via Remote PowerShell.


22.10.25 - Added SafeGuard & Win11 Check
22.10.31 - Added Serial
25.5.12 - Adopted for Task Sequence PowerShell Step
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [String]$logPath = "C:\Windows\Temp"
)

function Get-MachineInfo {
Function Test-PendingReboot {
    #Pending Reboot From Adam, and I added the part for ConfigMgr
    #https://adamtheautomator.com/pending-reboot-registry/
    function Test-RegistryKey {
            [OutputType('bool')]
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Key
            )
    
            $ErrorActionPreference = 'Stop'

            if (Get-Item -Path $Key -ErrorAction Ignore) {
                $true
            }
        }

        function Test-RegistryValue {
            [OutputType('bool')]
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Key,

                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Value
            )
    
            $ErrorActionPreference = 'Stop'

            if (Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) {
                $true
            }
        }

        function Test-RegistryValueNotNull {
            [OutputType('bool')]
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Key,

                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Value
            )
    
            $ErrorActionPreference = 'Stop'

            if (($regVal = Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) -and $regVal.($Value)) {
                $true
            }
        }

    $tests = @(
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' }
            { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress' }
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' }
            { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending' }
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting' }
            #{ Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations' }
            #{ Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations2' }
            { 
                # Added test to check first if key exists, using "ErrorAction ignore" will incorrectly return $true
                'HKLM:\SOFTWARE\Microsoft\Updates' | Where-Object { test-path $_ -PathType Container } | ForEach-Object {            
                    (Get-ItemProperty -Path $_ -Name 'UpdateExeVolatile' -ErrorAction Ignore | Select-Object -ExpandProperty UpdateExeVolatile) -ne 0 
                }
            }
            { Test-RegistryValue -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Value 'DVDRebootSignal' }
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttemps' }
            { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'JoinDomain' }
            { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'AvoidSpnSet' }
            {
                # Added test to check first if keys exists, if not each group will return $Null
                # May need to evaluate what it means if one or both of these keys do not exist
                ( 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' | Where-Object { test-path $_ } | %{ (Get-ItemProperty -Path $_ ).ComputerName } ) -ne 
                ( 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' | Where-Object { Test-Path $_ } | %{ (Get-ItemProperty -Path $_ ).ComputerName } )
            }
            {
                # Added test to check first if key exists
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending' | Where-Object { 
                    (Test-Path $_) -and (Get-ChildItem -Path $_) } | ForEach-Object { $true }
            }
        )


    foreach ($test in $tests) {
	    if (& $test) {
		    $WindowsPendingReboot = "Windows"
            #Write-Output "Windows Pending Reboot: $true"
            #Write-Output $test
	    }
    }
    try {
        if (Get-Service -Name CcmExec -ErrorAction SilentlyContinue){
            if ((Invoke-WmiMethod -Namespace 'root\ccm\ClientSDK' -Class CCM_ClientUtilities -Name DetermineIfRebootPending).RebootPending -eq "true" ){
            $CMPendingReboot = "ConfigMgr"
            #Write-Output "CM Pending Reboot $true"
            }
        }
    }
    catch {}
    if ($CMPendingReboot -or $WindowsPendingReboot){
        if ($CMPendingReboot){
            $CMPendingReboot
        }
        if ($WindowsPendingReboot){
            $WindowsPendingReboot
        }
    }
    else {Write-Output "False"}
}
Function Convert-FromUnixDate ($UnixDate) {
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixDate))
}
Function Get-TPMVer {

$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
if ($Manufacturer -match "HP")
    {
    if ($((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion) -match "1.2")
        {
        $versionInfo = (Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersionInfo
        $verMaj      = [Convert]::ToInt32($versionInfo[0..1] -join '', 16)
        $verMin      = [Convert]::ToInt32($versionInfo[2..3] -join '', 16)
        $verBuild    = [Convert]::ToInt32($versionInfo[4..6] -join '', 16)
        $verRevision = 0
        [version]$ver = "$verMaj`.$verMin`.$verBuild`.$verRevision"
        Write-Output "TPM Verion: $ver | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"
        }
    else {Write-Output "TPM Verion: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersion) | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"}
    }

else
    {
    if ($((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion) -match "1.2")
        {
        Write-Output "TPM Verion: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersion) | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"
        }
    else {Write-Output "TPM Verion: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).ManufacturerVersion) | Spec: $((Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM).SpecVersion)"}
    }
}

<#
Modified for OSD by @gwblok



Changes
2022.01.28
    - Changed Get-TPM to using Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM
2022.07.01 
    - Modified for OSDCloud

#>

#=============================================================================================================================
#
#
# Script Name:     HardwareReadiness.ps1
# Description:     Verifies the hardware compliance. Return code 0 for success. 
#                  In case of failure, returns non zero error code along with error message.

# This script is not supported under any Microsoft standard support program or service and is distributed under the MIT license

# Copyright (C) 2021 Microsoft Corporation

# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
# modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software
# is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#=============================================================================================================================


$exitCode = 0

[int]$MinOSDiskSizeGB = 64
[int]$MinMemoryGB = 4
[Uint32]$MinClockSpeedMHz = 1000
[Uint32]$MinLogicalCores = 2
[Uint16]$RequiredAddressWidth = 64

$PASS_STRING = "PASS"
$FAIL_STRING = "FAIL"
$FAILED_TO_RUN_STRING = "FAILED TO RUN"
$UNDETERMINED_CAPS_STRING = "UNDETERMINED"
$UNDETERMINED_STRING = "Undetermined"
$CAPABLE_STRING = "Capable"
$NOT_CAPABLE_STRING = "Not capable"
$CAPABLE_CAPS_STRING = "CAPABLE"
$NOT_CAPABLE_CAPS_STRING = "NOT CAPABLE"
$STORAGE_STRING = "Storage"
$OS_DISK_SIZE_STRING = "OSDiskSize"
$MEMORY_STRING = "Memory"
$SYSTEM_MEMORY_STRING = "System_Memory"
$GB_UNIT_STRING = "GB"
$TPM_STRING = "TPM"
$TPM_VERSION_STRING = "TPMVersion"
$PROCESSOR_STRING = "Processor"
$SECUREBOOT_STRING = "SecureBoot"
$I7_7820HQ_CPU_STRING = "i7-7820hq CPU"

# 0=name of check, 1=attribute checked, 2=value, 3=PASS/FAIL/UNDETERMINED
$logFormat = '{0}: {1}={2}. {3}; '

# 0=name of check, 1=attribute checked, 2=value, 3=unit of the value, 4=PASS/FAIL/UNDETERMINED
$logFormatWithUnit = '{0}: {1}={2}{3}. {4}; '

# 0=name of check.
$logFormatReturnReason = '{0}, '

# 0=exception.
$logFormatException = '{0}; '

# 0=name of check, 1= attribute checked and its value, 2=PASS/FAIL/UNDETERMINED
$logFormatWithBlob = '{0}: {1}. {2}; '

# return returnCode is -1 when an exception is thrown. 1 if the value does not meet requirements. 0 if successful. -2 default, script didn't run.
$outObject = @{ returnCode = -2; returnResult = $FAILED_TO_RUN_STRING; returnReason = ""; logging = "" }

# NOT CAPABLE(1) state takes precedence over UNDETERMINED(-1) state
function Private:UpdateReturnCode {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(-2, 1)]
        [int] $ReturnCode
    )

    Switch ($ReturnCode) {

        0 {
            if ($outObject.returnCode -eq -2) {
                $outObject.returnCode = $ReturnCode
            }
        }
        1 {
            $outObject.returnCode = $ReturnCode
        }
        -1 {
            if ($outObject.returnCode -ne 1) {
                $outObject.returnCode = $ReturnCode
            }
        }
    }
}

$Source = @"
using Microsoft.Win32;
using System;
using System.Runtime.InteropServices;

    public class CpuFamilyResult
    {
        public bool IsValid { get; set; }
        public string Message { get; set; }
    }

    public class CpuFamily
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct SYSTEM_INFO
        {
            public ushort ProcessorArchitecture;
            ushort Reserved;
            public uint PageSize;
            public IntPtr MinimumApplicationAddress;
            public IntPtr MaximumApplicationAddress;
            public IntPtr ActiveProcessorMask;
            public uint NumberOfProcessors;
            public uint ProcessorType;
            public uint AllocationGranularity;
            public ushort ProcessorLevel;
            public ushort ProcessorRevision;
        }

        [DllImport("kernel32.dll")]
        internal static extern void GetNativeSystemInfo(ref SYSTEM_INFO lpSystemInfo);

        public enum ProcessorFeature : uint
        {
            ARM_SUPPORTED_INSTRUCTIONS = 34
        }

        [DllImport("kernel32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        static extern bool IsProcessorFeaturePresent(ProcessorFeature processorFeature);

        private const ushort PROCESSOR_ARCHITECTURE_X86 = 0;
        private const ushort PROCESSOR_ARCHITECTURE_ARM64 = 12;
        private const ushort PROCESSOR_ARCHITECTURE_X64 = 9;

        private const string INTEL_MANUFACTURER = "GenuineIntel";
        private const string AMD_MANUFACTURER = "AuthenticAMD";
        private const string QUALCOMM_MANUFACTURER = "Qualcomm Technologies Inc";

        public static CpuFamilyResult Validate(string manufacturer, ushort processorArchitecture)
        {
            CpuFamilyResult cpuFamilyResult = new CpuFamilyResult();

            if (string.IsNullOrWhiteSpace(manufacturer))
            {
                cpuFamilyResult.IsValid = false;
                cpuFamilyResult.Message = "Manufacturer is null or empty";
                return cpuFamilyResult;
            }

            string registryPath = "HKEY_LOCAL_MACHINE\\Hardware\\Description\\System\\CentralProcessor\\0";
            SYSTEM_INFO sysInfo = new SYSTEM_INFO();
            GetNativeSystemInfo(ref sysInfo);

            switch (processorArchitecture)
            {
                case PROCESSOR_ARCHITECTURE_ARM64:

                    if (manufacturer.Equals(QUALCOMM_MANUFACTURER, StringComparison.OrdinalIgnoreCase))
                    {
                        bool isArmv81Supported = IsProcessorFeaturePresent(ProcessorFeature.ARM_SUPPORTED_INSTRUCTIONS);

                        if (!isArmv81Supported)
                        {
                            string registryName = "CP 4030";
                            long registryValue = (long)Registry.GetValue(registryPath, registryName, -1);
                            long atomicResult = (registryValue >> 20) & 0xF;

                            if (atomicResult >= 2)
                            {
                                isArmv81Supported = true;
                            }
                        }

                        cpuFamilyResult.IsValid = isArmv81Supported;
                        cpuFamilyResult.Message = isArmv81Supported ? "" : "Processor does not implement ARM v8.1 atomic instruction";
                    }
                    else
                    {
                        cpuFamilyResult.IsValid = false;
                        cpuFamilyResult.Message = "The processor isn't currently supported for Windows 11";
                    }

                    break;

                case PROCESSOR_ARCHITECTURE_X64:
                case PROCESSOR_ARCHITECTURE_X86:

                    int cpuFamily = sysInfo.ProcessorLevel;
                    int cpuModel = (sysInfo.ProcessorRevision >> 8) & 0xFF;
                    int cpuStepping = sysInfo.ProcessorRevision & 0xFF;

                    if (manufacturer.Equals(INTEL_MANUFACTURER, StringComparison.OrdinalIgnoreCase))
                    {
                        try
                        {
                            cpuFamilyResult.IsValid = true;
                            cpuFamilyResult.Message = "";

                            if (cpuFamily >= 6 && cpuModel <= 95 && !(cpuFamily == 6 && cpuModel == 85))
                            {
                                cpuFamilyResult.IsValid = false;
                                cpuFamilyResult.Message = "";
                            }
                            else if (cpuFamily == 6 && (cpuModel == 142 || cpuModel == 158) && cpuStepping == 9)
                            {
                                string registryName = "Platform Specific Field 1";
                                int registryValue = (int)Registry.GetValue(registryPath, registryName, -1);

                                if ((cpuModel == 142 && registryValue != 16) || (cpuModel == 158 && registryValue != 8))
                                {
                                    cpuFamilyResult.IsValid = false;
                                }
                                cpuFamilyResult.Message = "PlatformId " + registryValue;
                            }
                        }
                        catch (Exception ex)
                        {
                            cpuFamilyResult.IsValid = false;
                            cpuFamilyResult.Message = "Exception:" + ex.GetType().Name;
                        }
                    }
                    else if (manufacturer.Equals(AMD_MANUFACTURER, StringComparison.OrdinalIgnoreCase))
                    {
                        cpuFamilyResult.IsValid = true;
                        cpuFamilyResult.Message = "";

                        if (cpuFamily < 23 || (cpuFamily == 23 && (cpuModel == 1 || cpuModel == 17)))
                        {
                            cpuFamilyResult.IsValid = false;
                        }
                    }
                    else
                    {
                        cpuFamilyResult.IsValid = false;
                        cpuFamilyResult.Message = "Unsupported Manufacturer: " + manufacturer + ", Architecture: " + processorArchitecture + ", CPUFamily: " + sysInfo.ProcessorLevel + ", ProcessorRevision: " + sysInfo.ProcessorRevision;
                    }

                    break;

                default:
                    cpuFamilyResult.IsValid = false;
                    cpuFamilyResult.Message = "Unsupported CPU category. Manufacturer: " + manufacturer + ", Architecture: " + processorArchitecture + ", CPUFamily: " + sysInfo.ProcessorLevel + ", ProcessorRevision: " + sysInfo.ProcessorRevision;
                    break;
            }
            return cpuFamilyResult;
        }
    }
"@

# Storage
try {

    if ($InWinPE){
        $osDrive = Get-Disk -Number 0
        $osDriveSize = $osDrive | Select-Object @{Name = "SizeGB"; Expression = { $_.Size / 1GB -as [int] } } 
        }
    else {
        $osDrive = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -Property SystemDrive
        $osDriveSize = Get-WmiObject -Class Win32_LogicalDisk -filter "DeviceID='$($osDrive.SystemDrive)'" | Select-Object @{Name = "SizeGB"; Expression = { $_.Size / 1GB -as [int] } } 
        }

    if ($null -eq $osDriveSize) {
        UpdateReturnCode -ReturnCode 1
        $outObject.returnReason += $logFormatReturnReason -f $STORAGE_STRING
        $outObject.logging += $logFormatWithBlob -f $STORAGE_STRING, "Storage is null", $FAIL_STRING
        $exitCode = 1
        $HR_Storage = $FAIL_STRING
    }
    elseif ($osDriveSize.SizeGB -lt $MinOSDiskSizeGB) {
        UpdateReturnCode -ReturnCode 1
        $outObject.returnReason += $logFormatReturnReason -f $STORAGE_STRING
        $outObject.logging += $logFormatWithUnit -f $STORAGE_STRING, $OS_DISK_SIZE_STRING, ($osDriveSize.SizeGB), $GB_UNIT_STRING, $FAIL_STRING
        $exitCode = 1
        $HR_Storage = $FAIL_STRING
    }
    else {
        $outObject.logging += $logFormatWithUnit -f $STORAGE_STRING, $OS_DISK_SIZE_STRING, ($osDriveSize.SizeGB), $GB_UNIT_STRING, $PASS_STRING
        UpdateReturnCode -ReturnCode 0
        $HR_Storage = $PASS_STRING
    }
}
catch {
    UpdateReturnCode -ReturnCode -1
    $outObject.logging += $logFormat -f $STORAGE_STRING, $OS_DISK_SIZE_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
    $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
    $exitCode = 1
    $HR_Storage = $FAIL_STRING
}

# Memory (bytes)
try {
    $memory = Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum | Select-Object @{Name = "SizeGB"; Expression = { $_.Sum / 1GB -as [int] } }

    if ($null -eq $memory) {
        UpdateReturnCode -ReturnCode 1
        $outObject.returnReason += $logFormatReturnReason -f $MEMORY_STRING
        $outObject.logging += $logFormatWithBlob -f $MEMORY_STRING, "Memory is null", $FAIL_STRING
        $exitCode = 1
        $HR_Memory = $FAIL_STRING

    }
    elseif ($memory.SizeGB -lt $MinMemoryGB) {
        UpdateReturnCode -ReturnCode 1
        $outObject.returnReason += $logFormatReturnReason -f $MEMORY_STRING
        $outObject.logging += $logFormatWithUnit -f $MEMORY_STRING, $SYSTEM_MEMORY_STRING, ($memory.SizeGB), $GB_UNIT_STRING, $FAIL_STRING
        $exitCode = 1
        $HR_Memory = $FAIL_STRING

    }
    else {
        $outObject.logging += $logFormatWithUnit -f $MEMORY_STRING, $SYSTEM_MEMORY_STRING, ($memory.SizeGB), $GB_UNIT_STRING, $PASS_STRING
        UpdateReturnCode -ReturnCode 0
        $HR_Memory = $PASS_STRING
    }
}
catch {
    UpdateReturnCode -ReturnCode -1
    $outObject.logging += $logFormat -f $MEMORY_STRING, $SYSTEM_MEMORY_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
    $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
    $exitCode = 1
    $HR_Memory = $FAIL_STRING
}

# TPM
try {
    if ($InWinPE){
        $tpm = Get-CimInstance -Namespace "ROOT\cimv2\Security\MicrosoftTpm" -ClassName Win32_TPM 
        }
    else {
        $tpm = Get-Tpm
        }
    
    #$tpm = Get-Tpm
    
    if ($null -eq $tpm) {
        UpdateReturnCode -ReturnCode 1
        $outObject.returnReason += $logFormatReturnReason -f $TPM_STRING
        $outObject.logging += $logFormatWithBlob -f $TPM_STRING, "TPM is null", $FAIL_STRING
        $exitCode = 1
        $HR_TPM = $FAIL_STRING
    }
    elseif ($tpm.IsOwned_InitialValue -or $tpm.TpmPresent) {
        $tpmVersion = Get-WmiObject -Class Win32_Tpm -Namespace root\CIMV2\Security\MicrosoftTpm | Select-Object -Property SpecVersion

        if ($null -eq $tpmVersion.SpecVersion) {
            UpdateReturnCode -ReturnCode 1
            $outObject.returnReason += $logFormatReturnReason -f $TPM_STRING
            $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, "null", $FAIL_STRING
            $exitCode = 1
            $HR_TPM = $FAIL_STRING
        }

        $majorVersion = $tpmVersion.SpecVersion.Split(",")[0] -as [int]
        if ($majorVersion -lt 2) {
            UpdateReturnCode -ReturnCode 1
            $outObject.returnReason += $logFormatReturnReason -f $TPM_STRING
            $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, ($tpmVersion.SpecVersion), $FAIL_STRING
            $exitCode = 1
            $HR_TPM = $FAIL_STRING
        }
        else {
            $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, ($tpmVersion.SpecVersion), $PASS_STRING
            UpdateReturnCode -ReturnCode 0
            $HR_TPM = $PASS_STRING
        }
    }
    else {
        if ($tpm.GetType().Name -eq "String") {
            UpdateReturnCode -ReturnCode -1
            $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
            $outObject.logging += $logFormatException -f $tpm
        }
        else {
            UpdateReturnCode -ReturnCode  1
            $outObject.returnReason += $logFormatReturnReason -f $TPM_STRING
            if ($InWinPE){
                $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, "NA", $FAIL_STRING
                }
            else {                
                $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, ($tpm.TpmPresent), $FAIL_STRING
                }
            $HR_TPM = $FAIL_STRING
        }
        $exitCode = 1
        $HR_TPM = $FAIL_STRING
    }
}
catch {
    UpdateReturnCode -ReturnCode -1
    $outObject.logging += $logFormat -f $TPM_STRING, $TPM_VERSION_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
    $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
    $exitCode = 1
    $HR_TPM = $FAIL_STRING
}

# CPU Details

try {
    $cpuDetails = @(Get-WmiObject -Class Win32_Processor)[0]

    if ($null -eq $cpuDetails) {
        UpdateReturnCode -ReturnCode 1
        $exitCode = 1
        $outObject.returnReason += $logFormatReturnReason -f $PROCESSOR_STRING
        $outObject.logging += $logFormatWithBlob -f $PROCESSOR_STRING, "CpuDetails is null", $FAIL_STRING
        $HR_CPU = $FAIL_STRING
    }
    else {
        $processorCheckFailed = $false

        # AddressWidth
        if ($null -eq $cpuDetails.AddressWidth -or $cpuDetails.AddressWidth -ne $RequiredAddressWidth) {
            UpdateReturnCode -ReturnCode 1
            $processorCheckFailed = $true
            $exitCode = 1
            $HR_CPU = $FAIL_STRING
        }

        # ClockSpeed is in MHz
        if ($null -eq $cpuDetails.MaxClockSpeed -or $cpuDetails.MaxClockSpeed -le $MinClockSpeedMHz) {
            UpdateReturnCode -ReturnCode 1;
            $processorCheckFailed = $true
            $exitCode = 1
            $HR_CPU = $FAIL_STRING
        }

        # Number of Logical Cores
        if ($null -eq $cpuDetails.NumberOfLogicalProcessors -or $cpuDetails.NumberOfLogicalProcessors -lt $MinLogicalCores) {
            UpdateReturnCode -ReturnCode 1
            $processorCheckFailed = $true
            $exitCode = 1
            $HR_CPU = $FAIL_STRING
        }

        # CPU Family
        Add-Type -TypeDefinition $Source
        $cpuFamilyResult = [CpuFamily]::Validate([String]$cpuDetails.Manufacturer, [uint16]$cpuDetails.Architecture)

        $cpuDetailsLog = "{AddressWidth=$($cpuDetails.AddressWidth); MaxClockSpeed=$($cpuDetails.MaxClockSpeed); NumberOfLogicalCores=$($cpuDetails.NumberOfLogicalProcessors); Manufacturer=$($cpuDetails.Manufacturer); Caption=$($cpuDetails.Caption); $($cpuFamilyResult.Message)}"

        if (!$cpuFamilyResult.IsValid) {
            UpdateReturnCode -ReturnCode 1
            $processorCheckFailed = $true
            $exitCode = 1
            $HR_CPU = $FAIL_STRING
        }

        if ($processorCheckFailed) {
            $outObject.returnReason += $logFormatReturnReason -f $PROCESSOR_STRING
            $outObject.logging += $logFormatWithBlob -f $PROCESSOR_STRING, ($cpuDetailsLog), $FAIL_STRING
            $HR_CPU = $FAIL_STRING
        }
        else {
            $outObject.logging += $logFormatWithBlob -f $PROCESSOR_STRING, ($cpuDetailsLog), $PASS_STRING
            UpdateReturnCode -ReturnCode 0
            $HR_CPU = $PASS_STRING
        }
    }
}
catch {
    UpdateReturnCode -ReturnCode -1
    $outObject.logging += $logFormat -f $PROCESSOR_STRING, $PROCESSOR_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
    $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
    $exitCode = 1
    $HR_CPU = $FAIL_STRING
}

# SecureBoot
try {
    $isSecureBootEnabled = Confirm-SecureBootUEFI
    $outObject.logging += $logFormatWithBlob -f $SECUREBOOT_STRING, $CAPABLE_STRING, $PASS_STRING
    UpdateReturnCode -ReturnCode 0
    $HR_SecureBoot = $PASS_STRING
}
catch [System.PlatformNotSupportedException] {
    # PlatformNotSupportedException "Cmdlet not supported on this platform." - SecureBoot is not supported or is non-UEFI computer.
    UpdateReturnCode -ReturnCode 1
    $outObject.returnReason += $logFormatReturnReason -f $SECUREBOOT_STRING
    $outObject.logging += $logFormatWithBlob -f $SECUREBOOT_STRING, $NOT_CAPABLE_STRING, $FAIL_STRING
    $exitCode = 1
    $HR_SecureBoot = $FAIL_STRING
}
catch [System.UnauthorizedAccessException] {
    UpdateReturnCode -ReturnCode -1
    $outObject.logging += $logFormatWithBlob -f $SECUREBOOT_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
    $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
    $exitCode = 1
    $HR_SecureBoot = $FAIL_STRING
}
catch {
    UpdateReturnCode -ReturnCode -1
    $outObject.logging += $logFormatWithBlob -f $SECUREBOOT_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
    $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
    $exitCode = 1
    $HR_SecureBoot = $FAIL_STRING
}

# i7-7820hq CPU
try {
    $supportedDevices = @('surface studio 2', 'precision 5520')
    $systemInfo = @(Get-WmiObject -Class Win32_ComputerSystem)[0]

    if ($null -ne $cpuDetails) {
        if ($cpuDetails.Name -match 'i7-7820hq cpu @ 2.90ghz'){
            $modelOrSKUCheckLog = $systemInfo.Model.Trim()
            if ($supportedDevices -contains $modelOrSKUCheckLog){
                $outObject.logging += $logFormatWithBlob -f $I7_7820HQ_CPU_STRING, $modelOrSKUCheckLog, $PASS_STRING
                $outObject.returnCode = 0
                $exitCode = 0
            }
        }
    }
}
catch {
    if ($outObject.returnCode -ne 0){
        UpdateReturnCode -ReturnCode -1
        $outObject.logging += $logFormatWithBlob -f $I7_7820HQ_CPU_STRING, $UNDETERMINED_STRING, $UNDETERMINED_CAPS_STRING
        $outObject.logging += $logFormatException -f "$($_.Exception.GetType().Name) $($_.Exception.Message)"
        $exitCode = 1
    }
}

Switch ($outObject.returnCode) {

    0 { $outObject.returnResult = $CAPABLE_CAPS_STRING }
    1 { $outObject.returnResult = $NOT_CAPABLE_CAPS_STRING }
    -1 { $outObject.returnResult = $UNDETERMINED_CAPS_STRING }
    -2 { $outObject.returnResult = $FAILED_TO_RUN_STRING }
}

$Global:Readiness = $null
$Global:Readiness = [ordered]@{
Return = $null
Reason = $null
SecureBoot = $null
CPU = $null
TPM = $null
Memory = $null
Storage = $null
}


$BIOSInfo = Get-WmiObject -Class 'Win32_Bios'

# Get the current BIOS release date and format it to datetime
$CurrentBIOSDate = [System.Management.ManagementDateTimeConverter]::ToDatetime($BIOSInfo.ReleaseDate).ToUniversalTime()

$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
$ManufacturerBaseBoard = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Manufacturer
$ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model
if ($ManufacturerBaseBoard -eq "Intel Corporation")
    {
    $ComputerModel = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
    }
$HPProdCode = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
$Serial = (Get-WmiObject -class:win32_bios).SerialNumber
$cpuDetails = @(Get-WmiObject -Class Win32_Processor)[0]

Write-Output "Computer Name: $env:computername"
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$InstallDate_CurrentOS = Convert-FromUnixDate $CurrentOSInfo.GetValue('InstallDate')
$WindowsRelease = $CurrentOSInfo.GetValue('ReleaseId')
if ($WindowsRelease -eq "2009"){$WindowsRelease = $CurrentOSInfo.GetValue('DisplayVersion')}
$BuildUBR_CurrentOS = $($CurrentOSInfo.GetValue('CurrentBuild'))+"."+$($CurrentOSInfo.GetValue('UBR'))
Write-Output "Windows $WindowsRelease | $BuildUBR_CurrentOS | Installed: $InstallDate_CurrentOS"
$LastReboot = (Get-CimInstance -ClassName win32_operatingsystem).lastbootuptime
if ($LastReboot)
    {
    Write-Output "Last Reboot: $LastReboot"
    $RebootTimeDiff = (get-date) - $LastReboot
    $RebootTimeDiffHours = $RebootTimeDiff.TotalHours
    $RebootTimeDiffHoursRound = ([Math]::Round($RebootTimeDiffHours,2))
    
    if ($RebootTimeDiffHoursRound -lt 48)
        {
        Write-Output "Last Reboot $RebootTimeDiffHoursRound Hours ago"
        }
    Else
        {
        $RebootTimeDiffDays = $RebootTimeDiff.TotalDays
        $RebootTimeDiffdaysRound = ([Math]::Round($RebootTimeDiffDays,2))
        Write-Output "Last Reboot $RebootTimeDiffdaysRound days ago"
        }
    }
$PendingReboot = Test-PendingReboot
Write-Output "Pending Reboot: $PendingReboot"
try #Use WMI
    {
    $Loggedon = Get-WmiObject -ComputerName $env:COMPUTERNAME -Class Win32_Computersystem | Select-Object UserName
    $Domain,$User = $Loggedon.Username.split('\',2)
    Write-Output "Logged on User: $User"
    }
catch
    {
    Write-Output "No CONSOLE Logged on User"
    $NoConsoleUser = $True
    }

try #Use Explorer
    {
    $Users = (Get-Process -Name explorer -IncludeUserName -ErrorAction SilentlyContinue).UserName
    $LoggedOnUsers = $Null
    foreach ($User in $Users)
        {
        $UserAccount = ($User).split("\")[1]
        $LoggedOnUsers += "$($UserAccount), "
        }
    $LoggedOnUsers = $LoggedOnUsers.Substring(0,$LoggedOnUsers.Length-2)
    if ($NoConsoleUser){Write-Output "Logged on RDP User: $LoggedOnUsers"}
    }
catch
    {
    Write-Output "No Logged on User (RDP)"
    }

Write-Output "Computer Model: $ComputerModel"
Write-Output "Serial: $Serial"
if ($Manufacturer -like "H*"){Write-Output "Computer Product Code: $HPProdCode"}
Write-Output $cpuDetails.Name
Write-Output "Current BIOS Level: $($BIOSInfo.SMBIOSBIOSVersion) From Date: $CurrentBIOSDate"
Get-TPMVer
$TimeUTC = [System.DateTime]::UtcNow
$TimeCLT = get-date
Write-Output "Current Client Time: $TimeCLT"
Write-Output "Current Client UTC: $TimeUTC"
Write-Output "Time Zone: $(Get-TimeZone)"
$Locale = Get-WinSystemLocale
if ($Locale -ne "en-US"){Write-Output "WinSystemLocale: $locale"}
Get-WmiObject win32_LogicalDisk -Filter "DeviceID='C:'" | % { $FreeSpace = $_.FreeSpace/1GB -as [int] ; $DiskSize = $_.Size/1GB -as [int] }


if (Test-Path -Path "C:\windows\ccm\ccmexec.exe"){
    #----- CM Client Cache -------------#
    $CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
    $CMCacheObjects = $CMObject.GetCacheInfo() 

    $CMCacheSizeMB = $CMCacheObjects.TotalSize
    $CMCacheSizePerent = [math]::Round((($CMCacheSizeMB / $DiskSize) * 100),0)
    $CMCacheUsedMB = $CMCacheObjects.TotalSize - $CMCacheObjects.FreeSize
    $CMCacheUsedCachePercent = [math]::Round((($CMCacheUsedMB / $CMCacheSizeMB) * 100),0)
    $CMCacheUsedDrivePercent = [math]::Round((($CMCacheUsedMB / $DiskSize) * 100),0)

    Write-Output "CMCache Info (MB): %: $CMCacheSizePerent | Max: $CMCacheSizeMB | Used: $CMCacheUsedMB | Used Cache %: $CMCacheUsedCachePercent | Used Drive %: $CMCacheUsedDrivePercent"
    #----- Branch Cache -------------#
    $BCStatus = Get-BCStatus -ErrorAction SilentlyContinue
    $BCHashCache = Get-BCHashCache -ErrorAction SilentlyContinue
    $BCDataCache = Get-BCDataCache -ErrorAction SilentlyContinue

    if ($BCStatus -ne $Null)
        {
        $BCCacheSizeMB = [math]::Round(($BCDataCache.MaxCacheSizeAsNumberOfBytes / 1MB),0)
        $BCCacheSizePercent = $BCDataCache.MaxCacheSizeAsPercentageOfDiskVolume
        $BCCacheUsedMB = [math]::Round(($BCDataCache.CurrentActiveCacheSize / 1MB),0)
        $BCCacheUsedPercent = [math]::Round((($BCCacheUsedMB / $DiskSize) * 100),0)

        $BCHashSizeMB = [math]::Round(($BCHashCache.MaxCacheSizeAsNumberOfBytes / 1MB),0)
        $BCHashSizePercent = $BCHashCache.MaxCacheSizeAsPercentageOfDiskVolume
        $BCHashUsedMB = [math]::Round(($BCHashCache.CurrentSizeOnDiskAsNumberOfBytes / 1MB),0)
        $BCHashUsedPercent

        $BCCacheComboSizeMB = $BCCacheSizeMB + $BCHashSizeMB
        $BCCacheComboSizePercent = $BCCacheSizePercent + $BCHashSizePercent 
        $BCCacheComboUsedMB = $BCCacheUsedMB + $BCHashUsedMB
        $BCCacheComboUsedCachePercent = [math]::Round((($BCCacheComboUsedMB / $BCCacheComboSizeMB) * 100),0)
        $BCCacheComboUsedDrivePercent = [math]::Round((($BCCacheComboUsedMB / $DiskSize) * 100),0)
                 

        #Write-Host "BC Info (MB): [Hash] %:$BCHashSizePercent | Max: $BCHashSizeMB | Used: $BCHashUsedMB [Cache] %: $BCCacheSizePercent | Max: $BCCacheSizeMB | Used: $BCCacheUsedMB" -ForegroundColor Green
        Write-Output "BC Info (MB): Max %: $BCCacheComboSizePercent | Max: $BCCacheComboSizeMB | Used: $BCCacheComboUsedMB | Used Cache %: $BCCacheComboUsedCachePercent | Used Drive %: $BCCacheComboUsedDrivePercent"
    }
}



Write-Output "DiskSize = $DiskSize, FreeSpace = $Freespace"
    #Get Volume Infomration
    try 
        {
        $SecureBootStatus = Confirm-SecureBootUEFI
        }
    catch {}
    if ($SecureBootStatus -eq $false -or $SecureBootStatus -eq $true)
        {
        $Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
        $SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
        $SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
        $SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
        $FreeMB = [MATH]::Round(($SystemVolume).SizeRemaining /1MB)
        if ($FreeMB -le 50)
            {
            Write-Output "Systvem Volume FreeSpace = $FreeMB MB"
            
            }
        else
            {Write-Output "Systvem Volume FreeSpace = $FreeMB MB"}
        }
    else
        {
        }

    
$MemorySize = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory/1MB)
Write-Output "Memory size = $MemorySize MB"

if (Get-WmiObject -Class win32_battery)
        {
        if ((Get-WmiObject -Class Win32_Battery –ea 0).BatteryStatus -eq 2)
            {Write-Output "Power Status: Device is on AC Power"}
        Else
            {
            Write-Output "Power Status: Device is on Battery"
            Write-Output "Power Status: Time Remaining on Battery = $((Get-WmiObject -Class win32_battery).estimatedChargeRemaining)"
            }
        }
    if ((get-WmiObject Win32_NetworkAdapterConfiguration).defaultIPGateway -ilike '0.0.0.0')
        {Write-Output "Network Status: Device is on VPN"}

#SafeGuardID
$Compliance = 'Compliant'
$UX = Get-ChildItem -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators" | Where-Object {$_.Name -notmatch "UNV"}
foreach ($U in $UX){
    $GatedBlockId = $U.GetValue('GatedBlockId')
    $GatedBlockReason = $U.GetValue('GatedBlockReason')
    $FailedPrereqs = $U.GetValue('FailedPrereqs')
    $DestBuildNum = $U.GetValue('DestBuildNum')
    $UpgEx = $U.GetValue('UpgEx')
    if ($GatedBlockId){
        if ($GatedBlockId -ne "None"){

            #$Compliance = $GatedBlockId
            $Key = $U.PSChildName
            $Compliance = "$GatedBlockId | $GatedBlockReason | $FailedPrereqs | $DestBuildNum | $UpgEx"
        }         
    }
}

Write-Output "GateBlock: $Compliance"


#Windows 11
Write-Output "Windows 11 Info"


Write-Output "Windows 11 Compatiblity: $($outObject.returnResult)"
$Global:Readiness.Return = $outObject.returnResult
if ($outObject.returnReason)
    {
    if ($outObject.returnResult -eq $NOT_CAPABLE_CAPS_STRING){
        $Reason = $outObject.returnReason
        $Reason = $Reason.Substring(0,$Reason.Length-2)
    }
    else {$Reason = $outObject.returnReason}
    Write-Output "HR_ReturnReason = $($outObject.returnReason)"
    $Global:Readiness.Reason = $Reason 
}
Write-Output "HR_SecureBoot = $HR_SecureBoot"
$Global:Readiness.SecureBoot = $HR_SecureBoot
Write-Output "HR_CPU = $HR_CPU"
$Global:Readiness.CPU = $HR_CPU
Write-Output "HR_TPM = $HR_TPM"
$Global:Readiness.TPM = $HR_TPM
Write-Output "HR_Memory = $HR_Memory"
$Global:Readiness.Memory = $HR_Memory
Write-Output "HR_Storage = $HR_Storage"
$Global:Readiness.Storage= $HR_Storage

}

#Create log directory if it doesn't exist
if (Test-Path -path $LogLocation) {
    Write-Output "Log directory already exists: $LogLocation"
} else {
    New-Item -Path $LogLocation -ItemType Directory -Force | Out-Null
    Write-Output "Created log directory: $LogLocation"
}


$Info = Get-MachineInfo
$Info | Out-File -FilePath "$logPath\MachineInfo.log" -Append -Force