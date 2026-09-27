function Get-DellCatalogXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$CatalogUrl,
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [switch]$UseCachedCatalog
    )

    $null = New-Item -Path $WorkingDirectory -ItemType Directory -Force
    $cabPath = Join-Path $WorkingDirectory 'DellSDPCatalogPC.cab'
    $xmlPath = Join-Path $WorkingDirectory 'DellSDPCatalogPC.xml'

    if ($UseCachedCatalog -and (Test-Path -LiteralPath $xmlPath -PathType Leaf)) {
        Write-Host "Using cached Dell catalog XML: $xmlPath"
        return $xmlPath
    }

    Write-Host "Downloading Dell catalog from $CatalogUrl to $cabPath ..."
    Invoke-WebRequest -Uri $CatalogUrl -OutFile $cabPath -UseBasicParsing -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $cabPath -PathType Leaf)) {
        throw "Dell catalog CAB was not downloaded to '$cabPath'."
    }

    Write-Host "Catalog downloaded. Extracting XML to $WorkingDirectory ..."
    Remove-Item -LiteralPath $xmlPath -Force -ErrorAction SilentlyContinue
    $expandPath = Join-Path $env:SystemRoot 'System32\expand.exe'
    $expandOutput = & $expandPath '-F:DellSDPCatalogPC.xml' $cabPath $WorkingDirectory 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $xmlPath -PathType Leaf)) {
        throw "Could not extract DellSDPCatalogPC.xml. expand.exe exit code: $LASTEXITCODE. $($expandOutput -join ' ')"
    }

    Write-Host "Catalog XML ready: $xmlPath"
    return $xmlPath
}

function Get-DellCatalogPackageDocuments {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $settings.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create($Path, $settings)
    try {
        while ($reader.Read()) {
            if ($reader.NodeType -ne [System.Xml.XmlNodeType]::Element -or $reader.LocalName -ne 'SoftwareDistributionPackage') {
                continue
            }

            $subtree = $reader.ReadSubtree()
            try {
                $document = [System.Xml.XmlDocument]::new()
                $document.XmlResolver = $null
                $document.Load($subtree)
                Write-Output $document
            }
            finally {
                $subtree.Dispose()
            }
        }
    }
    finally {
        $reader.Dispose()
    }
}

function Get-DellXmlText {
    param(
        [Parameter(Mandatory)][System.Xml.XmlNode]$Node,
        [Parameter(Mandatory)][string]$XPath
    )

    $selected = $Node.SelectSingleNode($XPath)
    if ($selected -is [System.Xml.XmlAttribute]) { return ([string]$selected.Value).Trim() }
    if ($selected) { return ([string]$selected.InnerText).Trim() }
    return ''
}

function Get-DellCatalogFileDigest {
    param([Parameter(Mandatory)][string]$Path)

    $algorithm = [System.Security.Cryptography.SHA1]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try { return [Convert]::ToBase64String($algorithm.ComputeHash($stream)) }
        finally { $stream.Dispose() }
    }
    finally {
        $algorithm.Dispose()
    }
}
