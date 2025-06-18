#GARYTOWN.COM
#Download & Extract to System32
$FileName = "BGInfo.zip"
$ExpandPath = "$env:programdata\BGInfo"

if (-not (Test-Path -Path $ExpandPath)) {
    Write-Output "Creating Directory: $ExpandPath"
    New-Item -ItemType Directory -Path $ExpandPath -Force
}

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
    $BCStatus = (Get-Service -name PeerDistSvc).status
    if ($BCStatus -eq 'Running') {
        $BCStatus = (Get-BCClientConfiguration).CurrentClientMode
    } else {
        Write-Output "Peer Distribution Service is not running."
    }
    if (-not(Test-Path -path 'HKLM:\SOFTWARE\2Pint Software\BGinfo')){
        New-Item -Path 'HKLM:\SOFTWARE\2Pint Software\BGinfo' -ItemType directory -Force | Out-Null
    }
    New-ItemProperty -Path 'HKLM:\SOFTWARE\2Pint Software\BGinfo' -Name 'BCStatus' -Value $BCStatus -PropertyType String -Force | Out-Null
}


#Create Process Vars
$BGinfoPath = "$ExpandPath\bginfo64.exe"
$BGInfoArgs = "$ExpandPath\BGInfo.bgi /nolicprompt /silent /timer:0"


#Start BG Info
Start-Process -FilePath $BGinfoPath -ArgumentList $BGInfoArgs -PassThru