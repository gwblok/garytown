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
Write-Host -ForegroundColor Magenta "Building Demos ver 25.4.21.12.39..... please wait...."
#Build Samples to display properly later
$Example1 = Get-HPDeviceDetails
$Example2 = Get-HPDeviceDetails -Like "*EliteBook*G11*"
$Example3 = Get-HPDeviceDetails -like "ProDesk*400*G5*"
$Example4 = Get-HPDeviceDetails -Like "*"
try {$Example5 = Get-HPDeviceDetails -OSList -erroraction SilentlyContinue
}
catch {
    Write-Host "Error getting OSList" -ForegroundColor Red
    $Example5 = $null
}
try {$Example6 = Get-SoftpaqList -erroraction SilentlyContinue}
catch {
    $Example6 = Get-SoftpaqList -os win11 -osver 22H2 -erroraction SilentlyContinue 
}   
$Example7 = Get-SoftpaqList -Platform 8870 -Os win11 -OsVer 23H2
$Example8 = Get-SoftpaqList -Platform 8870 -Os win11 -OsVer 23H2 -Category Driver | Where-Object {$_.Name -like "*Chipset*"}

# Getting Information about the device it runs on
write-host "---------------------------------------------" -ForegroundColor DarkMagenta
Write-Host "Get-HPDeviceDetails" -ForegroundColor Green
Read-Host -Prompt "Press Enter to continue"
#Get-HPDeviceDetails
Write-Output $Example1 | Out-Host
Write-Host ""
Read-Host -Prompt "Press Enter to continue"
#Find the Platform Code for the device based on Model Name
write-host "---------------------------------------------" -ForegroundColor DarkMagenta
Write-Host "Find the Platform Code for the device based on Model Name" -ForegroundColor Green
Write-Host 'Get-HPDeviceDetails -Like "*EliteBook*G11*"' -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to continue"
#Get-HPDeviceDetails -Like "*EliteBook*G11*"
Write-Output $Example2 | Out-Host
Write-Host 'That was: Get-HPDeviceDetails -Like "*EliteBook*G11*"' -ForegroundColor Cyan
Write-Host ""
Write-Host 'Get-HPDeviceDetails -like "ProDesk*400*G5*"' -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to continue"
#Get-HPDeviceDetails -like "ProDesk*400*G5*"
Write-Output $Example3 | Out-Host
Write-Host 'That was: Get-HPDeviceDetails -like "ProDesk*400*G5*"' -ForegroundColor Cyan
Write-Host ""
Read-Host -Prompt "Press Enter to continue"
#Get all HP Comercial Devices in a List
write-host "---------------------------------------------" -ForegroundColor DarkMagenta
Write-Host "Get all HP Commercial Devices in a List" -ForegroundColor Green
Write-Host 'Get-HPDeviceDetails -Like "*"' -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to continue"
#Get-HPDeviceDetails -Like "*"
Write-Output $Example4 | Out-Host
Write-Output "Counts:" $Example4.Count | Out-Host
Write-Host ""
Write-Host 'That was: Get-HPDeviceDetails -Like "*"' -ForegroundColor Cyan
Read-Host -Prompt "Press Enter to continue"
# Get List of Windows Builds support by device
write-host "---------------------------------------------" -ForegroundColor DarkMagenta
write-host "Get List of Windows Builds support by device" -ForegroundColor Green
Write-Host 'Get-HPDeviceDetails -OSList' -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to continue"
#Get-HPDeviceDetails -OSList
Write-Output $Example5 | Out-Host
Write-Host ""
Read-Host -Prompt "Press Enter to continue"
# Get List of Softpaq Updates for the device
write-host "---------------------------------------------" -ForegroundColor DarkMagenta
Write-Host "Get List of Softpaq Updates for the device" -ForegroundColor Green
Write-Host 'Get-SoftpaqList' -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to continue"
#Get-SoftpaqList #(uses the current OS & Build of the platform it is running on)
Write-Output $Example6 | Out-Host
Write-Host ""
Write-Host 'That was: Get-SoftpaqList' -ForegroundColor Cyan
Read-Host
# Get List of Softpaq Updates for a specific platform and specific OS & Build
write-host "---------------------------------------------" -ForegroundColor DarkMagenta
Write-Host "Get List of Softpaq Updates for a specific platform and specific OS & Build" -ForegroundColor Yellow
Write-Host 'Get-SoftpaqList -Platform 8870 -Os win11 -OsVer 23H2' -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to continue"
#Get-SoftpaqList -Platform 8870 -Os win11 -OsVer 23H2
Write-Output $Example7 | Out-Host
Write-Host 'That was: Get-SoftpaqList -Platform 8870 -Os win11 -OsVer 23H2' -ForegroundColor Cyan
Write-Host ""
Read-Host -Prompt "Press Enter to continue"
# Get List of Softpaq Updates for a specific platform and specific OS & Build
write-host "---------------------------------------------" -ForegroundColor DarkMagenta
Write-Host "Get List of Softpaq Updates for a specific platform and specific OS & Build & Category" -ForegroundColor Yellow
Write-Host 'Get-SoftpaqList -Platform 8870 -Os win11 -OsVer 23H2 -Category Driver | Where-Object {$_.Name -like "*Chipset*"}' -ForegroundColor Yellow
Read-Host -Prompt "Press Enter to continue"
#Get-SoftpaqList -Platform 8870 -Os win11 -OsVer 23H2
Write-Output $Example8 | Out-Host
Write-Host 'That was: Get-SoftpaqList -Platform 8870 -Os win11 -OsVer 23H2 -Category Driver | Where-Object {$_.Name -like "*Chipset*"}' -ForegroundColor Cyan
Write-Host ""
Read-Host -Prompt "Press Enter to continue"

#Get the Max OS & OSVer Supported OS for a Device (Plaform = 8549 - HP EliteBook 840 G6):
write-host "---------------------------------------------" -ForegroundColor DarkMagenta
write-host "Get the Max OS & OSVer Supported OS for a Device (Plaform = 8549 - HP EliteBook 840 G6)" -ForegroundColor Green
Read-Host -Prompt "Press Enter to continue"
Write-Host -ForegroundColor yellow '
$Platform = "8549"
$MaxOSSupported = ((Get-HPDeviceDetails -platform $Platform -oslist).OperatingSystem | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
$MaxOSVer = ((Get-HPDeviceDetails -platform $Platform -oslist | Where-Object {$_.OperatingSystem -eq "$MaxOSSupported"}).OperatingSystemRelease | Measure-Object -Maximum).Maximum
Write-Output "Max OS Supported: $MaxOSSupported $MaxOSVer"
'
Read-Host -Prompt "Press Enter to continue"
$Platform = '8549'
$MaxOSSupported = ((Get-HPDeviceDetails -platform $Platform -oslist).OperatingSystem | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
$MaxOSVer = ((Get-HPDeviceDetails -platform $Platform -oslist | Where-Object {$_.OperatingSystem -eq "$MaxOSSupported"}).OperatingSystemRelease | Measure-Object -Maximum).Maximum
Write-Output "Max OS Supported: $MaxOSSupported $MaxOSVer"
Read-Host -Prompt "Press Enter to continue"
#Region Find Latest Driver Pack for a Device (Plaform = 8549 - HP EliteBook 840 G6)
#This is because HP might support newer OS's with updates, but the driver pack might not be updated for that OS
write-host "---------------------------------------------" -ForegroundColor DarkMagenta
write-host "Find Latest Driver Pack for a Device (Plaform = 8549 - HP EliteBook 840 G6)" -ForegroundColor Green
write-host "this is because HP might support newer OS's with updates, but the driver pack might not be updated for that OS" -ForegroundColor Green
Write-Host ""
write-host "First, lets see if there is a Windows 11 Driver Pack available" -ForegroundColor Green
Read-Host -Prompt "Press Enter to continue"
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
                Write-Host -ForegroundColor Green "Windows 11 $($SupportedWinXXBuilds[$loop_index]) Driver Pack Found"
            }
        }
        while ($null-eq $DriverPack  -and $loop_index -lt $SupportedWinXXBuilds.Count)
    }
}
write-host ""
Read-Host -Prompt "Press Enter to continue"
write-host "If no Win11 Driver Pack found, check for Win10 Driver Pack" -ForegroundColor Green
Read-Host -Prompt "Press Enter to continue"
write-host ""
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
Read-Host -Prompt "Press Enter to continue"
Write-Host -ForegroundColor Green '
#region building a custom driver pack
#Building your own DriverPack with more updated softpaqs from the latest support OS
#https://developers.hp.com/hp-client-management/blog/new-hp-cmsl-build-your-own-driver-pack-commands
'
Write-Host -ForegroundColor Yellow 'New-HPDriverPack -Platform $Platform -Os $MaxOS -OSVer $MaxOSVer -Path $BuildPath'
Read-Host -Prompt "Press Enter to continue"
$Platform = '8549' #(Plaform = 8549 - HP EliteBook 840 G6)
$BuildPath = "C:\DriverPack"
#Find Latest Supported OS
$MaxOSSupported = ((Get-HPDeviceDetails -platform $Platform -oslist).OperatingSystem | Where-Object {$_ -notmatch "LTSB"}| Select-Object -Unique| Measure-Object -Maximum).Maximum
$MaxOSVer = ((Get-HPDeviceDetails -platform $Platform -oslist | Where-Object {$_.OperatingSystem -eq "$MaxOSSupported"}).OperatingSystemRelease | Measure-Object -Maximum).Maximum
#Convert OS to Match CMSL Parameter inputs
if ($MaxOSSupported -Match "11"){$MaxOS = "Win11"}
else {$MaxOS = "Win10"}
New-HPDriverPack -Platform $Platform -Os $MaxOS -OSVer $MaxOSVer -Path $BuildPath -WhatIf
#endregion
Read-Host -Prompt "Press Enter to continue"

#Region BIOS
Write-Host -ForegroundColor Magenta '
<#
There are two different Functions for BIOS Updates, Get-HPBIOSUpdates and Get-HPBIOSWindowsUpdate.
Get-HPBIOSUpdates is for getting the BIOS updates and flashing them
- Pulls directly from HPs BIOS Update Catalog
- If BIOS Security is enabled, you will need to provide a Password or Sure Admin payload file
- provides parameters to suspend Bitlocker
- Typically updates are available in the HP Catalog before the Microsoft Catalog
- Uses HP Platform Code (Baseboard Product) to find BIOS updates

Get-HPBIOSWindowsUpdate is for getting the BIOS updates and flashing them using the Windows Update method.
- Downloads from Microsoft Catalog
- Bypasses BIOS Security (Passwords and Sure Admin)
- Automatically will suspend bitlocker
- Typically takes longer for updates to be available in the Microsoft Catalog
  - This can be a good thing, as by the time it will show up in WU, it will have had longer time for testing and validation
- Is based on the BIOS Family, not the Platform Code
  - Get-HPDeviceFamilyPlatformDetails will give you the Family for a Platform Code
#>

'
Read-Host -Prompt "Press Enter to continue"
write-host ""
write-host -ForegroundColor Green '
#Get Current BIOS Information on Current Machine & Latest Available
'
Write-Host -ForegroundColor Yellow 'Get-HPBIOSVersion'
Get-HPBIOSVersion | out-host
write-host -ForegroundColor Yellow 'Get-HPBIOSUpdates -Latest'
Get-HPBIOSUpdates -Latest | out-host
Write-Host ""
Read-Host -Prompt "Press Enter to continue"

write-host -ForegroundColor Green '
#Get Current Machine if BIOS Update Available
# https://developers.hp.com/hp-client-management/doc/get-hpbiosupdates
#True = NO BIOS Update Available | BIOS ALREADY UP TO DATE (OR NEWER THAN AVAILABLE)
#False = BIOS Update Available
'
Write-Host -ForegroundColor Yellow 'Get-HPBIOSUpdates -Check'
Get-HPBIOSUpdates -Check | out-host
Read-Host -Prompt "Press Enter to continue"
Write-Host -ForegroundColor Green '
#Update BIOS on Current Machine
'
Write-Host -ForegroundColor Yellow 'Get-HPBIOSUpdates -Flash'
#Get-HPBIOSUpdates -Flash
Write-Host "Maybe in the future, but not now" -ForegroundColor Red

Read-Host -Prompt "Press Enter to continue"
write-host -ForegroundColor Green '
#Downgrade BIOS on Current Machine
Get-HPBIOSUpdates -Flash -Version "01.26.00" -Force
#NOTE, you can use Get-HPBIOSUpdates to see what versions are available to downgrade to, and it will prompt user to approve upon reboot.
'
Read-Host -Prompt "Press Enter to continue"

Write-Host -ForegroundColor Green '
# There are several ways to get the latest BIOS for a device and update it
$Platform = "8881" #(HP EliteDesk 805 G8 Desktop Mini PC)

#Get List of BIOS Updates for a device
'
Write-Host -ForegroundColor Yellow 'Get-HPBIOSUpdates -Platform $Platform'
$Platform = '8881'
Get-HPBIOSUpdates -Platform $Platform | out-host

Read-Host -Prompt "Press Enter to continue"

Write-Host -ForegroundColor Green '
#Updating BIOS with Encpassulated update (Get-HPBIOSWindowsUpdate)
# https://developers.hp.com/hp-client-management/doc/get-hpbioswindowsupdate

#Get List of BIOS Updates for a device
'
Write-Host -ForegroundColor Yellow 'Get-HPBIOSWindowsUpdate'
Get-HPBIOSWindowsUpdate | out-host
Write-Host ""
Read-Host -Prompt "Press Enter to continue"
Write-Host -ForegroundColor Green '
#Update BIOS on Current Machine
'
Write-Host -ForegroundColor Yellow 'Get-HPBIOSWindowsUpdate -Flash'
#Get-HPBIOSWindowsUpdate -Flash
Write-Host "Maybe in the future, but not now" -ForegroundColor Red
Read-Host -Prompt "Press Enter to continue"

Write-Host -ForegroundColor Green '
#Notification Demo
Write-host "Notification Demo" -ForegroundColor Cyan
$script:ToastBase64Image = "iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAMAAABHP [example base64 image]"
$script:logopath = "c:\programdata\toastlogo.png"
$script:bytes = [Convert]::FromBase64String($ToastBase64Image)
[IO.File]::WriteAllBytes($logopath , $bytes)

$script:param = @{
    Title = "Please Reboot"
    Message = "Security Changes Require a Reboot"
    LogoImage = $logopath
    TitleBarHeader = "GARYTOWN"
    TitleBarIcon = $logopath
}

Invoke-HPNotification @param
'
Read-Host -Prompt "Press Enter to continue"
#Notification Demo
Write-host ' Notification Demo' -ForegroundColor Cyan
$script:ToastBase64Image = 'iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAMAAABHPGVmAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAMAUExURRQAHQAACAAAGQAAKRMAKAECNhsFNQUXOhocOSgAKScDNjcDOCkbOjgbOx4gOTYiPiIjPUkAG2cAHEUAKVgCLUYHOFsDN0obO1gbPG8AI3UHOWkcOncbO1QiPnAhPgAERwIaRRYcQwMbUy8aQRM3TgElQxokRAElWBgnViYoRDgqQykzTDU2SyUrUis0VTU5WAc0ZRo2ZCQ/cSg7ZUsWQFYaQmIfQHsdQl02TkYlQVYmQkY3SkM7U3E3TGkmQ3gnQzFBTDpEVgBBYTJRbS1EajVLaitLdDNMdzZWfERDTUhIWFNHV0lTXFVUXWdIVWdXXHhVWUVJZE1TZ1lZY1VZcnlaYmZdZFNkeFtiaGZla3dpa2lpdHNudGhzdHh2eJcAHIIAIYUDNJgDNYcbO5ccO7MBMLoALacaO7kbOooiPpkkPqckPbkkPvUAAPUAHc8AJsgINdkAMcsYONgeOucBLvQAKfQHMugaOPQZNsgkPNckO+glO/QnO4EAQbIeQow0SYYoQ5UpQ7g1SKgqRLgmQaYxRcA7UsYoQdYrQvYpQOUsQfQ2QpFOWodFVaxQU4lZZLdaYZtqcohiaJRmaYV7e5R0dahpc6Z2drR7fMtDUsdZWvFNUfRGTPVXV9RuXcVUYuNWYdh8d+FiY/RpZvdzbPV5c3+AfoeCfquDf7iCdsqIfvaFezhZhDBtkjtkijxlkTp+pkFvj0FslkR2nG50gHt4hEh8pYV9hrF8gXyEg0+Qt0uFq0qNtFGOtlKSuGuUsHeivo+SkImIhpGNiZaTjZqXk7GSkaOHhKOdl52inKmwnaikm7OqnpqXobOYqZ6xvounuKiws6upo7Oto7m1qb27stSQi8WIidmblOSRgvaNhPaViuaamPWdl9OqnO+pnvWnmtC5s9SspcO7rdW6qMO8su23quu5qfO2qNfBrcrEttXKudrSv+3QuezCr+fIt/XFtJqzxdbOwdvVxePe0ePbyfPcyOrizfPkzuzm1PXs1f302+7s4PTv4vn05gAAAAA8zmUAAAEAdFJOU////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////wBT9wclAAAACXBIWXMAAA7CAAAOwgEVKEqAAAASTUlEQVRoQ+2ZfXxTZZbHJdeHe8U2ZEVs1ra0AVrm0rQdBwSrCHZ1pJRmFIJsQ2p2NB1aaBYVTG1eFssQ7Qu+jFLWUejuzoLNOEUYBUV56W6ThklJYbW5HVTstBojcG9smYaQJpeGOc9N0LY0LfrHfvazH8+nKUn6PM/3Oed3zrnPvdxw5X/BfoR8L/sR8r3s/zwkMnQ5Ens7vv1wSKirVVOiaeviQhOSfjDEr0qbmZ6WNjNN0caEYt/Fs4khlwOxNyPsckla9vLTxxuyZ2ZnK10TUCaGhNrdA5dj778zDonR9u5B3mdFSOaOfRnPriNcftWU1e2w10hkiL9qEa8IIL2D8JZz2q7dw0i7Hk26bv6XaWs6QtHlwSLwYmiKfKv3En7LswOxgfHseiC89fHb/+0llg8MMO12a1OTzXHC72Tk5CsPr2YxhPPGBsaziSGwWUY06/HHnV4ENmX6tGk337Pca/3T6u3LdzyEXBAxxh8bGs8mguB4hP255FRtMuP5zVNPPd346VlugO3acfqTT62n3ju1qI2x2SYqlPEhAoIpamdE0vKNt7X19zafO9/Rtv2uKbfddbrnc80A+8XqNcRcFRcbHs/GhWAGq0Lzy/pcxPQFZU89a2fafv/a9ntTq5975XRP2KNpeKiDtTsd7RO4Mh4EEAEburnsaX3l10wR0pZrbyAeeRg9Vr4w5d7Pu8+Bkz72G88au9rPj0+JD8FuMDL04n+++Vl3z9ngQBFBEsqvvnrruXUzkha+3P15T5j/0hc67ny1qQuyeyg2a0yLC4HCC7vsDOs773E5rNYdL7zwh0ce+uqtpKSKmnUp61/8/M8fXIDk7Tjff9znzO+CDcXmjWXxIEOD4XCAddtV96Bn33iu+t//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'
$script:logopath = "c:\programdata\toastlogo.png"
$script:bytes = [Convert]::FromBase64String($ToastBase64Image)
[IO.File]::WriteAllBytes($logopath , $bytes)

$script:param = @{
    Title = 'Please Reboot'
    Message = "Security Changes Require a Reboot"
    LogoImage = $logopath
    TitleBarHeader = "GARYTOWN"
    TitleBarIcon = $logopath
}

Invoke-HPNotification @param
Read-Host -Prompt "Press Enter to continue"
Write-Host -ForegroundColor Yellow 'Invoke-HPRebootNotification @Param'
Invoke-HPRebootNotification @param

#endregion
