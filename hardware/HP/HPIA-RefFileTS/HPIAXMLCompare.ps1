<#  XML Compare Script - GARY BLOK

This assumes you're using the script to create HP Reference XML files and placing them in $RefFolderRoot

This will compare the most recent run of that script vs the previous run of that script.
During the process it will output to the console, but also output JSON files to a new folder: ChangeLogs-PrevDate-LatestDate

Let me know if you want anything else added to the JSON, anything in the reference files should be available for us.


#>


#Add Info about PRevious Version 

$RefFolderRoot = "D:\HPIA-ReferenceFiles"
$RefFolderPrevious = (Get-ChildItem -Path $RefFolderRoot | Sort-Object -Descending) | Select-Object -First 2 | Select-Object -Last 1
$RefFolderLatest = (Get-ChildItem -Path $RefFolderRoot | Sort-Object -Descending) | Select-Object -First 1
$RefFilesLatest = Get-ChildItem -Path $RefFolderLatest.FullName | Where-Object {$_.Name -match "xml"}

#Build Change Log Folder:
$PreviousDate = $($RefFolderPrevious.name).Split("-") | Select-Object -Last 1
$LatestDate = $($RefFolderLatest.name).Split("-") | Select-Object -Last 1
$ChangeFolderName = "ChangeLogs-$($PreviousDate)-$($LatestDate)"
if (!(Test-Path -Path "$RefFolderRoot\$ChangeFolderName")){
    New-Item -Path "$RefFolderRoot\$ChangeFolderName" -ItemType Directory | Out-Null
}

$CompleteReportArrary = @()
 
foreach ($RefFile in $RefFilesLatest)
    {
    $Ref1 = $null
    $Ref2 = $null
    $NewDriverArrayList = $null
    $RemovedDriverArrayList = $null
    $NewDriverUpdates = $null
    $RemovedDriverUpdates = $null
    #Latest Reference File XML
    [XML]$Ref2 = Get-Content -Path $RefFile.FullName -Raw #Newer Version of Ref File
    
    #Get corrisponding XML from Previous build
    $PreviousRefFile = Get-ChildItem -Path $RefFolderPrevious.FullName | Where-Object {$_.Name -match $RefFile.Name}
    try {
        [XML]$Ref1 = Get-Content -Path $PreviousRefFile.FullName -Raw -ErrorAction SilentlyContinue
    }
    catch {}
    if (!($Ref1)){
        $Platform = $Ref2.ImagePal.SystemInfo.System.SystemID
        $OSVersion = $Ref2.ImagePal.SystemInfo.System.OSVersion
        Write-Host "Baseline Compare for $Platform | $OSVersion" -ForegroundColor Magenta
        Write-Host "There is no Previous Baseline, probably new Model" -ForegroundColor Cyan
    }
    else {
        #Build Data From XML Files    
        $Models = $Ref1.ImagePal.SystemInfo.System.ProductName
        $Platform = $Ref1.ImagePal.SystemInfo.System.SystemID
        $OSDescription = $Ref1.ImagePal.SystemInfo.System.OSDescription
        $OSBuildNumber = $Ref1.ImagePal.SystemInfo.System.OSBuildNumber
        $OSVersion = $Ref1.ImagePal.SystemInfo.System.OSVersion

        $Ref1Date = $Ref1.ImagePal.DateLastModified
        $Ref2Date = $Ref2.ImagePal.DateLastModified

        $UpdateInfo1 = $Ref1.ImagePal.Solutions.UpdateInfo | Where-Object {$_.Category -match "Driver" -and $_.Category -notmatch "Manageability"}
        $UpdateInfo2 = $Ref2.ImagePal.Solutions.UpdateInfo | Where-Object {$_.Category -match "Driver" -and $_.Category -notmatch "Manageability"}
        $OldSPs = $UpdateInfo1.Id
        $NewSPs = $UpdateInfo2.Id
        $DifferenceSPs = $NewSPs | Where-Object {$_ -notin $OldSPs}
        $DifferenceRemovedSPs = $OldSPs | Where-Object {$_ -notin $NewSPs}
        $NewDriverUpdates = $UpdateInfo2 | Where-Object {$_.Id -in $DifferenceSPs}
        $NewDriverUpdates = $NewDriverUpdates | Sort-Object -Property name

        $RemovedDriverUpdates = $UpdateInfo1 | Where-Object {$_.Id -in $DifferenceRemovedSPs}
        $RemovedDriverUpdates = $RemovedDriverUpdates | Sort-Object -Property name


        $UpdateInfoBIOS1 = $Ref1.ImagePal.Solutions.UpdateInfo | Where-Object {$_.Category -match "BIOS"}
        $UpdateInfoBIOS2 = $Ref2.ImagePal.Solutions.UpdateInfo | Where-Object {$_.Category -match "BIOS"}
        $OldSPBIOSs = $UpdateInfoBIOS1.Id
        $NewSPBIOSs = $UpdateInfoBIOS2.Id
        $DifferenceSPBIOSs = $NewSPBIOSs | Where-Object {$_ -notin $OldSPBIOSs}
        $NewBIOSUpates = $UpdateInfoBIOS2 | Where-Object {$_.Id -in $DifferenceSPBIOSs}

        #Display Results
        Write-Host "Baseline Compare for $Platform | $OSVersion" -ForegroundColor Magenta
        Write-Host "Previous Baseline Date: $Ref1Date vs Current Baseline Date: $Ref2Date" -ForegroundColor Cyan
        Write-Host $Models
        if (($NewDriverUpdates) -or ($RemovedDriverUpdates)-or ($NewBIOSUpates)){
            Write-Host "Driver Changes:" -ForegroundColor Gray
            $SPInventory = New-Object -TypeName PSObject
	        $SPInventory | Add-Member -MemberType NoteProperty -Name "Platform" -Value "$Platform" -Force
            $SPInventory | Add-Member -MemberType NoteProperty -Name "Model" -Value "$Models" -Force
	        $SPInventory | Add-Member -MemberType NoteProperty -Name "OSVersion" -Value "$OSVersion" -Force
            $SPInventory | Add-Member -MemberType NoteProperty -Name "FileName" -Value "$($RefFile.Name)" -Force
	        $SPInventory | Add-Member -MemberType NoteProperty -Name "Previous" -Value "$Ref1Date" -Force
	        $SPInventory | Add-Member -MemberType NoteProperty -Name "Latest" -Value "$Ref2Date" -Force	
        
            $NewDriverArray = @()
            if ($NewDriverUpdates){
                Write-Host " New Driver Changes:" -ForegroundColor Gray
                foreach ($NewDriver in $NewDriverUpdates){
                    $tempdriver = New-Object -TypeName PSObject
                    [String]$SoftpaqID = $NewDriver.Id
                    [String]$SoftpaqName = $NewDriver.Name
                    [int]$PadSize = 75 - ($SoftpaqName.Length)
                    [string]$Pad = ''.PadLeft($PadSize)
                    [String]$SoftpaqVersion = $NewDriver.Version
                    $tempdriver | Add-Member -MemberType NoteProperty -Name "SoftpaqID" -Value "$SoftpaqID" -Force
                    $tempdriver | Add-Member -MemberType NoteProperty -Name "SoftpaqName" -Value "$SoftpaqName" -Force
                    $tempdriver | Add-Member -MemberType NoteProperty -Name "SoftpaqVersion" -Value "$SoftpaqVersion" -Force
                    if ($SoftpaqID.Length -eq 7){[string]$PadSP = ''.PadLeft(1)}
                    else {[string]$PadSP = ''}
                    Write-Host "  $SoftpaqID $PadSP |  $SoftpaqName $Pad | $SoftpaqVersion" -ForegroundColor Gray
                    $NewDriverArray += $tempdriver

                }
                [System.Collections.ArrayList]$NewDriverArrayList = $NewDriverArray
                $SPInventory | Add-Member -MemberType NoteProperty -Name "NewDriverList" -Value $NewDriverArrayList -Force	
            }
            $RemovedDriverArray = @()
            if ($RemovedDriverUpdates){
                Write-Host " Removed Drivers:" -ForegroundColor Gray
                foreach ($RemovedDriver in $RemovedDriverUpdates){
                    $tempdriver = New-Object -TypeName PSObject
                    [String]$SoftpaqID = $RemovedDriver.Id
                    [String]$SoftpaqName = $RemovedDriver.Name
                    [int]$PadSize = 75 - ($SoftpaqName.Length)
                    [string]$Pad = ''.PadLeft($PadSize)
                    [String]$SoftpaqVersion = $RemovedDriver.Version
                    $tempdriver | Add-Member -MemberType NoteProperty -Name "SoftpaqID" -Value "$SoftpaqID" -Force
                    $tempdriver | Add-Member -MemberType NoteProperty -Name "SoftpaqName" -Value "$SoftpaqName" -Force
                    $tempdriver | Add-Member -MemberType NoteProperty -Name "SoftpaqVersion" -Value "$SoftpaqVersion" -Force
                    if ($SoftpaqID.Length -eq 7){[string]$PadSP = ''.PadLeft(1)}
                    else {[string]$PadSP = ''}
                    Write-Host "  $SoftpaqID $PadSP |  $SoftpaqName $Pad | $SoftpaqVersion" -ForegroundColor Gray
                    $RemovedDriverArray += $tempdriver

                }
                [System.Collections.ArrayList]$RemovedDriverArrayList = $RemovedDriverArray
                $SPInventory | Add-Member -MemberType NoteProperty -Name "RemovedDriverList" -Value $RemovedDriverArrayList -Force	
            }
            $NewBIOSArray = @()
            if ($NewBIOSUpates){
                $tempbios = New-Object -TypeName PSObject
                Write-Host "BIOS Changes:" -ForegroundColor Gray
                [String]$SoftpaqID = $NewBIOSUpates.Id
                [String]$SoftpaqName = $NewBIOSUpates.Name
                [int]$PadSize = 75 - ($SoftpaqName.Length)
                [string]$Pad = ''.PadLeft($PadSize)
                [String]$SoftpaqVersion = $NewBIOSUpates.Version
                $tempbios | Add-Member -MemberType NoteProperty -Name "SoftpaqID" -Value "$SoftpaqID" -Force
                $tempbios | Add-Member -MemberType NoteProperty -Name "SoftpaqName" -Value "$SoftpaqName" -Force
                $tempbios | Add-Member -MemberType NoteProperty -Name "SoftpaqVersion" -Value "$SoftpaqVersion" -Force
                if ($SoftpaqID.Length -eq 7){[string]$PadSP = ''.PadLeft(1)}
                else {[string]$PadSP = ''}
                Write-Host "  $SoftpaqID $PadSP |  $SoftpaqName $Pad | $SoftpaqVersion" -ForegroundColor Gray
                $NewBIOSArray += $tempbios
                $SPInventory | Add-Member -MemberType NoteProperty -Name "NewBIOSList" -Value $NewBIOSArray -Force	

            }
        $OutFileName = $($RefFile.Name).Replace("xml","json")
        $SPInventory | ConvertTo-Json | Out-File "$RefFolderRoot\$ChangeFolderName\$OutFileName" -Force
        $CompleteReportArrary += $SPInventory
        }
    }
}

$CompleteReportArrary | ConvertTo-Json -Depth 10 | Out-File "$RefFolderRoot\$ChangeFolderName\_CompleteList.json" -Force

<# OLD CODE

$RefFile1 = "D:\HPIA-ReferenceFiles\ReferenceFiles-20230308\8895_64_11.0.21H2.xml"  #XML created 2022.09.26
$RefFile2 = "D:\HPIA-ReferenceFiles\ReferenceFiles-20230921\8895_64_11.0.21H2.xml" #XML created 2023.01.13



[XML]$Ref1 = Get-Content -Path $RefFile1 -Raw
[XML]$Ref2 = Get-Content -Path $RefFile2 -Raw

$Models = $Ref1.ImagePal.SystemInfo.System.ProductName
$Platform = $Ref1.ImagePal.SystemInfo.System.SystemID
$OSDescription = $Ref1.ImagePal.SystemInfo.System.OSDescription
$OSBuildNumber = $Ref1.ImagePal.SystemInfo.System.OSBuildNumber
$OSVersion = $Ref1.ImagePal.SystemInfo.System.OSVersion

$Ref1Date = $Ref1.ImagePal.DateLastModified
$Ref2Date = $Ref2.ImagePal.DateLastModified

$UpdateInfo1 = $Ref1.ImagePal.Solutions.UpdateInfo | Where-Object {$_.Category -match "Driver"}
$UpdateInfo2 = $Ref2.ImagePal.Solutions.UpdateInfo | Where-Object {$_.Category -match "Driver"}
$OldSPs = $UpdateInfo1.Id
$NewSPs = $UpdateInfo2.Id
$DifferenceSPs = $NewSPs | Where-Object {$_ -notin $OldSPs}
$NewDriverUpdates = $UpdateInfo2 | Where-Object {$_.Id -in $DifferenceSPs}
$NewDriverUpdates = $NewDriverUpdates | Sort-Object -Property name


$UpdateInfoBIOS1 = $Ref1.ImagePal.Solutions.UpdateInfo | Where-Object {$_.Category -match "BIOS"}
$UpdateInfoBIOS2 = $Ref2.ImagePal.Solutions.UpdateInfo | Where-Object {$_.Category -match "BIOS"}
$OldSPBIOSs = $UpdateInfoBIOS1.Id
$NewSPBIOSs = $UpdateInfoBIOS2.Id
$DifferenceSPBIOSs = $NewSPBIOSs | Where-Object {$_ -notin $OldSPBIOSs}
$NewBIOSUpates = $UpdateInfoBIOS2 | Where-Object {$_.Id -in $DifferenceSPBIOSs}


<#Manual Verficiation - Run these 3 and ensure the $NewDriverUpdates are correct
$NewDriverUpdates | Select-Object -Property name, Version, id | Sort-Object -Property name
$UpdateInfo1 | Select-Object -Property name, Version, id | Sort-Object -Property name
$UpdateInfo2 | Select-Object -Property name, Version, id | Sort-Object -Property name
#>

<# OLD CODE
Write-Host "Baseline Compare for $Platform | $OSVersion" -ForegroundColor Magenta
Write-Host "Previous Baseline Date: $Ref1Date vs Current Baseline Date: $Ref2Date" -ForegroundColor Cyan
Write-Host "Driver Changes:" -ForegroundColor Gray


if ($NewDriverUpdates){
    foreach ($NewDriver in $NewDriverUpdates){
        [String]$SoftpaqID = $NewDriver.Id
        [String]$SoftpaqName = $NewDriver.Name
        [int]$PadSize = 55 - ($SoftpaqName.Length)
        [string]$Pad = ''.PadLeft($PadSize)
        [String]$SoftpaqVersion = $NewDriver.Version
        Write-Host " $SoftpaqID  |  $SoftpaqName $Pad | $SoftpaqVersion" -ForegroundColor Gray
    }
}

if ($NewBIOSUpates){
    Write-Host "BIOS Changes:" -ForegroundColor Gray
    [String]$SoftpaqID = $NewBIOSUpates.Id
    [String]$SoftpaqName = $NewBIOSUpates.Name
    [int]$PadSize = 55 - ($SoftpaqName.Length)
    [string]$Pad = ''.PadLeft($PadSize)
    [String]$SoftpaqVersion = $NewBIOSUpates.Version
    Write-Host " $SoftpaqID  |  $SoftpaqName $Pad | $SoftpaqVersion" -ForegroundColor Gray
}




<#  Testing different idea
$Superseded = $Ref2.ImagePal.'Solutions-Superseded'.UpdateInfo
$SupersededSPs = $Superseded.Supersedes
$SupersededIds = $Superseded.Id
$SupersededFromLastRun =@()
foreach ($OldSP in $OldSPs){
    if ($SupersededSPs -contains $OldSP){
        Write-Output $OldSP
        $SupersededFromLastRun += $OldSP

    }
}
$SSItems = $Superseded | Where-Object {$_.Supersedes -in $SupersededFromLastRun}

#>
