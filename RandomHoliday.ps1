#Grabs a Unique Holiday. - @gwblok
if ((Test-NetConnection "www.checkiday.com").PingSucceeded)
    {
    [xml]$Events = (New-Object System.Net.WebClient).DownloadString("https://www.checkiday.com/rss.php?tz=America/Chicago")
    if ($Events)
        {
        $EventNames = $Events.rss.channel.item.description
        #Pick Random Calendar Event
        [int]$Picker = Get-Random -Minimum 1 -Maximum $EventNames.Count
        $EventPicked = ($EventNames[$Picker]).'#cdata-section'
        Write-Output $EventPicked
        }
    else
        {
        Write-Output "No Special Events today"
        }
    }
else
    {
    Write-Output "Can't Connect to Website"
    }



#Set Fun Version in CM Console for the Uploaded Media - Checks for "Holiday" and uses that. - @gwblok
#This is modified to use part of the Holiday Name in my Output.  Just an example of something you could use it for.
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
        if($VersionName.Contains('National')) {$VersionName = $VersionName.Replace("National","")}
        
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
