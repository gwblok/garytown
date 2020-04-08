<#  Version 2020.04.08 - Creator @gwblok - GARYTOWN.COM
    Used to download BIOS Updates from HP
    This Script was created to build a BIOS Update Package. 
    Future Scripts based on this will be one that gets the Model / Product info from the machine it's running on and pull down the correct BIOS and run the Updater

    REQUIREMENTS:  HP Client Management Script Library
    Download / Installer: https://ftp.hp.com/pub/caps-softpaq/cmit/hp-cmsl.html  
    Docs: https://developers.hp.com/hp-client-management/doc/client-management-script-library-0
    

    Typically I run in "Download" mode.  I wrote parts of this a long time ago, and will probably come back and remove some of that junk, just make it more simple.
    Usage... Stage Prod or Pre-Prod.
    If you don't do Pre-Prod... just delete that Param section out and set $Stage = Prod or remove all Stage references complete, do whatever you want I guess.

    PROXY... either update or delete the proxy stuff
#>
[CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$true,Position=1,HelpMessage="Method")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Report", "Download", "Force")]
		    $RunMethod = "Report",
		    [Parameter(Mandatory=$true,Position=1,HelpMessage="Stage")]
            [ValidateNotNullOrEmpty()]
            [ValidateSet("Pre-Prod", "Prod")]
		    $Stage = "Pre-Prod"

 	    )


#Script Vars
$scriptName = $MyInvocation.MyCommand.Name
$OS = "Win10"
$Category = "bios"
$LogFile = "$PSScriptRoot\HPBIOSDownload.log"
$SiteCode = "PS2"

#Reset Vars
$BIOS = ""
$Model = ""



 

#region: CMTraceLog Function formats logging in CMTrace style
        function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "HP BIOS Downloader",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile
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

function Get-FolderSize {
[CmdletBinding()]
Param (
[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
$Path,
[ValidateSet("KB","MB","GB")]
$Units = "MB"
)
  if ( (Test-Path $Path) -and (Get-Item $Path).PSIsContainer ) {
    $Measure = Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    $Sum = $Measure.Sum / "1$Units"
    [PSCustomObject]@{
      "Path" = $Path
      "Size($Units)" = $Sum
    }
  }
}



if ((Test-NetConnection proxy-garytown.com -Port 8080).PingSucceeded -eq $True)
    {
    $UseProxy = $true
    CMTraceLog -Message "Found Proxy Server, using for Downloads" -Type 1 -LogFile $LogFile
    Write-Output "Found Proxy Server, using for Downloads"
    $ProxyServer = "http://proxy-garytown.com:8080"
    $BitsProxyList = @("192.168.1.176:8080, 168.33.22.169:8080, 111.222.214.218.21:8080")
    }
Else 
    {
    CMTraceLog -Message "No Proxy Server Found, continuing without" -Type 1 -LogFile $LogFile
    Write-Output "No Proxy Server Found, continuing without"
    }

#Load CM PowerShell
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"
$HPModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.Mifname -eq $Stage}

#$HPModelsTable = Get-CMPackage -Fast -Id "PS200433"

Set-Location -Path "C:"
CMTraceLog -Message "Starting Script: $scriptName" -Type 1 -LogFile $LogFile
Write-Output "Starting Script: $scriptName"




foreach ($HPModel in $HPModelsTable) #{Write-Host "$($HPModel.Name)"}
    {
    Write-Host "Starting Process for $($HPModel.MIFFilename)" -ForegroundColor Green
    $BIOSInfo = $null
    $Prodcode = $HPModel.Language
    $Name = $HPModel.MIFFilename
    $MaxBuild = ((Get-HPDeviceDetails -platform $Prodcode -oslist | Where-Object {$_.OperatingSystem -eq "Microsoft Windows 10"}).OperatingSystemRelease | measure -Maximum).Maximum
    $BIOS = Get-HPBiosUpdates -platform $Prodcode -latest
    $BIOSInfo = Get-SoftpaqList -Platform $Prodcode -Category BIOS -OsVer $MaxBuild 
    $BIOSInfo = $BIOSInfo | Where-Object {$_.Version -match $BIOS.Ver}
    if (!($BIOSInfo)){$Description = "SOFTPAQ DATA irregularity, Try to Rerun" }
    else{$Description = $BIOSInfo.ReleaseNotes}
     
       #Get Current Driver CMPackage Version from CM

        Set-Location -Path "$($SiteCode):"
        $PackageInfo = $HPModel
        $PackageInfoVersion = $null
        $PackageInfoVersion = $PackageInfo.Version
        $DownloadLocation = $PackageInfo.PkgSourcePath
        Set-Location -Path "C:"

    if ($PackageInfoVersion -eq $Bios.ver -and $RunMethod -ne "Force")
        {Write-host "  $Name already current with version $($PackageInfoVersion)" -ForegroundColor Green
        CMTraceLog -Message "CM Package $($PackageInfo.Name) already Current: $PackageInfoVersion HP: $($Bios.Ver)" -Type 1 -LogFile $LogFile
        $AlreadyCurrent = $true
        }
    else
        {
        if (!($PackageInfoVersion)){write-host "  $Name package has no previous downloads, downloading: $($BIOS.ver)" -ForegroundColor Yellow}
        else{Write-Host "  $Name package is version $($PackageInfoVersion), new version available $($BIOS.ver)" -ForegroundColor Yellow}
        $SaveAs = "$($DownloadLocation)\$($Bios.Bin)"
        Get-HPBiosUpdates -platform $ProdCode -download -saveAs $SaveAs -overwrite
        $AlreadyCurrent = $false
        }
   
    Write-Host "  Confirming Package Info in ConfigMgr $($PackageInfo.Name) ID: $($HPModel.PackageID)" -ForegroundColor yellow
    Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
    Set-Location -Path "$($SiteCode):"         
    Set-CMPackage -Id $HPModel.PackageID -Version "$($BIOS.Ver)"
    Set-CMPackage -Id $HPModel.PackageID -MIFVersion $BIOS.Date
    Set-CMPackage -Id $HPModel.PackageID -MIFPublisher $BIOSInfo.ReleaseDate
    Set-CMPackage -Id $HPModel.PackageID -Description $Description
    $PackageInfo = Get-CMPackage -Id $HPModel.PackageID -Fast
    Update-CMDistributionPoint -PackageId $HPModel.PackageID
    Set-Location -Path "C:"
    CMTraceLog -Message "Updated Package $($PackageInfo.Name), ID $($HPModel.PackageID) to $($PackageInfoVersion) which was released $($TargetDate)"  -Type 1 -LogFile $LogFile

     Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    }  



CMTraceLog -Message "Finished Script: $scriptName" -Type 1 -LogFile $LogFile
Write-Output "Finished Script: $scriptName"
