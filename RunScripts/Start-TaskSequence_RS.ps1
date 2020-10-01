<#Triggers Task Sequence based on Package ID Parameter
    @GWBLOK
    
    Once Triggered, it will wait 2 minutes, then parse the execmgr log using a function from Jeff Scripter: ConvertFrom-Log
    Once Parsed, looks for if the Task Sequence Successfully Started and reports back (Only if the Time Stamp for Starting is After the time you run the script)


#>
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true)][string]
		    $TSPackageID = "PS2000CA"
	    )

Function ConvertFrom-Logs
{
  <#
      .Synopsis
      Reads logs into an array of objects. 
    
      .DESCRIPTION
      Author:    Jeff Scripter
      Modified:  Jeff Scripter

      Purpose: 
      This function tries to parse logs into a object format allowing for greater ability to sort and parse for data.

      Return:
      Array of Custom objects:
      Message - The output of the log's line
      Date - date time in the log
      Type - 0 - status, 1 - information, 2 - error, 3 -warning, 4 - verbose, 5 - debug
      Typename - (status, information, error, warning, verbose, debug)
      Component - service, component, or code section logging the message
      <Other log spec info>

      Overview:
      Determines the type of log that is being parsed and converts it into an array of objects by looping through the Regex matches
      And building objects.

      .NOTES
      Comment:
      This can be a bit slow when parsing logs larger than 2mb. In these cases, it is helpful to remove extra lines before parsing.

      Assumptions:  
      Log follows certain formatting standards. 
    
      Changes:
      2017_03_13 - Original - Jeff Scripter - Original
      2017_05_02 - 1.0.1 - Jeff Scripter - Fixed sccm regex to not choke on _ in the components field and updated error\file parsing
      2017_06_02 - 1.0.2 - Jeff Scripter - Not flagging msi property lines as error

      Test Script: 
      1) 

      .EXAMPLE
      ConvertFrom-Logs -string (get-content -raw 'C:\windows\inf\setupapi.dev.log')
  #>

  [OutputType([Boolean])]
  Param
  (
    [Parameter( 
    ValueFromPipeline)]
    [String] $string,
    [String] $LogPath,
    [string] $Date,
    [string] $LogComponent,
    [Int] $Bottom = $Null,
    [DateTime] $After


  )
    
  Begin
  {
    $component = "$($MyInvocation.InvocationName)-1.0.2"
    
    If ($LogPath) 
    {
      If (Test-Path -Path $LogPath)
      {
        $string = Get-Content -Raw -Path $LogPath
        $LogFileName = Get-Item $LogPath |Select-Object -ExpandProperty name
      }
      Else
      {
        Return $False
      }
    }
    
    $dateRegex = '\d{1,2}\/\d{1,2}\/\d{4}'
    $timeRegex = '\d{1,2}\:\d{1,2}\:\d{2}(\:\d{3}){0,1}'
    
    $SccmRegexShort = '\[LOG\[(?:.|\s)+?\]LOG\]'
    $SccmRegexLong = '(?im)((?<=\[LOG\[)((?:.|\s)+?)(\]LOG\]))(.{2,4}?)<(\s*[a-z0-9:\-\.\+]+="[_a-z0-9:\-\.\+]*")+>'
    
    $CMTraceRegexShort = '.+?\$\$(.*?<(.*?)>.*?){3}'
    $CMTraceRegexLong = '(?im)\G((?:.|\s)+?)\$\$(.*?<(.*?)>.*?){3}'

    $MSIRegexShort = 'MSI \([sc]\)'
    $MSIRegexLong = '(?i)MSI \([sc]\) \([0-9a-f]{1,2}:[0-9a-f]{1,2}\) \[\d{1,2}:\d{1,2}:\d{1,2}:\d{1,3}\].*?'
    
    $IISRegexShort = '\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3} (POST|GET|PATCH|DELETE)' 
    
    $ErrorcodeRegex = '(?i)0x[0-9a-fA-F]{8}|(?<=\s)-\d{10}(?=\s)|(?<=code\s*)\d{1,}|(?<=error\s*)\d{1,}'
    $FilePathRegex = '(([a-zA-Z]\:)|(\\))(\\{1}|((\\{1})[^\\]([^/:*?<>"|]*))+)([/:*?<>"|]*(\.[a-zA-Z]+))'
    
    $StringLength = $string.Length
    
    
    $Return = @()
    
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
      If ([regex]::match($string.Substring(0,$TestLength),$SccmRegexShort).value)
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
          
          #convert to Dtaetime .net object
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
          If ($After -GT $Hash.Item('time') -and ([Boolean] $Hash.Item('time'))) 
          {
            $Counter = $SccmRegex.count
          }
          Try
          {
            [string] $Errorcode = [RegEx]::match($Hash['Message'],$ErrorcodeRegex 
            ).value
            $ErrorMSG = [System.ComponentModel.Win32Exception]::New([int32]($Errorcode)).Message
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
          $Return += New-Object -TypeName PSobject -Property $Hash
         
        }
        [array]::Reverse($Return)

      }
      
      #CMTrace log Parsing
      If (-not $Return)
      { 
        If ([regex]::match($string.Substring(0,$TestLength),$CMTraceRegexShort).value)
        {
          $CMTraceRegex = [regex]::matches($string, $CMTraceRegexLong)
          
          #Loop for each line
          If (-not $Bottom)
          {
            $Bottom = $CMTraceRegex.count
          }
          For ($Counter = 1 ; $Counter -Lt $Bottom + 1; $Counter++)
          { 
            $r = $CMTraceRegex[ $CMTraceRegex.count - $Counter]
                   
            #Get key information   
            $Hash = @{}
            $parts = $r.groups
            $Hash.add('Message', $parts[1].Value.trim())          
            $Hash.add('component',$parts[3].Captures[0].value)
            $Hash.add('time',([datetime]$parts[3].Captures[1].value))
            $Hash.add('thread',($parts[3].Captures[2].value.split('=')[1].replace('"','')))
            If($LogFileName)
            {
              $Hash.Add('LogFileName',$LogFileName)
            }
            If($LogPath)
            {
              $Hash.Add('LogPath',$LogPath)
            }
            #get severity
            :Type Switch ($true){
              ($Hash.Item('Message') -match '(error|fail)')
              {
                $Hash.add('Type',2)
                $Hash.Add('TypeName', 'Error')
                Break type
              }
              
               
              ($Hash.Item('Message') -match 'warning')
              {
                $Hash.add('Type',3)
                $Hash.Add('TypeName', 'Warning')
                Break type
              }
              
              ($Hash.Item('Message') -match 'verbose')
              {
                $Hash.add('Type',4)
                $Hash.Add('TypeName', 'Verbose')
                Break type
              }
              
              ($Hash.Item('Message') -match 'debug')
              {
                $Hash.add('Type',5)
                $Hash.Add('TypeName', 'Debug')
                Break type
              }
              
              Default
              {
                $Hash.add('Type',1)
                $Hash.Add('TypeName', 'Info')
                Break Type
              }
            }
            
            #Build Object
            If ($After -GT $Hash.Item('time') -and ([Boolean] $Hash.Item('time'))) 
            {
              $Counter = $CMTraceRegex.count
            }  
            Try
            {
              [string] $Errorcode = [RegEx]::match($Hash['Message'],$ErrorcodeRegex).value
              $ErrorMSG = [System.ComponentModel.Win32Exception]::New([int32]($Errorcode)).Message
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
            $Return += New-Object -TypeName PSobject -Property $Hash
          }
          [array]::Reverse($Return)
                    
        }
      }
      
      #MSI Log Parsing
      If (-not $Return)
      { 
        If ([regex]::match($string.Substring(0,$TestLength),$MSIRegexShort).value)
        {
          $MSIRegex = [Regex]::Matches($string,$MSIRegexLong)
          $Date = [regex]::match($string,$dateRegex).value
          $time = [regex]::match($string,$timeRegex).value
          $time = [regex]::replace($time,'\:([0-9]{3}$)',".$1")
          $MSIinfo = [regex]::match($string,'MSI \(([sc])\) \(([0-9a-f]{1,2}:[0-9a-f]{1,2})\)')
          $Thread = $MSIinfo.groups[2].value
          $LogComponent = [regex]::match($string,'\w+\.msi').value
          If (-not $Date)
          {
            $Date = $Date
          }

          Foreach ($s in $string.split("`n`r", [System.StringSplitOptions]::RemoveEmptyEntries))
          {
            $Hash = @{}
            $Hash.add('Message', $s)  
            If($LogFileName)
            {
              $Hash.Add('LogFileName',$LogFileName)
            }
            If($LogPath)
            {
              $Hash.Add('LogPath',$LogPath)
            }        
            $d = [regex]::match($s,$dateRegex).value
            If ($d)
            {
              $Date = $d
            }
            $t = [regex]::match($s,$timeRegex).value
            $t = [regex]::replace($t,'\:([0-9]{3}$)','.$1')
            If ($t)
            {
              $time = $t
            }
            If ($Date -and $time)
            {
              $Hash.add('time',([datetime]"$Date $time"))
            }
            $MSIinfo = [regex]::match($string,'MSI \(([sc])\) \(([0-9a-f]{1,2}:[0-9a-f]{1,2})\)')
            If ($MSIinfo)
            {
              $Thread = $MSIinfo.groups[2].value
            }
            $Hash.add('thread',$Thread)
            $Hash.add('Component',$LogComponent)

            Switch ($true){
              ($Hash.Item('Message') -match '(error|fail)' -and $Hash.Item('Message') -notmatch '(Property\(.\)|Note):' )
              {
                $Hash.add('Type',2)
                $Hash.Add('TypeName', 'Error')
                Break
              }
              
               
              ($Hash.Item('Message') -match 'warning')
              {
                $Hash.add('Type',3)
                $Hash.Add('TypeName', 'Warning')
                Break
              }
              
              ($Hash.Item('Message') -match 'verbose')
              {
                $Hash.add('Type',4)
                $Hash.Add('TypeName', 'Verbose')
                Break
              }
              
              ($Hash.Item('Message') -match 'debug')
              {
                $Hash.add('Type',5)
                $Hash.Add('TypeName', 'Debug')
                Break
              }
              
              Default
              {
                $Hash.add('Type',1)
                $Hash.Add('TypeName', 'Info')
                Break
              }
            }
            Try
            {
              [string] $Errorcode = [RegEx]::match($Hash['Message'],$ErrorcodeRegex).value
              $ErrorMSG = [System.ComponentModel.Win32Exception]::New([int32]($Errorcode)).Message
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
            $Return += New-Object -TypeName PSobject -Property $Hash
          }
                  
        }
      }

      #IIS Log Parsing
      If (-not $Return)
      { 
        If ([regex]::match($string.Substring(0,$TestLength),$IISRegexShort).value)
        {
          $IISRows = $string.split("`n`r", [System.StringSplitOptions]::RemoveEmptyEntries) |Where-Object -FilterScript {
            $_[0] -ne '#'
          }
          $IISFields = [regex]::Match($string,'(?i)#Fields:(.*)').groups[1].value.split(' ',[System.StringSplitOptions]::RemoveEmptyEntries)


          #Loop for each line
          If (-not $Bottom)
          {
            $Bottom = $IISRows.count
          }
          For ($Counter = 1 ; $Counter -Lt $Bottom + 1; $Counter++)
          { 
            $r = $IISRows[ $IISRows.count - $Counter]
            $Hash = @{}
            If($LogFileName)
            {
              $Hash.Add('LogFileName',$LogFileName)
            }
            If($LogPath)
            {
              $Hash.Add('LogPath',$LogPath)
            }
            #Get logged fields
            Foreach ($F in $IISFields)
            { 
              If ($F -ilike 'Date' )
              {
                $Date = $r.split(' ')[$IISFields.IndexOf($F)]
              }
              ElseIf ($F -ilike 'Time')
              {
                $time = $r.split(' ')[$IISFields.IndexOf($F)]
              }
              Else
              {
                $Hash.add($F,$r.split(' ')[$IISFields.IndexOf($F)])
              }
            }
            
            #get core information
            $Hash.add('Message', $r)         
            $Hash.add('Time', ([DateTime] "$Date $time"))    
            $Hash.add('thread',$Thread)
            $Hash.add('Component',$LogComponent)

            #Severity information
            Switch ($true){
              ($Hash.Item('sc-status') -match '5\d\d')
              {
                $Hash.add('Type',2)
                $Hash.Add('TypeName', 'ServerError')
                Break
              }
              
               
              ($Hash.Item('sc-status') -match '4\d\d')
              {
                $Hash.add('Type',3)
                $Hash.Add('TypeName', 'ClientError')
                Break
              }
              
              ($Hash.Item('sc-status') -match '3\d\d')
              {
                $Hash.add('Type',4)
                $Hash.Add('TypeName', 'Redirection')
                Break
              }
              
              ($Hash.Item('sc-status') -match '2\d\d')
              {
                $Hash.add('Type',1)
                $Hash.Add('TypeName', 'Success')
                Break
              }  
                          
              ($Hash.Item('sc-status') -match '1\d\d')
              {
                $Hash.add('Type',5)
                $Hash.Add('TypeName', 'Verbose')
                Break
              }
              
              Default
              {
                $Hash.add('Type',4)
                $Hash.Add('TypeName', 'Debug')
                Break
              }
            }
            If ($After -GT $Hash.Item('time') -and ([Boolean] $Hash.Item('time'))) 
            {
              $Counter = $IISRows.count
            }       
            Try
            {
              [string] $Errorcode = [RegEx]::match($Hash['Message'],$ErrorcodeRegex).value
              $ErrorMSG = [System.ComponentModel.Win32Exception]::New([int32]($Errorcode)).Message
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
            $Return += New-Object -TypeName PSobject -Property $Hash
          }
          [array]::Reverse($Return)
                    
        }
      }
      
      
      #Other Logs
      If (-not $Return)
      { 
        #get date info
        $Date = [regex]::match($string,$dateRegex).value
        $time = [regex]::match($string,$timeRegex).value
        $time = [regex]::replace($time,'\:([0-9]{3}$)','.$1')
        $Thread = [regex]::match($string,'(?i)thread="*([a-f0-9\:]+)"*').groups[1].value
        $componentregex = [regex]::match($string,'(?i)component="*([a-z0-9\:]+)"*').groups[1].value
        If ($componentregex)
        {
          $LogComponent = $componentregex
        }
        If (-not $Date)
        {
          $Date = $Date
        }

        #gather message and update date when needed
        Foreach ($s in $string.split("`n`r", [System.StringSplitOptions]::RemoveEmptyEntries))
        {
          $Hash = @{}
          $Hash.add('Message', $s.trim()) 
          If($LogFileName)
          {
            $Hash.Add('LogFileName',$LogFileName)
          }
          If($LogPath)
          {
            $Hash.Add('LogPath',$LogPath)
          }         
          $d = [regex]::match($s,$dateRegex).value
          If ($d)
          {
            $Date = $d
          }
          $t = [regex]::match($s,$timeRegex).value
          $t = [regex]::replace($t,'\:([0-9]{3}$)','.$1')
          If ($t)
          {
            $time = $t
          }
          If ($Date -and $time)
          {
            $Hash.add('time',([datetime]"$Date $time"))
          }
          $Threadregex = [regex]::match($string,'(?i)thread="*([a-f0-9\:]+)"*').groups[1].value
          If ($Threadregex)
          {
            $Thread = $Threadregex
          }
          $Hash.add('thread',$Thread)
          $componentregex = [regex]::match($string,'(?i)component="*([a-z0-9\:]+)"*').groups[1].value
          If ($componentregex)
          {
            $LogComponent = $componentregex
          }
          $Hash.add('Component',$LogComponent)

          #severity info
          Switch ($true){
            ($Hash.Item('Message') -match '(error|fail)')
            {
              $Hash.add('Type',2)
              $Hash.Add('TypeName', 'Error')
              Break
            }
              
               
            ($Hash.Item('Message') -match 'warning')
            {
              $Hash.add('Type',3)
              $Hash.Add('TypeName', 'Warning')
              Break
            }
              
            ($Hash.Item('Message') -match 'verbose')
            {
              $Hash.add('Type',4)
              $Hash.Add('TypeName', 'Verbose')
              Break
            }
              
            ($Hash.Item('Message') -match 'debug')
            {
              $Hash.add('Type',5)
              $Hash.Add('TypeName', 'Debug')
              Break
            }
              
            Default
            {
              $Hash.add('Type',1)
              $Hash.Add('TypeName', 'Info')
              Break
            }
          }
          
          Try
          {
            [string] $Errorcode = [RegEx]::match($Hash['Message'],$ErrorcodeRegex).value
            $ErrorMSG = [System.ComponentModel.Win32Exception]::New([int32]($Errorcode)).Message
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
          $Return += New-Object -TypeName PSobject -Property $Hash
        }
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
    get-wmiobject -query "SELECT * FROM CCM_Scheduler_ScheduledMessage WHERE ScheduledMessageID='$TSDeployID-$TSPackageID-$TSLastGroup'" -namespace "ROOT\ccm\policy\machine\actualconfig" | Out-Null
    $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'");$a.ADV_RepeatRunBehavior='RerunAlways';$a.Put() | Out-Null
    $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'");$a.ADV_MandatoryAssignments=$True;$a.Put() | Out-Null
    $a=([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_TaskSequence.ADV_AdvertisementID='$TSDeployID',PKG_PackageID='$TSPackageID',PRG_ProgramID='*'");$a.PRG_Requirements='<?xml version=''1.0'' ?><SWDReserved>    <PackageHashVersion>1</PackageHashVersion>    <PackageHash.1></PackageHash.1>    <PackageHash.2></PackageHash.2>    <NewPackageHash></NewPackageHash>    <ProductCode></ProductCode>    <DisableMomAlerts>false</DisableMomAlerts>    <RaiseMomAlertOnFailure>false</RaiseMomAlertOnFailure>    <BalloonRemindersRequired>false</BalloonRemindersRequired>    <PersistOnWriteFilterDevices>true</PersistOnWriteFilterDevices>    <DefaultProgram>true</DefaultProgram>    <PersistInCache>0</PersistInCache>    <DistributeOnDemand>false</DistributeOnDemand>    <Multicast>false</Multicast>    <MulticastOnly>false</MulticastOnly>    <MulticastEncrypt>false</MulticastEncrypt>    <DonotFallback>false</DonotFallback>    <PeerCaching>true</PeerCaching>    <OptionalPreDownload>true</OptionalPreDownload>    <PreDownloadRule></PreDownloadRule>    <Requirements></Requirements>    <AssignmentID></AssignmentID>    <ScheduledMessageID>CAS29CDE-CAS04823-6F6BCC28</ScheduledMessageID>    <OverrideServiceWindows>TRUE</OverrideServiceWindows>    <RebootOutsideOfServiceWindows>FALSE</RebootOutsideOfServiceWindows>    <WoLEnabled>FALSE</WoLEnabled>    <ShowTSProgressUI>FALSE</ShowTSProgressUI>    <UseTSCustomProgressMessage>FALSE</UseTSCustomProgressMessage>    <TSCustomProgressMessage><![CDATA[]]></TSCustomProgressMessage>    <ContainsAdditionalProperties>FALSE</ContainsAdditionalProperties></SWDReserved>';$a.Put() | Out-Null
    foreach ($TS in $TSScheduleMessageID)
        {
        ([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule($($TS)) | Out-Null
        Write-Output "Triggered TS"
        }


    Start-Sleep -Seconds 120  #Gives time on the client to trigger TS and do it's stuff before we start to query how it went

    $ExecMgrLog = ConvertFrom-Logs -LogPath C:\Windows\CCM\logs\execmgr.log
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
