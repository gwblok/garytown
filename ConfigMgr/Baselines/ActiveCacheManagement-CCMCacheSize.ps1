<#
Gary Blok | @gwblok | RecastSoftware.com
Credit Keith Garner for most of the code

.SYNOPSIS
SCCM Cache Management script

.DESCRIPTION
Basic management of local CCM Cache
if the HD is 250GB or less, Sets the CCMCache to 25GB ($CacheMinSize)
if the HD is 500GB or more, Sets the CCMCache to 50GB Max ($CacheMaxSize)
If anything in the middle, sets it to 10% of Disk Size.

.NOTES

WHen running with a CI:

For testing (Detection) change $DetectionMode = $true.
    And test for 'Success'

For Remediation ensure $DetectionMode = $false (or empty), and run.

#>

$CacheMinSize = 25600
$CacheMaxSize = 51200

$OrgName = "Recast_IT"
[string]$Version = '2021.04.22'
$RegConfig = "HKLM:\Software\$OrgName\Cache"
$LogName = "CCMCacheChecker.log"
$LogDir = "$env:ProgramData\$OrgName\Logs"
$LogFile = "$LogDir\$LogName"
$ComponentText = "CCMCacheCheck"
$DetectionMode=$true
if (!(Test-Path -Path $LogDir)){New-Item -Path $LogDir -ItemType Directory -Force}

$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr'  
$CMCacheObjects = $CMObject.GetCacheInfo() 
$CCMCacheLocation = $CMCacheObjects.Location

#region Logging & Error Reporting
#############################################################


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
		    $LogFile = "$env:ProgramData\Logs\IForgotToNameTheLogVar.log"
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
Function Exit-WithError {
    [cmdletbinding()]
    param ( 
        [int] $ExitCode,
        [string] $Msg
    )


    if ( $ExitCode -ne 0 ) { 
        CMTraceLog -Message  "ERROR: $Msg" -Type 1 -LogFile $LogFile
        New-EventLog -LogName Application -Source 'CCMCacheChecker' -ErrorAction SilentlyContinue
        Write-EventLog -LogName Application -Source 'CCMCacheChecker' -EventId $ExitCode -Message $msg
    }
    else {
        CMTraceLog -Message  "$Msg" -Type 1 -LogFile $LogFile
    }

    Set-ItemProperty -path $RegConfig -name 'LastStatusInt' -Value $ExitCode 
    Set-ItemProperty -path $RegConfig -name 'LastStatusMsg' -Value $Msg

    exit $ExitCode
}

#endregion

#region Test Functions
#############################################################

function Test-AgeInDays {
    [cmdletbinding()]
    param( 
        [parameter(Mandatory=$true, ValueFromPipeline=$true)]        
        $Keys,
        [int] $lt,
        [int] $gt,
        [int] $eq
     )

    process {

        foreach ( $Key in $Keys ) {

            $StartDate = [DateTime]::ParseExact($Key.FinishTimeUTC,"yyyyMMddHHmmssfff", $null )
            $TimeSpan = new-timespan -start $StartDate -end (get-Date)
            if ( $lt ) {
                $key | where-object { $TimeSpan.TotalDays -lt $lt } | write-output
            } 
            elseif ( $gt ) {
                $key | where-object { $TimeSpan.TotalDays -gt $gt } | write-output
            }
            else {
                $TimeSpan | % TotalDays | write-output
            }
        }
    }
}

#endregion

#region External Primitaves
#############################################################

$global:CCM = $null

function Get-CCMCachePath {
    Get-CCMCacheSettings location | Write-Output
}

function Get-AppSettings {
    [cmdletbinding()]
    param ( [string] $Name )
    if ( -not ( test-path $RegConfig ) ) {
        new-item -ItemType Directory -Path $RegConfig -force -ErrorAction SilentlyContinue | Out-Null
    }
    try { Get-ItemPropertyValue -Path $RegConfig -name $Name | Write-Output } catch {}
}

function Set-AppSettings {
    [cmdletbinding()]
    param ( [string] $Name, [string] $Value )
    CMTraceLog -Message  "`t`tSettings: [$Name] = [$value]" -Type 1 -LogFile $LogFile
    if ( -not ( test-path $RegConfig ) ) {
        new-item -ItemType Directory -Path $RegConfig -force -ErrorAction SilentlyContinue | Out-Null
    }
    Set-ItemProperty -path $RegConfig -name $Name -Value $Value | Out-Null
}


function Get-CCMCacheSettings {
    [cmdletbinding()]
    param ( [string] $Name )

    $global:CCM.GetCacheInfo().$Name | Write-Output
}

function Set-CCMCacheSettings {
    [cmdletbinding()]
    param ( [string] $Name, [string] $Value )
    CMTraceLog -Message  "`t`tSettings: [$Name] = [$value]" -Type 1 -LogFile $LogFile
    $global:CCM.GetCacheInfo().$Name = $Value
}

function Test-ForCCM {
    try {
        $global:CCM = new-object -ComObject UIResource.UIResourceMgr -ErrorAction SilentlyContinue
    } catch {}

    if ( -not $global:CCM ) { Exit-WithError 101 'Missing CCM Installation - Service' }
}


#endregion


#region Main()
#############################################################

$Result = 'Success'

if ( -not $testingMode ) {

    Test-ForCCM

    $DiskSize = Get-Volume c | % Size
    $CCMTotalSize = Get-CCMCacheSettings TotalSize

    CMTraceLog -Message  "`t`tSettings: [$Name] = [$value]" -Type 1 -LogFile $LogFile


    #######################################

    if ( -not ( Get-AppSettings -Name 'Exempt' | Where-Object { $_ -eq 'True' } ) ) {
        
        if ( $DetectionMode ) {
    
            CMTraceLog -Message  "`t`tChange Settings for: $DiskSize" -Type 1 -LogFile $LogFile
        
            if ( $DiskSize -lt 250GB ) {            
                if ( $CCMTotalSize -ne $CacheMinSize  ) {
                    $Result = "CCM Value not set, change from [$($CCMTotalSize)] to [$($CacheMinSize)]."
                }
            }
            elseif ( $DiskSIze -gt 500GB ) { 
                if ( $CCMTotalSize -ne $CacheMaxSize ) {
                    $Result = "CCM Value not set, change from [$($CCMTotalSize)] to [$($CacheMaxSize)]."
                }
            }
            else {
                if ( $CCMTotalSize -ne ($DiskSize / 10MB ) ) {
                    $Result = "CCM Value not set, change from [$($CCMTotalSize)] to [$(($DiskSize / 10MB ))]."
                }
            }


        }
        else {

            CMTraceLog -Message  "`t`tCHange Settings for: $DiskSize" -Type 1 -LogFile $LogFile
            if ( $DiskSize -lt 250GB ) {            
                Set-CCMCacheSettings TotalSize $CacheMinSize 
            }
            elseif ( $DiskSIze -gt 500GB ) { 
                Set-CCMCacheSettings TotalSize $CacheMaxSize
            }
            else {
                Set-CCMCacheSettings TotalSize ($DiskSize / 10MB )
            }
        }
    }

    #######################################

    write-verbose "Write Summary to Registry"

    Set-AppSettings -Name 'DiskSize' -Value $DiskSize
    Set-AppSettings -Name 'CCMTotalSize' -Value $CCMTotalSize
    Set-AppSettings -Name 'LastStatusInt' -Value 0
    Set-AppSettings -Name 'LastStatusMsg' -Value 'Success'
    Set-AppSettings -Name 'Version' -value $Version.ToString()

    #######################################
    Write-Verbose 'Done'

    Write-host $Result

}

#endregion
