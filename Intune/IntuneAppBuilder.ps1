#Gary Blok
#Build CMClient App Intune Installer
$ConfigMgrInstallPath = "S:\ConfigMgr"
$CMClientInstallScript = "F:\CM_Sources\CM Client\CMClientInstall.ps1"
$AppSourcePath = "F:\CM_Sources\CM Client\ConfigMgrClient"
$CCMSetupFolder = "$AppSourcePath\ccmsetup"
$AppBundlePath = "F:\CM_Sources\CM Client\ConfigMgrClient_IntuneApp"
$IntuneUtilFolderPath = "F:\CM_Sources\CM Client\Microsoft-Win32-Content-Prep-Tool"
$IntuneUtilPath = "F:\CM_Sources\CM Client\Microsoft-Win32-Content-Prep-Tool\IntuneWinAppUtil.exe"
$IntuneUtilURL = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"
#https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/blob/master/IntuneWinAppUtil.exe




#Test Folder Structure and Build if needed
if (!(Test-Path -Path $AppSourcePath)){
    New-item -Path $AppSourcePath -ItemType Directory -Force | Out-Null
    Write-Host "Created $AppSourcePath" -ForegroundColor Green
}
if (!(Test-Path -Path $AppBundlePath)){
    New-item -Path $AppBundlePath -ItemType Directory -Force | Out-Null
    Write-Host "Created $AppSourcePath" -ForegroundColor Green
}
if (!(Test-Path -Path $IntuneUtilFolderPath)){
    New-item -Path $IntuneUtilFolderPath -ItemType Directory -Force | Out-Null
    Write-Host "Created $IntuneUtilFolderPath" -ForegroundColor Green
}
if (!(Test-Path -Path $IntuneUtilPath)){
    Invoke-WebRequest -UseBasicParsing -Uri $IntuneUtilURL -OutFile $IntuneUtilPath
    Write-Host "Downloaded IntuneWinAppUtil.exe to $IntuneUtilPath" -ForegroundColor Green
}
if (!(Test-Path -Path $CCMSetupFolder)){
    Write-Host "CCMSetup Child Folder not found in $AppSourcePath" -ForegroundColor Red
    Write-Host "Copying CMClient BITS from $($ConfigMgrInstallPath)\Client to $CCMSetupFolder" -ForegroundColor Green
    New-item -Path $CCMSetupFolder -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$($ConfigMgrInstallPath)\Client\*" -Destination $CCMSetupFolder -Recurse -Force
}
$App = get-item -Path $AppSourcePath
$OutPutPath = "$AppBundlePath"
#if (Test-Path -Path $OutPutPath){Remove-Item -Path $OutPutPath -Force -Recurse}
#New-Item -Path $OutPutPath -ItemType Directory -Force | Out-Null
Copy-Item -Path $CMClientInstallScript -Destination $AppSourcePath -Force
$InstallPS1 = $null
$InstallPS1 = Get-ChildItem -Path $App.FullName -Filter *.ps1
if (!($SetupEXE)){$SetupEXE = Get-ChildItem -Path $App.FullName -Filter *.msi}
$SetupFolder = $App.FullName
$SetupScriptPath = $InstallPS1.FullName
#$CreateIntuneApp = Start-Process -FilePath $IntuneUtilPath -ArgumentList "-c $SetupFolder -s $SetupEXEPath -o $OutPutPath -q" -Wait -PassThru
Write-Host "Starting Intune Package Creation" -ForegroundColor Green
& $IntuneUtilPath -c $SetupFolder -s $SetupScriptPath -o $OutPutPath -q

Write-Host "Finished CM Client Install for Intune: $AppBundlePath" -ForegroundColor Green
