function Get-DellSystemId {
    param([Parameter(Mandatory)][object]$ComputerSystem)

    $sku = ([string]$ComputerSystem.SystemSKUNumber).Trim()
    if ($sku -match '^(?:0x)?(?<hex>[0-9A-Fa-f]{4})$') {
        return $Matches.hex.ToUpperInvariant()
    }
    throw "Dell SystemSKUNumber '$sku' is not a four-character system ID."
}

function Get-DellModelCatalogXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SystemId,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [string]$DownloadDirectory = (Get-DellPSUpdatePath -Name Downloads),
        [switch]$UseCachedCatalog,
        [uri]$CatalogIndexUrl = 'https://downloads.dell.com/catalog/CatalogIndexPC.cab'
    )

    $null = New-Item -Path $WorkingDirectory -ItemType Directory -Force
    $null = New-Item -Path $DownloadDirectory -ItemType Directory -Force
    $indexCabPath = Join-Path $DownloadDirectory 'CatalogIndexPC.cab'
    $indexXmlPath = Join-Path $WorkingDirectory 'CatalogIndexPC.xml'
    $indexExtractDirectory = Join-Path $WorkingDirectory 'CatalogIndex'
    $modelXmlPath = Join-Path $WorkingDirectory "Model_$SystemId.xml"
    $expandPath = Join-Path $env:SystemRoot 'System32\expand.exe'

    if ($UseCachedCatalog -and (Test-Path -LiteralPath $modelXmlPath -PathType Leaf)) {
        Write-Host "Using cached Dell model catalog XML: $modelXmlPath"
        return $modelXmlPath
    }

    Write-Host "Downloading Dell catalog index from $CatalogIndexUrl ..."
    Invoke-WebRequest -Uri $CatalogIndexUrl -OutFile $indexCabPath -UseBasicParsing -ErrorAction Stop
    Remove-Item -LiteralPath $indexXmlPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $indexExtractDirectory -Recurse -Force -ErrorAction SilentlyContinue
    $null = New-Item -Path $indexExtractDirectory -ItemType Directory -Force
    $expandOutput = & $expandPath $indexCabPath '-F:*' $indexExtractDirectory 2>&1
    $extractedIndex = Get-ChildItem -LiteralPath $indexExtractDirectory -File | Select-Object -First 1
    if ($LASTEXITCODE -ne 0 -or -not $extractedIndex) {
        throw "Could not extract Dell catalog index. expand.exe exit code: $LASTEXITCODE. $($expandOutput -join ' ')"
    }
    Copy-Item -LiteralPath $extractedIndex.FullName -Destination $indexXmlPath -Force

    $indexDocument = [System.Xml.XmlDocument]::new()
    $indexDocument.XmlResolver = $null
    $indexDocument.Load($indexXmlPath)
    $manifest = $indexDocument.SelectSingleNode("//*[local-name()='GroupManifest'][.//*[local-name()='Model' and translate(@systemID, 'abcdef', 'ABCDEF')='$SystemId']]")
    if (-not $manifest) { throw "Dell model catalog index does not contain system ID '$SystemId'." }

    $manifestInformation = $manifest.SelectSingleNode("./*[local-name()='ManifestInformation']")
    if (-not $manifestInformation) { throw "Dell model catalog entry for system ID '$SystemId' has no manifest information." }
    $relativePath = $manifestInformation.GetAttribute('path')
    if ([string]::IsNullOrWhiteSpace($relativePath) -or $relativePath -match '(^[\\/]|\.\.)') {
        throw "Dell model catalog path '$relativePath' is invalid."
    }

    $baseLocation = $indexDocument.DocumentElement.GetAttribute('baseLocation')
    if ([string]::IsNullOrWhiteSpace($baseLocation)) { $baseLocation = 'downloads.dell.com' }
    if ($baseLocation -ine 'downloads.dell.com') { throw "Dell model catalog base location '$baseLocation' is not trusted." }
    $modelCatalogUri = [uri]::new("https://$baseLocation/$relativePath")
    $modelCabPath = Join-Path $DownloadDirectory ([IO.Path]::GetFileName($modelCatalogUri.AbsolutePath))

    Write-Host "Downloading Dell model catalog for system ID $SystemId ..."
    Invoke-WebRequest -Uri $modelCatalogUri -OutFile $modelCabPath -UseBasicParsing -ErrorAction Stop
    $sha256Node = $manifest.SelectSingleNode(".//*[local-name()='Hash' and translate(@algorithm, 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')='SHA256']")
    if (-not $sha256Node -or [string]::IsNullOrWhiteSpace($sha256Node.InnerText)) {
        throw "Dell model catalog index does not provide a SHA-256 digest for '$modelCatalogUri'."
    }
    $actualHash = (Get-FileHash -LiteralPath $modelCabPath -Algorithm SHA256).Hash
    if ($actualHash -ine $sha256Node.InnerText.Trim()) {
        Remove-Item -LiteralPath $modelCabPath -Force -ErrorAction SilentlyContinue
        throw "Dell model catalog SHA-256 validation failed for '$modelCatalogUri'."
    }

    $extractDirectory = Join-Path $WorkingDirectory "Model_$SystemId"
    Remove-Item -LiteralPath $extractDirectory -Recurse -Force -ErrorAction SilentlyContinue
    $null = New-Item -Path $extractDirectory -ItemType Directory -Force
    $expandOutput = & $expandPath $modelCabPath '-F:*' $extractDirectory 2>&1
    $extractedXml = Get-ChildItem -LiteralPath $extractDirectory -File | Select-Object -First 1
    if ($LASTEXITCODE -ne 0 -or -not $extractedXml) {
        throw "Could not extract Dell model catalog XML. expand.exe exit code: $LASTEXITCODE. $($expandOutput -join ' ')"
    }

    Copy-Item -LiteralPath $extractedXml.FullName -Destination $modelXmlPath -Force
    return $modelXmlPath
}