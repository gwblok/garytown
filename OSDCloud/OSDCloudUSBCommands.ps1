function Create-OSCatalogs {

#Get ESD files from the Microsoft Creation Tool's list
#This file needs to be updated for each release of Windows
#This will create a table of all of the ESD files from MS, then create a "database" for OSDCloud
#Gary Blok's attempt to help David

param (
 $OSDCloudWorkspace

)

$StagingFolder = "$env:TEMP\OSDStaging"
$OSDCloudWorkspace
if (!(Test-Path -Path $StagingFolder)){
    new-item -Path $StagingFolder -ItemType Directory | Out-Null
}

$WindowsTable = @(
@{ Version = 'Win1022H2';LocalCab = "Win1022H2.Cab"; URL = "https://download.microsoft.com/download/3/c/9/3c959fca-d288-46aa-b578-2a6c6c33137a/products_win10_20230510.cab.cab"}
@{ Version = 'Win1121H2';LocalCab = "Win1121H2.Cab"; URL = "https://download.microsoft.com/download/1/b/4/1b4e06e2-767a-4c9a-9899-230fe94ba530/products_Win11_20211115.cab"}
@{ Version = 'Win1122H2';LocalCab = "Win1122H2.Cab"; URL = "https://download.microsoft.com/download/b/1/9/b19bd7fd-78c4-4f88-8c40-3e52aee143c2/products_win11_20230510.cab.cab"}
@{ Version = 'Win1123H2';LocalCab = "Win1123H2.Cab"; URL = "https://download.microsoft.com/download/e/8/6/e86b4c6f-4ae8-40df-b983-3de63ea9502d/products_win11_202311109.cab"}
)


#region functions borrowed from HPCMSL
function Invoke-HPPrivateExpandCAB {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)] $cab,
    [Parameter(Mandatory = $true)] $expectedFile
  )
  Write-Verbose "Expanding CAB $cab to $cab.dir"

  $target = "$cab.dir"
  Invoke-HPPrivateSafeRemove -Path $target -Recurse
  Write-Verbose "Expanding $cab to $target"
  $result = New-Item -Force $target -ItemType Directory
  Write-Verbose "Created folder $result"

  $shell = New-Object -ComObject "Shell.Application"
  $exception = $null
  try {
    if (!$?) { $(throw "unable to create $comObject object") }
    $sourceCab = $shell.Namespace($cab).items()
    $DestinationFolder = $shell.Namespace($target)
    $DestinationFolder.CopyHere($sourceCab)
  }
  catch {
    $exception = $_.Exception
  }
  finally {
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject([System.__ComObject]$shell) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
  }

  if ($exception) {
    throw "Failed to decompress $cab. $($exception.Message)."
  }

  $downloadedOk = Test-Path $expectedFile
  if ($downloadedOk -eq $false) {
    throw "Invalid cab file, did not find $expectedFile in contents"
  }
  return $expectedFile
}

function Invoke-HPPrivateSafeRemove {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)] [string[]]$path,
    [Parameter(Mandatory = $false)] [switch]$recurse
  )
  foreach ($p in $path) {
    if (Test-Path $p) {
      Write-Verbose "Removing $p"
      Remove-Item $p -Recurse:$recurse
    }
  }
}
#endregion

#region functions
function Test-WebConnection{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline)]
        # Uri to test
        [System.Uri]
        $Uri = 'google.com'
    )
    $Params = @{
        Method = 'Head'
        Uri = $Uri
        UseBasicParsing = $true
        Headers = @{'Cache-Control'='no-cache'}
    }

    try {
        Write-Verbose "Test-WebConnection OK: $Uri"
        Invoke-WebRequest @Params | Out-Null
        $true
    }
    catch {
        Write-Verbose "Test-WebConnection FAIL: $Uri"
        $false
    }
    finally {
        $Error.Clear()
    }
}

#endregion

$ESDInfo  = @()
ForEach ($Option in $WindowsTable){
    Invoke-WebRequest -Uri $Option.URL -UseBasicParsing -OutFile "$StagingFolder\$($Option.LocalCab)" -ErrorAction SilentlyContinue -Verbose
    $file = Invoke-HPPrivateExpandCAB -cab "$StagingFolder\$($Option.LocalCab)" -expectedFile "$StagingFolder\$($Option.LocalCab).dir\products.xml" -Verbose
    [XML]$XML = Get-Content -Raw -Path "$StagingFolder\$($Option.LocalCab).dir\products.xml"
    $ESDInfo += $XML.MCT.Catalogs.Catalog.PublishedMedia.Files.File
    }

#Remove Dups
$UniqueESDInfo = $ESDInfo | Group-Object -Property FileName | %{$_.Group[0]}
#Clean Up Results
$x64ESDInfo = $UniqueESDInfo | Where-Object {$_.Architecture -eq "x64"}
$x64ESDInfo = $x64ESDInfo | Where-Object {$_.Edition -eq "Professional" -or $_.Edition -eq "Education" -or $_.Edition -eq "Enterprise" -or $_.Edition -eq "Professional" -or $_.Edition -eq "HomePremium"}


Import-Module -Name OSD -Force
#=================================================
#   FeatureUpdates
#=================================================

$Results = $x64ESDInfo
$Results = $Results | Select-Object `
@{Name='Status';Expression={($null)}}, `
@{Name='ReleaseDate';Expression={($null)}}, `
@{Name='Name';Expression={($_.Title)}}, `
@{Name='Version';Expression={($null)}}, `
@{Name='ReleaseID';Expression={($_.null)}}, `
@{Name='Architecture';Expression={($_.Architecture)}}, `
@{Name='Language';Expression={($_.LanguageCode)}}, `
@{Name='Activation';Expression={($null)}}, `
@{Name='Build';Expression={($null)}}, `
@{Name='FileName';Expression={($_.FileName)}}, `
@{Name='ImageIndex';Expression={($null)}}, `
@{Name='ImageName';Expression={($null)}}, `
@{Name='Url';Expression={($_.FilePath)}}, `
@{Name='SHA1';Expression={($_.Sha1)}}, `
@{Name='UpdateID';Expression={($_.UpdateID)}}

foreach ($Result in $Results) {
    #=================================================
    #   
    #=================================================
    if ($Result.FileName -match 'Windows 10') {
        $Result.Version = 'Windows 10'
    }
    if ($Result.Name -match 'Windows 11') {
        $Result.Version = 'Windows 11'
    }
    #=================================================
    #   Language
    #=================================================
    #if ($Result.FileName -match 'sr-latn-rs') {
    #    $Result.Language = 'sr-latn-rs'
    #}
    #else {
    #    $Regex = "[a-zA-Z]+-[a-zA-Z]+"
    #    $Result.Language = ($Result.FileName | Select-String -AllMatches -Pattern $Regex).Matches[0].Value
    #}
    #=================================================
    #   Activation
    #=================================================
    if ($Result.Url -match 'business') {
        $Result.Activation = 'Volume'
    }
    else {
        $Result.Activation = 'Retail'
    }
    #=================================================
    #   Build
    #=================================================
    $Regex = "[0-9]*\.[0-9]+"
    $Result.Build = ($Result.FileName | Select-String -AllMatches -Pattern $Regex).Matches[0].Value

    #=================================================
    #   OS Version
    #=================================================
    if ($Result.Build -lt 22000) {
      $Result.Version = 'Windows 10'
    }
    if ($Result.Build -ge 22000) {
        $Result.Version = 'Windows 11'
    }
    #=================================================
    #   ReleaseID
    #=================================================
    if ($Result.Build -match "19045"){$Result.ReleaseID = "22H2"}
    if ($Result.Build -match "22000"){$Result.ReleaseID = "21H2"}
    if ($Result.Build -match "22621"){$Result.ReleaseID = "22H2"}
    if ($Result.Build -match "22631"){$Result.ReleaseID = "23H2"}
    
    #$Result.ReleaseID = (($Result.FileName).Split(".")[3]).Split("_")[0] #worked on some, not others

    #=================================================
    #   Date
    #=================================================
    $DateString = (($Result.FileName).Split(".")[2]).Split("-")[0]
    $Date = [datetime]::parseexact($DateString, 'yyMMdd', $null)
    $Result.ReleaseDate = (Get-Date $Date -Format "yyyy-MM-dd")
    #=================================================
    #   SHA1
    #=================================================
    #$Regex = "[0-9a-f]{40}"
    #$Result.SHA1 = ($Result.FileName | Select-String -AllMatches -Pattern $Regex).Matches[0].Value
    #$Result.SHA1 = ((Split-Path -Leaf $Result.Url) | Select-String -AllMatches -Pattern $Regex).Matches[0].Value
    #=================================================
    #   Name
    #=================================================
    if ($Result.Activation -eq 'Volume') {
        $Result.Name = $Result.Version + ' ' + $Result.ReleaseID + ' x64 ' + $Result.Language + ' Volume ' + $Result.Build
    }
    else {
        $Result.Name = $Result.Version + ' ' + $Result.ReleaseID + ' x64 ' + $Result.Language + ' Retail ' + $Result.Build
    }
    #=================================================
}
$Results = $Results | Sort-Object -Property Name
$Results | Export-Clixml -Path "$OSDCloudWorkspace\Config\Catalogs\CloudOperatingSystems.xml" -Force
Import-Clixml -Path "$OSDCloudWorkspace\Config\Catalogs\CloudOperatingSystems.xml" | ConvertTo-Json | Out-File "$OSDCloudWorkspace\Config\Catalogs\CloudOperatingSystems.json" -Encoding ascii -Width 2000 -Force

#================================================


}

$OSDCloudWorkspace = "C:\OSDCloudWinPE"
$OSDCloudSureRecoverAgent = "$OSDCloudWorkspace\SureRecoverAgent"

try {
    [void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspace)
    [void][System.IO.Directory]::CreateDirectory($OSDCloudSureRecoverAgent)
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\boot")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\efi")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\efi\boot")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\efi\microsoft\boot")
    [void][System.IO.Directory]::CreateDirectory("$OSDCloudSureRecoverAgent\sources")
}
catch {throw}

Install-Module -Name OSD -Scope AllUsers
Update-Module -name OSD -Force
import-module -name OSD -Force


#Run Once
New-OSDCloudTemplate -Name "OSDCloudWinRE" -WinRE
New-OSDCloudWorkspace -WorkspacePath $OSDCloudWorkspace

New-OSDCloudTemplate -Name "OSDCloudWinPE"

#Run Once - Add Custom Wallpaper
Edit-OSDCloudWinPE -Wallpaper "$OSDCloudWorkspace\WinRE.jpg"

#Run Once - Add WinPE Drivers & Install HPCMSL
Edit-OSDCloudWinPE -CloudDriver HP,USB -PSModuleInstall HPCMSL
Edit-OSDCloudWinPE -PSModuleInstall HPCMSL


Edit-OSDCloudWinPE -WirelessConnect -StartURL 'https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/OSDCloudStartNet.ps1'

#Run when updates are made to PS Modules OSD or HPCMSL
Edit-OSDCloudWinPE -PSModuleInstall HPCMSL, AzureAD, Az.Accounts, Az.KeyVault, Az.Resources, Az.Storage, Microsoft.Graph.DeviceManagement, Microsoft.Graph.Intune, UEFIv2 -WirelessConnect -StartURL 'https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/OSDCloudStartNet.ps1'

#Custom Files
Mount-WindowsImage -Path C:\mount -ImagePath "$OSDCloudWorkspace\Media\sources\boot.wim" -Index 1

#Clear out Extra OSD modules
$Folder = Get-ChildItem 'C:\mount\Program Files\WindowsPowerShell\Modules\OSD'
if ($Folder.Count -gt 1){
    $LatestFolder = $Folder | Sort-Object -Property Name | Select-Object -Last 1
    write-host "Latest Module: $($LatestFolder.Name)" -ForegroundColor Green
    Foreach ($Item in $Folder){
     if ( $Item.Name -ne $LatestFolder.Name){
        write-host "Removing $($Item.FullName)" -ForegroundColor Yellow
        Remove-item -Path $Item.FullName -Force -Recurse
        }        
    }
}
else {
    write-host "Latest Module: $($Folder.Name)" -ForegroundColor Green
}

#Find OSD Module
$Folder = Get-ChildItem 'C:\mount\Program Files\WindowsPowerShell\Modules\OSD'
$OSDModule = "$($Folder.FullName)"

#Update ESD file OS Catalog
Create-OSCatalogs -OSDCloudWorkspace $OSDCloudWorkspace 
Copy-Item "$OSDModule\Catalogs\CloudOperatingSystems.json" "$OSDModule\Catalogs\CloudOperatingSystems.json.bak"
Copy-Item "$OSDModule\Catalogs\CloudOperatingSystems.xml" "$OSDModule\Catalogs\CloudOperatingSystems.xml.bak"
Copy-Item -Path C:\OSDCloudWinPE\Config\Catalogs\* $OSDModule\Catalogs -Force -Verbose
Copy-Item -Path C:\OSDCloudWinPE\CustomModuleFiles\OSD.json $OSDModule -Verbose


#Update OSD Module from My Current Code
$Folder = Get-ChildItem 'C:\mount\Program Files\WindowsPowerShell\Modules\OSD'
$OSDModule = "$($Folder.FullName)"
$GitHubFolder = "C:\Users\GaryBlok\OneDrive - garytown\Documents\GitHub"

copy-item "$GitHubFolder\OSD\*"                                                         "$OSDModule" -Force -Verbose -Recurse
#copy-item "$GitHubFolder\OSD\Public\Functions\OSDCloud\Get-WiFiActiveProfileSSID.ps1"   "$OSDModule\public\functions\OSDCloud\Get-WiFiActiveProfileSSID.ps1" -Force -Verbose
#copy-item "$GitHubFolder\OSD\Public\Functions\OSDCloud\Get-WiFiProfileKey.ps1"          "$OSDModule\public\functions\OSDCloud\Get-WiFiProfileKey.ps1" -Force -Verbose
#copy-item "$GitHubFolder\OSD\Public\Functions\OSDCloud\Initialize-OSDCloudStartnet.ps1" "$OSDModule\public\functions\OSDCloud\Initialize-OSDCloudStartnet.ps1" -Force -Verbose
#copy-item "$GitHubFolder\OSD\Public\Functions\OSDCloud\Test-DCUSupport.ps1"             "$OSDModule\public\functions\OSDCloud\Test-DCUSupport.ps1" -Force -Verbose
#copy-item "$GitHubFolder\OSD\Public\Functions\OSDCloud\Test-HPIASupport.ps1"            "$OSDModule\public\functions\OSDCloud\Test-HPIASupport.ps1" -Force -Verbose
#copy-item "$GitHubFolder\OSD\Public\OSDCloud.Setup.ps1"                                 "$OSDModule\public\OSDCloud.Setup.ps1" -Force -Verbose
#copy-item "$GitHubFolder\OSD\Public\OSDCloud.ps1"                                       "$OSDModule\public\OSDCloud.ps1" -Force -Verbose
#copy-item "$GitHubFolder\OSD\Public\OSD.WinRE.WiFi.ps1"                                 "$OSDModule\public\OSD.WinRE.WiFi.ps1" -Force -Verbose
#copy-item "$GitHubFolder\OSD\OSD.psd1"                                                  "$OSDModule\OSD.psd1" -Force -Verbose
Copy-Item "C:\OSDCloudWinPE\Config\cmtrace.exe" "C:\Mount\Windows\System32\cmtrace.exe" -Force -Verbose
#Copy-Item "\\nas\OpenShare\SplashScreen\SPLASH.JSON" "D:\Mount\OSDCloud\Config\SPLASH.JSON" -force -Verbose

#Copy-Item "\\nas\OpenShare\WinRE\*" "D:\Mount\OSDCloud\Extras\" -force -Verbose -Recurse
#Copy-Item "\\nas\OpenShare\SplashScreen" "D:\Mount\OSDCloud\Config\Scripts" -Recurse -force -Verbose
#Copy-Item "\\nas\OpenShare\SplashScreen\Start-Splash.ps1" "D:\Mount\OSDCloud\Config\Scripts\StartNet" -Force -Verbose

Dismount-WindowsImage -Path c:\mount -Save
Update-OSDCloudUSB

New-OSDCloudISO
#Copy-Item "$OSDCloudWorkspace\Media\sources\boot.wim" -Destination "\\nas\8TB\TEMP" -Force -Verbose
Copy-Item "$OSDCloudWorkspace\Media\sources\boot.wim" -Destination "\\cm.lab.garytown.com\c$\HP\SureRecover\HPSRStaging\CustomAgent\sources"


#Grab Required Files for Sure Recover (Just the 4 files for what we're doing)
Copy-Item "$OSDCloudWorkspace\Media\Boot\boot.sdi" -Destination "$OSDCloudSureRecoverAgent\boot" -Force -Verbose
Copy-Item "$OSDCloudWorkspace\Media\Efi\Boot\bootx64.efi" -Destination "$OSDCloudSureRecoverAgent\Efi\Boot" -Force -Verbose
Copy-Item "$OSDCloudWorkspace\Media\Efi\Microsoft\Boot\BCD" -Destination "$OSDCloudSureRecoverAgent\Efi\Microsoft\Boot\" -Force -Verbose
Copy-Item "$OSDCloudWorkspace\Media\sources\boot.wim" -Destination "$OSDCloudSureRecoverAgent\sources" -Force -Verbose


$Cabs = Get-ChildItem -Path "D:\OSDCloudWinRE\FoDs" -File -Recurse -Filter *.cab
foreach ($Cab in $Cabs){
    Write-Host "$($Cab.Fullname)"
    Dism /Image:"D:\mount\" /Add-Package /PackagePath="$($Cab.Fullname)"
}

Dism /Image:"D:\mount\" /Add-Package /PackagePath="D:\OSDCloudWinRE\edge.cab"
Add-WindowsPackage  -WindowsDirectory D:\Mount\ -PackagePath D:\OSDCloudWinRE\edge.cab
