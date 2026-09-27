function Install-DellUpdate {
    <#
    .SYNOPSIS
        Installs applicable Dell updates.

    .DESCRIPTION
        Accepts update objects from Get-DellUpdate through the pipeline or
        searches by package ID. The command lists selected updates and asks
        for confirmation unless -Force is specified. Payloads are downloaded
        over HTTPS, validated with Dell's SHA-256 digest, silently installed,
        logged, and removed from the temporary download directory.

    .PARAMETER PackageIds
        Install only these Dell package or release IDs. Multiple IDs may be
        supplied as an array or as comma-separated values. Cannot be combined
        with -Packages.

    .PARAMETER Packages
        Update objects returned by Get-DellUpdate. Accepts pipeline input.
        Cannot be combined with -PackageIds.

    .PARAMETER ExcludePackageIds
        Exclude these package or release IDs from installation.

    .PARAMETER NoLog
        Do not create an installation log.

    .PARAMETER Force
        Start installation without the confirmation prompt.

    .PARAMETER AcceptLicense
        Accept the license terms for selected Dell update packages. Required
        for installation, but not for -WhatIf.

    .PARAMETER Category
        Install BIOS updates, driver updates, or all selected updates.

    .PARAMETER Severities
        Install only updates matching the specified severity values. Dell's
        Urgent, Recommended, and Optional values are supported along with the
        Panasonic-style Critical, Important, Moderate, Low, and Unspecified
        aliases.

    .PARAMETER Path
        Optional payload download directory. When omitted, a protected folder
        under ProgramData is created and removed automatically.

    .EXAMPLE
        Get-DellUpdate | Install-DellUpdate -AcceptLicense

    .EXAMPLE
        Install-DellUpdate -PackageIds G896W, 4YHV8 -AcceptLicense -Force

    .EXAMPLE
        Get-DellUpdate | Install-DellUpdate -ExcludePackageIds 4YHV8 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Search', ConfirmImpact = 'Medium')]
    param(
        [Parameter(Position = 0, ParameterSetName = 'Search')]
        [Alias('PackageId')]
        [string[]]$PackageIds,

        [Parameter(Position = 0, ValueFromPipeline, ParameterSetName = 'Packages')]
        [Alias('Package', 'Update')]
        [psobject[]]$Packages,

        [string[]]$ExcludePackageIds,
        [switch]$NoLog,
        [switch]$Force,
        [switch]$AcceptLicense,
        [switch]$SkipSignatureCheck,

        [uri]$Proxy,
        [pscredential]$ProxyCredential,
        [switch]$ProxyUseDefaultCredentials,

        [ValidateSet('OnlyBios', 'OnlyDrivers', 'All')]
        [string]$Category = 'All',

        [ValidateSet('Urgent', 'Recommended', 'Optional', 'Critical', 'Important', 'Moderate', 'Low', 'Unspecified')]
        [string[]]$Severities,

        [string]$Path
    )

    begin {
        $pipelinePackages = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($package in @($Packages)) {
            if ($null -ne $package) { $pipelinePackages.Add($package) }
        }
    }

    end {
        function Expand-DellPackageIdList {
            param([string[]]$Values)
            @($Values | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        }

        function Write-DellInstallationLog {
            param([string]$Message)
            if ($NoLog -or -not $logPath) { return }
            Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message" -Encoding UTF8
        }

        $requestedIds = @(Expand-DellPackageIdList -Values $PackageIds)
        $excludedIds = @(Expand-DellPackageIdList -Values $ExcludePackageIds)
        $selectedPackages = if ($PSCmdlet.ParameterSetName -eq 'Packages') {
            @($pipelinePackages)
        }
        else {
            @(Get-DellUpdate)
        }

        if ($requestedIds.Count) {
            $selectedPackages = @($selectedPackages | Where-Object { $_.PackageID -in $requestedIds -or $_.ReleaseID -in $requestedIds -or $_.ID -in $requestedIds })
        }
        if ($excludedIds.Count) {
            $selectedPackages = @($selectedPackages | Where-Object { $_.PackageID -notin $excludedIds -and $_.ReleaseID -notin $excludedIds -and $_.ID -notin $excludedIds })
        }

        if ($Category -eq 'OnlyBios') {
            $selectedPackages = @($selectedPackages | Where-Object { $_.Type -match 'BIOS' -or $_.Category -eq 'BIOS' })
        }
        elseif ($Category -eq 'OnlyDrivers') {
            $selectedPackages = @($selectedPackages | Where-Object { $_.Type -eq 'Driver' })
        }

        if ($PSBoundParameters.ContainsKey('Severities')) {
            $severityMap = @{
                Critical = @('Critical', 'Urgent')
                Important = @('Important', 'Recommended')
                Moderate = @('Moderate')
                Low = @('Low', 'Optional')
                Unspecified = @('Unspecified', '')
                Urgent = @('Urgent')
                Recommended = @('Recommended')
                Optional = @('Optional')
            }
            $acceptedSeverities = @($Severities | ForEach-Object { $severityMap[$_] } | Select-Object -Unique)
            $selectedPackages = @($selectedPackages | Where-Object { $_.Severity -in $acceptedSeverities })
        }

        $selectedPackages = @($selectedPackages | Sort-Object ReleaseID -Unique)
        if (-not $selectedPackages.Count) {
            Write-Verbose 'No applicable Dell updates matched the specified criteria.'
            return
        }

        foreach ($package in $selectedPackages) {
            if ($package.PSObject.TypeNames -notcontains 'Dell.Client.Update.DellUpdate') {
                throw 'Install-DellUpdate requires update objects returned by Get-DellUpdate.'
            }
            if ($package.IsApplicable -ne $true -or $package.IsInstalled -ne $false) {
                throw "Refusing to install '$($package.Title)': it is not positively marked applicable and not installed."
            }
            if (-not $package.DownloadUri -or -not $package.Sha256) {
                throw "Dell model catalog payload metadata is incomplete for '$($package.Title)'."
            }
        }

        if (-not $WhatIfPreference -and -not $AcceptLicense) {
            throw '-AcceptLicense is required before installing Dell update packages.'
        }

        if (-not $Force -and -not $WhatIfPreference) {
            Write-Host 'The following Dell updates will be installed:'
            $selectedPackages | Select-Object ReleaseID, Name, Version, Severity | Format-Table -AutoSize | Out-Host
            if (-not $PSCmdlet.ShouldContinue("Install $($selectedPackages.Count) Dell update package(s)?", 'Install Dell updates')) {
                return
            }
        }

        $isAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $WhatIfPreference -and -not $isAdministrator) {
            throw 'Install-DellUpdate must be run from an elevated PowerShell session.'
        }

        $removePayloadDirectory = [string]::IsNullOrWhiteSpace($Path)
        $payloadDirectory = if ($removePayloadDirectory) {
            Join-Path $env:ProgramData "Dell\ClientUpdate\Temp\$([guid]::NewGuid().ToString('N'))"
        }
        else {
            $Path
        }
        $logPath = $null
        if (-not $NoLog -and -not $WhatIfPreference) {
            $logDirectory = 'C:\util2\DellClientUpdate'
            $null = New-Item -Path $logDirectory -ItemType Directory -Force
            $logPath = Join-Path $logDirectory "$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Write-DellInstallationLog "Selected $($selectedPackages.Count) Dell update package(s)."
        }

        try {
            foreach ($package in $selectedPackages) {
                if (-not $PSCmdlet.ShouldProcess($package.Title, 'Download, verify, and install Dell update')) { continue }

                $sourceUri = [uri]$package.DownloadUri
                if ($sourceUri.Scheme -ne 'https') { throw "Refusing non-HTTPS catalog payload URI: '$sourceUri'." }
                $null = New-Item -Path $payloadDirectory -ItemType Directory -Force
                $installerPath = Join-Path $payloadDirectory ([IO.Path]::GetFileName($sourceUri.AbsolutePath))

                $actualDigest = if (Test-Path -LiteralPath $installerPath -PathType Leaf) {
                    (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
                }
                if ($actualDigest -ine [string]$package.Sha256) {
                    $webRequestParameters = @{
                        Uri = $sourceUri
                        OutFile = $installerPath
                        UseBasicParsing = $true
                        ErrorAction = 'Stop'
                    }
                    if ($Proxy) { $webRequestParameters.Proxy = $Proxy }
                    if ($ProxyCredential) { $webRequestParameters.ProxyCredential = $ProxyCredential }
                    if ($ProxyUseDefaultCredentials) { $webRequestParameters.ProxyUseDefaultCredentials = $true }
                    Write-DellInstallationLog "Downloading $($package.ReleaseID) from $sourceUri"
                    Invoke-WebRequest @webRequestParameters
                    $actualDigest = (Get-FileHash -LiteralPath $installerPath -Algorithm SHA256).Hash
                }
                if ($actualDigest -ine [string]$package.Sha256) {
                    throw "Catalog SHA-256 validation failed for '$($package.Title)'."
                }
                if (-not $SkipSignatureCheck) {
                    $signature = Get-AuthenticodeSignature -LiteralPath $installerPath
                    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or $signature.SignerCertificate.Subject -notmatch '(?i)\bDell\b') {
                        throw "Authenticode signature validation failed for '$($package.Title)': $($signature.StatusMessage)"
                    }
                }

                Write-DellInstallationLog "Starting $($package.ReleaseID): $installerPath /s"
                $processResult = Start-Process -FilePath $installerPath -ArgumentList '/s' -WorkingDirectory $payloadDirectory -Wait -PassThru
                $success = $processResult.ExitCode -in @(0, 2)
                $rebootRequired = $processResult.ExitCode -eq 2
                Write-DellInstallationLog "Completed $($package.ReleaseID) with exit code $($processResult.ExitCode)."

                $result = [pscustomobject]@{
                    ID = $package.ID
                    PackageID = $package.PackageID
                    ReleaseID = $package.ReleaseID
                    Title = $package.Title
                    Success = [bool]$success
                    RebootRequired = [bool]$rebootRequired
                    PendingAction = if ($rebootRequired) { 'REBOOT_MANDATORY' } else { 'NONE' }
                    ExitCode = $processResult.ExitCode
                    FailureReason = if ($success) { '' } else { "Dell update package exited with code $($processResult.ExitCode)." }
                    LogPath = $logPath
                    Runtime = $processResult.ExitTime - $processResult.StartTime
                }
                $result.PSObject.TypeNames.Insert(0, 'Dell.Client.Update.DellInstallResult')
                $result
            }
        }
        finally {
            if ($removePayloadDirectory -and (Test-Path -LiteralPath $payloadDirectory)) {
                Remove-Item -LiteralPath $payloadDirectory -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}