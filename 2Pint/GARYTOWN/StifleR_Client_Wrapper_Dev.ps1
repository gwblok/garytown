$STIFLERSERVERS = 'https://2psr210.2p.garytown.com:1414'
$STIFLERULEZURL = 'https://raw.githubusercontent.com/2pintsoftware/StifleRRules/master/StifleRulez.xml'


$ClientURL = 'https://garytown.com/Downloads/2Pint/210/StifleR.ClientApp.Installer64_release2.10_Release_x64_2.10.20402.2148.zip'
$ClientInstallScript = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/2Pint/StifleR/StifleR_Client_Installer.ps1'

$packageName = $ClientURL.Split('/')[-1]
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
$null = New-Item -ItemType Directory -Path $tempDir -Force -ErrorAction SilentlyContinue
$packagePath = Join-Path -Path $tempDir -ChildPath $packageName


#region functions
function Test-Url {
    param (
        [string]$Url
    )
    
    try {
        $request = [System.Net.WebRequest]::Create($Url)
        $request.Method = "HEAD"  # Uses HEAD to check status without downloading content
        $request.Timeout = 5000   # 5 second timeout
        
        $response = $request.GetResponse()
        $status = [int]$response.StatusCode
        
        if ($status -eq 200) {
            #Write-Output "URL is active: $Url"
            return $true
        }
        else {
            #Write-Output "URL responded with status code $status $Url"
            return $false
        }
        $response.Close()
    }
    catch {
        Write-Output "URL is not accessible: $Url - Error: $_"
    }
}

#endregion

#Test URLs
if (-not (Test-Url -Url $ClientURL)) {
    Write-Output "URL is not accessible: $ClientURL"
    return
}


#Download and extract the package
Write-Host -ForegroundColor Cyan "Starting download and extraction of $packageName"
Start-BitsTransfer -Source $ClientURL -Destination $packagePath
Expand-Archive -Path $packagePath -DestinationPath $tempDir

#Build Install Script
#$InstallScript = Invoke-RestMethod -Uri $ClientInstallScript -Method Get
#$InstallScript | Out-File -FilePath "$tempDir\StifleR_Client_Installer.ps1" -Force -Encoding utf8

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
write-host -ForegroundColor DarkGray "Invoke-WebRequest -UseBasicParsing -Uri $ClientInstallScript -OutFile $tempDir\StifleR_Client_Installer.ps1"
Invoke-WebRequest -UseBasicParsing -Uri $ClientInstallScript -OutFile "$tempDir\StifleR_Client_Installer.ps1"


if (Test-path -path "$tempDir\StifleR_Client_Installer.ps1" ) {
    Write-Output "Successfully Created $tempDir\StifleR_Client_Installer.ps1"  
}
else{
    Write-Output "Failed to create $tempDir\StifleR_Client_Installer.ps1"
    exit 253
}
#Build Defaults.ini
$StifleRDefaultsini = @"
[MSIPARAMS]
INSTALLFOLDER=C:\Program Files\2Pint Software\StifleR Client
STIFLERSERVERS=$STIFLERSERVERS
STIFLERULEZURL=$STIFLERULEZURL
DEBUGLOG=0
RULESTIMER=86400
MSILOGFILE=C:\Windows\Temp\StifleRClientMSI.log


[CONFIG]
VPNStrings=Citrix VPN, Cisco AnyConnect
ForceVPN=0
Logfile=C:\Windows\Temp\StifleRInstaller.log
Features=Power, PerformanceCounters, AdminElevatedTracking,EventLog
BranchCachePort=1337
BlueLeaderProxyPort=1338
GreenLeaderOfferPort=1339
BranchCachePortForGreenLeader=1336
DefaultNonRedLeaderDOPolicy=102400
DefaultNonRedLeaderBITSPolicy=768000
DefaultDisconnectedDOPolicy=25600
DefaultDisconnectedBITSPolicy=25600
"@
$StifleRDefaultsini | Out-File -FilePath "$tempDir\StifleRDefaults.ini" -Force -Encoding utf8
if (Test-path -path "$tempDir\StifleRDefaults.ini") {
    Write-Output "Successfully Created $tempDir\StifleRDefaults.ini"  
}

#Build CMD file
$RunPScmd = @"
REM - this CMD file checks the platform (x86/64) and then runs the correct PS command line


PUSHD %~dp0
If "%PROCESSOR_ARCHITEW6432%"=="AMD64" GOTO 64bit
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command ".\StifleR_Client_Installer.ps1 -Defaults .\StifleRDefaults.ini -DebugPreference Continue"
GOTO END
:64bit
"%WinDir%\Sysnative\windowsPowershell\v1.0\Powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command ".\StifleR_Client_Installer.ps1 -Defaults .\StifleRDefaults.ini -DebugPreference Continue"
:END
POPD
"@

$RunPScmd | Out-File -FilePath "$tempDir\RunPS.cmd" -Force -Encoding utf8
if (Test-path -path "$tempDir\RunPS.cmd") {
    Write-Output "Successfully Created $tempDir\RunPS.cmd"  
}
#Trigger RunPS.cmd
Write-Host "Running $tempDir\RunPS.cmd" -ForegroundColor Green
Start-Process -FilePath "$tempDir\RunPS.cmd" -Wait
