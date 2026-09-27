Set-StrictMode -Version 2.0
$script:DellWmiRuleCache = @{}
$script:DellRuleWarnings = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$script:DellProcessorArchitectures = $null
$script:DellNativeInventory = $null
$script:DellNativeDescriptionIndex = $null
$script:DellSystemTypeId = $null
$script:DellNativeBiosDescriptions = @()
$script:DellSysInvUnavailable = $false

foreach ($sourceDirectory in @('private', 'public')) {
    $directoryPath = Join-Path $PSScriptRoot $sourceDirectory
    Get-ChildItem -LiteralPath $directoryPath -Filter '*.ps1' -File -ErrorAction Stop |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }
}

Export-ModuleMember -Function Get-DellUpdate, Get-DellUpdateHist, Install-DellUpdate
