Function Start-TaskSequence {

<#Triggers Task Sequence based on Package ID Parameter
    @GWBLOK
    
    Once Triggered, it will wait 2 minutes, then parse the execmgr log using a function from Jeff Scripter: ConvertFrom-Log
    Once Parsed, looks for if the Task Sequence Successfully Started and reports back (Only if the Time Stamp for Starting is After the time you run the script)


#>
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true)][string]
		    $TSPackageID
	    )

#Needs Function ConvertFrom-Logs 
#START SCRIPT ACTIONS

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
        write-host "Triggered: $TS = $TriggeredTSName" -ForegroundColor Yellow
        }

    start-sleep -Seconds 20
    $TSExecutionRequests = Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest | Where-Object { $_.ContentID -eq $TSPackageID} | Select-Object AdvertID, ContentID, @{Label='ReceivedTime'; Expression={[System.Management.ManagementDateTimeConverter]::ToDatetime($_.ReceivedTime)}}
    if ($TSExecutionRequests){write-host "  CCM_TSExecutionRequest info: AdvertID: $($TSExecutionRequests.AdvertID) | ContentID: $($TSExecutionRequests.ContentID) | ReceivedTime: $($TSExecutionRequests.ReceivedTime)" -ForegroundColor Green}
    Else {write-host "  NO CCM_TSExecutionRequest info in WMI" -ForegroundColor yellow}
    write-host "  Waiting 2 minutes for process to have time to run and fill logs" -ForegroundColor Yellow
    Start-Sleep -Seconds 90  #Gives time on the client to trigger TS and do it's stuff before we start to query how it went
    $ExecMgrLog = $null
    $ExecMgrLog = ConvertFrom-Logs -LogPath C:\Windows\CCM\logs\execmgr.log | Where-Object { $_.Message -match $TSPackageID}
    if (!($ExecMgrLog)){$ExecMgrLog = ConvertFrom-Logs -LogPath C:\Windows\CCM\logs\execmgr-*.log | Where-Object { $_.Message -match $TSPackageID}}
    $Last2Instances = $null
    $Last2Instances = $ExecMgrLog | Where-Object { $_.Message -match "Execution Request for advert"} | Sort-Object -Property time | Select-Object -Last 2
    foreach ($Instance in $Last2Instances)
        {
        write-host "  $($Instance.Message) at $($Instance.time)"
        }

    #$ExecMgrLog | Where-Object { $_.Message -match $TSPackageID}
    #$ExecMgrLogString = $ExecMgrLog | Where-Object -FilterScript { $_ -match "The task sequence $TSPackageID was successfully started"}
    $ExecMgrLogString = $ExecMgrLog | Where-Object -FilterScript { $_.Message -match "The task sequence $TSPackageID was successfully started"}
    $ExecMgrLogString = $ExecMgrLogString | Where-Object -FilterScript {$_.Time -eq ($ExecMgrLogString.time | measure -Maximum).Maximum}
    $ExecMgrLogMWString = $ExecMgrLog | Where-Object -FilterScript { $_.Message -eq "MTC task for SWD execution request with program id: *, package id: $TSPackageID is waiting for service window."}
    $ExecMgrLogMWString = $ExecMgrLogMWString | Where-Object -FilterScript {$_.Time -eq ($ExecMgrLogMWString.time | measure -Maximum).Maximum}
    
    if ($CurrentTimeStamp -lt $ExecMgrLogString.time){Write-Output "Successfully Started Task Sequence $TSName"}
    Else 
        {
        Write-Output "Failed to Start Task Sequence $TSName"
        $NoTrigger = $true
        }
    if ($ExecMgrLogMWString -and $NoTrigger)
        {
        $CMServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE PolicySource <> "Local" '
        Write-output "Waiting for MW"
        }
    }
Else {Write-Output "No Task Sequence for Package ID $TSPackageID on this Machine"}

}
