###################################################################################################################
##                           PowerShell script to test for valid download URLs for the                           ##
##                            Microsoft Windows Compatibility Appraiser database files                           ##
###################################################################################################################

# This script is based on the work of Gary Blok
# It makes use of parallel processing available in PowerShell Core to improve execution speed
# Run on a well-spec'd multi-core machine for best performance
# To avoid port exhaustion it is recommended to set the following registry value and reboot first: HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters > TcpTimedWaitDelay [DWORD] > 2
# > This will reduce the time a connection is in the 'TIME_WAIT' state to 2 seconds before it removes the connection, freeing the port
# > Use '(netstat -ano | findstr ":80").Count' to find the number of ports currently connected on http (80)
# Expected run time could be around 10-15 minutes
#Requires -Version 7

#region ----------------------------------------------- Parameters ------------------------------------------------
# The directory to output the resulting json file to
$OutputDirectory = "D:\SafeGuard\AppraiserDatabase"
# The first date you wish to start searching for valid cab file URLs from
# 20200109 is currently the date of the earliest downloadable cab
$StartDate = "20200109" # yyyyMMdd
# Maximum number of parallel threads. The optimal number depends on available system resources
$ThrottleLimit = 100
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Prepare ---------------------------------------------------
# Create the output directory if needed
try {[void][IO.Directory]::CreateDirectory($OutputDirectory)}
catch {throw}

# Check if TcpTimedWaitDelay has been set to the recommended value
$TcpTimedWaitDelay = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name TcpTimedWaitDelay -ErrorAction SilentlyContinue | Select -ExpandProperty TcpTimedWaitDelay
if ($null -eq $TcpTimedWaitDelay -or $TcpTimedWaitDelay -ne 2)
{
    Write-Warning "To avoid port exhaustion it is recommended to set the following registry value and reboot: HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters > TcpTimedWaitDelay [DWORD] > 2"
}
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Prepare potential URL list --------------------------------
# Set cab date values
[int]$URLYear = $StartDate.Substring(0,4)
[int]$URLMonth = $StartDate.Substring(4,2)
[int]$URLDay = $StartDate.Substring(6,2)
[int]$URLExtra1 = 1
[int]$URLExtra2 = 0

[int]$MaxDay = 31
[int]$MaxMonth = 12
[int]$MaxExtra1 = 13
[int]$MaxExtra2 = 5

$FullDate = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)"
$StartURL = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)_$('{0:d2}' -f [int]$URLExtra1)_$('{0:d2}' -f [int]$URLExtra2)"
$DateStop = Get-Date -Format yyyy_MM_dd

$PotentialURLList = [Collections.Generic.List[PSCustomObject]]::new()

do {
    $URLExtra2++
    $StartURL = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)_$('{0:d2}' -f [int]$URLExtra1)_$('{0:d2}' -f [int]$URLExtra2)"
    if ($URLExtra2 -gt $MaxExtra2){
        $URLExtra2 = 1
        $URLExtra1++
        $StartURL = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)_$('{0:d2}' -f [int]$URLExtra1)_$('{0:d2}' -f [int]$URLExtra2)"
        if ($URLExtra1 -gt $MaxExtra1){
            $URLExtra1 = 1
            $URLDay++
            $StartURL = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)_$('{0:d2}' -f [int]$URLExtra1)_$('{0:d2}' -f [int]$URLExtra2)"
            if ($URLDay -gt $MaxDay){
                $URLDay = 1
                $URLMonth++
                $StartURL = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)_$('{0:d2}' -f [int]$URLExtra1)_$('{0:d2}' -f [int]$URLExtra2)"
                if ($URLMonth -gt $MaxMonth){
                    $URLMonth = 1
                    $URLYear++
                    $StartURL = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)_$('{0:d2}' -f [int]$URLExtra1)_$('{0:d2}' -f [int]$URLExtra2)"
                }
            }
        }
    }
    $PotentialURLList.Add([PSCustomObject]@{ 
        ALTERNATEDATALINK = "http://adl.windows.com/appraiseradl/$($StartURL)_AMD64.cab"
        ALTERNATEDATAVERSION = "$($StartURL.replace('_',''))" 
    })
    $FullDate = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)"
} 
while ($FullDate -lt $DateStop)
Write-Output "Prepared $($PotentialURLList.Count) potential URLs to test"
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Test each URL ---------------------------------------------
Write-Output "Testing each URL...this will take some time"
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$ValidURLs = [Collections.Generic.List[PSCustomObject]]::new()
# Use implicit output to avoid the need for a thread-safe collection in this case
$ValidURLs.Add(($PotentialURLList | ForEach-Object -Parallel {
    $PotentialURL = $_
    $URL = $PotentialURL.ALTERNATEDATALINK
    $HttpClient = [System.Net.Http.HttpClient]::new()
    try 
    {
        $Response = $HttpClient.Send([System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $URL))
        if ($Response.IsSuccessStatusCode)
        {
            return $PotentialURL
        }
    }
    catch 
    {
        # try again with a delay
        Start-Sleep -Seconds 3
        $Response = $HttpClient.Send([System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Head, $URL))
        if ($Response.IsSuccessStatusCode)
        {
            return $PotentialURL
        }
        return
    }
    $HttpClient.Dispose()
} -ThrottleLimit $ThrottleLimit))

$ValidURLs[0].Count #438 #413 #391 #446 #456 #462 # 462 #462
Write-Output "Discovered $($ValidURLs[0].Count) valid URLs"
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Export Data ------------------------------------------------
# Output the data to a JSON file
try 
{
    [IO.File]::WriteAllLines("$OutputDirectory\SafeGuardHoldURLs.json", ($ValidURLs[0] | Sort -Property ALTERNATEDATAVERSION  | ConvertTo-Json), [Text.UTF8Encoding]::new($False))
    Write-Output "Valid URLs exported to $OutputDirectory\SafeGuardHoldURLs.json."
}
catch 
{
    throw $_.Exception.Message
}
$Stopwatch.Stop()
Write-Output "Execution complete in $($Stopwatch.Elapsed.Minutes) minutes and $($Stopwatch.Elapsed.Seconds) seconds." #15 #18 #12 #12 #13 #15 #12 #12 #13
#endregion --------------------------------------------------------------------------------------------------------
