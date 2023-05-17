$DCM = (Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT * FROM SMS_InstalledSoftware where ARPDisplayName like 'Dell Command%'").ProductVersion
$Manufacturer = (Get-WmiObject -Class:Win32_ComputerSystem).Manufacturer
$ComputerModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model 
if ($Manufacturer -match "Dell")
    {
    $SystemTypeID = ((Get-CimInstance -Namespace root/DCIM/SYSMAN -ClassName DCIM_ComputerSystem).OtherIdentifyingInfo[2]).replace("DCIM:","")
    if ($DCM){Write-Output "$Manufacturer | $ComputerModel | $SystemTypeID | DCM: $DCM"}
    else{Write-Output "$Manufacturer | $ComputerModel | TypeID N\A | DCM N\A"}
    } 
