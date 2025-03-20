
#Test if Remediation is applicable
#Region Applicability
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#April 2024 UBRs
$AprilPatch = @('19044.4291','19045.4291','22631.3447','22621.3447','22000.2899', '26100.1150','26120.1')
$MatchedPatch = $AprilPatch | Where-Object {$_ -match $Build}
[int]$MatchedUBR = $MatchedPatch.split(".")[1]

if ($UBR -ge $MatchedUBR){
    $OSSupported = $true
}
else {
    $OSSupported = $false
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


#$SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$RemediationRegPath = 'HKLM:\SOFTWARE\Remediation\KB5025885'
if (-not (Test-Path -Path $RemediationRegPath)){
    New-Item -Path $RemediationRegPath -Force -ItemType Directory | Out-Null
}
if (Test-Path -Path $RemediationRegPath){
    $Step3Success = (Get-Item -Path $RemediationRegPath -ErrorAction SilentlyContinue).GetValue('Step3Success')
    $RebootCount = (Get-Item -Path $RemediationRegPath -ErrorAction SilentlyContinue).GetValue('RebootCount')
}
if ($null -ne $Step3Success){
    if ($Step3Success -eq 1){
        $Step3Success = $true
    }
    else {
        $Step3Success = $false
    }
}
if ($null -eq $RebootCount){
    $RebootCount = 0
}
#TimeStamp when Detection last Ran
$DetectionTime = Get-Date -Format "yyyyMMddHHmmss"
New-ItemProperty -Path $RemediationRegPath -Name "Step3DetectionTime" -Value $DetectionTime -PropertyType String -Force | Out-Null

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
if ($Step1Complete -ne $true -or $Step2Complete -ne $true -or $Step3Complete -ne $true){
        Write-Output "Needs Remediation"
        exit 1
}
if ($null -eq $RebootCount){
    if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true){
        Write-Output "The remediation is already applied."
        exit 0
    }
    else {
        Write-Output "Needs Remediation"
        exit 1
    }
}
else {
    if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true -and $RebootCount -eq 5){
        Write-Output "Needs Remediation to update Registry Values"
        exit 1
    }
}

#endregion Remediation
