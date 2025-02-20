#Get a list of all Platforms
Get-HPDeviceDetails -Match *

#Find information based on Model Name
Get-HPDeviceDetails -Match "HP Z2 Mini G4"

#Find driver pack for your specific platform & OS Build
Get-SoftpaqList -Platform 8458 -Os win11 -OsVer 21H2 -Category Driverpack

