function Install-DellUpdate {
    <#
    .SYNOPSIS
        Downloads and installs a Dell update returned by Get-DellUpdate.

    .DESCRIPTION
        Accepts Dell update objects from the pipeline, verifies the catalog
        digest for downloaded payloads, and invokes the MSI or command-line
        installer declared by Dell. Objects not marked applicable and not
        installed are rejected.

    .PARAMETER Update
        Dell update object returned by Get-DellUpdate.

    .PARAMETER Path
        Directory used to store downloaded installer files.

    .EXAMPLE
        Get-DellUpdate | Install-DellUpdate -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject]$Update,
        [string]$Path = (Join-Path $env:ProgramData 'DellPSUPdater\Packages')
    )

    process {
        if ($Update.PSObject.TypeNames -notcontains 'Dell.Client.Update.DellUpdate') {
            throw 'Install-DellUpdate requires an update object returned by Get-DellUpdate.'
        }
        if ($Update.IsApplicable -ne $true -or $Update.IsInstalled -ne $false) {
            throw "Refusing to install '$($Update.Title)': it is not positively marked applicable and not installed."
        }

        if (-not $PSCmdlet.ShouldProcess($Update.Title, 'Download and install Dell catalog update')) {
            return
        }

        $item = $Update.CatalogItem
        $commandLineData = $item.SelectSingleNode("./*[local-name()='CommandLineInstallerData']")
        $msiData = $item.SelectSingleNode("./*[local-name()='MsiInstallerData']")
        $originFiles = @($item.SelectNodes("./*[local-name()='OriginFile']"))

        if ($commandLineData) {
            $programName = $commandLineData.GetAttribute('Program')
            $origin = $originFiles | Where-Object { [IO.Path]::GetFileName($_.GetAttribute('FileName')) -ieq [IO.Path]::GetFileName($programName) } | Select-Object -First 1
            if (-not $programName -or -not $origin) {
                throw "Catalog installer source is missing for '$($Update.Title)'."
            }
            $installerFileName = [IO.Path]::GetFileName($programName)
            $installerArguments = $commandLineData.GetAttribute('Arguments')
        }
        elseif ($msiData) {
            $msiFile = $msiData.GetAttribute('MsiFile')
            $origin = $originFiles | Where-Object { [IO.Path]::GetFileName($_.GetAttribute('FileName')) -ieq [IO.Path]::GetFileName($msiFile) } | Select-Object -First 1
            if (-not $origin) { throw "Catalog MSI source is missing for '$($Update.Title)'." }
            $installerFileName = [IO.Path]::GetFileName($msiFile)
            $msiProperties = $msiData.GetAttribute('CommandLine')
            $installerArguments = "/i `"$(Join-Path $Path $installerFileName)`" /qn /norestart $msiProperties"
        }
        else {
            throw "Unsupported installer format for '$($Update.Title)'. Only Dell catalog MSI and command-line installer records are supported."
        }

        $sourceUri = $origin.GetAttribute('OriginUri')
        if ($sourceUri -notmatch '^https://') { throw "Refusing non-HTTPS catalog payload URI: '$sourceUri'." }
        $null = New-Item -Path $Path -ItemType Directory -Force
        $installerPath = Join-Path $Path $installerFileName

        Write-Verbose "Downloading '$($Update.Title)' from $sourceUri"
        Invoke-WebRequest -Uri $sourceUri -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
            throw "Download did not create installer file '$installerPath'."
        }

        $expectedDigest = $origin.GetAttribute('Digest')
        if ($expectedDigest) {
            $actualDigest = Get-DellCatalogFileDigest -Path $installerPath
            if ($actualDigest -ne $expectedDigest) {
                Remove-Item -LiteralPath $installerPath -Force -ErrorAction SilentlyContinue
                throw "Catalog SHA-1 digest validation failed for '$($Update.Title)'."
            }
        }

        if ($msiData) {
            $executable = Join-Path $env:SystemRoot 'System32\msiexec.exe'
        }
        else {
            $executable = $installerPath
        }

        Write-Verbose "Starting '$($Update.Title)': $executable $installerArguments"
        $processResult = Start-Process -FilePath $executable -ArgumentList $installerArguments -WorkingDirectory $Path -Wait -PassThru
        $catalogReturnCode = $null
        if ($commandLineData) {
            $catalogReturnCode = $commandLineData.SelectSingleNode("./*[local-name()='ReturnCode'][@Code='$($processResult.ExitCode)']")
        }

        if ($catalogReturnCode) {
            $success = $catalogReturnCode.GetAttribute('Result') -eq 'Succeeded'
            $reboot = $catalogReturnCode.GetAttribute('Reboot') -eq 'true'
        }
        elseif ($commandLineData) {
            $defaultResult = $commandLineData.GetAttribute('DefaultResult')
            $success = ($processResult.ExitCode -eq 0 -or $defaultResult -eq 'Succeeded')
            $reboot = $commandLineData.GetAttribute('RebootByDefault') -eq 'true'
        }
        else {
            $success = $processResult.ExitCode -in @(0, 3010, 1641)
            $reboot = $processResult.ExitCode -in @(3010, 1641)
        }

        $result = [pscustomobject]@{
            ID = $Update.ID
            Title = $Update.Title
            Success = [bool]$success
            PendingAction = if ($reboot) { 'REBOOT_MANDATORY' } else { 'NONE' }
            ExitCode = $processResult.ExitCode
            InstallerPath = $installerPath
            Runtime = $processResult.ExitTime - $processResult.StartTime
        }
        $result.PSObject.TypeNames.Insert(0, 'Dell.Client.Update.DellInstallResult')
        $result
    }
}
