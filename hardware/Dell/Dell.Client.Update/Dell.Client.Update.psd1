@{
    RootModule = 'Dell.Client.Update.psm1'
    ModuleVersion = '0.3.0'
    GUID = 'f0ce0f0b-7b7c-44f4-9eb9-364a09f6bd9d'
    Author = 'OEMWrapPS-Local'
    CompanyName = 'Community'
    Copyright = '(c) Gary Blok. All rights reserved.'
    Description = 'Scans and installs Dell updates using model-specific catalogs and native Windows inventory.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-DellUpdate', 'Install-DellUpdate')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Dell', 'Update', 'BIOS', 'Driver', 'Firmware', 'Catalog')
        }
    }
}
