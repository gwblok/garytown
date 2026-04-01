<#
    Gary Blok & Mike Terrill
    KB5025885 Monitoring Only Script-Intune
    Version: 25.09.25

This is a monitoring script for the remediation of KB5025885
This will not make any changes, but only report on the status of the remediation for KB5025885
It will exit with different error codes based on the status of the remediation

0 = Remediation is not required (Already Complete)
1 = Step 1 is not complete "Install the updated certificate definitions to the DB"
2 = Step 2 is not complete "Update the Boot Manager on your device."
3 = Step 3 is not complete "Enable the revocation."
4 = SecureBoot is not enabled
5 = Windows Version needs to be updated first

#https://support.microsoft.com/en-us/topic/how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d
#>

#Test if Remediation is applicable
#Region Applicability
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#March 2026 UBRs
$MinimumPatch = @('19045.7058','22631.6783','26100.8037','26200.8037','26300.8037')
$MatchedPatch = $MinimumPatch | Where-Object {$_ -match $Build}
if ($null -eq $MatchedPatch){
    Write-Output "The OS ($Build.$UBR) is not supported for this remediation."
    Write-Error "Exit 5 - OS Version not supported"
    exit 5
}
[int]$MatchedUBR = $MatchedPatch.split(".")[1]

if ($UBR -ge $MatchedUBR){
    #$OSSupported = $true
}
else {
    #$OSSupported = $false
    Write-Output "The OS ($Build.$UBR) is not supported for this remediation."
    Write-Error "Exit 5 - OS Version not supported"
    exit 5
}
if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
    #This is required for remediation to work
}
else {
    Write-Output "Secure Boot is not enabled."
    Write-Error "Exit 4 - Secure Boot is not enabled"
    exit 4
}

#endregion Applicability

#Registry Keys for Remediation
$SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$SecureBootKey = Get-Item -Path $SecureBootRegPath
$SecureBootRegValue = $SecureBootKey.GetValue("AvailableUpdates")

#region Test if Remediation is already applied for each Step
Function Get-WindowsUEFICA2023Capable{
    try {
        $SecureBootServicing = Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' -ErrorAction Stop
        $WindowsUEFICA2023Capable = $SecureBootServicing.GetValue('WindowsUEFICA2023Capable')
    }
    catch {return 0}
    if ($WindowsUEFICA2023Capable) {
        return $WIndowsUEFICA2023Capable
    }
    else  {return 0}
}

Function Get-SecureBootUpdateSTaskStatus{#Check to see if a reboot is required
    [CmdletBinding()]
    param ()
    $taskName = "Secure-Boot-Update"
    $Task = Get-ScheduledTask -TaskName $TaskName
    if ($null -eq $Task) {
        Write-Verbose "Scheduled Task '$TaskName' not found."
        return $null
    }
    $TaskHistory = Get-ScheduledTaskInfo -InputObject $Task
    $LastRunTime = $TaskHistory.LastRunTime
    $LastTaskResult = $TaskHistory.LastTaskResult
    if ($TaskHistory.LastTaskResult -eq 0) {
        $LastTaskResultDescription = "Successfully completed"
    }
    elseif ($TaskHistory.LastTaskResult -eq 2147942750) {
        $LastTaskResultDescription = "No action was taken as a system reboot is required."
    }
    elseif ($TaskHistory.LastTaskResult -eq 2147946825) {
        $LastTaskResultDescription = "Secure Boot is not enabled on this machine."
    }
    else {
        $LastTaskResultDescription = "Unknown error"
    }
    [PSCustomObject]@{
        TaskName       = $TaskName
        LastRunTime    = $LastRunTime
        LastTaskResult = $LastTaskResult
        LastTaskDescription = $LastTaskResultDescription
    }
}
$StepsComplete = Get-WindowsUEFICA2023Capable
$Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'

#Individual Cert Results Confirmation - Applying the DB updates
$MSKEKPresent = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI kek).bytes) -match 'Microsoft Corporation KEK 2K CA 2023'
if ($MSKEKPresent -eq $false){$Step1Compliance = $false}
$MSCA2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft UEFI CA 2023'
if ($MSCA2023Present -eq $false){$Step1Compliance = $false}
$OptionROM2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft Option ROM UEFI CA 2023'
if ($OptionROM2023Present -eq $false){$Step1Compliance = $false}
$Win2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
if ($Win2023Present -eq $false){$Step1Compliance = $false}

#endregion Test if Remediation is already applied for each Step

#Check for Step Completion, and also report the current value of the Secure Boot Key

if ($StepsComplete -lt 1 -or $Step1Compliance -eq $false){
    Write-Output "Step 1 is not complete | SBKey: $SecureBootRegValue | $((Get-SecureBootUpdateSTaskStatus).LastTaskDescription)"
    Write-Error "Step 1 Required (Adding Certs) | SecureBoot Registry Key Value: $SecureBootRegValue | Secure Boot Update Scheduled Task last Result $((Get-SecureBootUpdateSTaskStatus).LastTaskResult)"
    if ($MSKEKPresent -eq $false){Write-Output "  Microsoft Corporation KEK 2K CA 2023 is not present in the KEK Store"}
    if ($MSCA2023Present -eq $false){Write-Output "  Microsoft UEFI CA 2023 is not present in the DB Store"}
    if ($OptionROM2023Present -eq $false){Write-Output "  Microsoft Option ROM UEFI CA 2023 is not present in the DB Store"}
    if ($Win2023Present -eq $false){Write-Output "  Windows UEFI CA 2023 is not present in the DB Store"}

    exit 1
}
if ($StepsComplete -lt 2){
    Write-Output "Step 2 is not complete | SBKey: $SecureBootRegValue | $((Get-SecureBootUpdateSTaskStatus).LastTaskDescription)"
    Write-Error "Step 2 Required (Updating Boot Manager) | SecureBoot Registry Key Value: $SecureBootRegValue | Secure Boot Update Scheduled Task last Result $((Get-SecureBootUpdateSTaskStatus).LastTaskResult)"
    exit 2
}
if ($Step3Complete -ne $true){
    Write-Output "Step 3 is not complete | SBKey: $SecureBootRegValue | $((Get-SecureBootUpdateSTaskStatus).LastTaskDescription)"
    Write-Error "Step 3 Required (Revoking the 2011 Cert) | SecureBoot Registry Key Value: $SecureBootRegValue | Secure Boot Update Scheduled Task last Result $((Get-SecureBootUpdateSTaskStatus).LastTaskResult)"
    exit 3
}
if ($Step3Complete -eq $true){
    Write-Output "KB5025885 Complete"
    exit 0
}
