function Get-DellUpdate {
    <#
    .SYNOPSIS
        Gets Dell catalog updates applicable to this computer.

    .DESCRIPTION
        Streams Dell's third-party update catalog, evaluates each package's
        installability and installed-state rule trees, and returns update
        objects in the same style as Lenovo.Client.Update's Get-LnvUpdate.
        Dell updates that are superseded, already installed, not applicable,
        or indeterminate are not returned by default.

    .PARAMETER All
        Return all non-superseded catalog items whose package is applicable to
        this system, including already-installed items. Applicability is still
        evaluated; this does not mean every catalog item is returned.

    .PARAMETER NoTestInstalled
        Do not evaluate installed state. Requires -All; IsInstalled is $null.

    .PARAMETER UseCachedCatalog
        Reuse DellSDPCatalogPC.xml if it already exists in WorkingDirectory.

    .PARAMETER ExplainRules
        Attach ApplicabilityRuleStatus and InstallRuleStatus to every returned
        update object and include status details in verbose output.

        .NOTES
            Dell model-specific rules use WMI classes in Root\Dell\sysinv. When
            that namespace is unavailable, the module uses native SMBIOS, BIOS,
            PnP driver, OS, and MSI registry data to evaluate supported predicates.
            Some Dell inventory identities cannot be reconstructed exactly; those
            remain indeterminate and are excluded from normal results. DSIA can
            improve coverage, but it is not a prerequisite.
    #>
    [CmdletBinding()]
    param(
        [switch]$All,
        [switch]$NoTestInstalled,
        [switch]$UseCachedCatalog,
        [switch]$ExplainRules,
        [uri]$CatalogUrl = 'https://downloads.dell.com/catalog/DellSDPCatalogPC.cab',
        [string]$WorkingDirectory = (Join-Path $env:ProgramData 'DellPSUPdater')
    )

    if ($NoTestInstalled -and -not $All) {
        throw '-NoTestInstalled can only be used with -All.'
    }

    $computer = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    if ($computer.Manufacturer -notmatch '^Dell') {
        throw "Get-DellUpdate supports Dell systems only. Detected '$($computer.Manufacturer)'."
    }

    $catalogXml = Get-DellCatalogXml -CatalogUrl $CatalogUrl -WorkingDirectory $WorkingDirectory -UseCachedCatalog:$UseCachedCatalog
    $candidateUpdates = [System.Collections.Generic.List[object]]::new()
    $supersededPackageIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $applicablePackageDocuments = [System.Collections.Generic.List[System.Xml.XmlDocument]]::new()
    $packageCount = 0
    $installabilityPassCount = 0

    foreach ($document in (Get-DellCatalogPackageDocuments -Path $catalogXml)) {
        $packageCount++
        $package = $document.DocumentElement
        $properties = $package.SelectSingleNode("./*[local-name()='Properties']")
        $packageId = if ($properties) { $properties.GetAttribute('PackageID') } else { '' }
        $title = Get-DellXmlText -Node $package -XPath ".//*[local-name()='LocalizedProperties']/*[local-name()='Title']"
        if (-not $title) { $title = $packageId }

        $installableNode = $package.SelectSingleNode("./*[local-name()='IsInstallable']")
        if (-not $installableNode) { continue }
            Set-DellNativeRuleContext -Node $package
        $installabilityStatus = Test-DellCatalogRule -Rule ([System.Xml.XmlElement]$installableNode.FirstChild)
        if ($installabilityStatus -ne 1) { continue }
        $installabilityPassCount++
        $applicablePackageDocuments.Add($document)

        foreach ($supersededNode in $package.SelectNodes("./*[local-name()='SupersededPackages']/*[local-name()='PackageID']")) {
            if ($supersededNode.InnerText.Trim()) {
                $null = $supersededPackageIds.Add($supersededNode.InnerText.Trim())
            }
        }

    }

    foreach ($document in $applicablePackageDocuments) {
        $package = $document.DocumentElement
        $properties = $package.SelectSingleNode("./*[local-name()='Properties']")
        $packageId = if ($properties) { $properties.GetAttribute('PackageID') } else { '' }
        $title = Get-DellXmlText -Node $package -XPath ".//*[local-name()='LocalizedProperties']/*[local-name()='Title']"
        if (-not $title) { $title = $packageId }

        foreach ($item in $package.SelectNodes("./*[local-name()='InstallableItem']")) {
            Set-DellNativeRuleContext -Node $item
            $itemInstallable = $item.SelectSingleNode("./*[local-name()='ApplicabilityRules']/*[local-name()='IsInstallable']")
            $itemApplicabilityStatus = if ($itemInstallable) {
                Test-DellCatalogRule -Rule ([System.Xml.XmlElement]$itemInstallable.FirstChild)
            }
            else {
                1
            }
            if ($itemApplicabilityStatus -ne 1) { continue }

            $isInstalledNode = $item.SelectSingleNode("./*[local-name()='ApplicabilityRules']/*[local-name()='IsInstalled']")
            if ($NoTestInstalled) {
                $installedStatus = $null
            }
            elseif ($isInstalledNode -and $isInstalledNode.FirstChild) {
                $installedStatus = Test-DellCatalogRule -Rule ([System.Xml.XmlElement]$isInstalledNode.FirstChild)
            }
            else {
                $installedStatus = -1
                Write-DellRuleWarningOnce "Catalog item '$title' ($packageId) has no usable IsInstalled rule; installed state is unknown."
            }

            if (-not $All -and $installedStatus -ne 0) { continue }

            $update = [pscustomobject]@{
                ID = $packageId
                PackageID = $packageId
                Name = $title
                Title = $title
                Severity = Get-DellXmlText -Node $package -XPath ".//*[local-name()='UpdateSpecificData']/@MsrcSeverity"
                ReleaseDate = Get-DellXmlText -Node $package -XPath ".//*[local-name()='Properties']/@CreationDate"
                Type = Get-DellXmlText -Node $package -XPath ".//*[local-name()='UpdateSpecificData']/@UpdateClassification"
                IsApplicable = ($installabilityStatus -eq 1 -and $itemApplicabilityStatus -eq 1)
                IsInstalled = if ($null -eq $installedStatus) { $null } elseif ($installedStatus -lt 0) { $null } else { [bool]$installedStatus }
                ApplicabilityRuleStatus = $installabilityStatus
                InstallRuleStatus = $installedStatus
                CatalogPackage = $package
                CatalogItem = $item
            }
            $update.PSObject.TypeNames.Insert(0, 'Dell.Client.Update.DellUpdate')
            $candidateUpdates.Add($update)
        }
    }

    Write-Verbose "Read $packageCount catalog packages; $installabilityPassCount passed package applicability; $($candidateUpdates.Count) candidate items passed item applicability and installed-state filters."

    foreach ($update in $candidateUpdates) {
        if ($supersededPackageIds.Contains($update.PackageID)) {
            Write-Verbose "Skipping superseded update $($update.PackageID): $($update.Title)"
            continue
        }
        if ($ExplainRules) {
            Write-Verbose "Update $($update.PackageID): applicable=$($update.IsApplicable), installed=$($update.IsInstalled), install-rule-status=$($update.InstallRuleStatus)"
        }
        $update
    }
}
