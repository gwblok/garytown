#Gary Blok | @gwblok | Recast Software

Write-Output "Updating OEM Info"

try {$tsenv = new-object -comobject Microsoft.SMS.TSEnvironment}
catch{Write-Output "Not in TS"}

if ($tsenv){
    #Assumes you've created these TS Variables
    #This is slick because you could have different ones set based on location using dynamic variables / conditions
    $SupportHours = $tsenv.value('SupportHours')
    $SupportPhone = $tsenv.value('SupportPhone')
    $SupportUrl = $tsenv.value('SupportUrl')
    
    }

if (!($SupportHours)){$SupportHours = "9 AM - 5 PM"}
if (!($SupportPhone)){$SupportPhone = "0118 999 881 999 119 725 3"}
if (!($SupportUrl)){$SupportUrl = "https://www.recastsoftware.com/"}


$cs = Get-WmiObject -Class Win32_ComputerSystem
$manufacturer = $cs.Manufacturer
$model = $cs.Model

if(-not (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation"))
{
    New-Item -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion" -Name "OEMInformation"
}


#Download Logo from GitHub
$LogoURL = "https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/logo.bmp"
Invoke-WebRequest -UseBasicParsing -Uri $LogoURL -OutFile "$env:TEMP\logo.bmp"

#Copy the file into place
if (Test-Path -Path "$env:TEMP\logo.bmp"){
    Write-Output "Running Command: Copy-Item $($env:TEMP)\logo.bmp $env:windir\system32\OEMLogo.bmp -Force -Verbose"
    Copy-Item "$env:TEMP\logo.bmp" -Destination "$env:windir\system32\OEMLogo.bmp" -Force -Verbose
    if (Test-Path -Path "$env:windir\system32\OEMLogo.bmp"){
        New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation" -Name Logo -PropertyType String -Value "$env:windir\system32\OEMLogo.bmp" -Force
        Write-Output "Updated Logo"
        }
    else {
        Write-Output "Failed to find OEMLogo.bmp in $env:windir\system32"
        }
    }
else
    {
    Write-Output "Did not find Logo.bmp in temp folder - Please confirm URL"
    }





New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation" -Name Manufacturer -PropertyType String -Value $manufacturer -Force
Write-Output "Set Manufacturer to $manufacturer"

New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation" -Name Model -PropertyType String -Value $model -Force
Write-Output "Set model to $model"

New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation" -Name SupportHours -PropertyType String -Value $SupportHours -Force
Write-Output "Set SupportHours to $SupportHours"

New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation" -Name SupportPhone -PropertyType String -Value $SupportPhone -Force
Write-Output "Set SupportPhone to $SupportPhone"

New-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\OEMInformation" -Name SupportUrl -PropertyType String -Value $SupportUrl -Force
Write-Output "Set SupportUrl to $SupportUrl"
