#This script is for generating a JSON file from a CSV file containing error codes and their descriptions.
# https://smsagent.blog/2015/07/06/create-a-database-of-error-codes-and-descriptions-for-windows-and-configmgr/
#$ErrorCodeDB = Get-Content -path "C:\Users\GaryBlok\Downloads\errorcodes_final.csv" | ConvertFrom-Csv
#$ErrorCodeDB | ConvertTo-Json | Out-File -Path 'C:\Users\GaryBlok\OneDrive - garytown\GitHub\garytown\CodeDependancies\errorcodes.json' -Force

#$DatabaseURL = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CodeDependancies/errorcodes.json'
#$ErrorCodeDB  = (Invoke-WebRequest -URI $DatabaseURL).content | ConvertFrom-Json
#$ErrorCodeDB.count
#$ErrorCodeDB | Select-Object -First 10

Function Get-ErrorCodeDBInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$ErrorCode,
        [string]$ErrorCodeHex,
        [string]$ErrorCodeSignedInt,
        [string]$ErrorCodeUnignedInt
    )
    if ($null -eq $ErrorCodeHex -and $null -eq $ErrorCodeSignedInt -and $null -eq $ErrorCodeUnignedInt) {
        Write-Output "No Error Code provided."
        return
    }
    #Load Data
    $DatabaseURL = 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/CodeDependancies/errorcodes.json'
    try {$ErrorCodeDB  = (Invoke-WebRequest -URI $DatabaseURL).content | ConvertFrom-Json}
    catch {
        Write-Error "Error retrieving error code database: $_"
        return
    }
    if ($ErrorCode){
        if ($ErrorCode -match '0x') {
            $ErrorCodeHex = $ErrorCode
        }
        elseif ($ErrorCode -like '-*') {
            $ErrorCodeSignedInt = $ErrorCode 
        }
        elseif ($ErrorCode -like '*') {
            $ErrorCodeUnignedInt = $ErrorCode
        }
        else {
            $ErrorCode = 'Unknown'
        }
        Write-Output "Error Code: $ErrorCode"
    }
    if ($ErrorCodeHex){
        $ErrorCodeDB | Where-Object {$_.Hexadecimal -eq $ErrorCodeHex}
    }
    if ($ErrorCodeSignedInt){
        $ErrorCodeDB | Where-Object {$_.SignedInteger -eq $ErrorCodeSignedInt}
    }
    if ($ErrorCodeUnignedInt){
        $ErrorCodeDB | Where-Object {$_.UnsignedInteger -eq $ErrorCodeUnignedInt}
    }
}   
function Get-LastScheduledTaskResult {
    param (
        [string]$TaskName
    )

    try {
        $Task = Get-ScheduledTask -TaskName $TaskName
        if ($null -eq $Task) {
            Write-Output "Scheduled Task '$TaskName' not found."
            return $null
        }

        $TaskHistory = Get-ScheduledTaskInfo -InputObject $Task
        $LastRunTime = $TaskHistory.LastRunTime
        $LastTaskResult = $TaskHistory.LastTaskResult
        $LastTaskResultDescription = (Get-ErrorCodeDBInfo -ErrorCodeUnignedInt $LastTaskResult).ErrorDescription
        [PSCustomObject]@{
            TaskName       = $TaskName
            LastRunTime    = $LastRunTime
            LastTaskResult = $LastTaskResult
            LastTaskDescription = $LastTaskResultDescription
        }
    }
    catch {
        Write-Error "Error retrieving scheduled task result: $_"
    }
}