Function Remove-OldOSDModulesLocalMachine {
    #Clean Up OSD Modules - Non-Current on Local Machine
    $Folder = Get-ChildItem 'C:\Program Files\WindowsPowerShell\Modules\OSD'
    if ($Folder.Count -gt 1){
        $LatestFolder = $Folder | Sort-Object -Property Name | Select-Object -Last 1
        write-host "Latest Module: $($LatestFolder.Name)" -ForegroundColor Green
        Foreach ($Item in $Folder){
         if ( $Item.Name -ne $LatestFolder.Name){
            write-host "Removing $($Item.FullName)" -ForegroundColor Yellow
            Remove-item -Path $Item.FullName -Force -Recurse
            }        
        }
    }
    else {
        write-host "Latest Module: $($Folder.Name)" -ForegroundColor Green
    }
}
Function Get-7ZipIntoPE {
    param (
        $MountPath = 'C:\mount'
    )
    write-host "Mounting: $(Get-OSDCloudWorkspace)\Media\sources\boot.wim to $MountPath"  -ForegroundColor Green
    Mount-WindowsImage -Path $MountPath -ImagePath "$(Get-OSDCloudWorkspace)\Media\sources\boot.wim" -Index 1 -Verbose

    Write-Host -ForegroundColor Yellow "7Zip for Extracting Driver Packs in WinPE"
    $Latest = Invoke-WebRequest -Uri https://github.com/ip7z/7zip/releases/latest -UseBasicParsing
    $NextLink = ($Latest.Links | Where-Object {$_.href -match "releases/tag"}).href
    $Version = $NextLink.Split("/")[-1]
    $VersionClean = ($Version).Replace(".","")
    $FileName = "7z$VersionClean-extra.7z"
    # Example: https://github.com/ip7z/7zip/releases/download/24.07/7z2407-extra.7z
    $Download7zrURL = "https://github.com/ip7z/7zip/releases/download/$Version/7zr.exe"
    $DownloadURL ="https://github.com/ip7z/7zip/releases/download/$Version/$fileName"

    Write-Host -ForegroundColor DarkGray "Downloading $DownloadURL"
    Invoke-WebRequest -Uri $Download7zrURL -OutFile "$env:TEMP\7zr.exe" -UseBasicParsing
    Invoke-WebRequest -Uri $DownloadURL -OutFile "$env:TEMP\$FileName" -UseBasicParsing
    if (Test-Path -Path $env:TEMP\$FileName){
        Write-Host -ForegroundColor DarkGray "Extracting $env:TEMP\$FileName"
        #$null = & "$env:temp\7zr.exe" x "$env:TEMP\$FileName" -o"$MountPath\Windows\System32" -y
        $null = & "$env:temp\7zr.exe" x "$env:TEMP\$FileName" -o"$env:temp\7zip" -y
        Copy-Item -Path "$env:temp\7zip\x64\*" -Destination "$MountPath\Windows\System32" -Recurse -Force -verbose
    }
    else {
        Write-Warning "Could not find $env:TEMP\$FileName"
    }
    
    #Dismount - Save
    Dismount-WindowsImage -Path $MountPath -Save
}

Function Remove-OldOSDModulesInWinPE {
#Custom Changes to Boot.Wim
    param (
        $MountPath = 'C:\mount'
    )
    write-host "Mounting: $(Get-OSDCloudWorkspace)\Media\sources\boot.wim to $MountPath"  -ForegroundColor Green
    Mount-WindowsImage -Path $MountPath -ImagePath "$(Get-OSDCloudWorkspace)\Media\sources\boot.wim" -Index 1 -Verbose

    #Clear out Extra OSD modules
    $Folder = Get-ChildItem "$MountPath\Program Files\WindowsPowerShell\Modules\OSD"
    if ($Folder.Count -gt 1){
        $LatestFolder = $Folder | Sort-Object -Property Name | Select-Object -Last 1
        write-host "Latest Module: $($LatestFolder.Name)" -ForegroundColor Green
        Foreach ($Item in $Folder){
         if ( $Item.Name -ne $LatestFolder.Name){
            write-host "Removing $($Item.FullName)" -ForegroundColor Yellow
            Remove-item -Path $Item.FullName -Force -Recurse
            }        
        }
    }
    else {
        write-host "Latest Module: $($Folder.Name)" -ForegroundColor Green
    }
    #Dismount - Save
    Dismount-WindowsImage -Path $MountPath -Save
}

$OSDCloudRootPath = "C:\OSDCloud-ROOT"
$ADKPaths = Get-AdkPaths -ErrorAction SilentlyContinue
if (!($ADKPaths)){
    Write-Host "NO ADK Found, resolve and try again" -ForegroundColor Red
    break
}
$ADKPath = $ADKPaths.PathWinPE
$ADKWinPE = Get-ChildItem -Path $ADKPaths.PathWinPE -Filter *.wim -Recurse
$ADKWinPEInfo = Get-WindowsImage -ImagePath $ADKWinPE.FullName -Index 1

Write-Host "ADK WinPE Version:       " -ForegroundColor Cyan -NoNewline
Write-Host "$($ADKWinPEInfo.Version)" -ForegroundColor Green
Write-Host "ADK WinPE Architecture:  " -ForegroundColor Cyan -NoNewline
Write-Host "$($ADKWinPEInfo.ImageName)" -ForegroundColor Green


$Mappings = @(

@{ Build = '10.0.26100.1'; OSName = "Windows 11 24H2 x64"}
@{ Build = '10.0.22621.1'; OSName = "Windows 11 22H2 x64"}
@{ Build = '10.0.19045.1'; OSName = "Windows 10 22H2 x64"}

)
$OSNameNeeded = ($Mappings | Where-Object {$_.Build -match $ADKWinPEInfo.Version}).OSName
$Lang = ($ADKWinPE.FullName | Split-Path) | Split-Path -Leaf


$CU_MSU = Get-ChildItem -Path "$OSDCloudRootPath\Patches\CU\$OSNameNeeded" -Filter *.msu -ErrorAction SilentlyContinue
if ($CU_MSU){
    if ($CU_MSU.count -gt 1){
        $CU_MSU = $CU_MSU | Sort-Object -Property Name | Select-Object -Last 1
    }
    $PatchPath = $CU_MSU.FullName
    If ($PatchPath) {
        $AvailableCU = $PatchPath
        Write-Host -ForegroundColor Green "Available CU Found: $AvailableCU"
        #Write-Host -ForegroundColor DarkGray "Applying CU $PatchPath"
        #Add-WindowsPackage -Path $MountPath -PackagePath $PatchPath -Verbose
    }
}
else {
    write-host "No CU's found to apply to OS $OSNameNeeded"
}

<#
$GitHubFolder = "C:\Users\GaryBlok\OneDrive - garytown\Documents\GitHub - ZBook"
$LocalModuleFolder = Get-ChildItem 'C:\Program Files\WindowsPowerShell\Modules\OSD'
$OSDLocalModule = "$($LocalModuleFolder.FullName)"
copy-item "$GitHubFolder\OSD\*"   "$OSDLocalModule" -Force -Verbose -Recurse
#>

#Make Sure you're running 24.3.20.1
Update-Module -name OSD -Force

#Restart PowerShell after OSD has been updated (if it needed to be updated)

<#
#Setup WorkSpace Location
Import-Module -name OSD -force
$OSDCloudWorkspace = "C:\OSDCloudWinPE"
$OSDCloudWorkspaceWinRE = "C:\OSDCloudWinRE"
$OSDCloudWorkspaceARM64 = "C:\OSDCloudARM64"
[void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspace)
[void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspaceWinRE)
[void][System.IO.Directory]::CreateDirectory($OSDCloudWorkspaceARM64)

#New Template (After you've updated ADK to lastest Version)
New-OSDCloudTemplate -Name "OSDCloudWinPE"
New-OSDCloudTemplate -Name "OSDCloudWinRE" -WinRE
New-OSDCloudTemplate -Name "OSDCloudARM64" -ARM64

#New WorkSpace x64
Set-OSDCloudTemplate -Name OSDCloudWinPE
New-OSDCloudWorkspace -WorkspacePath $WorkSpacePath
New-OSDCloudWorkSpaceSetupCompleteTemplate

#>


$templateName = "OSDCloud-22H2WinPE"
$WorkSpacePath = "C:\$TemplateName"
$MountPath = "C:\Mount"

$DisplayLinkDriverPath = "C:\Users\GaryBlok\Downloads\DisplayLink USB Graphics Software for Windows11.4 M0-INF\x64"

if ($AvailableCU){
    New-OSDCloudTemplate -Name $templateName -CumulativeUpdate $AvailableCU -Add7Zip
}
else {
    New-OSDCloudTemplate -Name $templateName -Add7Zip
}
New-OSDCloudWorkspace -WorkspacePath $WorkSpacePath

Set-OSDCloudWorkspace -WorkspacePath $WorkSpacePath

#Edit-OSDCloudWinPE -CloudDriver HP,USB -Add7Zip -PSModuleInstall HPCMSL #7Zip is already in template now
Edit-OSDCloudWinPE -CloudDriver HP,USB -PSModuleInstall HPCMSL

#Added HPCMSL into WinPE
Edit-OSDCloudWinPE -PSModuleInstall HPCMSL

New-OSDCloudISO


#New WorkSpace ARM64

Set-OSDCloudTemplate -Name OSDCloudARM64
New-OSDCloudWorkspace -WorkspacePath $OSDCloudWorkspaceARM64


#Cleanup
if (Test-Path -Path "$(Get-OSDCloudWorkspace)\Media"){
    $Folders = get-childitem -path "$(Get-OSDCloudWorkspace)\Media"-Recurse | where-object {$_.Attributes -match "Directory" -and $_.Name -match "-" -and $_.Name -notmatch "en-us"}
    $Folders | Remove-Item -Force -Recurse
}
#Cleanup Languages
$KeepTheseDirs = @('boot','efi','en-us','sources','fonts','resources')
Get-ChildItem "$(Get-OSDCloudWorkspace)\Media" | Where {$_.PSIsContainer} | Where {$_.Name -notin $KeepTheseDirs} | Remove-Item -Recurse -Force
Get-ChildItem "$(Get-OSDCloudWorkspace)\Media\Boot" | Where {$_.PSIsContainer} | Where {$_.Name -notin $KeepTheseDirs} | Remove-Item -Recurse -Force
Get-ChildItem "$(Get-OSDCloudWorkspace)\Media\EFI\Microsoft\Boot" | Where {$_.PSIsContainer} | Where {$_.Name -notin $KeepTheseDirs} | Remove-Item -Recurse -Force


New-OSDCloudWorkSpaceSetupCompleteTemplate
Edit-OSDCloudWinPE -DriverPath "C:\OSDCloudARM64\WinPEDrivers\SurfaceProX\FileRepository"
Edit-OSDCloudWinPE -DriverPath "C:\swsetup\Dock"
#Create Cloud USB
New-OSDCloudUSB

#Update the Cloud USB drive
#Note, I found I need to add some parameters for it to sync over everything properly.
Update-OSDCloudUSB -PSUpdate



#Custom Changes to Boot.Wim
write-host "Mounting: $(Get-OSDCloudWorkspace)\Media\sources\boot.wim"  -ForegroundColor Green
Mount-WindowsImage -Path $MountPath -ImagePath "$(Get-OSDCloudWorkspace)\Media\sources\boot.wim" -Index 1


#Copy Development Files - Overwrite production
$GitHubFolder = "C:\Users\GaryBlok\OneDrive - garytown\Documents\GitHub - ZBook"
$OSDMountedModuleFolder = Get-ChildItem "$MountPath\Program Files\WindowsPowerShell\Modules\OSD"
$OSDMountedModule = "$($OSDMountedModuleFolder.FullName)"

#Update Boot WIM
write-host "Updating Module in Boot WIM from Dev Source" -ForegroundColor Green
if (($GitHubFolder) -and ($OSDMountedModule) -and ($MountPath)){
    copy-item "$GitHubFolder\OSD\*"   "$OSDMountedModule" -Force -Recurse
    Copy-Item "C:\OSDCloudWinPE\Config\cmtrace.exe" "$MountPath\Windows\System32\cmtrace.exe" -Force
}
#Update Local Module

#Dismount - Save
Dismount-WindowsImage -Path $MountPath -Save

#Update Flash Drive
Update-OSDCloudUSB
