
$RefFile1 = "D:\HPIA-ReferenceFiles\ReferenceFiles-20230308\8895_64_11.0.21H2.xml"  #XML created 2022.09.26
$RefFile2 = "D:\HPIA-ReferenceFiles\ReferenceFiles-20230522\8895_64_11.0.21H2.xml" #XML created 2023.01.13


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
