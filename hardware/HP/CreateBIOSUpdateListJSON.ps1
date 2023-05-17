$HPDevices = Get-HPDeviceDetails -match *
$BIOSUpdateHistory = @()
$Count = 0
foreach ($HPDevice in $HPDevices){
    $Count ++
    
    [String]$Model = $HPDevice.Name
    [String]$ProductID = $HPDevice.SystemID
    Write-Host "Recording $Count of $($HPDevices.Count) | $Model - $ProductID" -ForegroundColor Green
    $AvailableUpdates = Get-HPBIOSUpdates -Platform $ProductID -ErrorAction SilentlyContinue
    if ($AvailableUpdates){
        $ModelUpdateObject = [PSCustomObject]@{
        Model = $Model
        ProductID = $ProductID
        BIOSUpdates = [System.Collections.ArrayList]@()
        }
        foreach ($Update in $AvailableUpdates){
            [VOID]$ModelUpdateObject.BIOSUpdates.Add([PSCustomObject]@{
            Version = $Update.Ver
            Date = $UPdate.Date
            BIN = $Update.Bin
            })

        }
        $BIOSUpdateHistory += $ModelUpdateObject
    }
}

write-host "Creating JSON File"

$Json = $BIOSUpdateHistory | ConvertTo-Json -Depth 10 | Out-File C:\windows\Temp\HPBIOSJSON.JSON
