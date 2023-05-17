#
#  Copyright 2018-2021 HP Development Company, L.P.
#  All Rights Reserved.
#
# NOTICE:  All information contained herein is, and remains the property of HP Development Company, L.P.
#
# The intellectual and technical concepts contained herein are proprietary to HP Development Company, L.P
# and may be covered by U.S. and Foreign Patents, patents in process, and are protected by
# trade secret or copyright law. Dissemination of this information or reproduction of this material
# is strictly forbidden unless prior written permission is obtained from HP Development Company, L.P.


Set-StrictMode -Version 5.1
$ErrorActionPreference = "Stop"
#requires -Modules "HP.Private","HP.Utility"

if ($PSEdition -eq "Core") {
  Add-Type -Path "$PSScriptRoot\MSAL_4.36.2\netcoreapp2.1\Microsoft.Identity.Client.dll" -IgnoreWarnings -WarningAction SilentlyContinue
}
else {
  Add-Type -Path "$PSScriptRoot\MSAL_4.36.2\net45\Microsoft.Identity.Client.dll" -IgnoreWarnings -WarningAction SilentlyContinue
}

$msgs = @{
  0x031e = @("Sure Start found the primary BIOS in shared flash memory is either corrupted or missing.  Possible causes include but not limited to interrupted BIOS update or recent BIOS attack.",1);
  0x031f = @("Sure Start found the backup BIOS is either corrupted or missing.  Possible causes include but not limited to interrupted BIOS update.",1);
  0x0320 = @("Sure Start found shared flash memory layout is different from original factory settings.",1);
  0x0322 = @("Sure Start has recovered the primary BIOS in shared flash memory.",0);
  0x0323 = @("Sure Start has updated the backup copy of BIOS.",0);
  0x0324 = @("Sure Start found shared flash memory layout is different from original factory settings and has repaired the shared flash layout.",0);
  0x0326 = @("Sure Start found that the primary BIOS in shared flash memory on resume from Sleep is different than what system originally booted with.",0);
  0x0328 = @("Sure Start found that the 'BIOS Update Policy' setting was set to Locked but was unable to honor policy as backup copy of BIOS may be corrupted or missing.",1);
  0x032a = @("Sure Start received a command to perform a manual recovery.",0);
  0x032b = @("Sure Start integrity checking on backup copy of critical factory configured parameters failed and is no longer being used.",2);
  0x032c = @("Sure Start integrity checking on backup copy of critical network parameters data failed and is no longer being used.",2);
  0x032d = @("Sure Start integrity checking on backup copy of shared flash memory layout description failed and is no longer being used.",2);
  0x032e = @("Sure Start has found and repaired an integrity issue with saved audit logs; some logging data may have been lost.",1);
  0x032f = @("Sure Start policy settings have been corrupted and reverted to factory defaults.",1);
  0x0330 = @("System was placed in manufacturing programming mode.",1);
  0x0331 = @("System was taken out of manufacturing programming mode.",0);
  0x0332 = @("Sure Start found that backup and primary copy of BIOS do not match.",0);
  0x0333 = @("Sure Start received a request to perform a self test.",0);
  0x0334 = @("The permanent fuse in the HP Sure Start embedded controller has been modified to block the automated process that typically locks this platform to production firmware only. This should only occur on platforms that are used by HP for development purposes or exception manufacturing processes. Permanently locking this device to use production firmware only will now require a manual process.",1);
  0x0335 = @("The permanent fuse in the HP Sure Start embedded controller has been modified such that HP Sure Start will only accept HP production firmware.",0);
  0x0336 = @("A BIOS update was blocked because it did not meet the policy version requirements.",1);
  0x0337 = @("A BIOS update was blocked because it would have rolled back the current BIOS to an older BIOS which was prohibited by policy.",1);
  0x0338 = @("Runtime Verification (S0 Sure Start) has been skipped as EpSC was not able to read a correct known data back (FDT Signature).",1);

  0x801f = @("Sure Start repaired the onboard ethernet configuration data.",1);
  0x8020 = @("Sure Start has recovered the primary BIOS in shared flash memory from a copy located on flash.",1);
  0x8021 = @("Sure Start has recovered the primary BIOS in shared flash memory from a copy located on the HDD.",1);
  0x8022 = @("Sure Start has recovered the primary BIOS in shared flash memory from a copy located on a USB Key.",1);
  0x8026 = @("Sure Start has repaired machine specific data that was corrupted.",1);
  0x8028 = @("Sure Start has determined that the BIOS settings policy store has been corrupted. Recovery of the BIOS setting policy store resulted in all BIOS settings reverting to factory defaults.",2);
  0x802a = @("The BIOS received a Manual Recovery command.",1);
  0x802b = @("Sure Start detected corrupted security critical BIOS policy/data settings and recovered from the backup copy in the Sure Start private flash.",1);
  0x802c = @("HP Sure Start detected a BIOS update operation completed.",1);
  0x802d = @("Sure Start detected a problem with and corrected part of the data storage overhead related to BIOS settings. No BIOS settings were changed.",1);
  0x802e = @("Sure Start has captured a back-up copy of the boot drive partition sector (Master Boot Record or GUID Partition Table).",0);
  0x802f = @("Sure Start has recovered the boot drive partition sector (Master Boot Record or GUID Partition Table) from the Sure Start back-up copy.",1);

  0x821e = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected an unauthorized attempt to modify HP runtime firmware or disable HP runtime firmware protection mechanisms. System may be unstable until restarted.",1);
  0x821f = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected an unauthorized attempt to modify HP runtime Firmware within main (DRAM) memory. System may be unstable until restarted.",1);
  0x8220 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected an attempt to execute unauthorized code within the HP System Management Mode portion of main (DRAM) memory. System may be unstable until restarted.",1);
  0x8221 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected an attempt to access unauthorized data outside of the HP System Management Mode portion of main (DRAM) memory. System may be unstable until restarted.",1);
  0x8222 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected an attempt to execute unauthorized code outside of the HP System Management Mode portion of main (DRAM) memory. System may be unstable until restarted.",1);
  0x8223 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' test/demo more has been enabled.",1);
  0x8224 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' test/demo more has been disabled.",0);
  0x8225 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected a problem which may indicate a security problem. System may be unstable until restarted.",1);

  0x831e = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected an unauthorized change to HP runtime Firmware within main (DRAM) memory. System may be unstable until restarted.",1);
  0x831f = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected an unauthorized change to the System Management Mode Base Address (SMBASE) configuration of the CPU. System may be unstable until restarted.",1);
  0x8320 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected an unauthorized change to critical Peripheral Component Interconnect (PCI) configuration settings within the core logic. System may be unstable until restarted.",1);
  0x8321 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' stopped receiving status messages from the monitoring application. System may be unstable until restarted.",1);
  0x8322 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' received an invalid manifest describing the memory space to be monitored during runtime. Runtime Intrusion Detection is disabled for this boot.",1);
  0x8323 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has experienced a general failure of the monitoring application. System may be unstable until restarted.",1);
  0x8324 = @("Sure Start 'HP Firmware Runtime Intrusion Detection' has detected an unauthorized change to critical Memory Mapped IO configuration settings within the core logic. System may be unstable until restarted.",1);

  0x841e = @("HP Secure Platform Management successfully initialized.",0);
  0x841f = @("An HP Secure Platform Management command was received that was rejected.",1);
  0x8420 = @("HP Secure Platform Management has been unconfigured.",0);
  0x8421 = @("The HP Secure Platform Management signing key was updated.",0);
  0x8422 = @("HP Hardware Enforced Protection has been activated via an HP Secure Platform Management command.",0);
  0x8423 = @("HP Hardware Enforced Protection has been deactivated via an HP Secure Platform Management command.",0);
  0x8424 = @("A problem has been detected with the HP Hardware Enforced Protection Agent and there is no assurance that the system remains in compliance with the guidelines that were set.  The system may be unstable until restarted.",1);
  0x8425 = @("An HP Secure Platform Management command has been received instructing the HP Hardware Enforced Protection Agent to suspend compliance checking and enforcement.",1);
  0x8426 = @("An HP Secure Platform Management command has been received instructing the HP Hardware Enforced Protection Agent to resume compliance checking and enforcement.",1);
  0x8427 = @("An HP Secure Platform Management command has been received instructing the HP Hardware Enforced Protection Agent to enter recovery mode.",1);
  0x8428 = @("The platform OS recovery process was started by the firmware.",0);
  0x8429 = @("The platform OS recovery process has successfully completed.",0);
  0x842a = @("The platform OS recovery process failed to complete successfully.",0);
  0x842b = @("The OS reported that HP Hardware Enforced Protection was not reinstalled.",0);
  0x842c = @("The system processed a service event which took action.",0);
  0x842d = @("HP Sure Run detected a problem.",1);

  0x851e = @("The Sure Start Secure Boot Keys Protection feature has been enabled.",0);
  0x851f = @("The Sure Start Secure Boot Keys Protection feature has been disabled.",0);
  0x8520 = @("Sure Start determined that the Secure Boot Keys were invalid and based on the recovery policy they have NOT been repaired.",2);
  0x8521 = @("The Secure Boot Keys have been repaired at the request of the user.",0);
  0x8522 = @("Sure Start determined that the Secure Boot Keys were invalid and they have been repaired automatically based on policy.",1);
  0x8523 = @("The BIOS has been configured to globally suppress the boot time prompts used by the BIOS to prevent remote entities from performing actions without user consent.",0);
  0x8524 = @("The BIOS has been configured to allow boot time prompts used to prevent remote entities from performing actions without user consent.",0);
  0x8525 = @("Sure Start has detected the Intel Management Engine (ME) is unable to start and has initiated the recovery process using an ME recovery firmware image stored on local disk or external recovery media.",1);
  0x8526 = @("Sure Start successfully recovered the Intel Management Engine firmware.",1);
  0x8527 = @("Sure Start was unable to recover the Intel Management Engine firmware.",1);
  0x8528 = @("Intel management engine firmware update failed.",1);
  0x8529 = @("Intel management engine firmware update succeeded.",0);
  0x852A = @("BIOS was unable to locate Intel management engine firmware binary needed to restore Intel management engine firmware ",1);

  0x861E = @("The HP Sure Start EpSC has found an integrity problem with the backup copy of Intel CSME bootloader firmware; the Intel CSME bootloader firmware integrity checking / recovery capability is no longer available.",2);
  0x861F = @("The HP Sure Start EpSC has found an integrity issue with the Intel CSME bootloader firmware.",1);
  0x8620 = @("The HP Sure Start EpSC has successfully captured a new backup of the most recent version of Intel CSME bootloader firmware and Intel CSME configuration.",0);
  0x8621 = @("The HP Sure Start EpSC has performed a recovery of the Intel CSME bootloader firmware and Intel CSME factory configuration. Administrative action may be required to ensure that all Intel CSME provided services are configured as desired.",2);
  0x8622 = @("The HP Sure Start EpSC detected that the system was unable to boot successfully after an Intel CSME firmware update; an attempt will be made to restore Intel CSME firmware.",2);
  0x8623 = @("HP Sure Start detected that the Intel CSME firmware file system (Intel CSME configuration) is corrupted; an attempt will be made to restore Intel CSME firmware and configuration to last known good state.",2);
  0x8624 = @("HP Sure Start detected that the Intel CSME failed to complete the boot initialization sequence immediately after the Intel CSME firmware update operation; an attempt will be made to restore Intel CSME firmware and configuration to last known good state.",2);
  0x8625 = @("Sure Start has detected the Intel Management Engine (ME) is unable to start and has initiated the recovery process using an ME recovery firmware image stored on local disk or external recovery media.",1);
  0x8626 = @("HP Sure Start has detected that the Intel CSME is in a disabled state due to corruption within the Intel CSME data region.",2);
  0x8627 = @("HP Sure Start unable to recover the Intel CSME firmware.",1);
  0x8628 = @("Intel CSME firmware update operation attempted by HP Sure Start failed due to error returned by Intel CSME firmware update interface.",1);
  0x8629 = @("HP Sure Start successfully updated primary Intel CSME firmware.",0);
  0x862A = @("HP Sure Start was unable to locate Intel CSME firmware binary needed to restore Intel CSME firmware.",1);
  0x862B = @("Intel CSME capsule update firmware package that was provided to HP Sure Start has failed the digital signature verification.",1);
  0x862D = @("HP Sure Start has detected an unexpected platform reset during an Intel CSME firmware update attempt.",1);
  0x862e = @("HP Sure Start EpSC detected an unauthorized Intel CSME state transition to manufacturing mode.",1);

  0x871E = @("HP BIOSSphere was unable to activate protection against malicious hardware impacting system operation.",2);
  0x871F = @("A device attempted to access memory that it was not allowed to access.",1);
  0x8720 = @("A device was given unrestricted access to memory.",0);
  0x8721 = @("A device was removed from the list of devices having unrestricted access to memory.",0);

  0x881E = @("An attempt was made to access the system locally and an incorrect PIN was entered multiple times resulting in the system forcing a reboot.",2);
  0x881F = @("An attempt to change a firmware setting was made with an invalid signature.",1);
  0x8820 = @("The local access key was changed.",0);
  0x8821 = @("HP Sure Admin - Enhanced BIOS Authentication Mode Local Access Key 1 was set.",0);
  0x8822 = @("HP Sure Admin - Enhanced BIOS Authentication Mode Local Access Key 1 was cleared.",0);
  0x8823 = @("Enhanced BIOS Authentication Mode was enabled.",0);
  0x8824 = @("Enhanced BIOS Authentication Mode was disabled.",0);
  0x8825 = @("The users Secure Platform Management PIN reminder was set.",0);
  0x8826 = @("The users Secure Platform Management PIN reminder was cleared.",0);
  0x8827 = @("The users Secure Platform Management PIN was requested.",0);

  0x891E = @("HP EpSC runtime intrusion detection - HP BIOS detected/blocked an illegal attempt to access the HP EpSC trusted interface from the OS.",1);
  0x891F = @("HP EpSC runtime intrusion detection - HP EpSC detected/blocked an illegal attempt to access the HP EpSC trusted interface from the OS.",1);
  0x8920 = @("HP EpSC runtime intrusion detection -  An illegal attempt to write to EpSC code region of memory was detected and blocked.",2);
  0x8921 = @("HP EpSC runtime intrusion detection -  An illegal attempt to execute from an EpSC data region of memory was detected and blocked.",2);
  0x8922 = @("Threat Hunter - A hidden process was found running in the OS.",1);

  0x8A1E = @("HP TamperLock - The system detected that the cover was opened.",1);
  0x8A1F = @("HP TamperLock - The user acknowledged a BIOS POST notification that the cover had been opened.",0);
  0x8A20 = @("HP TamperLock - The TPM was cleared due to cover removal based on current HP TamerLock policy settings",0);
}


function checkBitlocker ($bitlocker)
{
  if ($bitlocker -eq "ignore")
  {
    Write-Verbose "Skipping BitLocker check, because BitLocker action = IGNORE"
    return $true
  }
  else {
    ($r,$dr) = isBootDriveBitlockerEncrypted
    Write-Verbose "Boot drive is BitLocker encrypted: $r"
    if ($r -eq $true)
    {
      if ($bitlocker -eq 'stop')
      {
        Write-Verbose ("BitLocker is on, and BitLocker action = STOP")

        Write-Host -ForegroundColor Cyan "This system has BitLocker enabled."

        Write-Host -ForegroundColor Cyan "Do you want to suspend BitLocker for one reboot?"
        Write-Host -ForegroundColor Cyan "You can also specify '-BitLocker suspend' or '-BitLocker ignore' on the command line to skip this check."
        $response = Read-Host -Prompt "Type 'Y' to suspend BitLocker and anything else to abort. "
        if ($response -ne "Y") {
          Write-Verbose "User did not confirm BitLocker suspension, aborting."
          return $false
        }
        else { $bitlocker = 'suspend' }
      }


      if ($bitlocker -eq "suspend")
      {
        if (!$quiet) { Write-Host ("Suspending BitLocker on this system.") }
        Write-Verbose ("BitLocker is on, and BitLocker action = SUSPEND")
        suspendBitlockerForOneReboot
        return $true
      }
      else {
        Write-Verbose ("Unknown BitLocker check option: $bitlocker")
        return $false
      }

    }
  }
}


function getAuditLogEntries ([ref]$buffer_out,[ref]$buffer_size,[ref]$records_count,[ref]$mi_result)
{
  $bs = $buffer_size.Value
  $rc = $records_count.Value
  $r = $mi_result.Value
  switch (Test-OSBitness) {
    32 { [DfmNativeBios]::get_audit_logs_32($buffer_out.Value,[ref]$bs,[ref]$rc,[ref]$r) }
    64 { [DfmNativeBios]::get_audit_logs_64($buffer_out.Value,[ref]$bs,[ref]$rc,[ref]$r) }
  }
  $buffer_size.Value = $bs
  $records_count.Value = $rc
  $mi_result.Value = $r
}




function isBootDriveBitlockerEncrypted ()
{
  [CmdletBinding()]
  param()

  $c = Get-BitLockerVolume | Where-Object VolumeType -EQ 'OperatingSystem'
  if (!$c -or $c.ProtectionStatus -eq "Off")
  {
    Write-Verbose ("No OperatingSystem drive found, or drive is not encrypted")
    return ($false,$null)
  }
  Write-Verbose "Operating system $($c.MountPoint) is BitLocker encrypted."
  return ($true,$c)
}


function suspendBitlockerForOneReboot ()
{
  [CmdletBinding()]
  param()

  ($isEncrypted,$drive) = isBootDriveBitlockerEncrypted
  if ($isEncrypted) {
    Write-Verbose "Suspending BitLocker on $($drive.MountPoint) for one reboot."
    Suspend-BitLocker -MountPoint $drive.MountPoint -RebootCount 1
  }
  else
  {
    Write-Verbose 'No BitLocker operating system drives found to suspend.'
  }
}




<#
.SYNOPSIS
    Return the runtime architecture (64-bit or 32-bit)

.DESCRIPTION
  This function returns 32 or 64, indicating the architecture of the running process.

.NOTES
    - When running 32-bit PowerShell on 64-bit systems, this will return 32.
#>
function Test-OSBitness
{
  [CmdletBinding()]
  param()

  if ([IntPtr]::Size -eq 4)
  { 32 } else { 64 }
}

function formatLogTimestamp ([timestamp_t]$ts)
{
  try {
    Get-Date -Year $ts.Year -Month $ts.Month -Day $ts.Day -Hour $ts.hour -Minute $ts.minute -Second $ts.second -Millisecond 0
  }
  catch {
    return $null
  }
}

function formatLogEntryInHex ([int]$Status,[int]$MessageNumber,[timestamp_t]$TimeStamp,[int]$Source,[int]$Id,[int]$Severity,[int]$Data0,[int]$Data1,[int]$Data2,[int]$Data3,[int]$Data4)
{
  try {
    $StatusHex = '{0:X2}' -f $Status
    $MessageNumberHex = '{0:X2}' -f $MessageNumber
    $ts = Get-FormattedTime ($TimeStamp)
    $SourceHex = '{0:X2}' -f $Source
    $IdHex = '{0:X2}' -f $Id
    $SeverityHex = '{0:X2}' -f $Severity
    $Data0Hex = '{0:X2}' -f $Data0
    $Data1Hex = '{0:X2}' -f $Data1
    $Data2Hex = '{0:X2}' -f $Data2
    $Data3Hex = '{0:X2}' -f $Data3
    $Data4Hex = '{0:X2}' -f $Data4
    return $StatusHex + ':' + $MessageNumberHex + ':' + $ts + ':' + $SourceHex + ':' + $IdHex + ':' + $SeverityHex + ':' + $Data0Hex + ':' + $Data1Hex + ':' + $Data2Hex + ':' + $Data3Hex + ':' + $Data4Hex
  }
  catch {
    return $null
  }
}

function Get-FormattedTime ([timestamp_t]$ts)
{
  $second = [string]$ts.second
  $second = $second.PadLeft(2,'0')

  $minute = [string]$ts.minute
  $minute = $minute.PadLeft(2,'0')

  $hour = [string]$ts.hour
  $hour = $hour.PadLeft(2,'0')

  $day = [string]$ts.Day
  $day = $day.PadLeft(2,'0')

  $month = [string]$ts.Month
  $month = $month.PadLeft(2,'0')

  $year = [string]$ts.Year
  $year = $year.substring($year.Length - 2)

  return ($second + ':' + $minute + ':' + $hour + ':' + $day + ':' + $month + ':' + $year)
}

function resolvePath ([string]$path)
{
  $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
}

function displayInvocationException ($exception)
{
  $bitness = Test-OSBitness
  Write-Verbose "Could not find support library for the current format: $($exception.Message)"
  throw "Could not call the support library. Please make sure the library dfmbios$bitness.dll is in the path."
}

function formatLogSeverity ([int]$severity)
{
  switch ($severity) {
    0 { "Info" }
    1 { "Warn" }
    2 { "Critical" }
    0xff { "Undefined" }
  }
}

function formatPowerstate ([powerstate_t]$state)
{
  switch ($state) {
    S0 { "S0" }
    S3 { "S3" }
    S4S5 { "S4/S5" }
    default { "Undefined" }
  }
}

function decodeLogData ($function,$byte1,$byte2,$byte3,$byte4,$byte5)
{
  switch ($function) {
    0x0323 {}
    0x0322 {}
    0x032f {}
    default { return $null }
  }
}

function getAdditionalData ([int]$source,[int]$id,[byte]$byte1,[byte]$byte2,[byte]$byte3,[byte]$byte4,[byte]$byte5)
{
  $result = "Not significant"
  switch ($source)
  {
    0x03 {
      switch ($id) {
        (0x22 -or 0x23) {
          $result = "Writing BIOS $byte1.$byte2.$byte3.$byte4 $byte5"
        }
        0x2f {
          $result = "Label: {0}{1}{2}{3}" -f [char]$byte2,[char]$byte3,[char]$byte4,[char]$byte5
        }
      }
    }
  }
  return $result
}

function formatEventSource ([int]$source) {
  switch ($source) {
    0x00 { "EC ROM ($source)" }
    0x01 { "RTOS ($source)" }
    0x02 { "EC Task ($source)" } # EC Task
    0x03 { "HP Sure Start ($source)" } # FB EC TASK
    0x80 { "General BIOS Messages ($source)" }
    0x81 { "Secure HDD Erase ($source)" }
    0x82 { "HP Sure Start Runtime Intrusion Detection for Intel ($source)" } # SS3 from BIOS
    0x83 { "HP Sure Start Runtime Intrusion Detection for AMD ($source)" } # SS3 from PCP
    0x84 { "HP Secure Platform Management ($source)" }
    0x85 { "HP Sure Start Gen4 ($source)" }
    0x86 { "HP Sure Start resilience for Intel CSME ($source)" }
    0x87 { "HP DMA Protection ($source)" }
    0x88 { "HP Sure Admin ($source)" }
    0x89 { "HP EpSC Runtime Intrusion Detection ($source)" }
    0x8A { "HP TamperLock ($source)" }
    default {
      Write-Verbose ("An unknown source ID was found: $source")
      "Reserved ($source)"
    }
  }
}

function makeCredential ($data)
{

  [bios_credential_t]$cred = New-Object bios_credential_t

  if (-not $data) {
    $cred.authentication = [authentication_t]::auth_t_anonymous
  }
  else
  {
    $cred.authentication = [authentication_t]::auth_t_password
    $c = New-Object authentication_data_t
    $c.Password = $data
    $c.password_size = $data.Length
    $cred.Data = $c
  }
  $cred
}



function getLogEntry ([uint32]$source,[uint32]$id,[int]$index)
{
  [int]$code = $id -bor ($source -shl 8)
  $result = "Undefined log entry $id from source $source."
  try {
    $result = $msgs[$code][$index] } catch {
    Write-Verbose ("No entry for source=$source and id=$id, using generic description");
  }
  return [string]$result
}

function getImageInformation ($filename)
{

  if (Test-Path $filename) { $info = (Get-Item $filename) }
  else {
    throw "Logo bitmap file $file not found."
  }

  [psobject]$result = New-Object PSOBJECT
  try {
    $image = New-Object -ComObject Wia.ImageFile
    $image.LoadFile($info.FullName)
  }
  catch [System.ArgumentException]{
    Write-Verbose $_.Exception
    throw "Could not load '$file' please make sure this is a valid JPEG file"
  }

  Write-Verbose "This picture is $($image.width) x $($image.height)"
  Write-Verbose "This picture is $($info.length) bytes"

  $result |
  Add-Member -MemberType NoteProperty -Name FullName -Value $info.FullName -Passthru |
  Add-Member -MemberType NoteProperty -Name Size -Value $info.Length -Passthru |
  Add-Member -MemberType NoteProperty -Name Width -Value $image.Width -Passthru |
  Add-Member -MemberType NoteProperty -Name Height -Value $image.Height -Passthru |
  Add-Member -MemberType NoteProperty -Name Depth -Value $image.pixeldepth -Passthru |
  Add-Member -MemberType NoteProperty -Name Xdpi -Value $image.horizontalresolution -Passthru |
  Add-Member -MemberType NoteProperty -Name Ydpi -Value $image.verticalresolution -Passthru
}



<#
.SYNOPSIS
    Retrieve firmware log entries

.DESCRIPTION
    This function retrieves an array of firmware log entries. These logs are HP specific, and generate by various
  HP firmware subsystems.

  Returns An array of bios_log_entry_t objects.


.PARAMETER Numeric
  If numeric is specified, the output displays the log entries as raw values, which is often
  useful for debugging or communicating with HP. Otherwise, the script will attempt to
  interpret the logs and display friendly text.

.EXAMPLE
    $logs = Get-HPFirmwareAuditLog -numeric

.NOTES
    - Requires HP BIOS with firmware log support
    - This function requires elevated privileges.
#>
function Get-HPFirmwareAuditLog {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPFirmwareAuditLog")]
  param([switch]$Numeric)


  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  $buffer_size = 0
  $buffer_out = $null
  $records_count = 0
  $mi_result = 0

  Write-Verbose "Querying for number of records."
  try {
    $result = getAuditLogEntries -buffer_out ([ref]$buffer_out) -buffer_size ([ref]$buffer_size) -records_count ([ref]$records_count) -mi_result ([ref]$mi_result)
  }
  catch [System.Management.Automation.MethodInvocationException]
  {
    displayInvocationException ($_.Exception)
  }

  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x01

  if ($records_count -eq 0)
  {
    Write-Verbose "There are not records to retrieve."
    return "No records."
  }
  Write-Verbose "Found $records_count records."
  $buffer_out = [bios_log_entry_t[]]::new($records_count)

  try {
    $result = getAuditLogEntries -buffer_out ([ref]$buffer_out) -buffer_size ([ref]$buffer_size) -records_count ([ref]$records_count) -mi_result ([ref]$mi_result)

    <#
    switch (Test-OSBitness) {
      32 { $result = [DfmNativeBios]::get_audit_logs_32($buffer_out,[ref]$buffer_size,[ref]$records_count,[ref]$mi_result) }
      64 { $result = [DfmNativeBios]::get_audit_logs_64($buffer_out,[ref]$buffer_size,[ref]$records_count,[ref]$mi_result) }
    }
    #>
  }
  catch [System.Management.Automation.MethodInvocationException]
  {
    displayInvocationException ($_.Exception)
  }

  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x01
  Write-Verbose "Received $records_count records"

  if (-not $numeric.IsPresent) {
    $buffer_out | Select-Object -Property `
       message_number,`
       @{ Name = "severity"; Expression = { formatLogSeverity (getLogEntry -Source $_.source_id -Id $_.event_id -Index 1) } },`
       @{ Name = "system_state_at_event"; Expression = { formatPowerstate ($_.system_state_at_event) } },`
       @{ Name = "source_id"; Expression = { formatEventSource ($_.source_id) } },`
       event_id,`
       timestamp_is_exact,`
       @{ Name = "timestamp"; Expression = { formatLogTimestamp ($_.timestamp) } },`
       @{ Name = "description"; Expression = { getLogEntry -Source $_.source_id -Id $_.event_id -Index 0 -Numeric $numeric.IsPresent } },`
       @{ Name = "raw_event_data"; Expression = { (formatLogEntryInHex -Status $_.Status -MessageNumber $_.message_number -timestamp $_.timestamp -Source $_.source_id -Id $_.event_id -Severity $_.severity -Data0 $_.data_0 -Data1 $_.data_1 -Data2 $_.data_2 -Data3 $_.data_3 -Data4 $_.data_4) } } | Sort-Object timestamp,message_number
  }
  else
  {
    $buffer_out | Select-Object -Property `
       message_number,`
       @{ Name = "severity"; Expression = { [int]$_.severity } },`
       @{ Name = "system_state_at_event"; Expression = { [int]$_.system_state_at_event } },`
       source_id,`
       event_id,`
       timestamp_is_exact,`
       @{ Name = "timestamp"; Expression = { formatLogTimestamp ($_.timestamp) } },`
       @{ Name = "raw_event_data"; Expression = { (formatLogEntryInHex -Status $_.Status -MessageNumber $_.message_number -timestamp $_.timestamp -Source $_.source_id -Id $_.event_id -Severity $_.severity -Data0 $_.data_0 -Data1 $_.data_1 -Data2 $_.data_2 -Data3 $_.data_3 -Data4 $_.data_4) } } | Sort-Object timestamp,message_number
  }
}


<#
.SYNOPSIS
    Set the HP firmware logo (replaces the HP logo at boot) where supported.

.DESCRIPTION
  This command sets the boot logo that is seen after computer POST and before the OS takes over. Normally this
  if the HP logo, but companies may wish to customize it with their own enterprise or workgroup logo.

  Please note that the file format has specific restrictions. See the file parameter for more information.

.NOTES
  - Requires HP BIOS.
  - This function requires elevated privileges.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.


.PARAMETER File
  The file to use as logo. Restrictions are as follows:
    1. Must be JPEG
    2. Resolution may not be higher than 1024x768
    3. FIle size may not be larger than 32751 bytes.


.PARAMETER Password
  Specify the BIOS password, if a setup password is currently active.

.EXAMPLE
    Set-HPFirmwareBootLogo -file myfile.jpg

.LINK
  Clear-HPFirmwareBootLogo

.LINK
  [Get-HPFirmwareBootLogoIsActive](Get-HPFirmwareBootLogoIsActive)

.NOTES
  - Not currently supported in Windows PE.
  - Requires HP BIOS
  - This command requires elevated privileges.
  - Due to a BIOS limitation, this function will not succeed when HP Sure Admin is enabled. 
#>
function Set-HPFirmwareBootLogo
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Set%E2%80%90HPFirmwareBootLogo")]

  param(
    [Parameter(Mandatory = $true,Position = 0)] [string]$File,
    [Parameter(Mandatory = $false,Position = 1)] [string]$Password = $null)

  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  [bios_credential_t]$cred = makeCredential ($password)
  $max_size = (32768 - 16 - 1)
  $mi_result = 0

  if ($password -ne $null)
  {
    $cred.authentication = [authentication_t]::auth_t_password
    $cred.Data.Password = $password
    $cred.Data.password_size = $password.Length
  }

  $info = getImageInformation ($file)

  if (($info.Width -gt 1024) -or ($info.Height -gt 768) -or ($info.Size -gt $max_size))
  {
    Write-Verbose ("Validation error:")
    Write-Verbose (" File size: $size")
    Write-Verbose (" File resolution: $width x $height")
    throw ("File is larger than $max_size or has a greater resolution than 1024x768")
  }

  try {
    switch (Test-OSBitness) {
      32 { $result = [DfmNativeBios]::set_enterprise_logo32($info.FullName,[ref]$cred,[ref]$mi_result) }
      64 { $result = [DfmNativeBios]::set_enterprise_logo64($info.FullName,[ref]$cred,[ref]$mi_result) }
    }
  }
  catch [System.Management.Automation.MethodInvocationException]
  {
    displayInvocationException ($_.Exception)
  }
  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x02

}


<#
.SYNOPSIS
   Returns true if a custom logo is currently active, false if the standard HP logo is active.


.DESCRIPTION
  Use this command to see if a logo was previously configured via Set-HPFirmwareBootLogo.

  Returns $true if a custom logo is active, otherwise $false.

.NOTES
  - Requires HP BIOS
  - This command requires elevated privileges.

.EXAMPLE
    $isactive = Get-HPFirmwareBootLogoIsActive

.LINK
  Clear-HPFirmwareBootLogo

.LINK
  [Set-HPFirmwareBootLogo](Set-HPFirmwareBootLogo)



#>
function Get-HPFirmwareBootLogoIsActive
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPFirmwareBootLogoIsActive")]
  param()
  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }
  $state = 0
  $installed = 0
  $mi_error = 0

  try {
    switch (Test-OSBitness) {
      32 { $result = [DfmNativeBios]::query_enterprise_logo32([ref]$installed,[ref]$state,[ref]$mi_error) }
      64 { $result = [DfmNativeBios]::query_enterprise_logo64([ref]$installed,[ref]$state,[ref]$mi_error) }
    }
  }
  catch [System.Management.Automation.MethodInvocationException]
  {
    displayInvocationException ($_.Exception)
  }

  Test-HPPrivateCustomResult -result $result -mi_result $mi_error -Category 0x02
  Write-Verbose ("Flash is in progress: $state")
  Write-Verbose ("Logo in use: $installed")
  $installed -eq 1
}

<#
.SYNOPSIS
  Remove an active custom boot logo

.DESCRIPTION
  This function clears any active boot logo, and reverts back to the HP logo as the boot logo.

.PARAMETER password
  Specify the BIOS password, if a setup password is currently active.
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.

.EXAMPLE
  Clear-HPFirmwareBootLogo -file myfile.jpg

.LINK
  Set-HPFirmwareBootLogo

.LINK
  [Get-HPFirmwareBootLogoIsActive](Get-HPFirmwareBootLogoIsActive)

.NOTES
  - Requires HP BIOS
  - This command requires elevated privileges.
  - Due to a BIOS limitation, this function will not succeed when HP Sure Admin is enabled.

#>
function Clear-HPFirmwareBootLogo
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Clear%E2%80%90HPFirmwareBootLogo")]

  param([Parameter(Mandatory = $false,Position = 0)] [string]$Password = $null)
  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  $mi_result = 0
  $cred = makeCredential ($password)

  try {
    switch (Test-OSBitness) {
      32 { $result = [DfmNativeBios]::clear_enterprise_logo32([ref]$cred,[ref]$mi_result) }
      64 { $result = [DfmNativeBios]::clear_enterprise_logo64([ref]$cred,[ref]$mi_result) }
    }
  }
  catch [System.Management.Automation.MethodInvocationException]
  {

    displayInvocationException ($_.Exception)
  }

  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x02
}



<#
.SYNOPSIS
  Update the system firmware from a capsule or BIOS binary file

.DESCRIPTION
  This function initiates the flash process on the current platform. The update must be provided as a BIN file, and can be obtained via the [Get-HPBIOSUpdates](https://developers.hp.com/hp-client-management/doc/Get%E2%80%90HPBiosUpdates) cmdlet.
  If HP Sure Admin is enabled a payload file should be provided instead of a password.

.PARAMETER File
  The firmware update binary (.BIN) file.

.PARAMETER PayloadFile
  The HP Sure Admin authorization for update firmware with the provided binary file.
  See New-HPSureAdminFirmwareUpdatePayload to know how to generate the payload file.

.PARAMETER Password
  The BIOS password, if a password is currently set. Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.

.PARAMETER Quiet
  Suppress non-essential messages

.PARAMETER BitLocker
  Provide an answer to the BitLocker check prompt (if any). The value may be one of:
    stop - stop if BitLocker is detected but not suspended, and prompt.
    stop is default when BitLocker switch is provided.
    ignore - skip the BitLocker check
    suspend - suspend BitLocker if active, and continue

.PARAMETER Force
   Force the BIOS update, even if the target BIOS is already installed.

.PARAMETER FilenameHint
  Alias -filename_hint. Some older generations of platforms require that the filename of the BIOS update is in a specific format. If you are using a filename other than the original name, you can use filename_hint to pass the original filename in, without the .bin extension.
  If filename_hint is not specified, the cmdlet will extract the filename from the 'file' parameter. However if this does not match the required format, it may fail on that particular generation.
  If the system does not require a specific format (as it is true of most recent systems), the parameter is ignored.

.EXAMPLE
  Update-HPFirmware -file bios.bin -password 'mysecret'

.EXAMPLE
  Update-HPFirmware -File bios.bin -PayloadFile PayloadFile.dat

.NOTES
  - Requires HP BIOS.
  - Requires 64-bit PowerShell (not supported under 32-bit PowerShell)
  - UEFI boot mode is required, legacy mode is not supported.
  - This command requires elevated privileges.

  **WinPE notes**

  - Use '-BitLocker ignore' when using this function in WinPE, as BitLocker checks are not applicable in Windows PE.
  - Requires that the WInPE image is built with the WinPE-SecureBootCmdlets.cab component.

#>
function Update-HPFirmware {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Update%E2%80%90HPFirmware")]
  param(
    [Parameter(ParameterSetName = "Password",Mandatory = $false,Position = 0)]
    [string]$Password,

    [Parameter(ParameterSetName = "PayloadFile",Mandatory = $true,Position = 0)]
    [System.IO.FileInfo]$PayloadFile,

    [ValidateScript({ if (-not ($_ | Test-Path)) { throw "Firmware file '$_' cannot be accessed." } return $true })]
    [Parameter(ParameterSetName = "Password",Mandatory = $true,Position = 1)]
    [Parameter(ParameterSetName = "PayloadFile",Mandatory = $true,Position = 1)]
    [System.IO.FileInfo]$File,

    [Parameter(ParameterSetName = "Password",Mandatory = $false,Position = 2)]
    [Parameter(ParameterSetName = "PayloadFile",Mandatory = $false,Position = 2)]
    [switch]$Quiet,

    [ValidateSet('stop','ignore','suspend')]
    [Parameter(ParameterSetName = "Password",Mandatory = $false,Position = 3)]
    [Parameter(ParameterSetName = "PayloadFile",Mandatory = $false,Position = 3)]
    [string]$BitLocker = 'stop',

    [Alias("filename_hint")]
    [Parameter(ParameterSetName = "Password",Mandatory = $false,Position = 4)]
    [Parameter(ParameterSetName = "PayloadFile",Mandatory = $false,Position = 4)]
    [string]$FilenameHint,

    [Parameter(ParameterSetName = "Password",Mandatory = $false,Position = 5)]
    [Parameter(ParameterSetName = "PayloadFile",Mandatory = $false,Position = 5)]
    [switch]$Force
  )

  Test-HPFirmwareFlashSupported -CheckPlatform
  $resolvedFile = resolvePath ($file)

  Write-Verbose 'Preparing BIOS update'
  Write-Verbose "Update file is: $resolvedFile"

  [byte[]]$authorization = $null
  $authorizationLength = 0
  if ($PSCmdlet.ParameterSetName -eq 'PayloadFile') {
    $payload = Get-Content -Path $PayloadFile -Encoding UTF8
    [PortableFileFormat]$portable = ConvertFrom-Json -InputObject $payload

    if ($portable.purpose -ne "hp:sureadmin:firmwareupdate") {
      throw "The payload should be generated by New-HPSureAdminFirmwareUpdatePayload function"
    }

    $data = [System.Text.Encoding]::UTF8.GetString($portable.Data) | ConvertFrom-Json
    [byte[]]$authorization = $data.Authorization | ConvertFrom-Json
    $authorizationLength = $authorization.Length
  }

  $blenabled = checkBitlocker ($bitlocker)
  if ($blenabled -eq $false) {
    Write-Verbose "Aborting due to BitLocker issue"
    return
  }
  $cred = makeCredential ($password)


  if (-not $FilenameHint)
  {
    $FilenameHint = [io.path]::GetFileNameWithoutExtension($file)
  }
  Write-Verbose "Caller gives a filename hint of '$FilenameHint'"

  try {
    # Reconstruct the file name for the current BIOS and use it to compare
    # with the target BIOS file name. This is used as a 'best effort' check.
    $ver,$fam = (Get-HPBIOSVersion -IncludeFamily).Replace(".","").Split()
    $ver = $ver.Replace(".","").PadLeft(6,'0')
    $BiosVersion = "$($fam)_$($ver)"
  }
  catch {
    Write-Verbose "Could not construct file name for the currently installed BIOS."
    $BiosVersion = ""
  }

  if (-not $Force.IsPresent -and ($FilenameHint -eq $BiosVersion)) {
    Write-Host "This system is already running BIOS version $(Get-HPBIOSVersion)"
    Write-Host -ForegroundColor Cyan "Use '-Force' on the command line to proceed anyway."
    return
  }

  $Callback = {
    param(
      [int32]$Location,
      [int32]$Value1,
      [int32]$Value2,
      [int32]$Status
    )

    if (-not $quiet.IsPresent) {
      $activityTitle = "Updating system firmware"
      switch ($location)
      {
        1 { Write-Progress -Activity $activityTitle -CurrentOperation "Beginning flash process" -PercentComplete 0 }
        2 {
          $progress = ($Value1 * 100) / $Value2
          Write-Progress -Activity $activityTitle -CurrentOperation "Copying firmware" -PercentComplete $progress
        }
        3 { Write-Progress -Activity $activityTitle -CurrentOperation "Completing operation" -PercentComplete 100 }
        4 { Write-Progress -Activity $activityTitle -CurrentOperation "Waiting for the BIOS to process the file" -PercentComplete 100 }
        10 { Write-Progress -Activity $activityTitle -CurrentOperation "Operation complete" -PercentComplete 100 -Completed }
        default { Write-Verbose "Unknown status received $location" }
      }
    }
  } -as [ProgressCallback]

  $efi_path = Get-EFIPartitionPath -FixedOnly

  Set-HPPrivateFlashHPDevice -ResolvedFile $resolvedFile -Cred $cred -Callback $Callback -FilenameHint $FilenameHint -Efi_path $efi_path -Authorization $authorization -AuthorizationLength $authorizationLength -Verbose:$VerbosePreference

  if (-not $quiet.IsPresent) {
    Write-Host -ForegroundColor Cyan "Firmware image has been deployed. The process will continue after reboot."
  }
}

function Set-HPPrivateFlashHPDevice {
  [CmdletBinding()]
  param(
    $ResolvedFile,
    $Cred,
    $Callback,
    $FilenameHint,
    $Efi_path,
    $Authorization,
    $AuthorizationLength
  )

  try {
    $mi_result = 0
    switch (Test-OSBitness) {
      32 { $result = [DfmNativeBios]::flash_hp_device32([string]$ResolvedFile,[ref]$Cred,[ref]$mi_result,$Callback,$FilenameHint,$Efi_path,$Authorization,$AuthorizationLength) }
      64 { $result = [DfmNativeBios]::flash_hp_device64([string]$ResolvedFile,[ref]$Cred,[ref]$mi_result,$Callback,$FilenameHint,$Efi_path,$Authorization,$AuthorizationLength) }
    }
    Test-HPPrivateCustomResult -result $result -Category 0x02 -mi_result $mi_result
  }
  catch [System.Management.Automation.MethodInvocationException]
  {
    displayInvocationException ($_.Exception)
  }

  Test-HPPrivateCustomResult -result 0x80000711 -mi_result $result -Category 0x02
}

function Set-HPPrivateFirmwareUpdatePayload {
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = 'Payload',Position = 0,Mandatory = $true,ValueFromPipeline = $true)]
    [string]$Payload
  )

  [PortableFileFormat]$portable = ConvertFrom-Json -InputObject $payload
  if ($portable.purpose -ne "hp:sureadmin:firmwareupdate") {
    throw "The payload should be generated by New-HPSureAdminFirmwareUpdatePayload function"
  }

  $data = [System.Text.Encoding]::UTF8.GetString($portable.Data) | ConvertFrom-Json
  $params = @{
    file = resolvePath ($data.FileName)
  }
  if ($data.Quiet -eq $True) {
    $params.Quiet = $data.Quiet
  }
  if ($data.Force -eq $True) {
    $params.Force = $data.Force
  }
  if ($data.bitlocker) {
    $params.bitlocker = $data.bitlocker
  }

  [byte[]]$authorization = $data.Authorization | ConvertFrom-Json
  $authorizationLength = $authorization.Length

  $efi_path = (Get-EFIPartitionPath -FixedOnly) + "EFI\HP\DEVFW"
  New-Item -ItemType Directory -Force -Path $efi_path -ErrorAction SilentlyContinue | Out-Null
  $efi_path += "\Firmware.EAD"
  Write-Verbose "Writing firmware update authorization to $efi_path"

  try {
    switch (Test-OSBitness) {
      32 { $result = [DfmNativeBios]::write_authorization_to_file32($authorization,$authorizationLength,$efi_path) }
      64 { $result = [DfmNativeBios]::write_authorization_to_file64($authorization,$authorizationLength,$efi_path) }
    }
  }
  catch [System.Management.Automation.MethodInvocationException]
  {
    displayInvocationException ($_.Exception)
  }

  if ($result -ne 0) {
    throw "Error writing firmware update authorization to file: $result"
  }

  if ([System.IO.File]::Exists($params.file) -eq $true) {
    Write-Verbose "File ($params.File) was found, calling Update-HPFirmware"
    Update-HPFirmware @params
  }
  else {
    Write-Verbose "File ($params.File) was not found, you can call Update-HPFirmware manually"
  }
}

<#
.SYNOPSIS
    Validate that BIOS flashing can succeed, or throw an exception if requirements are not met

.DESCRIPTION
  This cmdlet throws an exception if the current platform does not meet the minimum requirements
  for flashing.

  If the cmdlet indicates the flash is not supported, please flash via the existing SoftPaq method instead
  of using the library.

.PARAMETER file
  The firmware update binary (.BIN) file.


.EXAMPLE
    Test-HPFirmwareFlashSupported

.NOTES
  - The current requirements for flash to be attempted are:

  - UEFI Mode is required, legacy mode is not supported.
  - Proper flash support in the BIOS (normally 2017 or later platforms)
#>
function Test-HPFirmwareFlashSupported
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Test%E2%80%90HPFirmwareFlashSupported")]
  param(
    [Parameter(Mandatory = $false,Position = 0)] [System.IO.FileInfo]$File = $null,
    [Parameter(Mandatory = $false,Position = 1)] [switch]$CheckPlatform,
    [Parameter(Mandatory = $false,Position = 2)] [switch]$CheckFile
  )
  [int]$major = [environment]::OSVersion.Version.Major
  [int]$release = (Get-ItemProperty -Path Registry::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ReleaseId
  [int]$result = 0

  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  if ($checkplatform.IsPresent) {


    Write-Verbose "Checking UEFI mode"
    if ((Get-HPDeviceBootInformation).Mode -ne "UEFI")
    {
      Write-Verbose "Mode $((Get-HPDeviceBootInformation).Mode) is not supported."
      throw [System.Management.Automation.RuntimeException]"This cmdlet only supported Windows 10 UEFI mode."
    }

    Write-Verbose "Making sure BIOS update is not locked"
    try {
      if ((Get-HPBIOSSettingValue "Lock BIOS Version") -ne "Disable")
      {
        Write-Verbose "Lock BIOS Version is set, flash will probably fail"
        throw [System.Management.Automation.RuntimeException]"You cannot flash while 'Lock BIOS Version' is enabled."
      }
    } catch [System.InvalidOperationException],[System.Management.Automation.ItemNotFoundException]{
      Write-Verbose "This system does not appear to have a Lock BIOS Version setting, ignoring."
    }
  }

  if ($checkfile.IsPresent) {
    Write-Verbose "Checking that the flash file $file matches the current platform"
    [Environment]::CurrentDirectory = $pwd
    $is_capsule = 0
    $is_for_current_platform = 0

    try {
      switch (Test-OSBitness) {
        32 { $result = [DfmNativeBios]::get_flash_file_information32([IO.Path]::GetFullPath($file),[ref]$is_capsule,[ref]$is_for_current_platform) }
        64 { $result = [DfmNativeBios]::get_flash_file_information64([IO.Path]::GetFullPath($file),[ref]$is_capsule,[ref]$is_for_current_platform) }
      }
    }
    catch [ArgumentException]
    {
      $err = "Failed to process file with path $($_)"
      Write-Verbose $err
      throw $err
    }
    catch [System.Management.Automation.MethodInvocationException]
    { displayInvocationException ($_.Exception)
    }
    Test-HPPrivateCustomResult $result
    Write-Verbose "get_flash_file_information returned capsule=>$is_capsule,  matches_this_platform=>$is_for_current_platform"
    if ($is_capsule -eq 0) {
      throw "Flash file is not an UEFI capsule."
    }
    if ($is_for_current_platform -eq 0) {
      throw "Flash file is not intended for the current platform."
    }
  }
  Write-Verbose "All flash checks passed"
}


<#
.SYNOPSIS
    Create a password file compatible with HP Bios Configuration Utility (BCU)

.DESCRIPTION
  This cmdlet creates a password file that is compatible with the HP Bios Configuration Utility (BCU). The command
  is roughly equivalent to running the hpqpasswd tool with the following arguments:

     hpqpassd /s /p"password" /f"outfile"


.PARAMETER password
  The passwords to encode into the target file.

.PARAMETER outfile
  The file to create. If not specified, the script will attempt to create a file in the current directory named password.bin"

.EXAMPLE
    Write-HPFirmwarePasswordFile -password 'mysecret' -outfile mysecret.bin

.NOTES
  - Use single quotes around the password to prevent PowerShell from interpreting special characters in the string.


#>
function Write-HPFirmwarePasswordFile
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Write%E2%80%90HPFirmwarePasswordFile")]
  param(
    [Parameter(Mandatory = $true,Position = 0)] [string]$Password,
    [Parameter(Mandatory = $false,Position = 1)] [System.IO.FileInfo]$Outfile = "password.bin"
  )
  Write-Verbose "Creating password file $outfile..."
  [bios_credential_t]$cred = New-Object bios_credential_t
  $cred.authentication = [authentication_t]::auth_t_password;
  $c = New-Object authentication_data_t
  $c.Password = $password
  $c.password_size = $password.Length
  $cred.Data = $c

  $outFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outFile)
  Write-Verbose ("Writing password to file $outfile")
  try {
    switch (Test-OSBitness) {
      32 { $result = [DfmNativeBios]::encrypt_password_to_file32([ref]$cred,$outFile) }
      64 { $result = [DfmNativeBios]::encrypt_password_to_file64([ref]$cred,$outFile) }
    }
    Test-HPPrivateCustomResult -result $result -Category -1 }
  catch [ArgumentException]
  {
    $err = "Failed to process file with path $($_)"
    Write-Verbose $err
    throw $err
  }
  catch [System.Management.Automation.MethodInvocationException]
  {
    displayInvocationException ($_.Exception)
  }
  Write-Verbose "Ok."
}

function createTemporaryDirectory {
  $parent = [System.IO.Path]::GetTempPath()
  [string]$name = [System.Guid]::NewGuid()
  New-Item -ItemType Directory -Path (Join-Path $parent $name)
}




<#
.SYNOPSIS
    Get EFI partition path

.DESCRIPTION
  This cmdlet retrieves the path of the EFI partition


.PARAMETER FixedOnly
  Ignore removable drives during search


.EXAMPLE
    Get-EFIPartitionPath

.NOTES
  - This function requires elevated privileges.

#>
function Get-EFIPartitionPath
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Get%E2%80%90EFIPartitionPath")]
  param([Parameter(Mandatory = $false,Position = 1)] [switch]$FixedOnly)

  if (-not (Test-IsElevatedAdmin)) {
    throw [System.Security.AccessControl.PrivilegeNotHeldException]"elevated administrator"
  }

  $volumes = Get-Volume | Select-Object `
     @{ Name = "Path"; Expression = { $_.Path } },`
     @{ Name = "Mount"; Expression = { $_.DriveType } },`
     @{ Name = "Type"; Expression = { (Get-Partition -Volume $_).type } },`
     @{ Name = "Disk"; Expression = { (Get-Partition -Volume $_).DiskNumber } }

  if ($fixedOnly) { $volumes = $volumes | Where-Object Mount -EQ "Fixed" }
  [array]$efi = $volumes | Where-Object { $_.type -eq "System" }

  if (-not $efi) {
    throw [System.Management.Automation.ItemNotFoundException]"Could not locate EFI partition. "
  }

  # ignore EFI partitions that may be offline
  [array]$efi = $efi | Where-Object { (Get-Disk -Number $_.Disk).OperationalStatus -eq "Online" }

  if (-not $efi) {
    throw [System.Management.Automation.ItemNotFoundException]"Could not locate EFI partition. "
  }

  # try to match the EFI partition to the boot disk, if we find multiple
  if ($efi.Count -gt 1 -and -not (Test-WinPE))
  {
    Write-Verbose "Found multiple ($($efi.Count)) EFI fixed partitions, trying to trim them down."
    [array]$efi = $efi | Where-Object { (Get-Disk -Number $_.Disk).IsBoot -eq $true }
  }


  if ($efi.Count -gt 1) {
    throw [System.Management.Automation.ItemNotFoundException]"Could not locate EFI partition, too many candidates."
  }


  $efi[0].Path
}


<#
.SYNOPSIS
    Determine if running in WinPE

.DESCRIPTION
  Returns $true if running in Win PE, $false otherwise

.EXAMPLE
    Test-WinPE
#>
function Test-WinPE
{
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Test%E2%80%90WinPE")]
  param()

  $r = Test-Path -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlset\Control\MiniNT
  Write-Verbose ("Running in Windows PE: $r")
  $r
}




function Get-HPPrivateRetailConfiguration
{
  [CmdletBinding()]
  param()
  $configuration = New-Object RetailInformation
  $mi_result = 0
  $cmd = '[DfmNativeRetail]::get_retail_dock_configuration_' + (Test-OSBitness) + '([ref]$configuration, [ref]$mi_result)';
  $result = Invoke-Expression -Command $cmd
  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04
  return $configuration
}

function Set-HPPrivateRetailConfiguration
{
  [CmdletBinding()]
  param(
    [RetailInformation]$configuration
  )
  $cfg = $configuration
  $mi_result = 0
  $cmd = '[DfmNativeRetail]::set_retail_dock_configuration_' + (Test-OSBitness) + '([ref]$cfg, [ref]$mi_result)';
  $result = Invoke-Expression -Command $cmd
  Test-HPPrivateCustomResult -result $result -mi_result $mi_result -Category 0x04
}

# SIG # Begin signature block
# MIIaywYJKoZIhvcNAQcCoIIavDCCGrgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBKZiwaHFhlLa71
# P02OVGSpvQRGQ5+IWQQTdEBei+rTraCCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
# ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBa
# Fw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lD
# ZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/l
# qJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fT
# eyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqH
# CN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+
# bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLo
# LFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIB
# yTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHow
# eDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwA
# AgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAK
# BghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7s
# DVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGS
# dQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6
# r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo
# +MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qz
# sIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHq
# aGxEMrJmoecYpJpkUe8wggU3MIIEH6ADAgECAhAFUi3UAAgCGeslOwtVg52XMA0G
# CSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcNMjEwMzIyMDAwMDAw
# WhcNMjIwMzMwMjM1OTU5WjB1MQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZv
# cm5pYTESMBAGA1UEBxMJUGFsbyBBbHRvMRAwDgYDVQQKEwdIUCBJbmMuMRkwFwYD
# VQQLExBIUCBDeWJlcnNlY3VyaXR5MRAwDgYDVQQDEwdIUCBJbmMuMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtJ+rYUkseHcrB2M/GyomCEyKn9tCyfb+
# pByq/Jyf5kd3BGh+/ULRY7eWmR2cjXHa3qBAEHQQ1R7sX85kZ5sl2ukINGZv5jEM
# 04ERNfPoO9+pDndLWnaGYxxZP9Y+Icla09VqE/jfunhpLYMgb2CuTJkY2tT2isWM
# EMrKtKPKR5v6sfhsW6WOTtZZK+7dQ9aVrDqaIu+wQm/v4hjBYtqgrXT4cNZSPfcj
# 8W/d7lFgF/UvUnZaLU5Z/+lYbPf+449tx+raR6GD1WJBAzHcOpV6tDOI5tQcwHTo
# jJklvqBkPbL+XuS04IUK/Zqgh32YZvDnDohg0AEGilrKNiMes5wuAQIDAQABo4IB
# xDCCAcAwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYE
# FD4tECf7wE2l8kA6HTvOgkbo33MvMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAK
# BggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQu
# ZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwSwYDVR0gBEQwQjA2
# BglghkgBhv1sAwEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5j
# b20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmlu
# Z0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQBZca1CZfgn
# DucOwEDZk0RXqb8ECXukFiih/rPQ+T5Xvl3bZppGgPnyMyQXXC0fb94p1socJzJZ
# fn7rEQ4tHxL1vpBvCepB3Jq+i3A8nnJFHSjY7aujglIphfGND97U8OUJKt2jwnni
# EgsWZnFHRI9alEvfGEFyFrAuSo+uBz5oyZeOAF0lRqaRht6MtGTma4AEgq6Mk/iP
# LYIIZ5hXmsGYWtIPyM8Yjf//kLNPRn2WeUFROlboU6EH4ZC0rLTMbSK5DV+xL/e8
# cRfWL76gd/qj7OzyJR7EsRPg92RQUC4RJhCrQqFFnmI/K84lPyHRgoctAMb8ie/4
# X6KaoyX0Z93PMYIPsjCCD64CAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UE
# AxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQBVIt
# 1AAIAhnrJTsLVYOdlzANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDgzdNUfDfei5QsW+O/eYqDzwyv3AKJ
# Z8jLURfyOc2TWjANBgkqhkiG9w0BAQEFAASCAQCBN+mtLhrJql+EPcJh3ESYj5gJ
# 7N9bAwKdsld57RuHgZy/faaLxJXKlDcUpGdVpyK0JFD1FTGL0P4n+0CwmzuHhTgx
# ZZaB2eltzdXsfdwomBSwnZmSVM+AoztTh+m+CvFUBG6f5UBHAmI2Y73gcQJskfWY
# RcT7Ha1kj7KeokShssFbQxFa4d/Z+kbJAFCZM1Mougl7lncG6Tbo5UMsTlC2B8qn
# 5mcsUMFKJR7eQGU07VHc4s3E2ls4xUYC6XX2SEiUnOxk6Gbt2PryJIropmNP3ifv
# yaF8asFDTGq0t8CUg++Wtsu621v059WvBmJoxrK86pUm9RX0bNgE/pbZhXuwoYIN
# fjCCDXoGCisGAQQBgjcDAwExgg1qMIINZgYJKoZIhvcNAQcCoIINVzCCDVMCAQMx
# DzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0BCRABBKBpBGcwZQIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEIEUiy5/lzc+9VjNd2LbNHi0hE1HjP763zZHR
# odvSNXgwAhEAkntrdUlGVIniOG9IOuxU/BgPMjAyMTExMjIxOTE5MDNaoIIKNzCC
# BP4wggPmoAMCAQICEA1CSuC+Ooj/YEAhzhQA8N0wDQYJKoZIhvcNAQELBQAwcjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElE
# IFRpbWVzdGFtcGluZyBDQTAeFw0yMTAxMDEwMDAwMDBaFw0zMTAxMDYwMDAwMDBa
# MEgxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjEgMB4GA1UE
# AxMXRGlnaUNlcnQgVGltZXN0YW1wIDIwMjEwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQDC5mGEZ8WK9Q0IpEXKY2tR1zoRQr0KdXVNlLQMULUmEP4dyG+R
# awyW5xpcSO9E5b+bYc0VkWJauP9nC5xj/TZqgfop+N0rcIXeAhjzeG28ffnHbQk9
# vmp2h+mKvfiEXR52yeTGdnY6U9HR01o2j8aj4S8bOrdh1nPsTm0zinxdRS1LsVDm
# QTo3VobckyON91Al6GTm3dOPL1e1hyDrDo4s1SPa9E14RuMDgzEpSlwMMYpKjIjF
# 9zBa+RSvFV9sQ0kJ/SYjU/aNY+gaq1uxHTDCm2mCtNv8VlS8H6GHq756WwogL0sJ
# yZWnjbL61mOLTqVyHO6fegFz+BnW/g1JhL0BAgMBAAGjggG4MIIBtDAOBgNVHQ8B
# Af8EBAMCB4AwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDBB
# BgNVHSAEOjA4MDYGCWCGSAGG/WwHATApMCcGCCsGAQUFBwIBFhtodHRwOi8vd3d3
# LmRpZ2ljZXJ0LmNvbS9DUFMwHwYDVR0jBBgwFoAU9LbhIB3+Ka7S5GGlsqIlssgX
# NW4wHQYDVR0OBBYEFDZEho6kurBmvrwoLR1ENt3janq8MHEGA1UdHwRqMGgwMqAw
# oC6GLGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtdHMuY3Js
# MDKgMKAuhixodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vc2hhMi1hc3N1cmVkLXRz
# LmNybDCBhQYIKwYBBQUHAQEEeTB3MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5k
# aWdpY2VydC5jb20wTwYIKwYBBQUHMAKGQ2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURUaW1lc3RhbXBpbmdDQS5jcnQwDQYJ
# KoZIhvcNAQELBQADggEBAEgc3LXpmiO85xrnIA6OZ0b9QnJRdAojR6OrktIlxHBZ
# vhSg5SeBpU0UFRkHefDRBMOG2Tu9/kQCZk3taaQP9rhwz2Lo9VFKeHk2eie38+dS
# n5On7UOee+e03UEiifuHokYDTvz0/rdkd2NfI1Jpg4L6GlPtkMyNoRdzDfTzZTlw
# S/Oc1np72gy8PTLQG8v1Yfx1CAB2vIEO+MDhXM/EEXLnG2RJ2CKadRVC9S0yOIHa
# 9GCiurRS+1zgYSQlT7LfySmoc0NR2r1j1h9bm/cuG08THfdKDXF+l7f0P4TrweOj
# SaH6zqe/Vs+6WXZhiV9+p7SOZ3j5NpjhyyjaW4emii8wggUxMIIEGaADAgECAhAK
# oSXW1jIbfkHkBdo2l8IVMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# JDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xNjAxMDcx
# MjAwMDBaFw0zMTAxMDcxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxE
# aWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMT
# KERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBUaW1lc3RhbXBpbmcgQ0EwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC90DLuS82Pf92puoKZxTlUKFe2I0rE
# DgdFM1EQfdD5fU1ofue2oPSNs4jkl79jIZCYvxO8V9PD4X4I1moUADj3Lh477sym
# 9jJZ/l9lP+Cb6+NGRwYaVX4LJ37AovWg4N4iPw7/fpX786O6Ij4YrBHk8JkDbTuF
# fAnT7l3ImgtU46gJcWvgzyIQD3XPcXJOCq3fQDpct1HhoXkUxk0kIzBdvOw8YGqs
# LwfM/fDqR9mIUF79Zm5WYScpiYRR5oLnRlD9lCosp+R1PrqYD4R/nzEU1q3V8mTL
# ex4F0IQZchfxFwbvPc3WTe8GQv2iUypPhR3EHTyvz9qsEPXdrKzpVv+TAgMBAAGj
# ggHOMIIByjAdBgNVHQ4EFgQU9LbhIB3+Ka7S5GGlsqIlssgXNW4wHwYDVR0jBBgw
# FoAUReuir/SSy4IxLVGLp6chnfNtyA8wEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNV
# HQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwgweQYIKwYBBQUHAQEEbTBr
# MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYBBQUH
# MAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6
# Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmww
# UAYDVR0gBEkwRzA4BgpghkgBhv1sAAIEMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8v
# d3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUA
# A4IBAQBxlRLpUYdWac3v3dp8qmN6s3jPBjdAhO9LhL/KzwMC/cWnww4gQiyvd/Mr
# HwwhWiq3BTQdaq6Z+CeiZr8JqmDfdqQ6kw/4stHYfBli6F6CJR7Euhx7LCHi1lss
# FDVDBGiy23UC4HLHmNY8ZOUfSBAYX4k4YU1iRiSHY4yRUiyvKYnleB/WCxSlgNcS
# R3CzddWThZN+tpJn+1Nhiaj1a5bA9FhpDXzIAbG5KHW3mWOFIoxhynmUfln8jA/j
# b7UBJrZspe6HUSHkWGCbugwtK22ixH67xCUrRwIIfEmuE7bhfEJCKMYYVs9BNLZm
# XbZ0e/VWMyIvIjayS6JKldj1po5SMYIChjCCAoICAQEwgYYwcjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFt
# cGluZyBDQQIQDUJK4L46iP9gQCHOFADw3TANBglghkgBZQMEAgEFAKCB0TAaBgkq
# hkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTIxMTEyMjE5
# MTkwM1owKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU4deCqOGRvu9ryhaRtaq0lKYk
# m/MwLwYJKoZIhvcNAQkEMSIEIKd3jugzQ092JuDdKONqgkLtxVBcIvm1tLCv/rN6
# r1OLMDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEILMQkAa8CtmDB5FXKeBEA0Fcg+Mp
# K2FPJpZMjTVx7PWpMA0GCSqGSIb3DQEBAQUABIIBAGw954txZ7+eu/1T8UtTvYWi
# CWR3ERyMH1LcAptiSHqqcYaPPCzbxJeKFdn2TurNvGEZWi+8UakzZHUT7NF0Mxs5
# IQa6Iki+PvlPpxoujgWMYx9XZ0F18XmSw+gS2UCzVUW9vO2mFE5suPoBhAARjzO4
# XzWUMo+EyGlgjBOzrfpkrKr44N5RNwvkMaJxXgKoRddZ4iJFhRiT35dWC74yOLVJ
# iX9m539kTLsB42o8eE2EosENOZGam6Jg02aki9iUbFYJDe6KIIaduOjqIj1b8q32
# 2awXM1ijcEg0EsC29gATNxPW0/Rxo9M/1DRkmZe6O0KVLq9gUCzQhQcvlMIkcD0=
# SIG # End signature block
