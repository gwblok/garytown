function Test-DellCommandUpdateSelection {
    param(
        [AllowNull()][psobject]$Settings,
        [Parameter(Mandatory)][string]$PropertyName
    )

    $property = if ($Settings) { $Settings.PSObject.Properties[$PropertyName] } else { $null }
    return -not $property -or [int]$property.Value -ne 0
}

function Get-DellCommandUpdatePolicy {
    $settingsRoot = 'HKLM:\SOFTWARE\Dell\UpdateService\Clients\CommandUpdate\Preferences\Settings'
    $generalSettings = Get-ItemProperty -LiteralPath (Join-Path $settingsRoot 'General') -ErrorAction SilentlyContinue
    $delayDays = 0

    if ($generalSettings -and [int]$generalSettings.ExcludeUpdatesFromLastNDays -eq 1) {
        $serviceLogPath = Join-Path $env:ProgramData 'Dell\UpdateService\Log\Service.log'
        if (Test-Path -LiteralPath $serviceLogPath -PathType Leaf) {
            $delayEntry = Get-Content -LiteralPath $serviceLogPath -ErrorAction Stop |
                Select-String -Pattern 'Delay Days\s*=\s*(?<days>\d+)' |
                Select-Object -Last 1
            if ($delayEntry -and [int]$delayEntry.Matches[0].Groups['days'].Value -in 1..45) {
                $delayDays = [int]$delayEntry.Matches[0].Groups['days'].Value
            }
        }
        if ($delayDays -eq 0) {
            throw 'Dell Command Update release-delay policy is enabled, but its effective delay could not be read. Run a DCU scan or specify -DelayDays explicitly.'
        }
    }

    $typeSettings = Get-ItemProperty -LiteralPath (Join-Path $settingsRoot 'UpdateFilter\UpdateType') -ErrorAction SilentlyContinue
    $types = @(
        if (Test-DellCommandUpdateSelection -Settings $typeSettings -PropertyName IsApplicationSelected) { 'Application' }
        if (Test-DellCommandUpdateSelection -Settings $typeSettings -PropertyName IsBIOSSelected) { 'BIOS' }
        if (Test-DellCommandUpdateSelection -Settings $typeSettings -PropertyName IsDriverSelected) { 'Driver' }
        if (Test-DellCommandUpdateSelection -Settings $typeSettings -PropertyName IsFirmwareSelected) { 'Firmware' }
    )

    $categorySettings = Get-ItemProperty -LiteralPath (Join-Path $settingsRoot 'UpdateFilter\DeviceCategory') -ErrorAction SilentlyContinue
    $categories = [System.Collections.Generic.List[string]]::new()
    foreach ($mapping in @(
        @{ Property = 'IsAudioSelected'; Values = @('Audio') },
        @{ Property = 'IsVideoSelected'; Values = @('Video') },
        @{ Property = 'IsNetworkSelected'; Values = @('Network') },
        @{ Property = 'IsStorageSelected'; Values = @('Storage') },
        @{ Property = 'IsInputSelected'; Values = @('Input') },
        @{ Property = 'IsChipsetSelected'; Values = @('Chipset') },
        @{ Property = 'IsDeviceCategoryOtherSelected'; Values = @('Application', 'BIOS', 'Communications', 'Docks/Stands', 'Security', 'Serial ATA', 'Systems Management') }
    )) {
        if (Test-DellCommandUpdateSelection -Settings $categorySettings -PropertyName $mapping.Property) {
            foreach ($value in $mapping.Values) { $categories.Add($value) }
        }
    }

    $severitySettings = Get-ItemProperty -LiteralPath (Join-Path $settingsRoot 'UpdateFilter\RecommendedLevel') -ErrorAction SilentlyContinue
    $severities = @(
        if ((Test-DellCommandUpdateSelection -Settings $severitySettings -PropertyName IsSecurityUpdatesSelected) -or
            (Test-DellCommandUpdateSelection -Settings $severitySettings -PropertyName IsCriticalUpdatesSelected)) { 'Urgent' }
        if (Test-DellCommandUpdateSelection -Settings $severitySettings -PropertyName IsRecommendedUpdatesSelected) { 'Recommended' }
        if (Test-DellCommandUpdateSelection -Settings $severitySettings -PropertyName IsOptionalUpdatesSelected) { 'Optional' }
    )

    return [pscustomobject]@{
        DelayDays = $delayDays
        Types = $types
        Categories = @($categories)
        Severities = $severities
    }
}