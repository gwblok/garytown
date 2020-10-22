Function Get-CCMDTSJobsActive {

    $ActiveTransfer = Get-BitsTransfer -AllUsers | Where-Object {$_.DisplayName -eq "CCMDTS Job" -and $_.JobState -eq "Transferring"}
    if ($ActiveTransfer)
        {
        Write-host "Currently Transferring BITS Job: $($ActiveTransfer.JobId)"-ForegroundColor Green
        $PackageID = (($ActiveTransfer.FileList | Select-Object -First 1).RemoteName).split("/") | Where-Object {$_ -Match "MEM"}
        $App = (($ActiveTransfer.FileList | Select-Object -First 1).RemoteName).split("/") | Where-Object {$_ -Match "content_"}
        $DownloadLocation = (($ActiveTransfer.FileList | Select-Object -First 1).LocalName).split("\")[3]
        #$ExampleFile = (($ActiveTransfer.FileList | Select-Object -First 1).RemoteName).split("/")
        $ExampleFileLocalName = $ActiveTransfer.FileList | Where-Object {$_.LocalName -Match 'install.wim'}
        if (!($ExampleFileLocalName)){$ExampleFileLocalName = ($ActiveTransfer.FileList | Select-Object -First 1).LocalName}
        $TotalSize = [math]::Round($ActiveTransfer.BytesTotal / 1024 / 1024,2) 
        $PercentComplete = [math]::Round($ActiveTransfer.BytesTransferred / $ActiveTransfer.BytesTotal * 100,2)
        

        if ($PackageID -or $App)
            {
            Write-host "  Downloading Content: $PackageID $App " -ForegroundColor Green
            #Write-host "  Example File Info:" -ForegroundColor Green
            #$ExampleFileLocalName
            Write-host "  Downloading Location: c:\windows\ccmcache\$DownloadLocation " -ForegroundColor Green
            write-host "  Total Size: $TotalSize and Downloaded: $PercentComplete%" -ForegroundColor Green
            }
        }
    
    }
Function Get-CCMDTSJobs {

    $CMTransfers = Get-BitsTransfer -AllUsers | Where-Object {$_.DisplayName -eq "CCMDTS Job" -and $_.JobState -ne "Transferred" }
    if ($CMTransfers)
        {
        Return Write-host "There are currently $($CMTransfers.count) CM Content Transfers"-ForegroundColor Green}

        }
