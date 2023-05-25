function Get-FirstFreeDriveLetter {
    $driveLetters = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' } | Select-Object -ExpandProperty Name
    $alphabet = [char[]]([char]'S'..[char]'Z')
    $freeLetters = $alphabet | Where-Object { $driveLetters -notcontains "$($_):\" }
    if ($freeLetters) {
        return $freeLetters[0]
    }
    else {
        return $null
    }
}
