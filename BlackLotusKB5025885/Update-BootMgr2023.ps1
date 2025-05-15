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
        Rename-Item -Path "$MountPath\Windows\Boot\EFI" -NewName "EFI_2011" -Force -Verbose
        Rename-Item -Path "$MountPath\Windows\Boot\Fonts" -NewName "Fonts_2011" -Force -Verbose
        Rename-Item -Path "$MountPath\Windows\Boot\PXE" -NewName "PXE_2011" -Force -Verbose
        Copy-Item -Path "$($SystemVolume.Path)\EFI\Microsoft\Boot" -Destination "$($SystemVolume.Path)\EFI\Microsoft\Boot.bak" -Force
        Copy-Item -Path "$TempLocation\EFI\*" -Destination "$($SystemVolume.Path)\EFI\Microsoft\Boot\" -Force -Recurse

        
    }
}



param(
    [Parameter(Mandatory=$false)]
    [string]$WinPEPath
)

$MountPath = "c:\mount"
$WinPEIndex = '1'
Write-Output "======================================================================"
Write-Output "Starting WinPE Black Lotus Modifications"
Write-Output ""
Write-Output "WinPEPath:  $WinPEPath"
Write-Output "MountPath:  $MountPath"
Write-Output "WinPEIndex: $WinPEIndex"


$WinPEPath = (Get-ChildItem -Path $WinPEPath -Filter *.wim).FullName
if ($WinPEPath){
    if (Test-Path -Path $WinPEPath){
        Write-Output "Found WinPE: $WinPEPath"
    }
    else{
        Write-Output "NO WinPE Found"
        exit 5
    }
}
else{
    Write-Output "NO WinPE Found"
    exit 5
}

# Clean up and create Mount directory
If (Test-Path $MountPath) {
    Write-Host "Cleaning up previous run: $MountPath" -ForegroundColor DarkGray
    Remove-Item $MountPath -Force -Verbose -Recurse
}
New-Item -Path $MountPath -ItemType Directory -Force | Out-Null

If (Test-Path "c:\UpdatedBoot.wim") {
    Write-Host "Cleaning up previous run: c:\UpdatedBoot.wim" -ForegroundColor DarkGray
    Remove-Item "c:\UpdatedBoot.wim" -Force -Verbose
}

Write-Output "Mount-WindowsImage -ImagePath $WinPEPath -Index $WinPEIndex -Path $MountPath"
Mount-WindowsImage -ImagePath $WinPEPath -Index $WinPEIndex -Path $MountPath

#Rename 2011 Signed Files to _2011
Rename-Item -Path "$MountPath\Windows\Boot\EFI" -NewName "EFI_2011" -Force -Verbose
Rename-Item -Path "$MountPath\Windows\Boot\Fonts" -NewName "Fonts_2011" -Force -Verbose
Rename-Item -Path "$MountPath\Windows\Boot\PXE" -NewName "PXE_2011" -Force -Verbose

#Rename updated Signed Files to Default Values

Rename-Item -Path "$MountPath\Windows\Boot\EFI_EX" -NewName "EFI" -Force -Verbose
Rename-Item -Path "$MountPath\Windows\Boot\Fonts_EX" -NewName "Fonts" -Force -Verbose
Rename-Item -Path "$MountPath\Windows\Boot\PXE_EX" -NewName "PXE" -Force -Verbose

#Rename Child Files

$EFIFiles = Get-Childitem -Path "$MountPath\Windows\Boot\EFI" -Filter *_EX*.* -Recurse
foreach ($File in $EFIFiles){
    $NewName = $File.Name.Replace("_EX","")
    Rename-Item -Path $File.FullName -NewName $NewName  -Verbose
}

$FontFiles = Get-Childitem -Path "$MountPath\Windows\Boot\Fonts" -Filter *_EX*.* -Recurse
foreach ($File in $FontFiles){
    $NewName = $File.Name.Replace("_EX","")
    Rename-Item -Path $File.FullName -NewName $NewName  -Verbose
}

$PXEFiles = Get-Childitem -Path "$MountPath\Windows\Boot\PXE" -Filter *_EX*.* -Recurse
foreach ($File in $PXEFiles){
    $NewName = $File.Name.Replace("_EX","")
    Rename-Item -Path $File.FullName -NewName $NewName  -Verbose
}

Dismount-WindowsImage -Path $MountPath -Save

Copy-Item -Path $WinPEPath "c:\UpdatedBoot.wim"
