###################################################################################################################
##                    PowerShell script to create a Windows Feature Update block 'database'                      ##
##                      using Microsoft's Windows Compatibility Appraiser database files                         ##
###################################################################################################################

# This script is based on the work of Adam Gross and Gary Blok
# It makes use of parallel processing available in PowerShell Core to improve execution speed
# Run on a well-spec'd multi-core machine for best performance
# Requires that sdb2xml.exe exists at $AppraiserWorkingDirectory\sdb2xml.exe (https://github.com/heaths/sdb2xml)
# Requires .Net Framework 3.5 to run the sdb2xml.exe utility
# Expected run time could be around 40-60 minutes

<#  Changes by Gary Blok (Thanks Trevor for this awesome reworking of our original script)
    25.2.9 Modified to not clean out after running, and then checking for previous runs, skipping downloads, and expanding if already present, saving a lot of time.

#>
#Requires -Version 7

#region ----------------------------------------------- Parameters ------------------------------------------------
$ProgressPreference = 'SilentlyContinue'
# The local directory we'll use to download to
$AppraiserWorkingDirectory = "C:\SafeGuard\AppraiserDatabase"
# A thread-safe (ish) object to use across runspaces
$syncHash = [hashtable]::Synchronized(@{
    Semaphore = [System.Threading.SemaphoreSlim]::new(1,1)
    Counter = @(0)
    GatedBlocks = [Collections.Generic.List[PSCustomObject]]::new()
})
# Maximum number of parallel threads. The optimum number depends on available system resources
$ThrottleLimit = 25
# Minimum free space required on the drive where the cab files will be downloaded to in GB
$MinimumDriveSpace = 30
# Clean out the working directory when finished to free up the used space
$PurgeWorkingDirectory = $false
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Prepare ---------------------------------------------------
# Create the working directory if needed
#$AppraiserRoot = "$AppraiserWorkingDirectory\$(Get-Date -format "yyyy-MM-dd HH.mm")"
$AppraiserRoot = "$AppraiserWorkingDirectory\BuildZone"
try {[void][System.IO.Directory]::CreateDirectory($AppraiserRoot)}
catch {throw}

# Check if sdb2xml.exe exists
If ((Test-Path -Path "$AppraiserWorkingDirectory\sdb2xml.exe") -eq $false)
{
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Feature-Updates/SafeGuardHolds/sdb2xml.exe' -OutFile "$AppraiserWorkingDirectory\sdb2xml.exe"
    if ((Test-Path -Path "$AppraiserWorkingDirectory\sdb2xml.exe") -eq $false)
    {
        throw "sdb2xml.exe not found at $AppraiserWorkingDirectory\sdb2xml.exe."
    }
}

# Check if .Net Framework 3.5 is installed
$Net35 = Get-ItemProperty "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.5" -Name Install -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Install
if ($null -eq $Net35 -or $net35 -ne 1)
{
    throw ".Net Framework 3.5 is not installed."
}

# Check that the chosen drive has sufficient free space for the downloads
$Drive = (Get-Item -Path $AppraiserWorkingDirectory).PSDrive.Name
$DriveInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$Drive`:'"
$DriveFreeSpace = [math]::Round($DriveInfo.FreeSpace / 1GB, 2)
if ($DriveFreeSpace -lt $MinimumDriveSpace)
{
    throw "There is not enough free space on the $Drive drive to download the appraiser databases."
}

# Download the appraiser cab URLs from Gary's public list
try 
{
    $SettingsTableRequest = Invoke-WebRequest -URI "https://raw.githubusercontent.com/gwblok/garytown/refs/heads/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldURLS.json" -ErrorAction Stop
    $SettingsTable = $SettingsTableRequest.Content | ConvertFrom-Json -ErrorAction Stop 
}
catch 
{
    throw $_.Exception.Message
}

# Alternate code to read a local json file instead
# $SettingsTable = Get-Content $AppraiserWorkingDirectory\SafeGuardHoldURLs.json -Raw | ConvertFrom-Json

Write-Output "Beginning parallel processing for $($SettingsTable.Count) appraiser databases"

# Start a timer
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Download CABs ---------------------------------------------
write-host -foregroundcolor darkgray "====================================================="
write-host -foregroundcolor magenta "Downloading $($SettingsTable.Count) CAB files"
write-host -foregroundcolor darkgray "====================================================="

$SettingsTable | ForEach-Object -Parallel {
    $Appraiser = $_
    # Increment the counter
    $syncHash = $using:syncHash
    $syncHash['Semaphore'].Wait()
    $syncHash['Counter'][0] ++
    $Count = $syncHash['Counter'][0] 
    $null = $syncHash['Semaphore'].Release()
    [string]$AppraiserVersion = $Appraiser.ALTERNATEDATAVERSION
    [string]$AppraiserURL = $Appraiser.ALTERNATEDATALINK

    # Download the cab file
    try 
    {
        $OutFilePath = "$using:AppraiserRoot\$AppraiserVersion"
        $OutFileName = $AppraiserURL.Split("/")[-1]
        Write-Output "[Thread $Count] Downloading $OutFileName..."
        [void][System.IO.Directory]::CreateDirectory($OutFilePath)   
        if (Test-Path -Path "$OutFilePath\$OutFileName"){Write-host -ForegroundColor Green "File already exists: $OutFileName"}
        else {Invoke-WebRequest -URI $AppraiserURL -OutFile "$OutFilePath\$OutFileName" -ErrorAction Stop}
    }
    catch 
    {
        throw "[Thread $Count] $($_.Exception.Message)"
    }
    [System.gc]::Collect()
} -ThrottleLimit $ThrottleLimit

# Reset the counter
$syncHash['Counter'][0] = 0
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Expand SDBs to XML ----------------------------------------

write-host -foregroundcolor darkgray "====================================================="
write-host -foregroundcolor magenta "  Expand SDBs to XML"
write-host -foregroundcolor darkgray "====================================================="

$CabDirectories = Get-ChildItem -Path $AppraiserRoot -Directory
$CabDirectories | ForEach-Object -Parallel {
    $CabDirectory = $_.Name
    # Increment the counter
    $syncHash = $using:syncHash
    $syncHash['Semaphore'].Wait()
    $syncHash['Counter'][0] ++
    $Count = $syncHash['Counter'][0] 
    $null = $syncHash['Semaphore'].Release()
    # Expand out the cab contents
    try 
    {
        $CabFile = Get-ChildItem -Path "$using:AppraiserRoot\$CabDirectory" -Filter "*.cab" -ErrorAction Stop | Select-Object -First 1
        $OutFilePath = "$using:AppraiserRoot\$CabDirectory"
        $OutFileName = $CabFile.Name
        if (Test-Path -Path "$OutFilePath\Appraiser_Expanded.sdb"){Write-host -ForegroundColor Yellow "File already exists: $($OutFilePath)\Appraiser_Expanded.sdb"}
        else {
            Write-Output "[Thread $Count] Expanding $OutFileName..."
            $null = & expand.exe "$OutFilePath\$OutFileName" -F:* $OutFilePath
            # Decompress the appraiser.sdb
            $appraiserSDB = Get-ChildItem -Path $OutFilePath -Recurse -File -Filter "Appraiser.sdb" -ErrorAction Stop
            $inFileBytes = [System.IO.File]::ReadAllBytes( $(resolve-path $appraiserSDB) )
            $expandedAppraiserSDB = "$OutFilePath\Appraiser_Expanded.sdb"
            $DeflateStreamBlob = $inFileBytes[22..($inFileBytes.Length)]
            $MemoryStream = [System.IO.MemoryStream]::new($DeflateStreamBlob)
            $OutputObj = [System.IO.FileStream]::new($expandedAppraiserSDB, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None))
            $DeflateStream = [System.IO.Compression.DeflateStream]::new($MemoryStream, ([IO.Compression.CompressionMode]::Decompress))
            $buffer = [byte[]]::new(1024)
            while ($true) {
                $read = $DeflateStream.Read($buffer, 0, 1024)
                if ($read -le 0) {
                    break;
                }
                $OutputObj.Write($buffer, 0, $read)
            }
            # Don't forget to dispose!
            $OutputObj.Dispose()
        }
    }
    catch 
    {
        throw "[Thread $Count] $($_.Exception.Message)"
    }
    [System.gc]::Collect()
} -ThrottleLimit $ThrottleLimit

# Reset the count
$syncHash['Counter'][0] = 0
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Convert SDB to XML ----------------------------------------
write-host -foregroundcolor darkgray "====================================================="
write-host -foregroundcolor magenta "  Convert SDB to XML"
write-host -foregroundcolor darkgray "====================================================="
$CabDirectories | ForEach-Object -Parallel {
    $CabDirectory = $_.Name
    # Increment the counter
    $syncHash = $using:syncHash
    $syncHash['Semaphore'].Wait()
    $syncHash['Counter'][0] ++
    $Count = $syncHash['Counter'][0] 
    $null = $syncHash['Semaphore'].Release()
    # Convert the expanded sdb to xml using sdb2xml.exe
    $OutFilePath = "$using:AppraiserRoot\$CabDirectory"
    $expandedAppraiserSDB = "$OutFilePath\Appraiser_Expanded.sdb"
    try 
    {
        Write-Output "[Thread $Count] Converting the SDB file to XML for $CabDirectory..."
        # Copy the sdb2xml utility to the threads' working directory. Each thread needs to create its own process from it.
        [System.IO.File]::Copy("$using:AppraiserWorkingDirectory\sdb2xml.exe", "$OutFilePath\sdb2xml.exe", $true)
        $appraiserXMLFile = "$OutFilePath\appraiser.xml"
        if (Test-Path -Path "$OutFilePath\appraiser.xml"){Write-host -ForegroundColor Yellow "File already exists: $($OutFilePath)\appraiser.xml"}
        else {& $OutFilePath\sdb2xml.exe $expandedAppraiserSDB -out $appraiserXMLFile}
        
    }
    catch 
    {
        throw "[Thread $Count] $($_.Exception.Message)"
    }
    [System.gc]::Collect()
} -ThrottleLimit $ThrottleLimit

# Reset the counter
$syncHash['Counter'][0] = 0
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Parse Appraiser Data --------------------------------------

write-host -foregroundcolor darkgray "====================================================="
write-host -foregroundcolor magenta "  Parse Appraiser Data"
write-host -foregroundcolor darkgray "====================================================="

$CabDirectories | ForEach-Object -Parallel {
    $CabDirectory = $_.Name
    $syncHash = $using:syncHash
    $WorkingDirectory = "$using:AppraiserRoot\$CabDirectory"
    $appraiserXMLFile = "$WorkingDirectory\appraiser.xml"
    $GatedBlocks = [Collections.Generic.List[PSCustomObject]]::new() 
    # Search the Appraiser_Data.ini file and extract the value of 'AppraiserDataVersion'
    $AppraiserIni = Get-ChildItem -Path $WorkingDirectory -Filter "Appraiser_Data.ini" -File -ErrorAction SilentlyContinue
    if ($AppraiserIni)
    {
        $AppraiserVersion = Get-Content -Path $AppraiserIni.FullName -ErrorAction SilentlyContinue | Select-String -Pattern "AppraiserDataVersion" -ErrorAction SilentlyContinue
        if ($AppraiserVersion)
        {
            try 
            {
                $AppraiserVersion = $AppraiserVersion.ToString().Split("=")[-1].Trim()
            }
            catch 
            {
                $AppraiserVersion = "Unknown"
            }
        }
    }
    else 
    {
        $AppraiserVersion = "Unknown"
    }

    # Increment the counter
    $syncHash['Semaphore'].Wait()
    $syncHash['Counter'][0] ++
    $Count = $syncHash['Counter'][0] 
    $null = $syncHash['Semaphore'].Release()
    Write-Output "[Thread $Count] Parsing appraiser data for $CabDirectory..."
    try 
    {
        [xml]$Content = Get-Content -Path $AppraiserXMLFile -Raw -ErrorAction Stop
        $AppraiserDate = $Content.sdb.DATABASE.time.'#text'
        
        # Parse the XML file for 'OS Upgrade' blocks
        $OSUpgradeBlocks = $Content.SelectNodes("//SDB/DATABASE/OS_UPGRADE").Where({$_.DATA.Data_String.'#text' -eq 'GatedBlock'})
        foreach ($OSUpgradeBlock in $OSUpgradeBlocks)
        {
            $GatedBlocks.Add([PSCustomObject]@{
                AppName       = [string]$OSUpgradeBlock.App_Name.'#text'
                BlockType     = [string]$OSUpgradeBlock.Data[0].Data_String.'#text'
                SafeguardId   = [string]$OSUpgradeBlock.Data[1].Data_String.'#text'
                NAME          = [string]$OSUpgradeBlock.NAME.'#text'
                VENDOR        = [string]$OSUpgradeBlock.VENDOR.'#text'
                EXE_ID        = [string]$OSUpgradeBlock.EXE_ID.'#text'
                DEST_OS_GTE   = [string]$OSUpgradeBlock.DEST_OS_GTE.'#text'
                DEST_OS_LT    = [string]$OSUpgradeBlock.DEST_OS_LT.'#text'
                FirstAppraiserDate  = [string]$AppraiserDate
                FirstAppraiserVersions = [string]$AppraiserVersion
                LastAppraiserDate   = [string]"?"
                LastAppraiserVersions = [string]"?"
                INNERXML      = [string]$OSUpgradeBlock.InnerXML
            })
        }

        # Parse the XML file for 'Matching Info' blocks
        $MatchingInfoBlocks = $Content.SelectNodes("//SDB/DATABASE/MATCHING_INFO_BLOCK").Where({$_.DATA.Data_String.'#text' -eq 'GatedBlock'})
        foreach ($MatchingInfoBlock in $MatchingInfoBlocks)
        {
            $GatedBlocks.Add([PSCustomObject]@{
                AppName         = [string]$MatchingInfoBlock.App_Name.'#text'
                BlockType       = [string]$MatchingInfoBlock.Data[0].Data_String.'#text'
                SafeguardId     = [string]$MatchingInfoBlock.Data[1].Data_String.'#text'
                NAME            = [string]$MatchingInfoBlock.NAME.'#text'
                VENDOR          = [string]$MatchingInfoBlock.VENDOR.'#text'
                EXE_ID          = [string]$MatchingInfoBlock.EXE_ID.'#text'
                DEST_OS_GTE     = [string]$MatchingInfoBlock.DEST_OS_GTE.'#text'
                DEST_OS_LT      = [string]$MatchingInfoBlock.DEST_OS_LT.'#text'
                FirstAppraiserDate  = [string]$AppraiserDate
                FirstAppraiserVersions = [string]$AppraiserVersion
                LastAppraiserDate   = [string]"?"
                LastAppraiserVersions = [string]"?"
                INNERXML        = [string]$MatchingInfoBlock.InnerXML
            })
        }

        # Safely update the master collection with the extracted block data
        $syncHash['Semaphore'].Wait()
        $syncHash['GatedBlocks'].AddRange($GatedBlocks)
        $null = $syncHash['Semaphore'].Release()
    }
    catch 
    {
        throw "[Thread $Count] $($_.Exception.Message)"  
    }   
    [System.gc]::Collect()
} -ThrottleLimit $ThrottleLimit




# Reset the counter
$syncHash['Counter'][0] = 0
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Remove Duplicate Blocks -----------------------------------
# Removes duplicates based on the unique EXE Id.
# Each unique entry will list the date and appraiser versions of when the block was first seen, as well as the same
# for when the blocks were last present in an sdb
$GatedBlocks = $syncHash['GatedBlocks']

#Dump RAW before removing duplicates
try 
{
    [IO.File]::WriteAllLines("$AppraiserWorkingDirectory\SafeGuardHoldDataBaseRAW.json", ($GatedBlocks | ConvertTo-Json), [Text.UTF8Encoding]::new($False))
    Write-Output "Data exported to $AppraiserWorkingDirectory\SafeGuardHoldDataBaseRAW.json."
    Write-Output "Count of blocks before removing duplicates: $($GatedBlocks.Count)"
}
catch 
{
    throw $_.Exception.Message
}


Write-Output "Extracted $($GatedBlocks.Count) blocks from the XML files."
Write-Output "Removing duplicate blocks..."
$GroupedCollection = $GatedBlocks | Group-Object -Property EXE_ID
foreach ($Item in ($GroupedCollection | Where {$_.Count -gt 1}))
{
    $SortedGroup = $Item.group | Sort FirstAppraiserDate,FirstAppraiserVersions
    $Entry2Keep = $SortedGroup[-1]
    $LastAppraiserDate = $SortedGroup[-1].FirstAppraiserDate
    $LastAppraiserVersions = ($SortedGroup.Where({$_.FirstAppraiserDate -eq $LastAppraiserDate}) | Select -ExpandProperty FirstAppraiserVersions) -join ', '
    $FirstAppraiserDate = $SortedGroup[0].FirstAppraiserDate
    $FirstAppraiserVersions = ($SortedGroup.Where({$_.FirstAppraiserDate -eq $FirstAppraiserDate}) | Select -ExpandProperty FirstAppraiserVersions) -join ', '
    $Entry2Keep.LastAppraiserDate = $LastAppraiserDate
    $Entry2Keep.LastAppraiserVersions = $LastAppraiserVersions
    $Entry2Keep.FirstAppraiserDate = $FirstAppraiserDate
    $Entry2Keep.FirstAppraiserVersions = $FirstAppraiserVersions
    $Entries2Remove = $SortedGroup | Select -First ($SortedGroup.Count -1)
    foreach ($entry in $Entries2Remove)
    {
        [void]$GatedBlocks.Remove($entry)
    }
}
foreach ($GatedBlock in $GatedBlocks)
{
    If ($GatedBlock.LastAppraiserDate -eq "?") { $GatedBlock.LastAppraiserDate = $GatedBlock.FirstAppraiserDate }
    If ($GatedBlock.LastAppraiserVersions -eq "?") { $GatedBlock.LastAppraiserVersions = $GatedBlock.FirstAppraiserVersions }
}
Write-Output "Normalized block count: $($GatedBlocks.Count)."
#endregion --------------------------------------------------------------------------------------------------------


#region ----------------------------------------------- Export Data ------------------------------------------------
# Output the data to a JSON file
# Note: each Safeguard Id may have multiple block entries due to differing match requirements per entry,
# such as file version, etc.
write-host -foregroundcolor darkgray "====================================================="
write-host -foregroundcolor magenta "  Exporting Data & Overview"
write-host -foregroundcolor darkgray "====================================================="

try 
{
    [IO.File]::WriteAllLines("$AppraiserWorkingDirectory\SafeGuardHoldDataBase.json", ($GatedBlocks | ConvertTo-Json), [Text.UTF8Encoding]::new($False))
    Write-Output "Data exported to $AppraiserWorkingDirectory\SafeGuardHoldDataBase.json."
}
catch 
{
    throw $_.Exception.Message
}

# Clean up the working directory
if ($PurgeWorkingDirectory)
{
    Write-Output "Cleaning up the working directory..."
    Remove-Item -Path $AppraiserRoot -Recurse -Force
}

$SafeGuardGitHubJSONURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/Feature-Updates/SafeGuardHolds/SafeGuardHoldDataBase.json'
$SafeGuardGitHubData = (Invoke-WebRequest -URI $SafeGuardGitHubJSONURL).content | ConvertFrom-Json

$SafeGuardLocalJsonData = get-content -Path  $AppraiserWorkingDirectory\SafeGuardHoldDataBase.json | ConvertFrom-Json
$SafeGuardLocalJsonData = $SafeGuardLocalJsonData | sort-object -Property SafeguardId
$Difference = $($SafeGuardLocalJsonData.Count - $SafeGuardGitHubData.Count) 
Write-Host "Previous count (Currently on GitHub): $($SafeGuardGitHubData.Count)" -ForegroundColor Green
Write-Host "Current count (Just created): $($SafeGuardLocalJsonData.Count)" -ForegroundColor Green
write-host "Difference: $Difference New Items" -ForegroundColor Green

$Stopwatch.Stop()
Write-Output "Execution complete in $($Stopwatch.Elapsed.Hours) hours $($Stopwatch.Elapsed.Minutes) minutes and $($Stopwatch.Elapsed.Seconds) seconds."
#endregion --------------------------------------------------------------------------------------------------------
