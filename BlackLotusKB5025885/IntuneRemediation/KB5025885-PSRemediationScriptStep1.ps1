<# 
    Gary Blok & Mike Terrill
    KB5025885 Remediation Script
    Part 1 of 4
#>

function Set-PendingUpdate {
    # Set the registry key to indicate a pending update
    $RebootRequiredPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if (-not (Test-Path $RebootRequiredPath)) {New-Item -Path $RebootRequiredPath -Force | Out-Null}
    # Create a value to indicate a pending update
    New-ItemProperty -Path $RebootRequiredPath -Name "UpdatePending" -Value 1 -PropertyType DWord -Force | Out-Null

    # Set the orchestrator key to 15
    $OrchestratorPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator"
    New-ItemProperty -Path $OrchestratorPath -Name "ShutdownFlyoutOptions" -Value 10 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $OrchestratorPath -Name "EnhancedShutdownEnabled" -Value 1 -PropertyType DWord -Force | Out-Null

    $RebootDowntimePath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\RebootDowntime"
    New-ItemProperty -Path $RebootDowntimePath -Name "DowntimeEstimateHigh" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $RebootDowntimePath -Name "DowntimeEstimateLow" -Value 1 -PropertyType DWord -Force | Out-Null
}

#Region Applicability
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#April 2024 UBRs
$AprilPatch = @('19044.4291','19045.4291','22631.3447','22621.3447','22000.2899', '26100.1150', '26120.1')
$MatchedPatch = $AprilPatch | Where-Object {$_ -match $Build}
[int]$MatchedUBR = $MatchedPatch.split(".")[1]

if ($UBR -ge $MatchedUBR){
    #$OSSupported = $true
}
else {
    #$OSSupported = $false
    Write-Output "The OS is not supported for this remediation."
    exit 4
}
if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
    #This is required for remediation to work
}
else {
    Write-Output "Secure Boot is not enabled."
    exit 5
}
#endregion Applicability


$SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$RemediationsRegPath = 'HKLM:\SOFTWARE\Remediations\KB5025885'
if (-not (Test-Path -Path $RemediationsRegPath)){
    New-Item -Path $RemediationsRegPath -Force -ItemType Directory | Out-Null
}
$RebootCount = (Get-Item -Path $RemediationsRegPath -ErrorAction SilentlyContinue).GetValue('RebootCount')
if ($null -eq $RebootCount){
    $RebootCount = 0
}

#region Test if Remediation is already applied for each Step
#Test: Applying the DB update
$Step1Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'

#endregion Test if Remediation is already applied for each Step

#region Remediation
if ($Step1Complete -eq $true -and $RebootCount -ne 1){
    Write-Output "The remediation is already applied."
}
else {
    Write-Output "The remediation is not applied."
    #Region Do Step 1 - #Applying the DB update
    if ($Step1Complete -ne $true){
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x40 -Force
        New-ItemProperty -Path $RemediationsRegPath -Name "RebootCount" -PropertyType dword -Value 1 -Force
        Set-PendingUpdate
    }
    if ($Step1Complete -eq $true){
        if ($RebootCount -eq 1 -or $RebootCount -eq 0){
            New-ItemProperty -Path $RemediationsRegPath -Name "RebootCount" -PropertyType dword -Value 2 -Force
            New-ItemProperty -Path $RemediationsRegPath -Name  "Step1Success" -PropertyType dword -Value 1 -Force
            Set-PendingUpdate
        }
        else {
            New-ItemProperty -Path $RemediationsRegPath -Name  "Step1Success" -PropertyType dword -Value 1 -Force
        }
    }
    #endregion Do Step 1 - #Applying the DB update
}

#endregion Remediation