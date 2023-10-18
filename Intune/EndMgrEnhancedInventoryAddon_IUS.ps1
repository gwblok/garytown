<#  Addon Enhancement for HP Devices using MSEndpointMgr's Enhanced Inventory
https://msendpointmgr.com/2022/01/17/securing-intune-enhanced-inventory-with-azure-function/

I ASSUME you already set that up and have it working, if not, this will not work.  Once you have that setup, you can implement this ADD ON.


.Requirements
IUS from HP is setup on endpoint

HPIA Script has already run before this: https://github.com/gwblok/garytown/blob/master/Intune/EndMgrEnhancedInventoryAddon_HPIA.ps1


.ChangeLog
      23.10.09.01 - Intial Release
      23.10.17.01 - Modified to create Compliance Key based on latest HPIA XML Report
#>

#IUS Compliance




$CollectIUSStatusInventory = $true 
$IUSStatusLogName = "IUSStatusInventory"

[String[]]$DesiredCategories = @("Drivers","BIOS")

$HPIAStagingFolder = "$env:ProgramData\HP\IntelligentUpdateService"
$HPIAStagingReports = "$HPIAStagingFolder\Reports"




$IntelligentUpdateRegKeyPath = "HKLM:\SOFTWARE\HP\IntelligentUpdate"
$HPIAAnalysisReportingRegKeyPath = "HKLM:\SOFTWARE\HP\IUSAnalysisReporting"

$SkipItmes = @("ExecutionStatus","LatestRunStartTime")



#region Functions
Function Get-HPIAXMLResult {
<#  
Grabs the output from a recent run of HPIA and parses the XML to find recommendations.
Only Reports on Categories you provide instead of all
  This is intentional as logic in other parts ot the script will update items based on all recommendations reported....
  so if this reported on everything, it would update everything, even if you had a different desired effected.
#>
[CmdletBinding()]
    Param (
        [ValidateSet("All", "BIOS", "Drivers", "Software", "Firmware", "Accessories")]
        [String[]]$Category = @("Drivers"),
        [Parameter(Mandatory=$false)]
        $ReportsFolder = "$env:systemdrive\ProgramData\HP\IntelligentUpdateService\Reports"

        )
    [String]$Category = $($Category -join ",").ToString()
    #$LatestReportFolder = (Get-ChildItem -Path $ReportsFolder | Where-Object {$_.Attributes -match 'Directory'} | Select-Object -Last 1).FullName
    $LatestXML = Get-ChildItem -Path $ReportsFolder -Filter *.XML -Recurse | Select-Object -Last 1
    $Script:Compliance = $true
    try 
    {
        $XMLFile = $LatestXML
        If ($XMLFile)
        {
            Write-Output "Report located at $($XMLFile.FullName)"
            try 
            {
                [xml]$XML = Get-Content -Path $XMLFile.FullName -ErrorAction Stop
                
                $Recommendations = $xml.HPIA.Recommendations
                if ($Recommendations) {
                    
                    Write-Host "Found HPIA Recommendations" -ForegroundColor Green 
                    if ($Category -match "BIOS" -or $Category -eq "All"){
                        Write-Host "Checking BIOS Recommendations" -ForegroundColor Green 
                        $null = $Recommendation
                        $Recommendation = $xml.HPIA.Recommendations.BIOS.Recommendation
                        If ($Recommendation){
                            $Script:Compliance = $false
                            $ItemName = $Recommendation.TargetComponent
                            $CurrentBIOSVersion = $Recommendation.TargetVersion
                            $ReferenceBIOSVersion = $Recommendation.ReferenceVersion
                            $DownloadURL = "https://" + $Recommendation.Solution.Softpaq.Url
                            $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                            Write-Host "Component: $ItemName" -ForegroundColor Gray
                            Write-Host " Current version is $CurrentBIOSVersion" -ForegroundColor Gray
                            Write-Host " Recommended version is $ReferenceBIOSVersion" -ForegroundColor Gray
                        }
                        Else  
                        {
                            Write-Host "No BIOS recommendation in XML" -ForegroundColor Gray
                        }
                    }
                    if ($Category -match "drivers" -or $Category -eq "All"){
                        Write-Host "Checking Driver Recommendations" -ForegroundColor Green                
                        $null = $Recommendation
                        $Recommendation = $xml.HPIA.Recommendations.drivers.Recommendation
                        $Recommendation = $Recommendation | Where-Object {$_.Solution.Softpaq.Name -notmatch "myHP"}
                        If ($Recommendation){
                            $Script:Compliance = $false
                            Foreach ($item in $Recommendation){
                                $ItemName = $item.TargetComponent
                                $CurrentVersion = $item.TargetVersion
                                $ReferenceVersion = $item.ReferenceVersion
                                $DownloadURL = "https://" + $item.Solution.Softpaq.Url
                                $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                                Write-Host "Component: $ItemName" -ForegroundColor Gray   
                                Write-Host " Current version is $CurrentVersion" -ForegroundColor Gray
                                Write-Host " Recommended version is $ReferenceVersion" -ForegroundColor Gray
                                Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                                }
                            }
                        Else  
                            {
                            Write-Host "No Driver recommendation in XML" -ForegroundColor Gray

                        }
                    }
                    if ($Category -match "Software" -or $Category -eq "All"){
                        Write-Host "Checking Software Recommendations" -ForegroundColor Green 
                        $null = $Recommendation
                        $Recommendation = $xml.HPIA.Recommendations.software.Recommendation
                        If ($Recommendation){
                            $Script:Compliance = $false
                            Foreach ($item in $Recommendation){
                                $ItemName = $item.TargetComponent
                                $CurrentVersion = $item.TargetVersion
                                $ReferenceVersion = $item.ReferenceVersion
                                $DownloadURL = "https://" + $item.Solution.Softpaq.Url
                                $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                                Write-Host "Component: $ItemName" -ForegroundColor Gray   
                                Write-Host " Current version is $CurrentVersion" -ForegroundColor Gray
                                Write-Host " Recommended version is $ReferenceVersion" -ForegroundColor Gray
                                Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                            }
                        }
                        Else  
                            {
                            Write-Host "No Software recommendation in XML" -ForegroundColor Gray
                        }
                    }
                    if ($Category -match "Firmware" -or $Category -eq "All"){
                        Write-Host "Checking Firmware Recommendations" -ForegroundColor Green
                        $null = $Recommendation
                        $Recommendation = $xml.HPIA.Recommendations.Firmware.Recommendation
                        If ($Recommendation){
                            $Script:Compliance = $false
                            Foreach ($item in $Recommendation){
                                $ItemName = $item.TargetComponent
                                $CurrentVersion = $item.TargetVersion
                                $ReferenceVersion = $item.ReferenceVersion
                                $DownloadURL = "https://" + $item.Solution.Softpaq.Url
                                $SoftpaqFileName = $DownloadURL.Split('/')[-1]
                                Write-Host "Component: $ItemName" -ForegroundColor Gray   
                                Write-Host " Current version is $CurrentVersion" -ForegroundColor Gray
                                Write-Host " Recommended version is $ReferenceVersion" -ForegroundColor Gray
                                Write-Host " Softpaq download URL is $DownloadURL" -ForegroundColor Gray
                            }
                        }
                        Else  
                            {
                            Write-Host "No Firmware recommendation in XML" -ForegroundColor Gray
 
                        }
                    }
                }
                else {
                    Write-Host "NO HPIA Recommendations" -ForegroundColor Green 
                }
            }
            catch 
            {
                Write-Host "Failed to parse the XML file: $($_.Exception.Message)"
            }
        }
        Else  
        {
            Write-Host "Failed to find an XML report."
            }
    }
    catch 
    {
        Write-Host "Failed to find an XML report: $($_.Exception.Message)"
    }
}

#endregion

if (Test-Path -Path $IntelligentUpdateRegKeyPath){

    #region get HPIA compliance info from last report
    Get-HPIAXMLResult -Category $DesiredCategories -ReportsFolder $HPIAStagingReports -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $IntelligentUpdateRegKeyPath -Name "Compliance" -Value $script:compliance


    #endregion


    #region gather info for LA upload

    #Start to Build Object
    $IUSInventory = New-Object -TypeName PSObject
    $IUSInventory | Add-Member -MemberType NoteProperty -Name "ComputerName" -Value "$ComputerName" -Force
    $IUSInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceName" -Value "$ManagedDeviceName" -Force
    $IUSInventory | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value "$ManagedDeviceID" -Force
    $IUSInventory | Add-Member -MemberType NoteProperty -Name "AzureADDeviceID" -Value "$AzureADDeviceID" -Force


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

    if (Test-Path $HPIAAnalysisReportingRegKeyPath){
        $IUSAnalysisReportingRegKey = Get-Item -Path $HPIAAnalysisReportingRegKeyPath
        #$IUSAnalysisReportingRegKey = $IUSAnalysisReportingRegKey | Where-Object {$_.Property -notmatch "ExecutionStatus"}
    
        ForEach ($Setting in $IUSAnalysisReportingRegKey.Property){
            if ($Setting -notin $SkipItmes){
                $SettingName = $Setting
                $SettingValue = $IUSAnalysisReportingRegKey.GetValue($Setting)
                $IUSInventory | Add-Member -MemberType NoteProperty -Name $SettingName -Value $SettingValue -Force
            }
        }
    }
}

if (!((Test-Path $HPIAAnalysisReportingRegKeyPath) -or (Test-Path $IntelligentUpdateRegKeyPath))){
    $CollectIUSStatusInventory = $false 
} 

if ($CollectIUSStatusInventory) {
	$LogPayLoad | Add-Member -NotePropertyMembers @{$IUSStatusLogName = $IUSInventory}
}
#endregion
