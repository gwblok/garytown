<# Gary Blok - GARYTOWN.COM - @gwblok

Script for creating ARM64 Boot Media
Requires PS Module OSD as pre-req
    install-module -Name OSD

the OSD Module Code was created by David Segura
https://github.com/OSDeploy/OSD


#>

#Update these to suit your needs
$WinPE_ARM64WorkSpace = "C:\WinPE_ARM64_OSDWorkSpace"
$MountDir = "C:\WinPE_ARM64_MountDir"

#Default ADK Paths
$ADKPath = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit"
$ADKPathPE = "$ADKPath\Windows Preinstallation Environment"



if (Test-Path -Path $ADKPathPE){
    Write-Host "Found ADK PE: $ADKPathPE" -ForegroundColor Green
    $ADKImage = Get-WindowsImage -ImagePath "$ADKPathPE\arm64\en-us\winpe.wim" -Index 1
}
else {
    Write-Host "Did not detect ADK in path $ADKPathPE"
    throw
}
if (!(test-path -path "$WinPE_ARM64WorkSpace")){New-Item -Path $WinPE_ARM64WorkSpace -ItemType Directory | Out-Null}

#Create OSDCloud Template - This will build x64 template, no big deal, we'll replace later.
$OSDCloudTemplateName = 'ARM64'
if ((Get-OSDCloudTemplateNames) -notcontains "$OSDCloudTemplateName"){
    New-OSDCloudTemplate -Name ARM64
}

#Create the OSDCloud WorkSpace - This will be created based on the template, but we'll replace what we need
New-OSDCloudWorkspace -WorkspacePath $WinPE_ARM64WorkSpace


#Clean it out to replace with the ARM64 Stuff we'll build
Remove-Item -Path "$WinPE_ARM64WorkSpace\media\*" -Recurse -Force
Remove-Item -Path "$WinPE_ARM64WorkSpace\logs\*" -Recurse -Force
Remove-Item -Path "$WinPE_ARM64WorkSpace\*.iso" -Recurse -Force

#Create Media Folder Structure
Write-Host "Creating Media Folder Struture here: $WinPE_ARM64WorkSpace" -ForegroundColor Green
if (!(test-path -path "$WinPE_ARM64WorkSpace\media")){New-Item -Path "$WinPE_ARM64WorkSpace\media" -ItemType Directory | Out-Null}
if (!(test-path -path "$WinPE_ARM64WorkSpace\media\sources")){New-Item -Path "$WinPE_ARM64WorkSpace\media\sources" -ItemType Directory | Out-Null}
if (!(test-path -path "$WinPE_ARM64WorkSpace\media\EFI\Boot")){New-Item -Path "$WinPE_ARM64WorkSpace\media\EFI\Boot" -ItemType Directory | Out-Null}
if (!(test-path -path "$WinPE_ARM64WorkSpace\media\Boot")){New-Item -Path "$WinPE_ARM64WorkSpace\media\Boot" -ItemType Directory | Out-Null}
if (!(test-path -path "$WinPE_ARM64WorkSpace\media\EFI\Microsoft\Boot")){New-Item -Path "$WinPE_ARM64WorkSpace\media\EFI\Microsoft\Boot" -ItemType Directory | Out-Null}
if (!(test-path -path "$WinPE_ARM64WorkSpace\media\sources")){New-Item -Path "$WinPE_ARM64WorkSpace\media\sources" -ItemType Directory | Out-Null}
if (!(test-path -path "$WinPE_ARM64WorkSpace\fwfiles")){New-Item -Path "$WinPE_ARM64WorkSpace\fwfiles" -ItemType Directory | Out-Null}
if (!(Test-path -path $MountDir)){new-item -path $mountdir -ItemType directory -force | Out-Null}
#Copy Items needed from the ADK (copype)
Write-Host "Coping files from ADK to Workspace" -ForegroundColor Green
Write-Host -ForegroundColor Gray "$ADKPathPE\arm64\Media\ -> $WinPE_ARM64WorkSpace\media"
#copy-item -Path "$ADKPathPE\arm64\Media\*" -Destination "$WinPE_ARM64WorkSpace\media" -Recurse -Force
Copy-Item "$ADKPathPE\arm64\Media\*.efi" -Destination "$WinPE_ARM64WorkSpace\media" -Force -Verbose
Copy-Item "$ADKPathPE\arm64\Media\Boot\*" -Destination "$WinPE_ARM64WorkSpace\media\boot" -Force -Verbose
Copy-Item "$ADKPathPE\arm64\Media\EFI\Boot\*.efi" -Destination "$WinPE_ARM64WorkSpace\media\EFI\Boot" -Force -Verbose
Copy-Item "$ADKPathPE\arm64\Media\EFI\Microsoft\Boot\*" -Destination "$WinPE_ARM64WorkSpace\media\EFI\Microsoft\Boot" -Force -Verbose

Copy-item -path "$ADKPath\Deployment Tools\arm64\Oscdimg\efisys.bin" -Destination "$WinPE_ARM64WorkSpace\fwfiles"
Write-Host -ForegroundColor Gray "$ADKPathPE\arm64\en-us\winpe.wim -> $WinPE_ARM64WorkSpace\media\sources\boot.wim"
if (test-path -path "$WinPE_ARM64WorkSpace\media\sources\boot.wim"){
    Write-Host "Found Previous Boot Image" -ForegroundColor Yellow
    $BootImage = Get-WindowsImage -ImagePath "$WinPE_ARM64WorkSpace\media\sources\boot.wim" -Index 1
    Write-Host "Boot Image Info:" -ForegroundColor Yellow
    $BootImage
    if (($BootImage.ImageName -ne $ADKImage.ImageName) -and ($BootImage.Version -lt $ADKImage.Version)){
        Write-Host "Boot Image does not match ADK image for ARM, going to overwrite with one from ADK" -ForegroundColor Green
        copy-item -Path "$ADKPathPE\arm64\en-us\winpe.wim"-Destination "$WinPE_ARM64WorkSpace\media\sources\boot.wim" -Force
    }
}
else {
    copy-item -Path "$ADKPathPE\arm64\en-us\winpe.wim"-Destination "$WinPE_ARM64WorkSpace\media\sources\boot.wim" -Force
}


#region Update boot wim with the good stuff

#Mount WinPE Image
Write-Host "Mounting boot.wim and adding features from $ADKPathPE\ARM64\WinPE_OCs" -ForegroundColor Green
Mount-WindowsImage -Path $MountDir -ImagePath "$WinPE_ARM64WorkSpace\media\sources\boot.wim" -Index 1 | out-null

#Cabs to Install IN SPECIFIC ORDER
$CabNames =@('Dot3Svc','EnhancedStorage','MDAC','NetFx','PowerShell','Scripting','SecureBootCmdlets','WinPE-WMI','StorageWMI','PmemCmdlets','DismCmdlets','SecureStartup','x64-Support','PlatformId')
Write-Host -ForegroundColor Cyan "Feature List"
$CabNames

#Get Installed Features, this is handy if you're modifing it in the future
$InstallFeatures = Get-WindowsPackage -Path $mountdir | Where-Object {$_.PackageName -notmatch "en-US"}

#Start Adding Features
[int]$Counter = 0
[int]$MaxCount = $CabNames.Count
foreach ($CabName in $CabNames){
    $Counter ++
    Write-Host "Starting $CabName [$Counter of $MaxCount]" -ForegroundColor Green

    $Installed = $InstallFeatures | Where-Object {$_.PackageName -match $CabName}
    if ($Installed.PackageState -eq "Installed"){
        Write-Output " Already Installed"
    }
    else{
        $workingcab = $Null
        $workingcabenus = $Null
        $workingcab = get-childitem -Path "$ADKPathPE\ARM64\WinPE_OCs" -Filter *.cab | Where-Object {$_.Name -match $CabName}
        if ($workingcab){Add-WindowsPackage -Path $MountDir -PackagePath $workingcab.FullName -Verbose | Out-Null}
        $workingcabenus = get-childitem -Path "$ADKPathPE\ARM64\WinPE_OCs\en-us" -Filter *.cab | Where-Object {$_.Name -match $CabName}
        if ($workingcabenus){Add-WindowsPackage -Path $MountDir -PackagePath $workingcabenus.FullName -Verbose | Out-Null}

    }
}

#Add PS Modules to the Boot Image
write-host "Saving PowerShell Modules to boot.wim" -ForegroundColor Green
Save-Module -Name PowerShellGet -Path "$MountDir\Program Files\WindowsPowerShell\Modules"
Save-Module -Name PackageManagement -Path "$MountDir\Program Files\WindowsPowerShell\Modules"
Save-Module -Name HPCMSL -Path "$MountDir\Program Files\WindowsPowerShell\Modules" -AcceptLicense
Save-Module -name OSD -Path "$MountDir\Program Files\WindowsPowerShell\Modules"
#Set Execution Policy Bypass on boot WIM.
write-host "Setting Execution Policy of WinPE to Bypass" -ForegroundColor Green
Set-WindowsImageExecutionPolicy -ExecutionPolicy Bypass -Path $MountDir

#Add Extra Things I want (Please confirm you have these items in the locations listed)
$null = robocopy "$env:SystemRoot\System32" "$MountDir\Windows\System32" setx.exe /b /ndl /np /r:0 /w:0 /xj
$null = robocopy "$env:SystemRoot\System32" "$MountDir\Windows\System32" msinfo32.exe /b /ndl /np /r:0 /w:0 /xj
$null = robocopy "$env:SystemRoot\System32" "$MountDir\Windows\System32" msinfo32.exe.mui /s /b /ndl /np /r:0 /w:0 /xj
$null = robocopy "$env:SystemRoot\System32" "$MountDir\Windows\System32" curl.exe /b /ndl /np /r:0 /w:0 /xj
$null = robocopy "$env:SystemRoot\System32" "$MountDir\Windows\System32" cmtrace.exe /b /ndl /np /r:0 /w:0 /xj


#Dismount and Save WinPE Image
Dismount-WindowsImage -Path $MountDir -Save


#Add some extra stuff for OSDCloud, this also creates the boot ISO files if you are testing on an ARM64 VM.
write-host "Updating BootWim with OSDCloud Enhancements: [Edit-OSDCloudWinPE]" -ForegroundColor Green
Edit-OSDCloudWinPE #Only needs defaults, but feel free to use this to set the Wallpaper among many other options

#endregion



#Add Drivers 
# Add-WindowsDriver -Path "c:\offline" -Driver "c:\test\drivers" -Recurse
if (Test-Path "$WinPE_ARM64WorkSpace\Drivers"){
    write-host "Adding Drivers from $WinPE_ARM64WorkSpace\Drivers to boot image" -ForegroundColor Green
    Mount-WindowsImage -Path $MountDir -ImagePath "$WinPE_ARM64WorkSpace\media\sources\boot.wim" -Index 1 | out-null
    Add-WindowsDriver -Path $MountDir -Driver "$WinPE_ARM64WorkSpace\Drivers" -Recurse | out-null #This will be a folder of drivers you collect to add to your WinPE... good luck
    Dismount-WindowsImage -Path $MountDir -Save | out-null
    write-host "Adding Drivers Complete" -ForegroundColor Green
}

<# Run the function based on first time, or follow up times.
#Create the USBStick - First time
New-OSDCloudUSB -WorkspacePath $WinPE_ARM64WorkSpace

#Update (for if you add drivers or modify your boot.wim file, which you'll do when you want to update the PS Modules)
Update-OSDCloudUSB
#>
