<#
.SYNOPSIS
    This script will create the folders, scripts, and tasks for performing basic StifleR maintenance.

.DESCRIPTION
    The script sets up the necessary directory structure, places the required scripts, and creates scheduled tasks to automate StifleR maintenance tasks.

.AUTHOR
    2Pint Software

.VERSION
    25.2.14
    25.2.25 - Added Check to ensure it's running as Admin | added note about gMSA account, if you aren't using one, just change it to SYSTEM and update it manually after tasks are created.
#>

# Check for elevation (admin rights)
If ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    # All OK, script is running with admin rights
}
else
{
    Write-Warning "This script needs to be run with admin rights..."
    Exit 1
}

#Please ensure that the following folders exist before running this script, adjust the paths as necessary
#$StifleRParentFolder = "C:\Program Files\2Pint Software"
$StifleRInstallFolder = (Get-ItemPropertyValue -Path HKLM:\SYSTEM\CurrentControlSet\Services\StifleRServer -Name ImagePath | Split-Path -Parent).Replace('"','')
$StifleRParentFolder = $StifleRInstallFolder | split-Path -Parent
$gMSAAccountName = 'gMSAStifleR$'  #If you don't have a gMSA account, I'd recommend using "SYSTEM" then going in manually and changing it to the account you want to use.

#Create Folder Structure
$StifleRMaintenanceFolder = "$StifleRParentFolder\StifleR Maintenance"
$StifleRMaintenanceLogFolder = "$ENV:ProgramData\2Pint Software\StifleR Maintenance Logs"

# Create the StifleR Maintenance folder if it doesn't exist
if (-Not (Test-Path -Path $StifleRMaintenanceFolder)) {
    New-Item -ItemType Directory -Path $StifleRMaintenanceFolder -Force | Out-Null
}

# Create the StifleR Maintenance Log folder if it doesn't exist
if (-Not (Test-Path -Path $StifleRMaintenanceLogFolder)) {
    New-Item -ItemType Directory -Path $StifleRMaintenanceLogFolder -Force | Out-Null
}

function Test-ScheduledTaskExists {
    param (
        [string]$TaskName
    )

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        return $true
    } else {
        return $false
    }
}

#Creates Scheduled Task in 2Pint Software Folder in Scheduled Tasks
function New-StifleRMaintenanceTask {
    param (
        [string]$TaskName = "StifleRMaintenance",
        [string]$ScriptPath = "C:\Program Files\2Pint Software\StifleR Maintenance\script.ps1",
        [string]$gMSAAccountName = "gMSA_StifleRMaintenance",
        [string]$timeofday = "2:00AM"
    )
    
    if (Test-ScheduledTaskExists -TaskName $TaskName) {
        Write-Host "Scheduled task '$TaskName' already exists."
        return
    }
    
    # Define the name of the new folder
    $folderName = "2Pint Software"

    # Create a new scheduled task folder
    $taskService = New-Object -ComObject Schedule.Service
    $taskService.Connect()
    try {
        $taskService.GetFolder("$folderName") | Out-Null
    }
    catch {
        $rootFolder = $taskService.GetFolder("\")
        $rootFolder.CreateFolder($folderName) | Out-Null
    }
    
    # Define the action for the scheduled task
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    # Define the trigger for the scheduled task (daily at 2 AM)
    $trigger = New-ScheduledTaskTrigger -Daily -At $timeofday
    # Define the principal for the scheduled task
    $principal = New-ScheduledTaskPrincipal -UserId $gMSAAccountName -LogonType Password -RunLevel Highest
    # Register the scheduled task
    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $TaskName -Description "Daily StifleR Maintenance Task" -TaskPath "\2Pint Software" -Force -Principal $principal
}


# Example usage
#New-StifleRMaintenanceTask

#Create Maintenance Scripts - Clean up Stale Objects
$RemoveStifleRStaleClientsScriptContent = @'
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
'@

$RemoveStifleRStaleClientsScriptContent | Out-File -FilePath "$StifleRMaintenanceFolder\Remove-StifleRStaleClients.ps1" -Force
New-StifleRMaintenanceTask -TaskName "Remove StifleR Stale Clients" -ScriptPath "$StifleRMaintenanceFolder\Remove-StifleRStaleClients.ps1" -gMSAAccountName $gMSAAccountName -timeofday "3:00AM"


#Create Maintenance Scripts - Clean up Duplicate Objects
$RemoveStifleRDuplicateClientsScriptContent = @'
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
<# This can cause issue if you have a VPN Adapter that all use the same MAC Address
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
#>
Write-Log "Remove-StifleRDuplicates all done, over and out!"
'@

$RemoveStifleRDuplicateClientsScriptContent | Out-File -FilePath "$StifleRMaintenanceFolder\Remove-StifleRDuplicates.ps1" -Force
New-StifleRMaintenanceTask -TaskName "Remove StifleR Duplicate Clients" -ScriptPath "$StifleRMaintenanceFolder\Remove-StifleRDuplicates.ps1" -gMSAAccountName $gMSAAccountName -timeofday "4:00AM"