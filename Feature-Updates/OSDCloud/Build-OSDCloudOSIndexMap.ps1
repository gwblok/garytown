Import-Module -name OSD

$Indexes = @()
$ESDFilesX64Indexes = Get-OSDCloudOperatingSystemsIndexes -OSArch x64
$ESDFilesARM64Indexes = Get-OSDCloudOperatingSystemsIndexes -OSArch ARM64

$Indexes += $ESDFilesX64Indexes
$Indexes += $ESDFilesARM64Indexes


$ImageIndexDB = @()
$Builds = $Indexes.Build | Select-Object -Unique
$LatestBuild = $Builds | Sort-Object -Descending | Select-Object -First 1

$CapturePool = $Indexes | Where-Object {$_.Build -eq $LatestBuild}


foreach ($Index in $CapturePool){
    $SaveData = $Index | Select-Object -Property Architecture, Language, Activation, Indexes, IndexNames, TotalIndexes
    $ImageIndexDB += $SaveData
}

$ImageIndexDB | Export-Clixml -Path (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "Catalogs\CloudOperatingIndexMap.xml") -Force
Import-Clixml -Path (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "Catalogs\CloudOperatingIndexMap.xml") | ConvertTo-Json | Out-File (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "Catalogs\CloudOperatingIndexMap.json") -Encoding ascii -Width 2000 -Force
