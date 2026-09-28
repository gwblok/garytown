$moduleRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $moduleRoot 'Dell.Client.Update.psd1'
$env:TEMP = (Get-Item -LiteralPath $env:TEMP).FullName
$env:TMP = $env:TEMP

Remove-Module Dell.Client.Update -Force -ErrorAction SilentlyContinue
Import-Module $manifestPath -Force -ErrorAction Stop

Describe 'Dell.Client.Update module' {
    It 'has a valid module manifest' {
        $manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
        $manifest.Name | Should Be 'Dell.Client.Update'
        $manifest.Version.ToString() | Should Be '0.5.0'
    }

    It 'exports only the intended public commands' {
        $exports = @((Get-Module Dell.Client.Update).ExportedFunctions.Keys | Sort-Object)
        $exports.Count | Should Be 3
        ($exports -join ',') | Should Be 'Get-DellUpdate,Get-DellUpdateHist,Install-DellUpdate'
    }

    It 'uses the expected storage layout' {
        $paths = & (Get-Module Dell.Client.Update) {
            [pscustomobject]@{
                Catalogs = Get-DellPSUpdatePath -Name Catalogs
                Downloads = Get-DellPSUpdatePath -Name Downloads
                History = Get-DellPSUpdatePath -Name History
                Logs = Get-DellPSUpdatePath -Name Logs
            }
        }
        $paths.Downloads | Should Be (Join-Path $env:ProgramData 'DellPSUpdate\Downloads')
        $paths.Catalogs | Should Be (Join-Path $env:ProgramData 'DellPSUpdate\Catalogs')
        $paths.History | Should Be (Join-Path $env:ProgramData 'DellPSUpdate\History')
        $paths.Logs | Should Be (Join-Path $env:ProgramData 'DellPSUpdate\Logs')
    }

    It 'accepts Dell update objects from the pipeline' {
        $parameter = (Get-Command Install-DellUpdate).Parameters['Packages']
        @($parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }).ValueFromPipeline | Should Be $true
        ($parameter.Aliases -contains 'Package') | Should Be $true
    }

    It 'uses Dell-native type and severity values' {
        $command = Get-Command Install-DellUpdate
        $typeValues = @($command.Parameters['Type'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | ForEach-Object ValidValues)
        $severityValues = @($command.Parameters['Severities'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | ForEach-Object ValidValues)
        ($typeValues -join ',') | Should Be 'Application,BIOS,Driver,Firmware'
        ($severityValues -join ',') | Should Be 'Urgent,Recommended'
    }

    It 'supports concise and detailed update output' {
        $parameters = (Get-Command Get-DellUpdate).Parameters
        $parameters.ContainsKey('Details') | Should Be $true
        $parameters.ContainsKey('HonorDCUPolicy') | Should Be $true
        $delayRange = @($parameters['DelayDays'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] })[0]
        $delayRange.MinRange | Should Be 1
        $delayRange.MaxRange | Should Be 45
    }

    It 'rejects conflicting delay options' {
        { Get-DellUpdate -HonorDCUPolicy -DelayDays 14 } | Should Throw '-HonorDCUPolicy and -DelayDays cannot be used together.'
    }

    It 'supports registry and WMI reporting switches' {
        $parameters = (Get-Command Install-DellUpdate).Parameters
        $parameters.ContainsKey('SaveBIOSUpdateInfoToRegistry') | Should Be $true
        $parameters.ContainsKey('ExportToWMI') | Should Be $true
    }

    It 'does not expose license or signature bypass switches' {
        $parameters = (Get-Command Install-DellUpdate).Parameters
        $parameters.ContainsKey('AcceptLicense') | Should Be $false
        $parameters.ContainsKey('SkipSignatureCheck') | Should Be $false
    }

    It 'treats a current base driver as installed when stale extension INFs remain' {
        Mock Get-DellModelComponentMatches {
            @(
                [pscustomobject]@{ InstalledVersion = [version]'10.0.26200.21387'; ExpectedVersion = [version]'10.0.26200.21387'; IdentityType = 'PnP'; InfType = 'base' },
                [pscustomobject]@{ InstalledVersion = [version]'10.0.22000.1'; ExpectedVersion = [version]'10.0.26200.1'; IdentityType = 'Extension'; InfType = 'extension' }
            )
        } -ModuleName Dell.Client.Update
        [xml]$document = '<SoftwareComponent vendorVersion="10.0.26200.21387"><ComponentType value="DRVR" /></SoftwareComponent>'

        $state = & (Get-Module Dell.Client.Update) {
            param($component)
            Get-DellModelComponentState -Component $component -Inventory ([pscustomobject]@{})
        } $document.DocumentElement

        $state.IsInstalled | Should Be $true
        $state.ApplicabilityReason | Should Match 'meet or exceed'
    }

    It 'plans a package under WhatIf without creating payload files' {
        $testPath = Join-Path $TestDrive 'Downloads'
        $package = [pscustomobject]@{
            ID = 'TEST'
            PackageID = 'TEST'
            ReleaseID = 'TEST'
            Title = 'Test Dell Update'
            Version = '1.0'
            DellVersion = 'A00'
            Category = 'Chipset'
            Type = 'Driver'
            Severity = 'Recommended'
            DownloadUri = [uri]'https://downloads.dell.com/test.exe'
            Sha256 = 'ABC'
            IsApplicable = $true
            IsInstalled = $false
        }
        $package.PSObject.TypeNames.Insert(0, 'Dell.Client.Update.DellUpdate')

        { $package | Install-DellUpdate -Path $testPath -WhatIf } | Should Not Throw
        (Test-Path -LiteralPath $testPath) | Should Be $false
    }

    It 'rejects a package with a mismatched SHA-256 digest' {
        $file = Join-Path $TestDrive 'HashTest.exe'
        Set-Content -LiteralPath $file -Value 'test' -Encoding ASCII
        { & (Get-Module Dell.Client.Update) { param($path) Test-DellUpdatePackage -Path $path -ExpectedSha256 'BAD' } $file } | Should Throw 'Catalog SHA-256 validation failed'
    }

    It 'rejects an unsigned package even when its SHA-256 digest matches' {
        $file = Join-Path $TestDrive 'SignatureTest.exe'
        Set-Content -LiteralPath $file -Value 'test' -Encoding ASCII
        $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
        { & (Get-Module Dell.Client.Update) { param($path, $expectedHash) Test-DellUpdatePackage -Path $path -ExpectedSha256 $expectedHash } $file $hash } | Should Throw 'Authenticode signature validation failed'
    }

    It 'does not publish registry, WMI, or JSON history during WhatIf' {
        Mock Save-DellBiosUpdateInfoToRegistry {} -ModuleName Dell.Client.Update
        Mock Export-DellUpdateResultToWmi {} -ModuleName Dell.Client.Update
        Mock Write-DellUpdateHistorySession {} -ModuleName Dell.Client.Update
        $package = [pscustomobject]@{
            ID = 'BIOS-TEST'
            PackageID = 'BIOS-TEST'
            ReleaseID = 'BIOS-TEST'
            Title = 'Test Dell BIOS'
            Version = '1.0'
            DellVersion = 'A01'
            Category = 'BIOS'
            Type = 'BIOS'
            Severity = 'Urgent'
            DownloadUri = [uri]'https://downloads.dell.com/test.exe'
            Sha256 = 'ABC'
            IsApplicable = $true
            IsInstalled = $false
        }
        $package.PSObject.TypeNames.Insert(0, 'Dell.Client.Update.DellUpdate')

        $package | Install-DellUpdate -SaveBIOSUpdateInfoToRegistry -ExportToWMI -WhatIf
        Assert-MockCalled Save-DellBiosUpdateInfoToRegistry -ModuleName Dell.Client.Update -Times 0
        Assert-MockCalled Export-DellUpdateResultToWmi -ModuleName Dell.Client.Update -Times 0
        Assert-MockCalled Write-DellUpdateHistorySession -ModuleName Dell.Client.Update -Times 0
    }

    It 'reads and filters JSON history records newest first' {
        $global:DellHistoryTestPath = Join-Path $TestDrive 'History'
        $null = New-Item -Path $global:DellHistoryTestPath -ItemType Directory -Force
        Mock Get-DellPSUpdatePath { $global:DellHistoryTestPath } -ModuleName Dell.Client.Update
        @(
            [pscustomobject]@{ Timestamp = '2026-09-26T00:00:00Z'; Status = 'Success'; Category = 'BIOS'; Type = 'BIOS'; UpdateID = 'OLD' },
            [pscustomobject]@{ Timestamp = '2026-09-27T00:00:00Z'; Status = 'Failed'; Category = 'Chipset'; Type = 'Driver'; UpdateID = 'NEW' }
        ) | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $global:DellHistoryTestPath 'InstallHist-Test.json') -Encoding UTF8

        $records = @(Get-DellUpdateHist)
        $records.Count | Should Be 2
        $records[0].UpdateID | Should Be 'NEW'
        @(Get-DellUpdateHist -Status Failed -Category Chipset -Type Driver).Count | Should Be 1
        @(Get-DellUpdateHist -Last 1).Count | Should Be 1
        Remove-Variable DellHistoryTestPath -Scope Global -Force
    }

    It 'can query history when no matching records exist' {
        { @(Get-DellUpdateHist -Status Failed) } | Should Not Throw
    }
}
