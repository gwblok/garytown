<# @gwblok - MMS Miami 2021 Demo Code
Note, this script is only does part of the process... you'll still need to update the PowerShell script to do your install and update the detection method.
- Update the Install_App.ps1 file that is created from this script
This is more of a code SAMPLE for you to steal parts and get help with creating a WIM of your Applications' Content.
#>
#Load CM PowerShell
$SiteCode = "PS2"

Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

$AppSearch = Read-Host -Prompt "Search for Apps"
$AppChooser = Get-CMApplication -Fast -Name *$AppSearch* | Select-Object -Property "LocalizedDisplayName", "CI_ID" | Out-GridView -Title "Select the App you want to WIM" -PassThru
$AppItem = Get-CMApplication -Fast -Id $AppChooser.CI_ID
$AppDeploymentType = Get-CMDeploymentType -InputObject $AppItem

[xml]$AppDTXML = $AppDeploymentType.SDMPackageXML
$AppDTSource = $AppDTXML.AppMgmtDigest.DeploymentType.Installer.Contents.Content.Location
$AppDTInstallCommand = 

$Arg = $AppDTXML.AppMgmtDigest.DeploymentType.Installer.InstallAction.args.Arg
$CommandLine = ($Arg | Where-Object {$_.Name -eq "InstallCommandLine"}).'#Text'


$NewLocation = "$($AppDTSource.Substring(0,$AppDTSource.Length-1))_WIM"
Set-Location -Path $env:SystemDrive
if (Test-Path $NewLocation){Remove-Item $NewLocation -Force -Recurse}
$Null = New-Item -Path $NewLocation -ItemType Directory -Force



#WIM Expanded Files
$ScatchLocation = "D:\DedupExclude"
$DismScratchPath = "$ScatchLocation\DISM"
$DismTempPath = "$ScatchLocation\TEMP"
# Cleanup Previous Runs (Deletes the files)
if (Test-Path $dismscratchpath) {Remove-Item $DismScratchPath -Force -Recurse -ErrorAction SilentlyContinue}
$DismScratch = New-Item -Path $DismScratchPath -ItemType Directory -Force
if (Test-Path $DismTempPath) {Remove-Item $DismTempPath -Force -Recurse -ErrorAction SilentlyContinue}
$DismTemp = New-Item -Path $DismTempPath -ItemType Directory -Force

write-host "Copying Source Files to Temp location for WIMing" 
Copy-Item -Path $AppDTSource\* -Destination $DismTempPath -Recurse -Force
write-host "Creating App.wim"
New-WindowsImage -ImagePath "$NewLocation\App.wim" -CapturePath "$DismTempPath" -Name "$($AppItem.LocalizedDisplayName)"  -LogPath "$env:TEMP\dism-$($Model.MIFFilename).log" -ScratchDirectory $dismscratchpath

$InstallFile = {
$TempFolderName = New-Guid
$TempFolderLocation = "$env:temp\$TempFolderName"
$Null = New-Item $TempFolderLocation -ItemType Directory
Mount-WindowsImage -Path $TempFolderLocation -ImagePath ".\App.wim" -Index 1
#------------------------------------------------------------------------------
#Original Command Line Below:
}



$InstallFile | Out-File -FilePath "$NewLocation\Install_App.ps1"
$UpdatedCommandLine = $CommandLine.replace(".\",'$TempFolderLocation\')
$UpdatedCommandLine | Out-File -FilePath "$NewLocation\Install_App.ps1" -Append
$InstallFile = {Dismount-WindowsImage -Path $TempFolderLocation -Discard}
$InstallFile | Out-File -FilePath "$NewLocation\Install_App.ps1" -Append


Set-Location -Path "$($SiteCode):"
$NewApp = New-CMApplication -LocalizedName "$($AppItem.LocalizedDisplayName)_WIM" -Name "$($AppItem.LocalizedDisplayName)_WIM" -SoftwareVersion $AppItem.SoftwareVersion
$NewInstallCommand = {powershell -ExecutionPolicy Bypass -File ".\Install_App.ps1"}
$NewDT = Add-CMScriptDeploymentType -ApplicationName "$($AppItem.LocalizedDisplayName)_WIM" -DeploymentTypeName "$($AppItem.LocalizedDisplayName)_WIM" -ContentLocation $NewLocation -InstallCommand $NewInstallCommand -InstallationBehaviorType InstallForSystem -Force32Bit:$false -EstimatedRuntimeMins "60" -MaximumRuntimeMins "120" -ScriptLanguage PowerShell -ScriptText "Test"
