#Set Fun Version in CM Console for the Uploaded Media - Checks for "Holiday" and uses that. - @gwblok
if ((Test-NetConnection "www.checkiday.com").PingSucceeded)
    {
    [xml]$Events = (New-Object System.Net.WebClient).DownloadString("https://www.checkiday.com/rss.php?tz=America/Chicago")
    if ($Events)
        {
        $EventNames = $Events.rss.channel.item.description
        #Pick Random Calendar Event
        [int]$Picker = Get-Random -Minimum 1 -Maximum $EventNames.Count
        $EventPicked = ($EventNames[$Picker]).'#cdata-section'
        $VersionName = ($EventPicked.Replace("Today is ","")).replace(" Day!"," Edition")
        Write-Output "OSD Builder TS Version: $VersionName"
        }
    else
        {
        $VersionName = "BYO ISO Edition"
        Write-Output "No Special Events today, defaulting to generic"
        }
    }
else
    {
    Write-Output "Can't Connect to Website"
    $VersionName = "BYO ISO Edition"
    Write-Output "No Special Events today, defaulting to generic"
    }
