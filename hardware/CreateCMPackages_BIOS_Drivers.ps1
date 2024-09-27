<# 
Version 2020.12.15 - @GWBLOK
Creates Packages for the Models you specify - I have several models pre-populated, Delete ones you don't have and add the ones you need.

HP: needs Product Codes

Dell: needs SystemTypeID for Enterprise Cab & SystemSKUNumber for DCU Cab

Lenovo is a bit odd 
 - Set Model to Version: (Get-CimInstance -ClassName Win32_ComputerSystemProduct).Version
 - Set ProdCode to Modified Model: ((Get-WmiObject -Class Win32_ComputerSystemProduct | Select-Object -ExpandProperty Name).SubString(0, 4)).Trim() 



Info provided in the table is used to create the Packages and populate differnet fields which the other scripts need to pull down BIOS & Drivers.
StageTable... if you don't do "Piloting, or Pre-Prod Testing" of Packages using a different source, then you can remove this and write the script... or just comment out "Pre-Prod"

BIOS Download Scripts will be available here on my github.. eventually, likewise for Drivers.

2020.07.08 - Updated Model List - Added Intel & Nexcom
2020.12.13 - Switched Dells to use SystemTypeID, as it had better lock with the XML (Enterprise Catalog) they provide.
2020.12.14 - Added SystemSKU, to leverage the Dell Command Update XML, which appears to be updated more frequently than their Enterprise Catalog
2021.09.17 - Updated to only use SystemSKU on Dell, and made the Package Names match HP's layout. (Model - XXXX)
2021.12.20 - Updated Script for my new lab, and commented out several models to not over populate my lab
2022.01.28 - Changed Windows 10 to Windows Client to better support Windows 11 ... since Windows 10 isn't the last version of windows despite what MS said in 2015.

2022.02.06 - Added Lenovo Section

You'll need to connect to your CM Provider, and update the variables below for your CM.
#> 


$OperatingSystemDriversSupport = "Windows Client"  #Used to Tag OS Drivers are for (Because we use similar process for Server OS too)

#Load CM PowerShell
$SiteCode = "2CM"
$SetScope = $true #If you plan to scope the packages
$ScopeName = "Dev" #This is the scope you're using to set the packages to.
$User = $env:USERNAME

#Used to set Package Properties via WMI as I can't find a commandlet for it:
$SiteServer = "2CM.2p.garytown.com"
$namespace = "ROOT\SMS\site_$SiteCode"
$classname = "SMS_Package"
$langCode = "1033"
$arch = "64"


Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

$DPGroups = (Get-CMDistributionPointGroup).Name #Currently this is setup to Distribute to ALL DP Groups
$SourceShareLocation = "\\src\src$"
$HPIASourceShareRootLocation = "\\src\src$\Packages\HP ImageAssistant"
$HPIACMPackageName = "HP Image Assistant Softpaq Updater Tool"


#Download HP Icon
Set-Location -Path "C:\"
$HPIconURL = 'https://cdn.cookielaw.org/logos/4abb22ef-0e20-458e-be93-e351ad21c465/d7b075a7-eedf-48c4-8825-82055aa52681/e0ef4872-fc45-4dcb-bf84-4d8081cea805/HP_Logo_OT_email.png'
$HPICONPath = "$($SourceShareLocation)\Drivers\Packages\Windows Client\HP\HPICON.png"
if (!(Test-Path $HPICONPath)){
    Invoke-WebRequest -UseBasicParsing -Uri $HPIconURL -OutFile $HPICONPath
}



$ModelsTable= @(

#HP Area
#@{ ProdCode = '80FC'; Model = "HP Elite x2 1012 G1"; Man = "HP"}
#@{ ProdCode = '82CA'; Model = "HP Elite x2 1012 G2"; Man = "HP"}
#@{ ProdCode = '85B9'; Model = "HP Elite x2 G4"; Man = "HP"}
#@{ ProdCode = '80FB'; Model = "HP EliteBook 1030 G1"; Man = "HP"}
#@{ ProdCode = '80FA'; Model = "EliteBook 1040 G3"; Man = "HP"}
#@{ ProdCode = '807C'; Model = "HP EliteBook 820 G3"; Man = "HP"}
#@{ ProdCode = '8079'; Model = "HP EliteBook 840 G3"; Man = "HP"}
@{ ProdCode = '83B2'; Model = "HP EliteBook 840 G5"; Man = "HP"}
#@{ ProdCode = '8AB8'; Model = "HP EliteBook 840 G8"; Man = "HP"}
@{ ProdCode = '8B41'; Model = "HP EliteBook 840 G10"; Man = "HP"}
#@{ ProdCode = '827D'; Model = "HP EliteBook x360 1030 G2"; Man = "HP"}
#@{ ProdCode = '8438'; Model = "HP EliteBook x360 1030 G3"; Man = "HP"}
#@{ ProdCode = '8637'; Model = "HP EliteBook x360 1030 G4"; Man = "HP"}
#@{ ProdCode = '876D'; Model = "HP EliteBook x360 1030 G7"; Man = "HP"}
#@{ ProdCode = '857F'; Model = "HP Elite x360 1040 G6"; Man = "HP"}
#@{ ProdCode = '896D'; Model = "HP Elite x360 1040 G9"; Man = "HP"}
#@{ ProdCode = '8594'; Model = "HP EliteDesk 800 G5 DM"; Man = "HP"}
@{ ProdCode = '8711'; Model = "HP EliteDesk 800 G6 DM"; Man = "HP"}
@{ ProdCode = '8951'; Model = "HP Elite SFF 600 G9"; Man = "HP"}
@{ ProdCode = '8952'; Model = "HP Elite Mini 600 G9 DM"; Man = "HP"}
#@{ ProdCode = '83D2'; Model = "HP ProBook 640 G4"; Man = "HP"}
#@{ ProdCode = '856D'; Model = "HP ProBook 640 G5"; Man = "HP"}
#@{ ProdCode = '8730'; Model = "HP ProBook 445 G7"; Man = "HP"}
#@{ ProdCode = '8062'; Model = "HP ProDesk 400 G3 SFF"; Man = "HP"}
#@{ ProdCode = '82A2'; Model = "HP ProDesk 400 G4 SFF"; Man = "HP"}
#@{ ProdCode = '83F2'; Model = "HP ProDesk 400 G5 SFF"; Man = "HP"}
#@{ ProdCode = '859B'; Model = "HP ProDesk 400 G6 SFF"; Man = "HP"}
#@{ ProdCode = '21D0'; Model = "HP ProDesk 600 G1 DM"; Man = "HP"}
#@{ ProdCode = '8169'; Model = "HP ProDesk 600 G2 DM"; Man = "HP"}
#@{ ProdCode = '805D'; Model = "HP ProDesk 600 G2 SFF"; Man = "HP"}
#@{ ProdCode = '8053'; Model = "HP ProDesk 600 G2 SFF"; Man = "HP"}
@{ ProdCode = '829E'; Model = "HP ProDesk 600 G3 DM"; Man = "HP"}
#@{ ProdCode = '82B4'; Model = "HP ProDesk 600 G3 SFF"; Man = "HP"}
@{ ProdCode = '83EF'; Model = "HP ProDesk 600 G4 DM"; Man = "HP"}
@{ ProdCode = '859C'; Model = "HP ProDesk 400 G5 DM"; Man = "HP"}
#@{ ProdCode = '8598'; Model = "HP ProDesk 600 G5 DM"; Man = "HP"}
#@{ ProdCode = '8597'; Model = "HP ProDesk 600 G5 SFF"; Man = "HP"}
#@{ ProdCode = '8715'; Model = "HP ProDesk 600 G6 DM"; Man = "HP"}
#@{ ProdCode = '8714'; Model = "HP ProDesk 600 G6 SFF"; Man = "HP"}
#@{ ProdCode = '81C6'; Model = "HP Z6 G4 Workstation"; Man = "HP"}
#@{ ProdCode = '212A'; Model = "HP Z640 Workstation"; Man = "HP"}
#@{ ProdCode = '80D6'; Model = "HP ZBook 17 G3"; Man = "HP"}
#@{ ProdCode = '842D'; Model = "HP ZBook 17 G5"; Man = "HP"}
#@{ ProdCode = '860C'; Model = "HP ZBook 17 G6"; Man = "HP"}
#@{ ProdCode = '869D'; Model = "HP ProBook 440 G7"; Man = "HP"}
#@{ ProdCode = '8730'; Model = "HP ProBook 445 G7"; Man = "HP"}
#@{ ProdCode = '8266'; Model = "HP EliteDesk 705 G3 DM"; Man = "HP"}
#@{ ProdCode = '8955'; Model = "HP Pro Mini 400 G9 PC"; Man = "HP"}
#@{ ProdCode = '89D2'; Model = "HP EliteBook 645 G9"; Man = "HP"}
#@{ ProdCode = '8B12'; Model = "HP EliteBook 645 G9"; Man = "HP"}
#@{ ProdCode = '8055'; Model = "HP EliteDesk 800 G2 Mini"; Man = "HP"}
#@{ ProdCode = '857F'; Model = "HP EliteBook x360 1040 G6"; Man = "HP"}

#Dell - Note, I'm not using SysteTypeID anymore.
#@{SystemTypeID = "2069"; SKU = "0815"; Model = "Latitude 5290"; Man = "Dell"}
#@{SystemTypeID = "2231"; SKU = "08B7"; Model = "Latitude 5300"; Man = "Dell"}
#@{SystemTypeID = "2463"; SKU = "099F"; Model = "Latitude 5310"; Man = "Dell"}
#@{SystemTypeID = "2232"; SKU = "08B8"; Model = "Latitude 5400"; Man = "Dell"}
#@{SystemTypeID = "2464"; SKU = "09A0"; Model = "Latitude 5410"; Man = "Dell"}
#@{SystemTypeID = "2070"; SKU = "0816"; Model = "Latitude 5490"; Man = "Dell"}
#@{SystemTypeID = "2329"; SKU = "0919"; Model = "Latitude 5501"; Man = "Dell"}
#@{SystemTypeID = "2497"; SKU = "09C1"; Model = "Latitude 5511"; Man = "Dell"}
#@{SystemTypeID = "2001"; SKU = "07D1"; Model = "Latitude 5580"; Man = "Dell"}
@{SystemTypeID = "2071"; SKU = "0817"; Model = "Latitude 5590"; Man = "Dell"}
#@{SystemTypeID = "1951"; SKU = "079F"; Model = "Latitude 7280"; Man = "Dell"}
#@{SystemTypeID = "1952"; SKU = "07A0"; Model = "Latitude 7480"; Man = "Dell"}
@{SystemTypeID = "0000"; SKU = "06DE"; Model = "Latitude E5470"; Man = "Dell"}
#@{SystemTypeID = "1759"; SKU = "06DF"; Model = "Latitude E5570"; Man = "Dell"}
#@{SystemTypeID = "1581"; SKU = "062D"; Model = "Latitude E7250"; Man = "Dell"}
#@{SystemTypeID = "1755"; SKU = "06DB"; Model = "Latitude E7270"; Man = "Dell"}
#@{SystemTypeID = "1582"; SKU = "062E"; Model = "Latitude E7450"; Man = "Dell"}
#@{SystemTypeID = "1756"; SKU = "06DC"; Model = "Latitude E7470"; Man = "Dell"}
#@{SystemTypeID = "1723"; SKU = "06BB"; Model = "OptiPlex 3040"; Man = "Dell"}
#@{SystemTypeID = "0000"; SKU = "05A4"; Model = "OptiPlex 9020"; Man = "Dell"}

#@{SystemTypeID = "1954"; SKU = "07A2"; Model = "OptiPlex 5050"; Man = "Dell"}
#@{SystemTypeID = "2139"; SKU = "085B"; Model = "OptiPlex 5060"; Man = "Dell"}
#@{SystemTypeID = "2351"; SKU = "092F"; Model = "OptiPlex 5070"; Man = "Dell"}
#@{SystemTypeID = "2470"; SKU = "09A6"; Model = "OptiPlex 5080"; Man = "Dell"}
#@{SystemTypeID = "1721"; SKU = "06B9"; Model = "OptiPlex 7040"; Man = "Dell"}
@{SystemTypeID = "1953"; SKU = "07A1"; Model = "OptiPlex 7050"; Man = "Dell"}
@{SystemTypeID = "0000"; SKU = "0B8A"; Model = "OptiPlex 3090"; Man = "Dell"}
#@{SystemTypeID = "1914"; SKU = "077A"; Model = "XPS 13 9365"; Man = "Dell"}
#@{SystemTypeID = "2592"; SKU = "0A20"; Model = "Latitude 5420"; Man = "Dell"}
#@{SystemTypeID = "1953"; SKU = "07A1"; Model = "OptiPlex 7050"; Man = "Dell"}
#@{SystemTypeID = "0000"; SKU = "0738"; Model = "Precision 5820 Tower"; Man = "Dell"}
#@{SystemTypeID = "0000"; SKU = "06B7"; Model = "Precision Tower 3620"; Man = "Dell"}

#Intel
#@{ ProdCode = 'NUC7i5DNB'; Model = "NUC7i5DN"; Man = "Intel"}
#@{ ProdCode = 'NUC5i5MYBE'; Model = "NUC5i5"; Man = "Intel"}

#Microsoft
@{SKU = "None";  Model = "Virtual Machine"; Man = "Microsoft"}
@{SKU = "Surface_Book_1793";  Model = "Surface Book 2"; Man = "Microsoft"}

#NexCom
#@{ ProdCode = 'NDiSM535'; Model = "NDiS"; Man = "Nexcom"}

#LENOVO - Unique ID = First 4 of MTM
@{UniqueID = "10MQ";  Model = "ThinkCentre M710q"; Man = "Lenovo"}
@{UniqueID = "11LV";  Model = "ThinkCentre M60e"; Man = "Lenovo"}
)
#>

<#
$ModelsTable= @(

@{ ProdCode = '8B41'; Model = "HP EliteBook 840 G10"; Man = "HP"}

)
#>

$StageTable = @(
@{ Level = 'Dev'}
@{ Level = 'Prod'}
)



$PackageTypes = @(
@{ PackageType = 'BIOS'}
@{ PackageType = 'Driver'}
@{ PackageType = "Repo"}
)

#Create HPIA Package
Set-Location -Path "C:" 
if (!(Test-Path $HPIASourceShareRootLocation)){New-Item -Path $HPIASourceShareRootLocation -ItemType Directory -Force | Out-Null}
Set-Location -Path "$($SiteCode):"
$Test = Get-CMPackage -Name $HPIACMPackageName -Fast
if (!($Test)){
    
    Set-Location -Path "C:" 
    if (!(Test-Path -Path "$HPIASourceShareRootLocation\temp")){New-Item -Path "$HPIASourceShareRootLocation\temp" -ItemType Directory -Force | Out-Null}
    Set-Location -Path "$($SiteCode):"
    $NewPackage = New-CMPackage -Name $HPIACMPackageName
    Set-CMPackage -InputObject $NewPackage -Path "$HPIASourceShareRootLocation\temp"
    Set-CMPackage -InputObject $NewPackage -IconLocationFile $HPICONPath
    Set-CMPackage -InputObject $NewPackage -Description 'https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html'
    Set-CMPackage -InputObject $NewPackage -Manufacturer 'HP'
    
    $ReadmeContents = "Temporary, overwritten with more details below, just needed so there is content to distribute"
    Set-Location -Path "c:"
    $ReadmeContents | Out-File -FilePath "$HPIASourceShareRootLocation\temp\Readme.txt"
    Set-Location -Path "$($SiteCode):"

    foreach ($Group in $DPGroups) #Distribute Content
        {
        Write-host "  Starting Distribution to DP Group $Group" -ForegroundColor Green
        Start-CMContentDistribution -InputObject $NewPackage -DistributionPointGroupName $Group
    }
        
}
Set-Location -Path "C:" 

#Run through each Type for each Stage for each Platform and build packages for each


$OverallSummary = @()

foreach ($Type in $PackageTypes){

    #Create Sub Folders in Console (Optional)
    $FolderName = "$($Type.PackageType) Packages" #Driver Package Folder
    $NewFolderPath = "$($SiteCode):\Package\$($FolderName)"
    if (!(Test-path -Path $NewFolderPath))
        {
        New-Item -Name $FolderName -Path "$($SiteCode):\Package"
        Write-Host "Created CM Folder $NewFolderPath" -ForegroundColor Green
        }
    else {Write-Host "CM Folder $NewFolderPath already exist" -ForegroundColor Green}
    
    


    Set-Location -Path "$($SiteCode):"

    foreach ($Stage in $StageTable)
        {
        Write-Host "Working on Stage: $($Stage.Level)" -ForegroundColor Cyan
        foreach ($Model in $ModelsTable)
            {
            Write-host "Starting Model $($Model.Model)" -ForegroundColor magenta
            if ($Model.Man -eq "HP"){
                $Name = "$($Type.PackageType) $($Model.Man) $($Model.ProdCode) - $($Stage.Level)"
                $FolderName = "$($Model.ProdCode)" #Example: HP Elite x2 1012 G1 - 80FC
                #Get all Models supported by Platform (ProdCode) and Reduce the names to fit in the 127 char limit description field
                $ModelSupport = (Get-HPDeviceDetails -Platform $($Model.ProdCode)).Name
                $ModelSupport = $ModelSupport.replace(" Notebook PC","")
                $ModelSupport = $ModelSupport.replace(" 2-in-1","")
                $ModelSupport = $ModelSupport.replace(" Mobile Workstation PC","")
                $ModelSupport = $ModelSupport.replace(" Desktop PC","")
                $ModelSupport = $ModelSupport.replace(" All-in-One","AIO")
                $ModelSupport = $ModelSupport.replace(" Small Form Factor PC","")
                $ModelSupport = $ModelSupport.replace(" Microtower PC","")
                $ModelSupport = $ModelSupport.replace(" PC","")
                $ModelSupport = $ModelSupport.replace(" Workstation","")
                $ModelSupport = $ModelSupport.replace("HP ","")
                $ModelSupport = $ModelSupport -replace "\d+(\.\d+)? inch ", ""
                #$ModelSupport = $ModelSupport.replace(".","")
                $ModelSupport = $ModelSupport.replace("Elite","E")
                $ModelSupport = $ModelSupport.replace("Book","B")
                $ModelSupport = $ModelSupport.replace("Pro","P")
                $ModelSupport = $ModelSupport.replace("Desktop","DT")
                $ModelSupport = $ModelSupport.replace("Desk","D")
                $ModelSupport = $ModelSupport.replace("Book","B")
                $ModelSupport = $ModelSupport.replace("Book","B")
                $ModelSupport = $ModelSupport.replace("Book","B")
                [String]$Description = $ModelSupport -join " | "
            }
            elseif ($Model.Man -eq "Dell"){
                $Name = "$($Type.PackageType) $($Model.Man) $($Model.SKU) - $($Stage.Level)"
                $FolderName = "$($Model.SKU)" #Example: Latitude 5300 - YKDE
            }
            elseif ($Model.Man -eq "Lenovo"){
                $Name = "$($Type.PackageType) $($Model.Man) $($Model.UniqueID) - $($Stage.Level)"
                $FolderName = "$($Model.UniqueID)" #Example: ThinkCentre M710q - 10MQ
            }
            elseif ($Model.Man -eq "Microsoft"){
                $Name = "$($Type.PackageType) $($Model.Man) $($Model.SKU) - $($Stage.Level)"
                $FolderName = "$($Model.SKU)" #Example: Microsoft
            }
            else{
                $Name = "$($Type.PackageType) $($Model.Man) $($Model.ProdCode) - $($Stage.Level)"
                $FolderName = "$($Model.ProdCode)" #Example: NUC7i5DN - NUC7i5DNB
            }
        
            #Source Folders Area 
            Set-Location -Path "C:"
            if ($Type.PackageType -eq "BIOS"){$SourceSharePackageLocation = "$($SourceShareLocation)\Firmware\Packages\$($Model.Man)\$FolderName\$($Stage.Level)"}

            if ($Type.PackageType -eq "Driver"){$SourceSharePackageLocation = "$($SourceShareLocation)\Drivers\Packages\Windows Client\$($Model.Man)\$FolderName\Pack\$($Stage.Level)"}
    
            if ($Type.PackageType -eq "Repo"){$SourceSharePackageLocation = "$($SourceShareLocation)\Drivers\Packages\Windows Client\$($Model.Man)\$FolderName\Repo\$($Stage.Level)"}


            #Create Prod & PreProd along with Online & Offline Sub Folders.
            if (!(Test-Path  $SourceSharePackageLocation)){New-Item -Path $SourceSharePackageLocation -ItemType Directory}
            Else {Write-Host "$SourceSharePackageLocation already exist"}                  

            #Update or Create new CM Package
            Set-Location -Path "$($SiteCode):"
            $PackageCheck = Get-CMPackage -Name $Name -Fast
            if (!($PackageCheck)){
                #Create New Package Shell
                Write-Host " Starting on Package $Name" -ForegroundColor gray
                $NewPackage = New-CMPackage -Name $Name 
                
                $OverallSummary += @{ Name = $Name; Folder = $FolderName ; Status = "Added"; Stage = $Stage.Values; Type = $Type.Values; Model = $Model.Model ; Man = $Model.Man; ProdCode = $Model.ProdCode }
                Set-CMPackage -InputObject $NewPackage -Path $SourceSharePackageLocation
                $ReadmeContents = "Temporary, overwritten with more details below, just needed so there is content to distribute"
                Set-Location -Path "c:"
                $ReadmeContents | Out-File -FilePath "$SourceSharePackageLocation\Readme.txt"
                Set-Location -Path "$($SiteCode):"
                foreach ($Group in $DPGroups) #Distribute Content
                    {
                    Write-host "  Starting Distribution to DP Group $Group" -ForegroundColor Green
                    Start-CMContentDistribution -InputObject $NewPackage -DistributionPointGroupName $Group
                }
                Set-Location -Path "c:"
                Remove-Item -Path "$SourceSharePackageLocation\Readme.txt" -Force
                Set-Location -Path "$($SiteCode):" 
            }
            else {
                Write-Host " Package $Name already exist, confirming information..." -ForegroundColor Cyan
                $OverallSummary += @{ Name = $Name; Folder = $FolderName ; Status = "Present"; Stage = $Stage.Values; Type = $Type.Values; Model = $Model.Model ; Man = $Model.Man; ProdCode = $Model.ProdCode}
                #Confirms Fields are set to standard info
            }
            #Set Addtional Package Info:
                if (!($PackageCheck)){$PackageCheck = Get-CMPackage -Name $Name -Fast}
                #Set Manufacturer
                Set-CMPackage -InputObject $PackageCheck -Manufacturer $Model.Man
                
                #Set Language (Unique ID)
                if ($Model.Man -eq "Dell" -or $Model.Man -eq "Microsoft"){Set-CMPackage -InputObject $PackageCheck -Language $Model.SKU}
                elseif($Model.Man -eq "Lenovo"){Set-CMPackage -InputObject $PackageCheck -Language $Model.UniqueID}
                else {Set-CMPackage -InputObject $PackageCheck -Language $Model.ProdCode}
                
                #Set MifName (Stage)
                Set-CMPackage -InputObject $PackageCheck -MifName $Stage.Level
                
                #Set Path (Package Source Path)
                Set-CMPackage -InputObject $PackageCheck -Path $SourceSharePackageLocation
                
                #Set a default Version of 0.0.1 to the Package or don't touch if already set.
                if ($PackageCheck.Version -eq $null){Set-CMPackage -InputObject $PackageCheck -Version "0.0.1"}
                
                #Set MifPublisher to who is running the script, so you can see who created package
                Set-CMPackage -InputObject $PackageCheck -MifPublisher $User

                #Set MifFileName to the My Perferred Model Name (Nice for reference)
                if ($Model.Man -eq "Lenovo"){Set-CMPackage -InputObject $PackageCheck -MifFileName "$($Model.Model) $($Model.Type)"}
                else {Set-CMPackage -InputObject $PackageCheck -MifFileName $Model.Model}

                #Set Description (Currenly only using on HP, field will updated via other scripts)
                if ($Model.Man -eq "HP"){Set-CMPackage -InputObject $PackageCheck -Description $Description}
                else {Set-CMPackage -InputObject $PackageCheck -Description ""}

                #Set the Scope on the Packages (RBAC)
                if ($SetScope -eq $true){
                    Write-Host  "  Starting Scope Maintenance" -ForegroundColor Cyan
                    #$ConfirmApp = Get-CMApplication -Name $M365.Name -ErrorAction SilentlyContinue
                    $AppScopes = Get-CMObjectSecurityScope -InputObject $PackageCheck 
                    if ($AppScopes.Count -eq 1 -and $AppScopes.CategoryName -eq "$ScopeName"){
                        Write-Host  "   Scope is already set correctly for $Name" -ForegroundColor Yellow
                    } 
                    if ($AppScopes.CategoryName -ccontains "Default"){
                        $DefaultScope = $AppScopes | Where-Object {$_.CategoryName -eq "default"} 
                        if (!($AppScopes.CategoryName -contains "$ScopeName")){
                            $PackageScope = Get-CMSecurityScope | Where-Object {$_.CategoryName -eq "$ScopeName"}
                            $AddRecastScope = Add-CMObjectSecurityScope -InputObject $PackageCheck -Scope $PackageScope
                            $PackageCheck = Get-CMPackage -Name $Name -Fast
                            Write-Host  "   Adding Scope $($PackageScope.CategoryName) to $Name" -ForegroundColor Green
                        }
                        $RemovedDefaultAppScope = Remove-CMObjectSecurityScope -InputObject $PackageCheck -Scope $DefaultScope -Force
                        $PackageCheck = Get-CMPackage -Name $Name -Fast
                        Write-Host  "   Removing Default Scope from $Name" -ForegroundColor Green
                    } 
                    $NonCorrectScope = $AppScopes | Where-Object {$_.CategoryName -ne "$ScopeName" -and $_.CategoryDescription -notmatch "A built-in security scope"} 
                    foreach ($Scope in $NonCorrectScope){
                        Write-Host  "   Removing Scope $($Scope.CategoryName) from $Name" -ForegroundColor Green
                        $RemovedAppScopes = Remove-CMObjectSecurityScope -InputObject $PackageCheck -Scope $Scope -Force
                    }
                }
            #Create Program and Tag for TS - This runs each time as there isn't a way (That I know of) to query if EnableTS is already set, so I just set it each run, no harm done.
            Set-Location -Path "$($SiteCode):"
            if (!($PackageCheck)){$PackageProgram = Get-CMProgram -PackageId $NewPackage.PackageID;$ProgramPackID = $NewPackage.PackageID}
            else{$PackageProgram = Get-CMProgram -PackageId $PackageCheck.PackageID;$ProgramPackID = $PackageCheck.PackageID}
            if ($PackageProgram -eq $null){
                Write-host "  Create New Program" -ForegroundColor Yellow
                $NewProgram = New-CMProgram -PackageId $ProgramPackID -StandardProgramName 'Pre-cache' -CommandLine 'cmd /c' -RunType Hidden -ProgramRunType WhetherOrNotUserIsLoggedOn -ErrorAction SilentlyContinue
                $PackageProgram = Get-CMProgram -PackageId $ProgramPackID
                Write-Host "  Program Name: $($PackageProgram.ProgramName) Created" -ForegroundColor Green
                Set-CMProgram -InputObject $PackageProgram -EnableTaskSequence $true -StandardProgram
                Write-Host "  Set Program $($PackageProgram.ProgramName) to Enable TS" -ForegroundColor Green
            }
            else{
                #Just confirming that this setting is set on every program
                Set-CMProgram -InputObject $PackageProgram -EnableTaskSequence $true -StandardProgram
            }
            #Confirm Package Attributes
            $PackageConfirm = Get-CMPackage -Name $Name -Fast
            
            #Set Pre-DownloadRules
            $CMPackageUpdate = Get-WmiObject -Class $classname -ComputerName $SiteServer -Namespace $namespace | Where-Object {$_.packageID -eq $PackageConfirm.PackageID}
            $CMPackageUpdate.PreDownloadRule = "@root\cimv2 select * from win32_operatingsystem where osarchitecture like ""%$arch%"" and oslanguage=$langCode"
            $CMPackageUpdate.Put() | Out-Null

            #Set Icon
            if ($Model.Man -eq "HP"){
                if (!($PackageConfirm.Icon)){
                    Set-CMPackage -InputObject $PackageConfirm -IconLocationFile $HPICONPath
                }
            }
        
            if ($Model.Man -eq "HP"){Write-Host "  Finished: $($PackageConfirm.Name) | Manufacturer: $($PackageConfirm.Manufacturer) | ProdCode: $($PackageConfirm.Language)" -ForegroundColor Green}
            elseif ($Model.Man -eq "Dell"){Write-Host "  Finished: $($PackageConfirm.Name) | Manufacturer: $($PackageConfirm.Manufacturer) | SKU: $($PackageConfirm.Language)" -ForegroundColor Green}
            else {Write-Host "  Finished: $($PackageConfirm.Name) | Manufacturer: $($PackageConfirm.Manufacturer) | ProdCode: $($PackageConfirm.Language)" -ForegroundColor Green}
            #Move Package to Folder (in console)
            if (test-path $NewFolderPath){Move-CMObject -ObjectId $PackageConfirm.PackageID -FolderPath $NewFolderPath}

            #Create Package.id File(s)
            Set-Location -Path "C:"
            $PackageCheck.PackageID | Out-File -FilePath "$SourceSharePackageLocation\Package.id" -Force
            $ReadmeContents = $PackageCheck
            $ReadmeContents | Out-File -FilePath "$SourceSharePackageLocation\Readme.txt"
            Write-Host "  ----------------------------------------------------------  " -ForegroundColor darkgray
        }
    }
}


#Write information to the Root Driver HP folder that includes Model Mappings to Platform IDs (ProdCode)
if ($Model.Man -eq "HP"){

    $PlatformInfoFilePath = "$($SourceShareLocation)\Drivers\Packages\Windows Client\$($Model.Man)\PlatformInfo.txt"
    if (Test-Path -Path $PlatformInfoFilePath){Remove-Item -Path $PlatformInfoFilePath -Force}

    Foreach ($Platform in $ModelsTable.ProdCode){
        Get-HPDeviceDetails -Platform $Platform | Select-Object -Property "SystemID", "Name"  | Out-File -FilePath $PlatformInfoFilePath -Append
    }
    #Copy to BIOS & Driver Area
    Copy-Item -Path $PlatformInfoFilePath -Destination "$($SourceShareLocation)\Firmware\Packages\$($Model.Man)\PlatformInfo.txt" -Force
}

#This is just summary info, not actually used for anything other than the person who ran the script.
$AlreadyInSystem = $OverallSummary | Where-Object {$_.Status -eq "Present" -and $_.Type -eq "BIOS"-and $_.Stage -eq "Prod"}
$AddedToSystem = $OverallSummary | Where-Object {$_.Status -eq "Added" -and $_.Type -eq "BIOS"-and $_.Stage -eq "Prod"}


Write-Host "!!!!! Script Summary !!!!!" -ForegroundColor Green
if ($AlreadyInSystem.Count -ge "1"){Write-Host " $($AlreadyInSystem.Count) Models already in System " -ForegroundColor Green}
if ($AddedToSystem.Count -ge "1")
    {
    Write-Host " Models added to System $($AddedToSystem.Count)" -ForegroundColor Green
    foreach ($Added in $AddedToSystem)
        {
        Write-Host "  $($Added.Man) $($Added.Model) - $($Added.ProdCode)" -ForegroundColor Cyan
        }
    }
