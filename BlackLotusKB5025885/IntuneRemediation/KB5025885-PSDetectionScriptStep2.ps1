
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
$SecureBootKey = Get-Item -Path $SecureBootRegPath
$SecureBootRegValue = $SecureBootKey.GetValue("AvailableUpdates")
$RemediationRegPath = 'HKLM:\SOFTWARE\Remediations\KB5025885'
if (Test-Path -Path $RemediationRegPath){
    $Key = Get-Item -Path $RemediationRegPath
    $Step2Success = ($Key).GetValue('Step2Success')
    $RebootCount = ($Key).GetValue('RebootCount')
}
else{
    New-Item -Path $RemediationRegPath -Force -ItemType Directory | Out-Null
}
if ($null -ne $Step2Success){
    if ($Step2Success -eq 1){
        $Step2Success = $true
    }
    else {
        $Step2Success = $false
    }
}
if ($null -eq $RebootCount){
    $RebootCount = 0
}
#TimeStamp when Detection last Ran
$DetectionTime = Get-Date -Format "yyyyMMddHHmmss"
New-ItemProperty -Path $RemediationRegPath -Name "Step2DetectionTime" -Value $DetectionTime -PropertyType String -Force | Out-Null

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
#If all 3 steps are complete, remediation is not needed, exit 

#Yes we're only doing the first 2 steps, but if the 3rd is done, I can assume the reboots are complete.
if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true){
    Write-Output "Step 2 Complete | SBKey: $SecureBootRegValue"
    exit 0
}
#If we detect steps are done, and we stamped the registry, we can assume the reboots are complete and we're good
if ($Step1Success -eq $true -and $Step1Complete -eq $true -and $Step2Success -eq $true -and $Step2Complete -eq $true){
    Write-Output "Step 2 Complete | SBKey: $SecureBootRegValue"
    exit 0
}
#If Steps 1 & 2 are complete, and we're on reboot 4, all is well, exit 0
if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $RebootCount -ge 4){
    Write-Output "Step 2 Complete | SBKey: $SecureBootRegValue"
    exit 0
}
#If Steps 1 & 2 are complete, and we're on less than 4 reboots, we probably need another reboot.
if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $RebootCount -lt 4){
    Write-Output "Step 1 - Cert Found & Step 2 - Boot Manager Updated, but Reboot less than 4: Needs Remediation (another reboot) | SBKey: $SecureBootRegValue"
    exit 1
}
#if Step 1 or 2 are not complete, remediation is needed, exit 1
if ($Step1Complete -ne $true){

    Write-Output "Step 1 - 2023 Cert Not Found in DB: Needs Remediation | SBKey: $SecureBootRegValue"
    exit 1
}
if ($Step2Complete -ne $true){

    Write-Output "Step 2 - Boot Manager Not Updated: Needs Remediation | SBKey: $SecureBootRegValue"
    exit 1
}

#endregion Remediation
    
