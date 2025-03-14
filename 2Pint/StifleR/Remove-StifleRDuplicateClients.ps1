<#

.SYNOPSIS
Maintenance task that removes duplicate clients from the StifleR DB based on name and MAC address

.DESCRIPTION
See above :)
Outputs results to a logfile

.REQUIREMENTS
Run on the StifleR Server

.USAGE
Set the path to the logfile
.\Remove-StifleRDuplicates.ps1

.NOTES
AUTHOR: 2Pint Software
EMAIL: support@2pintsoftware.com
VERSION: 25.02.14
CHANGE LOG:
25.02.13 : Initial version of script
25.02.14  : Added Group-ObjectCount function, replaced log function, removed redundant logging info

.LINK
https://2pintsoftware.com

#>

# Change this variable to match your environment!
$LogPath = "$ENV:ProgramData\2Pint Software\StifleR Maintenance Logs"

# Ok, lets do this...
$Date = $(get-date -f MMddyyyy_hhmmss)
$Logfile = "$LogPath\Remove-StifleRDuplicates_$Date.log"

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

function Group-ObjectCount {
    param (
        [string[]]
        $Property,
        [switch]
        $NoElement
    )
    begin {
        # create an empty hashtable
        $hashtable = @{}
    }
    process {
        # create a key based on the submitted properties, and turn
        # it into a string
        $key = $(foreach($prop in $Property) { $_.$prop }) -join ','
        # check to see if the key is present already
        if ($hashtable.ContainsKey($key) -eq $false) {
            # add an empty array list
            $hashtable[$key] = [Collections.Arraylist]@()
        }
        # add element to appropriate array list:
        $null = $hashtable[$key].Add($_)
    }
    end {
        # for each key in the hashtable,
        foreach($key in $hashtable.Keys) {
            if ($NoElement) {
                # return one object with the key name and the number
                # of elements collected by it:
                [PSCustomObject]@{
                    Count = $hashtable[$key].Count
                    Name = $key
                }
            } else {
                # include the content
                [PSCustomObject]@{
                    Count = $hashtable[$key].Count
                    Name = $key
                    Group = $hashtable[$key]
                }
            }
        }
    }
}

Write-Log "Starting Remove-StifleRDuplicates"

$Clients = Get-CimInstance -Namespace root\StifleR -Class "Clients"
Write-Log "Found $($Clients.Count) clients"

#Duplicates based on Computer Name
$duplicates = $Clients | Group-ObjectCount -Property ComputerName | Where-Object { $_.Count -gt 1 }

if ($($duplicates.Count) -eq 0) {
    Write-Log "Found $($duplicates.Count) clients based on duplicate names - no clients to clean up"
} else {
    Write-Log "---------------------------------------------------------------"
    Write-Log "Removing StifleR Clients based on Duplicate Names"
    Write-Log "Found $($duplicates.Count) clients with one or more duplicate names"
    Write-Log "---------------------------------------------------------------"
    Write-Log "Enumeration completed."
    Write-Log "About to remove Duplicate Clients from the DB based on Machine Name"

    $ClientsToRemove = @()

    ForEach ($duplicate in $duplicates) {
        $LatestDateOnline = $duplicate.Group.DateOnline | Sort-Object | Select-Object -Last 1
        $LatestCheckinClient = $duplicate.Group | Where-Object {$_.DateOnline -eq $LatestDateOnline}
        Write-Log "Keeping Duplicate Client With Latest Checkin: $($LatestCheckinClient.ComputerName), Last Checkin: $LatestDateOnline"
        foreach ($Client in $duplicate.Group) {
            $ClientName = $Client.ComputerName
            $LastCheckin = $Client.DateOnline
            if ($LastCheckin -ne $LatestDateOnline) {
                $ClientsToRemove += $ClientName
                Try {
                    Invoke-CimMethod -InputObject $Client -MethodName RemoveFromDB | Out-Null
                } Catch {
                    Write-Log "  Failed to remove Client $ClientName, $LastCheckin"
                    Write-Log $_.Exception
                    throw  $_.Exception
                }
                Write-Log "  Removed Client from DB Name: $ClientName, Last Checkin: $LastCheckin"
            }
        }
    }

    Write-Log "Removed $($ClientsToRemove.count) Clients"
    Write-Host "Removed $($ClientsToRemove.count) Clients" -ForegroundColor Green
    Write-Log ""
}

#Duplicates based on MAC Address
$Clients = Get-CimInstance -Namespace root\StifleR -Class "Clients"
$duplicates = $Clients | Group-ObjectCount -Property MacAddress | Where-Object { $_.Count -gt 1 }

if ($($duplicates.Count) -eq 0) {
    Write-Log "Found $($duplicates.Count) clients based on duplicate MAC address - no clients to clean up"
} else {
    Write-Log "---------------------------------------------------------------"
    Write-Log "Removing StifleR Clients based on Duplicate MAC Addresses"
    Write-Log "Found $($duplicates.Count) clients with one or more duplicate MAC addresses"
    Write-Log "---------------------------------------------------------------"
    Write-Log "About to remove Duplicate Clients from the DB based on MAC Address"

    $ClientsToRemove = @()

    ForEach ($duplicate in $duplicates) {
        $LatestDateOnline = $duplicate.Group.DateOnline | Sort-Object | Select-Object -Last 1
        $LatestCheckinClient = $duplicate.Group | Where-Object {$_.DateOnline -eq $LatestDateOnline}
        Write-Log "Keeping Duplicate Client With Latest Checkin: $($LatestCheckinClient.ComputerName), Last Checkin: $LatestDateOnline| $($LatestCheckinClient.MacAddress)"
        foreach ($Client in $duplicate.Group) {
            $ClientName = $Client.ComputerName
            $LastCheckin = $Client.DateOnline
            if ($LastCheckin -ne $LatestDateOnline) {
                $ClientsToRemove += $ClientName
                Try {
                    Invoke-CimMethod -InputObject $Client -MethodName RemoveFromDB | Out-Null
                } Catch {
                    Write-Log "  Failed to remove Client $ClientName, $LastCheckin"
                    Write-Log $_.Exception
                    throw  $_.Exception
                }
                Write-Log "  Removed Client from DB Name: $ClientName, Last Checkin: $LastCheckin | $($LatestCheckinClient.MacAddress)"
            }
        }
    }

    Write-Log "Removed $($ClientsToRemove.count) Clients"
    Write-Host "Removed $($ClientsToRemove.count) Clients" -ForegroundColor Green
}

Write-Log "Remove-StifleRDuplicates all done, over and out!"