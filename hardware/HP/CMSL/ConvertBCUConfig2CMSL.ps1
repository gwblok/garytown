
$RAWConfig = Get-Content -Path D:\HP840G5.BCUConfig -ReadCount 1
#$RAWConfig = $RAWConfig[0..20]
$InfoDatabase = @()
foreach ($Line in $RAWConfig | Where-Object {$_ -notmatch ";" -or $_ -notmatch "BIOSConfig"}){
    #Write-Output $Line
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
                        #ExtraSetting Value
                        #$ExtraValue = "$($(($NextLine.Split("`t")[1]).Trim()))"
                    }
                }
            }
            $InfoObject = New-Object PSObject -Property @{
                SettingName      = $SettingName
                SelectedValue    = $SelectedValue
                }
            $InfoDatabase += $InfoObject
        }
    }
}
