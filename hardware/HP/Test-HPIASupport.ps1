function Test-HPIASupport ([string]$PlatformID){

    $CabPath = "$env:TEMP\platformList.cab"
    $XMLPath = "$env:TEMP\platformList.xml"
    $PlatformListCabURL = "https://hpia.hpcloud.hp.com/ref/platformList.cab"
    if (!(Test-Path $CabPath)){
        Invoke-WebRequest -Uri $PlatformListCabURL -OutFile $CabPath -UseBasicParsing
    }
    if (!(Test-Path $XMLPath)){
        $Expand = expand $CabPath $XMLPath
    }
    [xml]$XML = Get-Content $XMLPath
    $Platforms = $XML.ImagePal.Platform.SystemID
    if ($PlatformID){
        $MachinePlatform = $PlatformID
        }
    else {
        $MachinePlatform = (Get-CimInstance -Namespace root/cimv2 -ClassName Win32_BaseBoard).Product
    }
    if ($MachinePlatform -in $Platforms){$HPIASupport = $true}
    else {$HPIASupport = $false}

    return $HPIASupport
    }
