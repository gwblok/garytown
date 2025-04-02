#Gary Blok | @gwblok | GARYTOWN
#Create ConfigMgr Control Panel Shortcut & Software Center Shortcut on Desktop

$Remediation = $false

#Build ShortCut Information - Control Panel
$SourceExe = "$env:windir\system32\control.exe"
$DestinationPath = "$env:Public\Desktop\Control Panel.lnk"
$ArgumentsToSourceExe = $Null
if (!(Test-Path -Path $DestinationPath)){

    if ($Remediation -eq $true){
        #Create Shortcut
        $WshShell = New-Object -comObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($DestinationPath)
        $Shortcut.IconLocation = "C:\Windows\System32\SHELL32.dll, 21"
        $Shortcut.TargetPath = $SourceExe
        $Shortcut.Arguments = $ArgumentsToSourceExe
        $Shortcut.Save()

        write-output "Creating Control Panel Icon on Desktop"
    }
    else { exit 1 }

}

#Build ShortCut Information - ConfigMgr Control Applet
$SourceExe = "$env:windir\system32\control.exe"
$DestinationPath = "$env:Public\Desktop\ConfigMgr Panel.lnk"
if (Test-Path -Path "$env:windir\ccm\ccmexec.exe"){
    if (!(Test-Path -Path $DestinationPath)){

        if ($Remediation -eq $true){
            #Create Shortcut
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($DestinationPath)
            $Shortcut.IconLocation = "C:\Windows\System32\SHELL32.dll, 14"
            $Shortcut.TargetPath = $SourceExe
            $Shortcut.Arguments = "smscfgrc"
            $Shortcut.Save()

            write-output "Creating ConfigMgr Control Panel Icon on Desktop"
        }
        else { exit 1 }

    }
}
else{
    if (Test-Path -Path $DestinationPath){
        Remove-Item -Path $DestinationPath
    }
}

#Build ShortCut Information - Software Center
$SourceExe = "$env:windir\CCM\ClientUX\SCClient.exe"
$DestinationPath = "$env:Public\Desktop\Software Center.lnk"
if (Test-Path -Path $SourceExe){
    $ArgumentsToSourceExe = "softwarecenter:Page=AvailableSoftware"
    $DestinationPath = "$env:Public\Desktop\Software Center.lnk"

    if (!(Test-Path -Path $DestinationPath)){

        if ($Remediation -eq $true){

            #Create Shortcut
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($DestinationPath)
            $Shortcut.TargetPath = $SourceExe
            $Shortcut.Arguments = $ArgumentsToSourceExe
            $Shortcut.Save()

            write-output "Creating ConfigMgr Software Center Icon on Desktop"
        }
        else { Exit 1}
    }
}
else{
    if (Test-Path -Path $DestinationPath){
        Remove-Item -Path $DestinationPath
    }
}
