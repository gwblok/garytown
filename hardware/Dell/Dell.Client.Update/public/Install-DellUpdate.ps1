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

    .PARAMETER SaveBIOSUpdateInfoToRegistry
        Save the latest BIOS installation result under
        HKLM:\SOFTWARE\Dell\ClientUpdate\BIOSUpdate.

    .PARAMETER ExportToWMI
        Append installation results to the Dell_UpdateHistory class in the
        root\DellClientUpdate WMI namespace for inventory and compliance use.

    .PARAMETER Proxy
        Proxy server URI used for package downloads.

    .PARAMETER ProxyCredential
        Credential used to authenticate to the proxy server.

    .PARAMETER ProxyUseDefaultCredentials
        Use the current user's credentials for proxy authentication.

    .PARAMETER Category
        Install only updates matching Dell catalog categories. Multiple Dell
        categories may be specified. Omit this parameter to include all.

    .PARAMETER Type
        Install only updates matching Dell component types. Valid values are
        Application, BIOS, Driver, and Firmware. Omit this parameter to include all.

    .PARAMETER Severities
        Install only updates matching Dell's Urgent or Recommended criticality.
        Omit this parameter to include all.

    .PARAMETER Path
        Optional payload download directory. When omitted, a protected folder
        under C:\Windows\Temp\Dell is created and removed automatically.

    .EXAMPLE
        Get-DellUpdate | Install-DellUpdate

    .EXAMPLE
        Install-DellUpdate -PackageIds G896W, 4YHV8 -Force

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
        [switch]$SaveBIOSUpdateInfoToRegistry,
        [switch]$ExportToWMI,

        [uri]$Proxy,
        [pscredential]$ProxyCredential,
        [switch]$ProxyUseDefaultCredentials,

        [ValidateSet('Application', 'Audio', 'BIOS', 'Chipset', 'Communications', 'Docks/Stands', 'Input', 'Network', 'Security', 'Serial ATA', 'Storage', 'Systems Management', 'Video')]
        [string[]]$Category,

        [ValidateSet('Application', 'BIOS', 'Driver', 'Firmware')]
        [string[]]$Type,

        [ValidateSet('Urgent', 'Recommended')]
        [string[]]$Severities,

        [string]$Path
    )

    begin {
        $pipelinePackages = [System.Collections.Generic.List[object]]::new()
        $historyRecords = [System.Collections.Generic.List[object]]::new()
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

        function Publish-DellInstallationResult {
            param(
                [Parameter(Mandatory)][psobject]$Package,
                [Parameter(Mandatory)][psobject]$Result
            )

            if ($SaveBIOSUpdateInfoToRegistry -and $Package.Type -eq 'BIOS') {
                try {
                    Save-DellBiosUpdateInfoToRegistry -Package $Package -Result $Result
                }
                catch {
                    Write-Warning "Could not save BIOS update information to the registry: $($_.Exception.Message)"
                    Write-DellInstallationLog "BIOS registry reporting failed for $($Package.ReleaseID): $($_.Exception.Message)"
                }
            }
            if ($ExportToWMI) {
                try {
                    Export-DellUpdateResultToWmi -Package $Package -Result $Result
                }
                catch {
                    Write-Warning "Could not export update result to WMI: $($_.Exception.Message)"
                    Write-DellInstallationLog "WMI reporting failed for $($Package.ReleaseID): $($_.Exception.Message)"
                }
            }
        }

        $requestedIds = @(Expand-DellPackageIdList -Values $PackageIds)
        $excludedIds = @(Expand-DellPackageIdList -Values $ExcludePackageIds)
        $selectedPackages = if ($PSCmdlet.ParameterSetName -eq 'Packages') {
            @($pipelinePackages)
        }
        else {
            $callerWhatIfPreference = $WhatIfPreference
            try {
                $WhatIfPreference = $false
                @(Get-DellUpdate)
            }
            finally {
                $WhatIfPreference = $callerWhatIfPreference
            }
        }

        if ($requestedIds.Count) {
            $selectedPackages = @($selectedPackages | Where-Object { $_.PackageID -in $requestedIds -or $_.ReleaseID -in $requestedIds -or $_.ID -in $requestedIds })
        }
        if ($excludedIds.Count) {
            $selectedPackages = @($selectedPackages | Where-Object { $_.PackageID -notin $excludedIds -and $_.ReleaseID -notin $excludedIds -and $_.ID -notin $excludedIds })
        }

        if ($PSBoundParameters.ContainsKey('Category')) {
            $selectedPackages = @($selectedPackages | Where-Object { $_.Category -in $Category })
        }

        if ($PSBoundParameters.ContainsKey('Type')) {
            $selectedPackages = @($selectedPackages | Where-Object { $_.Type -in $Type })
        }

        if ($PSBoundParameters.ContainsKey('Severities')) {
            $selectedPackages = @($selectedPackages | Where-Object { $_.Severity -in $Severities })
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
            Join-Path (Get-DellPSUpdatePath -Name Downloads) $([guid]::NewGuid().ToString('N'))
        }
        else {
            $Path
        }
        $logPath = $null
        if (-not $NoLog -and -not $WhatIfPreference) {
            $logDirectory = Get-DellPSUpdatePath -Name Logs
            $null = New-Item -Path $logDirectory -ItemType Directory -Force
            $logPath = Join-Path $logDirectory "$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
            Write-DellInstallationLog "Selected $($selectedPackages.Count) Dell update package(s)."
        }

        try {
            foreach ($package in $selectedPackages) {
                if (-not $PSCmdlet.ShouldProcess($package.Title, 'Download, verify, and install Dell update')) { continue }

                $startedAt = Get-Date
                try {

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
                    $signature = Get-AuthenticodeSignature -LiteralPath $installerPath
                    if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or $signature.SignerCertificate.Subject -notmatch '(?i)\bDell\b') {
                        throw "Authenticode signature validation failed for '$($package.Title)': $($signature.StatusMessage)"
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
                    Publish-DellInstallationResult -Package $package -Result $result
                    $historyRecords.Add((New-DellUpdateHistoryRecord -Package $package -Result $result))
                    $result
                }
                catch {
                    Write-DellInstallationLog "Failed $($package.ReleaseID): $($_.Exception.Message)"
                    $result = [pscustomobject]@{
                        ID = $package.ID
                        PackageID = $package.PackageID
                        ReleaseID = $package.ReleaseID
                        Title = $package.Title
                        Success = $false
                        RebootRequired = $false
                        PendingAction = 'NONE'
                        ExitCode = $null
                        FailureReason = $_.Exception.Message
                        LogPath = $logPath
                        Runtime = (Get-Date) - $startedAt
                    }
                    $result.PSObject.TypeNames.Insert(0, 'Dell.Client.Update.DellInstallResult')
                    Publish-DellInstallationResult -Package $package -Result $result
                    $historyRecords.Add((New-DellUpdateHistoryRecord -Package $package -Result $result))
                    $result
                }
            }
        }
        finally {
            if (-not $WhatIfPreference -and $historyRecords.Count) {
                try {
                    $historyFile = Write-DellUpdateHistorySession -Records @($historyRecords)
                    Write-DellInstallationLog "Installation history saved to $historyFile"
                }
                catch {
                    Write-Warning "Could not save Dell update installation history: $($_.Exception.Message)"
                }
            }
            if ($removePayloadDirectory -and (Test-Path -LiteralPath $payloadDirectory)) {
                Remove-Item -LiteralPath $payloadDirectory -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}