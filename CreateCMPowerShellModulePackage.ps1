#Run this on a machine that has the MEMCM Console Installed

#where you want the files copied, this will be the source of the package you create in CM
$PackageSourceFolder = "\\src\src$\Apps\Microsoft\ConfigurationManager\CMConsolePosh"



$ConfigModulePath = (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
$ConfigModuleFolder = $(Split-Path $env:SMS_ADMIN_UI_PATH)
# Grab the Commandlet and Copy the files the commandlet directly references... 
$ConfigModuleContent = Get-Content -Path $ConfigModulePath
foreach ($Line in $ConfigModuleContent | Where-Object {$_ -Match "AdminUI.PS" -and $_ -notmatch ".XML"})
    {
    #Write-Output $Line
    $Line = $Line.TrimEnd(",")
    $RemoveFront = $Line.Substring("1")
    $RemoveEnd = $Line.substring($Line.length -1, 1)        
    $File = $RemoveFront.TrimEnd($RemoveEnd)
    Write-Output $File
    if (Test-Path "$($ConfigModuleFolder)\$($File)" -ErrorAction SilentlyContinue) {Copy-Item -Path "$($ConfigModuleFolder)\$($File)" -Destination $PackageSourceFolder -Force}
    }

Copy-Item -Path "$ConfigModuleFolder\*.ps1xml" -Destination $PackageSourceFolder -Force
Copy-Item -Path "$ConfigModuleFolder\*.dll" -Destination $PackageSourceFolder -Force
Copy-Item -Path $ConfigModulePath -Destination $PackageSourceFolder -Force


#Test to Confirm you have what you need:
Import-Module "$($PackageSourceFolder)\ConfigurationManager.psd1"
