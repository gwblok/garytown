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
        $paths.Downloads | Should Be (Join-Path $env:SystemRoot 'Temp\Dell')
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

    It 'can query history when no matching records exist' {
        { @(Get-DellUpdateHist -Status Skipped) } | Should Not Throw
    }
}
