<# 
    Gary Blok & Mike Terrill
    KB5025885 Detection Script
    Version: 25.05.13

    Changes
    25.6.3 - Added Set-PendingUpdate back to script
#>

#Control the Remediation Process
$EnableStep1 = $true
$EnableStep2 = $true
$EnableStep3 = $false

#This function sets the registry keys to indicate a pending update (orange circle in the shutdown flyout)
function Set-PendingUpdate {
    # Set the registry key to indicate a pending update
    $RebootRequiredPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if (-not (Test-Path $RebootRequiredPath)) {New-Item -Path $RebootRequiredPath -Force | Out-Null}
    # Create a value to indicate a pending update
    New-ItemProperty -Path $RebootRequiredPath -Name "UpdatePending" -Value 1 -PropertyType DWord -Force | Out-Null

    # Set the orchestrator key to 15
    $OrchestratorPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator"
    if (-not (Test-Path $OrchestratorPath)) {New-Item -Path $OrchestratorPath -Force | Out-Null}
    $Values = get-item -Path $OrchestratorPath
    if (($Null -eq $Values.GetValue('ShutdownFlyoutOptions')) -or ($Values.GetValue('ShutdownFlyoutOptions') -eq 0)){
        New-ItemProperty -Path $OrchestratorPath -Name "ShutdownFlyoutOptions" -Value 10 -PropertyType DWord -Force | Out-Null
    }
    if (($Null -eq $Values.GetValue('EnhancedShutdownEnabled')) -or ($Values.GetValue('EnhancedShutdownEnabled') -eq 0)){
        New-ItemProperty -Path $OrchestratorPath -Name "EnhancedShutdownEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    }

    $RebootDowntimePath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\RebootDowntime"
    if (-not (Test-Path $RebootDowntimePath)) {New-Item -Path $RebootDowntimePath -Force | Out-Null}
    $Values = get-item -Path $RebootDowntimePath
    if (($Null -eq $Values.GetValue('DowntimeEstimateHigh')) -or ($Values.GetValue('DowntimeEstimateHigh') -eq 0)){
        New-ItemProperty -Path $RebootDowntimePath -Name "DowntimeEstimateHigh" -Value 1 -PropertyType DWord -Force | Out-Null
    }
    if (($Null -eq $Values.GetValue('DowntimeEstimateLow')) -or ($Values.GetValue('DowntimeEstimateLow') -eq 0)){
        New-ItemProperty -Path $RebootDowntimePath -Name "DowntimeEstimateLow" -Value 1 -PropertyType DWord -Force | Out-Null
    }
}

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

#Individual Cert Results Confirmation - Applying the DB updates
$MSKEKPresent = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI kek).bytes) -match 'Microsoft Corporation KEK 2K CA 2023'
if ($MSKEKPresent -eq $false){$Step1Compliance = $false}
$MSCA2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft UEFI CA 2023'
if ($MSCA2023Present -eq $false){$Step1Compliance = $false}
$OptionROM2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft Option ROM UEFI CA 2023'
if ($OptionROM2023Present -eq $false){$Step1Compliance = $false}
$Win2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
if ($Win2023Present -eq $false){$Step1Compliance = $false}

$StepsComplete = Get-WindowsUEFICA2023Capable
$Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'

$LastStepComplete = $StepsComplete
if ($Step3Complete -eq $true){$LastStepComplete = 3}
#endregion Test if Remediation is already applied for each Step

#region Remediation

#Report This Info to Intune Process:
Write-Output "StepComplete: $LastStepComplete | SBKey: $SecureBootRegValue | PI: $((Get-SecureBootUpdateSTaskStatus).LastTaskDescription)"

#If we detect that the scheduled task is already waiting a pending reboot, no point doing anything else, just Set-PendingUpdate and exit
if ((Get-SecureBootUpdateSTaskStatus).LastTaskResult -eq 2147942750){
    Write-Error "Secure Boot Update Task is already waiting for a reboot"
    Set-PendingUpdate
    exit 0
}

if ($StepsComplete -eq 0 -or $Step1Compliance -eq $false){
    if ($EnableStep1){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x1844 -Force
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
        Start-Sleep -Seconds 1
        Set-PendingUpdate
        Write-Error "Setting Value for Step 1 | 0x1844"
    }
    else{
        Write-Error "Step 1 is not enabled for remediation"
    }
    exit 0
}
#If the first 2 steps are complete, remediation is needed, exit 
if ($StepsComplete -eq 1){
    if ($EnableStep2){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x1944 -Force
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
        Start-Sleep -Seconds 1
        Set-PendingUpdate
        Write-Error "Setting Value for Step 2 | 0x1944"
    }
    else{
        Write-Error "Step 2 is not enabled for remediation"
    }
    exit 0
}
if ($StepsComplete -eq 2){
    if ($EnableStep3){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x80 -Force
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
        Start-Sleep -Seconds 1
        Set-PendingUpdate
        Write-Error "Setting Value for Step 3 | 0x80"
    }
    else{
        Write-Error "Step 3 is not enabled for remediation"
    }
    exit 0
}
if ($Step3Complete -eq $true){
    Write-Error "KB5025885 Complete - No Remediation Needed"
    exit 0
}
#endregion Detection
