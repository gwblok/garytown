function Get-DellUpdate {
    <#
    .SYNOPSIS
        Gets Dell model-catalog updates applicable to this computer.

    .DESCRIPTION
        Downloads Dell's model-specific catalog, matches its supported-device
        metadata against native Windows PnP and INF inventory, and returns the
        newest applicable package for each component family. Dell OpenManage
        Inventory Agent packages are excluded.

    .PARAMETER All
        Return the newest applicable package for each detected component,
        including packages whose installed components are current.

    .PARAMETER NoTestInstalled
        Do not report installed state. Requires -All; IsInstalled is $null.

    .PARAMETER UseCachedCatalog
        Reuse the model-specific XML if it exists in WorkingDirectory.

    .PARAMETER WorkingDirectory
        Directory for catalog downloads and extracted XML. Defaults to
        C:\Windows\Temp\Dell.

    .PARAMETER CatalogUrl
        Dell model catalog index CAB URL.

    .PARAMETER ExplainRules
        Include matching device and version details in verbose output.
    #>
    [CmdletBinding()]
    param(
        [switch]$All,
        [switch]$NoTestInstalled,
        [switch]$UseCachedCatalog,
        [switch]$ExplainRules,
        [uri]$CatalogUrl = 'https://downloads.dell.com/catalog/CatalogIndexPC.cab',
        [string]$WorkingDirectory = 'C:\Windows\Temp\Dell'
    )

    if ($NoTestInstalled -and -not $All) {
        throw '-NoTestInstalled can only be used with -All.'
    }

    $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    if ($computer.Manufacturer -notmatch '^Dell') {
        throw "Get-DellUpdate supports Dell systems only. Detected '$($computer.Manufacturer)'."
    }

    $systemId = Get-DellSystemId -ComputerSystem $computer
    $catalogPath = Get-DellModelCatalogXml -SystemId $systemId -WorkingDirectory $WorkingDirectory -UseCachedCatalog:$UseCachedCatalog -CatalogIndexUrl $CatalogUrl
    $catalog = [System.Xml.XmlDocument]::new()
    $catalog.XmlResolver = $null
    $catalog.Load($catalogPath)

    $baseLocation = $catalog.DocumentElement.GetAttribute('baseLocation')
    if ([string]::IsNullOrWhiteSpace($baseLocation)) { $baseLocation = 'downloads.dell.com' }
    $operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $inventory = Get-DellModelInventory
    $candidateUpdates = [System.Collections.Generic.List[object]]::new()
    $componentCount = 0

    Write-Host "Evaluating Dell model catalog for system ID $systemId ..."
    foreach ($componentNode in $catalog.SelectNodes("//*[local-name()='SoftwareComponent']")) {
        $componentCount++
        $component = [System.Xml.XmlElement]$componentNode
        $nameNode = $component.SelectSingleNode("./*[local-name()='Name']/*[local-name()='Display']")
        $name = if ($nameNode) { $nameNode.InnerText.Trim() } else { $component.GetAttribute('releaseID') }
        if ($name -like 'Dell OpenManage Inventory Agent*') { continue }
        if (-not (Test-DellModelOperatingSystem -Component $component -OperatingSystem $operatingSystem)) { continue }

        $state = Get-DellModelComponentState -Component $component -Inventory $inventory
        if (-not $state) { continue }

        $vendorVersion = $component.GetAttribute('vendorVersion')
        $dellVersion = $component.GetAttribute('dellVersion')
        $releaseId = $component.GetAttribute('releaseID')
        $packageId = $component.GetAttribute('packageID')
        if (-not $packageId) { $packageId = $releaseId }
        $relativePath = $component.GetAttribute('path')
        $componentIds = @($component.SelectNodes("./*[local-name()='SupportedDCHDevices' or local-name()='SupportedDevices']/*[local-name()='Device']/@componentID") | ForEach-Object Value | Where-Object { $_ } | Sort-Object -Unique)
        $familyId = if ($componentIds.Count) { $componentIds -join ',' } else { $name }
        $releaseDate = [datetime]::MinValue
        $null = [datetime]::TryParse($component.GetAttribute('releaseDate'), [ref]$releaseDate)
        $severityNode = $component.SelectSingleNode("./*[local-name()='Criticality']/*[local-name()='Display']")
        $typeNode = $component.SelectSingleNode("./*[local-name()='ComponentType']/*[local-name()='Display']")
        $categoryNode = $component.SelectSingleNode("./*[local-name()='Category']/*[local-name()='Display']")
        $sha256Node = $component.SelectSingleNode("./*[local-name()='Cryptography']/*[local-name()='Hash' and translate(@algorithm, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')='SHA256']")

        $update = [pscustomobject]@{
            ID = $releaseId
            PackageID = $packageId
            ReleaseID = $releaseId
            Name = $name
            Title = "$name,$vendorVersion,$dellVersion"
            Version = $vendorVersion
            DellVersion = $dellVersion
            Severity = if ($severityNode) { $severityNode.InnerText.Trim() } else { '' }
            ReleaseDate = $releaseDate
            Type = if ($typeNode) { $typeNode.InnerText.Trim() } else { $component.SelectSingleNode("./*[local-name()='ComponentType']").GetAttribute('value') }
            Category = if ($categoryNode) { $categoryNode.InnerText.Trim() } else { '' }
            Size = [long]$component.GetAttribute('size')
            DownloadUri = [uri]::new("https://$baseLocation/$relativePath")
            Sha256 = if ($sha256Node) { $sha256Node.InnerText.Trim() } else { '' }
            IsApplicable = $true
            IsInstalled = if ($NoTestInstalled) { $null } else { [bool]$state.IsInstalled }
            ApplicabilityRuleStatus = 1
            InstallRuleStatus = if ($NoTestInstalled) { $null } elseif ($state.IsInstalled) { 1 } else { 0 }
            MatchedDevices = @($state.Matches)
            CatalogPackage = $component
            CatalogItem = $null
            FamilyID = $familyId
        }
        $update.PSObject.TypeNames.Insert(0, 'Dell.Client.Update.DellUpdate')
        $candidateUpdates.Add($update)
    }

    $latestUpdates = foreach ($family in ($candidateUpdates | Group-Object FamilyID)) {
        $family.Group | Sort-Object -Property @(
            @{ Expression = {
                $parsedVersion = [version]'0.0'
                $null = [version]::TryParse($_.Version, [ref]$parsedVersion)
                $parsedVersion
            }; Descending = $true },
            @{ Expression = 'ReleaseDate'; Descending = $true }
        ) | Select-Object -First 1
    }

    Write-Host "Model catalog evaluation complete: $componentCount packages checked; $(@($latestUpdates).Count) installed component families matched."
    foreach ($update in $latestUpdates) {
        if (-not $All -and $update.IsInstalled -ne $false) { continue }
        if ($ExplainRules) {
            $matchSummary = @($update.MatchedDevices | ForEach-Object { "$($_.DeviceName): $($_.InstalledVersion) -> $($_.ExpectedVersion)" }) -join '; '
            Write-Verbose "$($update.ReleaseID) $($update.Name): installed=$($update.IsInstalled); $matchSummary"
        }
        $update
    }
}