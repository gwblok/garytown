$ESDStorage = 'F:\ESDFiles'

Import-Module -name OSD
$ESDFilesX64 = Get-OSDCloudOperatingSystems -OSArch x64
$ESDFilesARM64 = Get-OSDCloudOperatingSystems -OSArch ARM64

#================================================
#   X64 Get Index Info
#================================================
$ImageIndexDB = @()
$Counter = 0
foreach ($ESD in $ESDFilesX64){
    $Counter ++
    write-host -ForegroundColor Cyan "Starting $($ESD.Name) - $Counter of $($ESDFilesX64.Count)"
    Write-Host -ForegroundColor Green "Time: $(Get-Date -Format HH:mm:ss-yyyy-MM-dd)"
    $ImageFolderPath = "$ESDStorage\$($ESD.version) $($ESD.ReleaseId) $($ESD.Architecture)"
    if (!(Test-Path -Path $ImageFolderPath)){New-Item -Path $ImageFolderPath -ItemType Directory -Force | Out-Null}
    $ImagePath = "$ImageFolderPath\$($ESD.FileName)"
    $ImageDownloadRequired = $true
    if (Test-path -path $ImagePath){
        Write-Host -ForegroundColor Gray "Found previously downloaded media, getting SHA1 Hash"
        $SHA1Hash = Get-FileHash $ImagePath -Algorithm SHA1
        if ($SHA1Hash.Hash -eq $esd.SHA1){
            Write-Host -ForegroundColor Gray "SHA1 Match on $ImagePath, skipping Download"
            $ImageDownloadRequired = $false
        }
        else {
            Write-Host -ForegroundColor Gray "SHA1 Match Failed on $ImagePath, removing content"
        }
        
    }

    if ($ImageDownloadRequired -eq $true){
        #Save-WebFile -SourceUrl $ESD.Url -DestinationDirectory $ScratchLocation -DestinationName $ESD.FileName
        Write-Host -ForegroundColor Gray "Starting Download to $ImagePath, this takes awhile"
        #Clear Out any Previous Attempts
        $ExistingBitsJob = Get-BitsTransfer -Name "$($ESD.FileName)" -AllUsers -ErrorAction SilentlyContinue
        If ($ExistingBitsJob) {
            Remove-BitsTransfer -BitsJob $ExistingBitsJob
        }
    
        if ((Get-Service -name BITS).Status -ne "Running"){
            Write-Host -ForegroundColor Yellow "BITS Service is not Running, which is required to download ESD File, attempting to Start"
            $StartBITS = Start-Service -Name BITS -PassThru
            Start-Sleep -Seconds 2
            if ($StartBITS.Status -ne "Running"){

            }
        }
        #Start Download using BITS
        Write-Host -ForegroundColor DarkGray "Start-BitsTransfer -Source $ESD.Url -Destination $ImageFolderPath -DisplayName $($ESD.FileName) -Description 'Windows Media Download' -RetryInterval 60"
        $BitsJob = Start-BitsTransfer -Source $ESD.Url -Destination $ImageFolderPath -DisplayName "$($ESD.FileName)" -Description "Windows Media Download" -RetryInterval 60
        If ($BitsJob.JobState -eq "Error"){
            write-Host "BITS tranfer failed: $($BitsJob.ErrorDescription)"
        }
    }
    if (Test-Path -Path $ImagePath){
        $ImageInfo = Get-WindowsImage -ImagePath $ImagePath
        $TotalIndexes = $ImageInfo.Count
        $Inventory = New-Object System.Object
        $Inventory | Add-Member -MemberType NoteProperty -Name "Status" -Value "$($esd.Status)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "ReleaseDate" -Value "$($esd.ReleaseDate)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($esd.Name)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Version" -Value "$($esd.Version)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "ReleaseID" -Value "$($esd.ReleaseID)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Architecture" -Value "$($esd.Architecture)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Language" -Value "$($esd.Language)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Activation" -Value "$($esd.Activation)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Build" -Value "$($esd.Build)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "FileName" -Value "$($esd.FileName)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "ImageIndex" -Value "$($esd.ImageIndex)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "ImageName" -Value "$($esd.ImageName)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Url" -Value "$($esd.Url)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "SHA1" -Value "$($esd.SHA1)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "UpdateID" -Value "$($esd.UpdateID)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Win10" -Value "$($esd.Win10)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Win11" -Value "$($esd.Win11)" -Force

        $Inventory | Add-Member -MemberType NoteProperty -Name "TotalIndexes" -Value "$TotalIndexes" -Force
        $IndexNameArray = @()
        $Indexes = @{}

        foreach ($ImageIndex in $ImageInfo){
            
            #$Inventory | Add-Member -MemberType NoteProperty -Name "Index$($ImageIndex.imageindex)Name" -Value "$($ImageIndex.ImageName)" -Force
            #$Inventory | Add-Member -MemberType NoteProperty -Name "Index$($ImageIndex.imageindex)Desc" -Value "$($ImageIndex.ImageDescription)" -Force
            if ($ImageIndex.ImageIndex -ge 4){
                $IndexNameArray += $ImageIndex.ImageName
                $Indexes.Add($ImageIndex.ImageName, $ImageIndex.imageindex)
            }
        }
        $Inventory | Add-Member -MemberType NoteProperty -Name "IndexNames" -Value $IndexNameArray -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Indexes" -Value $Indexes -Force
        $ImageIndexDB += $Inventory
    }
}
$ImageIndexDB | ConvertTo-Json | Out-File "$ESDStorage\CloudOperatingSystemsIndexes.JSON" -Force

#================================================
#   ARM64 Get Index Info
#================================================

$ImageIndexDB = @()
$Counter = 0
foreach ($ESD in $ESDFilesARM64){
    $Counter ++
    write-host -ForegroundColor Cyan "Starting $($ESD.Name) - $Counter of $($ESDFilesARM64.Count)"
    Write-Host -ForegroundColor Green "Time: $(Get-Date -Format HH:mm:ss-yyyy-MM-dd)"
    $ImageFolderPath = "$ESDStorage\$($ESD.version) $($ESD.ReleaseId) $($ESD.Architecture)"
    if (!(Test-Path -Path $ImageFolderPath)){New-Item -Path $ImageFolderPath -ItemType Directory -Force | Out-Null}
    $ImagePath = "$ImageFolderPath\$($ESD.FileName)"
    
    $ImageDownloadRequired = $true
    
    if (Test-path -path $ImagePath){
        Write-Host -ForegroundColor Gray "Found previously downloaded media, getting SHA1 Hash"
        $SHA1Hash = Get-FileHash $ImagePath -Algorithm SHA1
        if ($SHA1Hash.Hash -eq $esd.SHA1){
            Write-Host -ForegroundColor Gray "SHA1 Match on $ImagePath, skipping Download"
            $ImageDownloadRequired = $false
        }
        else {
            Write-Host -ForegroundColor Gray "SHA1 Match Failed on $ImagePath, removing content"
        }
        
    }

    if ($ImageDownloadRequired -eq $true){
        #Save-WebFile -SourceUrl $ESD.Url -DestinationDirectory $ScratchLocation -DestinationName $ESD.FileName
        Write-Host -ForegroundColor Gray "Starting Download to $ImagePath, this takes awhile"
        #Clear Out any Previous Attempts
        $ExistingBitsJob = Get-BitsTransfer -Name "$($ESD.FileName)" -AllUsers -ErrorAction SilentlyContinue
        If ($ExistingBitsJob) {
            Remove-BitsTransfer -BitsJob $ExistingBitsJob
        }
    
        if ((Get-Service -name BITS).Status -ne "Running"){
            Write-Host -ForegroundColor Yellow "BITS Service is not Running, which is required to download ESD File, attempting to Start"
            $StartBITS = Start-Service -Name BITS -PassThru
            Start-Sleep -Seconds 2
            if ($StartBITS.Status -ne "Running"){

            }
        }
        #Start Download using BITS
        Write-Host -ForegroundColor DarkGray "Start-BitsTransfer -Source $ESD.Url -Destination $ImageFolderPath -DisplayName $($ESD.FileName) -Description 'Windows Media Download' -RetryInterval 60"
        $BitsJob = Start-BitsTransfer -Source $ESD.Url -Destination $ImageFolderPath -DisplayName "$($ESD.FileName)" -Description "Windows Media Download" -RetryInterval 60
        If ($BitsJob.JobState -eq "Error"){
            write-Host "BITS tranfer failed: $($BitsJob.ErrorDescription)"
        }
    }

    if (Test-Path -Path $ImagePath){
        $ImageInfo = Get-WindowsImage -ImagePath $ImagePath
        $TotalIndexes = $ImageInfo.Count
        $Inventory = New-Object System.Object
        $Inventory | Add-Member -MemberType NoteProperty -Name "Status" -Value "$($esd.Status)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "ReleaseDate" -Value "$($esd.ReleaseDate)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Name" -Value "$($esd.Name)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Version" -Value "$($esd.Version)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "ReleaseID" -Value "$($esd.ReleaseID)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Architecture" -Value "$($esd.Architecture)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Language" -Value "$($esd.Language)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Activation" -Value "$($esd.Activation)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Build" -Value "$($esd.Build)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "FileName" -Value "$($esd.FileName)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "ImageIndex" -Value "$($esd.ImageIndex)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "ImageName" -Value "$($esd.ImageName)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Url" -Value "$($esd.Url)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "SHA1" -Value "$($esd.SHA1)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "UpdateID" -Value "$($esd.UpdateID)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Win10" -Value "$($esd.Win10)" -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Win11" -Value "$($esd.Win11)" -Force

        $Inventory | Add-Member -MemberType NoteProperty -Name "TotalIndexes" -Value "$TotalIndexes" -Force
        $IndexNameArray = @()
        $Indexes = @{}

        foreach ($ImageIndex in $ImageInfo){
            
            #$Inventory | Add-Member -MemberType NoteProperty -Name "Index$($ImageIndex.imageindex)Name" -Value "$($ImageIndex.ImageName)" -Force
            #$Inventory | Add-Member -MemberType NoteProperty -Name "Index$($ImageIndex.imageindex)Desc" -Value "$($ImageIndex.ImageDescription)" -Force
            if ($ImageIndex.ImageIndex -ge 4){
                $IndexNameArray += $ImageIndex.ImageName
                $Indexes.Add($ImageIndex.ImageName, $ImageIndex.imageindex)
            }
        }
        $Inventory | Add-Member -MemberType NoteProperty -Name "IndexNames" -Value $IndexNameArray -Force
        $Inventory | Add-Member -MemberType NoteProperty -Name "Indexes" -Value $Indexes -Force
        $ImageIndexDB += $Inventory
    }
}
$ImageIndexDB | ConvertTo-Json | Out-File "$ESDStorage\CloudOperatingSystemsARM64Indexes.JSON" -Force
