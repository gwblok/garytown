<#
GARY BLOK | @gwblok | GARYTOWN.COM

.SYNOPSIS
	Sets information for HP Dock Connection History
   
.DESCRIPTION 
    This script will record HP Dock connections into WMI
   
.Requirements
    Requires that you have the HP WMI Provider Installed to get information from the currently installed HP Dock


.LINK
	https://www.hp.com/us-en/solutions/client-management-solutions/download.html

.NOTES
   Releases
   23.05.22 - Origial Release

	
#>

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
    Write-Host "No Dock Connected"

}
