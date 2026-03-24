 #https://support.microsoft.com/en-us/topic/kb5025885-how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d#bkmk_update_boot_media

function Test-BlackLotusKB5025885Compliance { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch] $Details = $false
    )
    
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

    #Region Applicability
    $CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $Build = $CurrentOSInfo.GetValue('CurrentBuild')
    [int]$UBR = $CurrentOSInfo.GetValue('UBR')

    #July 2024 UBRs
    $JulyPatch = @('19045.4651','22621.3880','22631.3880','26100.1150','26120.1','26200.1')
    $MatchedPatch = $JulyPatch | Where-Object {$_ -match $Build}
    if ($null -eq $MatchedPatch){
        $Applicability = "The OS ($Build.$UBR) is not supported for this remediation."
    }
    [int]$MatchedUBR = $MatchedPatch.split(".")[1]

    if ($UBR -ge $MatchedUBR){
        #$OSSupported = $true
    }
    else {
        #$OSSupported = $false
        $Applicability = "The OS ($Build.$UBR) is not supported for this remediation."
    }
    if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
        #This is required for remediation to work
    }
    else {
        $Applicability =  "Secure Boot is not enabled."
    }

    #endregion Applicability
    $Compliance = $true
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'

    #region Gather Info

    #Step 1 Results Confirmation - Applying the DB update
    $Step1Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'
    if ($Step1Complete -eq $false){$Compliance = $false}

    #Step 2 Results Confirmation - Updating the boot manager
    #Check Signing Cert on bootmgfw file
    $Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
    $SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
    $SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
    $SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
    $FilePath = "$($SystemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi"
    $CertCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $CertCollection.Import($FilePath, $null, 'DefaultKeySet')
    If ($CertCollection.Subject -like "*Windows UEFI CA 2023*") {
        $Step2Complete = $true
        }
    else{
        $Step2Complete = $false
        $Compliance = $false
    }

    #Step 3 Results Confirmation - Applying the DBX update
    $Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'
    if ($Step3Complete -eq $false){$Compliance = $false}

    #Get Last Step Complete Status
    $StepsComplete = Get-WindowsUEFICA2023Capable
    $LastStepComplete = $StepsComplete
    if ($Step3Complete -eq $true){$LastStepComplete = 3}

    $SecureBootRegValue = Get-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates"

    $LastReboot = (Get-WinEvent -LogName System -MaxEvents 1 -FilterXPath "*[System[EventID=6005]]" | Select-Object -Property TimeCreated).TimeCreated
    $LastTaskRun = (Get-SecureBootUpdateSTaskStatus).LastRunTime
    #endregion Gather Info

    $ComplianceTable = @(
        # Individual bits used for certificate servicing (per MS Secure Boot troubleshooting guide KB5085046)
        # Order reflects the sequence the Secure-Boot-Update task processes each bit
        [PSCustomObject]@{ HexValue = "0x0004"; DecValue = 4;     Order = 4; Description = "This bit tells the scheduled task to look for a Key Exchange Key signed by the device's Platform Key (PK). The PK is managed by the OEM. OEMs sign the Microsoft KEK with their PK and deliver it to Microsoft where it's included in monthly cumulative updates."; SuccessEvent = 1043 }
        [PSCustomObject]@{ HexValue = "0x0040"; DecValue = 64;    Order = 1; Description = "This bit tells the scheduled task to add the Windows UEFI CA 2023 certificate to the Secure Boot DB. This allows Windows to trust boot managers signed by this certificate."; SuccessEvent = 1036 }
        [PSCustomObject]@{ HexValue = "0x0080"; DecValue = 128;   Order = $null; Description = "Apply the DBX update to revoke PCA 2011 signing certificate"; SuccessEvent = 1037 }
        [PSCustomObject]@{ HexValue = "0x0100"; DecValue = 256;   Order = 5; Description = "This bit tells the scheduled task to apply the boot manager, signed by the Windows UEFI CA 2023, to the boot partition. This will replace the Microsoft Windows Production PCA 2011 signed boot manager."; SuccessEvent = 1799 }
        [PSCustomObject]@{ HexValue = "0x0200"; DecValue = 512;   Order = $null; Description = "Apply the SVN update to the firmware"; SuccessEvent = $null }
        [PSCustomObject]@{ HexValue = "0x0280"; DecValue = 640;   Order = $null; Description = "Combo - Apply the DBX update & SVN update to the firmware"; SuccessEvent = $null }
        [PSCustomObject]@{ HexValue = "0x0800"; DecValue = 2048;  Order = 2; Description = "This bit tells the scheduled task to apply the Microsoft Option ROM UEFI CA 2023 to the DB. When the 0x4000 flag is set, the scheduled task will first check the database for the Microsoft Corporation UEFI CA 2011 certificate. It will apply the Microsoft Option ROM UEFI CA 2023 certificate only if the 2011 certificate is present."; SuccessEvent = 1044 }
        [PSCustomObject]@{ HexValue = "0x1000"; DecValue = 4096;  Order = 3; Description = "This bit tells the scheduled task to apply the Microsoft UEFI CA 2023 to the DB. When the 0x4000 flag is set, the scheduled task will first check the database for the Microsoft Corporation UEFI CA 2011 certificate. It will apply the Microsoft UEFI CA 2023 certificate only if the 2011 certificate is present."; SuccessEvent = 1045 }
        [PSCustomObject]@{ HexValue = "0x4000"; DecValue = 16384; Order = $null; Description = "This bit modifies the behavior of the 0x0800 and 0x1000 bits so that the Microsoft UEFI CA 2023 and Microsoft Option ROM UEFI CA 2023 are applied only if the DB already contains the Microsoft Corporation UEFI CA 2011. To help ensure that the device's security profile remains the same, this bit only applies these new certificates if the device trusts the Microsoft Corporation UEFI CA 2011 certificate. Not all Windows devices trust this certificate. This bit remains set after all other bits are processed."; SuccessEvent = $null }
        # Expected progression values when using 0x5944 (all certificate servicing steps)
        [PSCustomObject]@{ HexValue = "0x5944"; DecValue = 22852; Order = $null; Description = "Initial state before Secure Boot certificate servicing begins."; SuccessEvent = $null }
        [PSCustomObject]@{ HexValue = "0x5904"; DecValue = 22788; Order = $null; Description = "After Order 1 (0x0040) - Windows UEFI CA 2023 is added to the Secure Boot DB."; SuccessEvent = 1036 }
        [PSCustomObject]@{ HexValue = "0x5104"; DecValue = 20740; Order = $null; Description = "After Order 2 (0x0800) - Add Microsoft Option ROM UEFI CA 2023 to the DB if the device previously trusted the Microsoft UEFI CA 2011."; SuccessEvent = 1044 }
        [PSCustomObject]@{ HexValue = "0x4104"; DecValue = 16644; Order = $null; Description = "After Order 3 (0x1000) - Microsoft UEFI CA 2023 is added to the DB if the device previously trusted the Microsoft UEFI CA 2011."; SuccessEvent = 1045 }
        [PSCustomObject]@{ HexValue = "0x4100"; DecValue = 16640; Order = $null; Description = "After Order 4 (0x0004) - New Microsoft KEK 2K CA 2023 signed by the OEM platform key is applied."; SuccessEvent = 1043 }
        [PSCustomObject]@{ HexValue = "0x4000"; DecValue = 16384; Order = $null; Description = "After Order 5 (0x0100) - Boot manager signed by Windows UEFI CA 2023 is installed. Final value of 0x4000 indicates successful completion of all applicable update actions."; SuccessEvent = 1799 }
    )
    #$ComplianceTable | Format-Table -AutoSize

    Write-Output "======================================================================"
    Write-Output "KB5025885: Windows Boot Manager revocations for Secure Boot changes"
    Write-Output "CVE-2023-24932 remediation Summary"
    Write-Output "======================================================================"
    Write-Output ""

    if ($null -ne $Applicability){
        Write-Host "Applicability: $($Applicability)" -ForegroundColor Red
        Write-Output ""
    }

    if ($Step1Complete  -eq $true){
        Write-Host -ForegroundColor Green "SUCCESS: " -NoNewline; Write-Host -ForegroundColor Gray "Applying the DB update |  1036 | The PCA2023 certificate was added to the DB."
    }
    else {
        Write-Host -ForegroundColor Yellow "Not Complete: " -NoNewline; Write-Host -ForegroundColor Gray "Applying the DB update |  1036 | The PCA2023 certificate was added to the DB."
    }
    Write-Output "======================================================================"
    if ($Step2Complete  -eq $true){
        Write-Host -ForegroundColor Green "SUCCESS: " -NoNewline; Write-Host -ForegroundColor Gray "Updating the boot manager |  1799 | The PCA2023 signed boot manager was applied."
    }
    else {
        Write-Host -ForegroundColor Yellow "Not Complete: " -NoNewline; Write-Host -ForegroundColor Gray "Updating the boot manager |  1799 | The PCA2023 signed boot manager was applied."
    }
    Write-Output "======================================================================"
    if ($Step3Complete  -eq $true){
        Write-Host -ForegroundColor Green "SUCCESS: " -NoNewline; Write-Host -ForegroundColor Gray "Applying the DBX update |  1037 | The DBX update that untrusts the PCA2011 signing certificate was applied."
    }
    else {
        Write-Host -ForegroundColor Yellow "Not Complete: " -NoNewline; Write-Host -ForegroundColor Gray "Applying the DBX update |  1037 | The DBX update that untrusts the PCA2011 signing certificate was applied."
    }
    Write-Output ""
    
    if ($Compliance -eq $true){
        Write-Output "================================================================================"
        Write-Output ""
        Write-Output "CVE-2023-24932 SUCCESSFULLY REMEDIATED - 2011 Cert Revoked and 2023 Cert Trusted"
        Write-Output ""
        Write-Output "Current Secure Boot Registry Value: $($SecureBootRegValue.AvailableUpdates)"
        Write-Output "================================================================================"
    }
    else {
        Write-Output "================================================================================"
        Write-Host -ForegroundColor Magenta "                     BLACK LOTUS STATUS OVERVIEW"
        Write-Output "Additional Items need to be completed for CVE-2023-24932"
        Write-Output "Last Step Complete: $LastStepComplete"
        Write-Output "Current Secure Boot Registry Value: $($SecureBootRegValue.AvailableUpdates)"
        Write-Output "Last Secure Boot Update Scheduled Task Status: $((Get-SecureBootUpdateSTaskStatus).LastTaskDescription)"
        
        Write-Output "================================================================================"
    }
    if ($SecureBootRegValue.AvailableUpdates -ne 0 -and $null -ne $SecureBootRegValue.AvailableUpdates){
            $CurrentStage = $ComplianceTable | Where-Object {$_.DecValue -eq $SecureBootRegValue.AvailableUpdates}
            Write-Output ""
            Write-Host " Boot Registry Value Dec: $($SecureBootRegValue.AvailableUpdates) Hex: $($CurrentStage.HexValue)" -ForegroundColor Yellow
            $WrappedDesc = ($CurrentStage.Description) -split "(?<=\. )" | ForEach-Object { "   $_" }
            $WrappedDesc | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
            Write-Host " Last Task Run: $($LastTaskRun)" -ForegroundColor Yellow
            Write-Host " Last Reboot: $($LastReboot)" -ForegroundColor Yellow
            if ($LastTaskRun -lt $LastReboot){
                Write-Host "!!! Task Hasn't Run Since Reboot !!!" -ForegroundColor Yellow
                Write-Host " Typically take 5-10 Minutes to auto trigger" -ForegroundColor Yellow
                Write-Host " Feel Free to manually trigger it" -ForegroundColor Yellow
                Write-Host "Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'" -ForegroundColor DarkGray
            }
            Write-Output ""
        }
    Write-Output "================================================================================"
    <# No longer using after Cinco de Mayo 2025
    if (Test-Path -Path HKLM:\SOFTWARE\Remediation\KB5025885){
        $Key = Get-Item -Path HKLM:\SOFTWARE\Remediation\KB5025885
        Write-Output "======================================================================"
        Write-Output ""
        Write-Output $KEY
        Write-Output ""
        Write-Output "======================================================================"
    }
    #>
    if ($Details -eq $true){
        Write-Output "======================================================================"
        Write-Output ""
        Write-Output "Details Requested, additional information about the remediation"
        Write-Output ""
        Write-Host "Registry Items used for remediation" -ForegroundColor magenta
        Write-Host -ForegroundColor Cyan "Secure Boot Key Registry Location: " -NoNewline; Write-Host -ForegroundColor Yellow "$SecureBootRegPath"
        Write-Host -ForegroundColor Cyan "WindowsUEFICA2023Capable Registry Location: " -NoNewline; Write-Host -ForegroundColor Yellow "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"
        write-Host "Registry Values and Descriptions" -ForegroundColor magenta
        $ComplianceTable | Format-Table -AutoSize
        Write-Host -ForegroundColor Cyan  "Trigger Step 1: " -NoNewline; Write-Host -ForegroundColor Yellow " New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x40 -Force"
        Write-Host -ForegroundColor Cyan  "Trigger Step 2: " -NoNewline; Write-Host -ForegroundColor Yellow " New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x100 -Force"
        Write-Host -ForegroundColor Cyan  "Trigger Step 3: " -NoNewline; Write-Host -ForegroundColor Yellow " New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x80 -Force"
        Write-Host -ForegroundColor Cyan  "Trigger Step 4: " -NoNewline; Write-Host -ForegroundColor Yellow " New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x200 -Force"
        Write-Host -ForegroundColor Cyan  "Trigger Combo : " -NoNewline; Write-Host -ForegroundColor Yellow " New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x280 -Force"
        Write-Output ""
        Write-Host "Scheduled Task used for remediation" -ForegroundColor magenta
        write-Host "\Microsoft\Windows\PI\Secure-Boot-Update" -ForegroundColor Yellow
        Write-Host -ForegroundColor Cyan  "Trigger: " -NoNewline; Write-Host -ForegroundColor Yellow "  Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'"
        Write-Host "Do this after you Set the Registry Value, then wait for results... often requires reboot after." -ForegroundColor DarkGray
        Write-Output ""
        Write-Host "How to Detect" -ForegroundColor magenta
        Write-Host -ForegroundColor Cyan  "Step 1 Complete: " -NoNewline; Write-Host -ForegroundColor Yellow "((Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' -Name 'WindowsUEFICA2023Capable') -ge 1)"
        Write-Host -ForegroundColor Cyan  "Step 2 Complete: " -NoNewline; Write-Host -ForegroundColor Yellow "((Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing' -Name 'WindowsUEFICA2023Capable') -eq 2)"
        Write-Host -ForegroundColor Cyan  "Step 3 Complete: " -NoNewline; Write-Host -ForegroundColor Yellow "[System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'"
        Write-Host -ForegroundColor Cyan  "Step 4 Complete: " -NoNewline; Write-Host -ForegroundColor Yellow "No Detection Method Available"
        Write-Output "======================================================================"
    }
}