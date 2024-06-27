#GARYTOWN.COM
#Download & Extract to System32
$FileName = "BGInfo.zip"
$ExpandPath = "$env:windir\system32"
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
Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/master/OSD/BGInfo/WinPE-TSStarted.bgi" -OutFile "$env:TEMP\WinPE_BGInfo.bgi"

#Create Process Vars
$BGinfoPath = "$ExpandPath\bginfo64.exe"
$BGInfoArgs = "$env:TEMP\WinPE_BGInfo.bgi /nolicprompt /silent /timer:0"


#Start BG Info
Start-Process -FilePath $BGinfoPath -ArgumentList $BGInfoArgs -PassThru

#Fix Refresh on 24H2 Boot Image
if (get-process -name WallpaperHost -ErrorAction SilentlyContinue) {
    Stop-Process -Name WallpaperHost -Force
    if (Test-Path -Path $env:SystemRoot\System32\WallpaperHost.exe) {
        Start-Process -FilePath $env:SystemRoot\System32\WallpaperHost.exe -PassThru
    }
}
