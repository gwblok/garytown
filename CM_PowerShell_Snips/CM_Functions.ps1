Function Get-CCMDTSJobsActive {

    $ActiveTransfers = Get-BitsTransfer -AllUsers | Where-Object {$_.DisplayName -eq "CCMDTS Job" -and $_.JobState -eq "Transferring"}
    if ($ActiveTransfers)
        {
        ForEach ($ActiveTransfer in $ActiveTransfers){
            
            $SiteCode = ([wmiclass]"ROOT\ccm:SMS_Client").GetAssignedSite().sSiteCode #Unless you have a CAS
            #$SiteCode = 'MEM'
            $M365Content = "stream.x64.x-none.dat"
            Write-host "Currently Transferring BITS Job: $($ActiveTransfer.JobId)"-ForegroundColor Magenta
            $PackageID = (($ActiveTransfer.FileList | Select-Object -First 1).RemoteName).split("/") | Where-Object {$_ -Match $SiteCode}
            $App = (($ActiveTransfer.FileList | Select-Object -First 1).RemoteName).split("/") | Where-Object {$_ -Match "content_"}
            $M365 = (($ActiveTransfer.FileList | Select-Object -First 1).RemoteName).split("/") | Where-Object {$_ -Match "$M365Content"}
            $DownloadLocation = (($ActiveTransfer.FileList | Select-Object -First 1).LocalName).split("\")[3]
            #$ExampleFile = (($ActiveTransfer.FileList | Select-Object -First 1).RemoteName).split("/")
            $ExampleFileLocalName = $ActiveTransfer.FileList | Where-Object {$_.LocalName -Match 'install.wim'}
            if (!($ExampleFileLocalName)){$ExampleFileLocalName = ($ActiveTransfer.FileList | Select-Object -First 1).LocalName}
            $TotalSize = [math]::Round($ActiveTransfer.BytesTotal / 1024 / 1024,2) 
            $PercentComplete = [math]::Round($ActiveTransfer.BytesTransferred / $ActiveTransfer.BytesTotal * 100,2)
            $FileDownloading = $ActiveTransfer.FileList | Where-Object {$_.IsTransferComplete -eq $false -and $_.BytesTransferred -gt 0 -and ($_.BytesTotal -gt $_.BytesTransferred)}

            if ($PackageID -or $App -or $M365)
                {
                Write-host "  Downloading Content: $PackageID $App " -ForegroundColor Green
                #Write-host "  Example File Info:" -ForegroundColor Green
                #$ExampleFileLocalName
                Write-host "  Downloading Location: c:\windows\ccmcache\$DownloadLocation " -ForegroundColor Green
                write-host "  Total Size: $TotalSize and Downloaded: $PercentComplete%" -ForegroundColor Green
                write-host "  Transfer Starttime: $($ActiveTransfer.CreationTime)" -ForegroundColor Green
                Write-Host "  Current Client Time: $(get-date)" -ForegroundColor Green
                $FileList = $ActiveTransfer.FileList | Where-Object {$_.LocalName -notmatch "AppDeployToolkit" -and $_.LocalName -notmatch "Deploy-Application"} | select -First 5
                Write-Host "   First 5 Files in List" -ForegroundColor DarkGreen
                ForEach ($File in $FileList)
                    {
                    Write-Host "   $($File.LocalName)" -ForegroundColor Gray
                    }
                if ($FileDownloading -ne "" -and $FileDownloading -ne $Null)
                    {
                    Write-Host "  Currently downloadling: $($FileDownloading.LocalName)" -ForegroundColor Green
                    Write-Host "   Total Size: $($FileDownloading.BytesTotal)" -ForegroundColor Green
                    Write-Host "   Amount Downloaded: $($FileDownloading.BytesTransferred)" -ForegroundColor Green
                    }
                }
            }
        
        
        
        }
    
    
    
    }
Function Get-CCMDTSJobs {

    [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)][switch]
		    $TransferCount
	    )
    $CMTransfers = Get-BitsTransfer -AllUsers | Where-Object {$_.DisplayName -eq "CCMDTS Job" -and $_.JobState -ne "Transferred" }
    $SiteCode = ([wmiclass]"ROOT\ccm:SMS_Client").GetAssignedSite().sSiteCode #Unless you have a CAS
    #$SiteCode = 'MEM'
    if ($TransferCount)
        {
        Write-host "There are currently $($CMTransfers.count) CM Content Transfers"-ForegroundColor Green}
    else
        {
        if ($CMTransfers)
            {
            Write-host "There are currently $($CMTransfers.count) CM Content Transfers"-ForegroundColor Green
            $CMTransfers = Get-BitsTransfer -AllUsers | Where-Object {$_.DisplayName -eq "CCMDTS Job" -and $_.JobState -ne "Transferred" -and $_.JobState -ne "Transferring"  }
            if ($CMTransfers.count -ge 1)
                {
                foreach ($Transfer in $CMTransfers)
                    {
                    $PackageID = (($Transfer.FileList | Select-Object -First 1).RemoteName).split("/") | Where-Object {$_ -Match $SiteCode}
                    $App = (($Transfer.FileList | Select-Object -First 1).RemoteName).split("/") | Where-Object {$_ -Match "content_"}
                    $DownloadLocation = (($Transfer.FileList | Select-Object -First 1).LocalName).split("\")[3]
                    $TotalSize = [math]::Round($Transfer.BytesTotal / 1024 / 1024,2) 
                    $PercentComplete = [math]::Round($Transfer.BytesTransferred / $Transfer.BytesTotal * 100,2)

                    Write-host " -------------------------------------------------" -ForegroundColor Gray
                    Write-host "  Downloading Content: $PackageID $App | JobID:  $($Transfer.JobId)" -ForegroundColor Green
                    Write-host "  Downloading Location: c:\windows\ccmcache\$DownloadLocation " -ForegroundColor Green
                    write-host "  Total Size: $TotalSize and Downloaded: $PercentComplete%" -ForegroundColor Green
                    write-host "  Total Files: $($Transfer.FilesTotal)" -ForegroundColor Green
                    write-host "  CreationTime: $($Transfer.CreationTime)" -ForegroundColor Green
                    write-host "  ModificationTime: $($Transfer.ModificationTime)" -ForegroundColor Green
                    if (!($DownloadLocation -match "CIDownloader")){
                        $FileList = $Transfer.FileList | Where-Object {$_.LocalName -notmatch "AppDeployToolkit" -and $_.LocalName -notmatch "Deploy-Application"} | select -First 5
                        Write-Host "   First 5 Files in List" -ForegroundColor DarkGreen
                        ForEach ($File in $FileList)
                            {
                            Write-Host "   $($File.LocalName)" -ForegroundColor Gray
                            }
                        }
                    }
                }
            }
        }
    }
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

#$TSPackageID = "MEM01D7D"  - Handy for testing.
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
Function Get-TaskSequenceInfo {
 $TSInfo = Get-CimInstance -Namespace root/ccm/Policy/Machine/RequestedConfig -ClassName CCM_TaskSequence -Filter "PRG_DependentPolicy='False'"
 $TSInfoActual = Get-CimInstance -Namespace root/ccm/Policy/Machine/ActualConfig -ClassName CCM_TaskSequence -Filter "PRG_DependentPolicy='False'"
    if ($TSInfo -ne $null)
        {
        write-host "Available Task Sequences:" -ForegroundColor Gray
        foreach ($TS in $TSInfo)#{}
            {
            
            $TSActual = $TSInfoActual | Where-Object {$_.ADV_AdvertisementID -eq $TS.ADV_AdvertisementID}
            if ($ts.ADV_MandatoryAssignments -eq "True"){$DeploymentType = "Required"}
            else{$DeploymentType = "Available"}
            if ($TS.PRG_PRF_RunNotification -eq "True"){$Popups = "Enabled"}
            Else {$Popups = "Disabled"}
            
            if ($TSActual.ADV_MandatoryAssignments -eq "True"){$DeploymentTypeActual = "Required"}
            else{$DeploymentTypeActual = "Available"}
            if ($TSActual.PRG_PRF_RunNotification -eq "True"){$PopupsActual = "Enabled"}
            Else {$PopupsActual = "Disabled"}

            if ($DeploymentType -ne $DeploymentTypeActual){$DeploymentType = "!!Mixed!!"}
            if ($Popups -ne $PopupsActual){$Popups = "!!Mixed!!"}

            write-host " $($TS.PKG_Name) | PackageID: $($TS.PKG_PackageID) | DeployID: $($TS.ADV_AdvertisementID) | Notifications: $Popups | Deployed as $DeploymentType | ActiveTime (UTC): $($TS.ADV_ActiveTime)" -ForegroundColor cyan
            if ($TS.PRG_Comment -ne $null -and $TS.PRG_Comment -ne ""){ write-host "  Description: $($TS.PRG_Comment)" -ForegroundColor cyan}
            $Collection = $DeploymentTable | Where-Object {$_.DID -eq $($TS.ADV_AdvertisementID)}
            if ($Collection){Write-Host "  Deployment Collection: $($Collection.DIDName)" -ForegroundColor Magenta}
            $StartTime = Get-TSExecutionHistoryStartTime -TSPackageID $TS.PKG_PackageID
            $ExHistory = Get-TSExecutionHistoryStatus -TSPackageID $TS.PKG_PackageID
            if ($StartTime -eq "No History" -and $ExHistory -eq "No History"){write-host "   Execution History: $ExHistory" -ForegroundColor Green}
            else
                {
                if ($ExHistory -eq "Success"){write-host "   Execution History: Status = $ExHistory | Start Time: $StartTime" -ForegroundColor Green}
                elseif ($ExHistory -eq "Failure"){write-host  "   Execution History: Status = $ExHistory | Start Time: $StartTime" -ForegroundColor Red}
                else {write-host "   Execution History: Status = $ExHistory | Start Time: $StartTime" -ForegroundColor yellow}
                }
            }
        }
}
#Get Execution History for Production Upgrade
Function Get-TaskSequenceExecutionRequest {
    Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest | Where-Object {$_.ContentID -eq $PackageIDTSProd} | Select-Object ContentID, MIFPackageName, State

}
Function Reset-TaskSequence {
    
    $TSExecutionRequests = Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest
    if ($TSExecutionRequests)
        {
        Write-host "Removing TS Excustion Request from WMI" -ForegroundColor Yellow
        $TSExecutionRequests = $TSExecutionRequests | where-object {$_.MIFPackageName -ne $null}
        ForEach ($TSExecutionRequest in $TSExecutionRequests){Write-Host "  Deleting Execution Request for: $($TSExecutionRequest.MIFPackageName)" -ForegroundColor Yellow}
        Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest | Remove-WmiObject
        Get-CimInstance -Namespace root/ccm -ClassName SMS_MaintenanceTaskRequests | Remove-CimInstance
        }
    Set-Service smstsmgr -StartupType manual
    Start-Service smstsmgr
    Start-Sleep -Seconds 5
    if ((Get-Process CcmExec -ea SilentlyContinue) -ne $Null) {Get-Process CcmExec | Stop-Process -Force}
    if ((Get-Process TSManager -ea SilentlyContinue) -ne $Null) {Get-Process TSManager| Stop-Process -Force}
    Start-Sleep -Seconds 5
    Start-Service ccmexec
    Start-Sleep -Seconds 5
    Start-Service smstsmgr
    restart-service ccmexec -force -ErrorAction SilentlyContinue
    Start-Process -FilePath C:\windows\ccm\CcmEval.exe
    start-sleep -Seconds 15
    if (get-process -name TSManager -ErrorAction SilentlyContinue){Get-Process -name TSManager | Stop-Process -force}
    if (get-process -name TsProgressUI -ErrorAction SilentlyContinue){Get-Process -name TsProgressUI | Stop-Process -force}
    #Invoke Machine Policy
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}" |Out-Null
    Invoke-WMIMethod -Namespace root\ccm -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}" |Out-Null
    if (test-path -path c:\windows\ccm\logs\smstslog\smsts.log){remove-item -path c:\windows\ccm\logs\smstslog -recurse -force -erroraction silentlycontinue}
    Write-output "Completed Resetting Task Sequences"
}
#Delete Execution History
Function Remove-TSExecutionHistory {
    [cmdletbinding()]
    param ([string] $TSPackageID)
    $ExecutionHistoryPath = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System\$($TSPackageID)"
    if (Test-Path -Path $ExecutionHistoryPath)
    {write-host "Found History for $($TSPackageID), Deleting now" -ForegroundColor Yellow ;  Remove-Item -Path HKLM:\SOFTWARE\Microsoft\SMS\'Mobile Client\Software Distribution\Execution History'\System\$($TSPackageID) -Recurse -verbose} Else {write-host "No History for $($TSPackageID)" -ForegroundColor Yellow}
    }
#Show Execution History for Production POST TS Success
Function Get-TSExecutionHistoryStatus {
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
Function Get-TSExecutionHistoryStartTime {
    [cmdletbinding()]
    param ([string] $TSPackageID)
    $ExecutionHistoryPath = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System\$($TSPackageID)"
    if (Test-Path -Path $ExecutionHistoryPath)
        {
        $ExcutionHistory = get-item -Path $ExecutionHistoryPath
        $ExcutionHistorySubKey = get-item -Path $ExecutionHistoryPath\$($ExcutionHistory.GetSubKeyNames())
        $ExcutionHistoryProdTS = ($ExcutionHistorySubKey.GetValue("_RunStartTime"))
        ($ExcutionHistorySubKey.GetValue("_RunStartTime"))
        }
    else {write-output "No History"}
    }
Function Set-LogPropertiesBitsLogMaxSize {
    Param(
        [Parameter(Mandatory=$true,
        HelpMessage="Enter how many MB you want Log to be, IE: 5 or 10, etc")]
        [Int]
        $MaxSize
        )
    $logSize = $MaxSize * 1024 * 1024 #Convert input number to bytes
    $BitsLog = Get-LogProperties -Name 'Microsoft-Windows-Bits-Client/Operational'
    $BitsLog.MaxLogSize = $logSize
    Set-LogProperties -LogDetails $BitsLog
    Write-Output "Maxsize: $((Get-LogProperties -Name 'Microsoft-Windows-Bits-Client/Operational').MaxLogSize) bytes ($(((Get-LogProperties -Name 'Microsoft-Windows-Bits-Client/Operational').MaxLogSize)/ 1024 /1024) MB)"
    }
Function Set-TSExecutionHistory {
    [cmdletbinding()]
    param ([string] $TSPackageID, [ValidateSet("Failure", "Success")][string] $HistoryStatus)
    #Set Execution History for Production TS Success
    $ExecutionHistoryPath = "HKLM:\SOFTWARE\Microsoft\SMS\Mobile Client\Software Distribution\Execution History\System\$($TSPackageID)"
    $ExcutionHistory = get-item -Path $ExecutionHistoryPath
    $ExcutionHistorySubKey = get-item -Path $ExecutionHistoryPath\$($ExcutionHistory.GetSubKeyNames())
    Set-ItemProperty -Path $ExecutionHistoryPath\$($ExcutionHistory.GetSubKeyNames()) -Name "_State" -Value $HistoryStatus
    }
Function Get-TSInfo {
    [cmdletbinding()]
    param ([string] $TSPackageID)
    Get-CimInstance -Namespace root/ccm/Policy/Machine/ActualConfig -ClassName CCM_TaskSequence -Filter "PKG_PackageID='$TSPackageID'" | Select-Object -Property * -ExcludeProperty TS_Sequence
    }
Function Get-CMPackages {
    $PackageIDs = ($Packages = Get-CimInstance -Namespace root\ccm/Policy/Machine/ActualConfig -ClassName CCM_SoftwareDistribution | Where-Object {$_.TS_Sequence -eq $Null}).PKG_PackageID | Select-Object -Unique
    Foreach ($PackageID in $PackageIDs)
    {
    $WorkingPackage = $Packages | Where-Object {$_.PKG_PackageID -eq $PackageID}
    $CommandLine = ($WorkingPackage | Where-Object {![String]::IsNullOrWhiteSpace($_.PRG_CommandLine)}).PRG_CommandLine | Select-Object -First 1
    Write-host "--------------"   
    Write-host "Package Info:"
    Write-host " Name: $($WorkingPackage[0].PKG_Name)"
    Write-host " PackageID: $($WorkingPackage[0].PKG_PackageID)"
    if ($CommandLine){Write-host "  Command line: $($CommandLine)"}
    
    Get-CCMCachePackageInfo -Package $($WorkingPackage[0].PKG_PackageID)
    }
}
Function Start-PackageCommandLine {
 [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true)][string]
		    $PackageID
	    )
 
 $PackageLastGroup = '0CE1A3FC'
 #$PackageID = "MEM0112E"
 $PackageInfo = Get-CimInstance -Namespace root\ccm/Policy/Machine/ActualConfig -ClassName CCM_SoftwareDistribution | Where-Object {$_.PKG_PackageID  -eq $PackageID} | Select-Object -Unique -First 1
 $PackageAdvertID = $PackageInfo.ADV_AdvertisementID
 $ProgramID = $PackageInfo.PRG_ProgramID
 $PackageName = $PackageInfo.PKG_Name

 $ScheduleMessageID = (get-wmiobject -query "SELECT * FROM CCM_Scheduler_ScheduledMessage WHERE ScheduledMessageID LIKE""%-$PackageID-$PackageLastGroup""" -namespace "ROOT\ccm\policy\machine\actualconfig").ScheduledMessageID
 
 get-wmiobject -query "SELECT * FROM CCM_Scheduler_ScheduledMessage WHERE ScheduledMessageID='$PackageAdvertID-$PackageID-$PackageLastGroup'" -namespace "ROOT\ccm\policy\machine\actualconfig"  | Out-Null
 $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$PackageAdvertID',PKG_PackageID='$PackageID',PRG_ProgramID='$ProgramID'");$a.ADV_RepeatRunBehavior='RerunAlways';$a.Put() | Out-Null
 $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$PackageAdvertID',PKG_PackageID='$PackageID',PRG_ProgramID='$ProgramID'");$a.ADV_RepeatRunBehavior='RerunAlways';$a.Put() | Out-Null
 $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$PackageAdvertID',PKG_PackageID='$PackageID',PRG_ProgramID='$ProgramID'");$a.ADV_MandatoryAssignments=$True;$a.Put() | Out-Null
 $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$PackageAdvertID',PKG_PackageID='$PackageID',PRG_ProgramID='$ProgramID'");$a.ADV_MandatoryAssignments=$True;$a.Put() | Out-Null
 $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$PackageAdvertID',PKG_PackageID='$PackageID',PRG_ProgramID='$ProgramID'");$a.PRG_Requirements='<?xml version=''1.0'' ?><SWDReserved>    <PackageHashVersion>4</PackageHashVersion>    <PackageHash.1></PackageHash.1>    <PackageHash.2>C055624DB492C09FDE3D8A6E1CB3D2DE8881C00352B1B76179C2D5939D60EF3A</PackageHash.2>    <NewPackageHash><Hash HashPreference="4" Algorithm="140789027962884" HashString="C055624DB492C09FDE3D8A6E1CB3D2DE8881C00352B1B76179C2D5939D60EF3A" SignatureHash="E78DACEE8AEFDA38A0D55B3BBE807E8DECAE1BC69E4420FE2EFA32AE0AC2BCC0"/></NewPackageHash>    <ProductCode></ProductCode>    <DisableMomAlerts>false</DisableMomAlerts>    <RaiseMomAlertOnFailure>false</RaiseMomAlertOnFailure>    <BalloonRemindersRequired>false</BalloonRemindersRequired>    <PersistOnWriteFilterDevices>true</PersistOnWriteFilterDevices>    <DefaultProgram>false</DefaultProgram>    <PersistInCache>0</PersistInCache>    <DistributeOnDemand>false</DistributeOnDemand>    <Multicast>false</Multicast>    <MulticastOnly>false</MulticastOnly>    <MulticastEncrypt>false</MulticastEncrypt>    <DonotFallback>true</DonotFallback>    <PeerCaching>true</PeerCaching>    <OptionalPreDownload>false</OptionalPreDownload>    <PreDownloadRule></PreDownloadRule>    <Requirements></Requirements>    <AssignmentID></AssignmentID>    <ScheduledMessageID>MEM2208F-MEM0112E-0CE1A3FC</ScheduledMessageID>    <OverrideServiceWindows>TRUE</OverrideServiceWindows>    <RebootOutsideOfServiceWindows>FALSE</RebootOutsideOfServiceWindows>    <WoLEnabled>FALSE</WoLEnabled>    <ContainsAdditionalProperties>FALSE</ContainsAdditionalProperties></SWDReserved>';$a.Put() | Out-Null
 $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$PackageAdvertID',PKG_PackageID='$PackageID',PRG_ProgramID='$ProgramID'");$a.PRG_Requirements='<?xml version=''1.0'' ?><SWDReserved>    <PackageHashVersion>4</PackageHashVersion>    <PackageHash.1></PackageHash.1>    <PackageHash.2>C055624DB492C09FDE3D8A6E1CB3D2DE8881C00352B1B76179C2D5939D60EF3A</PackageHash.2>    <NewPackageHash><Hash HashPreference="4" Algorithm="140789027962884" HashString="C055624DB492C09FDE3D8A6E1CB3D2DE8881C00352B1B76179C2D5939D60EF3A" SignatureHash="E78DACEE8AEFDA38A0D55B3BBE807E8DECAE1BC69E4420FE2EFA32AE0AC2BCC0"/></NewPackageHash>    <ProductCode></ProductCode>    <DisableMomAlerts>false</DisableMomAlerts>    <RaiseMomAlertOnFailure>false</RaiseMomAlertOnFailure>    <BalloonRemindersRequired>false</BalloonRemindersRequired>    <PersistOnWriteFilterDevices>true</PersistOnWriteFilterDevices>    <DefaultProgram>false</DefaultProgram>    <PersistInCache>0</PersistInCache>    <DistributeOnDemand>false</DistributeOnDemand>    <Multicast>false</Multicast>    <MulticastOnly>false</MulticastOnly>    <MulticastEncrypt>false</MulticastEncrypt>    <DonotFallback>true</DonotFallback>    <PeerCaching>true</PeerCaching>    <OptionalPreDownload>false</OptionalPreDownload>    <PreDownloadRule></PreDownloadRule>    <Requirements></Requirements>    <AssignmentID></AssignmentID>    <ScheduledMessageID>MEM2208F-MEM0112E-0CE1A3FC</ScheduledMessageID>    <OverrideServiceWindows>TRUE</OverrideServiceWindows>    <RebootOutsideOfServiceWindows>FALSE</RebootOutsideOfServiceWindows>    <WoLEnabled>FALSE</WoLEnabled>    <ContainsAdditionalProperties>FALSE</ContainsAdditionalProperties></SWDReserved>';$a.Put() | Out-Null

foreach ($Schedule in $ScheduleMessageID)
    {
    ([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule($($Schedule)) | Out-Null
    write-host "Triggered: $Schedule = $PackageName" -ForegroundColor Yellow
    }

}
Function Get-CCMCachePackageInfo {
    [cmdletbinding()]
    param ([string] $PackageID)
    $CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
    $CMCacheObjects = $CMObject.GetCacheInfo() 
    $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -match $PackageID}
    }
Function Get-CCMCacheUpgradeMediaPackageInfo {
    [cmdletbinding()]
    param ([string] $PackageID)
    $CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
    $CMCacheObjects = $CMObject.GetCacheInfo() 
    #$CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -match $PackageID}
    $OSUpgradeContent = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -eq "$PackageID"} 
    $ContentVersion = $OSUpgradeContent.ContentVersion | Sort-Object
    $HighestContentID = $ContentVersion | measure -Maximum
    $NewestContent = $OSUpgradeContent | Where-Object {$_.ContentVersion -eq $HighestContentID.Maximum}
    $NewestContent   
    }
Function Get-CCMCacheSizeInfo {
$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
$CMCacheObjects = $CMObject.GetCacheInfo() 
$UsedSpace = $($($CMCacheObjects.TotalSize) - $($CMCacheObjects.FreeSize))
$CacheSize = $($CMCacheObjects.TotalSize)
if ($CacheSize -lt 25600){write-host  "  CM Cache Size: $CacheSize MB | Used Space: $UsedSpace MB" -ForegroundColor red}
else{write-host  "  CM Cache Size: $CacheSize MB | Used Space: $UsedSpace MB" -ForegroundColor Green}
}
Function Get-CCMCachePackages {


$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
$CMCacheObjects = $CMObject.GetCacheInfo() 
$CIModel = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet

#$CCMUpdatePackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -match "-"}
$CCMPackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -notmatch "-"}
#$CCMCacheApps = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -match "Content"}

return $CCMPackages
}
Function Get-CCMCacheSoftwareUpdates {

$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
$CMCacheObjects = $CMObject.GetCacheInfo() 
$CIModel = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet

$CCMUpdatePackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -match "-"}
#$CCMPackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -notmatch "-"}
#$CCMCacheApps = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -match "Content"}

return $CCMUpdatePackages
}
Function Get-CCMCacheApps {

$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
$CMCacheObjects = $CMObject.GetCacheInfo() 
$CIModel = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet

#$CCMUpdatePackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -match "-"}
#$CCMPackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -notmatch "-"}
$CCMCacheApps = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -match "Content"}
$AppDatabase = @()
foreach ($App in $CCMCacheApps)
    {
    #$app.ContentId
    $Info = $CIModel | Where-Object {$_.InstallAction.Content.ContentId -eq $App.ContentId}
    $ContentID = $app.ContentId
    $Location = $app.Location
    $ContentVersion = $app.ContentVersion
    $ContentSize = $app.ContentSize
    $LastReferenceTime = $app.LastReferenceTime
    $AppDeliveryTypeId = $info.AppDeliveryTypeId
    $AppDTName = $info.AppDeliveryTypeName


    $AppDatabaseObject = New-Object PSObject -Property @{
        ContentId = $ContentID
        Location = $Location 
        ContentVersion = $ContentVersion
        ContentSize = $ContentSize
        LastReferenceTime = $LastReferenceTime
        AppDeliveryTypeId = $AppDeliveryTypeId
        AppDeliveryTypeName = $AppDTName
        }
        #Take the PS Object and append the Database Array    
        $AppDatabase += $AppDatabaseObject
    }

return $AppDatabase
}
Function Get-CCMCacheInfo {
    [cmdletbinding()]
    param ([switch] $Package, [switch] $Application, [switch] $Update)

    $CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
$CMCacheObjects = $CMObject.GetCacheInfo() 
$CIModel = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet

if ($Update)
    {
    $CCMUpdatePackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -match "-"}
    return $CCMUpdatePackages
    }
if ($Package)
    {
    $CCMPackages = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -notmatch "Content" -and $_.ContentId -notmatch "-"}
    return $CCMPackages
    }
if ($Application)
    {$CCMCacheApps = $CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentId -match "Content"}
    $AppDatabase = @()
    foreach ($App in $CCMCacheApps)
        {
        #$app.ContentId
        $Info = $CIModel | Where-Object {$_.InstallAction.Content.ContentId -eq $App.ContentId}
        $ContentID = $app.ContentId
        $Location = $app.Location
        $ContentVersion = $app.ContentVersion
        $ContentSize = $app.ContentSize
        $AppDeliveryTypeId = $info.AppDeliveryTypeId
        $AppDTName = $info.AppDeliveryTypeName

        $AppDatabaseObject = New-Object PSObject -Property @{
            ContentId = $ContentID
            Location = $Location 
            ContentVersion = $ContentVersion
            ContentSize = $ContentSize
            AppDeliveryTypeId = $AppDeliveryTypeId
            AppDeliveryTypeName = $AppDTName
            }
            #Take the PS Object and append the Database Array    
            $AppDatabase += $AppDatabaseObject
        }
    return $AppDatabase
    }
}
Function Remove-CCMCacheItem {
    [cmdletbinding()]
    param ([string] $ContentID)
# Connect to resource manager COM object    
$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
# Using GetCacheInfo method to return cache properties 
$CMCacheObjects = $CMObject.GetCacheInfo() 
# Delete Cache item 
$CMCacheObjects.GetCacheElements() | Where-Object {$_.ContentID -in $ContentID} | ForEach-Object { 
    $CMCacheObjects.DeleteCacheElementEx($_.CacheElementID,$True)
    Write-Host "Deleted: Name: $($_.ContentID)  Version: $($_.ContentVersion)" -ForegroundColor Red
    }
}
Function Get-TaskSequenceReferenceInfo {
    [cmdletbinding()]
    param ([string] $TSPackageID)



#$TSPackageID = 'MEM00A1B'

#$ItemID = 'MEM00A07'
$TSInfo = Get-CimInstance -Namespace root/ccm/Policy/Machine/ActualConfig -ClassName CCM_TaskSequence -Filter "PKG_PackageID='$TSPackageID'" 
$ReferenceItems = $TSInfo.TS_References
$CIModel = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet
$AppInfoWMI = Get-CimInstance -Namespace root/ccm/Policy/Machine -ClassName CCM_ApplicationCIAssignment
$TSDatabase = @()
$CachedPackageDatabase = @()
$PackageDatabase = @()
$AppDatabase = @()

foreach ($Item in $ReferenceItems)
    {
    $ItemID = (($Item.split(" ")[1]).split('"'))[1]
    #write-host "-------"
    if ($ItemID -notmatch "Application")
        {
        #$ItemID
        $CacheInfo = Get-CCMCachePackageInfo -PackageID $ItemID
        $TSItemInfo = (Get-TSInfo -TSPackageID $ItemID -ErrorAction SilentlyContinue).PKG_Name
        #if ($TSItemInfo.count -ge 1){$TSItemInfo = $TSItemInfo[0]}
        if ((!($TSItemInfo)) -and (!($CacheInfo)))
            {
            #Write-Host $ItemID
            $PackageDatabase += $ItemID
            }
        if ($TSItemInfo){$TSDatabase += $TSItemInfo}
        if ($CacheInfo)
            {
            if ($CacheInfo.count -gt 1){$CacheInfo = $CacheInfo[-1]}
            $CachedPackageDatabaseObject = New-Object PSObject -Property @{
            ContentId = $CacheInfo.ContentID
            Location = $CacheInfo.Location
            ContentVersion = $CacheInfo.ContentVersion
            ContentSize = $CacheInfo.ContentSize
            }
            #Take the PS Object and append the Database Array    
            $CachedPackageDatabase += $CachedPackageDatabaseObject
            }
        }
    else
        {
        #$ItemID
        $ItemID = $ItemID.Split("/")[1]
        $CIModel | Where-Object {$_.AppDeliveryTypeId -eq $ItemID}
        
        foreach ($AppInfo in $AppInfoWMI)
            {
            [XML]$XML = $AppInfo.AssignedCIs
            if ($XML.ci.ModelName -match $ItemID)
                {
                $AppDatabaseObject = New-Object PSObject -Property @{
                    AssignmentName = $AppInfo.AssignmentName
                    AssignmentID = $AppInfo.AssignmentID
                    }
                $AppDatabase += $AppDatabaseObject
                }
            }
        }
    }

Write-Host "---------------------------------" -ForegroundColor Gray
Write-Host "Referenced Packages Downloaded to Cache" -ForegroundColor Green
Write-Host ($CachedPackageDatabase | Out-String)

Write-Host "---------------------------------" -ForegroundColor Gray
Write-Host "Referenced Packages NOT in Cache" -ForegroundColor Green
Write-Host ($PackageDatabase | Out-String)

Write-Host "---------------------------------" -ForegroundColor Gray
Write-Host "Referenced Applications in TS" -ForegroundColor Green
Write-Host ($AppDatabase | Select-Object -Unique | Out-String)

Write-Host "---------------------------------" -ForegroundColor Gray
Write-Host "Task Sequence References" -ForegroundColor Green
Write-Host ($TSDatabase | Select-Object -Unique | Out-String)

}
Function ConvertFrom-Logs {
    [OutputType([PSObject[]])]
    Param
    (
        [Parameter(ValueFromPipeline)]
        [String] $string,
        [Int]$Tail,
        [String] $LogPath,
        [string] $Date,
        [string] $LogComponent,
        [Int] $Bottom = $Null,
        [DateTime] $After
    )
    
    Begin
    {
    
        If ($LogPath) 
        {
            If (Test-Path -Path $LogPath)
            {
                if ($Tail){$string = Get-Content -Path $LogPath -Tail $Tail}
                else {$string = Get-Content -Raw -Path $LogPath}
                
                $LogFileName = Get-Item -Path $LogPath |Select-Object -ExpandProperty name
            }
            Else
            {
                Return $False
            }
        }
    
        $SccmRegexShort = '\[LOG\[(?:.|\s)+?\]LOG\]'
        $SccmRegexLong = '(?im)((?<=\[LOG\[)((?:.|\s)+?)(\]LOG\]))(.{2,4}?)<(\s*[a-z0-9:\-\.\+]+="[_a-z0-9:\-\.\+]*")+>'

        $ErrorcodeRegex = '(?i)0x[0-9a-fA-F]{8}|(?<=\s)-\d{10}(?=\s)|(?<=code\s*)\d{1,}|(?<=error\s*)\d{1,}'
        $FilePathRegex = '(([a-zA-Z]\:)|(\\))(\\{1}|((\\{1})[^\\]([^/:*?<>"|]*))+)([/:*?<>"|]*(\.[a-zA-Z]+))'
    
        $StringLength = $string.Length    
        $Return = New-Object -TypeName System.Collections.ArrayList
    
    }
    Process
    {
        $TestLength = 500
        If ($StringLength -lt $TestLength)
        {
            $TestLength = $StringLength
        }
    
        #Which type is the log
        If ($StringLength -gt 5)
        {
            # SCCM Log Parshing
            If ([regex]::match($string.Substring(0,$TestLength),$SccmRegexShort).value,'Compiled')
            { 
                $SccmRegex = [regex]::matches($string,$SccmRegexLong)
        
                #foreach Line
                If (-not $Bottom -or $SccmRegex.count -lt $Bottom)
                {
                    $Bottom = $SccmRegex.count
                }
                For ($Counter = 1 ; $Counter -Lt $Bottom + 1; $Counter++)
                { 
                    $r = $SccmRegex[ $SccmRegex.count - $Counter]
                    $Errorcode = ''
                    $FilePath = ''
                    #get Message
                    $Hash = @{}
                    $Hash.Add('Message',$r.groups[2].value)
                    If($LogFileName)
                    {
                        $Hash.Add('LogFileName',$LogFileName)
                    }
                    If($LogPath)
                    {
                        $Hash.Add('LogPath',$LogPath)
                    }
                    #get additional information 
                    $parts = $r.groups |
                    Where-Object -FilterScript {
                        $_.captures.count -gt 1
                    } |
                    Select-Object -ExpandProperty captures

                    Foreach ($p in $parts)
                    {
                        If ($p.value -match '\w=')
                        {
                            $name = $p.value.split('=')[0].trim()
                            $value = $p.value.split('=')[1].replace('"','').Replace('>','').Replace('<','')
                            $Hash.Add($name, $value)
                        }
                    }
          
                    #convert to Datetime .net object
                    If ($Hash.Item('time') -ne $Null -and $Hash.Item('Date') -ne $Null)
                    {
                        $Hash.Add('TempTime', $Hash.Item('time'))
                        $Hash.Item('time') = [datetime] "$($Hash.Item('date')) $($Hash.Item('time').split('+')[0])"
                        If ($Hash.Item('time').gettype() -eq [datetime])
                        {
                            $Hash.Remove('Date')
                        }
                        Else
                        {
                            $Hash.Item('time') = $Hash.Item('TempTime')
                        }
                        $Hash.Remove('TempTime')
                    }
          
                    #get severity information
                    Switch ($Hash.Item('Type'))
                    {
                        0 
                        {
                            $Hash.Add('TypeName', 'Status')
                        }
                        1 
                        {
                            $Hash.Add('TypeName', 'Info')
                        }
                        2 
                        {
                            $Hash.Add('TypeName', 'Error')
                        }
                        3 
                        {
                            $Hash.Add('TypeName', 'Warning')
                        }
                        4 
                        {
                            $Hash.Add('TypeName', 'Verbose')
                        }
                        5 
                        {
                            $Hash.Add('TypeName', 'Debug')
                        }
                    }
          
                    #build object
                    If ($After -GT $Hash.Item('time') -and ([bool] $Hash.Item('time'))) 
                    {
                        $Counter = $SccmRegex.count
                    }
                    Try
                    {
                        [string] $Errorcode = [RegEx]::match($Hash['Message'],$ErrorcodeRegex 
                        ).value
                        $ErrorMSG = [ComponentModel.Win32Exception]::New([int]($Errorcode)).Message
                    }
                    Catch
                    {
                        $Errorcode = ''
                        $Error.removeat(0)
                    }
                    [string] $FilePath = [RegEx]::match($Hash['Message'],$FilePathRegex).value 
                    If ($Errorcode -ne '')
                    {
                        $Hash.Add('ErrorCode', $Errorcode)
                        $Hash.Add('ErrorMessage', $ErrorMSG)
                    }
                    If ($FilePath -ne '')
                    {
                        $Hash.Add('FilePath', $FilePath)
                    }
                    $TempObj = New-Object -TypeName PSobject -Property $Hash
                    $Return.add($TempObj)
                }
                [array]::Reverse($Return)
            }Else
            {
                Write-Warning -Message 'Not Sccm log format'
            }
        }
    }   
    End
    {
        Return $Return
    }
}
Function Convert-FromUnixDate ($UnixDate) {
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($UnixDate))
}
function Test-RegistryValue {

                    param (

    [parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]$Path,

[parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]$Value
    )

    try {

    Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        return $true
        }

    catch {

    return $false

}

}
Function Get-CMClientLogging {

$CMClientLogsKeysPath = "HKLM:SOFTWARE\Microsoft\CCM\Logging\@GLOBAL"
$CMClientLogsKeys = get-item $CMClientLogsKeysPath
$CMClientLogsKeys
}
Function Set-CMClientLogging {
    #https://docs.microsoft.com/en-us/mem/configmgr/core/plan-design/hierarchy/about-log-files
    [cmdletbinding()]
    param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("Default","Verbose","Warnings and Errors","Errors Only")]
    [string] $LogLevel,
    [Parameter(Mandatory=$false)]
    [int] $LogMaxHistory,
    [Parameter(Mandatory=$false)]
    [int] $LogMaxSizeMB,
    [Parameter(Mandatory=$false)]
    [Switch]$DebugLogging
    
    )
    $CMClientLogsKeysPath = "HKLM:SOFTWARE\Microsoft\CCM\Logging\@GLOBAL"
    $CMClientParentLogsKeysPath = "HKLM:SOFTWARE\Microsoft\CCM\Logging"
    $CMClientDebuggingLogsKeysPath = "HKLM:SOFTWARE\Microsoft\CCM\Logging\DebugLogging"
    if ($LogLevel){
        if ($LogLevel -eq "Default"){Set-ItemProperty -Path $CMClientLogsKeysPath -Name "LogLevel" -Value "1"}
        elseif ($LogLevel -eq "Verbose"){Set-ItemProperty -Path $CMClientLogsKeysPath -Name "LogLevel" -Value "0"}
        elseif ($LogLevel -eq "Warnings and Errors"){Set-ItemProperty -Path $CMClientLogsKeysPath -Name "LogLevel" -Value "2"}
        elseif ($LogLevel -eq "Errors Only"){Set-ItemProperty -Path $CMClientLogsKeysPath -Name "LogLevel" -Value "3"}
        Write-Output "Set LogLevel to $LogLevel"
        }
    if ($LogMaxHistory){
        Set-ItemProperty -Path $CMClientLogsKeysPath -Name "LogMaxHistory" -Value $LogMaxHistory
        Write-Output "Set LogMaxHistory to $LogMaxHistory"
        }
    if ($LogMaxSizeMB){
        $LogMaxSize = $LogMaxSizeMB * 1048576
        Set-ItemProperty -Path $CMClientLogsKeysPath -Name "LogMaxSize" -Value $LogMaxSize
        Write-Output "Set LogMaxSize to $LogMaxSize"
        }
    if ($DebugLogging){
        if ($DebugLogging -eq $True)
            {
            if (!(test-path -Path $CMClientDebuggingLogsKeysPath -ErrorAction SilentlyContinue)){New-Item -Path $CMClientParentLogsKeysPath -Name "DebugLogging" | Out-Null}
            Set-ItemProperty -Path $CMClientDebuggingLogsKeysPath -Name "Enabled" -Value "True"
            }
        else
            {
            Set-ItemProperty -Path $CMClientDebuggingLogsKeysPath -Name "Enabled" -Value "False"
            }
        Write-Output "Set LogMaxSize to $LogMaxSize"
        }
    Restart-Service -Name CcmExec
    }
Function Test-PendingReboot {
    function Test-RegistryKey {
            [OutputType('bool')]
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Key
            )
    
            $ErrorActionPreference = 'Stop'

            if (Get-Item -Path $Key -ErrorAction Ignore) {
                $true
            }
        }

        function Test-RegistryValue {
            [OutputType('bool')]
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Key,

                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Value
            )
    
            $ErrorActionPreference = 'Stop'

            if (Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) {
                $true
            }
        }

        function Test-RegistryValueNotNull {
            [OutputType('bool')]
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Key,

                [Parameter(Mandatory)]
                [ValidateNotNullOrEmpty()]
                [string]$Value
            )
    
            $ErrorActionPreference = 'Stop'

            if (($regVal = Get-ItemProperty -Path $Key -Name $Value -ErrorAction Ignore) -and $regVal.($Value)) {
                $true
            }
        }

    $tests = @(
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' }
            { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootInProgress' }
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' }
            { Test-RegistryKey -Key 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending' }
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting' }
            #{ Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations' }
            #{ Test-RegistryValueNotNull -Key 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Value 'PendingFileRenameOperations2' }
            { 
                # Added test to check first if key exists, using "ErrorAction ignore" will incorrectly return $true
                'HKLM:\SOFTWARE\Microsoft\Updates' | Where-Object { test-path $_ -PathType Container } | ForEach-Object {            
                    (Get-ItemProperty -Path $_ -Name 'UpdateExeVolatile' -ErrorAction Ignore | Select-Object -ExpandProperty UpdateExeVolatile) -ne 0 
                }
            }
            { Test-RegistryValue -Key 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Value 'DVDRebootSignal' }
            { Test-RegistryKey -Key 'HKLM:\SOFTWARE\Microsoft\ServerManager\CurrentRebootAttemps' }
            { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'JoinDomain' }
            { Test-RegistryValue -Key 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon' -Value 'AvoidSpnSet' }
            {
                # Added test to check first if keys exists, if not each group will return $Null
                # May need to evaluate what it means if one or both of these keys do not exist
                ( 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' | Where-Object { test-path $_ } | %{ (Get-ItemProperty -Path $_ ).ComputerName } ) -ne 
                ( 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' | Where-Object { Test-Path $_ } | %{ (Get-ItemProperty -Path $_ ).ComputerName } )
            }
            {
                # Added test to check first if key exists
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services\Pending' | Where-Object { 
                    (Test-Path $_) -and (Get-ChildItem -Path $_) } | ForEach-Object { $true }
            }
        )


    foreach ($test in $tests) {
	    if (& $test) {
		    $WindowsPendingReboot = "Windows"
            #Write-Output "Windows Pending Reboot: $true"
            #Write-Output $test
	    }
    }

    if (Get-Service -Name CcmExec){
        if ((Invoke-WmiMethod -Namespace 'root\ccm\ClientSDK' -Class CCM_ClientUtilities -Name DetermineIfRebootPending).RebootPending -eq "true" ){
        $CMPendingReboot = "ConfigMgr"
        #Write-Output "CM Pending Reboot $true"
        }
    }
    if ($CMPendingReboot -or $WindowsPendingReboot){
        if ($CMPendingReboot){
            $CMPendingReboot
        }
        if ($WindowsPendingReboot){
            $WindowsPendingReboot
        }
    }
    else {Write-Output "False"}
}
Function Get-SetupCommandLine {

write-host "Checking Log: smsts.log" -ForegroundColor Green
$smstslog = ConvertFrom-Logs -LogPath "C:\Windows\ccm\logs\smsts.log" -ErrorAction SilentlyContinue
$Message = $smstslog | Where-Object -FilterScript { $_.Message -match "Set command line:" -and $_.Message -match "/ImageIndex 1 /auto Upgrade /quiet /noreboot /postoobe" }
if ($Message)
    {
    write-host "Time: $($message.Time)" -ForegroundColor Green
            
    if ($Message.Message -match '%')
        {
        Write-Host "This is probably missing a variable being defined, look for % in the string" -ForegroundColor Red
        write-host $Message.Message -ForegroundColor Yellow
        }
    else
        {
        write-host $Message.Message -ForegroundColor Green
        }
    }
else
    {
    $SMTSLogFiles = Get-Item -Path c:\windows\ccm\logs\smsts-*.log | Sort-Object -Descending
    foreach ($LogFile in $SMTSLogFiles)
        {
        write-host "Checking Log: $($LogFile.fullname)" -ForegroundColor Green
        $smstslog = ConvertFrom-Logs -LogPath $LogFile.fullname -ErrorAction SilentlyContinue
        $Message = $smstslog | Where-Object -FilterScript { $_.Message -match "Set command line:" -and $_.Message -match "/ImageIndex 1 /auto Upgrade /quiet /noreboot /postoobe" }
        if ($Message)
            {
            write-host "Time: $($message.Time)" -ForegroundColor Green
            
            if ($Message.Message -match '%')
                {
                Write-Host "This is probably missing a variable being defined, look for % in the string" -ForegroundColor Red
                write-host $Message.Message -ForegroundColor Yellow
                }
            else
                {
                write-host $Message.Message -ForegroundColor Green
                }
            break
            }

        }
    }
}
Function Invoke-CMClientMachinePolicy {
#Invoke Machine Policy
[Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000021}')
[Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000022}')
Write-Output "Attempted Triggering Machine Policy Update"
}
Function Invoke-CMClientHWInv {
#Invoke Machine Policy
[Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000001}')
[Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000003}')
Write-Output "Attempted Triggering Hardware Inventory & DDR"
}
Function Invoke-CMClientHWInvFull {
$Action = "{00000000-0000-0000-0000-000000000001}"   #Hinv Action
Get-WmiObject -Namespace "root\ccm\invagt" -Class InventoryActionStatus | where {$_.InventoryActionID -eq "$Action"} | Remove-WmiObject
Invoke-WmiMethod -Namespace "root\ccm" -Class SMS_Client -Name TriggerSchedule -ArgumentList $Action -ErrorAction SilentlyContinue | Out-Null
Write-Output "Attempted Triggering Full Hardware Inventory"
}
Function Get-BITSThrottlingPolicy {
$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling"
$BitsPolicy = Get-Item $RegistryPath -ErrorAction SilentlyContinue
If($BitsPolicy.GetValue('EnableBandwidthLimits') -ne $null)
    {
    $BitsPolicyWorkSchedule = get-item -Path $RegistryPath\WorkSchedule
    $BitsPolicyWorkSchedule
    }
Else {Write-Output "No BITS Throttling Policy, No need to Set Maintenance"}

}
Function Set-BITSMaintenancePolicy {

param(
    [int]$ThrottleLimit = 20,
    [switch]$DeleteMaintenancePolicy
)
    
$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\BITS\Throttling"
if($DeleteMaintenancePolicy)
    {
    If (Test-Path $RegistryPath)
        {
        ## Delete Maintenance Policy (Re-enables the BITS Policy)
        Remove-Item "$RegistryPath\MaintenanceSchedule" -Force
        Remove-ItemProperty -Path $RegistryPath -Name "EnableMaintenanceLimits" -Force
        Write-Output "Removed BITS Maintenance Policy"
        }
    Else {Write-Output "No BITS Maintenance Policy to Remove"}
    }
else
    {
    If (Test-Path $RegistryPath) {
        $BitsPolicy = Get-Item $RegistryPath -ErrorAction SilentlyContinue
        If($BitsPolicy.GetValue('EnableBandwidthLimits') -ne $null) {
            New-ItemProperty -Path $RegistryPath -Name "EnableMaintenanceLimits" -PropertyType DWORD -Value "1" -Force
            If(!(Test-Path "$RegistryPath\MaintenanceSchedule")) {New-Item -Path "$RegistryPath\MaintenanceSchedule" -Force | Out-Null}
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "EndDay" -PropertyType DWORD -Value "6" -Force
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "EndHour" -PropertyType DWORD -Value "23" -Force
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "HighBandwidthLimit" -PropertyType DWORD -Value "0" -Force
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "HighBandwidthType" -PropertyType DWORD -Value "3" -Force
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "LowBandwidthLimit" -PropertyType DWORD -Value "0" -Force
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "LowBandwidthType" -PropertyType DWORD -Value "3" -Force
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "NormalBandwidthLimit" -PropertyType DWORD -Value "0" -Force
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "NormalBandwidthType" -PropertyType DWORD -Value "3" -Force
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "StartDay" -PropertyType DWORD -Value "0" -Force
            New-ItemProperty -Path "$RegistryPath\MaintenanceSchedule" -Name "StartHour" -PropertyType DWORD -Value "0" -Force
            Write-Output "Enabled BITS Maintenance Policy"
            }
        }
    Else {Write-Output "No BITS Throttling Policy, No need to Set Maintenance"}
    }
}
Function Get-WMIRepo {
$WMIRepositorySize = [math]::Round((get-item -Path C:\windows\system32\wbem\repository\OBJECTS.DATA).Length / 1024 / 1024,2) 
Write-Host "   WMI Repository Size: $WMIRepositorySize" -ForegroundColor Yellow
$Policies = Get-CimInstance -Namespace root/ccm/Policy/Machine/RequestedConfig -ClassName CCM_Policy_Policy3
Write-Host "   Total CM Policies: $($Policies.count)" -ForegroundColor Yellow
foreach ($Policy in ($Policies.PolicyCategory | Select-Object -Unique))
    {
    if (($Policies | Where-Object {$_.PolicyCategory -eq "$Policy"}).count -ge 1)
        {
        Write-Host "   $($Policy): $(($Policies | Where-Object {$_.PolicyCategory -eq "$Policy"}).count)" -ForegroundColor Green
        }
    }
}
Function Get-Baselines {
$Baselines = Get-CimInstance -Namespace root\ccm\policy\Machine\ActualConfig -ClassName CCM_DCMCIAssignment
#$Baselines.AssignmentName

if ($Baselines)
    {
    foreach ($Baseline in $Baselines)
        {
        [XML]$XML = $Baseline.AssignedCIs
        $BaselineDisplayName = $XML.ci.DisplayName
        $DeploymentCollection = ($Baseline.AssignmentName).replace("$($BaselineDisplayName)_","")
        write-host "  Baseline: $BaselineDisplayName  |  Deployed to: $DeploymentCollection" -ForegroundColor Green
        }
    }
}
Function Invoke-Baseline{
#For using in "Run Script" Node.  Has Exit At end... will exit your ISE if you run in ISE. :-)
#Adopted from another script, so it has some Write-Hosts that don't really make sense in a CI, deal with it.

[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true)]
            #[ValidateSet("WaaS 20H2 Pre-Assessment","WaaS 20H2 Pre-Assessment Pre-Prod","WaaS W10 TS Self-Service Notification","WaaS 1909 Pre-Assessment Legacy","SDE Pulse Recent Connection")]
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
