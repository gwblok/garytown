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
Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
else{Write-Output "Failed Downloaded"; exit 255}
Write-Output "Starting Extraction of $FileName to $ExpandPath"
Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
if (Test-Path -Path $ExpandPath){Write-Output "Successfully Extracted Zip File"}
else{Write-Output "Failed Extract"; exit 255}


#Upload your own .bgi template file and then download it.
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CM_LAB/BGINFO/Server.bgi" -OutFile "$ExpandPath\Server_BGInfo.bgi"

#Download Backgound Image
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CM_LAB/BGINFO/2pint-desktop-product-icons-colour-dark-1920x1080.bmp" -OutFile "$ExpandPath\2pint-desktop-product-icons-colour-dark-1920x1080.png"


#Create Process Vars
$BGinfoPath = "$ExpandPath\bginfo64.exe"
$BGInfoArgs = "$ExpandPath\Server_BGInfo.bgi /nolicprompt /silent /timer:0"


#Start BG Info
Start-Process -FilePath $BGinfoPath -ArgumentList $BGInfoArgs -PassThru


#Create Scheduled Task to run at logon
$Action = New-ScheduledTaskAction -Execute $BGinfoPath -Argument $BGInfoArgs
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Limited
$Task = New-ScheduledTask -Action $Action -Trigger $Trigger -Principal $Principal -Description "Run BGInfo at user logon"
Register-ScheduledTask -TaskName "BGInfo" -InputObject $Task -Force