$DiscNumber = "5"
$Path = "C:\Users\GaryBlok\OneDrive\SonosMusicLibrary\Adventures in Odyssey"
$Folders = get-childitem -Path $Path -Recurse -Directory | Where-Object {$_.Attributes -match "Directory"}
$Folders = $Folders | Where-Object {$_.Name -match "Hall of Faith Disc"}
#$Files = get-childitem -Path $Path -Recurse -File | Where-Object {$_.Name -match ".mp3"}

$DestinationPath = "C:\Users\GaryBlok\OneDrive\SonosMusicLibrary\Adventures in Odyssey\Hall of Faith Collection"

Foreach ($Folder in $Folders){
    $DiscNumber = $Folder.Name.remove(0, ($($Folder.Name).Length - 2))
    $DiscNumber = $DiscNumber.Trim()
    if ($DiscNumber.length -eq 1){
        $DiscNumber = "0$DiscNumber"
    }   
    $Files = get-childitem -Path $Folder -Recurse -File | Where-Object {$_.Name -match ".mp3"}
    foreach ($File in $Files){
        Write-Output "$(($File.Name).Insert(0,"Disc $DiscNumber - "))"
        Rename-Item -Path $File.FullName -NewName "$(($File.Name).Insert(0,"Disc $DiscNumber - "))"
    }
    $Files = get-childitem -Path $Folder -Recurse -File | Where-Object {$_.Name -match ".mp3"}
    foreach ($File in $Files){
        Write-Output "$DestinationPath\$($File.Name)"
        Move-Item -Path $file.FullName -Destination "$DestinationPath\$($File.Name)"
    }
}

$SettingsList = Get-CimInstance -Namespace root\hp\instrumentedBIOS -ClassName HP_BIOSEnumeration
$SettingsList | Select-Object -Property Name, CurrentValue

$SettingsList = Get-CimInstance -Namespace root\hp\instrumentedBIOS -ClassName HP_BIOSSetting
$SettingsList | Select-Object -Property Name, CurrentValue, Value
$SettingsList | Where-Object {$_.Name -match "Asset"}


<#  BCU to HPCMSL converter Script
You can get fancy and update the code to cycle through your BCU config files and add them into your $RAWConfigs Array, or manually add the files like I show with 2 config files
This script will go config file by config file, grabbing the settings and create a "database" of settings and values
It will take that data and create a JSON object that can be used in a PowerShell script to set the BIOS settings

It will then build the PS Script Sample to set the BIOS settings
Take that ps1 file it creates and modify as needed
Update the Scripts Path to where you want the PS1 file created.
#>

#Gather BCU Data from Config Files and Create JSON object for use in PowerShell Script
#region Gather
$RAWConfig1 = Get-Content -Path D:\HP840G5.BCUConfig -ReadCount 1
$RAWConfig2 = Get-Content -Path D:\HP840G5v2.BCUConfig -ReadCount 1

$RAWConfigs = @($RAWConfig1, $RAWConfig2)
#$RAWConfig = $RAWConfig[0..20]
$InfoDatabaseTotal = @()
Foreach ($RAWConfig in $RAWConfigs){
    $InfoDatabase = @()
    foreach ($Line in $RAWConfig | Where-Object {$_ -notmatch ";" -or $_ -notmatch "BIOSConfig"}){
        #Write-Output $Line
        $SettingName = $null
        $SelectedValue = $null
        if ($Line -match ";" -or $Line -match "BIOSConfig"){
            #Do Nothing
        }
        else {
            if ($Line -notmatch "`t"){
                $SettingName = "$($Line.Trim())"
                $LN = $Line.ReadCount
                Write-Host "$SettingName" -ForegroundColor green
                
                $NextTen = $RAWConfig[$LN..($LN+10)]
                #$NextTen
                foreach ($NextLine in $NextTen){
                    #Write-Output $NextLine
                    if ($NextLine -match "`t"){
                        #Setting Value
                        
                        if ($NextLine -like '*`**'){
                            #Selected Setting Value
                            $SelectedValue = "$($(($NextLine.Split("`t")[1]).Replace('*','')).Trim())"
                            Write-Host $SelectedValue -ForegroundColor Cyan
                            break
                            
                        }
                        else {
                           $SelectedValue = $null
                            #ExtraSetting Value
                            #$ExtraValue = "$($(($NextLine.Split("`t")[1]).Trim()))"
                        }
                    }
                    else {
                        break
                    }
                }
                if ($null -ne $SelectedValue){
                    $InfoObject = New-Object PSObject -Property @{
                        SettingName      = $SettingName
                        SelectedValue    = $SelectedValue
                        }
                    $InfoDatabase += $InfoObject
                    #$InfoDatabase = $InfoDatabase | Sort-Object -Property SettingName
                }
            }
        }
    }
    $InfoDatabaseTotal  += $InfoDatabase
}
$SettingNames = $InfoDatabaseTotal.SettingName | Select-Object -Unique
$Database = @()
ForEach ($SettingName in $SettingNames){
    $ItemWorking = $null
    $ItemWorking = $InfoDatabaseTotal | Where-Object {$_.SettingName -eq $SettingName} | Select-Object -Unique
    $Database += $ItemWorking 
}

$JSONDatabase = $Database | ConvertTo-Json

#endregion

#Create PowerShell Script to Set BIOS Settings
#region
$ScriptsPath = "C:\"

if (!(Test-Path -Path $ScriptsPath)){New-Item -Path $ScriptsPath} 

$BIOSScript = @(@{ Script = "HPBIOSSettings"; ps1file = 'HPBIOSSettings.ps1';Type = 'Setup'; Path = "$ScriptsPath"})


Write-Output "Creating $($BIOSScript.Script) Files"

$PSFilePath = "$($BIOSScript.Path)\$($BIOSScript.ps1File)"
        
#Create PowerShell File to do actions
        
New-Item -Path $PSFilePath -ItemType File -Force
Add-Content -path $PSFilePath '$SettingsDataJSON = @"'
Add-Content -Path $PSFilePath $JSONDatabase
Add-Content -path $PSFilePath '"@'
Add-Content -path $PSFilePath '$SettingsData = $SettingsDataJSON | ConvertFrom-Json'


Add-Content -path $PSFilePath 'foreach ($Setting in $SettingsData) {'
Add-Content -path $PSFilePath '    Write-Output "Attempting to Set $($Setting.SettingName) to $($Setting.SelectedValue)"'
Add-Content -path $PSFilePath '    try {Set-HPBIOSSettingValue -Name $Setting.SettingName -Value $Setting.SelectedValue}'
Add-Content -path $PSFilePath '    catch {Write-Output "Setting $($Setting.SettingName) Does Not Exist or Failed to set"}'
Add-Content -path $PSFilePath '}'

#endregion
