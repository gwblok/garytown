<# Gary Blok @gwblok GARYTOWN.COM
Based on https://github.com/AdamGrossTX/FU.WhyAmIBlocked/blob/master/Get-SafeguardHoldInfo.ps1 by Adam Gross

Modify Export-FUXMLFromSDB.ps1 file, update this line (should be line 96)
$SDBFiles = Get-ChildItem -Path "$($AppraiserDataPath)\*.sdb" -ErrorAction SilentlyContinue
to this:
$SDBFiles = Get-ChildItem -Path "$($AppraiserDataPath)\*.sdb" -Recurse | Where-Object {$_.Name -notmatch "backup"} -ErrorAction SilentlyContinue
#>

<#
requires -modules FU.WhyAmIBlocked - Modify based on notes above.

requires module OSD for the function Test-WebConnection - eventually I should remove this requirement.

THIS IS NO LONGER RELEVANT, but I'm keeping it here for reference.
        Run CMPivot to pull this info from the registry & Add to "SettingsTable" anything that is missing.
        I typically copy and paste the results from CMPivot into Excel only keeping the two columns "ALTERNATEDATALINK & ALTERNATEDATAVERSION"
        While in Excel, delete duplicates (Data Tab), then Sort on Version
        I then compare the item in Excel with the Settings Table and add anything new to the Settings Table.
        If you find anything I don't have, please contact me on Twitter @gwblok or GMAIL - garywblok and send me the ones I don't have listed below.


        #>
        #CMPIVOT Query
        <#
        Registry('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators\*') | where Property == 'GatedBlockId' and Value != '' and Value != 'None'
        | join kind=inner (
                Registry('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OneSettings\compat\appraiser\*') 
                | where Property == 'ALTERNATEDATALINK')
        | join kind=inner (
                Registry('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OneSettings\compat\appraiser\*') 
                | where Property == 'ALTERNATEDATAVERSION')
        | project Device,GatedBlockID=Value,ALTERNATEDATALINK=Value1,ALTERNATEDATAVERSION=Value2
        >


<# Updates
22.10.28 - Added more rows to the Lookup.
22.11.22 - Added more rows to the Lookup
22.11.22 - Rewrote process to be more efficent. 
- Removed Unused function
- Removed function and just incorporated the code into the script
- Skips Items that were already completed in a previous run
    - Skips downloading and extracting the XML, still parses XML and adds info to the Database.
23.11.20 - Added more rows for Lookup
24.3.4 - Added more rows for Lookup
24.3.4 - Added count per row as verification it is doing something. :-)
24.6.3 - Modified FU.WhyAmIBlocked Function Export-FUXMLFromSDB.ps1 to ignore SDB files named backup, this resolved errors I was seeing
- Also updated script to work on first pass correctly
- Added about 5 more lines in the Settings table.
24.7.23 - Added 4 lines thanks to @PatchThatBadBoi
24.10.24 - Added 2 lines thanks to @marceldk
24.10.30 - reimagine of the idea.  Wrote a block of code that tests all URLS starting Jan 1 2020, to current date.  This will find all the URLs that are valid.  This will be used to update the SettingsTable.  
- This is commented out by default, as it takes a long time to run.  I will run this once a month to update the SettingsTable.
- This data has been exported and uploaded to the GitHub Repo.  This will be used to update the SettingsTable.
- Still need to write code to start with the last date in the SettingsTable and go to current date to find any new URLs.
    - This will be a future update. | Get Settings TABLE JSON from GitHub, get latest date in the table, start from that date to current date, find any new URLs, add to SettingsTable, export to GitHub.
#>


<# No longer using this method, as it required manual updating as new things were found.
$SettingsTable = @(
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_02_20_06_05_AMD64.cab'; ALTERNATEDATAVERSION = '2360'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_05_07_07_02_AMD64.cab'; ALTERNATEDATAVERSION = '2369'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_05_28_05_02_AMD64.cab'; ALTERNATEDATAVERSION = '2372'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_06_17_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '2375'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_06_26_06_02_AMD64.cab'; ALTERNATEDATAVERSION = '2376'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_07_09_05_02_AMD64.cab'; ALTERNATEDATAVERSION = '2377'} # From Robert Stein (@RaslDasl)
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_07_23_05_02_AMD64.cab'; ALTERNATEDATAVERSION = '2379'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_10_01_04_02_AMD64.cab'; ALTERNATEDATAVERSION = '2387'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_10_26_05_02_AMD64.cab'; ALTERNATEDATAVERSION = '2390'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_11_05_05_02_AMD64.cab'; ALTERNATEDATAVERSION = '2391'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_11_24_07_02_AMD64.cab'; ALTERNATEDATAVERSION = '2393'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_12_10_07_02_AMD64.cab'; ALTERNATEDATAVERSION = '2394'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_12_17_05_02_AMD64.cab'; ALTERNATEDATAVERSION = '2395'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_01_07_05_02_AMD64.cab'; ALTERNATEDATAVERSION = '2396'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_01_14_02_02_AMD64.cab'; ALTERNATEDATAVERSION = '2397'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_01_28_04_02_AMD64.cab'; ALTERNATEDATAVERSION = '2398'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_02_12_02_02_AMD64.cab'; ALTERNATEDATAVERSION = '2399'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_03_04_04_02_AMD64.cab'; ALTERNATEDATAVERSION = '2400'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_03_11_04_02_AMD64.cab'; ALTERNATEDATAVERSION = '2401'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_12_16_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2430'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_11_24_07_03_AMD64.cab'; ALTERNATEDATAVERSION = '2459'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_12_10_07_03_AMD64.cab'; ALTERNATEDATAVERSION = '2460'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2020_12_17_05_03_AMD64.cab'; ALTERNATEDATAVERSION = '2461'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_01_07_05_03_AMD64.cab'; ALTERNATEDATAVERSION = '2462'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_01_14_02_03_AMD64.cab'; ALTERNATEDATAVERSION = '2463'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_01_28_04_03_AMD64.cab'; ALTERNATEDATAVERSION = '2464'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_02_12_02_03_AMD64.cab'; ALTERNATEDATAVERSION = '2465'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_07_29_02_02_AMD64.cab'; ALTERNATEDATAVERSION = '2501'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_10_14_12_02_AMD64.cab'; ALTERNATEDATAVERSION = '2509'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2021_12_09_11_02_AMD64.cab'; ALTERNATEDATAVERSION = '2515'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_01_20_02_01_AMD64.cab'; ALTERNATEDATAVERSION = '2519'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_01_21_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2520'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_01_27_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2521'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_02_10_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2522'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_02_24_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2523'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_03_24_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2524'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_04_28_02_01_AMD64.cab'; ALTERNATEDATAVERSION = '2528'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_06_02_12_01_AMD64.cab'; ALTERNATEDATAVERSION = '2530'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_08_24_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2540'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_09_13_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2541'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_09_22_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2542'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_09_29_02_01_AMD64.cab'; ALTERNATEDATAVERSION = '2543'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_10_06_01_01_AMD64.cab'; ALTERNATEDATAVERSION = '2544'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_10_13_02_01_AMD64.cab'; ALTERNATEDATAVERSION = '2545'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_10_20_12_01_AMD64.cab'; ALTERNATEDATAVERSION = '2546'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_10_27_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2547'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_11_03_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2548'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_11_10_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2549'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_11_10_04_01_X86.cab'; ALTERNATEDATAVERSION = '254986'} # From Robert Stein (@RaslDasl)
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_11_22_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2550'} # From Tyler Cox (@_Tcox8)
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_12_01_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2551'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_12_14_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2552'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_01_19_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2553'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_02_21_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2554'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_03_01_01_01_AMD64.cab'; ALTERNATEDATAVERSION = '2555'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_04_20_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2559'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_08_30_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2568'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_12_14_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2580'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_01_04_02_01_AMD64.cab'; ALTERNATEDATAVERSION = '2581'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_01_18_06_01_AMD64.cab'; ALTERNATEDATAVERSION = '2582'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_01_25_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2583'}

@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_02_22_03_01_AMD64.cab'; ALTERNATEDATAVERSION = '2585'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_05_16_01_01_AMD64.cab'; ALTERNATEDATAVERSION = '2591'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_10_24_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2606'} # From Marcel @marceldk
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_10_27_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '2614'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_11_10_04_02_AMD64.cab'; ALTERNATEDATAVERSION = '2616'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_11_14_04_03_AMD64.cab'; ALTERNATEDATAVERSION = '2643'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_11_16_04_03_AMD64.cab'; ALTERNATEDATAVERSION = '2644'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_08_30_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '2653'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_11_14_04_04_AMD64.cab'; ALTERNATEDATAVERSION = '2661'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_11_16_04_04_AMD64.cab'; ALTERNATEDATAVERSION = '2662'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_12_07_04_02_AMD64.cab'; ALTERNATEDATAVERSION = '2664'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_12_07_04_04_AMD64.cab'; ALTERNATEDATAVERSION = '26641'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_12_14_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '2665'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_12_14_03_04_AMD64.cab'; ALTERNATEDATAVERSION = '26651'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_01_04_02_02_AMD64.cab'; ALTERNATEDATAVERSION = '2666'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_01_04_02_04_AMD64.cab'; ALTERNATEDATAVERSION = '26661'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_01_18_06_04_AMD64.cab'; ALTERNATEDATAVERSION = '2667'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_01_18_06_02_AMD64.cab'; ALTERNATEDATAVERSION = '26671'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_01_25_03_04_AMD64.cab'; ALTERNATEDATAVERSION = '2668'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_01_25_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '26681'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_02_06_03_04_AMD64.cab'; ALTERNATEDATAVERSION = '2669'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_02_06_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '26691'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_02_22_03_04_AMD64.cab'; ALTERNATEDATAVERSION = '2670'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_02_22_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '26701'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_04_11_02_04_AMD64.cab'; ALTERNATEDATAVERSION = '2674'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_04_25_02_04_AMD64.cab'; ALTERNATEDATAVERSION = '2675'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_05_16_01_02_AMD64.cab'; ALTERNATEDATAVERSION = '2676'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_05_16_01_04_AMD64.cab'; ALTERNATEDATAVERSION = '26761'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_10_24_04_01_AMD64.cab'; ALTERNATEDATAVERSION = '2691'} 
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_10_24_04_02_AMD64.cab'; ALTERNATEDATAVERSION = '26912'} # From Marcel @marceldk
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_10_24_04_03_AMD64.cab'; ALTERNATEDATAVERSION = '26913'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_10_24_04_04_AMD64.cab'; ALTERNATEDATAVERSION = '26914'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2024_10_24_04_05_AMD64.cab'; ALTERNATEDATAVERSION = '26915'}


#Other:
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_11_03_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '11030302'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_11_10_04_02_AMD64.cab'; ALTERNATEDATAVERSION = '11100402'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_11_22_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '11220302'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_12_01_04_02_AMD64.cab'; ALTERNATEDATAVERSION = '12010402'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2022_12_14_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '12140302'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_02_21_03_02_AMD64.cab'; ALTERNATEDATAVERSION = '02210302'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_03_01_01_02_AMD64.cab'; ALTERNATEDATAVERSION = '03010102'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_08_30_03_03_AMD64.cab'; ALTERNATEDATAVERSION = '08300303'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_08_30_03_04_AMD64.cab'; ALTERNATEDATAVERSION = '08300304'}
@{ ALTERNATEDATALINK = 'http://adl.windows.com/appraiseradl/2023_08_30_03_05_AMD64.cab'; ALTERNATEDATAVERSION = '08300304'}
)

#>

#This is the new Process to find all URLs that are valid.  This will be used to update the SettingsTable.

<#Experimental - Run 1 Time Only to create the JSON file on GitHub - This will start at the beginning. Then skip the next section where it grabs info form GitHub


#StartDate
[int]$URLYear = 2018
[int]$URLMonth = 1
[int]$URLDay = 1
[int]$URLExtra1 = 1
[int]$URLExtra2 = 1

#>
#This will grab the latest URL from GitHub, and start from that date to current date to find any new URLs.

if (test-webconnection -uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldURLS.json" -ErrorAction SilentlyContinue){
    $OnlineSettingsTable = (Invoke-WebRequest -URI "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldURLS.json").content | ConvertFrom-Json
}
if ($OnlineSettingsTable){
    $LatestURL = $OnlineSettingsTable | Sort-Object ALTERNATEDATAVERSION -Descending | Select-Object -First 1
}
$Counter = 1
$GuessingTable = @() 

#StartDate
[int]$URLYear = $LatestURL.ALTERNATEDATAVERSION.Substring(0,4)
[int]$URLMonth = $LatestURL.ALTERNATEDATAVERSION.Substring(4,2)
[int]$URLDay = $LatestURL.ALTERNATEDATAVERSION.Substring(6,2)
[int]$URLExtra1 = $LatestURL.ALTERNATEDATAVERSION.Substring(8,2)
[int]$URLExtra2 = $LatestURL.ALTERNATEDATAVERSION.Substring(10,2)

[int]$MaxDay = 31
[int]$MaxMonth = 12
[int]$MaxExtra1 = 13
[int]$MaxExtra2 = 5

$FullDate = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)"
$StartURL = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)_$('{0:d2}' -f [int]$URLExtra1)_$('{0:d2}' -f [int]$URLExtra2)"
$DateStop = get-date -Format yyyy_MM_dd

do {
    $URLExtra2++
    $StartURL = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)_$('{0:d2}' -f [int]$URLExtra1)_$('{0:d2}' -f [int]$URLExtra2)"
    if ($URLExtra2 -gt $MaxExtra2){
        $URLExtra2 = 1
        $URLExtra1++
        $StartURL = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)_$('{0:d2}' -f [int]$URLExtra1)_$('{0:d2}' -f [int]$URLExtra2)"
        if ($URLExtra1 -gt $MaxExtra1){
            Write-Host "Checking http://adl.windows.com/appraiseradl/$($StartURL)_AMD64.cab" -ForegroundColor Yellow    
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
    #Write-Host "Checking http://adl.windows.com/appraiseradl/$($StartURL)_AMD64.cab" -ForegroundColor Yellow
    if (test-webconnection -uri "http://adl.windows.com/appraiseradl/$($StartURL)_AMD64.cab" -ErrorAction SilentlyContinue){
        Write-Host "$Counter Found http://adl.windows.com/appraiseradl/$($StartURL)_AMD64.cab | $($StartURL.replace('_',''))" -ForegroundColor cyan
        $Counter++
        $GuessingTable += @{ ALTERNATEDATALINK = "http://adl.windows.com/appraiseradl/$($StartURL)_AMD64.cab"; ALTERNATEDATAVERSION = "$($StartURL.replace('_',''))" }
    }
    $FullDate = "$($URLYear)_$('{0:d2}' -f [int]$URLMonth)_$('{0:d2}' -f [int]$URLDay)"
} 
while ($FullDate -lt $DateStop)
$Path = "C:\Temp"
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines("$Path\SafeGuardHoldURLS.json", ($GuessingTable | ConvertTo-Json), $Utf8NoBomEncoding)
$LocalGitHubPath = "C:\Users\GaryBlok\OneDrive - garytown\Documents\GitHub - ZBookStudio2Pint\garytown\Feature-Updates\SafeGuardHolds"
if (Test-Path $LocalGitHubPath\SafeGuardHoldURLS.json){
    [System.IO.File]::WriteAllLines("$LocalGitHubPath\SafeGuardHoldURLS.json", ($GuessingTable | ConvertTo-Json), $Utf8NoBomEncoding)
}
#>

# Need to write code here to grab the latest version from GitHub, then start from that date to current date to find any new URLs. - Future Update


$Path = "C:\Temp"
$AppriaserRoot = $Path
try {[void][System.IO.Directory]::CreateDirectory($AppriaserRoot)}
catch {throw}
    
#Download all Appraiser CAB Files
$SafeGuardHoldCombined = @()
$Count = 0
if (test-webconnection -uri "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldURLS.json" -ErrorAction SilentlyContinue){
    $SettingsTable = (Invoke-WebRequest -URI "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldURLS.json").content | ConvertFrom-Json
}
$TotalCount = $SettingsTable.Count
ForEach ($Item in $SettingsTable){  
    $Count = $Count + 1 
    $AppraiserURL = $Item.ALTERNATEDATALINK
    $AppraiserVersion = $Item.ALTERNATEDATAVERSION
    Write-Host "---------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "Starting on Version $AppraiserVersion, $Count of $TotalCount Items" -ForegroundColor Magenta
    $OutFilePath = "$AppriaserRoot\AppraiserData\$AppraiserVersion"
    $ExistingCAB = Get-ChildItem -Path $AppriaserRoot\*.cab -Recurse -File | Where-Object { $_.Name -like "*$AppraiserVersion*" } -ErrorAction SilentlyContinue
    if (-Not $ExistingCAB) {
        $LinkParts = $AppraiserURL.Split("/")
        $OutFileName = "$($AppraiserVersion)_$($LinkParts[$LinkParts.Count-1])"
        if (-not (Test-Path $OutFilePath)) {New-Item -Path $OutFilePath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null}     
        Invoke-WebRequest -URI $AppraiserURL -OutFile "$OutFilePath\$OutFileName"
    }
    $ExistingXMLS = Get-ChildItem -Path $AppriaserRoot\*.xml -Recurse -File | Where-Object { $_.Name -like "*$AppraiserVersion*" } -ErrorAction SilentlyContinue
    if (-Not $ExistingXMLS){
        write-host "Starting Function Export-FUXMLFromSDB $OutFilePath" -ForegroundColor Magenta
        Export-FUXMLFromSDB -AlternateSourcePath $OutFilePath -Path $AppriaserRoot
        $ExistingXMLS = Get-ChildItem -Path $AppriaserRoot\*.xml -Recurse -File | Where-Object { $_.Name -like "*$AppraiserVersion*" } -ErrorAction SilentlyContinue
        if (-Not $ExistingXMLS){
            Write-Host -ForegroundColor Yellow "Did not find any XML files in this Group $AppraiserVersion"
        }
    }
    foreach ($ExistingXML in $ExistingXMLS){
        Write-Host -ForegroundColor Gray "  Searching XML File $($ExistingXML.fullName) for SafeGuard Info"
        $SafeGuardHoldDataWorking  = $null
        $DBBlocks = if ($ExistingXML) {
            [xml]$Content = Get-Content -Path $ExistingXML -Raw
            $OSUpgrade = $Content.SelectNodes("//SDB/DATABASE/OS_UPGRADE")
            $GatedBlockOSU = $OSUpgrade | Where-Object { $_.DATA.Data_String.'#text' -eq 'GatedBlock' }  
            $GatedBlockOSU | ForEach-Object {
                @{
                    AppName       = $_.App_Name.'#text'
                    BlockType     = $_.Data[0].Data_String.'#text'
                    SafeguardId   = $_.Data[1].Data_String.'#text'
                    NAME          = $_.NAME.'#text'
                    APP_NAME      = $_.APP_NAME.'#text'
                    VENDOR        = $_.VENDOR.'#text'
                    EXE_ID        = $_.EXE_ID.'#text'
                    DEST_OS_GTE   = $_.DEST_OS_GTE.'#text'
                    DEST_OS_LT    = $_.DEST_OS_LT.'#text'
                    MATCHING_FILE = $_.MATCHING_FILE.'#text'
                    PICK_ONE      = $_.PICK_ONE.'#text'
                    INNERXML      = $_.InnerXML
                }
            }
            $MIB = $Content.SelectNodes("//SDB/DATABASE/MATCHING_INFO_BLOCK")
            $GatedBlockMIB = $MIB | Where-Object { $_.DATA.Data_String.'#text' -eq 'GatedBlock' }
            $GatedBlockMIB | ForEach-Object {
                @{
                    AppName         = $_.App_Name.'#text'
                    BlockType       = $_.Data[0].Data_String.'#text'
                    SafeguardId     = $_.Data[1].Data_String.'#text'
                    APP_NAME        = $_.APP_NAME.'#text'
                    DEST_OS_GTE     = $_.DEST_OS_GTE.'#text'
                    DEST_OS_LT      = $_.DEST_OS_LT.'#text'
                    EXE_ID          = $_.EXE_ID.'#text'
                    MATCH_PLUGIN    = $_.MATCH_PLUGIN.Name.'#text'
                    MATCHING_DEVICE = $_.MATCHING_DEVICE.Name.'#text'
                    MATCHING_REG    = $_.MATCHING_REG.Name.'#text'
                    NAME            = $_.NAME.'#text'
                    PICK_ONE        = $_.PICK_ONE.Name.'#text'
                    SOURCE_OS_LTE   = $_.SOURCE_OS_LTE.'#text'
                    VENDOR          = $_.VENDOR.'#text'
                    INNERXML        = $_.InnerXML
                }
            }
        } Select-Object -Unique * | Sort-Object AppName
        $SafeGuardHoldDataWorking  = $DBBlocks | ForEach-Object { [PSCustomObject]$_ }
        $SafeGuardHoldCombined += $SafeGuardHoldDataWorking
        if ($ExistingXMLS.Count -gt 1){
            $Last = $ExistingXMLS | Select-Object -Last 1
            if ($ExistingXML -eq $Last){

                Write-Host " SafeguardHoldCount:       $($SafeGuardHoldCombined.Count)" -ForegroundColor Green
                $SafeGuardHoldIDs = $SafeGuardHoldCombined.SafeguardID | Select-Object -Unique
                Write-Host " SafeguardHoldUniqueCount: $($SafeGuardHoldIDs.Count)" -ForegroundColor Green
            }
        }
    }
}
Write-Host "Found $($SafeGuardHoldCombined.Count) Safeguard hold Items contained in the $TotalCount Appraiser DB Versions, exported to $Path\SafeGuardHoldCombinedDataBase.json" -ForegroundColor Green
#$SafeGuardHoldCombined | ConvertTo-Json | Out-File "$Path\SafeGuardHoldCombinedDataBase.json" -Encoding utf8
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines("$Path\SafeGuardHoldCombinedDataBase.json", ($SafeGuardHoldCombined | ConvertTo-Json), $Utf8NoBomEncoding)

#Get Unique based on ID.  Assuming that all all safeguards with the same number are unique.
Write-Host " Building Database of Unique Safeguard IDs...." -ForegroundColor Magenta
$SafeGuardHoldIDs = $SafeGuardHoldCombined.SafeguardID | Select-Object -Unique
$SafeGuardHoldDatabase = @()
ForEach ($SafeGuardHoldID in $SafeGuardHoldIDs){
    $SafeGuardHoldWorking = $null
    $SafeGuardHoldWorking = $SafeGuardHoldCombined | Where-Object {$_.SafeguardID -eq $SafeGuardHoldID} | Select-Object -Unique
    $SafeGuardHoldDatabase += $SafeGuardHoldWorking 
}

#Export JSON as UTF8 without BOM
#$SafeGuardHoldDatabase | ConvertTo-Json -Depth 10 | Out-File "$Path\SafeGuardHoldDataBase.json" -Encoding utf8
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines("$Path\SafeGuardHoldDataBase.json", ($SafeGuardHoldDatabase | ConvertTo-Json), $Utf8NoBomEncoding)

Write-Host "Found $($SafeGuardHoldDatabase.Count) unique Safeguard hold Items, exported to $Path\SafeGuardHoldDataBase.json" -ForegroundColor Green

#Compare
Write-Host "Comparing Previous Online Output to this Run" -ForegroundColor Green
$OnlineSafeGuardJSONURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldDataBase.json'
$OnlineSafeGuardData = (Invoke-WebRequest -URI $OnlineSafeGuardJSONURL).content | ConvertFrom-Json
$Compare = Compare-Object -ReferenceObject $OnlineSafeGuardData -DifferenceObject $SafeGuardHoldDatabase

Write-Host "Previous Count: $($OnlineSafeGuardData.count) | Current Count: $($SafeGuardHoldDatabase.Count)" -ForegroundColor Green
