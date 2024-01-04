$AllPlats = Get-HPDeviceDetails -Match *
#$Platform = Get-HPDeviceDetails -Platform 82BD

<# Build Database of All HP Devices

EXAMPLE:
Platform           : 8C6C
Name               : HP Mini Conferencing PC with Zoom Rooms
DatefileFound      : True
Family             : U21
Platform Supported : True

#>

$AllPlatIDs = $AllPlats.systemid | Select-Object -Unique

$HPBIOSCheckTableArray = @()
foreach ($Platform in $AllPlatIDs){
    $datafilefound = $false
    $BIOSBin = $null
    $Family = $Null
    $PlatformSupported = $null
    $WindowsUpdateFile = $null

    Write-Host "Starting Platform $Platform " -ForegroundColor Cyan
    $Details = Get-HPDeviceDetails -Platform $Platform
    $Details
    $Count = $null
    $Count = $Details.Count
    if (!($Count)){$Count = '1'}
    $HPBIOSCheckTable = New-Object -TypeName PSObject
    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "Platform" -Value $Platform -Force
    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "SampleName" -Value $Details[0].Name -Force
    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "ModelCount" -Value $Count -Force
    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "DatefileFound" -Value "" -Force
    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "BIOSVersion" -Value "" -Force
    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "BIOSDate" -Value ""  -Force  
    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "Platform on WU" -Value "" -Force
    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "WUBIOSVersion" -Value "" -Force  
    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "WUBIOSCompare" -Value ""  -Force

    try {

        $BIOSPlatform = Get-HPBIOSUpdates -Platform $Platform
        $BIOSPlatformTableArray = @()
        foreach ($BIOS in $BIOSPlatform){
            $BIOSPlatformTable = New-Object -TypeName PSObject
            [version]$BIOSVer = $BIOS.ver
            $BIOSVer = [version]::new($BIOSVer.Major, $BIOSVer.Minor, $(if($BIOSVer.Build -eq -1){0}else{$BIOSVer.Build}), $(if($BIOSVer.Revision -eq -1){0}else{$BIOSVer.Revision}))
            $BIOSPlatformTable | Add-Member -MemberType NoteProperty -Name "Ver" -Value $BIOSVer  -Force
            $BIOSPlatformTable | Add-Member -MemberType NoteProperty -Name "Date" -Value $BIOS.Date  -Force
            $BIOSPlatformTableArray += $BIOSPlatformTable
        }

        $BIOSMeta = Get-HPBIOSUpdates -Platform $Platform -Latest
        $BIOSBin = $BIOSMeta.bin
        [version]$BIOSVer = $BIOSMeta.ver
        $BIOSVer = [version]::new($BIOSVer.Major, $BIOSVer.Minor, $(if($BIOSVer.Build -eq -1){0}else{$BIOSVer.Build}), $(if($BIOSVer.Revision -eq -1){0}else{$BIOSVer.Revision}))

        $BIOSDate = $BIOSMeta.Date
        $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "DatefileFound" -Value $true -Force
        $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "BIOSVersion" -Value "$BIOSVer" -Force
        $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "BIOSDate" -Value $BIOSDate  -Force

    }
    catch {
        Write-Host "Unable to retrieve BIOS data (data file not found)."
        $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "DatefileFound" -Value $false -Force   

    }
    if ($BIOSBin){
        $Family = $BIOSBin.Split("_")[0]
        $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "Family" -Value $Family -Force

        Write-Host " Determined Family to be: $family" -ForegroundColor Green
    }
    else {
        $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "Family" -Value "NA" -Force
    }   
        Write-Host " BIOS Version:        $BIOSVer"
        Write-Host " BIOS Date:           $BIOSDate"
    if ($Family){
        try {
            $WUBIOS = Get-HPBIOSWindowsUpdate -Family $Family -ErrorAction SilentlyContinue
            [Version]$WUBIOSVer = $WUBIOS.Version
            $WUBIOSVer = [version]::new($WUBIOSVer.Major, $WUBIOSVer.Minor, $(if($WUBIOSVer.Build -eq -1){0}else{$WUBIOSVer.Build}), $(if($WUBIOSVer.Revision -eq -1){0}else{$WUBIOSVer.Revision}))

            $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "Platform on WU" -Value $true -Force
            $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "WUBIOSVersion" -Value "$WUBIOSVer" -Force


            if ($WUBIOSVer -eq $BIOSVer){
                Write-Host " WU Version Match:    $WUBIOSVer" -ForegroundColor Green
                $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "WUBIOSCompare" -Value "Match"  -Force
                
            }
            else {
                Write-Host " WU Version Mismatch: $WUBIOSVer" -ForegroundColor Red
                
                if ($WUBIOSVer -lt $BIOSVer){
                    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "WUBIOSCompare" -Value "Older"  -Force
                    $Date = $BIOSPlatformTableArray | Where-Object {$_.ver -match $WUBIOSVer}
                    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "WUBIOSDate" -Value $Date.date  -Force
                    if ($Date){Write-Host " WU BIOS Date:        $($Date.date)" -ForegroundColor Red}
                }
                else {
                    $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "WUBIOSCompare" -Value "Newer"  -Force
                }
            } 
            $PlatformSupported = $true
            
        }
        catch {
            $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "Platform on WU" -Value $false -Force
            $PlatformSupported = $false
            
        }
    }
    else {
        $HPBIOSCheckTable | Add-Member -MemberType NoteProperty -Name "Platform on WU" -Value $false -Force
    }

    #>

    Write-Host "------------------------------------------------------" -ForegroundColor DarkGray
    $HPBIOSCheckTableArray += $HPBIOSCheckTable
}

$HPBIOSCheckTableArray | ConvertTo-Json | Out-File -FilePath d:\WUvsHPBiosVersions.json
