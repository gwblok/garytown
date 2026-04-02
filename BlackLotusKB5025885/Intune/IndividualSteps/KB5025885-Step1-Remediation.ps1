<# 
    Gary Blok & Mike Terrill
    KB5025885 Remediation Script-Intune
    Step 1 of 4
    Version: 26.04.01
    Changes
    - Updated applicability checks to match the latest UBR requirements for the March 2026 update
    - Updated output messages to be more user friendly and informative about the status of the remediation
    - Added more detailed comments throughout the script for clarity
    - Updated for the 4 certs vs the 1 cert
#>

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

#Individual Cert Results Confirmation - Applying the DB updates
$MSKEKPresent = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI kek).bytes) -match 'Microsoft Corporation KEK 2K CA 2023'
if ($MSKEKPresent -eq $false){$Step1Compliance = $false}
$MSCA2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft UEFI CA 2023'
if ($MSCA2023Present -eq $false){$Step1Compliance = $false}
$OptionROM2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Microsoft Option ROM UEFI CA 2023'
if ($OptionROM2023Present -eq $false){$Step1Compliance = $false}
$Win2023Present = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
if ($Win2023Present -eq $false){$Step1Compliance = $false}



if ($Step1Compliance -eq $false){
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x1844 -Force
    Start-Sleep -Seconds 1
    Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
    Start-Sleep -Seconds 1
    Set-PendingUpdate
    Write-Error "Setting Value for Step 1 | 0x1844"
}
