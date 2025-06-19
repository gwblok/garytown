#GARYTOWN.COM


$ExpandPath = "$env:programdata\BGInfo"
$RegistryKey = "HKLM:\SOFTWARE\2Pint Software\BGInfo"

#Region Build Registry Values
if (-not(Test-Path -path $RegistryKey)){
    New-Item -Path $RegistryKey -ItemType directory -Force | Out-Null
}

#Build Solution and Grab Data if running as SYSTEM
if ($env:USERNAME -eq "SYSTEM") {
    Write-Output "Running as SYSTEM, skipping BGInfo Scheduled Task creation."
    
    #Download & Extract to System32
    $FileName = "BGInfo.zip"
    
    
    if (-not (Test-Path -Path $ExpandPath)) {
        Write-Output "Creating Directory: $ExpandPath"
        New-Item -ItemType Directory -Path $ExpandPath -Force
    }
    if (Test-Path -path $ExpandPath\Bginfo64.exe) {
        Write-Output "BGInfo already exists in $ExpandPath, skipping download."
    }
    else{
        $URL = "https://download.sysinternals.com/files/$FileName"
        Write-Output "Downloading $URL"
        # Check if the file already exists before downloading
        if (Test-Path -Path $env:TEMP\$FileName) {
            Write-Output "File already exists in TEMP directory, skipping download."
        } else {
            Write-Output "Downloading $FileName to $env:TEMP"
            Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
            if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
            else{Write-Output "Failed Downloaded"; exit 255}
        }
        Write-Output "Starting Extraction of $FileName to $ExpandPath"
        Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
        if (Test-Path -Path $ExpandPath){Write-Output "Successfully Extracted Zip File"}
        else{Write-Output "Failed Extract"; exit 255}
    }
    $HyperVEnabled = Get-Service -Name "vmms" -ErrorAction SilentlyContinue
    if ($HyperVEnabled){
        New-ItemProperty -Path $RegistryKey -Name 'HyperV' -PropertyType String -Value "HyperV Enabled               VMs: $((Get-VM).count)" -Force | Out-Null
    }
    #Server Config and Background Image
    if (Get-WindowsEdition -Online | Where-Object { $_.Edition -match "Server" }) {
        Write-Output "Running on Windows Server Edition"
        #Upload your own .bgi template file and then download it.
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CM_LAB/BGINFO/Server.bgi" -OutFile "$ExpandPath\BGInfo.bgi"
        #Download Backgound Image
        if (-not (Test-Path -Path "$ExpandPath\bginfo.png")) {
            Write-Output "Downloading Background Image"
            Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CM_LAB/BGINFO/2pint-desktop-product-icons-colour-dark-1920x1080.bmp" -OutFile "$ExpandPath\bginfo.bmp"
            
        } else {
            Write-Output "Background Image already exists, skipping download."
        }
        # Get active network card information & trying to accomidate for hyperv hosts
        $NIC = (Get-CimInstance -Class win32_NetworkAdapter -Filter 'NetConnectionStatus = 2' | Select -First 1)
        if ($Null -eq $NIC.Speed){
            $NICs = (Get-CimInstance -Class win32_NetworkAdapter -Filter 'NetConnectionStatus = 2')
            $NICSpeed = (Get-CimInstance -Class win32_NetworkAdapter -Filter 'NetConnectionStatus = 2' | Where-Object {$_.Speed -ne $null}).Speed | Select -First 1
        }
        $NICSpeed = $NICSpeed/1000000
        $NICIP = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1" | % { $_.IPAddress | ? { -not $_.Contains(":") } } | Where-Object {$_ -notmatch '169.'}
        $UUID = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
        New-ItemProperty -Path $RegistryKey -Name 'Mac' -PropertyType String -Value $NIC.MacAddress -Force | Out-Null
        New-ItemProperty -Path $RegistryKey -Name 'NetworkCard' -PropertyType String -Value $NIC.Name -Force | Out-Null
        New-ItemProperty -Path $RegistryKey -Name 'NetworkSpeed' -PropertyType String -Value $NICSpeed -Force | Out-Null
        New-ItemProperty -Path $RegistryKey -Name 'NetworkIP' -PropertyType String -Value $NICIP -Force | Out-Null
        
    } 
    # If running on Windows Client Edition, use a different .bgi file & background image
    else {
        Write-Output "Running on Windows Client Edition"
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CM_LAB/BGINFO/Client.bgi" -OutFile "$ExpandPath\BGInfo.bgi"
        #Download Backgound Image
        if (-not (Test-Path -Path "$ExpandPath\bginfo.png")) {
            Write-Output "Downloading Background Image"
            Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CM_LAB/BGINFO/2pint-desktop-icon-text-dark-1920x1080.bmp" -OutFile "$ExpandPath\bginfo.bmp"
            
        } else {
            Write-Output "Background Image already exists, skipping download."
        }
        

        #Capture Branch Cache Status
        $BCStatus = (Get-Service -name PeerDistSvc).status
        if ($BCStatus -eq 'Running') {
            $BCStatus = (Get-BCClientConfiguration).CurrentClientMode
        } else {
            Write-Output "Peer Distribution Service is not running."
        }
        New-ItemProperty -Path 'HKLM:\SOFTWARE\2Pint Software\BGinfo' -Name 'BCStatus' -Value $BCStatus -PropertyType String -Force | Out-Null
        # Get active network card information & trying to accommodate for hyperv hosts
        $NIC = (Get-CimInstance -Class win32_NetworkAdapter -Filter 'NetConnectionStatus = 2' | Select -First 1)
        if ($Null -eq $NIC.Speed){
            $NICs = (Get-CimInstance -Class win32_NetworkAdapter -Filter 'NetConnectionStatus = 2')
            $NICSpeed = (Get-CimInstance -Class win32_NetworkAdapter -Filter 'NetConnectionStatus = 2' | Where-Object {$_.Speed -ne $null}).Speed | Select -First 1
        }
        $NICSpeed = $NICSpeed/1000000
        $NICIP = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 1" | % { $_.IPAddress | ? { -not $_.Contains(":") } }
        $UUID = (Get-CimInstance -Class Win32_ComputerSystemProduct).UUID
        New-ItemProperty -Path $RegistryKey -Name 'Mac' -PropertyType String -Value $NIC.MacAddress -Force | Out-Null
        New-ItemProperty -Path $RegistryKey -Name 'NetworkCard' -PropertyType String -Value $NIC.Name -Force | Out-Null
        New-ItemProperty -Path $RegistryKey -Name 'NetworkSpeed' -PropertyType String -Value $NICSpeed -Force | Out-Null
        New-ItemProperty -Path $RegistryKey -Name 'NetworkIP' -PropertyType String -Value $NICIP -Force | Out-Null
    }
}
# If not running as SYSTEM, trigger BGInfo
else{
    #Create Process Vars
    $BGinfoPath = "$ExpandPath\bginfo64.exe"
    $BGInfoArgs = "$ExpandPath\BGInfo.bgi /nolicprompt /silent /timer:0"
    #Start BG Info
    Start-Process -FilePath $BGinfoPath -ArgumentList $BGInfoArgs -PassThru
}