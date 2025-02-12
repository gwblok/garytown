<#
Get ESD files from the Microsoft Creation Tool's list
This file needs to be updated for each release of Windows
This will create a table of all of the ESD files from MS, then create a "database" for OSDCloud
Gary Blok's attempt to help David

Changes
23.12.23 - Several Updates
 - Updated Win10 22H2 CAB URL for newer ESD files
 - Updated Win11 23H2 CAB URL for newer ESD files
 - Started making modifications to support Win 11 22H2 GA ESD Files (22621.382)
24.10.1
 - Updated Win11 24H2 CAB URL for newer ESD files

#>

# Import OSD Module
Import-Module OSD -Force -ErrorAction Stop

$CatalogFolder = "D:\OSDCloudBuild-Catalogs"
if (!(Test-Path -Path $CatalogFolder)){
    new-item -Path $CatalogFolder -ItemType Directory | Out-Null
}
$StagingFolder = "D:\OSDCloudBuild-Catalogs\Staging"
if (!(Test-Path -Path $StagingFolder)){
    new-item -Path $StagingFolder -ItemType Directory | Out-Null
}


$WindowsTable = @(
@{ Version = 'Win1022H2';LocalCab = "Win1022H2.Cab"; URL = "https://download.microsoft.com/download/7/9/c/79cbc22a-0eea-4a0d-89c0-054a1b3aa8e0/products.cab"}
@{ Version = 'Win1121H2';LocalCab = "Win1121H2.Cab"; URL = "https://download.microsoft.com/download/1/b/4/1b4e06e2-767a-4c9a-9899-230fe94ba530/products_Win11_20211115.cab"}
@{ Version = 'Win1122H2';LocalCab = "Win1122H2.Cab"; URL = "https://download.microsoft.com/download/b/1/9/b19bd7fd-78c4-4f88-8c40-3e52aee143c2/products_win11_20230510.cab.cab"}
@{ Version = 'Win1123H2';LocalCab = "Win1123H2.Cab"; URL = "https://download.microsoft.com/download/6/2/b/62b47bc5-1b28-4bfa-9422-e7a098d326d4/products_win11_20231208.cab"}
@{ Version = 'Win1124H2';LocalCab = "Win1124H2.Cab"; URL = "https://download.microsoft.com/download/6/2/b/62b47bc5-1b28-4bfa-9422-e7a098d326d4/products-Win11-20241004.cab"}
)

#Previous: 
<#
@{ Version = 'Win1124H2';LocalCab = "Win1124H2.Cab"; URL = "https://download.microsoft.com/download/6/2/b/62b47bc5-1b28-4bfa-9422-e7a098d326d4/products_Win11_20240916.cab"}

#>


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

$ARM64ESDInfo = $UniqueESDInfo | Where-Object {$_.Architecture -eq "ARM64"}
$ARM64ESDInfo = $ARM64ESDInfo | Where-Object {$_.Edition -eq "Professional" -or $_.Edition -eq "Education" -or $_.Edition -eq "Enterprise" -or $_.Edition -eq "Professional" -or $_.Edition -eq "HomePremium"}
#$ARM64ESDInfo = $ARM64ESDInfo | Where-Object {$_.FileName -match '19045' -or $_.FileName -match '22631'}

$ComboESDInfo = $UniqueESDInfo | Where-Object {$_.Architecture -eq "x64" -or $_.Architecture -eq "ARM64"}
$ComboESDInfo = $ComboESDInfo | Where-Object {$_.Edition -eq "Professional" -or $_.Edition -eq "Education" -or $_.Edition -eq "Enterprise" -or $_.Edition -eq "Professional" -or $_.Edition -eq "HomePremium"}

Import-Module -Name OSD -Force

#region x64
#=================================================
#   FeatureUpdates x64
#=================================================

$X64Results = $x64ESDInfo
$X64Results = $X64Results | Select-Object `
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
@{Name='UpdateID';Expression={($_.UpdateID)}}, `
@{Name='Win10';Expression={($null)}}, `
@{Name='Win11';Expression={($null)}}

foreach ($Result in $X64Results) {

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
      $Result.Win10 = $true
      $Result.Win11 = $false
    }
    if ($Result.Build -ge 22000) {
        $Result.Version = 'Windows 11'
        $Result.Win10 = $false
        $Result.Win11 = $true
    }
    #=================================================
    #   ReleaseID
    #=================================================
    if ($Result.Build -match "19045"){$Result.ReleaseID = "22H2"}
    if ($Result.Build -match "22000"){$Result.ReleaseID = "21H2"}
    if ($Result.Build -match "22621"){$Result.ReleaseID = "22H2"}
    if ($Result.Build -match "22631"){$Result.ReleaseID = "23H2"}
    if ($Result.Build -match "26100"){$Result.ReleaseID = "24H2"}
    
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

$X64ResultsMCT = $X64Results | Sort-Object -Property Name
#endregion x64


#region ARM64
#=================================================
#   FeatureUpdates ARM64
#=================================================

$ARMResults = $ARM64ESDInfo
$ARMResults = $ARMResults | Select-Object `
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
@{Name='UpdateID';Expression={($_.UpdateID)}}, `
@{Name='Win10';Expression={($null)}}, `
@{Name='Win11';Expression={($null)}}

foreach ($Result in $ARMResults) {

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
      $Result.Win10 = $true
      $Result.Win11 = $false
    }
    if ($Result.Build -ge 22000) {
        $Result.Version = 'Windows 11'
        $Result.Win10 = $false
        $Result.Win11 = $true
    }
    #=================================================
    #   ReleaseID
    #=================================================
    if ($Result.Build -match "19045"){$Result.ReleaseID = "22H2"}
    if ($Result.Build -match "22000"){$Result.ReleaseID = "21H2"}
    if ($Result.Build -match "22621"){$Result.ReleaseID = "22H2"}
    if ($Result.Build -match "22631"){$Result.ReleaseID = "23H2"}
    if ($Result.Build -match "26100"){$Result.ReleaseID = "24H2"}

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
        $Result.Name = $Result.Version + ' ' + $Result.ReleaseID + ' ARM64 ' + $Result.Language + ' Volume ' + $Result.Build
    }
    else {
        $Result.Name = $Result.Version + ' ' + $Result.ReleaseID + ' ARM64 ' + $Result.Language + ' Retail ' + $Result.Build
    }
    #=================================================
}
$ARMResultsMCT = $ARMResults | Sort-Object -Property Name

#endregion ARM64

#region ARM64 & x64
#=================================================
#   FeatureUpdates ARM64 & x64 (Combo)
#=================================================

$ComboResults = $ComboESDInfo
$ComboResults = $ComboResults | Select-Object `
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
@{Name='UpdateID';Expression={($_.UpdateID)}}, `
@{Name='Win10';Expression={($null)}}, `
@{Name='Win11';Expression={($null)}}

foreach ($Result in $ComboResults) {

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
      $Result.Win10 = $true
      $Result.Win11 = $false
    }
    if ($Result.Build -ge 22000) {
        $Result.Version = 'Windows 11'
        $Result.Win10 = $false
        $Result.Win11 = $true
    }
    #=================================================
    #   ReleaseID
    #=================================================
    if ($Result.Build -match "19045"){$Result.ReleaseID = "22H2"}
    if ($Result.Build -match "22000"){$Result.ReleaseID = "21H2"}
    if ($Result.Build -match "22621"){$Result.ReleaseID = "22H2"}
    if ($Result.Build -match "22631"){$Result.ReleaseID = "23H2"}
    if ($Result.Build -match "26100"){$Result.ReleaseID = "24H2"}
    
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

$ComboResultsMCT = $ComboResults | Sort-Object -Property Name
#endregion ARM64 & x64



#===================================================================
#Build Catalog Files
#===================================================================

# x64 Catalog File

#$ResultsTotal += $ResultsWSUS
#$ResultsTotal | Export-Clixml -Path (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "Catalogs\CloudOperatingSystems.xml") -Force
#Import-Clixml -Path (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "Catalogs\CloudOperatingSystems.xml") | ConvertTo-Json | Out-File (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "Catalogs\CloudOperatingSystems.json") -Encoding ascii -Width 2000 -Force
$X64ResultsMCT | Export-Clixml -Path "$CatalogFolder\CloudOperatingSystemsX64.xml" -Force
Import-Clixml -Path "$CatalogFolder\CloudOperatingSystemsX64.xml" | ConvertTo-Json | Out-File "$CatalogFolder\CloudOperatingSystemsX64.json" -Encoding ascii -Width 2000 -Force

# ARM64 Catalog File

#$ARMResultsMCT | Export-Clixml -Path (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "Catalogs\CloudOperatingSystemsARM64.xml") -Force
#Import-Clixml -Path (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "Catalogs\CloudOperatingSystemsARM64.xml") | ConvertTo-Json | Out-File (Join-Path (Get-Module -Name OSD -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).ModuleBase "Catalogs\CloudOperatingSystemsARM64.json") -Encoding ascii -Width 2000 -Force
$ARMResultsMCT | Export-Clixml -Path "$CatalogFolder\CloudOperatingSystemsARM64.xml" -Force
Import-Clixml -Path "$CatalogFolder\CloudOperatingSystemsARM64.xml" | ConvertTo-Json | Out-File "$CatalogFolder\CloudOperatingSystemsARM64.json" -Encoding ascii -Width 2000 -Force

# ARM64 & x64 (Combo) Catalog File

$ComboResultsMCT | Export-Clixml -Path "$CatalogFolder\CloudOperatingSystems.xml" -Force
Import-Clixml -Path "$CatalogFolder\CloudOperatingSystems.xml" | ConvertTo-Json | Out-File "$CatalogFolder\CloudOperatingSystems.json" -Encoding ascii -Width 2000 -Force

#================================================
