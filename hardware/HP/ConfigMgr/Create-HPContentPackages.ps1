<# 
Version 2023.12.15 - @GWBLOK
Creates Packages for the Models you specify - I have several models pre-populated, Delete ones you don't have and add the ones you need.

HP: needs Product Codes (Platform)
(Get-CimInstance -ClassName win32_baseboard).Product


Info provided in the table is used to create the Packages and populate differnet fields which the other scripts need to pull down BIOS & Drivers.
StageTable... if you don't do "Piloting, or Pre-Prod Testing" of Packages using a different source, then you can remove this and write the script... or just comment out "Pre-Prod"

You'll need to connect to your CM Provider, and update the variables below for your CM.


I'd recommend using this in a lab first, and just populate one or two models in the ModelsTable to watch what happens.


THINGS YOU MUST CHANGE

$SiteCode
$ScopeName (If you're using SCOPES)
$SiteServer (and make sure the account you're running this with has proper rights on the site server)
$SourceShareLocation (Root of where you want your HP BIOS / Drivers / Offline Repo to be built and stored for a CM Package)

THINGS YOU PROBABLY WANT TO CHANGE
$langCode
$DPGroups
$ModelsTable
$StageTable
#> 


$OperatingSystemDriversSupport = "Windows Client"  #Used to Tag OS Drivers are for (Because we use similar process for Server OS too)

#Load CM PowerShell
$SiteCode = "MCM"
$SetScope = $true #If you plan to scope the packages
$ScopeName = "Dev" #This is the scope you're using to set the packages to.

#Used to set Package Properties via WMI as I can't find a commandlet for it:
$SiteServer = "cm.lab.garytown.com"
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

Set-Location -Path "$($SiteCode):"
$ModelsTable= @(

#@{ ProdCode = '80FC'; Model = "HP Elite x2 1012 G1"; Man = "HP"}
#@{ ProdCode = '82CA'; Model = "HP Elite x2 1012 G2"; Man = "HP"}
#@{ ProdCode = '85B9'; Model = "HP Elite x2 G4"; Man = "HP"}
#@{ ProdCode = '80FB'; Model = "HP EliteBook 1030 G1"; Man = "HP"}
#@{ ProdCode = '80FA'; Model = "EliteBook 1040 G3"; Man = "HP"}
#@{ ProdCode = '807C'; Model = "HP EliteBook 820 G3"; Man = "HP"}
#@{ ProdCode = '8079'; Model = "HP EliteBook 840 G3"; Man = "HP"}
@{ ProdCode = '83B2'; Model = "HP EliteBook 840 G5"; Man = "HP"}
@{ ProdCode = '8AB8'; Model = "HP EliteBook 840 G8"; Man = "HP"}
@{ ProdCode = '880D'; Model = "HP EliteBook 840 G8"; Man = "HP"}
@{ ProdCode = '8B41'; Model = "HP EliteBook 840 G10"; Man = "HP"}
#@{ ProdCode = '827D'; Model = "HP EliteBook x360 1030 G2"; Man = "HP"}
#@{ ProdCode = '8438'; Model = "HP EliteBook x360 1030 G3"; Man = "HP"}
#@{ ProdCode = '8637'; Model = "HP EliteBook x360 1030 G4"; Man = "HP"}
#@{ ProdCode = '876D'; Model = "HP EliteBook x360 1030 G7"; Man = "HP"}
@{ ProdCode = '857F'; Model = "HP Elite x360 1040 G6"; Man = "HP"}
@{ ProdCode = '896D'; Model = "HP Elite x360 1040 G9"; Man = "HP"}
#@{ ProdCode = '8594'; Model = "HP EliteDesk 800 G5 DM"; Man = "HP"}
@{ ProdCode = '8711'; Model = "HP EliteDesk 800 G6 DM"; Man = "HP"}
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
@{ ProdCode = '8266'; Model = "HP EliteDesk 705 G3 DM"; Man = "HP"}
@{ ProdCode = '8955'; Model = "HP Pro Mini 400 G9 PC"; Man = "HP"}
@{ ProdCode = '8B12'; Model = "HP EliteBook 645 G9"; Man = "HP"}
@{ ProdCode = '8055'; Model = "HP EliteDesk 800 G2 Mini"; Man = "HP"}
@{ ProdCode = '8720'; Model = "HP EliteBook x360 1040 G8"; Man = "HP"}
)


$StageTable = @(
@{ Level = 'Pre-Prod'}
@{ Level = 'Prod'}
)

$PackageTypes = @(
@{ PackageType = 'BIOS'}
@{ PackageType = 'Driver'}
@{ PackageType = 'HPIARepo'}
)




$OverallSummary = @()



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

foreach ($Type in $PackageTypes)
    {

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

    foreach ($Stage in $StageTable) #Prod / Pre-Prod
        {
        Write-Host "Working on Stage: $($Stage.Level)" -ForegroundColor Cyan
        foreach ($Model in $ModelsTable)
            {
            $Prodcode = $Model.ProdCode
            Write-host "Starting Model $($Model.Model) - $Prodcode" -ForegroundColor magenta
            #Not including Model Name into Package, as Platforms can work for several Models, we don't want to duplicate package content
            
            $Name = "$($Type.PackageType) $($Model.Man) $Prodcode - $($Stage.Level)"
            $FolderName = "$($Model.ProdCode)" #Example: 89C3


            #Get all Models supported by Platform (ProdCode) and Reduce the names to fit in the 127 char limit description field
            $ModelSupport = (Get-HPDeviceDetails -Platform $Prodcode).Name
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

            #Source Folders Area 
            Set-Location -Path "C:"

            #BIOS Package Source Folder Location
            if ($Type.PackageType -eq "BIOS"){$SourceSharePackageLocation = "$($SourceShareLocation)\Firmware\Packages\$($Model.Man)\$FolderName\$($Stage.Level)"}
            #HP Example: \\cmsource\osd$\Firmware\Packages\HP\HP Elite x2 1012 G1 - 80FC\Pre-Prod

            #DriverPack Source Folder Location
            if ($Type.PackageType -eq "Driver"){$SourceSharePackageLocation = "$($SourceShareLocation)\Drivers\Packages\Windows Client\$($Model.Man)\$FolderName\Pack\$($Stage.Level)"}
            #HP Example: \\cmsource\osd$\Drivers\Packages\Windows 10\HP\HP EliteBook x360 1030 G2 - 827D\Prod

            #HPIA Repo Source Folder Location
            if ($Type.PackageType -eq "HPIARepo"){$SourceSharePackageLocation = "$($SourceShareLocation)\Drivers\Packages\Windows Client\$($Model.Man)\$FolderName\Repo\$($Stage.Level)"}

            #Create Prod & PreProd along with Online & Offline Sub Folders.
            if (!(Test-Path  $SourceSharePackageLocation)){New-Item -Path $SourceSharePackageLocation -ItemType Directory}
            Else {Write-Host "$SourceSharePackageLocation already exist"}                  




            #Update or Create new CM Package
            Set-Location -Path "$($SiteCode):"
            $PackageCheck = Get-CMPackage -Name $Name -Fast
            if (!($PackageCheck))
                {
                #Create New Package Shell & Distribuite to all DP Groups
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
            else 
                {
                Write-Host " Package $Name already exist, confirming information..." -ForegroundColor Cyan
                $OverallSummary += @{ Name = $Name; Folder = $FolderName ; Status = "Present"; Stage = $Stage.Values; Type = $Type.Values; Model = $Model.Model ; Man = $Model.Man; ProdCode = $Model.ProdCode}
                #Confirms Fields are set to standard info
                }
            #Set Addtional Info:
                if (!($PackageCheck)){$PackageCheck = Get-CMPackage -Name $Name -Fast}
                Set-CMPackage -InputObject $PackageCheck -Manufacturer $Model.Man
                Set-CMPackage -InputObject $PackageCheck -Language $Model.ProdCode
                Set-CMPackage -InputObject $PackageCheck -MifName $Stage.Level
                Set-CMPackage -InputObject $PackageCheck -Path $SourceSharePackageLocation
                if ($PackageCheck.Version -eq $null){Set-CMPackage -InputObject $PackageCheck -Version "0.0.1"}
                if ($Type.PackageType -eq "Driver"){ Set-CMPackage -InputObject $PackageCheck -MifPublisher $OperatingSystemDriversSupport}
                Set-CMPackage -InputObject $PackageCheck -MifFileName $Model.Model
                Set-CMPackage -InputObject $PackageCheck -Description $Description

                if ($SetScope -eq $true){
                    Write-Host  "  Starting Scope Maintenance" -ForegroundColor Cyan
                    #$ConfirmApp = Get-CMApplication -Name $M365.Name -ErrorAction SilentlyContinue
                    $AppScopes = Get-CMObjectSecurityScope -InputObject $PackageCheck 
                    if ($AppScopes.Count -eq 1 -and $AppScopes.CategoryName -eq "$ScopeName")
                        {
                        Write-Host  "   Scope is already set correctly for $Name" -ForegroundColor Yellow
                        } 
                    if ($AppScopes.CategoryName -ccontains "Default")
                        {
                        $DefaultScope = $AppScopes | Where-Object {$_.CategoryName -eq "default"} 
                        if (!($AppScopes.CategoryName -contains "$ScopeName"))
                            {
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
                    foreach ($Scope in $NonCorrectScope)
                        {
                        Write-Host  "   Removing Scope $($Scope.CategoryName) from $Name" -ForegroundColor Green
                        $RemovedAppScopes = Remove-CMObjectSecurityScope -InputObject $PackageCheck -Scope $Scope -Force
                        }
                    }
            #Create Program and Tag for TS - This runs each time as there isn't a way (That I know of) to query if EnableTS is already set, so I just set it each run, no harm done.
            Set-Location -Path "$($SiteCode):"
            if (!($PackageCheck)){$PackageProgram = Get-CMProgram -PackageId $NewPackage.PackageID;$ProgramPackID = $NewPackage.PackageID}
            else{$PackageProgram = Get-CMProgram -PackageId $PackageCheck.PackageID;$ProgramPackID = $PackageCheck.PackageID}
            if ($PackageProgram -eq $null)
                {
                Write-host "  Create New Program" -ForegroundColor Yellow
                $NewProgram = New-CMProgram -PackageId $ProgramPackID -StandardProgramName 'Pre-cache' -CommandLine 'cmd /c' -RunType Hidden -ProgramRunType WhetherOrNotUserIsLoggedOn -ErrorAction SilentlyContinue
                $PackageProgram = Get-CMProgram -PackageId $ProgramPackID
                Write-Host "  Program Name: $($PackageProgram.ProgramName) Created" -ForegroundColor Green
                Set-CMProgram -InputObject $PackageProgram -EnableTaskSequence $true -StandardProgram
                Write-Host "  Set Program $($PackageProgram.ProgramName) to Enable TS" -ForegroundColor Green
                }
            else
                {
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
            if (!($PackageConfirm.Icon)){
                Set-CMPackage -InputObject $PackageConfirm -IconLocationFile $HPICONPath
            }

            if ($Model.Man -eq "HP"){Write-Host "  Finished: $($PackageConfirm.Name) | Manufacturer: $($PackageConfirm.Manufacturer) | ProdCode: $($PackageConfirm.Language)" -ForegroundColor Green}
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

$PlatformInfoFilePath = "$($SourceShareLocation)\Drivers\Packages\Windows Client\$($Model.Man)\PlatformInfo.txt"
if (Test-Path -Path $PlatformInfoFilePath){Remove-Item -Path $PlatformInfoFilePath -Force}

Foreach ($Platform in $ModelsTable.ProdCode){
    Get-HPDeviceDetails -Platform $Platform | Select-Object -Property "SystemID", "Name"  | Out-File -FilePath $PlatformInfoFilePath -Append
}
#Copy to BIOS Area
Copy-Item -Path $PlatformInfoFilePath -Destination "$($SourceShareLocation)\Firmware\Packages\$($Model.Man)\PlatformInfo.txt"


#This is just summary info, not actually used for anything other than the person who ran the script.
$AlreadyInSystem = $OverallSummary | Where-Object {$_.Status -eq "Present" -and $_.Type -eq "BIOS"-and $_.Stage -eq "Prod"}
$AddedToSystem = $OverallSummary | Where-Object {$_.Status -eq "Added" -and $_.Type -eq "BIOS"-and $_.Stage -eq "Prod"}

#Note, I think the logic for this might be wonky... but it's really not important and I haven't looked into it more.
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
    
