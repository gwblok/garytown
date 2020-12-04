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
Function ConvertFrom-Logs {
    [OutputType([PSObject[]])]
    Param
    (
        [Parameter(ValueFromPipeline)]
        [String] $string,
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
                $string = Get-Content -Raw -Path $LogPath
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
        write-output "$TS |"
        }

    start-sleep -Seconds 20
    $TSExecutionRequests = Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest | Where-Object { $_.ContentID -eq $TSPackageID} | Select-Object AdvertID, ContentID, @{Label='ReceivedTime'; Expression={[System.Management.ManagementDateTimeConverter]::ToDatetime($_.ReceivedTime)}}
    if ($TSExecutionRequests){Write-Output "  CCM_TSExecutionRequest $($TSExecutionRequests.ReceivedTime) |"}
    Else {
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
        $TSExecutionRequests = Get-WmiObject -Namespace Root\CCM\SoftMgmtAgent -Class CCM_TSExecutionRequest | Where-Object { $_.ContentID -eq $TSPackageID} | Select-Object AdvertID, ContentID, @{Label='ReceivedTime'; Expression={[System.Management.ManagementDateTimeConverter]::ToDatetime($_.ReceivedTime)}}
        if ($TSExecutionRequests){Write-Output "  CCM_TSExecutionRequest $($TSExecutionRequests.ReceivedTime) |"}
        else {Write-Output " NO CCM_TSExecutionRequest |"}
        }
    #write-host "  Waiting 2 minutes for process to have time to run and fill logs" -ForegroundColor Yellow
    Start-Sleep -Seconds 90  #Gives time on the client to trigger TS and do it's stuff before we start to query how it went
    $ExecMgrLog = $null
    $ExecMgrLog = ConvertFrom-Logs -LogPath C:\Windows\CCM\logs\execmgr.log | Where-Object { $_.Message -match $TSPackageID}
    if (!($ExecMgrLog)){$ExecMgrLog = ConvertFrom-Logs -LogPath C:\Windows\CCM\logs\execmgr-*.log | Where-Object { $_.Message -match $TSPackageID}}
    $Last2Instances = $null
    $Last2Instances = $ExecMgrLog | Where-Object { $_.Message -match "Execution Request for advert"} | Sort-Object -Property time | Select-Object -Last 2
    foreach ($Instance in $Last2Instances)
        {
        #write-host "  $($Instance.Message) at $($Instance.time)"
        }

    #$ExecMgrLog | Where-Object { $_.Message -match $TSPackageID}
    #$ExecMgrLogString = $ExecMgrLog | Where-Object -FilterScript { $_ -match "The task sequence $TSPackageID was successfully started"}
    $ExecMgrLogString = $ExecMgrLog | Where-Object -FilterScript { $_.Message -match "The task sequence $TSPackageID was successfully started"}
    $ExecMgrLogString = $ExecMgrLogString | Where-Object -FilterScript {$_.Time -eq ($ExecMgrLogString.time | measure -Maximum).Maximum}
    $ExecMgrLogMWString = $ExecMgrLog | Where-Object -FilterScript { $_.Message -eq "MTC task for SWD execution request with program id: *, package id: $TSPackageID is waiting for service window."}
    $ExecMgrLogMWString = $ExecMgrLogMWString | Where-Object -FilterScript {$_.Time -eq ($ExecMgrLogMWString.time | measure -Maximum).Maximum}
    
    if ($CurrentTimeStamp -lt $ExecMgrLogString.time){Write-Output "Successfully Started"}
    Else 
        {
        if ($ExecMgrLogMWString -and $NoTrigger)
            {
            $CMServiceWindows = Get-WMIObject -Namespace 'ROOT\ccm\Policy\Machine\RequestedConfig' -Query 'SELECT * FROM CCM_ServiceWindow WHERE PolicySource <> "Local" '
            Write-output "Waiting for MW"
            }
        Else
            {
            Write-Output "Failed to Start"
            $NoTrigger = $true
            }
        }

    }
Else {Write-Output "No Task Sequence for Package ID $TSPackageID on this Machine"}
