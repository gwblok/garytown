#Require OSD Module

$WinPE_ARM64WorkSpace = "C:\WinPE_ARM64_OSDWorkSpace"
$MountDir = "C:\WinPE_ARM64_MountDir"

#Default ADK Paths
$ADKPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
$ADKPathPE = "$ADKPath\Windows Preinstallation Environment"

if (!(test-path -path "$WinPE_ARM64WorkSpace")){New-Item -Path $WinPE_ARM64WorkSpace -ItemType Directory | Out-Null}

#Create OSDCloud Template - This will build x64 template, no big deal, we'll replace later.
$OSDCloudTemplateName = 'ARM64'
if ((Get-OSDCloudTemplateNames) -notcontains "$OSDCloudTemplateName"){
    New-OSDCloudTemplate -Name ARM64
}

#Creaet the OSDCloud WorkSpace - This will be created based on the template, but we'll replace what we need
if ((Get-OSDCloudWorkspace) -ne $WinPE_ARM64WorkSpace){
    New-OSDCloudWorkspace -WorkspacePath $WinPE_ARM64WorkSpace
}

#Clean it out to replace with the ARM64 Stuff we'll build
Remove-Item -Path "$WinPE_ARM64WorkSpace\media\*" -Recurse -Force
Remove-Item -Path "$WinPE_ARM64WorkSpace\logs\*" -Recurse -Force

if (!(test-path -path "$WinPE_ARM64WorkSpace\media")){New-Item -Path "$WinPE_ARM64WorkSpace\media" -ItemType Directory | Out-Null}
if (!(test-path -path "$WinPE_ARM64WorkSpace\media\sources")){New-Item -Path "$WinPE_ARM64WorkSpace\media\sources" -ItemType Directory | Out-Null}
if (!(test-path -path "$WinPE_ARM64WorkSpace\fwfiles")){New-Item -Path "$WinPE_ARM64WorkSpace\fwfiles" -ItemType Directory | Out-Null}

if (!(Test-path -path $MountDir)){new-item -path $mountdir -ItemType directory -force | Out-Null}
copy-item -Path "$ADKPathPE\arm64\Media\*" -Destination "$WinPE_ARM64WorkSpace\media" -Recurse -Force
Copy-item -path "$ADKPath\Deployment Tools\arm64\Oscdimg\efisys.bin" -Destination "$WinPE_ARM64WorkSpace\fwfiles"
copy-item -Path "$ADKPathPE\arm64\en-us\winpe.wim"-Destination "$WinPE_ARM64WorkSpace\media\sources\boot.wim"


#region Update boot wim with the good stuff

#Mount WinPE Image
Mount-WindowsImage -Path $MountDir -ImagePath "$WinPE_ARM64WorkSpace\media\sources\boot.wim" -Index 1

#Cabs to Install IN SPECIFIC ORDER
$CabNames =@('Dot3Svc','EnhancedStorage','MDAC','NetFx','PowerShell','Scripting','SecureBootCmdlets','WinPE-WMI','StorageWMI','PmemCmdlets','DismCmdlets','SecureStartup','x64-Support','PlatformId')

#Get Installed Features, this is handy if you're modifing it in the future
$InstallFeatures = Get-WindowsPackage -Path $mountdir | Where-Object {$_.PackageName -notmatch "en-US"}

#Start Adding Features
foreach ($CabName in $CabNames){
    Write-Host "Starting $CabName" -ForegroundColor Green

    $Installed = $InstallFeatures | Where-Object {$_.PackageName -match $CabName}
    if ($Installed.PackageState -eq "Installed"){
        Write-Output " Already Installed"
    }
    else{
        $workingcab = $Null
        $workingcabenus = $Null
        $workingcab = get-childitem -Path "$ADKPathPE\ARM64\WinPE_OCs" -Filter *.cab | Where-Object {$_.Name -match $CabName}
        if ($workingcab){Add-WindowsPackage -Path $MountDir -PackagePath $workingcab.FullName -Verbose}
        $workingcabenus = get-childitem -Path "$ADKPathPE\ARM64\WinPE_OCs\en-us" -Filter *.cab | Where-Object {$_.Name -match $CabName}
        if ($workingcabenus){Add-WindowsPackage -Path $MountDir -PackagePath $workingcabenus.FullName -Verbose}

    }
}

#Add PS Modules to the Boot Image
Save-Module -Name PowerShellGet -Path "$MountDir\Program Files\WindowsPowerShell\Modules"
Save-Module -Name PackageManagement -Path "$MountDir\Program Files\WindowsPowerShell\Modules"
Save-Module -Name HPCMSL -Path "$MountDir\Program Files\WindowsPowerShell\Modules" -AcceptLicense
Save-Module -name OSD -Path "$MountDir\Program Files\WindowsPowerShell\Modules"
#Set Execution Policy Bypass on boot WIM.
Set-WindowsImageExecutionPolicy -ExecutionPolicy Bypass -Path $MountDir


#Dismount and Save WinPE Image
Dismount-WindowsImage -Path $MountDir -Save

#endregion


#Add Drivers 
# Add-WindowsDriver -Path "c:\offline" -Driver "c:\test\drivers" -Recurse
Mount-WindowsImage -Path $MountDir -ImagePath "$WinPE_ARM64WorkSpace\media\sources\boot.wim" -Index 1
Add-WindowsDriver -Path $MountDir -Driver "$WinPE_ARM64WorkSpace\Drivers" -Recurse #This will be a folder of drivers you collect to add to your WinPE... good luck
Dismount-WindowsImage -Path $MountDir -Save

#Create the USBStick
New-OSDCloudUSB -WorkspacePath $WinPE_ARM64WorkSpace\
