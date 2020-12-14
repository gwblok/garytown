<# 
Version 2020.04.08 - @GWBLOK
Creates Packages for the Models you specify
HP needs Product Codes
Dell needs JSONModel, because if you use another script to download things, you'll find that they have different names in their JSON/XML than they use as their Model Name.

Info provided in the table is used to create the Packages and populate differnet fields which the other scripts need to pull down BIOS & Drivers.
StageTable... if you don't do "Piloting, or Pre-Prod Testing" of Packages using a different source, then you can remove this and write the script... or just comment out "Pre-Prod"

BIOS Download Scripts will be available here on my github.. eventually, likewise for Drivers.

2020.07.08 - Updated Model List - Added Intel & Nexcom
2020.12.13 - Switched Dells to use SystemTypeID, as it had better lock with the XML (Enterprise Catalog) they provide.

#> 


$OperatingSystemDriversSupport = "Windows 10"  #Used to Tag OS Drivers are for (Because we use similar process for Server OS too)
#$adgroup = "Device Drivers Administrators UAT" #This Group get Full Access on the Import Folder, which I've also disabled, but left for reference.  I doubt anyone will need this unless they want to setup an automated peer-review type process for driver import.

#Load CM PowerShell
$SiteCode = "PS2"

Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

$DPGroups = (Get-CMDistributionPointGroup).Name #Currently this is setup to Distribute to ALL DP Groups
$SourceShareLocation = "\\src\src$"


$ModelsTable= @(

@{ ProdCode = '80FC'; Model = "HP Elite x2 1012 G1"; Man = "HP"}
@{ ProdCode = '82CA'; Model = "HP Elite x2 1012 G2"; Man = "HP"}
@{ ProdCode = '85B9'; Model = "HP Elite x2 G4"; Man = "HP"}
@{ ProdCode = '80FB'; Model = "HP EliteBook 1030 G1"; Man = "HP"}
#@{ ProdCode = '80FA'; Model = "EliteBook 1040 G3"; Man = "HP"}
@{ ProdCode = '807C'; Model = "HP EliteBook 820 G3"; Man = "HP"}
@{ ProdCode = '8079'; Model = "HP EliteBook 840 G3"; Man = "HP"}
@{ ProdCode = '827D'; Model = "HP EliteBook x360 1030 G2"; Man = "HP"}
@{ ProdCode = '8438'; Model = "HP EliteBook x360 1030 G3"; Man = "HP"}
@{ ProdCode = '8637'; Model = "HP EliteBook x360 1030 G4"; Man = "HP"}
@{ ProdCode = '876D'; Model = "HP EliteBook x360 1030 G7"; Man = "HP"}
@{ ProdCode = '8594'; Model = "HP EliteDesk 800 G5 DM"; Man = "HP"}
@{ ProdCode = '83D2'; Model = "HP ProBook 640 G4"; Man = "HP"}
@{ ProdCode = '856D'; Model = "HP ProBook 640 G5"; Man = "HP"}
@{ ProdCode = '8730'; Model = "HP ProBook 445 G7"; Man = "HP"}
@{ ProdCode = '8062'; Model = "HP ProDesk 400 G3 SFF"; Man = "HP"}
@{ ProdCode = '82A2'; Model = "HP ProDesk 400 G4 SFF"; Man = "HP"}
@{ ProdCode = '83F2'; Model = "HP ProDesk 400 G5 SFF"; Man = "HP"}
@{ ProdCode = '859B'; Model = "HP ProDesk 400 G6 SFF"; Man = "HP"}
@{ ProdCode = '21D0'; Model = "HP ProDesk 600 G1 DM"; Man = "HP"}
@{ ProdCode = '8169'; Model = "HP ProDesk 600 G2 DM"; Man = "HP"}
@{ ProdCode = '805D'; Model = "HP ProDesk 600 G2 SFF"; Man = "HP"}
@{ ProdCode = '8053'; Model = "HP ProDesk 600 G2 SFF"; Man = "HP"}
@{ ProdCode = '829E'; Model = "HP ProDesk 600 G3 DM"; Man = "HP"}
@{ ProdCode = '82B4'; Model = "HP ProDesk 600 G3 SFF"; Man = "HP"}
@{ ProdCode = '83EF'; Model = "HP ProDesk 600 G4 DM"; Man = "HP"}
@{ ProdCode = '8598'; Model = "HP ProDesk 600 G5 DM"; Man = "HP"}
@{ ProdCode = '8597'; Model = "HP ProDesk 600 G5 SFF"; Man = "HP"}
@{ ProdCode = '8715'; Model = "HP ProDesk 600 G6 DM"; Man = "HP"}
@{ ProdCode = '8714'; Model = "HP ProDesk 600 G6 SFF"; Man = "HP"}
@{ ProdCode = '81C6'; Model = "HP Z6 G4 Workstation"; Man = "HP"}
@{ ProdCode = '212A'; Model = "HP Z640 Workstation"; Man = "HP"}
@{ ProdCode = '80D6'; Model = "HP ZBook 17 G3"; Man = "HP"}
@{ ProdCode = '842D'; Model = "HP ZBook 17 G5"; Man = "HP"}
@{ ProdCode = '860C'; Model = "HP ZBook 17 G6"; Man = "HP"}
@{ ProdCode = '869D'; Model = "HP ProBook 440 G7"; Man = "HP"}
@{ ProdCode = '8730'; Model = "HP ProBook 445 G7"; Man = "HP"}
<# Old JSON Model
@{JSONModel = "Latitude 5290"; Model = "Latitude 5290"; Man = "Dell"}
@{JSONModel = "Latitude 5300"; Model = "Latitude 5300"; Man = "Dell"}
@{JSONModel = "Latitude 5400";Model = "Latitude 5400"; Man = "Dell"}
@{JSONModel = "Latitude 5490";Model = "Latitude 5490"; Man = "Dell"}
@{JSONModel = "Latitude 5501";Model = "Latitude 5501"; Man = "Dell"}
@{JSONModel = "Latitude 5580";Model = "Latitude 5580"; Man = "Dell"}
@{JSONModel = "Latitude 5590";Model = "Latitude 5590"; Man = "Dell"}
@{JSONModel = "Latitude 7275";Model = "Latitude 7275"; Man = "Dell"}
@{JSONModel = "Latitude 7280";Model = "Latitude 7280"; Man = "Dell"}
@{JSONModel = "Latitude 7480";Model = "Latitude 7480"; Man = "Dell"}
@{JSONModel = "Latitude E5570";Model = "Latitude E5570"; Man = "Dell"}
@{JSONModel = "Latitude E7250_7250";Model = "Latitude E7250"; Man = "Dell"}
@{JSONModel = "Latitude E7270";Model = "Latitude E7270"; Man = "Dell"}
@{JSONModel = "Latitude E7450";Model = "Latitude E7450"; Man = "Dell"}
@{JSONModel = "Latitude E7470";Model = "Latitude E7470"; Man = "Dell"}
#@{JSONModel = "OptiPlex 3040";Model = "OptiPlex 3040"; Man = "Dell"} Not supported on 1909
@{JSONModel = "OptiPlex 5050";Model = "OptiPlex 5050"; Man = "Dell"}
@{JSONModel = "OptiPlex 5060";Model = "OptiPlex 5060"; Man = "Dell"}
@{JSONModel = "OptiPlex 5070";Model = "OptiPlex 5070"; Man = "Dell"}
@{JSONModel = "OptiPlex 5080";Model = "OptiPlex 5080"; Man = "Dell"}
#@{JSONModel = "OptiPlex 7010";Model = "OptiPlex 7010"; Man = "Dell"} Not supported on 1909
@{JSONModel = "OptiPlex 7040";Model = "OptiPlex 7040"; Man = "Dell"}
@{JSONModel = "OptiPlex 7050";Model = "OptiPlex 7050"; Man = "Dell"}
#@{JSONModel = "OptiPlex 9020";Model = "OptiPlex 9020"; Man = "Dell"} Not supported on 1909
#@{JSONModel = "Tablet 7140";Model = "Venue 11 Pro 7140"; Man = "Dell"} Not supported on 1909
@{JSONModel = "XPS Notebook 9365";Model = "XPS 13 9365"; Man = "Dell"}
#JSON Model based of Dell XML Data in ftp://ftp.dell.com/catalog/DellSDPCatalogPC.cab
@{JSONModel = "Latitude 5310"; Model = "Latitude 5310"; Man = "Dell"}
@{JSONModel = "Latitude 5410"; Model = "Latitude 5410"; Man = "Dell"}
@{JSONModel = "Latitude 5511"; Model = "Latitude 5511"; Man = "Dell"}
#>


@{SystemTypeID = "2069"; Model = "Latitude 5290"; Man = "Dell"}
@{SystemTypeID = "2231"; Model = "Latitude 5300"; Man = "Dell"}
@{SystemTypeID = "2232";Model = "Latitude 5400"; Man = "Dell"}
@{SystemTypeID = "2070";Model = "Latitude 5490"; Man = "Dell"}
@{SystemTypeID = "2329";Model = "Latitude 5501"; Man = "Dell"}
@{SystemTypeID = "2001";Model = "Latitude 5580"; Man = "Dell"}
@{SystemTypeID = "2071";Model = "Latitude 5590"; Man = "Dell"}
@{SystemTypeID = "1750";Model = "Latitude 7275"; Man = "Dell"}
@{SystemTypeID = "1951";Model = "Latitude 7280"; Man = "Dell"}
@{SystemTypeID = "1952";Model = "Latitude 7480"; Man = "Dell"}
@{SystemTypeID = "1759";Model = "Latitude E5570"; Man = "Dell"}
@{SystemTypeID = "1581";Model = "Latitude E7250"; Man = "Dell"}
@{SystemTypeID = "1755";Model = "Latitude E7270"; Man = "Dell"}
@{SystemTypeID = "1582";Model = "Latitude E7450"; Man = "Dell"}
@{SystemTypeID = "1756";Model = "Latitude E7470"; Man = "Dell"}
@{SystemTypeID = "1954";Model = "OptiPlex 5050"; Man = "Dell"}
@{SystemTypeID = "2139";Model = "OptiPlex 5060"; Man = "Dell"}
@{SystemTypeID = "2351";Model = "OptiPlex 5070"; Man = "Dell"}
@{SystemTypeID = "2470";Model = "OptiPlex 5080"; Man = "Dell"}
@{SystemTypeID = "1721";Model = "OptiPlex 7040"; Man = "Dell"}
@{SystemTypeID = "1953";Model = "OptiPlex 7050"; Man = "Dell"}
@{SystemTypeID = "1914";Model = "XPS 13 9365"; Man = "Dell"}
@{SystemTypeID = "2463"; Model = "Latitude 5310"; Man = "Dell"}
@{SystemTypeID = "2464"; Model = "Latitude 5410"; Man = "Dell"}
@{SystemTypeID = "2497"; Model = "Latitude 5511"; Man = "Dell"}


@{ ProdCode = 'NUC7i5DNB'; Model = "NUC7i5DN"; Man = "Intel"}
@{ ProdCode = 'NUC5i5MYBE'; Model = "NUC5i5"; Man = "Intel"}

@{ ProdCode = 'NDiSM535'; Model = "NDiS"; Man = "Nexcom"}

)
#>

<#
$ModelsTable= @(

@{ ProdCode = '80FA'; Model = "EliteBook 1040 G3"; Man = "HP"}
#@{ ProdCode = '860C'; Model = "HP ZBook 17 G6"; Man = "HP"}
@{JSONModel = "OptiPlex 3040";Model = "OptiPlex 3040"; Man = "Dell"}
#@{JSONModel = "Latitude 5290"; Model = "Latitude 5290"; Man = "Dell"}
)
#>

$StageTable = @(
@{ Level = 'Pre-Prod'}
@{ Level = 'Prod'}
)

$PackageTypes = @(
@{ PackageType = 'BIOS'}
@{ PackageType = 'Driver'}
)

$OverallSummary = @()

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

    foreach ($Stage in $StageTable)
        {
        Write-Host "Working on Stage: $($Stage.Level)" -ForegroundColor Cyan
        foreach ($Model in $ModelsTable)
            {
            Write-host "Starting Model $($Model.Model)" -ForegroundColor magenta
            if ($Model.Man -eq "HP")
                {
                $Name = "$($Type.PackageType) $($Model.Model) - $($Model.ProdCode) - $($Stage.Level)"
                $FolderName = "$($Model.Model) - $($Model.ProdCode)" #Example: HP Elite x2 1012 G1 - 80FC
                }
            elseif ($Model.Man -eq "Dell")
                {
                $Name = "$($Type.PackageType) $($Model.Man) $($Model.Model) - $($Stage.Level)"
                $FolderName = "$($Model.Model)" #Example: Latitude 5300
                }
            else
                {
                $Name = "$($Type.PackageType) $($Model.Man) $($Model.Model) - $($Stage.Level)"
                $FolderName = "$($Model.Model) - $($Model.ProdCode)" #Example: NUC7i5DN - NUC7i5DNB
                }
        
            #Source Folders Area 
            Set-Location -Path "C:"
            if ($Type.PackageType -eq "BIOS"){$SourceSharePackageLocation = "$($SourceShareLocation)\Firmware\Packages\$($Model.Man)\$FolderName\$($Stage.Level)"}
            #HP Example: \\cmsource\osd$\Firmware\Packages\HP\HP Elite x2 1012 G1 - 80FC\Pre-Prod
            #Dell Example: \\cmsource\osd$\Firmware\Packages\Dell\OptiPlex 7050\Pre-Prod
            
            if ($Type.PackageType -eq "Driver"){$SourceSharePackageLocation = "$($SourceShareLocation)\Drivers\Packages\Windows 10\$($Model.Man)\$FolderName\$($Stage.Level)"}
            #HP Example: \\cmsource\osd$\Drivers\Packages\Windows 10\HP\HP EliteBook x360 1030 G2 - 827D\Prod
            #Dell Example: \\cmsource\osd$\Drivers\Packages\Windows 10\Dell\Latitude 5300\Prod
            #Intel Example: \\cmsource\osd$\Drivers\Packages\Windows 10\Intel\NUC7i5DN - NUC7i5DNB\Pre-Prod
            #Nexcom Example: \\cmsource\osd$\Drivers\Packages\Windows 10\Nexcom\NDiS - NDiSM535\Pre-Prod

            #Create Prod & PreProd along with Online & Offline Sub Folders.
            if (!(Test-Path  $SourceSharePackageLocation)){New-Item -Path $SourceSharePackageLocation -ItemType Directory}
            Else {Write-Host "$SourceSharePackageLocation already exist"}
            

            #Update or Create new CM Package
            Set-Location -Path "$($SiteCode):"
            $PackageCheck = Get-CMPackage -Name $Name -Fast
            if (!($PackageCheck))
                {
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
            else 
                {
                Write-Host " Package $Name already exist, confirming information..." -ForegroundColor Cyan
                $OverallSummary += @{ Name = $Name; Folder = $FolderName ; Status = "Present"; Stage = $Stage.Values; Type = $Type.Values; Model = $Model.Model ; Man = $Model.Man; ProdCode = $Model.ProdCode}
                #Confirms Fields are set to standard info
                }
            #Set Addtional Info:
                if (!($PackageCheck)){$PackageCheck = Get-CMPackage -Name $Name -Fast}
                Set-CMPackage -InputObject $PackageCheck -Manufacturer $Model.Man
                if ($Model.Man -eq "Dell"){Set-CMPackage -InputObject $PackageCheck -Language $Model.SystemTypeID}
                else {Set-CMPackage -InputObject $PackageCheck -Language $Model.ProdCode}
                Set-CMPackage -InputObject $PackageCheck -MifName $Stage.Level
                Set-CMPackage -InputObject $PackageCheck -Path $SourceSharePackageLocation
                if ($PackageCheck.Version -eq $null){Set-CMPackage -InputObject $PackageCheck -Version "0.0.1"}
                if ($Type.PackageType -eq "Driver"){ Set-CMPackage -InputObject $PackageCheck -MifPublisher $OperatingSystemDriversSupport}
                #if ($Model.Man -eq "HP"){Set-CMPackage -InputObject $PackageCheck -MifFileName $Model.Model}
                #elseif ($Model.Man -eq "Dell"){Set-CMPackage -InputObject $PackageCheck -MifFileName $Model.JSONModel}
                #else {Set-CMPackage -InputObject $PackageCheck -MifFileName $Model.Model}
                Set-CMPackage -InputObject $PackageCheck -MifFileName $Model.Model

                Write-Host  "  Starting Scope Maintenance" -ForegroundColor Cyan
                #$ConfirmApp = Get-CMApplication -Name $M365.Name -ErrorAction SilentlyContinue
                $AppScopes = Get-CMObjectSecurityScope -InputObject $PackageCheck 
                if ($AppScopes.Count -eq 1 -and $AppScopes.CategoryName -eq "SDE")
                    {
                    Write-Host  "   Scope is already set correctly for $Name" -ForegroundColor Yellow
                    } 
                if ($AppScopes.CategoryName -ccontains "Default")
                    {
                    $DefaultScope = $AppScopes | Where-Object {$_.CategoryName -eq "default"} 
                    if (!($AppScopes.CategoryName -contains "Recast"))
                        {
                        $RecastScope = Get-CMSecurityScope | Where-Object {$_.CategoryName -eq "Recast"}
                        $AddRecastScope = Add-CMObjectSecurityScope -InputObject $PackageCheck -Scope $RecastScope
                        $PackageCheck = Get-CMPackage -Name $Name -Fast
                        Write-Host  "   Adding Scope $($RecastScope.CategoryName) to $Name" -ForegroundColor Green
                        }
                    $RemovedDefaultAppScope = Remove-CMObjectSecurityScope -InputObject $PackageCheck -Scope $DefaultScope -Force
                    $PackageCheck = Get-CMPackage -Name $Name -Fast
                    Write-Host  "   Removing Default Scope from $Name" -ForegroundColor Green
                    } 
                $NonRecastScope = $AppScopes | Where-Object {$_.CategoryName -ne "Recast" -and $_.CategoryDescription -notmatch "A built-in security scope"} 
                foreach ($Scope in $NonRecastScope)
                    {
                    Write-Host  "   Removing Scope $($Scope.CategoryName) from $Name" -ForegroundColor Green
                    $RemovedAppScopes = Remove-CMObjectSecurityScope -InputObject $PackageCheck -Scope $Scope -Force
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
        
            if ($Model.Man -eq "HP"){Write-Host "  Finished: $($PackageConfirm.Name) | Manufacturer: $($PackageConfirm.Manufacturer) | ProdCode: $($PackageConfirm.Language)" -ForegroundColor Green}
            elseif ($Model.Man -eq "Dell"){Write-Host "  Finished: $($PackageConfirm.Name) | Manufacturer: $($PackageConfirm.Manufacturer)" -ForegroundColor Green}
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
