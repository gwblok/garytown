$STIFLERSERVERS = 'https://2pstifler.2p.garytown.com:1414'
$STIFLERULEZURL = 'https://raw.githubusercontent.com/2pintsoftware/StifleRRules/master/StifleRulez.xml'


$ClientURL = 'https://2pstifler.2p.garytown.com/StifleR-ClientApp.zip'

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

if (Test-Path -Path $tempDir){
    Write-Host -ForegroundColor Green "Download and extraction completed successfully."
    $MSI = (Get-ChildItem -Path $tempDir -Filter *.msi -Recurse).FullName
}
else {
    Write-Host -ForegroundColor Red "Download or extraction failed."
    return
}
if (Test-Path -Path $MSI){
    Write-Host -ForegroundColor Green "MSI found: $MSI"
}
else {
    Write-Host -ForegroundColor Red "MSI not found in the extracted files."
    return
}


$OPTIONS = @"
{"SettingsOptions":{"StifleRulezURL":"$STIFLERULEZURL","LogEventLevel":"Verbose","Notifications":"Administrator","Features":"PolicyCorruption,%20EventLog,%20Power,%20PerformanceCounters,%20AdminElevatedTracking,%20AdminTracking,%20BranchCache,%20SendEndpoints,%20ResMon,%20MeasureBandwidth,%20LocationData,%20Disconnect,%20TcbStats,%20AckJobs,%20DOPolicy,%20RedLeader,%20BlueLeader,%20NotRedLeader,%20InterVlan,%20CreateBITSJobs,%20ExecutePowerShell,%20RunCmdLine,%20ModifyJobs,%20Notify,%20WOL,%20UpdateServers,%20UpdateRules,%20Beacon,%20CacheManagement,%20DiskManagement,%20PhysicalNetworkManagement,%20TSData,%20ClientTools,%20GeoTracking,%20MulticastDetection","StiflerServers":"[\u0022$STIFLERSERVERS\u0022]","MaxPokeBandwidth":"256","DefaultNonRedLeaderBITSPolicy":"256","DefaultDisconnectedBITSPolicy":"512","DefaultDisconnectedDOPolicy":"512","v1MaxSizeLimit":"1048576","CheckInterval":"30000","NoProgressTimeout":"300","MaxPolicyChangeTime":"30","UpdateScreenInterval":"5000","EnableDebugTelemetry":"True","UseServerAsClient":"True","SendGeoData":"True","VPNStrings":"[\u0022VPN\u0022,\u0022Cisco%20AnyConnect\u0022,\u0022Virtual%20Private%20Network\u0022,\u0022SonicWall\u0022]","SRUMInterval":"30","UseFilterDriver":"True","LimitWiFiSpeeds":"True","SignalRLogging":"True"}}
"@

Start-Process -FilePath msiexec.exe -ArgumentList "/i $MSI /quiet OPTIONS=$OPTIONS" -Wait -PassThru