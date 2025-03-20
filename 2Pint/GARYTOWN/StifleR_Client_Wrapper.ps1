$ClientURL = 'https://github.com/gwblok/garytown/raw/refs/heads/master/2Pint/GARYTOWN/StifleR.ClientApp.Installer64_release2.10_Release_x64_2.10.20313.1943.zip'
$ClientInstallScript = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/2Pint/StifleR/StifleR_Client_Installer.ps1'

$packageName = $ClientURL.Split('/')[-1]
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$null = New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue
$packagePath = Join-Path -Path $tempDir -ChildPath $packageName

Start-BitsTransfer -Source $ClientURL -Destination $packagePath
Expand-Archive -Path $packagePath -DestinationPath $tempDir

$InstallScript = Invoke-RestMethod -Uri $ClientInstallScript -Method Get