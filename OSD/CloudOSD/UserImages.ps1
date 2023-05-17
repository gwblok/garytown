<# Default Windows User Profile Images
Gary Blok @gwblok Recast Software

Used with OSDCloud Edition OSD

Grabs User Images from GitHub Repo and replaces default ones.
Just replace the RootURL with your own upload location

#>


try {$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment}
catch{Write-Output "Not in TS"}
if ($tsenv){$InWinPE = $tsenv.value('_SMSTSInWinPE')}

if ($InWinPE -ne "TRUE"){
Write-Output "Running in Full OS"
$InstallPath = "$env:ProgramData\Microsoft\User Account Pictures"
#Add Required Registry Value
Write-Output "Adding Value: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name UseDefaultTile -PropertyType DWORD -Value 1"
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "UseDefaultTile" -PropertyType DWORD -Value 1 -Force -Verbose

}

if ($InWinPE -eq "TRUE"){
Write-Output "Running in WinPE"

$InstallPath = "c:\ProgramData\Microsoft\User Account Pictures"
#Mount Registry & Add Required Registry Value
Write-Output "Mounting Offline Registry"
start-process -FilePath reg.exe -ArgumentList "load HKLM\Offline c:\windows\system32\config\software"
Write-Output "Adding Required Resistry Value"
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "UseDefaultTile" -PropertyType DWORD -Value 1 -Force -Verbose
Start-Sleep -s 2
Write-Output "Dismounting Registry"
[gc]::Collect()
start-process -FilePath reg.exe -ArgumentList "unload HKLM\Offline"
if (Test-Path -Path "HKLM:\Offline"){
    Start-Sleep -Seconds 2
    start-process -FilePath reg.exe -ArgumentList "unload HKLM\Offline" -Verbose

    }

}

$RootURL = "https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/UserPics/"
$Files = @(
"guest.png"
"user-192.png"
"user-200.png"
"user-32.png"
"user-40.png"
"user-48.png"
"user.png"
)


#Replace Contents with my Contents
foreach ($File in $Files){
    Write-Output "Downloading $RootURL/$File"
    Invoke-WebRequest -UseBasicParsing -Uri "$RootURL/$File" -OutFile "$env:TEMP\$File"
    Write-Output "Running Command: Copy-Item $($env:TEMP)\$File $InstallPath\$file -Force -Verbose"
    Copy-Item "$env:TEMP\$file" -Destination "$InstallPath\$file" -Force -Verbose
    }

Write-Output "Completed updating Default User Images Replacements"
