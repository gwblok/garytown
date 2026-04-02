<# 
    Gary Blok & Mike Terrill
    KB5025885 Detection Script
    Version: 26.04.02

    Changes: Updated applicability checks to match the latest UBR requirements for the March 2026 update
             Updated output messages to be more user friendly and informative about the status of the remediation
             Added more detailed comments throughout the script for clarity
             Updated for the 4 certs vs the 1 cert
             Added Step4 Detection for SVN update status

#>

#Control the Remediation Process
$EnableStep1 = $true #Certificate Updates
$EnableStep2 = $true #Boot Manager Update
$EnableStep3 = $false #DBX Update - OPTIONAL - This will revoke the 2011 Compromised Certificate, but also potentially make your life harder.
$EnableStep4 = $false #Enable the SVN to highest Level (Use Get-SecureBootSVN to check current level) - OPTIONAL - This will prevent any rollback of the Boot Manager, but also potentially make your life harder if you have any issues with the new Boot Manager and need to roll back.   


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

#Figure out last step completed for easier reporting to Intune and to determine if remediation is needed for the next steps
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
#region Detection

#Report This Info to Intune Process:
Write-Output "StepComplete: $LastStepComplete | SBKey: $SecureBootRegValue | PI: $((Get-SecureBootUpdateSTaskStatus).LastTaskDescription)"

if ((Get-SecureBootUpdateSTaskStatus).LastTaskResult -eq 2147942750){
    Write-Error "Reboot Required, Triggering Remediation"
    exit 1
}
if ($StepsComplete -eq 0 -or $Step1Compliance -eq $false){
   if ($EnableStep1){
        Write-Error "Step 1 is not yet complete - Remediation is needed"
        #Creating Mapping from $true or $false to 'Present' or 'Missing' for easier readability in outputs
        $Win2023Status = if ($Win2023Present) {"Present"} else {"Missing"}
        $MSKEKStatus = if ($MSKEKPresent) {"Present"} else {"Missing"}
        $MSCA2023Status = if ($MSCA2023Present) {"Present"} else {"Missing"}
        $OptionROM2023Status = if ($OptionROM2023Present) {"Present"} else {"Missing"} 
        Write-Output "Not up to date - missing cert(s) | Win2023: $Win2023Status | MSKEK: $MSKEKStatus | MSCA2023: $MSCA2023Status | OptionROM2023: $OptionROM2023Status "
        exit 1
    }
    else{
        Write-Error "Step 1 is not enabled for remediation"
        exit 0
    }
}
#If the first 2 steps are complete, remediation is needed, exit 
if ($LastStepComplete -eq 1){
    if ($EnableStep2){
        Write-Error "Certs good, but Step 2 is not yet complete - Remediation is needed for Boot Manager Update"
        exit 1
    }
    else{
        Write-Error "Step 2 is not enabled for remediation"
        exit 0
    }
}
if ($LastStepComplete -eq 2){
    if ($EnableStep3){
        Write-Error "BootMgr Update (Step 2) is Complete - Remediation is needed for DBX Update (Step 3)"
        exit 2
    }
    else{
        Write-Error "DBX Update (Step 3) is not enabled for remediation"
        exit 0
    }

}
if ($LastStepComplete -eq 3){
    if ($EnableStep4){
        Write-Error "DBX Update (Step 3) is Complete - Remediation is needed for SVN Update (Step 4)"
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
