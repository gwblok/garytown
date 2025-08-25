function Install-ExplorerPP {
    $URL = "https://download.explorerplusplus.com/stable/1.4.0/explorerpp_x64.zip"

    #Download the zip file to $env:\Temp, then extract to $env:systemroot
    $DownloadPath = "$env:Temp\explorerpp_x64.zip"
    $ExtractPath = "$env:systemroot"
    Invoke-WebRequest -Uri $URL -OutFile $DownloadPath -UseBasicParsing
    Expand-Archive -Path $DownloadPath -DestinationPath $ExtractPath -Force
}