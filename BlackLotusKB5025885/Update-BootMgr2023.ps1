<#
Gary Blok
Just a collection of Code & Notes to deal with the KB5025885 Remediation Process

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
        $Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
        $SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
        $SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
        $SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
        Copy-Item -Path "$($SystemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi" -Destination "$($SystemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi.bak" -Force
        Copy-Item -Path "C:\windows\boot\EFI_EX\bootmgfw_EX.efi" -Destination "$($SystemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi" -Force
    }
}

