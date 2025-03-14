<#
.SYNOPSIS
    Maintenance task that removes 'stale' clients from the StifleR DB  - that haven't checked in for xx days
.DESCRIPTION
    See above :)
    Outputs results to a logfile
.REQUIREMENTS
    Run on the StifleR Server
.USAGE
    Set the path to the logfile
    .\Remove-StifleRStaleClients.ps1
.NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 25.02.14
    CHANGE LOG:
    25.02.13  : Initial version of script
    25.02.14  : Replaced log function, removed redundant logging info
.LINK
    https://2pintsoftware.com
#>

# Change these two variables to match your environment!
$LogPath = "$ENV:ProgramData\2Pint Software\StifleR Maintenance Logs"
$NumberOfDays = 30

# Ok, lets do this...
$Date = $(get-date -f MMddyyyy_hhmmss)
$Logfile = "$LogPath\Remove-StifleRStaleClients_$Date.log"

Function Write-Log {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        $Message,
        [Parameter(Mandatory=$false)]
        $ErrorMessage,
        [Parameter(Mandatory=$false)]
        $Component = "Script",
        [Parameter(Mandatory=$false)]
        [int]$Type,
        [Parameter(Mandatory=$false)]
        $LogFile = $LogFile
    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
    $Time = Get-Date -Format "HH:mm:ss.ffffff"
    $Date = Get-Date -Format "MM-dd-yyyy"
    if ($ErrorMessage -ne $null) {$Type = 3}
    if ($Component -eq $null) {$Component = " "}
    if ($Type -eq $null) {$Type = 1}
    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
    $LogMessage.Replace("`0","") | Out-File -Append -Encoding UTF8 -FilePath $LogFile
}

Write-Log "Starting Client Cleanup."

$Clients = Get-CimInstance -Namespace root\StifleR -Class "Clients"
$TotalClients = ($Clients | Measure-Object).Count
Write-Log "There are currently $TotalClients Clients in the DB."

$DateFilter = ([wmi]"").ConvertFromDateTime((get-date).AddDays(-$NumberOfDays))
$ClientsToRemove = Get-CimInstance -Namespace root\StifleR -Class "Clients" -Filter "DateOnline < '$DateFilter'"
$TotalToRemove = ($ClientsToRemove | Measure-Object).Count

if ($TotalToRemove -eq 0) {
    Write-Log "Found $TotalToRemove clients more than $NumberOfDays old - no clients to clean up"
} else {
    Write-Log "---------------------------------------------------------------"
    Write-Log "Removing StifleR Clients not reporting in the last $NumberOfDays"
    Write-Log "Found $TotalToRemove clients"
    Write-Log "---------------------------------------------------------------"

    ForEach ($Client in $ClientsToRemove) {
        $ClientName = $Client.ComputerName
        $LastCheckin = $Client.DateOnline

        Try {
            Invoke-CimMethod -InputObject $Client -MethodName RemoveFromDB | Out-Null
        } Catch {
            Write-Log "Failed to remove Client $ClientName, $LastCheckin"
            Write-Log $_.Exception
            throw  $_.Exception
        }

        Write-Log "Removed Client from DB Name: $ClientName, Last Checkin: $LastCheckin"
    }

    Write-Log "Removed $TotalToRemove Clients"
}

Write-Log "Remove-StifleRStaleClients all done, over and out!"