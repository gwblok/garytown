<# GARYTOWN.COM

This script will loop through the Models you put in your model table, creating packages for them
Packages: Driver Pack Package & Offline Repo Package in CM.  These are emtpy shells to be populated.

Update the script with your environment details

#>

#Load CM PowerShell
$SiteCode = "MCM"
$SetScope = $true #If you plan to scope the packages
$ScopeName = "Dev" #This is the scope you're using to set the packages to.
$User = $env:USERNAME

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
$CMPackageLocation = "$SourceShareLocation\Drivers\CMPackages\HP"
$HPIASourceShareRootLocation = "$($CMPackageLocation)\HP Image Assistant Tool"
$HPIACMPackageName = "HP Image Assistant Tool"


Set-Location -Path "C:\"
if (!(Test-Path -Path $CMPackageLocation)){
    New-Item -Path $CMPackageLocation -ItemType Directory -Force | Out-Null
}
if (!(Test-Path -Path $HPIASourceShareRootLocation)){
    New-Item -Path $HPIASourceShareRootLocation -ItemType Directory -Force | Out-Null
}


#Download HP Icon

$HPIconURL = 'https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/HPIA-BlogSeries-2024/HP_Logo_clear.png'
$HPICONPath = "$($CMPackageLocation)\HPICON.png"
if (!(Test-Path $HPICONPath)){
    Invoke-WebRequest -UseBasicParsing -Uri $HPIconURL -OutFile $HPICONPath
}

Set-Location -Path "$($SiteCode):"
$ModelsTable= @(


@{ ProdCode = '83B2'; Model = "HP EliteBook 840 G5"; Man = "HP"}
@{ ProdCode = '8AB8'; Model = "HP EliteBook 840 G8"; Man = "HP"}
@{ ProdCode = '880D'; Model = "HP EliteBook 840 G8"; Man = "HP"}
@{ ProdCode = '8B41'; Model = "HP EliteBook 840 G10"; Man = "HP"}
@{ ProdCode = '857F'; Model = "HP Elite x360 1040 G6"; Man = "HP"}
@{ ProdCode = '896D'; Model = "HP Elite x360 1040 G9"; Man = "HP"}
@{ ProdCode = '8711'; Model = "HP EliteDesk 800 G6 DM"; Man = "HP"}
@{ ProdCode = '8952'; Model = "HP Elite Mini 600 G9 DM"; Man = "HP"}
@{ ProdCode = '8955'; Model = "HP Pro Mini 400 G9 PC"; Man = "HP"}
@{ ProdCode = '8B12'; Model = "HP EliteBook 645 G9"; Man = "HP"}
@{ ProdCode = '8055'; Model = "HP EliteDesk 800 G2 Mini"; Man = "HP"}
@{ ProdCode = '8720'; Model = "HP EliteBook x360 1040 G8"; Man = "HP"}
@{ ProdCode = '83F3'; Model = "HP ProDesk 400 G4"; Man = "HP"}
@{ ProdCode = '859C'; Model = "HP ProDesk 400 G5"; Man = "HP"}
)


$StageTable = @(
@{ Level = 'Dev'}
@{ Level = 'Prod'}
)

$PackageTypes = @(
@{ PackageType = 'DriverPack'}
@{ PackageType = 'OfflineRepo'}
)



#Create HPIA Package (If it doesn't exist)
Set-Location -Path "C:" 
if (!(Test-Path $HPIASourceShareRootLocation)){New-Item -Path $HPIASourceShareRootLocation -ItemType Directory -Force | Out-Null}
Set-Location -Path "$($SiteCode):"
$Test = Get-CMPackage -Name $HPIACMPackageName -Fast
if (!($Test)){
    
    Set-Location -Path "C:" 
    if (!(Test-Path -Path "$HPIASourceShareRootLocation")){New-Item -Path "$HPIASourceShareRootLocation" -ItemType Directory -Force | Out-Null}
    Set-Location -Path "$($SiteCode):"
    $NewPackage = New-CMPackage -Name $HPIACMPackageName
    Set-CMPackage -InputObject $NewPackage -Path "$HPIASourceShareRootLocation"
    Set-CMPackage -InputObject $NewPackage -IconLocationFile $HPICONPath
    Set-CMPackage -InputObject $NewPackage -Description 'https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html'
    Set-CMPackage -InputObject $NewPackage -Manufacturer 'HP'
    
    $ReadmeContents = "Temporary, overwritten with more details below, just needed so there is content to distribute"
    Set-Location -Path "c:"
    $ReadmeContents | Out-File -FilePath "$HPIASourceShareRootLocation\temp\Readme.txt"
    $LatestVersion = (Get-HPImageAssistantUpdateInfo).version
    $TempPath = "c:\windows\temp\HPIA\$LatestVersion"
    Install-HPImageAssistant -Extract -DestinationPath $TempPath
    Copy-Item -Path $TempPath\* -Destination $HPIASourceShareRootLocation -Recurse -Force
    Set-Location -Path "$($SiteCode):"
    Set-CMPackage -InputObject $NewPackage -Version $LatestVersion
    
    foreach ($Group in $DPGroups) #Distribute Content
        {
        Write-host "  Starting Distribution to DP Group $Group" -ForegroundColor Green
        Start-CMContentDistribution -InputObject $NewPackage -DistributionPointGroupName $Group
    }
}
Set-Location -Path "C:" 

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

    foreach ($Stage in $StageTable) #Prod / Dev
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

            #Source Folders Area 
            Set-Location -Path "C:"


            #DriverPack Source Folder Location
            if ($Type.PackageType -eq "DriverPack"){$SourceSharePackageLocation = "$CMPackageLocation\$FolderName\Pack\$($Stage.Level)"}
            #HP Example: \\cmsource\osd$\Drivers\Packages\Windows 10\HP\HP EliteBook x360 1030 G2 - 827D\Prod

            #HPIA Repo Source Folder Location
            if ($Type.PackageType -eq "OfflineRepo"){$SourceSharePackageLocation = "$CMPackageLocation\$FolderName\Repo\$($Stage.Level)"}

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
                #Confirms Fields are set to standard info
                }
            #Set Addtional Info:
                if (!($PackageCheck)){$PackageCheck = Get-CMPackage -Name $Name -Fast}
                Set-CMPackage -InputObject $PackageCheck -Manufacturer $Model.Man
                Set-CMPackage -InputObject $PackageCheck -Language $Model.ProdCode
                Set-CMPackage -InputObject $PackageCheck -MifName $Stage.Level
                Set-CMPackage -InputObject $PackageCheck -Path $SourceSharePackageLocation
                if ($PackageCheck.Version -eq $null){Set-CMPackage -InputObject $PackageCheck -Version "0.0.1"}
                #if ($Type.PackageType -eq "Driver"){ Set-CMPackage -InputObject $PackageCheck -MifPublisher $OperatingSystemDriversSupport}
                Set-CMPackage -InputObject $PackageCheck -MifFileName $Model.Model
                Set-CMPackage -InputObject $PackageCheck -Description $Description
                Set-CMPackage -InputObject $PackageCheck -MifPublisher $User

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

