




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


#region Remediation
    #Set SecureBoot Regitry Path
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'    

    #region Do Step 1 - #Applying the DB update
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x40 -Force
    #endregion Do Step 1 - #Applying the DB update

    #region Do Step 2 - #Updating the boot manager
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x100 -Force
    #endregion Do Step 2 - #Updating the boot manager

    #region Do Step 3 - #Applying the DBX update
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x80 -Force
    #endregion Do Step 3 - #Applying the DBX update

    #region Do Step 4 - #Apply the SVN update to the firmware
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x200 -Force
    #endregion Do Step 4 - #Apply the SVN update to the firmware

    #Combo Step 3 & 4 - #Apply the DBX update & SVN update to the firmware
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'  
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x280 -Force
#endregion Remediation
    
