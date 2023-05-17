#Requires HPCMSL Already installed during your OSD Process.

Start-Transcript -Path "$env:windir\Debug\ApplyHPUWPDriverPack.txt"
if (!(Test-Path -Path "c:\drivers\uwp\")){New-Item -Path "c:\drivers\uwp\" -ItemType Directory -Force | Out-Null}
Write-Host "Download UWP Apps to c:\drivers\uwp"
$UWPDP = New-HPUWPDriverPack -Path "c:\drivers\uwp\"

$InstallScript = Get-ChildItem -Path "c:\drivers\uwp\" -Filter InstallAllApps.cmd -Recurse
Write-Host "Start Installing UWP Apps - $($InstallScript.FullName)"
Start-Process CMD.EXE -ArgumentList "/c $($InstallScript.FullName)" -Wait
Stop-Transcript
