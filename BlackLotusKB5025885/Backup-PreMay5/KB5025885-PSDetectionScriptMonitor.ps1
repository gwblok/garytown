<#
This is a monitoring script for the remediation of KB5025885
This will not make any changes, but only report on the status of the remediation for KB5025885
It will exit with different error codes based on the status of the remediation

0 = Remediation is not required (Already Complete)
1 = Step 1 is not complete "Install the updated certificate definitions to the DB"
2 = Step 2 is not complete "Update the Boot Manager on your device."
3 = Step 3 is not complete "Enable the revocation."
4 = SecureBoot is not enabled
5 = Windows Version needs to be updated first

#https://support.microsoft.com/en-us/topic/how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d
#>

#Test if Remediation is applicable
#Region Applicability
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#July 2024 UBRs
$JulyPatch = @('19045.4651','22621.3880','22631.3880','26100.1150','26120.1')
$MatchedPatch = $JulyPatch | Where-Object {$_ -match $Build}
if ($null -eq $MatchedPatch){
    Write-Output "The OS ($Build.$UBR) is not supported for this remediation."
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

#endregion Applicability

function Get-LastScheduledTaskResult {
    param (
        [string]$TaskName
    )

    try {
        $Task = Get-ScheduledTask -TaskName $TaskName
        if ($null -eq $Task) {
            Write-Output "Scheduled Task '$TaskName' not found."
            return $null
        }

        $TaskHistory = Get-ScheduledTaskInfo -InputObject $Task
        $LastRunTime = $TaskHistory.LastRunTime
        $LastTaskResult = $TaskHistory.LastTaskResult

        [PSCustomObject]@{
            TaskName       = $TaskName
            LastRunTime    = $LastRunTime
            LastTaskResult = $LastTaskResult
        }
    }
    catch {
        Write-Error "Error retrieving scheduled task result: $_"
    }
}

#Use Registry Keys
Function Get-WindowsUEFICA2023Capable{
    try {
        $SecureBootServicing = Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' -ErrorAction Stop
        $WindowsUEFICA2023Capable = $SecureBootServicing.GetValue('WindowsUEFICA2023Capable')
        if ($null -eq $WindowsUEFICA2023Capable) {
            $Step1 = "Non-compliant"
        }
    }
    catch {
        return 0
    }

    if ($WindowsUEFICA2023Capable) {
        return $WIndowsUEFICA2023Capable
    }
    else  {
        return 0
    }
}

#Registry Keys for Remediation
$SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$SecureBootKey = Get-Item -Path $SecureBootRegPath
$SecureBootRegValue = $SecureBootKey.GetValue("AvailableUpdates")

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

#Check for Step Completion, and also report the current value of the Secure Boot Key
if ($Step1Complete -ne $true){
    Write-Output "Step 1 is not complete | SBKey: $SecureBootRegValue"
    Write-Error "1"
    exit 1
}
if ($Step2Complete -ne $true){
    Write-Output "Step 2 is not complete | SBKey: $SecureBootRegValue"
    Write-Error "2"
    exit 2
}
if ($Step3Complete -ne $true){
    Write-Output "Step 3 is not complete | SBKey: $SecureBootRegValue"
    Write-Error "3"
    exit 3
}
if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true){
    Write-Output "KB5025885 Complete"
    exit 0
}