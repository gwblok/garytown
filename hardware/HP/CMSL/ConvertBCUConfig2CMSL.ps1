
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
Add-Content -path $PSFilePath '    catch {Write-Output "Setting $($Setting.SettingName) Does Not Exist"}'
Add-Content -path $PSFilePath '}'

#endregion
