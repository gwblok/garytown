#Ninite Installer Script
#Downloads Ninite Installer based on Input
#Currently Supports a few different apps, feel free to add others
#Supports Install & Uninstall

[CmdletBinding()]
Param(
[Parameter(Mandatory=$true,Position=1,HelpMessage="Application")]
[ValidateNotNullOrEmpty()]
[ValidateSet("7Zip", "Chrome", "FileZilla", "Firefox", "GreenShot", "VLC", "VSCode", "WinDirStat", "libreoffice")]
[string]$NiniteApp,
 
    [Parameter(Mandatory=$true,Position=2,HelpMessage="Install or Uninstall")]
[ValidateNotNullOrEmpty()]
[ValidateSet("Install", "Uninstall")]
[string]$Invoke
)

Write-Host $NiniteApp
Write-Host $Invoke

#Timeout if things are taking too long, odds are good something was too quick for process to monitor, so this is here to make sure it doesn't hang.  15 Minute Timeout, unless the app specifies otherwise.
$AppTimeout = "901"

#Set Information Per App to be used laster
#Download & Process Info

if ($NiniteApp -eq "7Zip")
{
$downloadlink = "https://ninite.com/7Zip/ninite.exe"
$uninstallstring = '"C:\Program Files\7-Zip\Uninstall.exe" /S'
$AppTimeout = "300"
}
if ($NiniteApp -eq "Chrome")
{
$downloadlink = "https://ninite.com/chrome/ninite.exe"
$uninstallstring = "wmic product where name=""Google Chrome"" call uninstall"
}
if ($NiniteApp -eq "FileZilla")
{
$downloadlink = "https://ninite.com/FileZilla/ninite.exe"
$uninstallstring = '"C:\Program Files\FileZilla FTP Client\uninstall.exe" /S'
$AppTimeout = "300"
}
if ($NiniteApp -eq "Firefox")
{
$downloadlink = "https://ninite.com/FireFox/ninite.exe"
$uninstallstring = '"C:\Program Files\Mozilla Firefox\uninstall\helper.exe" /S'
}
if ($NiniteApp -eq "GreenShot")
{
$downloadlink = "https://ninite.com/GreenShot/ninite.exe"
$uninstallstring = '"c:\windows\system32\taskkill.exe" /IM greenshot* /F & "C:\Program Files\Greenshot\unins000.exe" /SILENT'
}
if ($NiniteApp -eq "VLC")
{
$downloadlink = "https://ninite.com/VLC/ninite.exe"
$uninstallstring = '"C:\Program Files\VideoLAN\VLC\uninstall.exe" /S /NCRC'
}
if ($NiniteApp -eq "VSCode")
{
$downloadlink = "https://ninite.com/VSCode/ninite.exe"
$uninstallstring = '"C:\Program Files\Microsoft VS Code\unins000.exe" /SILENT'
}
if ($NiniteApp -eq "WinDirStat")
{
$downloadlink = "https://ninite.com/WinDirStat/ninite.exe"
$uninstallstring = '"C:\Program Files (x86)\WinDirStat\Uninstall.exe" /S'
$AppTimeout = "300"
}
if ($NiniteApp -eq "LibreOffice")
{
$downloadlink = "https://ninite.com/Libreoffice/ninite.exe"
$uninstallstring = '"NA" /S'
$AppTimeout = "300"
}


if ($Invoke -eq "Install")
{
#Download the Ninite File
Invoke-WebRequest -Uri $downloadlink -OutFile $PSScriptRoot\NiniteInstaller.exe -UseBasicParsing -Verbose

if (!(test-path $PSScriptRoot\NiniteInstaller.exe))
{
Write-Host "Did not download, Exit Script"
exit
}

#Launch the Ninite Installer

start-process -FilePath "$PSScriptRoot\NiniteInstaller.exe"
$Y = 1
While(!(Get-WmiObject win32_process -Filter {Name =  'Ninite.exe'}) -and $Y -lt 10){
    Write-Output "Waiting for ninite.exe to download and launch"
    Start-Sleep -Seconds 1
    $Y++
}
#If internet connection not working right, it might not download 
If ($Y -ge 10)
{
Write-Host "Did not download, Exit Script"
Get-Process | Where {$_.Name -like "ninite*"} | Stop-Process -Verbose
exit
}

#Monitor Install Process

    $PIDs = (Get-WmiObject win32_process -Filter {Name = 'Ninite.exe'}).ProcessID
    Write-Host "Ninite Process IDs" $PIDs

    $MSIRunning = (Get-WmiObject win32_process -Filter {Name = "msiexec.exe" or Name = "Target.exe"} | Where-Object {$PIDs -contains $Psitem.ParentProcessID}).ProcessID 
    $X = 1
    while  ($MSIRunning -eq $null -and $X -lt "$AppTimeout")
    {
        $X++
        start-sleep -Seconds 1
        Write-Host "Waiting for Software Installer to Start"
        $MSIRunning = (Get-WmiObject win32_process -Filter {Name = "msiexec.exe" or Name = "Target.exe"} | Where-Object {$PIDs -contains $Psitem.ParentProcessID}).ProcessID 
    }
    Write-Host "Installer Started"
    Write-Host "Waiting for Software Installer To Finish"
    $ParentPID = (Get-WmiObject win32_process -Filter {Name = "msiexec.exe" or Name = "Target.exe"} | Where-Object {$PIDs -contains $Psitem.ParentProcessID}).ProcessID
    $ParentProc = Get-Process -Id $ParentPID
    $ParentProc.WaitForExit()
    Write-Host "Software Install Finished" 


#Kill Task on the Ninite Installer
start-sleep -Seconds 5
Write-Host "Kill Ninite Wrapper"
Get-Process | Where {$_.Name -like "ninite*"} | Stop-Process -Verbose

}
if (test-path $PSScriptRoot\NiniteInstaller.exe)
{
start-sleep -Seconds 2
Write-Host "Delete Ninite Installer"
Remove-Item "$PSScriptRoot\NiniteInstaller.exe"
}

#Run the Uninstall if in Uninstall Mode
if ($Invoke -eq "Uninstall")
{cmd.exe /c $uninstallstring}
