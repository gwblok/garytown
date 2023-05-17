#Trigger Scheduled Task
# Gary Blok - GARYTOWN.COM

[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true)][string]$TaskName = "Microsoft Compatibility Appraiser"
	    )

$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($Task -ne $null){
    Write-Output "Triggering Task $($Task.TaskName)"
    Start-ScheduledTask -InputObject $Task
}
else {
    Write-Output "No Task found with name: $TaskName"
}
