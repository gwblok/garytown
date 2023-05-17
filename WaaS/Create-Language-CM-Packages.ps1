<#
Creates CM Packages for Languages
Make sure you've downloaded the ISOs from VLSC
- FOD ISO
- Language Pack ISO (WIndows 10 Language Packs, Change Language from English to Mult-Language!!!!!!!!!!!!
- Language Pack ISO Updates for 20H2 as well. :-()
  - need to update the LXP files

YOU NEED TO UPDATE THESE ITEMS Below with the locations of the Mounted ISOs
$FODISO = "F:"
$LangPackISO = "G:"
$LXPUpdateISO = "I:"

This only have a handful of languages setup in the script, if you want more, you'll need to add them into the array along with the other information that goes along with them.
#GEOID: https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations
#Keyboard = https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs

NOTE, if you do not add this information, other dependancies will not work properly in the WaaS Process I've developed.

#>
# Site configuration
$SiteCode = "PS2" # Site code 
$ProviderMachineName = "CM.corp.viamonstra.com" # SMS Provider machine name

# Customizations
$initParams = @{}
#$initParams.Add("Verbose", $true) # Uncomment this line to enable verbose logging
#$initParams.Add("ErrorAction", "Stop") # Uncomment this line to stop the script on any errors

# Do not change anything below this line

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

#GEOID: https://docs.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations
#Keyboard = https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs

$LangsTable= @(

@{ LangCode = 'FR-CA'; GEOID = "39"; KeyboardLocale = "0c0c:00011009"; Info_LocName = "Canada"}
@{ LangCode = 'JA-JP'; GEOID = "122"; KeyboardLocale = "0411:{03B5835F-F03C-411B-9CE2-AA23E1171E36}{A76C93D9-5523-4E90-AAFA-4DB112F9AC76}"; Info_LocName = "Japan"}
@{ LangCode = 'KO-KR'; GEOID = "134"; KeyboardLocale = "0412:{A028AE76-01B1-46C2-99C4-ACD9858AE02F}{B5FE1F02-D5F2-4445-9C03-C568F23C99A1}"; Info_LocName = "Republic of Korea"}
@{ LangCode = 'TH-TH'; GEOID = "227"; KeyboardLocale = "041e:0000041e"; Info_LocName = "Thailand"}
@{ LangCode = 'VI-VN'; GEOID = "251"; KeyboardLocale = "042a:0000042a"; Info_LocName = "Vietnam"}
@{ LangCode = 'ZH-CN'; GEOID = "104"; KeyboardLocale = "0804:{81D4E9C9-1D3B-41BC-9E6C-4B40BF79E35E}{FA550B04-5AD7-411f-A5AC-CA038EC515D7}"; Info_LocName = "Hong Kong SAR"}
@{ LangCode = 'ZH-HK'; GEOID = "104"; KeyboardLocale = "042a:0804:{81D4E9C9-1D3B-41BC-9E6C-4B40BF79E35E}{FA550B04-5AD7-411f-A5AC-CA038EC515D7}"; Info_LocName = "unknown"}
@{ LangCode = 'ZH-TW'; GEOID = "237"; KeyboardLocale = "0404:{B115690A-EA02-48D5-A231-E3578D2FDF80}{B2F9C502-1742-11D4-9790-0080C882687E}"; Info_LocName = "Taiwan"}
)

$FileTable= @(

@{ Type = 'LP'; Mode = 'OFFLINE'; Name = "Microsoft-Windows-Client-Language-Pack_x64"}
@{ Type = 'FoD'; Mode = 'OFFLINE'; Name = "Microsoft-Windows-LanguageFeatures-Basic"}
@{ Type = 'FoD'; Mode = 'OFFLINE'; Name = "Microsoft-Windows-LanguageFeatures-OCR"}
@{ Type = 'FoD'; Mode = 'OFFLINE'; Name = "Microsoft-Windows-LanguageFeatures-Speech"}
@{ Type = 'FoD'; Mode = 'OFFLINE'; Name = "Microsoft-Windows-LanguageFeatures-TextToSpeech"}
@{ Type = 'FoD'; Mode = 'ONLINE'; Name = "Microsoft-Windows-InternetExplorer-Optional-Package"}
@{ Type = 'FoD'; Mode = 'ONLINE'; Name = "Microsoft-Windows-NetFx3-OnDemand-Package"}
)


$Build = '2004'
$LangPathSource = "\\SRC\SRC$\LanguageSupport"
Set-Location "$($SiteCode):\"
$DPGroups = (Get-CMDistributionPointGroup).Name #Currently this is setup to Distribute to ALL DP Groups
foreach ($Lang in $LangsTable) 
    {
    Write-Host "Starting Process on Language Pack $($Lang.LangCode)" -ForegroundColor Cyan
    $LangPackagePath = "$LangPathSource\$Build\Packages\$($Lang.LangCode)"
    if ($TestPackage = Get-CMPackage -Name "$Build Language Pack $($Lang.LangCode)" -Fast)
        {
        write-host " Found Package: $($TestPackage.Name), Confirming Settings" 
        if ($TestPackage.PkgSourcePath -ne $LangPackagePath)
            {
            write-host "  Updating Path to: $($Lang.FullName)" -ForegroundColor Yellow
            Set-CMPackage -InputObject $TestPackage -Path $LangPackagePath
            }
        else{write-host "  Path Set Correctly: $LangPackagePath" -ForegroundColor Green}
        if ($TestPackage.Description -ne $Lang.KeyboardLocale)
            {
            write-host "  Updating Description to Keyboard Code: $($Lang.KeyboardLocale)" -ForegroundColor Yellow
            Set-CMPackage -InputObject $TestPackage -Description $Lang.KeyboardLocale
            }
        else{write-host "  Keyboard Locale (Description) Set Correctly: $($Lang.KeyboardLocale)" -ForegroundColor Green}
        if ($TestPackage.MIFPublisher -ne $Lang.GEOID)
            {
            write-host "  Updating MIFPublisher Field to GEOID: $($Lang.GEOID)" -ForegroundColor Yellow
            Set-CMPackage -InputObject $TestPackage -MIFPublisher $Lang.GEOID
            }
        else{write-host "  GeoID (MIFPublisher) Set Correctly: $($Lang.GEOID)" -ForegroundColor Green}
        if ($TestPackage.MIFName -ne $Lang.Info_LocName)
            {
            write-host "  Updating MIFName Field to Local Country Name: $($Lang.Info_LocName)" -ForegroundColor Yellow
            Set-CMPackage -InputObject $TestPackage -MifName $Lang.Info_LocName
            }
        else{write-host "  Country Name (MIFName) Set Correctly: $($Lang.Info_LocName)" -ForegroundColor Green}
        if ($TestPackage.Language -ne $Lang.LangCode)
            {
            write-host "  Updating Language Field to Local Country Name: $($Lang.LangCode)" -ForegroundColor Yellow
            Set-CMPackage -InputObject $TestPackage -Language $Lang.LangCode
            }
        else{write-host "  Language Set Correctly: $($Lang.LangCode)" -ForegroundColor Green}

        }
    else
        {
        Write-Host " Creating: $Build Language Pack $($Lang.LangCode)"
        
        #Create Package Content
        $Readme = {Offline Folder is called by the Setup Engine.  These files are used in conjunction with the /InstallLangPacks %LANG01%
Online Folder is used post upgrade to add additonal CAB files that fail in the other method, and then to call the "Control" file to enable / force the language}
        Set-Location "c:\"
        if (!(Test-Path  $LangPackagePath)){New-Item -Path $LangPackagePath -ItemType Directory}
        Else {Write-Host "$LangPackagePath already exist"}
        if (!(Test-Path  "$LangPackagePath\Online")){New-Item -Path "$LangPackagePath\Online" -ItemType Directory}
        Else {Write-Host "$($LangPackagePath)\Online already exist"}
        if (!(Test-Path  "$LangPackagePath\Offline")){New-Item -Path "$LangPackagePath\Offline" -ItemType Directory}
        Else {Write-Host "$($LangPackagePath)\Offline already exist"}
        if (!(Test-Path  "$LangPackagePath\LocalExperiencePack")){New-Item -Path "$LangPackagePath\LocalExperiencePack" -ItemType Directory}
        Else {Write-Host "$($LangPackagePath)\LocalExperiencePack already exist"}
        
        New-Item -Path $LangPackagePath -Name "Readme.txt" -ItemType file -Value $Readme -Force
        Set-Location "$($SiteCode):\"

        #Set Package Attributes
        $NewPackage = New-CMPackage -Name "$Build Language Pack $($Lang.LangCode)" -Version $Build -Language $Lang.LangCode -Path $LangPackagePath -Description $Lang.KeyboardLocale
        Set-CMPackage -InputObject $NewPackage -MifName $Lang.Info_LocName
        Set-CMPackage -InputObject $NewPackage -MIFPublisher $Lang.GEOID
        foreach ($Group in $DPGroups) #Distribute Content
            {
            Write-host " Starting Distribution to DP Group $Group" -ForegroundColor Magenta
            Start-CMContentDistribution -InputObject $NewPackage -DistributionPointGroupName $Group
            }
        #Create Progam and Name
        $NewProgram = New-CMProgram -PackageName $NewPackage.Name -CommandLine "cmd.exe /c" -StandardProgramName "Pre-cache" -RunType Hidden -DiskSpaceRequirement "50" -ProgramRunType WhetherOrNotUserIsLoggedOn -RunMode RunWithAdministrativeRights
        Set-CMProgram -InputObject $NewProgram -StandardProgram -ProgramName "Pre-cache" -EnableTaskSequence $true
       
        Write-Host " Completed: $($NewPackage.Name) ID: $($NewPackage.PackageID), Confirming Attributes:"
        
        if ($TestNewPackage = Get-CMPackage -Name $NewPackage.Name -Fast)
            {
            write-host " Found Package: $($TestNewPackage.Name), Confirming Settings" 
            if ($TestNewPackage.PkgSourcePath -ne $LangPackagePath)
                {
                write-host "  Updating Path to: $($Lang.FullName)" -ForegroundColor Yellow
                Set-CMPackage -InputObject $TestNewPackage -Path $LangPackagePath
                }
            else{write-host "  Path Set Correctly: $LangPackagePath" -ForegroundColor Green}
            if ($TestNewPackage.Description -ne $Lang.KeyboardLocale)
                {
                write-host "  Updating Description to Keyboard Code: $($Lang.KeyboardLocale)" -ForegroundColor Yellow
                Set-CMPackage -InputObject $TestNewPackage -Description $Lang.KeyboardLocale
                }
            else{write-host "  Keyboard Locale (Description) Set Correctly: $($Lang.KeyboardLocale)" -ForegroundColor Green}
            if ($TestNewPackage.MIFPublisher -ne $Lang.GEOID)
                {
                write-host "  Updating MIFPublisher Field to GEOID: $($Lang.GEOID)" -ForegroundColor Yellow
                Set-CMPackage -InputObject $TestNewPackage -MIFPublisher $Lang.GEOID
                }
            else{write-host "  GeoID (MIFPublisher) Set Correctly: $($Lang.GEOID)" -ForegroundColor Green}
            if ($TestNewPackage.MIFName -ne $Lang.Info_LocName)
                {
                write-host "  Updating MIFName Field to Local Country Name: $($Lang.Info_LocName)" -ForegroundColor Yellow
                Set-CMPackage -InputObject $TestNewPackage -MifName $Lang.Info_LocName
                }
            else{write-host "  Country Name (MIFName) Set Correctly: $($Lang.Info_LocName)" -ForegroundColor Green}
            if ($TestNewPackage.Language -ne $Lang.LangCode)
                {
                write-host "  Updating Language Field to Local Country Name: $($Lang.LangCode)" -ForegroundColor Yellow
                Set-CMPackage -InputObject $TestNewPackage -Language $Lang.LangCode
                }
            else{write-host "  Language Set Correctly: $($Lang.LangCode)" -ForegroundColor Green}

            }
        }
    }



#Get language Files

#Set Location of FoD Mounted ISO
$FODISO = "F:"
$LangPackISO = "G:"
$LXPUpdateISO = "I:"
if ((Test-Path $FODISO) -and (Test-Path $LangPackISO))
    {
    foreach ($Lang in $LangsTable)#{}
        {
        Write-Host "Starting Language $($Lang.LangCode) | $($Lang.Info_LocName)" -ForegroundColor Magenta
        Set-Location "$($SiteCode):\"
        if ($TestPackage = Get-CMPackage -Name "$Build Language Pack $($Lang.LangCode)" -Fast)
            {
            foreach ($File in $FileTable | Where-Object {$_.Type -eq "FoD"})
                {
                Write-Host " Checking for File $($File.Name) in ISO" -ForegroundColor Yellow
                Set-Location -Path "c:\"
                $CurrentFile = $null
                $CurrentFile = Get-ChildItem -Path $FODISO | Where-Object {$_.Name -Match $File.Name -and $_.Name -Match $($Lang.LangCode)} -ErrorAction SilentlyContinue
                if ($CurrentFile)
                    { write-host "  Found & Copied $($CurrentFile.FullName)" -ForegroundColor Green
                    Copy-Item -Path $CurrentFile.FullName -Destination "$($TestPackage.PkgSourcePath)\$($File.Mode)" -Force
                    }
                else {write-host "  Did NOT Found a File for $($File.Name)" -ForegroundColor red}
                    
                }
            foreach ($File in $FileTable | Where-Object {$_.Type -eq "LP"})
                {
                Write-Host " Checking for File $($File.Name) in ISO" -ForegroundColor Yellow
                Set-Location -Path "c:\"
                $CurrentFile = $null
                $CurrentFile = Get-ChildItem -Path "$LangPackISO\x64\langpacks" | Where-Object {$_.Name -Match $File.Name -and $_.Name -Match $($Lang.LangCode)} -ErrorAction SilentlyContinue
                if ($CurrentFile)
                    { write-host "  Found & Copied $($CurrentFile.FullName)" -ForegroundColor Green
                    Copy-Item -Path $CurrentFile.FullName -Destination "$($TestPackage.PkgSourcePath)\$($File.Mode)" -Force
                    }
                else {write-host "  Did NOT Found a File for $($File.Name)" -ForegroundColor red}
                    
                }

                Write-Host " Checking for LocalExperiencePack (LXP) in ISO" -ForegroundColor Yellow
                Set-Location -Path "c:\"
                $CurrentFolder = $null
                $CurrentFolder = Get-ChildItem -Path "$LangPackISO\LocalExperiencePack" | Where-Object {$_.Name -Match $($Lang.LangCode)} -ErrorAction SilentlyContinue
                if ($CurrentFolder)
                    { write-host "  Found & Copied $($CurrentFolder.FullName) Contents" -ForegroundColor Green
                    Copy-Item -Path "$($CurrentFolder.FullName)\*.*" -Destination "$($TestPackage.PkgSourcePath)\LocalExperiencePack" -Force
                    }
                else {write-host "  Did NOT Find a LocalExperiencePack for $($Lang.LangCode)" -ForegroundColor red}

            }
        Write-Host "---------------------------------------" -ForegroundColor Gray

        }
    }


if (Test-Path $LXPUpdateISO)
    {
    Write-Host " Checking for LocalExperiencePack (LXP) in ISO" -ForegroundColor Yellow
    Set-Location -Path "c:\"
    $CurrentFolder = $null
    $CurrentFolder = Get-ChildItem -Path "$LXPUpdateISO\LocalExperiencePack" | Where-Object {$_.Name -Match $($Lang.LangCode)} -ErrorAction SilentlyContinue
    if ($CurrentFolder)
        { write-host "  Found & Copied $($CurrentFolder.FullName) Contents" -ForegroundColor Green
        Copy-Item -Path "$($CurrentFolder.FullName)\*.*" -Destination "$($TestPackage.PkgSourcePath)\LocalExperiencePack" -Force
        }
    else {write-host "  Did NOT Find a LocalExperiencePack for $($Lang.LangCode)" -ForegroundColor red}
    }
