#Builds Custom Opera Install and sets things how I want them to be

$BuildPath = 'c:\OperaBuild'
$CustomConfigsPath = 'c:\OperaBuild\CustomConfigs'
$InstallPath = "$BuildLocation\Opera"
$OperaInstallerPath = "$BuildPath\OperaInstaller.exe"
$URL = "https://net.geo.opera.com/opera_portable/stable/windows"

$ConfigFiles = @(
@{FileName = 'installer_prefs.json' ;URL = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/AppCustomizations/Opera/W365/installer_prefs.json'; InstallPath = "$InstallPath"}
@{FileName = 'Local State' ;URL = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/AppCustomizations/Opera/W365/Local%20State'; InstallPath = "$InstallPath\profile\data"}
@{FileName = 'Preferences' ;URL = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/AppCustomizations/Opera/W365/Preferences'; InstallPath = "$InstallPath\profile\data\Default"}
)

try {
    [void][System.IO.Directory]::CreateDirectory($BuildPath)
    [void][System.IO.Directory]::CreateDirectory($CustomConfigsPath)
}
catch {throw}


Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $OperaInstallerPath

$OperaArgs = "/singleprofile=1 /copyonly=1 /enable-stats=0 /enable-installer-stats=0 /launchbrowser=0 /installfolder=$InstallPath /allusers=0 /run-at-startup=0 /import-browser-data=0 /setdefaultbrowser=0 /language=en /personalized-ads=0 /personalized-content=0 /general-location=0 /consent-given=0 /silent"
$InstallOpera = Start-Process -FilePath $OperaInstallerPath -ArgumentList $OperaArgs -PassThru -Wait -NoNewWindow

Start-Sleep -Seconds 30

#Confirm Opera Path for Install is there
if (Test-Path -Path $InstallPath){
    
    #Cleanup Localizations
    $OperaInfo = Get-Item -Path "$InstallPath\opera.exe"
    Get-ChildItem -path "$InstallPath\$($OperaInfo.VersionInfo.ProductVersion)\localization" | Where-Object {$_.name -ne "en-US.pak"} | Remove-Item

    #Cleanup AutoUpdater
    Remove-Item -Path "$InstallFolder\autoupdate" -Force -Recurse
    
}

#Setup Config Files
foreach ($ConfigFile in $ConfigFiles){
    
    #Download ConfigFile to ConfigFiles Staging
    Invoke-WebRequest -UseBasicParsing -Uri $ConfigFile.URL -OutFile "$CustomConfigsPath\$($ConfigFile.FileName)"

    #Copy Config File to proper Location
    Copy-Item -Path "$CustomConfigsPath\$($ConfigFile.FileName)" -Destination $ConfigFile.InstallPath -Force
}
