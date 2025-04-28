
#region functions
function Test-NetworkConnectivity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Domain,  #Domain to ping

        [Parameter(Mandatory = $false)]
        [int]$Timeout = 60,  #Timeout in seconds (default: 60)

        [Parameter(Mandatory = $false)]
        [int]$Interval = 3  # Interval between pings in seconds (default: 3)
    )

    Write-Host "Pinging $Domain..."

    $startTime = Get-Date
    $TimedOut = $false

    do {
        $pingResult = Test-Connection -ComputerName $Domain -Count 1 -Quiet
        Start-Sleep -Seconds $Interval
        Write-Host "Checking connection..."

        # Check if the timeout period has been exceeded
        $elapsedTime = (Get-Date) - $startTime
        if (($elapsedTime.TotalSeconds -ge $Timeout) -and !($pingResult)) {
            Write-Host "Timeout reached. $Domain is not reachable." -ForegroundColor Red
            $TimedOut = $true
        }

    } while ((!($pingResult)) -and (!($TimedOut)))

    if ($pingResult) {
        Write-Host "$Domain is reachable." -ForegroundColor Green
        return $true
    } else {
        return $false
    }
}

function Connect-WiFi {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SSID  #SSID to connect to
    )

    Write-Host "Attempting to connect to WiFi network '$SSID'..."

    #Connect to the WiFi
    $WifiConnectionResult = netsh wlan connect name="$SSID"

    #Check the result
    if ($WifiConnectionResult -notlike "*Connection request was completed successfully.*") {
        Write-Host "Connection to WiFi wasn't successful. Error: $WifiConnectionResult" -ForegroundColor Red
        #Write-Host "Please try to connect manually instead." -ForegroundColor Yellow
        return $false  #Return false if connection failed
    } else {
        Write-Host "Successfully connected to WiFi network '$SSID'." -ForegroundColor Green
        return $true  #Return true if connection succeeded
    }
}
#endregion functions

#region variables

$InitNetwork = Start-Process -FilePath ".\wpeinit.exe" -ArgumentList "-InitializeNetwork" -NoNewWindow -Wait
$URLForTestingNetworkAccess = "google.com"
$SSIDNameFromiPXE = ""
$PSKFromiPXE = ""

#endregion variables

Write-Host "Checking network connection..."
$TestWired = Test-Connection -ComputerName $URLForTestingNetworkAccess -Count 1 -Quiet
if ($TestWired) {
    Write-Host "Network already connected, nothing to do here."
    Start-Sleep -Seconds 1
    Exit 0
    } 
    Else {

        #If we don't have network connectivity at this stage, we assume that a wireless connection is required.
        #Start by checking if we have WiFi info carried over from iPXE, if not, check if there's a DefaultWifiProfile.xml provided in the boot image,
        #finally, if we're still not connected, let the user see available networks and try to connect manually.

        Start-Service -Name wlansvc
        Start-Sleep -Seconds 5

        $WirelessNetworkAdapter = Get-WmiObject -ClassName Win32_NetworkAdapter | Where-Object {($_.NetConnectionID -eq 'Wi-Fi') -or ($_.NetConnectionID -eq 'WiFi') -or ($_.NetConnectionID -eq 'WLAN')} | Select-Object -First 1
        if ($WirelessNetworkAdapter.NetEnabled -eq $true) {
            (Get-WmiObject -ClassName Win32_NetworkAdapter | Where-Object {$_.NetConnectionID -eq 'Wi-Fi'}).disable() | Out-Null
            (Get-WmiObject -ClassName Win32_NetworkAdapter | Where-Object {$_.NetConnectionID -eq 'WiFi'}).disable() | Out-Null
            (Get-WmiObject -ClassName Win32_NetworkAdapter | Where-Object {$_.NetConnectionID -eq 'WLAN'}).disable() | Out-Null
            Write-Host "Disabled all Wifi adapters."
            Start-Sleep -Seconds 2
            (Get-WmiObject -ClassName Win32_NetworkAdapter | Where-Object {$_.NetConnectionID -eq 'Wi-Fi'}).enable() | Out-Null
            (Get-WmiObject -ClassName Win32_NetworkAdapter | Where-Object {$_.NetConnectionID -eq 'WiFi'}).enable() | Out-Null
            (Get-WmiObject -ClassName Win32_NetworkAdapter | Where-Object {$_.NetConnectionID -eq 'WLAN'}).enable() | Out-Null
            Start-Sleep -Seconds 2
            Write-Host "Enabled all Wifi adapters."
        }

        if ($SSIDNameFromiPXE) {

            #Create Wi-Fi profile XML
$profilefromiPXEXML = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSIDNameFromiPXE</name>
    <SSIDConfig>
        <SSID>
            <name>$SSIDNameFromiPXE</name>
        </SSID>
        <nonBroadcast>false</nonBroadcast>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$PSKFromiPXE</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@

            # Save the profile XML to a temporary file
            $tempiPXEProfilePath = "X:\Windows\System32\WifiProfileFromiPXE.xml"
            New-Item -Path $tempiPXEProfilePath -ItemType File -Force | Out-Null
            $profilefromiPXEXML | Out-File -FilePath $tempiPXEProfilePath -Encoding UTF8

            # Add the profile and connect to the network
            netsh wlan add profile filename="$tempiPXEProfilePath" | Out-Null
            Start-Sleep -Seconds 2
            $iPXEWifiConnectionResult = Connect-WiFi -SSID "$SSIDNameFromiPXE"

            # Check if the connection was successful
            if ($iPXEWifiConnectionResult) {
                Write-Host "WiFi connection established." -ForegroundColor Green
            } else {
                Write-Host "WiFi connection failed." -ForegroundColor Red
            }

            # Clean up the temporary profile file
            #Remove-Item -Path $tempiPXEProfilePath -Force

            # Test network connectivity
            if ($iPXEWifiConnectionResult) {
                $WiFiFromiPXEpingResult = Test-NetworkConnectivity -Domain $URLForTestingNetworkAccess -Timeout 60
            } else {
                # Set $WiFiFromiPXEpingResult to $false if connection failed to SSID coming from iPXE
                $WiFiFromiPXEpingResult = $false
            }

            if ($WiFiFromiPXEpingResult) {
                # If the ping is successful, we're golden
                Write-Host "Success! Wifi info from iPXE works!"
                Start-Sleep -Seconds 5
                exit 0
            }

        } #end if ($iPXEConnectedToSSID)

        if (Test-Path DefaultWifiProfile.xml) {
            # Add the Wi-Fi profile
            netsh wlan add profile filename="DefaultWifiProfile.xml"
            Start-Sleep -Seconds 2

            # Connect to the Wi-Fi network
            $SSID = ([xml](Get-Content DefaultWifiProfile.xml)).WLANProfile.Name
            $WifiConnectionResult = Connect-WiFi -SSID "$SSID"

            # Test network connectivity
            $pingResult = Test-NetworkConnectivity -Domain $URLForTestingNetworkAccess -Timeout 60
        } else {
            # Set $pingResult to $false if the profile doesn't exist
            $pingResult = $false
        }

        if ($pingResult) {
            # If the ping is successful, we're golden
            Write-Host "Success!"
            Start-Sleep -Seconds 5
        } else {
            # Ensure the Wi-Fi service is started
            net start wlansvc | Out-Null

            # Check if the connection was successful
            if ($WifiConnectionResult) {
                Write-Host "WiFi connection established." -ForegroundColor Green
            } else {
                Write-Host "WiFi connection not completed. Please connect to your WiFi." -ForegroundColor Yellow
            }


            #Get available Wi-Fi networks
            $response = netsh wlan show networks mode=bssid
            $WLANs = $response | Where-Object { $_ -match "^SSID" } | ForEach-Object {
                $report = "" | Select-Object SSID, NetworkType, Authentication, Encryption, Signal
                $i = $response.IndexOf($_)
                $report.SSID = $_ -replace "^SSID\s\d+\s:\s", ""
                $report.NetworkType = $response[$i + 1].Split(":")[1].Trim()
                $report.Authentication = $response[$i + 2].Split(":")[1].Trim()
                $report.Encryption = $response[$i + 3].Split(":")[1].Trim()
                $report.Signal = $response[$i + 5].Split(":")[1].Trim()
                $report
            }

            #Display available networks in a numbered list
            Write-Host "Available Wi-Fi Networks:" -ForegroundColor Cyan
            $WLANs | ForEach-Object -Begin { $index = 1 } -Process {
                Write-Host "[$index] $($_.SSID) - Signal: $($_.Signal), Authentication: $($_.Authentication)"
                $index++
            }

            #Prompt the user to select a network by number
            do {
                $selection = Read-Host "Enter the number of the network you want to connect to (or press Enter to cancel)"
                if (-not $selection) {
                    Write-Host "No selection made. Exiting." -ForegroundColor Yellow
                    exit
                }
                if ($selection -notmatch '^\d+$' -or [int]$selection -lt 1 -or [int]$selection -gt $WLANs.Count) {
                    Write-Host "Invalid selection. Please enter a valid number from the list." -ForegroundColor Red
                } else {
                    break
                }
            } while ($true)

            #Get the selected SSID
            $selectedNetwork = $WLANs[[int]$selection - 1]
            $SSID = $selectedNetwork.SSID
            Write-Host "You selected: $SSID" -ForegroundColor Green

            #Prompt for the password if needed
            $password = ""
            if ($selectedNetwork.Authentication -ne "Open") {
                $password = Read-Host "Enter password for Wi-Fi network '$SSID'" -AsSecureString
                $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
                    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
                )
            } else {
                $plainPassword = ""
            }

            #Delete any existing profile for the selected SSID
            netsh wlan delete profile name="$SSID" | Out-Null

            #Create Wi-Fi profile XML
$profileXML = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
    <name>$SSID</name>
    <SSIDConfig>
        <SSID>
            <name>$SSID</name>
        </SSID>
        <nonBroadcast>false</nonBroadcast>
    </SSIDConfig>
    <connectionType>ESS</connectionType>
    <connectionMode>auto</connectionMode>
    <MSM>
        <security>
            <authEncryption>
                <authentication>WPA2PSK</authentication>
                <encryption>AES</encryption>
                <useOneX>false</useOneX>
            </authEncryption>
            <sharedKey>
                <keyType>passPhrase</keyType>
                <protected>false</protected>
                <keyMaterial>$plainPassword</keyMaterial>
            </sharedKey>
        </security>
    </MSM>
</WLANProfile>
"@

            # Save the profile XML to a temporary file
            $tempProfilePath = "X:\Windows\System32\UserDefinedWifiProfile.xml"
            New-Item -Path $tempProfilePath -ItemType File -Force | Out-Null
            $profileXML | Out-File -FilePath $tempProfilePath -Encoding UTF8

            # Add the profile and connect to the network
            netsh wlan add profile filename="$tempProfilePath" | Out-Null
            $Result = Connect-WiFi -SSID "$SSID"

            # Test network connectivity
            if ($Result) {
                $ManuallyConnectedWifiPingResult = Test-NetworkConnectivity -Domain $URLForTestingNetworkAccess -Timeout 60
            } else {
                # Set $ManuallyConnectedWifiPingResult to $false if connection failed to manually configured SSID
                $ManuallyConnectedWifiPingResult = $false
            }

            if ($ManuallyConnectedWifiPingResult) {
                # If the ping is successful, we're golden
                Write-Host "Success! Manually configured WiFi works!"
                Start-Sleep -Seconds 5
                exit 0
            }

            # Clean up the temporary profile file
            #Remove-Item -Path $tempProfilePath -Force

        }
    }
