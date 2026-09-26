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
        $status = -1
        Write-DellRuleWarningOnce "Dell catalog WMI rule could not be evaluated in '$namespace': $($_.Exception.Message)"
    }

    $script:DellWmiRuleCache[$cacheKey] = $status
    return $status
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
