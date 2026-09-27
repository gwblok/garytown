function Get-DellUpdateHist {
    <#
    .SYNOPSIS
        Gets Dell update installation history.

    .DESCRIPTION
        Reads installation session records created by Install-DellUpdate under
        C:\ProgramData\DellPSUpdate\History and returns them newest first.

    .PARAMETER Status
        Return only Success, Failed, or Skipped records.

    .PARAMETER Category
        Return only records matching one or more Dell catalog categories.

    .PARAMETER Type
        Return only records matching Dell Application, BIOS, Driver, or
        Firmware component types.

    .PARAMETER Last
        Return only the specified number of most recent records.

    .EXAMPLE
        Get-DellUpdateHist

    .EXAMPLE
        Get-DellUpdateHist -Status Failed

    .EXAMPLE
        Get-DellUpdateHist -Type BIOS -Last 10
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Success', 'Failed', 'Skipped')]
        [string[]]$Status,

        [ValidateSet('Application', 'Audio', 'BIOS', 'Chipset', 'Communications', 'Docks/Stands', 'Input', 'Network', 'Security', 'Serial ATA', 'Storage', 'Systems Management', 'Video')]
        [string[]]$Category,

        [ValidateSet('Application', 'BIOS', 'Driver', 'Firmware')]
        [string[]]$Type,

        [ValidateRange(1, [int]::MaxValue)]
        [int]$Last
    )

    $historyPath = Get-DellPSUpdatePath -Name History
    if (-not (Test-Path -LiteralPath $historyPath -PathType Container)) { return }

    $records = [System.Collections.Generic.List[object]]::new()
    foreach ($historyFile in (Get-ChildItem -LiteralPath $historyPath -Filter 'InstallHist-*.json' -File -ErrorAction Stop)) {
        try {
            $fileRecords = @(Get-Content -LiteralPath $historyFile.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop)
            foreach ($record in $fileRecords) {
                $timestamp = [datetime]::MinValue
                if (-not [datetime]::TryParse([string]$record.Timestamp, [ref]$timestamp)) {
                    throw "Record has an invalid Timestamp value."
                }
                $record.Timestamp = $timestamp
                $record.PSObject.TypeNames.Insert(0, 'Dell.Client.Update.DellUpdateHistory')
                $records.Add($record)
            }
        }
        catch {
            Write-Warning "Could not read Dell update history file '$($historyFile.FullName)': $($_.Exception.Message)"
        }
    }

    $results = @($records | Sort-Object Timestamp -Descending)
    if ($PSBoundParameters.ContainsKey('Status')) {
        $results = @($results | Where-Object { $_.Status -in $Status })
    }
    if ($PSBoundParameters.ContainsKey('Category')) {
        $results = @($results | Where-Object { $_.Category -in $Category })
    }
    if ($PSBoundParameters.ContainsKey('Type')) {
        $results = @($results | Where-Object { $_.Type -in $Type })
    }
    if ($PSBoundParameters.ContainsKey('Last')) {
        $results = @($results | Select-Object -First $Last)
    }
    $results
}