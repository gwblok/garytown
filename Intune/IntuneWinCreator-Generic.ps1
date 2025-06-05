#Gary Blok


Function New-IntuneApp {
    [CmdletBinding()]
    param (
        
        [string]$IntuneUtilFolderPath,
        [parameter(Mandatory=$true)]
        [string]$SourceAppPath,
        [string]$OutputAppPath
    )



    if ($IntuneUtilFolderPath){
        if (Test-Path -Path $IntuneUtilFolderPath\IntuneWinAppUtil.exe){
            Write-Host "Using IntuneWinAppUtil from $IntuneUtilFolderPath" -ForegroundColor Green
        }
        else {
            Write-Host "IntuneWinAppUtil not found in $IntuneUtilFolderPath, please check the path." -ForegroundColor Red
            return
        }
    }
    else {
        $TempLocation = [System.IO.Path]::GetTempPath()
        $IntuneUtilFolderPath = "$TempLocation\Intune"
    }

    $IntuneUtilPath = "$IntuneUtilFolderPath\IntuneWinAppUtil.exe"
    $IntuneUtilURL = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"
    #https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/blob/master/IntuneWinAppUtil.exe


    #Test Folder Structure and Build if needed
    if (!(Test-Path -Path $SourceAppPath)){
        New-item -Path $SourceAppPath -ItemType Directory -Force | Out-Null
        Write-Host "Created $SourceAppPath" -ForegroundColor Green
        Write-Host "Place your SOURCE HERE!!!" -ForegroundColor Red
        return
    }
    else {
        Write-Host "Using Source: $SourceAppPath" -ForegroundColor Green
    }
    if (-not $OutputAppPath) {
        $OutputAppPath = $SourceAppPath | Split-Path -Parent
        $SourceFolderName = Split-Path -Path $SourceAppPath -Leaf
        $OutputAppPath = "$OutputAppPath\$SourceFolderName-Output"
    }
    if (!(Test-Path -Path $OutputAppPath)){
        New-item -Path $OutputAppPath -ItemType Directory -Force | Out-Null
        Write-Host "Created $OutputAppPath" -ForegroundColor Green
    }
    else {
        Write-Host "Using Output: $OutputAppPath" -ForegroundColor Green
    }

    if (!(Test-Path -Path $IntuneUtilFolderPath)){
        New-item -Path $IntuneUtilFolderPath -ItemType Directory -Force | Out-Null
        Write-Host "Created $IntuneUtilFolderPath" -ForegroundColor Green
    }
    else {
        Write-Host "Using IntuneUtilFolder: $IntuneUtilFolderPath" -ForegroundColor Green
    }
    if (!(Test-Path -Path $IntuneUtilPath)){
        Invoke-WebRequest -UseBasicParsing -Uri $IntuneUtilURL -OutFile $IntuneUtilPath
        Write-Host "Downloaded IntuneWinAppUtil.exe to $IntuneUtilPath" -ForegroundColor Green
    }
    else{
        Write-Host "Using IntuneWinAppUtil: $IntuneUtilPath" -ForegroundColor Green
    }


    $App = get-item -Path $SourceAppPath
    $SetupCMD = Get-ChildItem -Path $App.FullName -Filter *.cmd
    if (!($SetupCMD)){
        $SetupEXE = Get-ChildItem -Path $App.FullName -Filter *.exe
        if (!($SetupEXE)){$SetupEXE = Get-ChildItem -Path $App.FullName -Filter *.msi}
    }
    else {
        $SetupEXE = $SetupCMD
    }
    $SetupFolder = $App.FullName
    #$CreateIntuneApp = Start-Process -FilePath $IntuneUtilPath -ArgumentList "-c $SetupFolder -s $SetupEXEPath -o $OutPutPath -q" -Wait -PassThru
    Write-Host "Starting Intune Package Creation" -ForegroundColor Green
    write-Host "& $IntuneUtilPath -c $SetupFolder -s $($SetupEXE.FullName) -o $OutputAppPath -q"
    & $IntuneUtilPath -c $SetupFolder -s $SetupEXE.FullName -o $OutputAppPath -q

    Write-Host "Finished App for Intune: $OutputAppPath" -ForegroundColor Green
}