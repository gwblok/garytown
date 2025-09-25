<# 
    Gary Blok & Mike Terrill
    KB5025885 Remediation Script-Intune
    Step 3 of 4
    Version: 25.09.25
#>

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

#Region Applicability
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#July 2025 UBRs
$JulyPatch = @('19045.6093','22621.5624','22631.5624','26100.4652','26200.4652')
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
$RemediationRegPath = 'HKLM:\SOFTWARE\Remediations\KB5025885'
if (-not (Test-Path -Path $RemediationRegPath)){
    New-Item -Path $RemediationRegPath -Force -ItemType Directory | Out-Null
}
if (Test-Path -Path $RemediationRegPath){
    $Step1Success = (Get-Item -Path $RemediationRegPath -ErrorAction SilentlyContinue).GetValue('Step1Success')
    $RebootCount = (Get-Item -Path $RemediationRegPath -ErrorAction SilentlyContinue).GetValue('RebootCount')
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
New-ItemProperty -Path $RemediationRegPath -Name "Step3RemediationTime" -Value $DetectionTime -PropertyType String -Force | Out-Null




if ($OSSupported -eq $true){

    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
    $RemediationRegPath = 'HKLM:\SOFTWARE\Remediation\KB5025885'
    if (-not (Test-Path -Path $RemediationRegPath)){
        New-Item -Path $RemediationRegPath -Force -ItemType Directory | Out-Null
    }
    $RebootCount = (Get-Item -Path $RemediationRegPath -ErrorAction SilentlyContinue).GetValue('RebootCount')
    if ($null -eq $RebootCount){
        $RebootCount = 0
    }
    
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
    if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true -and $RebootCount -ne 5){
        Write-Output "The remediation is already applied."
    }

    else {
        Write-Output "The remediation is not applied."
        #Region Do Step 1 - #Applying the DB update
        if ($Step1Complete -ne $true){
            New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x40 -Force
            New-ItemProperty -Path $RemediationRegPath -Name "RebootCount" -PropertyType dword -Value 1 -Force
        }
        if ($Step1Complete -eq $true){
            if ($RebootCount -eq 1){
                New-ItemProperty -Path $RemediationRegPath -Name "RebootCount" -PropertyType dword -Value 2 -Force
                New-ItemProperty -Path $RemediationRegPath -Name  "Step1Success" -PropertyType dword -Value 1 -Force
            }
        }
        #endregion Do Step 1 - #Applying the DB update

        #region Do Step 2 - #Updating the boot manager
        if ($Step1Complete -eq $true -and $Step2Complete -ne $true){
            if ($RebootCount -eq 2){
                New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x100 -Force
                New-ItemProperty -Path $RemediationRegPath -Name  "RebootCount" -PropertyType dword -Value 3 -Force
            }
        }
        if ($Step2Complete -eq $true){
            if ($RebootCount -eq 3){
                New-ItemProperty -Path $RemediationRegPath -Name "RebootCount" -PropertyType dword -Value 4 -Force
                New-ItemProperty -Path $RemediationRegPath -Name  "Step2Success" -PropertyType dword -Value 1 -Force
            }
        }
        #endregion Do Step 2 - #Updating the boot manager

        #region Do Step 3 - #Applying the DBX update
        if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -ne $true){
            if ($RebootCount -eq 4){
                New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x80 -Force
                New-ItemProperty -Path $RemediationRegPath -Name  "RebootCount" -PropertyType dword -Value 5 -Force
            }
        }
        if ($Step3Complete -eq $true){
            if ($RebootCount -eq 5){
                New-ItemProperty -Path $RemediationRegPath -Name "RebootCount" -PropertyType dword -Value 6 -Force
                New-ItemProperty -Path $RemediationRegPath -Name  "Step3Success" -PropertyType dword -Value 1 -Force
            }
        }
        #endregion Do Step 3 - #Applying the DBX update
    }
    #endregion Remediation
    
} #Supported OS -eq $true
else {
    Write-Output "The OS is not supported for this remediation."
}
