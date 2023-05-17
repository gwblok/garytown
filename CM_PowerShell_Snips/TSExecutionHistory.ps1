# 3 Functions

#Remove Execution History
Function Remove-TSExecutionHistory {
    [cmdletbinding()]
    param ([string] $TSPackageID)
    $ExecutionHistoryPath = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System\$($TSPackageID)"
    if (Test-Path -Path $ExecutionHistoryPath)
    {write-host "Found History for $($TSPackageID), Deleting now" -ForegroundColor Yellow ;  Remove-Item -Path HKLM:\SOFTWARE\Microsoft\SMS\'Mobile Client\Software Distribution\Execution History'\System\$($TSPackageID) -Recurse -verbose} Else {write-host "No History for $($TSPackageID)" -ForegroundColor Yellow}
    }
#Show Execution History for Production POST TS Success
Function Get-TSExecutionHistory {
    [cmdletbinding()]
    param ([string] $TSPackageID)
    $ExecutionHistoryPath = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System\$($TSPackageID)"
    if (Test-Path -Path $ExecutionHistoryPath)
        {
        $ExcutionHistory = get-item -Path $ExecutionHistoryPath
        $ExcutionHistorySubKey = get-item -Path $ExecutionHistoryPath\$($ExcutionHistory.GetSubKeyNames())
        $ExcutionHistoryProdTS = ($ExcutionHistorySubKey.GetValue("_State"))
        ($ExcutionHistorySubKey.GetValue("_State"))
        }
    else {write-output "No History"}
    }
# Set the Execution to Failure or Success
Function Set-TSExecutionHistory {
    [cmdletbinding()]
    param ([string] $TSPackageID, [ValidateSet("Failure", "Success")][string] $HistoryStatus)
    #Set Execution History for Production TS Success
    $ExecutionHistoryPath = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System\$($TSPackageID)"
    $ExcutionHistory = get-item -Path $ExecutionHistoryPath
    $ExcutionHistorySubKey = get-item -Path $ExecutionHistoryPath\$($ExcutionHistory.GetSubKeyNames())
    Set-ItemProperty -Path $ExecutionHistoryPath\$($ExcutionHistory.GetSubKeyNames()) -Name "_State" -Value $HistoryStatus
    }
