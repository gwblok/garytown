<# 
    Gary Blok & Mike Terrill
    KB5025885 Detection Script
    Version: 25.05.13
#>

#Control the Remediation Process
$EnableStep1 = $true
$EnableStep2 = $true
$EnableStep3 = $false


#Test if Remediation is applicable
#Region Applicability
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#July 2024 UBRs
$JulyPatch = @('19045.4651','22621.3880','22631.3880','26100.1150','26120.1','26200.1')
$MatchedPatch = $JulyPatch | Where-Object {$_ -match $Build}
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

if ($StepsComplete -eq 0){
    if ($EnableStep1){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x40 -Force
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
        Start-Sleep -Seconds 1
        Set-PendingUpdate
        Write-Error "Setting Value for Step 1 | 0x40"
    }
    else{
        Write-Error "Step 1 is not enabled for remediation"
    }
    exit 0
}
#If the first 2 steps are complete, remediation is needed, exit 
if ($StepsComplete -eq 1){
    if ($EnableStep2){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x100 -Force
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
        Start-Sleep -Seconds 1
        Set-PendingUpdate
        Write-Error "Setting Value for Step 2 | 0x100"
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
