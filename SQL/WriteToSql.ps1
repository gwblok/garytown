#Declare Servername

$sqlServer=$env:COMPUTERNAME
#Invoke-sqlcmd Connection string parameters
$Database = 'test'
$Server = 'localhost'
$params = @{'server'=$Server;'Database'=$Database}
$TableName_Disks = 'AEM_CMDiskStats'
$TableName_Services = 'AEM_CMServiceStats'
#Fucntion to manipulate the data
Function Write-DiskData
{
param($tablename,$UID,$server,$devId,$volName,$frSpace,$totSpace)
 $totSpace=[math]::Round(($totSpace/1073741824),2)
 $frSpace=[Math]::Round(($frSpace/1073741824),2)
 $usedSpace = $totSpace - $frspace
 $usedSpace=[Math]::Round($usedSpace,2)
# Data preparation for loading data into SQL table 
$InsertResults = @"
INSERT INTO [$Database].[dbo].[$tablename](UID,SystemName,DeviceID,VolumeName,TotalSize,FreeSize,UsedSize)
VALUES ('$UID','$SERVER','$devId','$volName',$totSpace,$frSpace,$usedSpace)
"@      
#call the invoke-sqlcmdlet to execute the query
         Invoke-sqlcmd @params -Query $InsertResults
}
 
Function Write-ServiceData
{
param($tablename,$UID,$server,$SDN,$Name,$Status,$StartType)
# Data preparation for loading data into SQL table 
$InsertResults = @"
INSERT INTO [$Database].[dbo].[$tablename](UID,SystemName,DisplayName,Name,Status,StartType)
VALUES ('$UID','$SERVER','$SDN','$Name','$Status','$StartType')
"@      
#call the invoke-sqlcmdlet to execute the query
         Invoke-sqlcmd @params -Query $InsertResults
}

Function Create-SQLTable_Disk {
param($tablename)
$NewTable = @"
 CREATE TABLE $tablename
(
[UID] int not null,
[SystemName] VARCHAR(40) not null,
[DeviceID] VARCHAR(40) not null,
[VolumeName] VARCHAR(40) not null,
[TotalSize] int not null,
[FreeSize] int not null,
[UsedSize] int not null
)
"@
 
 Invoke-sqlcmd @params -Query $NewTable
 }
Function Create-SQLTable_Services {
param($tablename)
$NewTable = @"
 CREATE TABLE $tablename
(
[UID] int not null,
[SystemName] VARCHAR(40) not null,
[DisplayName] VARCHAR(40) not null,
[Name] VARCHAR(40) not null,
[Status] VARCHAR(40) not null,
[StartType] VARCHAR(40) not null
)
"@
 
 Invoke-sqlcmd @params -Query $NewTable
 }
Function Drop-SQLTable {
param($tablename)
$droptable = @"
DROP TABLE $tablename
"@
Invoke-sqlcmd @params -Query $droptable -ErrorAction SilentlyContinue
}


## Start Script Execution ##

#region SQL Table Reset
try {
    Drop-SQLTable $TableName_Services 
    Drop-SQLTable $TableName_Disks  
}
catch {}

Create-SQLTable_Disk $TableName_Disks
Create-SQLTable_Services $TableName_Services
#endregion

#region Disk Information
#Query WMI query to store the result in a varaible
$dp = Get-WmiObject win32_logicaldisk -ComputerName $sqlServer|  Where-Object {$_.drivetype -eq 3}
 
#Loop through array
$UID = 0
foreach ($item in $dp)
{
$UID ++
#Call the function to transform the data and prepare the data for insertion
Write-DiskData $TableName_Disks $UID $sqlServer $item.DeviceID $item.VolumeName $item.FreeSpace $item.Size
}

#endregion Disk Information


#region Service Information
#Query the destination table to view the result

$Services = @("IISADMIN","CcmExec","SMS_EXECUTIVE","SMS_SITE_COMPONENT_MANAGER","SMS_SITE_VSS_WRITER","SQLSERVERAGENT","W3SVC")
$ServiceStatus = Get-Service | Where-Object {$_.Name -in $Services}
#Loop through array
$UID = 0
foreach ($Status in $ServiceStatus)
{
$UID ++
$CurStatus = $Status.Status
$CurStartType = $Status.StartType
#Call the function to transform the data and prepare the data for insertion
Write-ServiceData $TableName_Services $UID $sqlServer $Status.DisplayName $Status.Name $CurStatus $CurStartType
}


#endregion

Invoke-Sqlcmd @params -Query "SELECT  * FROM $TableName_Services" | format-table -AutoSize
Invoke-Sqlcmd @params -Query "SELECT  * FROM $TableName_Disks" | format-table -AutoSize

#Invoke-Sqlcmd @params -Query "SELECT  * FROM tbl_PosHdisk" | format-table -AutoSize
