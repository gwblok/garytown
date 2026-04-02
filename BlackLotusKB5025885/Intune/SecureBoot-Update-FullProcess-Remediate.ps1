<# 
Gary Blok & Mike Terrill
KB5025885 Detection Script
Version: 26.04.02

Changes
- Updated applicability checks to match the latest UBR requirements for the March 2026 update
- Updated output messages to be more user friendly and informative about the status of the remediation
- Added more detailed comments throughout the script for clarity
- Added Step 4 (SVN Update) Detection & Remediation options


#>

#Control the Remediation Process
$EnableStep1 = $true #Certificate Updates
$EnableStep2 = $true #Boot Manager Update
$EnableStep3 = $false #DBX Update - OPTIONAL - This will revoke the 2011 Compromised Certificate, but also potentially make your life harder.
$EnableStep4 = $false #Enable the SVN to highest Level (Use Get-SecureBootSVN to check current level) - OPTIONAL - This will prevent any rollback of the Boot Manager, but also potentially make your life harder if you have any issues with the new Boot Manager and need to roll back.   

#This function sets the registry keys to indicate a pending update (orange circle in the shutdown flyout)
#region functions
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
    $RebootRequired = $false
    if ($TaskHistory.LastTaskResult -eq 0) {
        $LastTaskResultDescription = "Successfully completed"
    }
    elseif ($TaskHistory.LastTaskResult -eq 2147942750) {
        $LastTaskResultDescription = "No action was taken as a system reboot is required."
        $RebootRequired = $true
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
        RebootRequired = $RebootRequired
    }
}

#Function to help indicate a pending update
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
#endregion functions   

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

#Test: Applying the DB certificate updates (Step 1)
#Individual Cert Results Confirmation - Applying the DB updates
$MSKEKPresent = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI kek).bytes) -match 'Microsoft Corporation KEK 2K CA 2023'
if ($MSKEKPresent -eq $false){$Step1Compliance = $false}
$MSCA2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft UEFI CA 2023'
if ($MSCA2023Present -eq $false){$Step1Compliance = $false}
$OptionROM2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft Option ROM UEFI CA 2023'
if ($OptionROM2023Present -eq $false){$Step1Compliance = $false}
$Win2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
if ($Win2023Present -eq $false){$Step1Compliance = $false}
$Step1Complete = $Step1Compliance

#Test: Updating the boot manager (Step 2)
$Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
$SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
$SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
$SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
$FilePath = "$($SystemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi"
$CertCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$CertCollection.Import($FilePath, $null, 'DefaultKeySet')
If ($CertCollection.Subject -like "*Windows UEFI CA 2023*") {$Step2Complete = $true}
else {$Step2Complete = $false}

#Test: Applying the DBX update (Step 3)
$Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'

#Test: Checking Current SVN against the highest level (Step 4)

if ($EnableStep4 -eq $true){
    $Step4Complete = $false
    try {
        if (Get-Command -Name Get-SecureBootSVN -ErrorAction SilentlyContinue) {
            $CurrentSVN = Get-SecureBootSVN
            #Write-Output "Current Secure Boot SVN: "
            if ($CurrentSVN.FirmwareSVN -eq $CurrentSVN.BootManagerSVN){
                $Step4Complete = $true
            }
        }
        else {
            Write-Error "Unable to retrieve current Secure Boot SVN." 
        } 
    }
    catch {
        Write-Error "Unable to retrieve current Secure Boot SVN." 
    }
}
#endregion Test if Remediation is already applied for each Step

#Confirm Applicability for Remediation, to confirm which steps are needed, This will ensure previous steps are complete before moving ahead.
if ($Step1Complete -eq $true){
    $LastStepComplete = 1
}
else {
    $LastStepComplete = 0
}
if ($Step2Complete -eq $true -and $LastStepComplete -eq 1){
    $LastStepComplete = 2
}
if ($Step3Complete -eq $true -and $LastStepComplete -eq 2){
    $LastStepComplete = 3
}
if ($Step4Complete -eq $true -and $LastStepComplete -eq 3){
    $LastStepComplete = 4
}

#region Remediation

#Report This Info to Intune Process:
Write-Output "StepComplete: $LastStepComplete | SBKey: $SecureBootRegValue | PI: $((Get-SecureBootUpdateSTaskStatus).LastTaskDescription)"

#If we detect that the scheduled task is already waiting a pending reboot, no point doing anything else, just Set-PendingUpdate and exit
if ((Get-SecureBootUpdateSTaskStatus).LastTaskResult -eq 2147942750){
    Write-Error "Secure Boot Update Task is already waiting for a reboot"
    Set-PendingUpdate
    exit 0
}

if ($LastStepComplete -eq 0 -or $Step1Compliance -eq $false){
    if ($EnableStep1){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x1844 -Force
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
        Start-Sleep -Seconds 10
        $GetTaskResults = Get-SecureBootUpdateSTaskStatus
        if ($GetTaskResults.RebootRequired){
            Set-PendingUpdate
        }
        Write-Error "Setting Value for Step 1 | 0x1844"
    }
    else{
        Write-Error "Step 1 is not enabled for remediation"
    }
    exit 0
}
#If the first 2 steps are complete, remediation is needed, exit 
if ($LastStepComplete -eq 1){
    if ($EnableStep2){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x1944 -Force
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
        Start-Sleep -Seconds 10
        $GetTaskResults = Get-SecureBootUpdateSTaskStatus
        if ($GetTaskResults.RebootRequired){
            Set-PendingUpdate
        }
        Write-Error "Setting Value for Step 2 | 0x1944"
    }
    else{
        Write-Error "Step 2 is not enabled for remediation"
    }
    exit 0
}
if ($LastStepComplete -eq 2){
    if ($EnableStep3){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x80 -Force
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
        Start-Sleep -Seconds 10
        $GetTaskResults = Get-SecureBootUpdateSTaskStatus
        if ($GetTaskResults.RebootRequired){
            Set-PendingUpdate
        }
        Write-Error "Setting Value for DBX Update (Step 3) | 0x80"
    }
    else{
        Write-Error "Step 3 is not enabled for remediation"
    }
    exit 0
}
if ($LastStepComplete -eq 3){
    if ($EnableStep4){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x200 -Force
        Write-Error "Running Remediation for SVN Update (Step 4)"
        exit 3
    }
    else{
        Write-Error "SVN Update (Step 4) is not enabled for remediation"
        exit 0
    }
}
if ($LastStepComplete -eq 4){
    Write-Error "Secure Boot Updates Complete - No Remediation Needed"
    exit 0
}
#endregion Detection
