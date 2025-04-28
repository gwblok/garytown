$PSDBootImagePath = "C:\Users\GaryBlok\OneDrive - garytown\GitHub\garytown\2Pint\SureRecover\BootImage"
$KeyPath = "C:\Users\GaryBlok\OneDrive - garytown\Documents\HPConnectCerts"
$CertPswd = "P@ssw0rd"
$OpenSSLPath = "C:\Program Files\OpenSSL-Win64\bin"
Set-Location $PSDBootImagePath

$ManifestPath = "$PSDBootImagePath\Recovery.mft" 
$imageVersion = 1903 # Note: This can be any 16-bit integer

# mft_version is used to determine the format of the image file and must currently be set to 1.
$header = "mft_version=1, image_version=$imageVersion" 
Out-File -Encoding UTF8 -FilePath $ManifestPath -InputObject $header

$PSDBootImageFiles = "efi\boot\bootx64.efi","efi\boot\autoexec.pxe"

ForEach ($File in $PSDBootImageFiles){
    $FileObject = Get-ChildItem $File
    $hashObject = Get-FileHash -Algorithm SHA256 -Path $FileObject.FullName
    $fileHash = $hashObject.Hash.ToLower()
    $filePath = $hashObject.Path.Replace($PSDBootImagePath, '')
    $fileSize = (Get-Item $FileObject.FullName).length
    $manifestContent = "$fileHash $filePath $fileSize" 
    Out-File -Encoding utf8 -FilePath $ManifestPath -InputObject $manifestContent -Append
}

# Manifests for HP Sure Recover cannot include a BOM (Byte Order Mark)
# The following commands rewrite the file as UTF8 without BOM.
$content = Get-Content $ManifestPath
$encoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($ManifestPath,$content, $encoding)


# -----------------------
# Sign the HP Sure Recover Manifest
# -----------------------
Set-Location $OpenSSLPath

# You can sign the agent manifest with this command
# Run below in cmd prompt (will figure out the PowerShell syntax soon)
.\openssl dgst -sha256 -sign C:\Setup\HPKeys\re.key -passin pass:SecretPassword2 -out C:\Setup\BootImage\recovery.sig C:\Setup\BootImage\Recovery.mft

# Verify the signature file, using your public key from the previous step, using the following command:
.\openssl pkcs12 -in "$KeyPath\re.pfx" -clcerts -nokey -out "$KeyPath\re_public.pem" -passin "pass:$CertPswd"
.\openssl dgst -sha256 -verify "$KeyPath\re_public.pem" -signature C:\Setup\BootImage\recovery.sig C:\Setup\BootImage\recovery.mft