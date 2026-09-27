function Get-DellPSUpdatePath {
    param(
        [ValidateSet('Root', 'Catalogs', 'Downloads', 'History', 'Logs')]
        [string]$Name = 'Root',
        [switch]$Create
    )

    $rootPath = Join-Path $env:ProgramData 'DellPSUpdate'
    $path = if ($Name -eq 'Downloads') {
        Join-Path $env:SystemRoot 'Temp\Dell'
    }
    elseif ($Name -eq 'Root') {
        $rootPath
    }
    else {
        Join-Path $rootPath $Name
    }
    if ($Create) { $null = New-Item -Path $path -ItemType Directory -Force }
    return $path
}