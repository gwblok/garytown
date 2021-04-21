<#
Gary Blok | @gwblok | Recast Software

Checks for Compliance of Dell Command Update XML (Available Updates) from the XML created on Dell Command | Cloud Repository Manager
Confirms Dell Command Update is set to use our custom XML

You'll want to update the $OrgName

Requires that you have the XML you generated available on a webserver.  I'm using GitHub cuz it's free.
Requires that you name the XML Model-Ring.xml where Model = Model of Machine (WITHOUT SPACES) and Ring = Prod or Pre-Prod
  File Name Example: OptiPlex7050-Pre-Prod.xml
  Full URL Example: https://raw.githubusercontent.com/gwblok/garytown/master/hardware/Dell/CommandUpdate/OptiPlex7050-Pre-Prod.xml

#>


$ScriptVersion = "21.4.19.1"
$whoami = $env:USERNAME
$IntuneFolder = "$env:ProgramData\Intune"
$LogFilePath = "$IntuneFolder\Logs"
$LogFile = "$LogFilePath\Dell-Updates.log"
$scriptName = "Dell DCU XML - From GitHub"
[String]$SystemSKUNumber = (Get-CimInstance -ClassName Win32_ComputerSystem).SystemSKUNumber
[String]$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
[String]$Model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
$OrgName = "Recast_IT"
$ITFolder = "$env:ProgramData\$OrgName"
$ITRegPath = "HKLM:\SOFTWARE\$OrgName"
$ProxyConnection = "proxy-recastsoftware.com"
$ProxyConnectionPort = "8080"

if (!(Test-Path -Path $LogFilePath)){$null = New-Item -Path $LogFilePath -ItemType Directory -Force}
if (!(Test-Path -Path $ITFolder)){$null = New-Item -Path $ITFolder -ItemType Directory -Force}
if (!(Test-Path -Path $ITRegPath)){$null = New-Item -Path $ITRegPath -ItemType Registry -ErrorAction SilentlyContinue}

$ITRegItem = Get-Item -Path $ITRegPath
if ($ITRegItem.GetValue("Ring") -ne $null){$Ring = $ITRegItem.GetValue("Ring")}
else{$Ring = "Prod"}

$XMLName = "$($Model.replace(' ',''))-$ring.xml"
$XMLTempFolder = "$env:temp\DellDownloads"
$XMLTempFilePath = "$XMLTempFolder\$XMLName"
$XMLURLParent = "https://raw.githubusercontent.com/gwblok/garytown/master/hardware/Dell/CommandUpdate"
$XMLURLFile = "$XMLURLParent/$XMLName"

$Compliance = $true
$Remediate = $false

if ($Remediate -eq $true)
    {$ComponentText = "DCU XML - Remediation"}
else {$ComponentText = "DCU XML - Detection"}

Function Get-InstalledApplication {
  [CmdletBinding()]
  Param(
    [Parameter(
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true
    )]
    [String[]]$ComputerName=$ENV:COMPUTERNAME,

    [Parameter(Position=1)]
    [String[]]$Properties,

    [Parameter(Position=2)]
    [String]$IdentifyingNumber,

    [Parameter(Position=3)]
    [String]$Name,

    [Parameter(Position=4)]
    [String]$Publisher
  )
  Begin{
    Function IsCpuX86 ([Microsoft.Win32.RegistryKey]$hklmHive){
      $regPath='SYSTEM\CurrentControlSet\Control\Session Manager\Environment'
      $key=$hklmHive.OpenSubKey($regPath)

      $cpuArch=$key.GetValue('PROCESSOR_ARCHITECTURE')

      if($cpuArch -eq 'x86'){
        return $true
      }else{
        return $false
      }
    }
  }
  Process{
    foreach($computer in $computerName){
      $regPath = @(
        'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
      )

      Try{
        $hive=[Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
          [Microsoft.Win32.RegistryHive]::LocalMachine, 
          $computer
        )
        if(!$hive){
          continue
        }
        
        # if CPU is x86 do not query for Wow6432Node
        if($IsCpuX86){
          $regPath=$regPath[0]
        }

        foreach($path in $regPath){
          $key=$hive.OpenSubKey($path)
          if(!$key){
            continue
          }
          foreach($subKey in $key.GetSubKeyNames()){
            $subKeyObj=$null
            if($PSBoundParameters.ContainsKey('IdentifyingNumber')){
              if($subKey -ne $IdentifyingNumber -and 
                $subkey.TrimStart('{').TrimEnd('}') -ne $IdentifyingNumber){
                continue
              }
            }
            $subKeyObj=$key.OpenSubKey($subKey)
            if(!$subKeyObj){
              continue
            }
            $outHash=New-Object -TypeName Collections.Hashtable
            $appName=[String]::Empty
            $appName=($subKeyObj.GetValue('DisplayName'))
            if($PSBoundParameters.ContainsKey('Name')){
              if($appName -notlike $name){
                continue
              }
            }
            if($appName){
              if($PSBoundParameters.ContainsKey('Properties')){
                if($Properties -eq '*'){
                  foreach($keyName in ($hive.OpenSubKey("$path\$subKey")).GetValueNames()){
                    Try{
                      $value=$subKeyObj.GetValue($keyName)
                      if($value){
                        $outHash.$keyName=$value
                      }
                    }Catch{
                      Write-Warning "Subkey: [$subkey]: $($_.Exception.Message)"
                      continue
                    }
                  }
                }else{
                  foreach ($prop in $Properties){
                    $outHash.$prop=($hive.OpenSubKey("$path\$subKey")).GetValue($prop)
                  }
                }
              }
              $outHash.Name=$appName
              $outHash.IdentifyingNumber=$subKey
              $outHash.Publisher=$subKeyObj.GetValue('Publisher')
              if($PSBoundParameters.ContainsKey('Publisher')){
                if($outHash.Publisher -notlike $Publisher){
                  continue
                }
              }
              $outHash.ComputerName=$computer
              $outHash.Version=$subKeyObj.GetValue('DisplayVersion')
              $outHash.Path=$subKeyObj.ToString()
              New-Object -TypeName PSObject -Property $outHash
            }
          }
        }
      }Catch{
        Write-Error $_
      }
    }
  }
  End{}
}
function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = $ComponentText,
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile = "$env:ProgramData\Intune\Logs\IForgotToNameTheLogVar.log"
	    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
 
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }

CMTraceLog -Message  "---------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Starting $ScriptName, $ScriptVersion | Remediation Mode $Remediate" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Running as $whoami" -Type 1 -LogFile $LogFile

if ($Manufacturer -match "Dell")
    {

    $InstallApps = Get-InstalledApplication
    $InstalledDCU = $InstallApps | Where-Object {$_.Name -match 'Dell Command' -and $_.Name -match 'Update'}

    if ($InstalledDCU)
        {
        # Test Proxy ############################
        if ((Test-NetConnection $ProxyConnection -Port $ProxyConnectionPort).PingSucceeded -eq $true)
            {
            $UseProxy = $true
            $ProxyServer = "http://proxy-recastsoftware.com:8080"
            $BitsProxyList = @("10.1.1.5:8080, 10.2.2.5:8080, 10.3.3.5:8080")
            Write-Output "Found Proxy Server, using for Downloads"
            [system.net.webrequest]::DefaultWebProxy = new-object system.net.webproxy("$ProxyServer")
            }
        Else 
            {
            $UseProxy = $False
            $ProxyServer = $null
            $BitsProxyList = $null
            Write-Output "No Proxy Server Found, continuing without"
            }

        # Download our XML and compare against Current XML
        if (!(Test-Path $XMLTempFolder)){$newfolder = New-Item -Path $XMLTempFolder -ItemType Directory -Force}
        Write-Host "Downloading Dell $Model XML" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $XMLURLFile -OutFile $XMLTempFilePath -UseBasicParsing -Verbose -Proxy $ProxyServer
        
        [XML]$XMLDownloaded = Get-Content -Path $XMLTempFilePath
        $XMLDownloadDate = $XMLDownloaded.Manifest.dateTime

        if (Test-Path -Path "$ITFolder\$XMLName")
            {
            [XML]$XMLCurrent = Get-Content -Path "$ITFolder\$XMLName"
            $XMLCurrentDate = $XMLCurrent.Manifest.dateTime
            }
        if ($XMLDownloadDate -gt $XMLCurrentDate)
            {
            if ($Remediate -eq $true)
                {
                CMTraceLog -Message  "Replace Current XML: $XMLCurrentDate with Downloaded: $XMLDownloadDate." -Type 1 -LogFile $LogFile
                Copy-Item -Path $XMLTempFilePath -Destination "$ITFolder\$XMLName" -Force
                }
            else
                {
                CMTraceLog -Message  "Need to Replace Current XML: $XMLCurrentDate with Downloaded: $XMLDownloadDate." -Type 1 -LogFile $LogFile
                exit 1
                }
            }
        else
            {
            CMTraceLog -Message  "DCU Custom XML is already Current" -Type 1 -LogFile $LogFile
            }
        #Make sure DCU is pointed at our XML
        $DCUItem = Get-Item -Path "HKLM:\SOFTWARE\DELL\UpdateService\Clients\CommandUpdate\Preferences\Settings\General"
        if ($DCUItem.GetValue('CustomCatalogPaths') -ne "$ITFolder\$XMLName")
            {
            if ($Remediate -eq $true)
                {
                if (Test-Path -Path "$ITFolder\$XMLName")
                    {
                    CMTraceLog -Message  "Updating DCU to point to our Custom XML" -Type 1 -LogFile $LogFile
                    CMTraceLog -Message  "Updating Reistry" -Type 1 -LogFile $LogFile
                    if ($DCUItem.GetValue('CustomCatalogPaths') -eq $null)
                        {
                        New-ItemProperty -Path $DCUItem.PSPath -Name "CustomCatalogPaths" -Value "$ITFolder\$XMLName" -PropertyType MultiString
                        }
                    else
                        {
                        Set-ItemProperty -Path $DCUItem.PSPath -Name "CustomCatalogPaths" -Value "$ITFolder\$XMLName"
                        }
                    }
                }
            else
                {
                CMTraceLog -Message  "Need to update DCU to point to our Custom XML." -Type 1 -LogFile $LogFile
                exit 1
                }
            }
        }
    else
        {
        CMTraceLog -Message  "Does not have DCU Installed." -Type 2 -LogFile $LogFile
        }
        
    }
else
    {
    CMTraceLog -Message  "This isn't a Dell... exiting... check with admin on why this is running.  Script should only be applied to a dynamic group that contains Dell computers." -Type 2 -LogFile $LogFile
    }
