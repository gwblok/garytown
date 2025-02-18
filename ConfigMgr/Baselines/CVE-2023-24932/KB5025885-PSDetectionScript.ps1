
#Test if Remediation is applicable
#Region Applicablitity
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#April 2024 UBRs
$AprilPatch = @('19044.4291','19045.4291','22631.3447','22621.3447','22000.2899', '26100.1150')
$MatchedPatch = $AprilPatch | Where-Object {$_ -match $Build}
[int]$MatchedUBR = $MatchedPatch.split(".")[1]

if ($UBR -ge $MatchedUBR){
    $OSSupported = $true
}
else {
    $OSSupported = $false
}
#endregionApplicablitity


if ($OSSupported -eq $true){
    $SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
    $RemediationsRegPath = 'HKLM:\SOFTWARE\Remediations\KB5025885'
    if (Test-Path -Path $RemediationsRegPath){
        $RebootCount = (Get-Item -Path $RemediationsRegPath -ErrorAction SilentlyContinue).GetValue('RebootCount')
        if ($null -eq $RebootCount){
            $RebootCount = 0
        }
    }

    
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

    #region Remediation
    if ($Step1Complete -ne $true -or $Step2Complete -ne $true -or $Step3Complete -ne $true){
            Write-Output "Needs Remediation"
            exit 1
    }
    if ($null -eq $RebootCount){
        if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true){
            Write-Output "The remediation is already applied."
            exit 0
        }
        else {
            Write-Output "Needs Remediation"
            exit 1
        }
    }
    else {
        if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true -and $RebootCount -eq 5){
            Write-Output "Needs Remediation to update Registry Values"
            exit 1
        }
    }

    #endregion Remediation
    
} #Supported OS -eq $true
else {
    Write-Output "The OS is not supported for this remediation."
}
