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
   .\ClientDBCleanup.ps1

   .NOTES
    AUTHOR: 2Pint Software
    EMAIL: support@2pintsoftware.com
    VERSION: 24.10.2.1
        
    CHANGE LOG: 
    24.10.2.1 : Initial version of script 


   .LINK
    https://2pintsoftware.com

#>

# Change these two variables to match your environment!
$LogPath = "C:\ProgramData\2Pint Software\Maintenance\Logs\ClientDBCleanup" 


# Ok, lets do this...
$Date = $(get-date -f MMddyyyy_hhmmss)
$Logfile = "$LogPath\ClientDBCleanupRemoveDups_$Date.log"

Function Write-Log{
	param (
    [Parameter(Mandatory = $true)]
    [string]$Message
   )

   $TimeGenerated = $(Get-Date -UFormat "%D %T")
   $Line = "$TimeGenerated : $Message"
   Add-Content -Value $Line -Path $LogFile -Encoding Ascii

}

Write-Log "Starting Client Cleanup." 

$Clients = Get-CimInstance -Namespace root\StifleR -Class "Clients"
$TotalClients = ($Clients | Measure-Object).Count
Write-Log "There are currently $TotalClients Clients in the DB." 

Write-Log "About to enumerate clients not being online the past $NumberOfDays days." 
$DateFilter = ([wmi]"").ConvertFromDateTime((get-date).AddDays(-$NumberOfDays))

#Duplicates based on Computer Name
$duplicates = $Clients | Group-Object -Property ComputerName | Where-Object { $_.Count -gt 1 }

Write-Host "---------------------------------------------------------------" -ForegroundColor Green
Write-Host "Removing StifleR Clients based on Duplicate Names" -ForegroundColor Green
Write-Host "---------------------------------------------------------------" -ForegroundColor Green
Write-Log "Enumeration completed."

Write-Log "About to remove Duplicate Clients from the DB based on Machine Name" 

$ClientsToRemove = @()

ForEach ($duplicate in $duplicates){
    

    $LatestDateOnline = $duplicate.Group.DateOnline | Sort-Object | Select-Object -Last 1
    $LatestCheckinClient = $duplicate.Group | Where-Object {$_.DateOnline -eq $LatestDateOnline}
    Write-Host "Keeping Duplicate Client With Latest Checkin: $($LatestCheckinClient.ComputerName), Last Checkin: $LatestDateOnline" -ForegroundColor Cyan
    Write-Log "Keeping Duplicate Client With Latest Checkin: $($LatestCheckinClient.ComputerName), Last Checkin: $LatestDateOnline" 
    foreach ($Client in $duplicate.Group){
        $ClientName = $Client.ComputerName
        $LastCheckin = $Client.DateOnline
        if ($LastCheckin -ne $LatestDateOnline){
            $ClientsToRemove += $Client
            Write-Log " Removing Duplicate Client wtih older Checkin: $ClientName, Last Checkin: $LastCheckin" 

            Try{
                Write-Host " Removing Duplicate Client wtih older Checkin: $ClientName, Last Checkin: $LastCheckin" -ForegroundColor Yellow
                Invoke-CimMethod -InputObject $Client -MethodName RemoveFromDB | Out-Null
            }
            Catch{
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
Write-Host ""

Write-Host "---------------------------------------------------------------" -ForegroundColor Green
Write-Host "Removing StifleR Clients based on Duplicate Mac Addresses" -ForegroundColor Green
Write-Host "---------------------------------------------------------------" -ForegroundColor Green

#Duplicates based on Computer Name
$Clients = Get-CimInstance -Namespace root\StifleR -Class "Clients"
$duplicates = $Clients | Group-Object -Property MacAddress | Where-Object { $_.Count -gt 1 }

Write-Log "About to remove Duplicate Clients from the DB based on MAC Address" 

$ClientsToRemove = @()

ForEach ($duplicate in $duplicates){
    

    $LatestDateOnline = $duplicate.Group.DateOnline | Sort-Object | Select-Object -Last 1
    $LatestCheckinClient = $duplicate.Group | Where-Object {$_.DateOnline -eq $LatestDateOnline}
    Write-Host "Keeping Duplicate Client With Latest Checkin: $($LatestCheckinClient.ComputerName), Last Checkin: $LatestDateOnline | $($LatestCheckinClient.MacAddress)" -ForegroundColor Cyan
    Write-Log "Keeping Duplicate Client With Latest Checkin: $($LatestCheckinClient.ComputerName), Last Checkin: $LatestDateOnline| $($LatestCheckinClient.MacAddress)" 
    foreach ($Client in $duplicate.Group){
        $ClientName = $Client.ComputerName
        $LastCheckin = $Client.DateOnline
        if ($LastCheckin -ne $LatestDateOnline){
            $ClientsToRemove += $Client
            Write-Log " Removing Duplicate Client wtih older Checkin: $ClientName, Last Checkin: $LastCheckin| $($LatestCheckinClient.MacAddress)" 

            Try{
                Write-Host " Removing Duplicate Client wtih older Checkin: $ClientName, Last Checkin: $LastCheckin | $($LatestCheckinClient.MacAddress)" -ForegroundColor Yellow
                Invoke-CimMethod -InputObject $Client -MethodName RemoveFromDB | Out-Null
            }
            Catch{
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
