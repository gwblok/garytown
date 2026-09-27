Set-StrictMode -Version 2.0

foreach ($sourceDirectory in @('private', 'public')) {
    $directoryPath = Join-Path $PSScriptRoot $sourceDirectory
    Get-ChildItem -LiteralPath $directoryPath -Filter '*.ps1' -File -ErrorAction Stop |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

Export-ModuleMember -Function Get-DellUpdate, Get-DellUpdateHist, Install-DellUpdate
