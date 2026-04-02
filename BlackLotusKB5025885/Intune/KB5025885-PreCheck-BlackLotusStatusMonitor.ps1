<#
    Gary Blok & Mike Terrill
    KB5025885 Monitoring Only Script-Intune
    Version: 26.04.01

    Changes
    - Updated applicability checks to match the latest UBR requirements for the March 2026 update
    - Updated output messages to be more user friendly and informative about the status of the remediation
    - Added more detailed comments throughout the script for clarity
    - Updated for the 4 certs vs the 1 cert


This is a monitoring script for the remediation of KB5025885
This will not make any changes, but only report on the status of the remediation for KB5025885
It will exit with different error codes based on the status of the remediation

0 = Remediation is not required (Already Complete)
1 = Step 1 is not complete "Install the updated certificates definitions to the DB & KEK"
2 = Step 2 is not complete "Update the Boot Manager on your device."
3 = Step 3 is not complete "Enable the revocation."
4 = SecureBoot is not enabled
5 = Windows Version needs to be updated first

#https://support.microsoft.com/en-us/topic/how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d

# Step Results Matrix:
#              Col1    Col2    Col3    Col4    Col5    Col6    Col7    Col8
# Step 1       Fail    Pass    Fail    Pass    Fail    Pass    Fail    Pass
# Step 2       Fail    Fail    Pass    Pass    Pass    Pass    Pass    Pass
# Step 3       Fail    Fail    Fail    Fail    Pass    Pass    Pass    Pass
# Step 4       Fail    Fail    Fail    Fail    Fail    Fail    Pass    Pass
#
# Overall      Fail    Fail    Fail    **Pass  Fail    *Pass   Fail    Pass
#
# Output       Fail    Step 2  Step 1  Step 3  Step 1  Step 4  Step 1  Pass
#                      Incomp  Incomp  Incomp  Incomp  Incomp  Incomp
#
#              Not up                  **Up                    *Up             Up to
#              to date                 to date                 to date         date
#
# Output options:
# Not up to date - missing everything
# Not up to date - missing certificates
# Not up to date - missing boot manager
# **Up to date - missing revocation & SVN
# *Up to date - missing SVN
# Up to date - everything complete
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

#Step1 | The Certificates
$Step1Compliance = $true
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

#Step 2 | test: Updating the boot manager
$Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
$SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
$SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
$SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
$FilePath = "$($SystemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi"
$CertCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$CertCollection.Import($FilePath, $null, 'DefaultKeySet')
If ($CertCollection.Subject -like "*Windows UEFI CA 2023*") {$Step2Complete = $true}
else {$Step2Complete = $false}

#Step 3 | test: Applying the DBX update for the Microsoft Windows Production PCA 2011 revocation
$Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'

$SVN = Get-SecureBootSVN -ErrorAction Continue
if ($null -ne $SVN){
    $Step4Complete = if ($SVN.FirmwareSVN -eq $SVN.BootManagerSVN){$true} else {$false}
}
else {
    $Step4Complete = $false
}

#endregion Test if Remediation is already applied for each Step

$Win2023Status = if ($Win2023Present) {"Present"} else {"Missing"}
$MSKEKStatus = if ($MSKEKPresent) {"Present"} else {"Missing"}
$MSCA2023Status = if ($MSCA2023Present) {"Present"} else {"Missing"}
$OptionROM2023Status = if ($OptionROM2023Present) {"Present"} else {"Missing"} 

#Write the Output based on the results of the tests above using the Chart from the matrix above
if ($Step1Complete -and $Step2Complete -and $Step3Complete -and $Step4Complete) {
    Write-Output "Up to date - everything complete"
    exit 0
}
elseif ($Step1Complete -and $Step2Complete -and $Step3Complete -and -not $Step4Complete) {
    Write-Output "*Up to date (Certs, BootMgr & Revocation) - missing SVN"
    exit 0
}
elseif ($Step1Complete -and $Step2Complete -and -not $Step3Complete) {
    Write-Output "**Up to date (Certs & BootMgr) - missing revocation & SVN"
    exit 3
}
elseif ($Step1Complete -and -not $Step2Complete) {
    Write-Output "Not up to date (Certs) - missing boot manager, revocation & SVN"
    exit 2
}
elseif (-not $Step1Complete -and -not $Step2Complete -and -not $Step3Complete -and -not $Step4Complete) {
    Write-Output "Not up to date - missing everything | Win2023: $Win2023Status | MSKEK: $MSKEKStatus | MSCA2023: $MSCA2023Status | OptionROM2023: $OptionROM2023Status  "
    exit 1
}
else {
    Write-Output "Not up to date - missing certificates | Win2023: $Win2023Status | MSKEK: $MSKEKStatus | MSCA2023: $MSCA2023Status | OptionROM2023: $OptionROM2023Status "
    exit 1
}
