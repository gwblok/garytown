    Param (
		    [Parameter(Mandatory=$true)]
		    $BaselineName
	    )


Function Invoke-Baseline{
#For using in "Run Script" Node.  Has Exit At end... will exit your ISE if you run in ISE. :-)
#Adopted from another script, so it has some Write-Hosts that don't really make sense in a CI, deal with it.

[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true)]
		    $BaselineName
	    )


#Invoke Machine Policy
[Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000021}')
[Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000022}')
Start-Sleep -Seconds 15

#Testing
#$BaselineName = "SDE Pulse Recent Connection"

#Get Baseline Info
$DCM = [WMIClass] "ROOT\ccm\dcm:SMS_DesiredConfiguration"
$WaaSBaseline = Get-WmiObject -Namespace root\ccm\dcm -QUERY "SELECT * FROM SMS_DesiredConfiguration WHERE DisplayName LIKE '%$($BaselineName)%'"

if ($BaselineName -match "Pre-Prod")
    {
    $WaaSBaseline = $WaaSBaseline | Where-Object {$_.DisplayName -match "Pre-Prod"}
    $BaselineName = $WaaSBaseline.DisplayName
    }
else
    {
    $WaaSBaseline = $WaaSBaseline | Where-Object {$_.DisplayName -notmatch "Pre-Prod"}
    $BaselineName = $WaaSBaseline.DisplayName
    }

   
#Display Baseline Info
#Trigger WaaS Content Baseline
    
if ($WaaSBaseline -ne $null)
    {
    [VOID]$DCM.TriggerEvaluation($WaaSBaseline.Name, $WaaSBaseline.Version)
    Start-Sleep -Seconds 5
    $WaaSBaseline = Get-WmiObject -Namespace root\ccm\dcm -QUERY "SELECT * FROM SMS_DesiredConfiguration WHERE DisplayName LIKE '%$($BaselineName)%'"
    $LastEvalTime = $WaaSBaseline.LastEvalTime
    if ($LastEvalTime -ne $Null -and $LastEvalTime -notlike "000*" )
        {
        $LastEvalString = $LastEvalTime.Substring(0,14)
        #$LastEvalString = [MATH]::Round($LastEvalString)
        #$LastEvalString = $LastEvalString.ToString()
        $LastEvalString = [DateTime]::ParseExact($LastEvalString,"yyyyMMddHHmmss",$null)
        $EvalDifference = New-TimeSpan -End ([System.DateTime]::UtcNow) -Start $LastEvalString
        $EvalDifferenceHours = $EvalDifference.TotalHours    
        $UserReport = $DCM.GetUserReport($WaaSBaseline.Name,$WaaSBaseline.Version,$null,0)
        [XML]$Details = $UserReport.ComplianceDetails
        $WaaSNonCompliant = $Details.ConfigurationItemReport.ReferencedConfigurationItems.ConfigurationItemReport | Where-Object {$_.CIComplianceState -eq "NonCompliant"}
            
        if ($Details.ConfigurationItemReport.CIComplianceState -eq "Compliant")
            {
            $BaselineStatus = "Compliant"
            Write-Host "  Baseline $($BaselineName): $BaselineStatus" -ForegroundColor Green
            }
        Else
            {
            [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000021}')
            [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000022}')
            Start-Sleep -Seconds 180 
            [VOID]$DCM.TriggerEvaluation($WaaSBaseline.Name, $WaaSBaseline.Version)
            Start-Sleep -Seconds 300 
            $WaaSBaseline = Get-WmiObject -Namespace root\ccm\dcm -QUERY "SELECT * FROM SMS_DesiredConfiguration WHERE DisplayName LIKE '%$($BaselineName)%'"
            $WaaSNonCompliant = $Details.ConfigurationItemReport.ReferencedConfigurationItems.ConfigurationItemReport | Where-Object {$_.CIComplianceState -eq "NonCompliant"}
            $BaselineStatus = "NonCompliant"
            $UserReport = $DCM.GetUserReport($WaaSBaseline.Name,$WaaSBaseline.Version,$null,0)
            [XML]$Details = $UserReport.ComplianceDetails
            if ($Details.ConfigurationItemReport.CIComplianceState -eq "Compliant")
                {
                $BaselineStatus = "Compliant"
                Write-Host "  Baseline $($BaselineName): $BaselineStatus" -ForegroundColor Green
                }
            Else
                {
                Write-Host "  Baseline $($BaselineName): $BaselineStatus" -ForegroundColor Red
                $NonCompliantNames = ForEach ($PA_Rule in $WaaSNonCompliant)
                {($PA_Rule).CIProperties.Name.'#text'}
                ForEach ($PA_Rule in $WaaSNonCompliant)
                    {
                    Write-Host "  Rule: $($PA_Rule.CIProperties.Name.'#text')" -ForegroundColor Red
                    }
                #Write-Host "NonCompliant Items: $WaaSNonCompliant" -ForegroundColor Red
                [VOID]$DCM.TriggerEvaluation($WaaSBaseline.Name, $WaaSBaseline.Version)
                }
            }
        }
    Else
        {
        $BaselineStatus = "No Status"
        Write-Host "WaaS Content Baseline: $BaselineStatus" -ForegroundColor Red
        [VOID]$DCM.TriggerEvaluation($WaaSBaseline.Name, $WaaSBaseline.Version)
        }
    }
else
    {
    [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000021}')
    [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000022}')
    Write-Host "Baseline $BaselineName no found in policy" -ForegroundColor Red
    }


#Invoke Hardware Inventory Delta
[Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000001}')
}

Invoke-Baseline -BaselineName $BaselineName
