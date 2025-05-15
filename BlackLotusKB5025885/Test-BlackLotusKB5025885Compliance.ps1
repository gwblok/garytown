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
        [PSCustomObject]@{ HexValue = "0x40"; DecValue = 64; Description = "Step 1 - Apply the DB update to add the 2023 Cert" }
        [PSCustomObject]@{ HexValue = "0x100"; DecValue = 256; Description = "Step 2 - Update the boot manager" }
        [PSCustomObject]@{ HexValue = "0x80"; DecValue = 128; Description = "Step 3 - Apply the DBX update to revoke the 2011 Cert" }
        [PSCustomObject]@{ HexValue = "0x200"; DecValue = 512; Description = "Step 4 - Apply the SVN update to the firmware" }
        [PSCustomObject]@{ HexValue = "0x280"; DecValue = 640; Description = "Combo Step 3 & 4 - Apply the DBX update & SVN update to the firmware" }
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
        Write-Output "======================================================================"
        Write-Output ""
        Write-Output "CVE-2023-24932 SUCCESSFULLY REMEDIATED"
        Write-Output ""
        Write-Output "Current Secure Boot Registry Value: $($SecureBootRegValue.AvailableUpdates)"
        Write-Output "======================================================================"
    }
    else {
        Write-Output "======================================================================"
        Write-Host -ForegroundColor Magenta "                     BLACK LOTUS STATUS OVERVIEW"
        Write-Output "Additional Items need to be completed for CVE-2023-24932"
        Write-Output "Last Step Complete: $LastStepComplete"
        Write-Output "Current Secure Boot Registry Value: $($SecureBootRegValue.AvailableUpdates)"
        Write-Output "Last Secure Boot Update Scheduled Task Status: $((Get-SecureBootUpdateSTaskStatus).LastTaskDescription)"
        if ($SecureBootRegValue.AvailableUpdates -ne 0 -and $null -ne $SecureBootRegValue.AvailableUpdates){
            $CurrentStage = $ComplianceTable | Where-Object {$_.DecValue -eq $SecureBootRegValue.AvailableUpdates}
            Write-Output ""
            Write-Host "!!! Pending Change in Progress !!!" -ForegroundColor Yellow
            Write-Host " Boot Registry Value Dec: $($SecureBootRegValue.AvailableUpdates) Hex: $($CurrentStage.HexValue)" -ForegroundColor Yellow
            write-Host " $($CurrentStage.Description)" -ForegroundColor Yellow
            Write-Host " Last Task Run: $($LastTaskRun)" -ForegroundColor Yellow
            Write-Host " Last Reboot: $($LastReboot)" -ForegroundColor Yellow
            if ($LastTaskRun -lt $LastReboot){
                Write-Host "!!! Task Hasn't Run Since Reboot !!!" -ForegroundColor Yellow
                Write-Host " Typically take 5-10 Minutes to auto trigger" -ForegroundColor Yellow
                Write-Host " Feel Free to manually trigger it" -ForegroundColor Yellow
                Write-Host "Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'" -ForegroundColor DarkGray
            }
            else {
                Write-Host "!!! Reboot Still Needed !!!" -ForegroundColor Red
            }
            Write-Output ""
        }
        Write-Output "======================================================================"
    }
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