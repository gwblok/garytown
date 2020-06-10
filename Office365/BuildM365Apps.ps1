#Builds the Apps in CM - Middle of Development

$SC_Description = "***********************************************************************************
Save your work and close any Office applications before running this install
***********************************************************************************
This will automatically reinstall Visio, Project, or Access if previously installed."

$PreFix = "ACME "
$Stage = "Prod"
$ContentSourceParent = "\\src\apps$\SDE\Microsoft\Microsoft 365"

$ContentAppSourceContent = "Microsoft 365 Content"
$ContentAppSourceInstallers = "Microsoft 365 Installers"
$ContentAppSourceIcons = "Microsoft 365 Icons"
$CompanyName = 'Wells Fargo'
$O365Cache = "C:\ProgramData\O365_Cache"



#Load CM PowerShell
$SiteCode = "MEM"
$ProviderMachineName = "SCCMC1.ent.wfb.bank.corp" # SMS Provider machine name
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

#Update Channel Info
$CurrentPreviewChannel = "http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be"
$CurrentChannel = "http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60"
$MonthlyEnterpriseChannel = "http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6"
$SemiAnnualPreviewChannel = "http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf"
$SemiAnnualChannel = "http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114"


$ContentAppSourceName = "Microsoft 365 Content"
$ContentAppSourceNameFrench = "Microsoft 365 French Content"
$ContentAppSourceNameChina = "Microsoft 365 China Content"
$ContentAppSourceNameTaiwan = "Microsoft 365 Taiwan Content"
$ContentAppSourceNameGermany = "Microsoft 365 Germany Content"
$ContentAppSourceNameItaly = "Microsoft 365 Italy Content"

#App Names (Used for Names & AppDT Names)
$CurrentPreviewApp = "Microsoft 365 Office - Current Preview Channel"
$CurrentApp = "Microsoft 365 Office - Current Channel"
$MonthlyEnterpriseApp = "Microsoft 365 Office - Monthly Enterprise Channel"
$SemiAnnualPreviewApp = "Microsoft 365 Office - Semi Annual Enterprise Channel Preview"
$SemiAnnualApp = "Microsoft 365 Office - Semi Annual Enterprise Channel"
#Addons
$AccessApp = "Microsoft 365 Access"
$VisioProApp = "Microsoft 365 Visio Professional 2019"
$VisioStdApp = "Microsoft 365 Visio Standard 2019"
$ProjectProApp = "Microsoft 365 Project Professional 2019"
$ProjectStdApp = "Microsoft 365 Project Standard 2019"


$LanguageTable= @(
@{ Language = 'French - France'; Number = "1036"; Code = "fr-fr"; GC = "fr"; AppName = "$($PreFix)$ContentAppSourceNameFrench"; AppNameDT =$ContentAppSourceNameFrench}
#@{ Language = 'Chinese - China'; Number = "2052"; Code = "zh-cn"; GC = "zh-cn";AppName = "$($PreFix)$ContentAppSourceNameChina"; AppNameDT =$ContentAppSourceNameChina}
#@{ Language = 'Chinese - Taiwan'; Number = "1028"; Code = "zh-tw"; GC = "zh-tw";AppName = "$($PreFix)$ContentAppSourceNameTaiwan"; AppNameDT =$ContentAppSourceNameTaiwan}
#@{ Language = 'German - Germany'; Number = "1031"; Code = "de-de"; GC = "de";AppName = "$($PreFix)$ContentAppSourceNameGermany"; AppNameDT =$ContentAppSourceNameGermany}
#@{ Language = 'Italian - Italy'; Number = "1040"; Code = "it-it"; GC = "it";AppName = "$($PreFix)$ContentAppSourceNameItaly"; AppNameDT ="$ContentAppSourceNameItaly"}
)

$M365Table= @(
#Content App
@{ Type = "Content"; LangCode = "base";Name = "$($PreFix)$ContentAppSourceName"; Publisher = "Microsoft"; SC_AppName = $ContentAppSourceName; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\M365.png";AppDT1_Name = $ContentAppSourceName; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceContent\$stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -PreCache -Channel SemiAnnual -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1 -PreCache"; AppDT1_DM1_Type = "FileSystem"; AppDT1_DM1_Path = "$O365Cache\Office\Data"}
@{ Type = "Content"; LangCode = "fr-fr"; Name = "$($PreFix)$ContentAppSourceNameFrench"; Publisher = "Microsoft"; SC_AppName = $ContentAppSourceNameFrench; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\M365.png";AppDT1_Name = $ContentAppSourceNameFrench; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceContent\$stage"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -PreCache -Channel SemiAnnual -CompanyValue '$CompanyName' -language fr-fr"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1 -PreCache"; AppDT1_DM1_Type = "FileSystem"; AppDT1_DM1_Path = "$O365Cache\Office\Data"; AppDT1_Dependancy = "Content"}


#M365 Main Installs
@{ Type = "App"; Name = "$($PreFix)$MonthlyEnterpriseApp"; Publisher = "Microsoft"; SC_AppName = "$MonthlyEnterpriseApp"; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\M365.png"; AppDT1_Name = "$MonthlyEnterpriseApp"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceInstallers\$Stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\O365_Install.ps1 -Channel MonthlyEnterprise -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1" ; AppDT1_DM1_Type = "Registry"; AppDT1_DM1_HIVE = "HKLM"; AppDT1_DM1_Key = "Software\Microsoft\Office\ClickToRun\Configuration"; AppDT1_DM1_Value = "CDNBaseUrl"; AppDT1_DM1_EqualsValue = $MonthlyEnterpriseChannel; AppDT1_Dependancy = "Content" }
@{ Type = "App"; Name = "$($PreFix)$SemiAnnualPreviewApp"; Publisher = "Microsoft"; SC_AppName = "$SemiAnnualPreviewApp"; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\M365.png"; AppDT1_Name = "$SemiAnnualPreviewApp"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceInstallers\$Stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\O365_Install.ps1 -Channel SemiAnnualPreview -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1" ; AppDT1_DM1_Type = "Registry"; AppDT1_DM1_HIVE = "HKLM"; AppDT1_DM1_Key = "Software\Microsoft\Office\ClickToRun\Configuration"; AppDT1_DM1_Value = "CDNBaseUrl"; AppDT1_DM1_EqualsValue = $SemiAnnualPreviewChannel; AppDT1_Dependancy = "Content" }
@{ Type = "App"; Name = "$($PreFix)$SemiAnnualApp"; Publisher = "Microsoft"; SC_AppName = "$SemiAnnualApp"; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\M365.png"; AppDT1_Name = "$SemiAnnualApp"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceInstallers\$Stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\O365_Install.ps1 -Channel SemiAnnual -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1" ; AppDT1_DM1_Type = "Registry"; AppDT1_DM1_HIVE = "HKLM"; AppDT1_DM1_Key = "Software\Microsoft\Office\ClickToRun\Configuration"; AppDT1_DM1_Value = "CDNBaseUrl"; AppDT1_DM1_EqualsValue = $SemiAnnualChannel; AppDT1_Dependancy = "Content" }

#M365 Addons
@{ Type = "Addon"; Name = "$($PreFix)$AccessApp"; Publisher = "Microsoft"; SC_AppName = "$AccessApp"; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\Access.png"; AppDT1_Name = "$AccessApp"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceInstallers\$Stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\O365_Install.ps1 -Access -Channel SemiAnnual -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1" ; AppDT1_DM1_Type = "Registry"; AppDT1_DM1_HIVE = "HKLM"; AppDT1_DM1_Key = "Software\Microsoft\Office\ClickToRun\Configuration"; AppDT1_DM1_Value = "CDNBaseUrl"; AppDT1_DM2_FileLocation = "%ProgramFiles%\Microsoft Office\root\Office16"; AppDT1_DM2_FileName = "ACCESS.EXE"; AppDT1_Dependancy = "Content" }
@{ Type = "Addon"; Name = "$($PreFix)$VisioProApp"; Publisher = "Microsoft"; SC_AppName = "$VisioProApp"; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\Visio.png"; AppDT1_Name = "$VisioProApp"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceInstallers\$Stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\O365_Install.ps1 -VisioPro -Channel SemiAnnual -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1" ; AppDT1_DM1_Type = "Registry"; AppDT1_DM1_HIVE = "HKLM"; AppDT1_DM1_Key = "Software\Microsoft\Office\ClickToRun\Configuration"; AppDT1_DM1_Value = "CDNBaseUrl"; AppDT1_DM2_Key = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VisioPro2019Volume - en-us"; AppDT1_DM2_Value = "DisplayName"; AppDT1_Dependancy = "Content" }
@{ Type = "Addon"; Name = "$($PreFix)$VisioStdApp"; Publisher = "Microsoft"; SC_AppName = "$VisioStdApp"; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\Visio.png"; AppDT1_Name = "$VisioStdApp"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceInstallers\$Stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\O365_Install.ps1 -VisioStd -Channel SemiAnnual -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1" ; AppDT1_DM1_Type = "Registry"; AppDT1_DM1_HIVE = "HKLM"; AppDT1_DM1_Key = "Software\Microsoft\Office\ClickToRun\Configuration"; AppDT1_DM1_Value = "CDNBaseUrl"; AppDT1_DM2_Key = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\VisioStd2019Volume - en-us"; AppDT1_DM2_Value = "DisplayName"; AppDT1_Dependancy = "Content" }
@{ Type = "Addon"; Name = "$($PreFix)$ProjectProApp"; Publisher = "Microsoft"; SC_AppName = "$ProjectProApp"; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\Project.png"; AppDT1_Name = "$ProjectProApp"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceInstallers\$Stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\O365_Install.ps1 -ProjectPro -Channel SemiAnnual -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1" ; AppDT1_DM1_Type = "Registry"; AppDT1_DM1_HIVE = "HKLM"; AppDT1_DM1_Key = "Software\Microsoft\Office\ClickToRun\Configuration"; AppDT1_DM1_Value = "CDNBaseUrl"; AppDT1_DM2_Key = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ProjectPro2019Volume - en-us"; AppDT1_DM2_Value = "DisplayName"; AppDT1_Dependancy = "Content" }
@{ Type = "Addon"; Name = "$($PreFix)$ProjectStdApp"; Publisher = "Microsoft"; SC_AppName = "$ProjectStdApp"; SC_AppIcon = "$ContentSourceParent\$ContentAppSourceIcons\Project.png"; AppDT1_Name = "$ProjectStdApp"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceInstallers\$Stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\O365_Install.ps1 -ProjectStd -Channel SemiAnnual -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1" ; AppDT1_DM1_Type = "Registry"; AppDT1_DM1_HIVE = "HKLM"; AppDT1_DM1_Key = "Software\Microsoft\Office\ClickToRun\Configuration"; AppDT1_DM1_Value = "CDNBaseUrl"; AppDT1_DM2_Key = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ProjectStd2019Volume - en-us"; AppDT1_DM2_Value = "DisplayName"; AppDT1_Dependancy = "Content" }


)

$ContentBaseInfo = $M365Table | Where-Object {$_.Type -eq "Content" -and $_.LangCode -eq "base"} #Used to create the dependancy on each App
foreach ($M365 in $M365Table)#{Write-Host $M365.Name}
    {
    $LangCode = $null
    $WorkingAppRun = $null
    $WorkingAppRun = Get-CMApplication -Name $M365.Name -ErrorAction SilentlyContinue
    if ($WorkingAppRun)
        {
        Write-Host "Found App: $($M365.Name), skipping and moving on" -ForegroundColor Yellow
        }
    else
        {
    
    #Build Content Apps
        if ($M365.Type -eq "Content")
            {
            if ($M365.LangCode -ne "base"){$LangCode = $M365.LangCode}#Removes the Base Code if this is for the Base Content, otherwise the Language code will be appended onto the path for the language content apps
            Write-Host "Starting App: $($M365.Name)" -ForegroundColor Cyan
            #Write-Host "Language Code: $LangCode"
        #Create Application
            Write-Host " Creating Application: $($M365.Name)" -ForegroundColor Green
            $NewM365Content = New-CMApplication -Name $M365.Name -Publisher $M365.Publisher -LocalizedName $M365.SC_AppName -LocalizedDescription "M365 Content Copied Local used during M365 Install"
            #Set Icon for Software Center
            Set-CMApplication -InputObject $NewM365Content -IconLocationFile $M365.SC_AppIcon
            Write-Host "Set App SC Icon: $($M365.SC_AppIcon)" -ForegroundColor Green
        #Create Detection for AppDT 
            Write-Host "  Starting to Create Detection Method for AppDT" -ForegroundColor Green
            Set-Location -Path "C:"
            #Get the Cab File from the source (assuming you've setup the source already)
            if (Test-Path "$ContentSourceParent\$ContentAppSourceContent\$Stage\Office\Data")
                {
                $ContentApp_AppDT_DetectFile = (Get-ChildItem -Path "$ContentSourceParent\$ContentAppSourceContent\$Stage\Office\Data\v64_*.cab").Name
                }
            else 
                {
                $ContentApp_AppDT_DetectFile = "FakeFile.cab"
                Write-Host "  Didn't find actual content, creating a fake file name place holder" -ForegroundColor Yellow
                }
            Set-Location -Path "$($SiteCode):"
            $DetectionTypeFile = New-CMDetectionClauseFile -FileName $ContentApp_AppDT_DetectFile -Path "$O365Cache\Office\Data\" -Existence -Is64Bit
            Write-Host "  Created Detection Method for Content with File Name: $ContentApp_AppDT_DetectFile" -ForegroundColor Green

            #If Content for Language Addon, create additional Detection
            if ($LangCode)
                {
                Set-Location -Path "C:"
                $LangInfo = $LanguageTable | Where-Object {$_.Code -eq $langcode}
                $AppContentLocation = "$($M365.AppDT1_CL)-$LangCode\"
                $FindLangFiles = Get-ChildItem -Path $AppContentLocation\* -Recurse -erroraction SilentlyContinue
                $LangFiles = $FindLangFiles | Where-Object {$_.Name -Match $LangInfo.Number -or $_.Name -Match $LangCode}
                Set-Location -Path "$($SiteCode):"
                if ($LangFiles)
                    {
                    $ConfirmedLangFile = $LangFiles[0]
                    $DetectionFilePathLang = ($ConfirmedLangFile.DirectoryName).Replace("$AppContentLocation", "")
                    }
                else
                    {
                    $ConfirmedLangFile = @(@{Name = "NoLang.cab"})
                    Write-Host "  Didn't find language content, creating a fake file name place holder" -ForegroundColor Yellow
                    $DetectionFilePathLang = ("\Office")
                    }
                $DetectionTypeFileLang = New-CMDetectionClauseFile -FileName $ConfirmedLangFile.Name -Path "$O365Cache$DetectionFilePathLang" -Existence
            Write-Host "  Created Detection Method for $langcode Content with File Name: $($ConfirmedLangFile.Name)" -ForegroundColor Green
                }
            else {$AppContentLocation = $M365.AppDT1_CL}
            Set-Location -Path "C:"
            if (Test-Path -Path "$AppContentLocation\Office"){} #Assumption, if subdirectory Office is there, then Content is there too.
            else
                {
                $NewFolder = New-Item -Path "$AppContentLocation" -ItemType directory -ErrorAction SilentlyContinue
                $NewFile = New-Item -Path "$AppContentLocation\PlaceHolder.txt" -ItemType file
                Write-Host "  Created Folder:$AppContentLocation" -ForegroundColor yellow
                }
            Set-Location -Path "$($SiteCode):"
        
        #Create AppDT
            Write-Host "  Creating AppDT: $($M365.Name)" -ForegroundColor Green
            $NewM365ContentDT = Add-CMScriptDeploymentType -ApplicationName $NewM365Content.LocalizedDisplayName -DeploymentTypeName $M365.AppDT1_Name -ContentLocation $AppContentLocation -InstallCommand $M365.AppDT1_ProgramInstall -UninstallCommand $M365.AppDT1_ProgramUninstall -AddDetectionClause $DetectionTypeFile -InstallationBehaviorType InstallForSystem -Force32Bit:$false -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120" 
            
            if ($LangCode) 
                {
                $WorkingApp = Get-CMDeploymentType -ApplicationName $NewM365Content.LocalizedDisplayName -DeploymentTypeName $M365.AppDT1_Name 
                $WorkingApp | Set-CMScriptDeploymentType -AddDetectionClause $DetectionTypeFileLang
                $M365ContentAppDT = Get-CMDeploymentType -ApplicationName $ContentBaseInfo.Name -DeploymentTypeName $ContentBaseInfo.AppDT1_Name #Get the Content App
                $NewDependancyGroup = New-CMDeploymentTypeDependencyGroup -GroupName $ContentBaseInfo.Name -InputObject $WorkingApp
                $AddDependancyGroup = Add-CMDeploymentTypeDependency -DeploymentTypeDependency $M365ContentAppDT -IsAutoInstall $true -InputObject $NewDependancyGroup 
                Write-Host "  Adding Dependancy of $($ContentBaseInfo.Name) to App DT" -ForegroundColor Green
                }

            }


    #Build M365 Installation Apps
        if ($M365.Type -eq "App")
            {
            Write-Host "Starting App: $($M365.Name)" -ForegroundColor Cyan
        #Create App
            Write-Host " Creating Application: $($M365.Name)" -ForegroundColor Green
            $NewM365App = New-CMApplication -Name $M365.Name -Publisher $M365.Publisher -LocalizedName $M365.SC_AppName -LocalizedDescription $SC_Description       
            #Set Icon for Software Center
            Set-CMApplication -InputObject $NewM365App -IconLocationFile $M365.SC_AppIcon
            Write-Host "  Set App SC Icon: $($M365.SC_AppIcon)" -ForegroundColor Green
        #Create Detection
            $DetectionTypeRegistry = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM1_Key -ValueName $M365.AppDT1_DM1_Value -Value:$true -ExpressionOperator IsEquals -PropertyType String -ExpectedValue $M365.AppDT1_DM1_EqualsValue -Is64Bit
            $DetectionTypeRegistryLang = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM1_Key -ValueName $M365.AppDT1_DM1_Value -Value:$true -ExpressionOperator IsEquals -PropertyType String -ExpectedValue $M365.AppDT1_DM1_EqualsValue -Is64Bit

        #Create AppDT Base
            Set-Location -Path "C:"
            if (Test-Path "$($M365.AppDT1_CL)O365_Install.ps1"){}
            else 
                {               
                $NewFolder = New-Item -Path "$($M365.AppDT1_CL)" -ItemType directory -ErrorAction SilentlyContinue      
                $NewFile = New-Item -Path "$($M365.AppDT1_CL)\PlaceHolder.txt" -ItemType file
                Write-Host "  Created Folder: $($M365.AppDT1_CL)" -ForegroundColor yellow
                }
            Set-Location -Path "$($SiteCode):"
            $NewM365DT = Add-CMScriptDeploymentType -ApplicationName $M365.Name -DeploymentTypeName $M365.AppDT1_Name -ContentLocation $M365.AppDT1_CL -InstallCommand $M365.AppDT1_ProgramInstall -UninstallCommand $M365.AppDT1_ProgramUninstall -AddDetectionClause $DetectionTypeRegistry -InstallationBehaviorType InstallForSystem -Force32Bit:$false -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120" 
            Write-Host "  Created AppDT: $($M365.AppDT1_Name)" -ForegroundColor Green

            #Add Dependancy App:
            $WorkingAppDT = Get-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $M365.AppDT1_Name 
            $WorkingAppDT | Set-CMScriptDeploymentType -AddDetectionClause $DetectionTypeFileLang
            $M365ContentAppDT = Get-CMDeploymentType -ApplicationName $ContentBaseInfo.Name -DeploymentTypeName $ContentBaseInfo.AppDT1_Name
            $NewDependancyGroup = New-CMDeploymentTypeDependencyGroup -GroupName $ContentBaseInfo.Name -InputObject $WorkingAppDT
            $AddDependancyGroup = Add-CMDeploymentTypeDependency -DeploymentTypeDependency $M365ContentAppDT -IsAutoInstall $true -InputObject $NewDependancyGroup 
            Write-Host "  Adding Dependancy of $($ContentBaseInfo.Name) to App DT" -ForegroundColor Green

        #Take Care of Language Stuff
            
            foreach ($Language in $LanguageTable)
                {
                write-host "  Starting Language $($Language.Code)" -ForegroundColor Cyan
                #$DetectionTypeRegistry = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM1_Key -ValueName $Language.AppDT_DM1_Value -Value:$true -ExpressionOperator IsEquals -PropertyType String -ExpectedValue $M365.AppDT1_DM1_EqualsValue -Is64Bit
                $DeploymentTypeName = "$($M365.AppDT1_Name) $($Language.code)"
                $DeploymentInstallCommand = "$($M365.AppDT1_ProgramInstall) -language $($Language.code)"
                $NewM365AppDTLang = Add-CMScriptDeploymentType -ApplicationName $M365.Name -DeploymentTypeName $DeploymentTypeName -ContentLocation $M365.AppDT1_CL -InstallCommand $DeploymentInstallCommand -UninstallCommand $M365.AppDT1_ProgramUninstall -AddDetectionClause $DetectionTypeRegistryLang -InstallationBehaviorType InstallForSystem -Force32Bit:$false -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120"
                Write-Host "   Created AppDT: $($M365.AppDT1_Name) $($Language.code)" -ForegroundColor Green
                #Add Dependancy App:
                $WorkingAppDT = Get-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName #Gets the Current Application we're working on
                $M365LangContentAppDT = Get-CMDeploymentType -ApplicationName $Language.AppName -DeploymentTypeName $Language.AppNameDT #Gets the Language Content Application Info
                $NewDependancyGroup = New-CMDeploymentTypeDependencyGroup -GroupName $Language.AppNameDT -InputObject $WorkingAppDT #Creates the Dependancy Group on our Language AppDT
                $AddDependancyGroup = Add-CMDeploymentTypeDependency -DeploymentTypeDependency $M365LangContentAppDT -IsAutoInstall $true -InputObject $NewDependancyGroup #Adds the Language Content App as a Pre-Req on our new AppDT
                Write-Host "   Adding Dependancy of $($Language.AppNameDT) to App DT" -ForegroundColor Green
                Set-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName -Priority Increase
                $myGC = Get-CMGlobalCondition -Name "Operating System Language" | Where-Object PlatformType -eq 1
                $cultureA = [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures) | Where-Object Name -eq $Language.GC
                $myRule = $myGC | New-CMRequirementRuleOperatingSystemLanguageValue -RuleOperator OneOf -Culture $cultureA -IsMobile $False
                Set-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName -AddRequirement $myRule
                }           
            }
        if ($M365.Type -eq "Addon")
            {
            Write-Host "Starting App Addon: $($M365.Name)" -ForegroundColor Cyan
        #Create App
            Write-Host " Creating Application: $($M365.Name)" -ForegroundColor Green
            $NewM365App = New-CMApplication -Name $M365.Name -Publisher $M365.Publisher -LocalizedName $M365.SC_AppName -LocalizedDescription $SC_Description       
            #Set Icon for Software Center
            Set-CMApplication -InputObject $NewM365App -IconLocationFile $M365.SC_AppIcon
            Write-Host "  Set App SC Icon: $($M365.SC_AppIcon)" -ForegroundColor Green
        #Create Detection
            $DetectionTypeRegistry = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM1_Key -ValueName $M365.AppDT1_DM1_Value -Existence -Is64Bit -PropertyType String
            $DetectionTypeRegistryLang = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM1_Key -ValueName $M365.AppDT1_DM1_Value -Existence -Is64Bit -PropertyType String
           
            if ($M365.SC_AppName -eq $AccessApp)
                {
                $DetectionType2 = New-CMDetectionClauseFile -FileName $M365.AppDT1_DM2_FileName -Path $M365.AppDT1_DM2_FileLocation -Existence
                $DetectionType2Lang = New-CMDetectionClauseFile -FileName $M365.AppDT1_DM2_FileName -Path $M365.AppDT1_DM2_FileLocation -Existence
                }
            else
                {
                $DetectionType2 = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM2_Key -ValueName $M365.AppDT1_DM2_Value -Existence -Is64Bit -PropertyType String
                $DetectionType2Lang = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM2_Key -ValueName $M365.AppDT1_DM2_Value -Existence -Is64Bit -PropertyType String              
                }

        #Create AppDT Base
            Set-Location -Path "C:"
            if (Test-Path "$($M365.AppDT1_CL)O365_Install.ps1"){}
            else 
                {               
                $NewFolder = New-Item -Path "$($M365.AppDT1_CL)" -ItemType directory -ErrorAction SilentlyContinue      
                $NewFile = New-Item -Path "$($M365.AppDT1_CL)\PlaceHolder.txt" -ItemType file
                Write-Host "  Created Folder: $($M365.AppDT1_CL)" -ForegroundColor yellow
                }
            Set-Location -Path "$($SiteCode):"
            $NewM365DT = Add-CMScriptDeploymentType -ApplicationName $M365.Name -DeploymentTypeName $M365.AppDT1_Name -ContentLocation $M365.AppDT1_CL -InstallCommand $M365.AppDT1_ProgramInstall -UninstallCommand $M365.AppDT1_ProgramUninstall -AddDetectionClause $DetectionTypeRegistry -InstallationBehaviorType InstallForSystem -Force32Bit:$false -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120" 
            Write-Host "  Created AppDT: $($M365.AppDT1_Name)" -ForegroundColor Green
            $WorkingAppDT = Get-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $M365.AppDT1_Name
            $WorkingAppDT | Set-CMScriptDeploymentType -AddDetectionClause $DetectionType2
            Write-Host "   Adding additional Detection Method for this Addon" -ForegroundColor Green

            #Add Dependancy App:
            $WorkingAppDT = Get-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $M365.AppDT1_Name 
            $WorkingAppDT | Set-CMScriptDeploymentType -AddDetectionClause $DetectionTypeFileLang
            $M365ContentAppDT = Get-CMDeploymentType -ApplicationName $ContentBaseInfo.Name -DeploymentTypeName $ContentBaseInfo.AppDT1_Name
            $NewDependancyGroup = New-CMDeploymentTypeDependencyGroup -GroupName $ContentBaseInfo.Name -InputObject $WorkingAppDT
            $AddDependancyGroup = Add-CMDeploymentTypeDependency -DeploymentTypeDependency $M365ContentAppDT -IsAutoInstall $true -InputObject $NewDependancyGroup 
            Write-Host "  Adding Dependancy of $($ContentBaseInfo.Name) to App DT" -ForegroundColor Green

        #Take Care of Language Stuff
            
            foreach ($Language in $LanguageTable)
                {
                write-host "  Starting Language $($Language.Code)" -ForegroundColor Cyan
                #$DetectionTypeRegistry = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM1_Key -ValueName $Language.AppDT_DM1_Value -Existence -Is64Bit -PropertyType String
                $DeploymentTypeName = "$($M365.AppDT1_Name) $($Language.code)"
                $DeploymentInstallCommand = "$($M365.AppDT1_ProgramInstall) -language $($Language.code)"
                $NewM365AppDTLang = Add-CMScriptDeploymentType -ApplicationName $M365.Name -DeploymentTypeName $DeploymentTypeName -ContentLocation $M365.AppDT1_CL -InstallCommand $DeploymentInstallCommand -UninstallCommand $M365.AppDT1_ProgramUninstall -AddDetectionClause $DetectionTypeRegistryLang -InstallationBehaviorType InstallForSystem -Force32Bit:$false -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120"
                Write-Host "   Created AppDT: $($M365.AppDT1_Name) $($Language.code)" -ForegroundColor Green
                $WorkingAppDT = Get-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName #Gets the Current Application we're working on
                $WorkingAppDT | Set-CMScriptDeploymentType -AddDetectionClause $DetectionType2Lang
                Write-Host "   Adding additional Detection Method for this Addon" -ForegroundColor Green

                #Add Dependancy App:

                $WorkingAppDT = Get-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName #Gets the Current Application we're working on
                $M365LangContentAppDT = Get-CMDeploymentType -ApplicationName $Language.AppName -DeploymentTypeName $Language.AppNameDT #Gets the Language Content Application Info
                $NewDependancyGroup = New-CMDeploymentTypeDependencyGroup -GroupName $Language.AppNameDT -InputObject $WorkingAppDT #Creates the Dependancy Group on our Language AppDT
                $AddDependancyGroup = Add-CMDeploymentTypeDependency -DeploymentTypeDependency $M365LangContentAppDT -IsAutoInstall $true -InputObject $NewDependancyGroup #Adds the Language Content App as a Pre-Req on our new AppDT
                Write-Host "   Adding Dependancy of $($Language.AppNameDT) to App DT" -ForegroundColor Green
                Set-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName -Priority Increase
                $myGC = Get-CMGlobalCondition -Name "Operating System Language" | Where-Object PlatformType -eq 1
                $cultureA = [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures) | Where-Object Name -eq $Language.GC
                $myRule = $myGC | New-CMRequirementRuleOperatingSystemLanguageValue -RuleOperator OneOf -Culture $cultureA -IsMobile $False
                Set-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName -AddRequirement $myRule
                }
            }
        }
     if ($PreFix -ne $null)
        {
        Write-Host  "  Starting Scope Maintenance" -ForegroundColor Cyan
        $ConfirmApp = Get-CMApplication -Name $M365.Name -ErrorAction SilentlyContinue
        $AppScopes = Get-CMObjectSecurityScope -InputObject $ConfirmApp 
        if ($AppScopes.CategoryName -ccontains "Default")
            {
            $DefaultScope = $AppScopes | Where-Object {$_.CategoryName -eq "default"} 
            if (!($AppScopes.CategoryName -contains "SDE"))
                {
                $SDEScope = Get-CMSecurityScope | Where-Object {$_.CategoryName -eq "SDE"}
                $AddSDEScope = Add-CMObjectSecurityScope -InputObject $ConfirmApp -Scope $SDEScope
                Write-Host  "   Adding Scope $($SDEScope.CategoryName) to $($M365.Name)" -ForegroundColor Green
                }
            $RemovedDefaultAppScope = Remove-CMObjectSecurityScope -InputObject $ConfirmApp -Scope $DefaultScope -Force
            Write-Host  "   Removing Default Scope from $($M365.Name)" -ForegroundColor Green
            } 
        $NonACMEScope = $AppScopes | Where-Object {$_.CategoryName -ne "SDE" -and $_.CategoryDescription -notmatch "A built-in security scope"} 
        foreach ($Scope in $NonACMEScope)
            {
            Write-Host  "   Removing Scope $($Scope.CategoryName) from $($M365.Name)" -ForegroundColor Green
            $RemovedAppScopes = Remove-CMObjectSecurityScope -InputObject $ConfirmApp -Scope $Scope -Force
            }
        }
    }
