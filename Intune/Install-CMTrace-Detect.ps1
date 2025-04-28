<#
Gary Blok - @gwblok - GARYTOWN.COM
.Synopsis
Proactive Remediation for CMTrace to be on endpoint
#>
$AppName = "CMTrace"
$FileName = "CMTrace.exe"
$InstallPath = "$env:windir\system32"
$AppPath = "$InstallPath\$FileName"

<#
if (Test-Path -Path $AppPath){
    $CMTraceInstalledInfo = Get-Item -Path $AppPath
    $CMTraceInstalledSize = $CMTraceInstalledInfo.Length
    if (!($CMTraceInstalledSize -eq $CMTraceDownloadSize)){
        Write-Output "CMTrace is installed, but needs Update"
        exit 1
    }
}
#>
if (!(Test-Path -Path $AppPath)){
    Write-Output "$AppName Not Found, Exit 1"
    exit 1
}
else {
    Write-Output "$AppName Already Installed"
}