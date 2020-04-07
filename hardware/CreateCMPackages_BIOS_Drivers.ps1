$OperatingSystemDriversSupport = "Windows 10 x64"  #Used to Tag OS Drivers are for (Because we use similar process for Server OS too)
#$adgroup = "Device Drivers Administrators UAT" #This Group get Full Access on the Import Folder, which I've also disabled, but left for reference.  I doubt anyone will need this unless they want to setup an automated peer-review type process for driver import.

#Load CM PowerShell
$SiteCode = "PS2"

Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"
$DPGroups = (Get-CMDistributionPointGroup).Name #Currently this is setup to Distribute to ALL DP Groups
$SourceShareLocation = "\\src\src$\OSD"

$ModelsTable= @(

@{ ProdCode = '80FC'; Model = "Elite x2 1012 G1"; Man = "HP"}
@{ ProdCode = '82CA'; Model = "Elite x2 1012 G2"; Man = "HP"}
@{ ProdCode = '80FB'; Model = "EliteBook 1030 G1"; Man = "HP"}
@{ ProdCode = '80FA'; Model = "EliteBook 1040 G3"; Man = "HP"}
@{ ProdCode = '807C'; Model = "EliteBook 820 G3"; Man = "HP"}
@{ ProdCode = '8079'; Model = "EliteBook 840 G3"; Man = "HP"}
@{ ProdCode = '827D'; Model = "EliteBook x360 1030 G2"; Man = "HP"}
@{ ProdCode = '8438'; Model = "EliteBook x360 1030 G3"; Man = "HP"}
@{ ProdCode = '8594'; Model = "EliteDesk 800 G5 DM"; Man = "HP"}
@{ ProdCode = '83D2'; Model = "ProBook 640 G4"; Man = "HP"}
@{ ProdCode = '856D'; Model = "ProBook 640 G5"; Man = "HP"}
@{ ProdCode = '8062'; Model = "ProDesk 400 G3 SFF"; Man = "HP"}
@{ ProdCode = '82A2'; Model = "ProDesk 400 G4 SFF"; Man = "HP"}
@{ ProdCode = '83F2'; Model = "ProDesk 400 G5 SFF"; Man = "HP"}
@{ ProdCode = '859B'; Model = "ProDesk 400 G6 SFF"; Man = "HP"}
@{ ProdCode = '21D0'; Model = "ProDesk 600 G1 DM"; Man = "HP"}
@{ ProdCode = '8169'; Model = "ProDesk 600 G2 DM"; Man = "HP"}
@{ ProdCode = '805D'; Model = "ProDesk 600 G2 SFF"; Man = "HP"}
@{ ProdCode = '8053'; Model = "ProDesk 600 G2 SFF"; Man = "HP"}
@{ ProdCode = '829E'; Model = "ProDesk 600 G3 DM"; Man = "HP"}
@{ ProdCode = '82B4'; Model = "ProDesk 600 G3 SFF"; Man = "HP"}
@{ ProdCode = '83EF'; Model = "ProDesk 600 G4 DM"; Man = "HP"}
@{ ProdCode = '8598'; Model = "ProDesk 600 G5 DM"; Man = "HP"}
@{ ProdCode = '8597'; Model = "ProDesk 600 G5 SFF"; Man = "HP"}
@{ ProdCode = '81C6'; Model = "Z6 G4 Workstation"; Man = "HP"}
@{ ProdCode = '212A'; Model = "Z640 Workstation"; Man = "HP"}
@{ ProdCode = '80D6'; Model = "ZBook 17 G3"; Man = "HP"}
@{ ProdCode = '842D'; Model = "ZBook 17 G5"; Man = "HP"}
@{ ProdCode = '860C'; Model = "ZBook 17 G6"; Man = "HP"}
@{Model = "Latitude 5290"; Man = "Dell"}
@{Model = "Latitude 5300"; Man = "Dell"}
@{Model = "Latitude 5400"; Man = "Dell"}
@{Model = "Latitude 5490"; Man = "Dell"}
@{Model = "Latitude 5501"; Man = "Dell"}
@{Model = "Latitude 5580"; Man = "Dell"}
@{Model = "Latitude 5590"; Man = "Dell"}
@{Model = "Latitude 7275"; Man = "Dell"}
@{Model = "Latitude 7280"; Man = "Dell"}
@{Model = "Latitude 7480"; Man = "Dell"}
@{Model = "Latitude E5570"; Man = "Dell"}
@{Model = "Latitude E7250"; Man = "Dell"}
@{Model = "Latitude E7270"; Man = "Dell"}
@{Model = "Latitude E7450"; Man = "Dell"}
@{Model = "Latitude E7470"; Man = "Dell"}
@{Model = "OptiPlex 3040"; Man = "Dell"}
@{Model = "OptiPlex 5050"; Man = "Dell"}
@{Model = "OptiPlex 5060"; Man = "Dell"}
@{Model = "OptiPlex 5070"; Man = "Dell"}
@{Model = "OptiPlex 7010"; Man = "Dell"}
@{Model = "OptiPlex 7040"; Man = "Dell"}
@{Model = "OptiPlex 7050"; Man = "Dell"}
@{Model = "OptiPlex 9020"; Man = "Dell"}
@{Model = "Venue 11 Pro 7140"; Man = "Dell"}
@{Model = "XPS 13 9365"; Man = "Dell"}

)


$StageTable = @(
@{ Level = 'Pre-Prod'}
@{ Level = 'Prod'}
)

$PackageTypes = @(
@{ PackageType = 'BIOS'}
@{ PackageType = 'Driver'}
)



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
            if ($Model.Man -eq "HP"){$Name = "$($Type.PackageType) $($Model.Man) $($Model.Model) - $($Model.ProdCode) - $($Stage.Level)"}
            if ($Model.Man -eq "Dell"){$Name = "$($Type.PackageType) $($Model.Man) $($Model.Model) - $($Stage.Level)"}
        
            #Source Folders Area
            Set-Location -Path "C:"
            if ($Type.PackageType -eq "BIOS"){$SourceSharePackageLocation = "$($SourceShareLocation)\Firmware\Packages\$($Model.Man)\$($Model.Model)\$($Stage.Level)"}
            if ($Type.PackageType -eq "Driver"){$SourceSharePackageLocation = "$($SourceShareLocation)\Drivers\Packages\Windows10x64\$($Model.Man)\$($Model.Model)\$($Stage.Level)"}
        

            if (!(Test-Path  $SourceSharePackageLocation)){New-Item -Path $SourceSharePackageLocation -ItemType Directory}
            Else {Write-Host "$SourceSharePackageLocation already exist"}

            <# Creates Import Folder used with our automation... probably not helpful for anyone else
            if ($SiteCode -eq "PS5")
                {
                $SourceShareImportLocation = "$($SourceShareLocation)\$($Model.Man)\$($Model.Model)\Import"
                if (!(Test-Path  $SourceShareImportLocation))
                    {
                    New-Item -Path $SourceShareImportLocation -ItemType Directory
                    #Set Permission on Import Folder.... make sure you elevate first
                    cmd /c icacls "$SourceShareImportLocation" /grant "$($adgroup):(CI)F"
                    }
                Else {Write-Host "$SourceShareImportLocation already exist"}
                }
            #>

            #Update or Create new CM Package
            Set-Location -Path "$($SiteCode):"
            $PackageCheck = Get-CMPackage -Name $Name -Fast
            if (!($PackageCheck))
                {
                #Create New Package Shell
                Write-Host " Starting on Package $Name" -ForegroundColor gray
                $NewPackage = New-CMPackage -Name $Name 
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
                }
            else 
                {
                Write-Host " Package $Name already exist, confirming information..." -ForegroundColor Cyan
                #Confirms Fields are set to standard info
                }
            #Set Addtional Info:
                if (!($PackageCheck)){$PackageCheck = Get-CMPackage -Name $Name -Fast}
                Set-CMPackage -InputObject $PackageCheck -Manufacturer $Model.Man
                if ($Model.Man -eq "HP"){Set-CMPackage -InputObject $PackageCheck -Language $Model.ProdCode}
                Set-CMPackage -InputObject $PackageCheck -MifName $Stage.Level
                Set-CMPackage -InputObject $PackageCheck -Path $SourceSharePackageLocation
                if ($Type.PackageType -eq "Driver"){ Set-CMPackage -InputObject $PackageCheck -MifPublisher $OperatingSystemDriversSupport}
                Set-CMPackage -InputObject $PackageCheck -MifFileName $Model.Model
        
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
            if ($Model.Man -eq "Dell"){Write-Host "  Finished: $($PackageConfirm.Name) | Manufacturer: $($PackageConfirm.Manufacturer)" -ForegroundColor Green}
        
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
