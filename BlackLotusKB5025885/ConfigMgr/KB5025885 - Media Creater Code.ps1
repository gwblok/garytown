param(
    [Parameter(Mandatory=$false)]
    [string]$WinPEPath
)

$TimeStamp = get-date -format yyyyMMdd
$MountPath = "c:\mount"
$WinPEIndex = '1'
Write-Output "======================================================================"
Write-Output "Starting WinPE Black Lotus Modifications"
Write-Output ""
Write-Output "WinPEPath:  $WinPEPath"
Write-Output "MountPath:  $MountPath"
Write-Output "WinPEIndex: $WinPEIndex"


$WinPEPath = (Get-ChildItem -Path $WinPEPath -Filter *.wim).FullName
if ($WinPEPath){
    if (Test-Path -Path $WinPEPath){
        Write-Output "Found WinPE: $WinPEPath"
        $WimName = (Get-ChildItem -Path $WinPEPath -Filter *.wim).Name
    }
    else{
        Write-Output "NO WinPE Found"
        exit 5
    }
}
else{
    Write-Output "NO WinPE Found"
    exit 5
}

# Clean up and create Mount directory
If (Test-Path $MountPath) {
    Write-Host "Cleaning up previous run: $MountPath" -ForegroundColor DarkGray
    Remove-Item $MountPath -Force -Verbose -Recurse
}
New-Item -Path $MountPath -ItemType Directory -Force | Out-Null

If (Test-Path "c:\UpdatedBoot.wim") {
    Write-Host "Cleaning up previous run: c:\UpdatedBoot.wim" -ForegroundColor DarkGray
    Remove-Item "c:\UpdatedBoot.wim" -Force -Verbose
}

Write-Output "Mount-WindowsImage -ImagePath $WinPEPath -Index $WinPEIndex -Path $MountPath"
Mount-WindowsImage -ImagePath $WinPEPath -Index $WinPEIndex -Path $MountPath

#Rename 2011 Signed Files to _2011
Rename-Item -Path "$MountPath\Windows\Boot\EFI" -NewName "EFI_2011" -Force -Verbose
Rename-Item -Path "$MountPath\Windows\Boot\Fonts" -NewName "Fonts_2011" -Force -Verbose
Rename-Item -Path "$MountPath\Windows\Boot\PXE" -NewName "PXE_2011" -Force -Verbose

#Rename updated Signed Files to Default Values

Rename-Item -Path "$MountPath\Windows\Boot\EFI_EX" -NewName "EFI" -Force -Verbose
Rename-Item -Path "$MountPath\Windows\Boot\Fonts_EX" -NewName "Fonts" -Force -Verbose
Rename-Item -Path "$MountPath\Windows\Boot\PXE_EX" -NewName "PXE" -Force -Verbose

#Rename Child Files

$EFIFiles = Get-Childitem -Path "$MountPath\Windows\Boot\EFI" -Filter *_EX*.* -Recurse
foreach ($File in $EFIFiles){
    $NewName = $File.Name.Replace("_EX","")
    Rename-Item -Path $File.FullName -NewName $NewName  -Verbose
}

$FontFiles = Get-Childitem -Path "$MountPath\Windows\Boot\Fonts" -Filter *_EX*.* -Recurse
foreach ($File in $FontFiles){
    $NewName = $File.Name.Replace("_EX","")
    Rename-Item -Path $File.FullName -NewName $NewName  -Verbose
}

$PXEFiles = Get-Childitem -Path "$MountPath\Windows\Boot\PXE" -Filter *_EX*.* -Recurse
foreach ($File in $PXEFiles){
    $NewName = $File.Name.Replace("_EX","")
    Rename-Item -Path $File.FullName -NewName $NewName  -Verbose
}

Dismount-WindowsImage -Path $MountPath -Save

Copy-Item -Path $WinPEPath "c:\UpdatedBoot.wim"
if (Test-Path -path "G:\"){
    $WimName = $WimName.Replace(".wim","_2023.wim")
    Copy-Item -Path $WinPEPath "G:\$WimName"
}
