<#
Gary Blok
Fix for odd situtation where you have a machine with Step 1 & 3 complete, but not Step 2, and you can't enable Secure Boot because it won't boot.
You need to update the boot manager in the System Partition, then you can enable Secure Boot again.
#>

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
$Step2Complete = If ($CertCollection.Subject -like "*Windows UEFI CA 2023*") {$true} else {$false}

#Test: Applying the DBX update
$Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'
#endregion Test if Remediation is already applied for each Step


#If the BootMgr is not updated, check the alternate location and Update it if other steps are done.
if ($Step2Complete -eq $false -and $Step1Complete -eq $true -and $Step3Complete -eq $true){
    if (Test-Path -Path "C:\windows\boot\EFI_EX"){
        $FilePath = "C:\windows\boot\EFI_EX\bootmgfw_EX.efi"
        $CertCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        $CertCollection.Import($FilePath, $null, 'DefaultKeySet')
        $2023Cert = If ($CertCollection.Subject -like "*Windows UEFI CA 2023*") {$true} else {$false}
    }
    if ($2023Cert -eq $true){
        $TempLocation = "C:\windows\temp\bootfix"
        New-Item -Path $TempLocation -ItemType Directory -Force | Out-Null
        Copy-Item "C:\windows\boot\EFI_EX" -Destination $TempLocation -Recurse -Force
        Rename-Item -Path "$TempLocation\EFI_EX" -NewName "EFI" -Force -Verbose
        $EFIFiles = Get-Childitem -Path $TempLocation -Filter *_EX*.* -Recurse
        foreach ($File in $EFIFiles){
            $NewName = $File.Name.Replace("_EX","")
            Rename-Item -Path $File.FullName -NewName $NewName  -Verbose
        }
        $Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
        $SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
        $SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
        $SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
        Copy-Item -Path "$($SystemVolume.Path)\EFI\Microsoft\Boot" -Destination "$($SystemVolume.Path)\EFI\Microsoft\Boot.bak" -Force
        Copy-Item -Path "$TempLocation\EFI\*" -Destination "$($SystemVolume.Path)\EFI\Microsoft\Boot\" -Force -Recurse
    }
}

