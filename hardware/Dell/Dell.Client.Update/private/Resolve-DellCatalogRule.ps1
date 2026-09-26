function Get-DellXmlElementChildren {
    param([Parameter(Mandatory)][System.Xml.XmlNode]$Node)
    @($Node.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
}

function Write-DellRuleWarningOnce {
    param([Parameter(Mandatory)][string]$Message)
    if ($script:DellRuleWarnings.Add($Message)) {
        Write-Warning $Message
    }
}

function Compare-DellVersion {
    param(
        [Parameter(Mandatory)][string]$InstalledVersion,
        [Parameter(Mandatory)][string]$CatalogVersion
    )

    try {
        $installed = [version]$InstalledVersion
        $catalog = [version]$CatalogVersion
        if ($installed -gt $catalog) { return 1 }
        if ($installed -lt $catalog) { return -1 }
        return 0
    }
    catch {
        return -2
    }
}

function Test-DellCatalogWmiQuery {
    param([Parameter(Mandatory)][System.Xml.XmlElement]$Rule)

    $namespace = $Rule.GetAttribute('Namespace')
    $query = $Rule.GetAttribute('WqlQuery')
    if ([string]::IsNullOrWhiteSpace($namespace) -or [string]::IsNullOrWhiteSpace($query)) {
        return -1
    }

    $cacheKey = "$namespace`n$query"
    if ($script:DellWmiRuleCache.ContainsKey($cacheKey)) {
        return $script:DellWmiRuleCache[$cacheKey]
    }

    try {
        $instances = @(Get-CimInstance -Namespace $namespace -Query $query -ErrorAction Stop)
        $status = if ($instances.Count) { 1 } else { 0 }
    }
    catch {
        if ($namespace -ieq 'Root\Dell\sysinv') {
            $status = Test-DellNativeInventoryWql -Query $query
            if ($status -lt 0) {
                Write-DellRuleWarningOnce "Dell inventory WMI is unavailable and this catalog rule could not be safely derived from Windows inventory: $query"
            }
        }
        else {
            $status = -1
            Write-DellRuleWarningOnce "Dell catalog WMI rule could not be evaluated in '$namespace': $($_.Exception.Message)"
        }
    }

    $script:DellWmiRuleCache[$cacheKey] = $status
    return $status
}

function ConvertTo-DellIdentityVersion {
    param([string]$Version)

    if ([string]::IsNullOrWhiteSpace($Version)) { return $null }
    if ($Version -match '^A(?<number>\d+)[A-Z]?$') {
        return ('0001.{0}.0000' -f $Matches.number.PadLeft(4, '0'))
    }
    $parts = @($Version -split '\.')
    if ($parts.Count -lt 2 -or $parts.Count -gt 4 -or @($parts | Where-Object { $_ -notmatch '^\d+$' }).Count) { return $null }
    return (($parts | ForEach-Object { $_.PadLeft(4, '0') }) -join '.')
}

function ConvertTo-DellDriverIdentityDescription {
    param([string]$HardwareId)

    if ($HardwareId -match '(?i)^PCI\\VEN_(?<Vendor>[0-9A-F]{4})&DEV_(?<Device>[0-9A-F]{4})(?:&SUBSYS_(?<SubDevice>[0-9A-F]{4})(?<SubVendor>[0-9A-F]{4}))?') {
        $description = "Dell:DRVR_$($Matches.Device)_$($Matches.Vendor)"
        if ($Matches.SubDevice) { $description += "_$($Matches.SubDevice)_$($Matches.SubVendor)" }
        return "$description`_"
    }
    return $null
}

function Get-DellNativeInventoryRows {
    param([Parameter(Mandatory)][string]$ClassName)

    if ($null -eq $script:DellNativeInventory) {
        $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $script:DellSystemTypeId = $null
        $sku = ([string]$computer.SystemSKUNumber).Trim()
        if ($sku -match '^(?:0x)?(?<hex>[0-9A-Fa-f]{4})$') {
            $script:DellSystemTypeId = [Convert]::ToInt32($Matches.hex, 16).ToString()
        }
        elseif ($sku -match '^\d{1,5}$') {
            $script:DellSystemTypeId = [string][int]$sku
        }

        $softwareRows = [System.Collections.Generic.List[object]]::new()
        $osBuild = [string](Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).BuildNumber
        foreach ($driver in (Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop)) {
            $driverVersion = ConvertTo-DellIdentityVersion -Version ([string]$driver.DriverVersion)
            $deviceId = [string]$driver.DeviceID
            if (-not $driverVersion -or -not $deviceId) { continue }

            $hardwareIds = [System.Collections.Generic.List[string]]::new()
            $hardwareIds.Add($deviceId)
            try {
                $deviceProperties = Get-PnpDeviceProperty -InstanceId $deviceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop
                foreach ($hardwareId in @($deviceProperties.Data)) {
                    if ($hardwareId) { $hardwareIds.Add([string]$hardwareId) }
                }
            }
            catch { }

            foreach ($hardwareId in ($hardwareIds | Select-Object -Unique)) {
                $description = ConvertTo-DellDriverIdentityDescription -HardwareId $hardwareId
                $softwareRows.Add([pscustomobject]@{
                    HardwareID = $hardwareId
                    Description = $description
                    VersionString = $driverVersion
                    PackageVersion = $driverVersion
                    OSBuildNumber = $osBuild
                })
            }
        }

        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
        $biosVersion = ConvertTo-DellIdentityVersion -Version ([string]$bios.SMBIOSBIOSVersion)
        if ($biosVersion) {
            $softwareRows.Add([pscustomobject]@{
                HardwareID = ''
                Description = '__DELL_BIOS__'
                VersionString = $biosVersion
                PackageVersion = $biosVersion
                OSBuildNumber = $osBuild
            })
        }

        $script:DellNativeInventory = @{
            Dell_OEMComputerSystem = if ($script:DellSystemTypeId) { @([pscustomobject]@{ SystemTypeID = $script:DellSystemTypeId }) } else { @() }
            Dell_SoftwareIdentity = @($softwareRows)
        }
    }

    if (-not $script:DellNativeInventory.ContainsKey($ClassName)) { return @() }
    return @($script:DellNativeInventory[$ClassName])
}

function Set-DellNativeRuleContext {
    param([System.Xml.XmlNode]$Node)

    $script:DellNativeBiosDescriptions = @()
    if (-not $Node) { return }
    if ($null -eq $script:DellNativeInventory) {
        $null = Get-DellNativeInventoryRows -ClassName 'Dell_OEMComputerSystem'
    }
    if (-not $script:DellSystemTypeId) { return }

    $systemTypeMatches = $false
    foreach ($queryNode in $Node.SelectNodes(".//*[local-name()='WmiQuery']")) {
        $query = $queryNode.GetAttribute('WqlQuery')
        if ($query -match '(?is)FROM\s+Dell_OEMComputerSystem\s+WHERE\s+(.+)$') {
            $values = [regex]::Matches($Matches[1], "SystemTypeID\s*=\s*'(?<id>\d+)'") | ForEach-Object { $_.Groups['id'].Value }
            if ($script:DellSystemTypeId -in $values) { $systemTypeMatches = $true }
        }
    }

    if ($systemTypeMatches) {
        foreach ($queryNode in $Node.SelectNodes(".//*[local-name()='WmiQuery']")) {
            $query = $queryNode.GetAttribute('WqlQuery')
            if ($query -match "(?i)Description\s+LIKE\s+'(?<description>Dell:BIOS_[^']+)'" ) {
                $script:DellNativeBiosDescriptions += ($Matches.description -replace '%', '*')
            }
        }
    }
}

function ConvertFrom-DellWqlWhere {
    param([Parameter(Mandatory)][string]$WhereClause)

    $pattern = "\s*(?:(?<Left>\()|(?<Right>\))|(?<Operator>LIKE|>=|<=|<>|!=|=|>|<)|(?<Boolean>AND|OR)\b|(?<String>'(?:[^']|'')*')|(?<Word>[A-Za-z_][A-Za-z0-9_]*)|(?<Number>\d+)|(?<Invalid>.))"
    $tokens = [System.Collections.Generic.List[object]]::new()
    $offset = 0
    while ($offset -lt $WhereClause.Length) {
        $match = [regex]::Match($WhereClause.Substring($offset), $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $match.Success -or $match.Length -eq 0) { return $null }
        $offset += $match.Length
        foreach ($groupName in @('Left','Right','Operator','Boolean','String','Word','Number','Invalid')) {
            if (-not $match.Groups[$groupName].Success) { continue }
            $value = $match.Groups[$groupName].Value
            if ($groupName -eq 'Invalid') { return $null }
            if ($groupName -eq 'String') { $value = $value.Trim("'").Replace("''", "'") }
            $tokens.Add([pscustomobject]@{ Type = $groupName; Value = $value })
            break
        }
    }

    $output = [System.Collections.Generic.List[object]]::new()
    $operators = [System.Collections.Generic.Stack[object]]::new()
    $precedence = @{ AND = 2; OR = 1 }
    $index = 0
    while ($index -lt $tokens.Count) {
        $token = $tokens[$index]
        if ($token.Type -eq 'Left') { $operators.Push($token); $index++; continue }
        if ($token.Type -eq 'Right') {
            while ($operators.Count -and $operators.Peek().Type -ne 'Left') { $output.Add($operators.Pop()) }
            if (-not $operators.Count) { return $null }
            $null = $operators.Pop()
            $index++
            continue
        }
        if ($token.Type -eq 'Boolean') {
            while ($operators.Count -and $operators.Peek().Type -eq 'Boolean' -and $precedence[$operators.Peek().Value.ToUpperInvariant()] -ge $precedence[$token.Value.ToUpperInvariant()]) { $output.Add($operators.Pop()) }
            $operators.Push([pscustomobject]@{ Type = 'Boolean'; Value = $token.Value.ToUpperInvariant() })
            $index++
            continue
        }
        if ($token.Type -ne 'Word' -or $index + 2 -ge $tokens.Count -or $tokens[$index + 1].Type -ne 'Operator' -or $tokens[$index + 2].Type -notin @('String','Word','Number')) { return $null }
        $output.Add([pscustomobject]@{ Type = 'Predicate'; Property = $token.Value; Operator = $tokens[$index + 1].Value.ToUpperInvariant(); Expected = [string]$tokens[$index + 2].Value })
        $index += 3
    }
    while ($operators.Count) {
        if ($operators.Peek().Type -eq 'Left') { return $null }
        $output.Add($operators.Pop())
    }
    return ,@($output)
}

function Test-DellWqlPredicate {
    param($Predicate, $Instance)
    $property = $Instance.PSObject.Properties[$Predicate.Property]
    if (-not $property) { return $false }
    $actual = [string]$property.Value
    $expected = [string]$Predicate.Expected
    switch ($Predicate.Operator) {
        'LIKE' {
            $pattern = $expected -replace '%', '*'
            if ($Predicate.Property -eq 'Description' -and $pattern -like 'Dell:BIOS_*' -and $Instance.Description -eq '__DELL_BIOS__') {
                return [bool]($script:DellNativeBiosDescriptions -contains $pattern)
            }
            return $actual -like $pattern
        }
        '=' { return $actual -ieq $expected }
        '!=' { return $actual -ine $expected }
        '<>' { return $actual -ine $expected }
        { $_ -in @('>=','>','<=','<') } {
            $comparison = [string]::Compare($actual, $expected, [StringComparison]::OrdinalIgnoreCase)
            switch ($Predicate.Operator) {
                '>=' { return $comparison -ge 0 }
                '>' { return $comparison -gt 0 }
                '<=' { return $comparison -le 0 }
                '<' { return $comparison -lt 0 }
            }
        }
    }
    return $false
}

function Test-DellWqlExpressionForInstance {
    param([object[]]$Rpn, $Instance)
    $values = [System.Collections.Generic.Stack[bool]]::new()
    foreach ($token in $Rpn) {
        if ($token.Type -eq 'Predicate') { $values.Push([bool](Test-DellWqlPredicate -Predicate $token -Instance $Instance)) }
        elseif ($token.Value -in @('AND','OR')) {
            if ($values.Count -lt 2) { return $null }
            $right = $values.Pop(); $left = $values.Pop()
            if ($token.Value -eq 'AND') { $values.Push($left -and $right) } else { $values.Push($left -or $right) }
        }
        else { return $null }
    }
    if ($values.Count -ne 1) { return $null }
    return $values.Pop()
}

function Test-DellNativeInventoryWql {
    param([Parameter(Mandatory)][string]$Query)
    if ($Query -notmatch '(?is)^\s*SELECT\s+\*\s+FROM\s+(?<Class>[A-Za-z_][A-Za-z0-9_]*)\s+WHERE\s+(?<Where>.+?)\s*$') { return -1 }
    $rpn = ConvertFrom-DellWqlWhere -WhereClause $Matches.Where
    if (-not $rpn) { return -1 }
    $instances = @(Get-DellNativeInventoryRows -ClassName $Matches.Class)
    if (-not $instances.Count) {
        if ($Matches.Class -in @('Dell_OEMComputerSystem', 'Dell_SoftwareIdentity')) { return -1 }
        return 0
    }
    foreach ($instance in $instances) {
        $result = Test-DellWqlExpressionForInstance -Rpn $rpn -Instance $instance
        if ($null -eq $result) { return -1 }
        if ($result) { return 1 }
    }
    return 0
}

function Test-DellCatalogWindowsVersion {
    param([Parameter(Mandatory)][System.Xml.XmlElement]$Rule)

    try {
        $current = [System.Environment]::OSVersion.Version
        $currentTuple = [version]::new($current.Major, $current.Minor, 0, 0)
        $requiredTuple = [version]::new(
            [int]$Rule.GetAttribute('MajorVersion'),
            [int]$Rule.GetAttribute('MinorVersion'),
            [int]$Rule.GetAttribute('ServicePackMajor'),
            [int]$Rule.GetAttribute('ServicePackMinor')
        )
        switch ($Rule.GetAttribute('Comparison')) {
            'GreaterThanOrEqualTo' { return [int]($currentTuple -ge $requiredTuple) }
            'EqualTo' { return [int]($currentTuple -eq $requiredTuple) }
            default {
                Write-DellRuleWarningOnce "Unsupported WindowsVersion comparison '$($Rule.GetAttribute('Comparison'))'."
                return -1
            }
        }
    }
    catch {
        Write-DellRuleWarningOnce "Dell WindowsVersion rule could not be evaluated: $($_.Exception.Message)"
        return -1
    }
}

function Test-DellCatalogProcessor {
    param([Parameter(Mandatory)][System.Xml.XmlElement]$Rule)

    try {
        if ($null -eq $script:DellProcessorArchitectures) {
            $script:DellProcessorArchitectures = @(
                Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
                    ForEach-Object { [int]$_.Architecture } |
                    Select-Object -Unique
            )
        }
        return [int]([int]$Rule.GetAttribute('Architecture') -in $script:DellProcessorArchitectures)
    }
    catch {
        Write-DellRuleWarningOnce "Dell Processor rule could not be evaluated: $($_.Exception.Message)"
        return -1
    }
}

function Get-DellMsiInstalledVersion {
    param([Parameter(Mandatory)][string]$ProductCode)

    $productGuid = $ProductCode.Trim('{}')
    foreach ($root in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )) {
        $keyPath = Join-Path $root "{$productGuid}"
        if (Test-Path -LiteralPath $keyPath) {
            $item = Get-ItemProperty -LiteralPath $keyPath -ErrorAction SilentlyContinue
            if ($item.DisplayVersion) { return [string]$item.DisplayVersion }
        }
    }

    return $null
}

function Test-DellCatalogMsiProductInstalled {
    param([Parameter(Mandatory)][System.Xml.XmlElement]$Rule)

    $productCode = $Rule.GetAttribute('ProductCode')
    if (-not $productCode) { return -1 }
    $installedVersion = Get-DellMsiInstalledVersion -ProductCode $productCode
    if (-not $installedVersion) { return 0 }

    $minimumVersion = $Rule.GetAttribute('VersionMin')
    if (-not $minimumVersion) { return 1 }
    $comparison = Compare-DellVersion -InstalledVersion $installedVersion -CatalogVersion $minimumVersion
    if ($comparison -eq -2) {
        Write-DellRuleWarningOnce "MSI version '$installedVersion' could not be compared with catalog minimum '$minimumVersion' for product $productCode."
        return -1
    }
    return [int]($comparison -ge 0)
}

function Test-DellCatalogRule {
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Xml.XmlElement]$Rule)

    $children = @(Get-DellXmlElementChildren -Node $Rule)
    switch ($Rule.LocalName) {
        'And' {
            $unknown = $false
            foreach ($child in $children) {
                $status = Test-DellCatalogRule -Rule $child
                if ($status -eq 0) { return 0 }
                if ($status -lt 0) { $unknown = $true }
            }
            if ($unknown) { return -1 }
            return 1
        }
        'Or' {
            $unknown = $false
            foreach ($child in $children) {
                $status = Test-DellCatalogRule -Rule $child
                if ($status -eq 1) { return 1 }
                if ($status -lt 0) { $unknown = $true }
            }
            if ($unknown) { return -1 }
            return 0
        }
        'WmiQuery' { return (Test-DellCatalogWmiQuery -Rule $Rule) }
        'WindowsVersion' { return (Test-DellCatalogWindowsVersion -Rule $Rule) }
        'Processor' { return (Test-DellCatalogProcessor -Rule $Rule) }
        'MsiProductInstalled' { return (Test-DellCatalogMsiProductInstalled -Rule $Rule) }
        default {
            Write-DellRuleWarningOnce "Unsupported Dell catalog rule '$($Rule.LocalName)'; this result will be treated as indeterminate."
            return -1
        }
    }
}
