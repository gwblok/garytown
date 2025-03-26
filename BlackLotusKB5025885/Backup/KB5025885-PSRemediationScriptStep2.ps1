<# 
    Gary Blok & Mike Terrill
    KB5025885 Remediation Script
    Part 2 of 4
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
    Write-Output "The OS ($Build.$UBR) is not supported for this remediation."
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
$SecureBootKey = Get-Item -Path $SecureBootRegPath
$SecureBootRegValue = $SecureBootKey.GetValue("AvailableUpdates")
$RemediationRegPath = 'HKLM:\SOFTWARE\Remediation\KB5025885'
if (Test-Path -Path $RemediationRegPath){
    $Key = Get-Item -Path $RemediationRegPath
    $Step1Success = ($Key).GetValue('Step1Success')
    $RebootCount = ($Key).GetValue('RebootCount')
    $Step2RemRunCount = ($Key).GetValue('Step2RemRunCount')
    $Step2Set0x100 = ($Key).GetValue('Step2Set0x100') 
    if ($null -eq $Step2RemRunCount){$Step2RemRunCount = 0}   
    New-ItemProperty -Path $RemediationRegPath -Name "Step2RemRunCount" -Value ($Step2RemRunCount + 1) -PropertyType DWord -Force | Out-Null
}
else{
    New-Item -Path $RemediationRegPath -Force -ItemType Directory | Out-Null
}
if ($null -ne $Step1Success){
    if ($Step1Success -eq 1){
        $Step1Success = $true
    }
    else {
        $Step1Success = $false
    }
}
if ($null -eq $RebootCount){
    $RebootCount = 0
}
$DetectionTime = Get-Date -Format "yyyyMMddHHmmss"
New-ItemProperty -Path $RemediationRegPath -Name "Step2RemediationTime" -Value $DetectionTime -PropertyType String -Force | Out-Null

#region Test if Remediation is already applied for each Step
#Test: Applying the DB update
$Step1Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'

#Test: Updating the boot manager
$Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
$SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
$SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
$SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
$FilePath = "$($SystemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi"
$CertCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$CertCollection.Import($FilePath, $null, 'DefaultKeySet')
If ($CertCollection.Subject -like "*Windows UEFI CA 2023*") {$Step2Complete = $true}
else {$Step2Complete = $false}

#Test: Applying the DBX update
$Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'

#endregion Test if Remediation is already applied for each Step

#region Remediation
if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $RebootCount -ge 4){
    Write-Output "Step 2 Complete | SBKey: $SecureBootRegValue"
}

else {
    Write-Output "The remediation is not applied | SBKey: $SecureBootRegValue"
    #Region Do Step 1 - #Applying the DB update
    # I decided I don't want Step 2 to try to deal with Step 1 not being done.  So, I removed this logic.
    <#
    if ($Step1Complete -ne $true){
        
        Write-Output "Applying remediation | Setting Secure Boot Key to 0x40 & RebootCount to 1"
        New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x40 -Force
        New-ItemProperty -Path $RemediationRegPath -Name "RebootCount" -PropertyType dword -Value 1 -Force
        if ($null -eq $Step1Set0x40){
            New-ItemProperty -Path $RemediationRegPath -Name "Step1Set0x40" -PropertyType string -Value $DetectionTime -Force
        }
    }
    else {
        if ($RebootCount -eq 1){
            Write-Output "Applying remediation | Setting Step1Success to 1 & RebootCount to 2"
            New-ItemProperty -Path $RemediationRegPath -Name "RebootCount" -PropertyType dword -Value 2 -Force
            New-ItemProperty -Path $RemediationRegPath -Name  "Step1Success" -PropertyType dword -Value 1 -Force
        }
        else {
            if ($Step1Success -ne 1){
                Write-Output "Applying remediation | Setting Step1Success to 1"
                New-ItemProperty -Path $RemediationRegPath -Name  "Step1Success" -PropertyType dword -Value 1 -Force
            }
        }
    }
    #>

    #region Do Step 2 - #Updating the boot manager
    if ($Step1Complete -eq $true -and $Step2Complete -ne $true){
        if ($RebootCount -eq 2){
            Write-Output "Applying remediation | Setting Secure Boot Key to 0x100 & RebootCount to 3"
            New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x100 -Force
            if ($null -eq $Step2Set0x100){
                New-ItemProperty -Path $RemediationRegPath -Name "Step2Set0x100" -PropertyType string -Value $DetectionTime -Force
            }
            New-ItemProperty -Path $RemediationRegPath -Name  "RebootCount" -PropertyType dword -Value 3 -Force
        }
        else {
            Write-Output "Applying remediation | Setting Reboot Count to 2"
            New-ItemProperty -Path $RemediationRegPath -Name  "RebootCount" -PropertyType dword -Value 2 -Force
        }
    }
    if ($Step2Complete -eq $true){
        if ($RebootCount -in (0,1,2,3)){
            Write-Output "Applying remediation | Setting Step2Success to 1 & RebootCount to 4"
            New-ItemProperty -Path $RemediationRegPath -Name "RebootCount" -PropertyType dword -Value 4 -Force
            New-ItemProperty -Path $RemediationRegPath -Name  "Step2Success" -PropertyType dword -Value 1 -Force
        }
        else {
            Write-Output "Applying remediation | Setting Step2Success to 1"
            New-ItemProperty -Path $RemediationRegPath -Name  "Step2Success" -PropertyType dword -Value 1 -Force
        }
    }
    #endregion Do Step 2 - #Updating the boot manager
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
    $SecureBootKey = Get-Item -Path $SecureBootRegPath
    $SecureBootRegValue = $SecureBootKey.GetValue("AvailableUpdates")
    $RemediationRegPath = 'HKLM:\SOFTWARE\Remediations\KB5025885'
    Write-Output "SBKey: $SecureBootRegValue"
}
#endregion Remediation

