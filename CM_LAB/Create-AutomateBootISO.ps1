# Site configuration
$SiteCode = "MCM" # Site code 
$ProviderMachineName = "MEMCM.dev.recastsoftware.dev" # SMS Provider machine name
$CertPath = "\\src\src$\Certs\DP_WinPE.pfx"
if (!($CertPassword)){$CertPassword = Read-Host -AsSecureString}
$ISOSaveLocation = "\\src\src$\BootImages\ISOs"


# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}
# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName 
}
# Set the current location to be the site code.
Set-Location "$($SiteCode):\"

#This is used to pick which variables get put into the boot media
$Build = $Null
if (!($Build)){$Build = "Automated", "Manual" | Out-GridView -Title "Select the Build you want to update" -PassThru} #Automated includes SMSTSPreferredAdvertID, and AllowUnattended
$BootImageTable = Get-CMBootImage | Select-Object "Name","PackageID","Version" | Out-GridView -Title "Select Boot Image to Make Boot Media From" -PassThru
if ($Build -eq "Automated"){
    $AutomatedTS = Get-CMTaskSequence -Fast | Select-Object -Property "Name", "PackageID" | Out-GridView -Title "Select TS for Automated Deployment" -PassThru
    $AutomatedTaskSequence = Get-CMTaskSequence -TaskSequencePackageId $AutomatedTS.PackageID -Fast
    $SelectDeployment = Get-CMTaskSequenceDeployment -Fast -InputObject $AutomatedTaskSequence | Select-Object -Property "AdvertisementName", "CollectionID", "AdvertisementID" | Out-GridView -Title "Select Deployment for Automated Deployment" -PassThru
    $PerferedAdvertID = $SelectDeployment.AdvertisementID
    }
#Create Temp Location to Build ISO
Set-Location $env:SystemDrive
$IsoBuildPath = "$env:temp\CMISO"
if (Test-Path -Path $IsoBuildPath){Remove-Item -Path $IsoBuildPath -Force -Recurse}
$Null = New-Item -Path $IsoBuildPath -ItemType Directory 
if (!(Test-Path -Path $ISOSaveLocation)){$Null = New-Item -Path $ISOSaveLocation -ItemType Directory }

#Get Boot Media Inputs and Build
Set-Location "$($SiteCode):\"

#Boot Media Variables
if ($Build -eq "Automated"){$TSVariable = @{"SMSTSPreferredAdvertID" = "$PerferedAdvertID"; "CreatedByGWB" = "TRUE"} ; $AllowUnattended = $true}
if ($Build -eq "Manual"){$TSVariable = @{"CreatedByGWB" = "TRUE"} ; $AllowUnattended = $false}


$BootImage = Get-CMBootImage -Id $BootImageTable.PackageID
$DistributionPoint = Get-CMDistributionPoint -SiteCode $SiteCode  | Select-Object -First 1
$ManagementPoint = Get-CMManagementPoint -SiteCode $SiteCode

New-CMBootableMedia -AllowUacPrompt -AllowUnattended:$AllowUnattended -AllowUnknownMachine -BootImage $BootImage -DistributionPoint $DistributionPoint -ManagementPoint $ManagementPoint -SiteCode $SiteCode -MediaType CdDvd -Path "$IsoBuildPath\CMBoot.iso" -MediaMode SiteBased -UserDeviceAffinity AutoApproval -Variable $TSVariable -CertificatePath $CertPath -CertificatePassword $CertPassword



#Update to Remove Prompt: https://www.deploymentresearch.com/a-good-iso-file-is-a-quiet-iso-file/
Set-Location $env:SystemDrive
# Settings
$WinPE_Architecture = "amd64" # Or x86
$WinPE_InputISOfile = "$IsoBuildPath\CMBoot.iso"
$WinPE_OutputISOfile = "$IsoBuildPath\CMBoot_NoPrompt.iso"
 
$ADK_Path = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
$WinPE_ADK_Path = $ADK_Path + "\Windows Preinstallation Environment"
$OSCDIMG_Path = $ADK_Path + "\Deployment Tools" + "\$WinPE_Architecture\Oscdimg"

# Validate locations
If (!(Test-path $WinPE_InputISOfile)){ Write-Warning "WinPE Input ISO file does not exist, aborting...";Break}
If (!(Test-path $ADK_Path)){ Write-Warning "ADK Path does not exist, aborting...";Break}
If (!(Test-path $WinPE_ADK_Path)){ Write-Warning "WinPE ADK Path does not exist, aborting...";Break}
If (!(Test-path $OSCDIMG_Path)){ Write-Warning "OSCDIMG Path does not exist, aborting...";Break}

# Mount the Original ISO (WinPE_InputISOfile) and figure out the drive-letter
Mount-DiskImage -ImagePath $WinPE_InputISOfile
$ISOImage = Get-DiskImage -ImagePath $WinPE_InputISOfile | Get-Volume
$ISODrive = [string]$ISOImage.DriveLetter+":"

# Create a new bootable WinPE ISO file, based on the Original ISO, but using efisys_noprompt.bin instead
$BootData='2#p0,e,b"{0}"#pEF,e,b"{1}"' -f "$OSCDIMG_Path\etfsboot.com","$OSCDIMG_Path\efisys_noprompt.bin"
   
$Proc = Start-Process -FilePath "$OSCDIMG_Path\oscdimg.exe" -ArgumentList @("-bootdata:$BootData",'-u2','-udfver102',"$ISODrive\","`"$WinPE_OutputISOfile`"") -PassThru -Wait -NoNewWindow
if($Proc.ExitCode -ne 0)
{
    Throw "Failed to generate ISO with exitcode: $($Proc.ExitCode)"
}

# Dismount the Original ISO
Dismount-DiskImage -ImagePath $WinPE_InputISOfile

#Copy ISO to Share based on Boot Media Choosen
$ISOName = (((($BootImageTable.Name).Trim()).replace(" ","_")).replace("(","")).replace(")","")
Copy-Item $WinPE_OutputISOfile -Destination "$ISOSaveLocation\$($ISOName)_$($Build).iso" -Force
