#GARYTOWN.COM
#Download & Extract to System32
function Install-ZoomIt {
    $FileName = "ZoomIt.zip"
    $ExpandPath = "$env:windir\temp"
    $URL = "https://download.sysinternals.com/files/$FileName"
    Write-Output "Downloading $URL"
    Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
    if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
    else{Write-Output "Failed Downloaded"; exit 255}
    Write-Output "Starting Extraction of $FileName to $ExpandPath"
    Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
    if (Test-Path -Path $ExpandPath\ZoomIt.exe){
        Write-Output "Successfully Extracted Zip File to temp"
        Write-Output "Copying ZoomIt.exe to System32"
        Copy-Item -Path "$ExpandPath\ZoomIt.exe" -Destination "$env:windir\system32\ZoomIt.exe" -Force
    }
    else{Write-Output "Failed Extract"; exit 255}
}