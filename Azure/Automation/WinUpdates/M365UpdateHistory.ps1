<# Gary Blok - 2022.08.23
Some Code & Functions taken from:
https://github.com/SMSAgentSoftware/MEM/blob/main/%5BReporting%5D%20SoftwareUpdates/Get-WindowsUpdateInfoRunbook.ps1
https://github.com/binSHA3/O356Versions/blob/main/Get-O365Data.ps1

Thanks much for your contributions.

#>

$script:M365SupportedVersionTableHistory = [System.Data.DataTable]::new()
$script:Destination = "$env:TEMP"

function Format-VersionHistoryTable {
    #Function from: https://github.com/binSHA3/O356Versions/blob/main/Get-O365Data.ps1
    [cmdletbinding()]
    param (
        [Object] $TableObject
    )

    [String[]] $channels = $tableobject[0].psobject.Properties.Name | Where-Object { $_ -like "*Channel*" }
    [String] $lastYear = $null

    foreach ($row in $TableObject) {

        if ($row.Year){ 
            $lastYear = $row.Year
        } else {
            $row.Year = $lastYear
        }

        $relaseDateAry = $row.'Release date'.Split(' ')
        $month = [array]::indexof([cultureinfo]::CurrentCulture.DateTimeFormat.MonthNames, $relaseDateAry[0]) + 1
        $day = $relaseDateAry[1]
        $releaseDateStr = "$($day.PadLeft(2,'0'))-$($month.ToString().PadLeft(2,'0'))-$($row.Year)"
        $releaseDate = [datetime]::parseexact($releaseDateStr, 'dd-MM-yyyy', $null)

        foreach ($channel in $channels){
            $versionBuilds = $row.$channel.split(')')
            $release = 0
            foreach ($vb in $versionBuilds){
                $tempAry = $vb.Split('(')
                if ($tempAry[1]){
                    $channelBuild = $tempAry[1].Replace('Build ','').Replace(')','')
                    [PSCustomObject]([ordered]@{
                        Channel = $channel;
                        ChannelShortName = $channel.Replace('Channel', '').Replace('Enterprise', '').Replace('-', '').Replace('(', '').Replace(')', '').Replace(' ', '');
                        Version = $tempAry[0].Replace('Version ', '').Trim()
                        ChannelBuild = $channelBuild
                        FullBuild = ([version] "16.0.$($channelBuild)")
                        ReleaseDate = $releaseDate
                        Release = $release
                    })
                    $release++
                }              
            }
        }
    }
}


# Function to extract M365 History Versions from MS docs
Function New-M365SupportedVersionsTableHistory {

    # Windows release info URLs
    $URLs = @(
        "https://docs.microsoft.com/en-us/officeupdates/update-history-microsoft365-apps-by-date"
        #"https://docs.microsoft.com/en-us/windows/release-health/windows11-release-information"
    )
    If ($M365SupportedVersionTableHistory.Columns.Count -eq 0)
        {
        $M365SupportedVersionTableHistory.Columns.AddRange(@("Year","Release Date","Current Channel","Monthly Enterprise Channel","Semi-Annual Enterprise Channel (Preview)","Semi-Annual Enterprise Channel","Blank","Category"))
        }

    

    # Process each Windows release
    foreach ($URL in $URLs)
    {
        Invoke-WebRequest -URI $URL -OutFile $Destination\winreleaseinfo.html -UseBasicParsing
        $htmlarray = Get-Content $Destination\winreleaseinfo.html -ReadCount 0
        # get the headers and data cells
        $headers = $htmlarray | Select-String -SimpleMatch "<h3 " | Where {$_ -match "Version History"}
        $dataCells = $htmlarray | Select-String -SimpleMatch "</td>"

        # process each header
        $i = 1
        do {
            foreach ($header in $headers | Where-Object {$_ -match "Version History"})
            {
                $lineNumber = $header.LineNumber
                $nextHeader = $headers[$i]
                If ($null -ne $nextHeader)
                {
                    $nextHeaderLineNumber = $nextHeader.LineNumber
                    $cells = $dataCells | Where {$_.LineNumber -gt $lineNumber -and $_.LineNumber -lt $nextHeaderLineNumber}
                }
                else 
                {
                    $cells = $dataCells | Where {$_.LineNumber -gt $lineNumber}  
                }

                # process each cell
                $totalCells = $cells.Count
                $t = 0
                do {
                    $Row = $M365SupportedVersionTableHistory.NewRow()
                    "Year","Release Date","Current Channel","Monthly Enterprise Channel","Semi-Annual Enterprise Channel (Preview)","Semi-Annual Enterprise Channel","blank" | foreach {
                        if ($cells[$t].ToString() -match '<td style="text-align: left;"><a href="'){
                            $keep = $($($cells[$t].ToString().replace('<td style=`"text-align: left;`">','').replace('<a href="semi-annual-enterprise-channel','').replace('<a href="monthly-enterprise-channel','').replace('<a href="monthly-enterprise-channel-archived','').replace('</a><br/>','').replace('</a></td>','').replace('</a','').replace('-archived','').replace('</td',''))).split('>')
                            
                            $CurrentArray = @()
                            ForEach ($Item in $keep){
                                if ($Item.startswith("Version") -eq $true){
                                    #Write-Output $Item
                                    $Item = $item.Split('#')[0]
                                    $CurrentArray += $Item
                                }
                            }
                            $VersionData = $CurrentArray -join ' '
                            $Row["$_"] = $VersionData
                            }
                        else
                            {
                            $Row["$_"] = "$($cells[$t].ToString().Replace('<code>','').Replace('</code>','').Split('>').Split('<')[2])"
                            }
                        #$cells[$t]
                        $t ++
                    }
                    $Row["Category"] = "$($header.ToString().Split('>').Split('<')[4])"
                    if ($Row.Year -eq ""){}
                    else{[void]$M365SupportedVersionTableHistory.Rows.Add($Row)}
                }
                until ($t -ge ($totalCells -1))
                $i ++
            }
        }
        until ($i -ge $headers.count)
    }
    $script:FormattedVersionHistory = Format-VersionHistoryTable -TableObject ($M365SupportedVersionTableHistory).Rows | Sort-Object ReleaseDateDate, Channel, FullBuild
}

New-M365SupportedVersionsTableHistory
$script:FormattedVersionHistory
