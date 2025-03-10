# Get the event log entries for system reboots
$rebootEvents = Get-WinEvent -LogName System -MaxEvents 20 -FilterXPath "*[System[EventID=6005]]" | Select-Object -Property TimeCreated
