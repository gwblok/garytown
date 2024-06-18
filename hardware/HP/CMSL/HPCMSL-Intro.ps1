<# CMSL Basics
https://developers.hp.com/hp-client-management/doc/client-management-script-library

Most things in CMSL revolve around the HP Platform Code (Baseboard Product)
(Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product

To do automation, you'll need to know the Platform for the different devices you want to pull softpaqs or learn information about.

#Examples:  
-  Building a Custom Driver Pack: https://garytown.com/hpcmsl-new-hpdriverpack
-  Creating Offline HPIA Repository: https://garytown.com/osd-hp-image-assistant-revisited-offline-hpia-repo-in-cm-packages


#>

#Basics (To use on a different Model (Platform), use the -Platform parameter and product code for that platfrom

# Getting Information about the device it runs on
Get-HPDeviceDetails

#Find the Platform Code for the device based on Model Name
Get-HPDeviceDetails -Like "*EliteBook*G11*"
Get-HPDeviceDetails -like "ProDesk*400*G5*"

#Get all HP Comercial Devices in a List
Get-HPDeviceDetails -Like "*"

# Get List of Windows Builds support by device
Get-HPDeviceDetails -OSList

# Get List of Softpaq Updates for the device
Get-SoftpaqList #(uses the current OS & Build of the platform it is running on)

# Get List of Softpaq Updates for a specific platform and specific OS & Build
Get-SoftpaqList -Platform 8870 -Os win11 -OsVer 23H2

#Get the Max OS & OSVer Supported OS for a Device (Plaform = 8549 - HP EliteBook 840 G6):
$Platform = '8549'
$MaxOSSupported = ((Get-HPDeviceDetails -platform $Platform -oslist).OperatingSystem | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
$MaxOSVer = ((Get-HPDeviceDetails -platform $Platform -oslist | Where-Object {$_.OperatingSystem -eq "$MaxOSSupported"}).OperatingSystemRelease | Measure-Object -Maximum).Maximum
Write-Output "Max OS Supported: $MaxOSSupported $MaxOSVer"

#Region Find Latest Driver Pack for a Device (Plaform = 8549 - HP EliteBook 840 G6)
#This is because HP might support newer OS's with updates, but the driver pack might not be updated for that OS
$Platform = '8549'
if (((Get-HPDeviceDetails -platform $Platform -OSList).OperatingSystem) -contains "Microsoft Windows 11"){
    #Get the supported Builds for Windows 11 so we can loop through them
    $SupportedWinXXBuilds = (Get-HPDeviceDetails -platform $Platform -OSList| Where-Object {$_.OperatingSystem -match "11"}).OperatingSystemRelease | Sort-Object -Descending
    if ($SupportedWinXXBuilds){
        write-output "Checking for Win11 Driver Pack"
        [int]$Loop_Index = 0
        do {
            Write-Output "Checking for Driver Pack for $OS $($SupportedWinXXBuilds[$loop_index])"
            $DriverPack = Get-SoftpaqList -Platform $Platform -Category Driverpack -OsVer $($SupportedWinXXBuilds[$loop_index]) -Os "Win11" -ErrorAction SilentlyContinue
            if (!($DriverPack)){$Loop_Index++;}
            if ($DriverPack){
                Write-Host -ForegroundColor Green "Windows 10 $($SupportedWinXXBuilds[$loop_index]) Driver Pack Found"
            }
        }
        while ($null-eq $DriverPack  -and $loop_index -lt $SupportedWinXXBuilds.Count)
    }
}

if (!($DriverPack)){ #If no Win11 Driver Pack found, check for Win10 Driver Pack
    if (((Get-HPDeviceDetails -platform $Platform -OSList).OperatingSystem) -contains "Microsoft Windows 10"){
        #Get the supported Builds for Windows 10 so we can loop through them
        $SupportedWinXXBuilds = (Get-HPDeviceDetails -platform $Platform -OSList| Where-Object {$_.OperatingSystem -match "10"}).OperatingSystemRelease | Sort-Object -Descending
        if ($SupportedWinXXBuilds){
            write-output "Checking for Win10 Driver Pack"
            [int]$Loop_Index = 0
            do {
                Write-Output "Checking for Driver Pack for $OS $($SupportedWinXXBuilds[$loop_index])"
                $DriverPack = Get-SoftpaqList -Platform $Platform -Category Driverpack -OsVer $($SupportedWinXXBuilds[$loop_index]) -Os "Win10" -ErrorAction SilentlyContinue
                if (!($DriverPack)){$Loop_Index++;}
                if ($DriverPack){
                    Write-Host -ForegroundColor Green "Windows 10 $($SupportedWinXXBuilds[$loop_index]) Driver Pack Found"
                }
            }
            while ($null-eq $DriverPack  -and $loop_index -lt $SupportedWinXXBuilds.Count)
        }
    }
}
if ($DriverPack){
    Write-Host -ForegroundColor Green "Driver Pack Found: $($DriverPack.Name) for Platform: $Platform"
    $DriverPack
}
else {
    Write-Host -ForegroundColor Red "No Driver Pack Found for Platform: $Platform"
}
    #Example of looping through several models in ConfigMgr and populating their packages with Driver Packs
    #https://github.com/gwblok/garytown/blob/master/hardware/HP/Populate-CMPackage-HP-Drivers-WIM.ps1
#endregion

#region building a custom driver pack
#Building your own DriverPack with more updated softpaqs from the latest support OS
#https://developers.hp.com/hp-client-management/blog/new-hp-cmsl-build-your-own-driver-pack-commands
$Platform = '8549' #(Plaform = 8549 - HP EliteBook 840 G6)
$BuildPath = "C:\DriverPack"
#Find Latest Supported OS
$MaxOSSupported = ((Get-HPDeviceDetails -platform $Platform -oslist).OperatingSystem | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
$MaxOSVer = ((Get-HPDeviceDetails -platform $Platform -oslist | Where-Object {$_.OperatingSystem -eq "$MaxOSSupported"}).OperatingSystemRelease | Measure-Object -Maximum).Maximum
#Convert OS to Match CMSL Parameter inputs
if ($MaxOSSupported -Match "11"){$MaxOS = "Win11"}
else {$MaxOS = "Win10"}
New-HPDriverPack -Platform $Platform -Os $MaxOS -OSVer $MaxOSVer -Path $BuildPath
#endregion


#Region BIOS

<#
There are two different Functions for BIOS Updates, Get-HPBIOSUpdates and Get-HPBIOSWindowsUpdate.
Get-HPBIOSUpdates is for getting the BIOS updates and flashing them
- Pulls directly from HP's BIOS Update Catalog
- If BIOS Security is enabled, you will need to provide a Password or Sure Admin payload file
- provides parameters to suspend Bitlocker
- Typically updates are available in the HP Catalog before the Microsoft Catalog

Get-HPBIOSWindowsUpdate is for getting the BIOS updates and flashing them using the Windows Update method.
- Downloads from Microsoft Catalog
- Bypasses BIOS Security (Passwords and Sure Admin)
- Automatically will suspend bitlocker
- Typically takes longer for updates to be available in the Microsoft Catalog
  - This can be a good thing, as by the time it will show up in WU, it will have had longer time for testing and validation
#>

#Get Current BIOS Information on Current Machine
Get-HPBIOSVersion

#Get Current Machine if BIOS Update Available
# https://developers.hp.com/hp-client-management/doc/get-hpbiosupdates
Get-HPBIOSUpdates -Check
#True = BIOS Update Available
#False = No BIOS Update Available

#Update BIOS on Current Machine
Get-HPBIOSUpdates -Flash

#Downgrade BIOS on Current Machine
Get-HPBIOSUpdates -Flash -Version "01.26.00" -Force
#NOTE, you can use Get-HPBIOSUpdates -Check to see what versions are available to downgrade to, and it will prompt user to approve upon reboot.

# There are several ways to get the latest BIOS for a device and update it
$Platform = '8881' #(HP EliteDesk 805 G8 Desktop Mini PC)

#Get List of BIOS Updates for a device
Get-HPBIOSUpdates -Platform $Platform

#Updating BIOS with Encpassulated update (Get-HPBIOSWindowsUpdate)
# https://developers.hp.com/hp-client-management/doc/get-hpbioswindowsupdate

#Get List of BIOS Updates for a device
Get-HPBIOSWindowsUpdate

#Update BIOS on Current Machine
Get-HPBIOSWindowsUpdate -Flash



#endregion