<#  Addon Enhancement for HP Devices using MSEndpointMgr's Enhanced Inventory
https://msendpointmgr.com/2022/01/17/securing-intune-enhanced-inventory-with-azure-function/

I ASSUME you already set that up and have it working, if not, this will not work.  Once you have that setup, you can implement this ADD ON.


.Requirements
IUS from HP is setup on endpoint

HPIA Script has already run before this: https://github.com/gwblok/garytown/blob/master/Intune/EndMgrEnhancedInventoryAddon_HPIA.ps1


.ChangeLog
      23.10.09.01 - Intial Release
#>

#region IUS Compliance


$CollectIUSStatusInventory = $true 
$IUSStatusLogName = "IUSStatusInventory"

$IUSInventory = New-Object -TypeName PSObject
$IUSInventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
$IUSInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
$IUSInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
$IUSInventory | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force

$IntelligentUpdateRegKeyPath = "HKLM:\SOFTWARE\HP\IntelligentUpdate"
$IUSAnalysisReportingRegKeyPath = "HKLM:\SOFTWARE\HP\IntelligentUpdate\IUSAnalysisReporting"

$SkipItmes = @("ExecutionStatus","LatestRunStartTime")

if (Test-Path $IntelligentUpdateRegKeyPath){
    $IntelligentUpdateRegKey = Get-Item -Path $IntelligentUpdateRegKeyPath
    ForEach ($Setting in $IntelligentUpdateRegKey.Property){
        if ($Setting -notin $SkipItmes){
            $SettingName = $Setting
            $SettingValue = $IntelligentUpdateRegKey.GetValue($Setting)
            $IUSInventory | Add-Member -MemberType NoteProperty -Name $SettingName -Value $SettingValue -Force
        }
    }
}

if (Test-Path $IUSAnalysisReportingRegKeyPath){
    $IUSAnalysisReportingRegKey = Get-Item -Path $IUSAnalysisReportingRegKeyPath
    #$IUSAnalysisReportingRegKey = $IUSAnalysisReportingRegKey | Where-Object {$_.Property -notmatch "ExecutionStatus"}
    
    ForEach ($Setting in $IUSAnalysisReportingRegKey.Property){
        if ($Setting -notin $SkipItmes){
            $SettingName = $Setting
            $SettingValue = $IUSAnalysisReportingRegKey.GetValue($Setting)
            $IUSInventory | Add-Member -MemberType NoteProperty -Name $SettingName -Value $SettingValue -Force
        }
    }
}

if (!((Test-Path $IUSAnalysisReportingRegKeyPath) -or (Test-Path $IntelligentUpdateRegKeyPath))){
    $CollectIUSStatusInventory = $false 
} 

if ($CollectIUSStatusInventory) {
	$LogPayLoad | Add-Member -NotePropertyMembers @{$IUSStatusLogName = $IUSInventory}
}
#endregion
