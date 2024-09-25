# Generic settings, and list of packages to query on clients
$BCPort = 1337

$DPs = @(
    "2CM.2P.garytown.com"
    #"dp01.corp.viamonstra.com"
    #"dp02.corp.viamonstra.com"
    #"dp03.corp.viamonstra.com"
)

# Query remote or local cache for package content using package id
$RemoteComputerNames = @(
    "Dell-O-3090"
    "LENOVO-M60E"
    "HPED800G6-HOST"
    #"VM-2CM-5180-01"
    #"VM-2CM-P5180-01"
    #"VM-2CM-800G6-01"
    #"VM-2CM-800G6-02"
    #"VM-2CM-800G6-03"
    #"VM-2CM-800G6-04"
    #"VM-2CM-800G6-05"
    #"VM-2CM-800G6-06"
    #"VM-2CM-800G6-07"
    #"VM-2CM-800G6-08"
    "DELL-L-E5470-01"
    "DELL-L-E5470-02"
    "DELL-L-E5470-03"
    "DELL-L-E5470-04"
    #"PC0002"
)
if ("$env:computerName" -in $RemoteComputerNames){
    $RemoteComputerNames += "$env:computerName"
}

# Define location of main log file
$LogPath = "C:\Temp"
New-Item -Type Directory -Path $LogPath -Force | Out-Null
$Logfile = "$LogPath\BCMon.log"

# Packages to Check for
$PackagesToCheck = @()
$PackagesToCheck += [pscustomobject]@{ PackageID = "MCM00418"; SourceVersion = "1"; SourceName = "Win11 23H2 Media" } # 23H2 Media
$PackagesToCheck += [pscustomobject]@{ PackageID = "2CM00011"; SourceVersion = "1"; SourceName = "Win11 24H2 Media" } # 24H2 Media
$PackagesToCheck += [pscustomobject]@{ PackageID = "MCM00008"; SourceVersion = "2"; SourceName = "Win10 22H2 Media" } # 22H2 Media
$PackagesToCheck += [pscustomobject]@{ PackageID = "2CM0000F"; SourceVersion = "3"; SourceName = "24H2 Boot StifleR: 10.0.26100.1_24.08.29" } # 24H2 Boot Media
$PackagesToCheck += [pscustomobject]@{ PackageID = "2CM00004"; SourceVersion = "1"; SourceName = "24H2 Boot StifleR: 10.0.26100.1457_24.08.21" } # 24H2 Boot Media



#$PackagesToCheck += [pscustomobject]@{ PackageID = "PS10001F"; SourceVersion = "2" } # P2P Test Package - 200 MB Single File
#$PackagesToCheck += [pscustomobject]@{ PackageID = "PS10012D"; SourceVersion = "1" } # P2P Test Package - 300 MB Single File
#$PackagesToCheck += [pscustomobject]@{ PackageID = "PS1001D6"; SourceVersion = "10" } # 2Pint WinPE 11 x64 - OSD Toolkit
#$PackagesToCheck += [pscustomobject]@{ PackageID = "PS100003"; SourceVersion = "22" } # Configuration Manager Client Package
#$PackagesToCheck += [pscustomobject]@{ PackageID = "PS10014F"; SourceVersion = "1" } # Dell Drivers - Dell Latitude 3120 - Windows 11 x64 A01
#$PackagesToCheck += [pscustomobject]@{ PackageID = "PS1001E5"; SourceVersion = "2" } # Windows 11 Enterprise x64 23H2

# Use BCMon 1.26 or later
$BCMonURL = "https://raw.githubusercontent.com/2pintsoftware/BranchCache/master/BCMon/TwoPint.BCMon.Framework_Release_x64_1.27.0.0.zip"
$DownloadFileName = $BCMonURL |Split-Path -Leaf
$BCMonPath = "$env:ProgramData\2Pint\BCMonNet"
if (!(Test-Path -Path $BCMonPath)){New-Item -Path $BCMonPath -ItemType Directory -Force | Out-Null}
$BCMon = "$BCMonPath\BCMon.Net.exe"

#Download & Extract BCMon
if (!(Test-Path -Path "$BCMonPath\$DownloadFileName")){
    Start-BitsTransfer -Description "BCMonitor" -Destination $BCMonPath -Source $BCMonURL -DisplayName "BCMon"
}
if (Test-Path -Path "$BCMonPath\$DownloadFileName"){
    Expand-Archive -Path "$BCMonPath\$DownloadFileName" -DestinationPath $BCMonPath -Force
}



# Check for BCMon
If (!(Test-Path $BCMon)){
    Write-Warning "BCMon does not exist in $BCMon, aborting script..."
    Break
}

# Write BCMon appsettings.json file if PKI *(HTTPS) mode is detected 
$Path = "HKLM:SOFTWARE\Microsoft\CCM"
$PKIMode = $False
$HttpsState = ""
$ErrorActionPreference="SilentlyContinue" # workaround for Get-ItemPropertyValue and ErrorAction bug in PowerShell 5.1
$HttpsState = Get-ItemPropertyValue -Path $Path -Name "HttpsState" 
$ErrorActionPreference="Continue"


If (!($HttpsState)){
    Write-Warning "HttpsState valute not found, not a ConfigMgr client. Aborting script..." 
    Break
}
Else {
    If ($HttpsState -eq 31 -or $HttpsState -eq 63){
        # We are in PKI mode
        $PKIMode = $true
    }
}

# Look for cert if PKI Mode detected
If ($PKIMode) {

    # Get Client FQDN
    $ClientFQDN = [System.Net.Dns]::GetHostByName($env:computerName).HostName
    $CertSubject = "CN=" + $ClientFQDN 
    $Cert = ""
    # Get most recent cert
    $Cert = Get-ChildItem -path Cert:\LocalMachine\My\* | Where-Object {$_.Subject -eq $CertSubject} | Sort-Object NotAfter -Descending | Select -First 1

    If ($Cert){
        # Cert found, checking expiry date
        $Date = Get-Date
        If ($Date -gt $Cert.NotAfter){
            Write-Warning "Certificate found, but it's expired. Expiry date: $($Cert.NotAfter). Aborting script..."   
            break 
        }
    }
    Else{
        # No cert found
        Write-Warning "We are in PKI mode, but no valid certificate found. Aborting script..."
        Break
    }

    # Create the JSON object for the appsettings.json file
    # HttpClientCertificateThumbprint value is updated with value from cert
    $JSON = @"
    {
      "Logging": {
        "LogLevel": {
          "Default": "Warning",
          "TwoPint.PeerDist": "Information",
          "TwoPint.PeerDist.Service.Services.ProbeDecoder": "Warning"
        },
        "File": {
          "Path": "app.log",
          "Append": true,
          "MinLevel": "Debug", // min level for the file logger
          "FileSizeLimitBytes": 0, // use to activate rolling file behaviour
          "MaxRollingFiles": 0 // use to specify max number of log files
        }
      },
      "Settings": {
        "EnableFileLog": true,
        "IgnoreHttpCertificateError": true,
        "HttpAgent": "2Pint Software BC HashiBashi",
        "HttpClientCertificateThumbprint": "$($Cert.Thumbprint)"
      },
      "UdpSettings": {
        // Maximum number of messages to store in udp queue; if full, message will be dropped till channel clears up
        "MaximumMessagesInChannel": 1024,
        // maximum size of UDP message to be read (we are renting this size, and thus message has to be smaller)
        "MaximumBufferSize": 4192,
        "SenderCheckQueueIntervalWhileIdleInMs": 1, // how long to sleep the thread (while not sending messages) before checking the queue again
        "SenderRepeatCount": 1, // how many times to send udp packet
        // Random delay between sending data to same ipEndPoint (putting both as zero will add one tick delay to it)
        "SenderRepeatDelayRangeToSameEndPointInMs": {
          "MinInclusive": 0,
          "MaxInclusive": 1
        } // random delay between sending data to same ipEndPoint
      }
    }
"@
}
Else{

    # Create the JSON object for the appsettings.json file, without cert
    # HttpClientCertificateThumbprint value is set to ""
    $JSON = @"
    {
      "Logging": {
        "LogLevel": {
          "Default": "Warning",
          "TwoPint.PeerDist": "Information",
          "TwoPint.PeerDist.Service.Services.ProbeDecoder": "Warning"
        },
        "File": {
          "Path": "app.log",
          "Append": true,
          "MinLevel": "Debug", // min level for the file logger
          "FileSizeLimitBytes": 0, // use to activate rolling file behaviour
          "MaxRollingFiles": 0 // use to specify max number of log files
        }
      },
      "Settings": {
        "EnableFileLog": true,
        "IgnoreHttpCertificateError": true,
        "HttpAgent": "2Pint Software BC HashiBashi",
        "HttpClientCertificateThumbprint": ""
      },
      "UdpSettings": {
        // Maximum number of messages to store in udp queue; if full, message will be dropped till channel clears up
        "MaximumMessagesInChannel": 1024,
        // maximum size of UDP message to be read (we are renting this size, and thus message has to be smaller)
        "MaximumBufferSize": 4192,
        "SenderCheckQueueIntervalWhileIdleInMs": 1, // how long to sleep the thread (while not sending messages) before checking the queue again
        "SenderRepeatCount": 1, // how many times to send udp packet
        // Random delay between sending data to same ipEndPoint (putting both as zero will add one tick delay to it)
        "SenderRepeatDelayRangeToSameEndPointInMs": {
          "MinInclusive": 0,
          "MaxInclusive": 1
        } // random delay between sending data to same ipEndPoint
      }
    }
"@
}

# Write the appsettings.json file
$JSON | Out-File "$BCMonPath\appsettings.json"

# Create Download folders
$DownloadPath = "C:\BCTemp"
New-Item -Type Directory -Path $DownloadPath -Force | Out-Null

# Delete any existing log file if it exists
If (Test-Path $Logfile){Remove-Item $Logfile -Force -ErrorAction SilentlyContinue -Confirm:$false}

function Write-Log {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        $Message,
        [Parameter(Mandatory=$false)]
        $ErrorMessage,
        [Parameter(Mandatory=$false)]
        $Component = "Script",
        [Parameter(Mandatory=$false)]
        [int]$Type
    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
   $Time = Get-Date -Format "HH:mm:ss.ffffff"
   $Date = Get-Date -Format "MM-dd-yyyy"
   if ($ErrorMessage -ne $null) {$Type = 3}
   if ($Component -eq $null) {$Component = " "}
   if ($Type -eq $null) {$Type = 1}
   $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
   $LogMessage.Replace("`0","") | Out-File -Append -Encoding UTF8 -FilePath $LogFile
}

cls
# Lookup package in remote BranchCache cache
[System.Collections.ArrayList]$PackageInfo = @()
foreach ($RemoteComputerName in $RemoteComputerNames){
    Write-Host "$RemoteComputerName" -ForegroundColor Cyan
    $BCStatus = Invoke-Command -ComputerName $RemoteComputerName -ScriptBlock {Get-BCStatus}
    Write-Host -ForegroundColor Cyan "BC % of Disk: $($BCStatus.DataCache.MaxCacheSizeAsPercentageOfDiskVolume) | Max Size: $([math]::Round($BCStatus.DataCache.MaxCacheSizeAsNumberOfBytes / 1048576)) MB | Current Size: $([math]::Round($BCStatus.DataCache.CurrentSizeOnDiskAsNumberOfBytes / 1048576)) MB | Active Size: $([math]::Round($BCStatus.DataCache.CurrentActiveCacheSize / 1048576)) MB "
    foreach ($DP in $DPs){
        foreach ($PackageToCheck in $PackagesToCheck){

            $Message = "DP is: $DP. Remote Client is: $RemoteComputerName. Working on Package: $($PackageToCheck.PackageID) version: $($PackageToCheck.SourceVersion).  | $($PackageToCheck.SourceName)"
            Write-Host $Message
            Write-Log -Message  $Message
    
            # Request temporary files for RedirectStandardOutput and RedirectStandardError
            $RedirectStandardOutput = [System.IO.Path]::GetTempFileName()
            $RedirectStandardError = [System.IO.Path]::GetTempFileName()

            # Query local cache
            $Result = Start-Process $BCmon -ArgumentList "Package Id $($PackageToCheck.PackageID) -v $($PackageToCheck.SourceVersion) -h $DP -d $RemoteComputerName`:$BCPort" -NoNewWindow -Wait -PassThru -RedirectStandardOutput $RedirectStandardOutput -RedirectStandardError $RedirectStandardError
            # Show BCMon cpnsole output for troubleshooting
            #Start-Process cmd.exe -ArgumentList "/k `"$BCmon`" Package Id $($PackageToCheck.PackageID) -v $($PackageToCheck.SourceVersion) -h $DP -d $RemoteComputerName`:$BCPort" -Wait 

            If ($Result.ExitCode -eq 0){
                # Parse the BCMon Standard Output log for cache info
                If ((Get-Item $RedirectStandardOutput).length -gt 0){
                        
                    $CacheInfoFromStandardOutput = Get-Content $RedirectStandardOutput | Select-String -SimpleMatch -Pattern "In Cache"
                        
                    If ($CacheInfoFromStandardOutput){
                        $CacheString = $CacheInfoFromStandardOutput.ToString()

                        If ($CacheString){
                            $CachePercentage = [decimal]($CacheString.split(',')[-1].Trim().Split(" ")[0]).Replace("%","")
                        }
                        Else {
                            $CachePercentage = [decimal]"0.00"
                        }
                    }
                    Else {
                        $CachePercentage = [decimal]"0.00"
                    }
                        
                    $Message = "DP is: $DP.  Remote PC is $RemoteComputerName. Package: $($PackageToCheck.PackageID) BranchCache Cache Percentage: $CachePercentage "
                    Write-Host $Message -ForegroundColor Green
                    Write-Log -Message $Message

                    $obj = [PSCustomObject]@{
                        DP = $DP
                        Package = $PackageToCheck.PackageID
                        RemoteClient = $RemoteComputerName
                        BCPercentage = $CachePercentage
                    }

                    # Add all the values
                    $PackageInfo.Add($obj)|Out-Null
                }

            }
            Else {
                #Write-Warning "Reached error"
                
                # Log the BCMon Standard Output, skip any empty lines
                # NOTE: BCMon logs errors to Standard Output
                If ((Get-Item $RedirectStandardOutput).length -gt 0){
                    Write-Log -Message "BCMon did not run"
                    $CleanedRedirectStandardOutput = Get-Content $RedirectStandardOutput | Where-Object {$_.trim() -ne "" }
                } 
                foreach ($row in $CleanedRedirectStandardOutput){
                    Write-Log -Message $row
                    If ($row | Select-String -SimpleMatch -Pattern "Error" -Quiet){
                        Write-Warning "$row"
                    }
                }

                # Log the BCMon Standard Error, skip any empty lines
                If ((Get-Item $RedirectStandardError).length -gt 0){
                    Write-Log -Message "BCMon did not run"
                    $CleanedRedirectStandardError = Get-Content $RedirectStandardError | Where-Object {$_.trim() -ne "" }
                } 
                foreach ($row in $CleanedRedirectStandardError){
                    Write-Log -Message $row
                }

                Write-Warning "BCMon failed with Exit Code: $($Result.ExitCode) for Package: $($PackageToCheck.PackageID), with Source version: $($PackageToCheck.SourceVersion) on DP $DP"
                If ($($Result.ExitCode) -eq -2147467261) {
                    Write-Warning "Exit code -2147467261 means the DP is currently calculating the checksum, please try again in 30 seconds"
                }
                If ($($Result.ExitCode) -eq 1) {
                    Write-Warning "Exit code 1 usually means the Package ID or Source Version is incorrect "
                }

            }

        }
    }
    Write-Host "-----------------------------------------------------------------------------------------------------"
}

