 #https://support.microsoft.com/en-us/topic/kb5025885-how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d#bkmk_update_boot_media

function Invoke-BlackLotusKB5025885Compliance { 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'StepSelection1')]
        [switch] $Step1,

        [Parameter(Mandatory = $true, ParameterSetName = 'StepSelection2')]
        [switch] $Step2,

        [Parameter(Mandatory = $true, ParameterSetName = 'StepSelection3')]
        [switch] $Step3,

        [Parameter(Mandatory = $true, ParameterSetName = 'StepSelection4')]
        [switch] $Step4,

        [Parameter(Mandatory = $true, ParameterSetName = 'StepSelection34')]
        [switch] $Step34Combo,

        [Parameter(Mandatory = $true, ParameterSetName = 'StepSelectionN')]
        [switch] $NextStep
    ) 
    Function Invoke-Step1 {
        Write-Host -ForegroundColor Magenta "Setting Registry Value to 0x40 to enable Step 1"
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x40 -Force
        Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'
        Start-Sleep -Seconds 2
        Write-Host "Recommend Waiting a minute, then running the Function to Test Compliance again." 
        return $null
    }
    Function Invoke-Step2 {
        Write-Host -ForegroundColor Magenta "Setting Registry Value to 0x100 to enable Step 2 (You will need to reboot)"
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x100 -Force
        Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'
        Start-Sleep -Seconds 2
        Write-Host "Recommend Rebooting, then wait about 5 minutes, then running the Function to Test Compliance again." 
        return $null
    }
    Function Invoke-Step3 {
        Write-Host -ForegroundColor Magenta "Setting Registry Value to 0x80 to enable Step 3"
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x80 -Force
        Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'
        Start-Sleep -Seconds 2
        Write-Host "Recommend Waiting a minute, then running the Function to Test Compliance again." 
        return $null
    }
    Function Invoke-Step4 {
        Write-Host -ForegroundColor Magenta "Setting Registry Value to 0x200 to enable Step 4"
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x200 -Force
        Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'
        Start-Sleep -Seconds 2
        Write-Host "Applied the SVN update to the firmware, but no detection method available." 
        return $null
    }
    Function Invoke-Step34Combo {
        Write-Host -ForegroundColor Magenta "Setting Registry Value to 0x280 to enable Step 3 & Step 4"
        New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'   -Name 'AvailableUpdates' -PropertyType dword -Value 0x280 -Force
        Start-ScheduledTask -TaskName '\Microsoft\Windows\PI\Secure-Boot-Update'
        Start-Sleep -Seconds 2
        Write-Host "Recommend Waiting a minute, then running the Function to Test Compliance again." 
        return $null
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

    #endregion Gather Info



    if ($null -ne $Applicability){
        write-host -ForegroundColor red "Applicability: $($Applicability)"
        write-host -ForegroundColor Yellow "Resolve the Applicability issue before continuing."
        return $null
    }

    if ($Step1Complete  -eq $true){
        Write-Host -ForegroundColor Green "SUCCESS: " -NoNewline; Write-Host -ForegroundColor Gray "Step 1 | Applying the DB update |  1036 | The PCA2023 certificate was added to the DB."
    }
    else {
        Write-Host -ForegroundColor Yellow "Not Complete: " -NoNewline; Write-Host -ForegroundColor Gray "Applying the DB update |  1036 | The PCA2023 certificate was added to the DB."
        if ($Step1 -eq $true -or $NextStep -eq $true){
            Invoke-Step1
            return $null
        }
    }

    Write-Output "======================================================================"
    if ($Step2Complete  -eq $true){
        Write-Host -ForegroundColor Green "SUCCESS: " -NoNewline; Write-Host -ForegroundColor Gray "Step 2 | Updating the boot manager |  1799 | The PCA2023 signed boot manager was applied."
    }
    else {
        Write-Host -ForegroundColor Yellow "Not Complete: " -NoNewline; Write-Host -ForegroundColor Gray "Updating the boot manager |  1799 | The PCA2023 signed boot manager was applied."
        if ($Step2 -eq $true -or $NextStep -eq $true){
            Invoke-Step2
            return $null
        }
    }
    Write-Output "======================================================================"
    if ($Step3Complete  -eq $true){
        Write-Host -ForegroundColor Green "SUCCESS: " -NoNewline; Write-Host -ForegroundColor Gray "Step 3 | Applying the DBX update |  1037 | The DBX update that untrusts the PCA2011 signing certificate was applied."
    }
    else {
        Write-Host -ForegroundColor Yellow "Not Complete: " -NoNewline; Write-Host -ForegroundColor Gray "Applying the DBX update |  1037 | The DBX update that untrusts the PCA2011 signing certificate was applied."
        if ($Step3 -eq $true -or $NextStep -eq $true){
            Invoke-Step3
            return $null
        }
        if ($Step34Combo -eq $true){
            Invoke-Step34Combo
            return $null
        }
    }
    Write-Output ""
    
    if ($Step4){
        Write-Host -ForegroundColor Yellow "Applying the SVN update even though the detection method is not available."
        if ($Step4 -eq $true){
            Invoke-Step4
            return $null
        }
    }

    if ($Compliance -eq $true){
        Write-Output "=========================================================================================="
        Write-Output ""
        Write-Output "CVE-2023-24932 SUCCESSFULLY REMEDIATED"
        Write-Output ""
        Write-Output "STEP 4 - Apply the SVN update to the firmware is Unknown, no detection method available"
        Write-Output "=========================================================================================="
    }
}