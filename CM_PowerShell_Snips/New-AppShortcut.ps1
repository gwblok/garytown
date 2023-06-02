Function New-AppShortcut {
    <# Gary Blok | @gwblok | GARYTOWN.COM | 2023.06.02
    Creates a shortcut for the exe you provide

    
    ex: New-AppShortcut -SourceExePath "C:\Windows\ccm\ClientUX\SCClient.exe" -ShortCutName "Software Center" -Desktop
    That will create a shortcut for C:\Windows\ccm\ClientUX\SCClient.exe named Software Center and place it on the Desktop


    ex: New-AppShortcut -SourceExePath "C:\Windows\system32\wmiexplorer.exe" -ShortCutName "WMIExplorer"
    That will create a shortcut for C:\Windows\system32\wmiexplorer.exe named WMIExplorer and place it in the Start Menu

    #>
    [CmdletBinding()]
    param(
        [Parameter(Position=0,mandatory=$true)]
        [string]$SourceExePath,
        [Parameter(Position=1,mandatory=$true)]
        [string]$ShortCutName = "AppName",
        [string]$ArgumentsToSourceExe,
        [switch]$Desktop
        )

    #Build ShortCut Information
    if ($Desktop){
        $ShortCutFolderPath = "$env:Public\Desktop" 
    }
    else {
        $ShortCutFolderPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
    }
    $DestinationPath = "$ShortCutFolderPath\$($ShortCutName).lnk"
    Write-Output "Shortcut Creation Path: $DestinationPath"

    if ($ArgumentsToSourceExe){
        Write-Output "Shortcut = $SourceExePath -$($ArgumentsToSourceExe)"
    }
    Else {
        Write-Output "Shortcut = $SourceExePath"
    }
    

    #Create Shortcut
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($DestinationPath)
    $Shortcut.IconLocation = "$SourceExePath, 0"
    $Shortcut.TargetPath = $SourceExePath
    if ($ArgumentsToSourceExe){$Shortcut.Arguments = $ArgumentsToSourceExe}
    $Shortcut.Save()

    Write-Output "Shortcut Created"
}
