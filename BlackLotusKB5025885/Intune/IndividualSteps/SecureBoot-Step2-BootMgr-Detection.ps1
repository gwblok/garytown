<# 
    Gary Blok & Mike Terrill
    KB5025885 Detection Script-Intune
    Step 2 of 4
    Version: 25.09.25
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
    exit 5
}
if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
    #This is required for remediation to work
}
else {
    Write-Output "Secure Boot is not enabled."
    exit 4
}



$SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$SecureBootKey = Get-Item -Path $SecureBootRegPath
$SecureBootRegValue = $SecureBootKey.GetValue("AvailableUpdates")

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

#Creating Mapping from $true or $false to 'Present' or 'Missing' for easier readability in outputs
$Win2023Status = if ($Win2023Present) {"Present"} else {"Missing"}
$MSKEKStatus = if ($MSKEKPresent) {"Present"} else {"Missing"}
$MSCA2023Status = if ($MSCA2023Present) {"Present"} else {"Missing"}
$OptionROM2023Status = if ($OptionROM2023Present) {"Present"} else {"Missing"} 
#If Step1 or 2 Not Complete, exit 1
if ($Step1Complete -eq $false){
    Write-Output "Not up to date - missing Pre-Req | Win2023: $Win2023Status | MSKEK: $MSKEKStatus | MSCA2023: $MSCA2023Status | OptionROM2023: $OptionROM2023Status "
    exit 1
}
if ($Step2Complete -eq $false){
    Write-Output "Not up to date - missing boot manager update"
    exit 1
}