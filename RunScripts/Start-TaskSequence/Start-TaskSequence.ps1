<#Triggers Task Sequence based on Package ID Parameter
    @GWBLOK

This will send a Request to the endpoint to trigger the Tasksquence based on Package ID
It will trigger, then wait to see it the execution request is in WMI, if it is, it is considered complete
  If it doesn't find the exection request, it waits 90 seconds and retries.
    
#>

[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true)][string]
		    $TSPackageID,
		    [Parameter(Mandatory=$true)][string]
		    $RetryEvenIfSuccess  
	    )



Function Get-TSExecutionHistory {
    [cmdletbinding()]
    param ([string] $TSPackageID)
    $ExecutionHistoryPath = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System\$($TSPackageID)"
    if (Test-Path -Path $ExecutionHistoryPath)
        {
        $ExcutionHistory = get-item -Path $ExecutionHistoryPath
        $ExcutionHistorySubKey = get-item -Path $ExecutionHistoryPath\$($ExcutionHistory.GetSubKeyNames())
        $ExcutionHistoryProdTS = ($ExcutionHistorySubKey.GetValue("_State"))
        ($ExcutionHistorySubKey.GetValue("_State"))
        }
    else {write-output "No History"}
    }

Function Get-TSInfo {
    [cmdletbinding()]
    param ([string] $TSPackageID)
    Get-CimInstance -Namespace root/ccm/Policy/Machine/ActualConfig -ClassName CCM_TaskSequence -Filter "PKG_PackageID='$TSPackageID'" | Select-Object -Property * -ExcludeProperty TS_Sequence
    }

#START SCRIPT ACTIONS

$ExecutionHistory = Get-TSExecutionHistory -TSPackageID $TSPackageID
$TSInfo = Get-TSInfo -TSPackageID $TSPackageID
$TSName = $TSInfo.PKG_Name


if ($ExecutionHistory -eq "Success" -and $RetryEvenIfSuccess -ne "TRUE")
    {
    Write-Output "TS $TSName History: $ExecutionHistory, Exiting Script"
    Exit
    }
else
    {

    #$TSPackageID = "PS2000CA"  - Handy for testing.
    $TSLastGroup = '6F6BCC28'
    $CurrentTimeStamp = Get-Date
    $TSScheduleMessageID = (get-wmiobject -query "SELECT * FROM CCM_Scheduler_ScheduledMessage WHERE ScheduledMessageID LIKE""%-$TSPackageID-$TSLastGroup""" -namespace "ROOT\ccm\policy\machine\actualconfig").ScheduledMessageID
    if ($TSScheduleMessageID){$TSDeployID = $TSScheduleMessageID.Split("-")[0]}
    $TSName = (get-wmiobject -query "SELECT * FROM CCM_TaskSequence WHERE PKG_PackageID = ""$TSPackageID""" -namespace "ROOT\ccm\policy\machine\actualconfig").PKG_Name

    if ($TSName)
        {
        $TriggeredTSName = ([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'").PKG_Name
        get-wmiobject -query "SELECT * FROM CCM_Scheduler_ScheduledMessage WHERE ScheduledMessageID='$TSDeployID-$TSPackageID-$TSLastGroup'" -namespace "ROOT\ccm\policy\machine\actualconfig" | Out-Null
        $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'");$a.ADV_RepeatRunBehavior='RerunAlways';$a.Put() | Out-Null
        $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'");$a.ADV_MandatoryAssignments=$True;$a.Put() | Out-Null
        $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'");$a.PRG_Requirements='<?xml version=''1.0'' ?><SWDReserved>    <PackageHashVersion>1</PackageHashVersion>    <PackageHash.1></PackageHash.1>    <PackageHash.2></PackageHash.2>    <NewPackageHash></NewPackageHash>    <ProductCode></ProductCode>    <DisableMomAlerts>false</DisableMomAlerts>    <RaiseMomAlertOnFailure>false</RaiseMomAlertOnFailure>    <BalloonRemindersRequired>false</BalloonRemindersRequired>    <PersistOnWriteFilterDevices>true</PersistOnWriteFilterDevices>    <DefaultProgram>true</DefaultProgram>    <PersistInCache>0</PersistInCache>    <DistributeOnDemand>false</DistributeOnDemand>    <Multicast>false</Multicast>    <MulticastOnly>false</MulticastOnly>    <MulticastEncrypt>false</MulticastEncrypt>    <DonotFallback>false</DonotFallback>    <PeerCaching>true</PeerCaching>    <OptionalPreDownload>true</OptionalPreDownload>    <PreDownloadRule></PreDownloadRule>    <Requirements></Requirements>    <AssignmentID></AssignmentID>    <ScheduledMessageID>CAS29CDE-CAS04823-6F6BCC28</ScheduledMessageID>    <OverrideServiceWindows>TRUE</OverrideServiceWindows>    <RebootOutsideOfServiceWindows>FALSE</RebootOutsideOfServiceWindows>    <WoLEnabled>FALSE</WoLEnabled>    <ShowTSProgressUI>FALSE</ShowTSProgressUI>    <UseTSCustomProgressMessage>FALSE</UseTSCustomProgressMessage>    <TSCustomProgressMessage><![CDATA[]]></TSCustomProgressMessage>    <ContainsAdditionalProperties>FALSE</ContainsAdditionalProperties></SWDReserved>';$a.Put() | Out-Null
        foreach ($TS in $TSScheduleMessageID)
            {
            ([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule($($TS)) | Out-Null
            #write-output "$TS |"
            }

        start-sleep -Seconds 20 #Wait 20 Seconds and see if it Execution is in WMI
        $TSExecutionRequests = Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest | Where-Object { $_.ContentID -eq $TSPackageID} | Select-Object AdvertID, ContentID, @{Label='ReceivedTime'; Expression={[System.Management.ManagementDateTimeConverter]::ToDatetime($_.ReceivedTime)}}
        if ($TSExecutionRequests)
            {
            #Write-Output "  CCM_TSExecutionRequest $($TSExecutionRequests.ReceivedTime) |"
            }
        Else { #Trigger again, sometimes a 2nd attempt works, wait 90 seconds and kick off again
            Start-Sleep -Seconds 90
            $TriggeredTSName = ([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'").PKG_Name
            get-wmiobject -query "SELECT * FROM CCM_Scheduler_ScheduledMessage WHERE ScheduledMessageID='$TSDeployID-$TSPackageID-$TSLastGroup'" -namespace "ROOT\ccm\policy\machine\actualconfig" | Out-Null
            $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'");$a.ADV_RepeatRunBehavior='RerunAlways';$a.Put() | Out-Null
            $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'");$a.ADV_MandatoryAssignments=$True;$a.Put() | Out-Null
            $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'");$a.PRG_Requirements='<?xml version=''1.0'' ?><SWDReserved>    <PackageHashVersion>1</PackageHashVersion>    <PackageHash.1></PackageHash.1>    <PackageHash.2></PackageHash.2>    <NewPackageHash></NewPackageHash>    <ProductCode></ProductCode>    <DisableMomAlerts>false</DisableMomAlerts>    <RaiseMomAlertOnFailure>false</RaiseMomAlertOnFailure>    <BalloonRemindersRequired>false</BalloonRemindersRequired>    <PersistOnWriteFilterDevices>true</PersistOnWriteFilterDevices>    <DefaultProgram>true</DefaultProgram>    <PersistInCache>0</PersistInCache>    <DistributeOnDemand>false</DistributeOnDemand>    <Multicast>false</Multicast>    <MulticastOnly>false</MulticastOnly>    <MulticastEncrypt>false</MulticastEncrypt>    <DonotFallback>false</DonotFallback>    <PeerCaching>true</PeerCaching>    <OptionalPreDownload>true</OptionalPreDownload>    <PreDownloadRule></PreDownloadRule>    <Requirements></Requirements>    <AssignmentID></AssignmentID>    <ScheduledMessageID>CAS29CDE-CAS04823-6F6BCC28</ScheduledMessageID>    <OverrideServiceWindows>TRUE</OverrideServiceWindows>    <RebootOutsideOfServiceWindows>FALSE</RebootOutsideOfServiceWindows>    <WoLEnabled>FALSE</WoLEnabled>    <ShowTSProgressUI>FALSE</ShowTSProgressUI>    <UseTSCustomProgressMessage>FALSE</UseTSCustomProgressMessage>    <TSCustomProgressMessage><![CDATA[]]></TSCustomProgressMessage>    <ContainsAdditionalProperties>FALSE</ContainsAdditionalProperties></SWDReserved>';$a.Put() | Out-Null
            foreach ($TS in $TSScheduleMessageID)
                {
                ([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule($($TS)) | Out-Null
                }
            Start-Sleep -Seconds 20
            }
        $TSExecutionRequests = Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest | Where-Object { $_.ContentID -eq $TSPackageID} | Select-Object AdvertID, ContentID, @{Label='ReceivedTime'; Expression={[System.Management.ManagementDateTimeConverter]::ToDatetime($_.ReceivedTime)}}
        if ($TSExecutionRequests)
            {
            Write-Output "ExecutionRequest created for $TSName"
            }
        else {Write-Output "NO ExecutionRequest in WMI for $TSName"}
            
        }
    Else {Write-Output "No Task Sequence for Package ID $TSPackageID on this Machine"}
    }