Function Get-MSICode {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$AppPath
    )
    $MSI = Get-ChildItem -Path $AppPath -Filter *.msi
    if ($MSI) {
        $WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
        $Database = $WindowsInstaller.OpenDatabase($MSI.FullName, 0)
        $View = $Database.OpenView("SELECT Value FROM Property WHERE Property = 'ProductCode'")
        $View.Execute()
        $Record = $View.Fetch()
        if ($Record) {
            $ProductCode = $Record.StringData(1)
            Write-Verbose "Product Code: $ProductCode"
        } else {
            Write-Verbose "Product Code not found."
        }
        $View.Close()
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($WindowsInstaller) | Out-Null
        return $ProductCode
    } else {
        Write-Verbose "No MSI file found."
    }
}

