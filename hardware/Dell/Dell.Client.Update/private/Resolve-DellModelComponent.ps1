function Get-DellModelInventory {
    $inventory = [System.Collections.Generic.List[object]]::new()
    foreach ($driver in (Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop)) {
        $version = $null
        if (-not [version]::TryParse(([string]$driver.DriverVersion).Trim(), [ref]$version)) { continue }

        $hardwareIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        if ($driver.DeviceID) { $null = $hardwareIds.Add([string]$driver.DeviceID) }
        if ($driver.HardWareID) { $null = $hardwareIds.Add([string]$driver.HardWareID) }

        $inventory.Add([pscustomobject]@{
            DeviceName = [string]$driver.DeviceName
            DeviceId = [string]$driver.DeviceID
            HardwareIds = @($hardwareIds)
            DriverVersion = $version
            IdentityType = 'PnP'
            ExtensionId = ''
        })
    }

    foreach ($infFile in (Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'INF') -Filter 'oem*.inf' -File -ErrorAction Stop)) {
        $content = [IO.File]::ReadAllText($infFile.FullName)
        $extensionMatch = [regex]::Match($content, '(?im)^\s*ExtensionId\s*=\s*(?<id>\{[0-9A-F-]+\})\s*$')
        $versionMatch = [regex]::Match($content, '(?im)^\s*DriverVer\s*=\s*[^,]+,(?<version>[0-9.]+)\s*$')
        if (-not $extensionMatch.Success -or -not $versionMatch.Success) { continue }
        $version = $null
        if (-not [version]::TryParse($versionMatch.Groups['version'].Value, [ref]$version)) { continue }
        $hardwareIds = @([regex]::Matches($content, '(?im)^\s*[^;=\r\n]+\s*=\s*[^,\r\n]+,\s*(?<id>[A-Za-z0-9_*{}&\\.\-]+)\s*$') | ForEach-Object { $_.Groups['id'].Value } | Sort-Object -Unique)
        $inventory.Add([pscustomobject]@{
            DeviceName = "Driver extension $($extensionMatch.Groups['id'].Value)"
            DeviceId = $infFile.Name
            HardwareIds = $hardwareIds
            DriverVersion = $version
            IdentityType = 'Extension'
            ExtensionId = $extensionMatch.Groups['id'].Value
        })
    }
    $hardwareIndex = @{}
    $hardwareIdIndex = @{}
    foreach ($item in $inventory) {
        foreach ($hardwareId in $item.HardwareIds) {
            $normalizedHardwareId = $hardwareId.ToUpperInvariant()
            if (-not $hardwareIdIndex.ContainsKey($normalizedHardwareId)) {
                $hardwareIdIndex[$normalizedHardwareId] = [System.Collections.Generic.List[object]]::new()
            }
            if (-not $hardwareIdIndex[$normalizedHardwareId].Contains($item)) { $hardwareIdIndex[$normalizedHardwareId].Add($item) }
            if ($hardwareId -notmatch '(?i)(?:VEN_|VID_)(?<vendor>[0-9A-F]{4}).*(?:DEV_|PID_)(?<device>[0-9A-F]{4})') { continue }
            $key = "$($Matches.vendor):$($Matches.device)".ToUpperInvariant()
            if (-not $hardwareIndex.ContainsKey($key)) {
                $hardwareIndex[$key] = [System.Collections.Generic.List[object]]::new()
            }
            if (-not $hardwareIndex[$key].Contains($item)) { $hardwareIndex[$key].Add($item) }
        }
    }
    return [pscustomobject]@{
        Items = @($inventory)
        HardwareIndex = $hardwareIndex
        HardwareIdIndex = $hardwareIdIndex
        SelectorCache = @{}
    }
}

function Test-DellModelOperatingSystem {
    param(
        [Parameter(Mandatory)][System.Xml.XmlElement]$Component,
        [Parameter(Mandatory)][object]$OperatingSystem
    )

    $supportedSystems = @($Component.SelectNodes("./*[local-name()='SupportedOperatingSystems']/*[local-name()='OperatingSystem']"))
    if (-not $supportedSystems.Count) { return $true }

    $currentFamily = if ([int]$OperatingSystem.BuildNumber -ge 22000) { 'Windows 11' } else { 'Windows 10' }
    $currentArchitecture = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    foreach ($supportedSystem in $supportedSystems) {
        $display = $supportedSystem.SelectSingleNode("./*[local-name()='Display']")
        if ($supportedSystem.GetAttribute('osArch') -ieq $currentArchitecture -and $display.InnerText -like "$currentFamily*") {
            return $true
        }
    }
    return $false
}

function Test-DellModelHardwareSelector {
    param(
        [Parameter(Mandatory)][System.Xml.XmlElement]$Selector,
        [Parameter(Mandatory)][string[]]$HardwareIds
    )

    if ($Selector.LocalName -eq 'PCIInfo') {
        $vendorId = [regex]::Escape($Selector.GetAttribute('vendorID'))
        $deviceId = [regex]::Escape($Selector.GetAttribute('deviceID'))
        $subVendorId = $Selector.GetAttribute('subVendorID')
        $subDeviceId = $Selector.GetAttribute('subDeviceID')
        foreach ($hardwareId in $HardwareIds) {
            if ($hardwareId -notmatch "(?i)(?:VEN_|VID_)$vendorId.*(?:DEV_|PID_)$deviceId") { continue }
            if (-not $subVendorId -or -not $subDeviceId) { return $true }
            if ($hardwareId -match "(?i)SUBSYS_(?:$([regex]::Escape($subDeviceId))$([regex]::Escape($subVendorId))|$([regex]::Escape($subVendorId))$([regex]::Escape($subDeviceId)))") {
                return $true
            }
        }
        return $false
    }

    if ($Selector.LocalName -eq 'PnPInfo') {
        $vendorNode = $Selector.SelectSingleNode("./*[local-name()='PNPID']")
        $productNode = $Selector.SelectSingleNode("./*[local-name()='PnPProductID']")
        if (-not $vendorNode -or -not $productNode) { return $false }
        $vendorId = [regex]::Escape($vendorNode.InnerText)
        $productId = [regex]::Escape($productNode.InnerText)
        return [bool]($HardwareIds -match "(?i)(?:VEN_|VID_)$vendorId.*(?:DEV_|PID_)$productId")
    }

    if ($Selector.LocalName -eq 'Generic') {
        $expected = $Selector.InnerText.Trim()
        return [bool]($HardwareIds | Where-Object { $_.StartsWith($expected, [StringComparison]::OrdinalIgnoreCase) })
    }

    return $false
}

function Get-DellModelSelectorMatches {
    param(
        [Parameter(Mandatory)][System.Xml.XmlElement]$Selector,
        [Parameter(Mandatory)][object]$Inventory
    )

    $cacheKey = $Selector.OuterXml
    if ($Inventory.SelectorCache.ContainsKey($cacheKey)) { return @($Inventory.SelectorCache[$cacheKey]) }

    $candidates = @()
    if ($Selector.LocalName -eq 'PCIInfo') {
        $key = "$($Selector.GetAttribute('vendorID')):$($Selector.GetAttribute('deviceID'))".ToUpperInvariant()
        if ($Inventory.HardwareIndex.ContainsKey($key)) { $candidates = @($Inventory.HardwareIndex[$key]) }
    }
    elseif ($Selector.LocalName -eq 'PnPInfo') {
        $vendorNode = $Selector.SelectSingleNode("./*[local-name()='PNPID']")
        $productNode = $Selector.SelectSingleNode("./*[local-name()='PnPProductID']")
        if ($vendorNode -and $productNode) {
            $key = "$($vendorNode.InnerText):$($productNode.InnerText)".ToUpperInvariant()
            if ($Inventory.HardwareIndex.ContainsKey($key)) { $candidates = @($Inventory.HardwareIndex[$key]) }
        }
    }
    elseif ($Selector.LocalName -eq 'Generic') {
        $expected = $Selector.InnerText.Trim().ToUpperInvariant()
        if ($Inventory.HardwareIdIndex.ContainsKey($expected)) {
            $candidates = @($Inventory.HardwareIdIndex[$expected])
        }
        else {
            $candidates = @($Inventory.Items | Where-Object { $_.HardwareIds | Where-Object { $_.StartsWith($expected, [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1 })
        }
    }

    $results = @($candidates | Where-Object { Test-DellModelHardwareSelector -Selector $Selector -HardwareIds $_.HardwareIds })
    $Inventory.SelectorCache[$cacheKey] = $results
    return $results
}

function Get-DellModelComponentMatches {
    param(
        [Parameter(Mandatory)][System.Xml.XmlElement]$Component,
        [Parameter(Mandatory)][object]$Inventory
    )

    $matches = [System.Collections.Generic.List[object]]::new()
    $devices = @($Component.SelectNodes("./*[local-name()='SupportedDCHDevices' or local-name()='SupportedDevices']/*[local-name()='Device']"))
    foreach ($device in $devices) {
        $expectedVersionText = $device.GetAttribute('version')
        if (-not $expectedVersionText) { $expectedVersionText = $Component.GetAttribute('vendorVersion') }
        $expectedVersion = $null
        if (-not [version]::TryParse($expectedVersionText, [ref]$expectedVersion)) { continue }

        $selectors = @($device.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element -and $_.LocalName -in @('PCIInfo', 'PnPInfo', 'Generic') })
        $matchingInventory = [System.Collections.Generic.List[object]]::new()
        foreach ($selector in $selectors) {
            foreach ($item in (Get-DellModelSelectorMatches -Selector $selector -Inventory $Inventory)) {
                if (-not $matchingInventory.Contains($item)) { $matchingInventory.Add($item) }
            }
        }

        foreach ($installedDevice in $matchingInventory) {
            $matches.Add([pscustomobject]@{
                ComponentId = $device.GetAttribute('componentID')
                DeviceName = $installedDevice.DeviceName
                DeviceId = $installedDevice.DeviceId
                InstalledVersion = $installedDevice.DriverVersion
                ExpectedVersion = $expectedVersion
                IdentityType = $installedDevice.IdentityType
            })
        }
    }

    return @($matches | Sort-Object DeviceId, ExpectedVersion -Unique)
}

function Get-DellModelComponentState {
    param(
        [Parameter(Mandatory)][System.Xml.XmlElement]$Component,
        [Parameter(Mandatory)][object]$Inventory
    )

    $componentType = $Component.SelectSingleNode("./*[local-name()='ComponentType']").GetAttribute('value')
    if ($componentType -eq 'BIOS') {
        $installedVersion = ConvertTo-DellIdentityVersion -Version ([string](Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop).SMBIOSBIOSVersion)
        $expectedVersion = ConvertTo-DellIdentityVersion -Version $Component.GetAttribute('dellVersion')
        if (-not $installedVersion -or -not $expectedVersion) { return $null }
        return [pscustomobject]@{
            IsApplicable = $true
            IsInstalled = ([string]::Compare($installedVersion, $expectedVersion, [StringComparison]::OrdinalIgnoreCase) -ge 0)
            Matches = @()
        }
    }

    $matches = @(Get-DellModelComponentMatches -Component $Component -Inventory $Inventory)
    if (-not $matches.Count) { return $null }
    $packageVersion = $null
    $null = [version]::TryParse($Component.GetAttribute('vendorVersion'), [ref]$packageVersion)
    $hasCurrentExtensionMarker = [bool]($matches | Where-Object { $_.IdentityType -eq 'Extension' -and $packageVersion -and $_.InstalledVersion -eq $packageVersion } | Select-Object -First 1)
    $hasNewerPrimaryMarker = [bool]($matches | Where-Object { $_.IdentityType -eq 'PnP' -and $packageVersion -and $_.ExpectedVersion -eq $packageVersion -and $_.InstalledVersion -gt $_.ExpectedVersion } | Select-Object -First 1)
    $outdatedMatches = @($matches | Where-Object { $_.InstalledVersion -lt $_.ExpectedVersion })
    return [pscustomobject]@{
        IsApplicable = $true
        IsInstalled = ($hasCurrentExtensionMarker -or $hasNewerPrimaryMarker -or $outdatedMatches.Count -eq 0)
        Matches = $matches
    }
}