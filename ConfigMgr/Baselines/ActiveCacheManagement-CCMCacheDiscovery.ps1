<#

.SYNOPSIS


.DESCRIPTION
Basic management of local CCM Cache

.NOTES
Gary Blok | @gwblok | RecastSoftware.com

#>

$OrgName = "Recast_IT"
[string]$Version = '2021.04.22'
$RegConfig = "HKLM:\Software\$OrgName\Cache"
$LogName = "CCMCacheChecker.log"
$LogDir = "$env:ProgramData\$OrgName\Logs"
$LogFile = "$LogDir\$LogName"
$ComponentText = "CCMCacheCheck-Discovery"

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
        #Write-ToLog "ERROR: $Msg"
        CMTraceLog -Message  "ERROR: $Msg" -Type 1 -LogFile $LogFile
        New-EventLog -LogName Application -Source 'CacheChecker' -ErrorAction SilentlyContinue
        Write-EventLog -LogName Application -Source 'CacheChecker' -EventId $ExitCode -Message $msg
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

Function Test-ForSoftwareUpdate {
    # Content in a {GUID} folder
    [cmdletbinding()]
    param ( [parameter(Mandatory=$true, ValueFromPipeline=$true)] $InputObject )
    process { $InputObject | where-object { $_.PSChildName | Select-String -Pattern '^[\dA-F]{8}-(?:[\dA-F]{4}-){3}[\dA-F]{12}$' } | write-output }
}

Function Test-ForLegacyContent {
    # Content in a CAS00001 folder
    [cmdletbinding()]
    param ( [parameter(Mandatory=$true, ValueFromPipeline=$true)] $InputObject )
    process { $InputObject | where-object { $_.PSChildName | Select-String -Pattern '^[\dA-Z]{3}[\dA-F]{5}$' } | write-output }
}

Function Test-ForApplicationDeployment {
    # Content in a Content_{GUID} folder
    [cmdletbinding()]
    param ( [parameter(Mandatory=$true, ValueFromPipeline=$true)] $InputObject )
    process { $InputObject | where-object { $_.PSChildName | Select-String -Pattern '^Content_[\dA-F]{8}-(?:[\dA-F]{4}-){3}[\dA-F]{12}$' } | write-output }
}

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

if ( -not $testingMode ) {

    Set-AppSettings -Name 'CCMCacheSize'  -Value (get-childitem $CCMCacheLocation -recurse -exclude skpswi.dat | measure-object -sum length | % Sum)
    Set-AppSettings -Name 'CCMCacheItems' -Value (get-childitem $CCMCacheLocation -directory | measure-object | % Count)
    Set-AppSettings -Name 'LastStatusInt' -Value 0
    Set-AppSettings -Name 'LastStatusMsg' -Value 'Success'
    Set-AppSettings -Name 'Version' -value $Version.ToString()

    #######################################
    Write-Verbose 'Done'
    Write-host '0'

}

#endregion
