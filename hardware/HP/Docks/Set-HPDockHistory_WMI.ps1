<#
GARY BLOK | @gwblok | GARYTOWN.COM

.SYNOPSIS
	Sets information for HP Dock Connection History
   
.DESCRIPTION 
    This script will record HP Dock connections into WMI
    This script only supports HP Docks that are supported by the WMI Provider
   
.Requirements
    Requires that you have the HP WMI Provider Installed to get information from the currently installed HP Dock


.LINK
	https://www.hp.com/us-en/solutions/client-management-solutions/download.html

.NOTES
   Releases
   23.05.22 - Originial Release
   23.05.30 - Added Generic Dock lookup for non WMI Supported Docks.. just for Messaging, it doesn't inventory them

	
#>

#region Functions
function Get-HPDockInfo {
    <#
        Dock f/w checker
        Dan Felman/HP Inc
        March 24, 2023
        Version 01.00.00 Reports if an HP Dock is attached
                01.00.01 Add PID for Universal DOck, USB-C Dock G4

        Supports the follwing docks:
            USB-C G4 - VID_03F0&PID_484A
            USB-C G5 - VID_03F0&PID_046B - Adicora A
            USB-C G5 Essential Dock - VID_03F0&PID_379D -  Adicora R
            USB-C Universal - VID_17E9&PID_600A
            USB-C Universal G2 - VID_03F0&PID_0A6B - Adicora D
            TB G2 Dock - VID_03F0&PID_0667 - Hook    
            TB G4 Dock - VID_03F0&PID_0488 - Hook2
            HP E24d G4 FHD Docking Monitor - VID_03F0&PID_056D - Hughes /24
            HP E27d G4 QHD Docking Monitor - VID_03F0&PID_016E - Hughes /27
        Returns
            0 - NO HP dock found attached
            1 - 'HP Thunderbolt Dock G4'
            2 - 'HP Thunderbolt Dock G2' 
            3 - 'HP USB-C Dock G4' 
            4 - 'HP USB-C Dock G5' 
            5 - 'HP USB-C Universal Dock' 
            6 - 'HP USB-C Universal Dock G2' 
            7 - 'HP E24d G4 FHD Docking Monitor'
            8 - 'HP E27d G4 QHD Docking Monitor'
            9 - 'HP USB-C G5 Essential Dock'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$DebugOutput
    ) # param

    $ScriptVersion = '01.00.01 - Mar 30, 2023'
    #'Script Version: '+$ScriptVersion | Out-Host
    $CurrLoc = Get-Location
    #$ScriptPath = Split-Path $MyInvocation.MyCommand.Path

    #Set-Location $ScriptPath'\'$OCI_Path        # path to FW OCI updater folder

    #######################################################################################

        #'-- Reading signed drivers list - use to scan for attached HP docks'
        $PnpSignedDrivers = Get-CimInstance win32_PnpSignedDriver 
        $Dock_ProductName = 'none'
        $Dock_Attached = 0
        #'-- Searching for attached HP docks'
        # Find out if a Dock is connected - assume a single dock, so stop at first find
        foreach ( $iDriver in $PnpSignedDrivers ) {
            $f_InstalledDeviceID = "$($iDriver.DeviceID)"   # analyzing current device
            $Dock_ProductName = $null
            if ( ($f_InstalledDeviceID -match "HID\\VID_03F0") -or ($f_InstalledDeviceID -match "USB\\VID_17E9") ) {
                $DockDriver = $iDriver
                switch -Wildcard ( $f_InstalledDeviceID ) {
                    '*PID_0488*' { $Dock_Attached = 1 ; $Dock_ProductName = 'HP Thunderbolt Dock G4'}
                    '*PID_0667*' { $Dock_Attached = 2 ; $Dock_ProductName = 'HP Thunderbolt Dock G2' }
                    '*PID_484A*' { $Dock_Attached = 3 ; $Dock_ProductName = 'HP USB-C Dock G4' }
                    '*PID_046B*' { $Dock_Attached = 4 ; $Dock_ProductName = 'HP USB-C Dock G5' }
                    '*PID_600A*' { $Dock_Attached = 5 ; $Dock_ProductName = 'HP USB-C Universal Dock' }
                    '*PID_0A6B*' { $Dock_Attached = 6 ; $Dock_ProductName = 'HP USB-C Universal Dock G2' }
                    '*PID_056D*' { $Dock_Attached = 7 ; $Dock_ProductName = 'HP E24d G4 FHD Docking Monitor' }
                    '*PID_016E*' { $Dock_Attached = 8 ; $Dock_ProductName = 'HP E27d G4 QHD Docking Monitor' }
                    '*PID_379D*' { $Dock_Attached = 9 ; $Dock_ProductName = 'HP USB-C G5 Essential Dock' }

                } # switch -Wildcard ( $f_InstalledDeviceID )
            } # if ( $f_InstalledDeviceID -match "VID_03F0")
            if ( $Dock_Attached -gt 0 ) { break }

        } # foreach ( $iDriver in $PnpSignedDrivers )

    #######################################################################################

    Set-Location $CurrLoc

    $Return = @(
        @{Dock_Attached = $Dock_Attached ;  Dock_ProductName = $Dock_ProductName}
    )
    return $Return

}

# Set Vars for WMI Info
[String]$Namespace = "HP\InstrumentedServices\v1"
[String]$Class = "HP_DockHistory"

# Does Namespace Already Exist?
Write-Verbose "Getting WMI namespace $Namespace"
$Root = $Namespace | Split-Path
$filterNameSpace = $Namespace.Replace("$Root\","")
$NSfilter = "Name = '$filterNameSpace'"
$NSExist = Get-WmiObject -Namespace "Root\$Root" -Class "__namespace" -filter $NSfilter

# Namespace Does Not Exist
If(!($NSExist)){
    Write-Host "Namespace $namespace does not exist, Make sure the 'HP Accessory WMI Provider' is already installed"
    Write-Host "Download from: https://www.hp.com/us-en/solutions/client-management-solutions/download.html"
    }



#endregion functions

# START SCRIPT
$classname = "HP_DockAccessory"
$ConnectedDock = Get-CimInstance -Class $classname  -Namespace "Root\$namespace" -ErrorAction SilentlyContinue

if ($ConnectedDock){
    Write-Host "Dock Connected: $($ConnectedDock.ProductName)"
    Write-Host "  SerialNumber: $($ConnectedDock.SerialNumber)"
    Write-Host "  FirmwarePackageVersion: $($ConnectedDock.FirmwarePackageVersion)"
    Write-Host "  MACAddress: $($ConnectedDock.MACAddress)"


   # Does Class Already Exist?
    Write-Verbose "Getting $Class Class"
    $ClassExist = Get-CimClass -Namespace root/$Namespace -ClassName $Class -ErrorAction SilentlyContinue
    # Class Does Not Exist
    If($ClassExist -eq $null){
        Write-Verbose "$Class class does not exist. Creating new class . . ."
        # Create Class
        $NewClass = New-Object System.Management.ManagementClass("root\$namespace", [string]::Empty, $null)
        $NewClass.name = $Class
        $NewClass.Qualifiers.Add("Static",$true)
        $NewClass.Qualifiers.Add("Description","HP Dock History Gathered from the HP WMI Provider")
        $NewClass.Properties.Add("SerialNumber",[System.Management.CimType]::String, $false)
        $NewClass.Properties.Add("FirmwarePackageVersion",[System.Management.CimType]::String, $false)
        $NewClass.Properties.Add("ProductName",[System.Management.CimType]::String, $false)
        $NewClass.Properties.Add("MACAddress",[System.Management.CimType]::String, $false)
        $NewClass.Properties.Add("LastDateTime",[System.Management.CimType]::DateTime, $false)
        $NewClass.Properties.Add("ID",[System.Management.CimType]::String, $false)
        $NewClass.Properties["ID"].Qualifiers.Add("Key",$true)
        $NewClass.Put()
        } 

    [String]$ProductName = $($ConnectedDock.ProductName)
    $ProductName = $ProductName.Replace(" ","")
    $ID = "$($ProductName)_$($ConnectedDock.SerialNumber)"

    #Get Time for CIM Format
    $time = (Get-Date)
    $objScriptTime = New-Object -ComObject WbemScripting.SWbemDateTime
    $objScriptTime.SetVarDate($time)
    $cimTime = $objScriptTime.Value

    #Create Instance in WMI Class
    $wmipath = 'root\'+$Namespace+':'+$class
    $WMIInstance = ([wmiclass]$wmipath).CreateInstance()
    $WMIInstance.SerialNumber = $ConnectedDock.SerialNumber
    $WMIInstance.FirmwarePackageVersion = $ConnectedDock.FirmwarePackageVersion
    $WMIInstance.ProductName = $ConnectedDock.ProductName
    $WMIInstance.MACAddress = $ConnectedDock.MACAddress
    $WMIInstance.LastDateTime = ($cimTime)
    $WMIInstance.ID = $ID
    $WMIInstance.Put()
    Clear-Variable -Name WMIInstance
}
else {
    Write-Host "No WMI Supported Dock Connected"
    $GenericDockInfo = Get-HPDockInfo
    if ($GenericDockInfo){
        Write-Host "$($GenericDockInfo.Dock_ProductName) attached, but does not support WMI Provider"
    }
}
