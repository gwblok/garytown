<#
Gary Blok
Just a collection of Code & Notes to deal with the KB5025885 Remediation Process

NOTE: Step 2 doesn't work in PowerShell ISE.  If you run launch PowerShell directly, or use VSCode, it works fine.

#>

#Old Methods to get Information, look below for the new methods based on May 2025 information
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
If ($CertCollection.Subject -like "*Windows UEFI CA 2023*") {$true} else {$false}

#Test: Applying the DBX update
$Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'
#endregion Test if Remediation is already applied for each Step


#Region Detection after May 4 2025
#Updated for the May 5 2025 information:
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
$StepsComplete = Get-WindowsUEFICA2023Capable
$Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'

#Figure out the last step that was completed
$LastStepComplete = $StepsComplete
if ($Step3Complete -eq $true){$LastStepComplete = 3}

#endregion Detection after May 4 2025



#region Remediation
    #Set SecureBoot Regitry Path
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'    

    #region Do Step 1 - #Applying the DB update
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x40 -Force
    Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
    #endregion Do Step 1 - #Applying the DB update

    #region Do Step 2 - #Updating the boot manager
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x100 -Force
    Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
    #endregion Do Step 2 - #Updating the boot manager

    #region Do Step 3 - #Applying the DBX update
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x80 -Force
    Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
    #endregion Do Step 3 - #Applying the DBX update

    #region Do Step 4 - #Apply the SVN update to the firmware
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x200 -Force
    Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
    #endregion Do Step 4 - #Apply the SVN update to the firmware

    #Combo Step 3 & 4 - #Apply the DBX update & SVN update to the firmware
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x280 -Force
    Start-ScheduledTask -TaskName "\Microsoft\Windows\PI\Secure-Boot-Update"
#endregion Remediation
    
