#Builds the Apps in CM

$SC_Description = "***********************************************************************************
Save your work and close any Office applications before running this install
***********************************************************************************
This will automatically reinstall Visio, Project, or Access if previously installed."


$Stage = "Prod"
$ContentSourceParent = "\\src\src$\Apps\Microsoft\Microsoft 365"
$ContentAppSourceName = 'Microsoft 365 Content'
$ContentAppSourceContent = "Microsoft 365 Content"
$CompanyName = 'Recast Software'
$O365Cache = "C:\ProgramData\O365_Cache"



#Load CM PowerShell
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

$CurrentPreview = "http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be"
$Current = "http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60"
$MonthlyEnterprise = "http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6"
$SemiAnnualPreview = "http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf"
$SemiAnnual = "http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114"

$LanguageTable= @(
@{ Language = 'French - France'; Number = "1036"; Code = "fr-fr"; AppName = "Microsoft 365 French Content"; AppNameDT ="Microsoft 365 French Content"}
#@{ Language = 'Chinese - China'; Number = "2052"; Code = "zh-cn"; AppName = "Microsoft 365 China Content"; AppNameDT ="Microsoft 365 China Content"}
#@{ Language = 'Chinese - Taiwan'; Number = "1028"; Code = "zh-cn"; AppName = "Microsoft 365 Taiwan Content"; AppNameDT ="Microsoft 365 Taiwan Content"}
#@{ Language = 'German - Germany'; Number = "1031"; Code = "de-de"; AppName = "Microsoft 365 Germany Content"; AppNameDT ="Microsoft 365 Germany Content"}
#@{ Language = 'Italian - Italy'; Number = "1040"; Code = "it-it"; AppName = "Microsoft 365 Italy Content"; AppNameDT ="Microsoft 365 Italy Content"}
)

$M365Table= @(
#Content App
@{ Type = "Content"; LangCode = "base";Name = $ContentAppSourceName; Publisher = "Microsoft"; SC_AppName = "Microsoft 365 Content"; SC_AppIcon = "$ContentSourceParent\Microsoft 365 Icons\M365.png";AppDT1_Name = "Microsoft 365 Content"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceContent\$stage\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -PreCache -Channel Broad -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1 -PreCache"; AppDT1_DM1_Type = "FileSystem"; AppDT1_DM1_Path = "C:\ProgramData\O365_Cache\Office\Data"}
@{ Type = "Content"; LangCode = "fr-fr"; Name = 'Microsoft 365 French Content'; Publisher = "Microsoft"; SC_AppName = "Microsoft 365 French Content"; SC_AppIcon = "$ContentSourceParent\Microsoft 365 Icons\M365.png";AppDT1_Name = "Microsoft 365 French Content"; AppDT1_CL = "$ContentSourceParent\$ContentAppSourceContent\$stage"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\o365_Install.ps1 -PreCache -Channel Broad -CompanyValue '$CompanyName' -language fr-fr"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1 -PreCache"; AppDT1_DM1_Type = "FileSystem"; AppDT1_DM1_Path = "C:\ProgramData\O365_Cache\Office\Data"}


#M365 Main Installs
@{ Type = "App"; Name = 'Microsoft 365 Office - Monthly Enterprise Channel'; Publisher = "Microsoft"; SC_AppName = "Microsoft 365 Office - Monthly Enterprise Channel"; SC_AppIcon = "$ContentSourceParent\Microsoft 365 Icons\M365.png"; AppDT1_Name = "Microsoft 365 Office - Monthly Enterprise Channel"; AppDT1_CL = "$ContentSourceParent\Microsoft 365 Installers\Prod\"; AppDT1_ProgramInstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\O365_Install.ps1 -Channel MonthlyEnterprise -CompanyValue '$CompanyName'"; AppDT1_ProgramUninstall = "powershell.exe -ExecutionPolicy ByPass -WindowStyle Hidden .\uninstall.ps1" ; AppDT1_DM1_Type = "Registry"; AppDT1_DM1_HIVE = "HKLM"; AppDT1_DM1_Key = "Software\Microsoft\Office\ClickToRun\Configuration"; AppDT1_DM1_Value = "CDNBaseUrl"; AppDT1_DM1_EqualsValue = $MonthlyEnterprise; AppDT1_Dependancy = "Microsoft 365 Content" }


)

$ContentBaseInfo = $M365Table | Where-Object {$_.Type -eq "Content" -and $_.LangCode -eq "base"}
foreach ($M365 in $M365Table)#{Write-Host $M365.Name}
    {
    $LangCode = $null
    $TestAppExist = $null
    $TestAppExist = Get-CMApplication -Name $M365.Name -ErrorAction SilentlyContinue
    if (!($TestAppExist))
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
                    $DetectionFilePathLang = ($ConfirmedLangFile.DirectoryName).Replace("$LangContentSource", "")
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
            if (Test-Path -Path "$AppContentLocation\PlaceHolder.txt"){}
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
            
            #$GetM365ContentDT = Get-CMApplication -Name $NewM365Content.LocalizedDisplayName
            if ($LangCode) 
                {
                $WorkingApp = Get-CMDeploymentType -ApplicationName $NewM365Content.LocalizedDisplayName -DeploymentTypeName $M365.AppDT1_Name 
                $WorkingApp | Set-CMScriptDeploymentType -AddDetectionClause $DetectionTypeFileLang
                $M365ContentAppDT = Get-CMDeploymentType -ApplicationName $ContentBaseInfo.Name -DeploymentTypeName $ContentBaseInfo.AppDT1_Name
                #$WorkingApp | New-CMDeploymentTypeDependencyGroup -GroupName $ContentBaseInfo.Name | Add-CMDeploymentTypeDependency -DeploymentTypeDependency $M365ContentAppDT -IsAutoInstall $true
                $NewDependancyGroup = New-CMDeploymentTypeDependencyGroup -GroupName $ContentBaseInfo.Name -InputObject $WorkingApp
                $AddDependancyGroup = Add-CMDeploymentTypeDependency -DeploymentTypeDependency $M365ContentAppDT -IsAutoInstall $true -InputObject $NewDependancyGroup 
                Write-Host "  Adding Dependancy of $($ContentBaseInfo.Name) to App DT" -ForegroundColor Green
                }

        #Update Scope Info (ACME Only)
            <#
            $ConfirmApp = Get-CMApplication -Name $NewM365Content.LocalizedDisplayName
            $AppScopes = Get-CMObjectSecurityScope -InputObject $ConfirmApp 
            $NonACMEScope = $AppScopes | Where-Object {$_.CategoryName -ne "SDE" -and $_.CategoryDescription -notmatch "A built-in security scope"} 
            foreach ($Scope in $NonACMEScope)
                {
                Write-Host  "  Removing Scope $($Scope.CategoryName) from $($M365.Name)" -ForegroundColor Green
                $RemovedAppScopes = Remove-CMObjectSecurityScope -InputObject $ConfirmApp -Scope $Scope -Force
                }
            #>
            }


    #Build M365 Installation Apps
        if ($M365.Type -eq "App")
            {
            Write-Host "Starting App: $($M365.Name)" -ForegroundColor Cyan
        #Create App
            Write-Host " Creating Application: $($M365.Name)" -ForegroundColor Green
            $NewM365App = New-CMApplication -Name $M365.Name -Publisher $M365.Publisher -LocalizedName $M365.SC_AppName -LocalizedDescription $SC_Description       
            #Set Icon for Software Center
            Set-CMApplication -InputObject $NewM365Content -IconLocationFile $M365.SC_AppIcon
            Write-Host "  Set App SC Icon: $($M365.SC_AppIcon)" -ForegroundColor Green
        #Create Detection
            $DetectionTypeRegistry = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM1_Key -ValueName $M365.AppDT1_DM1_Value -Value:$true -ExpressionOperator IsEquals -PropertyType String -ExpectedValue $M365.AppDT1_DM1_EqualsValue -Is64Bit

        #Create AppDT Base
            Set-Location -Path "C:"
            if (Test-Path "$($M365.AppDT1_CL)\Placeholder.txt"){}
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
                $DetectionTypeRegistry = New-CMDetectionClauseRegistryKeyValue -Hive LocalMachine -KeyName $M365.AppDT1_DM1_Key -ValueName "UpdateChannel" -Value:$true -ExpressionOperator IsEquals -PropertyType String -ExpectedValue $M365.AppDT1_DM1_EqualsValue -Is64Bit
                $DeploymentTypeName = "$($M365.AppDT1_Name) $($Language.code)"
                $DeploymentInstallCommand = "$($M365.AppDT1_ProgramInstall) -language $($Language.code)"
                $NewM365AppDTLang = Add-CMScriptDeploymentType -ApplicationName $M365.Name -DeploymentTypeName $DeploymentTypeName -ContentLocation $M365.AppDT1_CL -InstallCommand $DeploymentInstallCommand -UninstallCommand $M365.AppDT1_ProgramUninstall -AddDetectionClause $DetectionTypeRegistry -InstallationBehaviorType InstallForSystem -Force32Bit:$false -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120"
                Write-Host "   Created AppDT: $($M365.AppDT1_Name) $($Language.code)" -ForegroundColor Green
                #Add Dependancy App:
                $WorkingAppDT = Get-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName #Gets the Current Application we're working on
                $M365LangContentAppDT = Get-CMDeploymentType -ApplicationName $Language.AppName -DeploymentTypeName $Language.AppNameDT #Gets the Language Content Application Info
                $NewDependancyGroup = New-CMDeploymentTypeDependencyGroup -GroupName $Language.AppNameDT -InputObject $WorkingAppDT #Creates the Dependancy Group on our Language AppDT
                $AddDependancyGroup = Add-CMDeploymentTypeDependency -DeploymentTypeDependency $M365LangContentAppDT -IsAutoInstall $true -InputObject $NewDependancyGroup #Adds the Language Content App as a Pre-Req on our new AppDT
                Write-Host "   Adding Dependancy of $($Language.AppNameDT) to App DT" -ForegroundColor Green
                Set-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName -Priority Increase
                $myGC = Get-CMGlobalCondition -Name "Operating System Language" | Where-Object PlatformType -eq 1
                $cultureA = [System.Globalization.CultureInfo]::GetCultures([System.Globalization.CultureTypes]::AllCultures) | Where-Object Name -eq "fr"
                $myRule = $myGC | New-CMRequirementRuleOperatingSystemLanguageValue -RuleOperator OneOf -Culture $cultureA -IsMobile $False
                Set-CMDeploymentType -ApplicationName $NewM365App.LocalizedDisplayName -DeploymentTypeName $DeploymentTypeName -AddRequirement $myRule
                }

        #Update Scope Info (ACME Only)
            <#
            $ConfirmApp = Get-CMApplication -Name $NewM365App.LocalizedDisplayName
            $AppScopes = Get-CMObjectSecurityScope -InputObject $ConfirmApp 
            $NonACMEScope = $AppScopes | Where-Object {$_.CategoryName -ne "SDE" -and $_.CategoryDescription -notmatch "A built-in security scope"}
            foreach ($Scope in $NonACMEScope)
                {
                Write-Host  "  Removing Scope $($Scope.CategoryName) from $($M365.Name)" -ForegroundColor Green
                $RemovedAppScopes = Remove-CMObjectSecurityScope -InputObject $ConfirmApp -Scope $Scope -Force
                }
            #>
            }
        }
    }
