# Get the event log entries for system reboots
Function Get-RebootEvents {
    [CmdletBinding()]
    param (
        [int]$MaxEvents = 20
    )
    # Get the last 20 reboot events (Event ID 6005) from the System log
    $rebootEvents = Get-WinEvent -LogName System -MaxEvents $MaxEvents -FilterXPath "*[System[EventID=6005]]" | Select-Object -Property TimeCreated
    return $rebootEvents
}

