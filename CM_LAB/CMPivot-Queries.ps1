#Good List of Examples:
# https://github.com/svschmit/CMPivot-Queries/blob/main/CMPivot%20Queries.md


#Get Info about a computer with a specific event ID
ComputerSystemProduct
| join (
EventLog('System',1d)
| where EventID == 6013
| order by DateTime desc
| take 1
)

#Similar but different
WinEvent('Microsoft-Windows-NlaSvc/Operational', 1d) | summarize countif( (ID == 4205) ) by Device | where (countif_ > 0) | join ComputerSystemProduct 

