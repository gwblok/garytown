Function Install-Update {
    [CmdletBinding()]
    Param (
    [Parameter(Mandatory=$true)]
	$UpdatePath
    )

    $scratchdir = 'C:\OSDCloud\Temp'
    if (!(Test-Path -Path $scratchdir)){
        new-item -Path $scratchdir | Out-Null
    }

    if ($env:SystemDrive -eq "X:"){
        $Process = "X:\Windows\system32\Dism.exe"
        $DISMArg = "/Image:C:\ /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
    }
    else {
        $Process = "C:\Windows\system32\Dism.exe"
        $DISMArg = "/Online /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
    }


    Write-Output "Starting Process of $Process -ArgumentList $DismArg -Wait"
    $DISM = Start-Process $Process -ArgumentList $DISMArg -Wait -PassThru
    
    return $DISM.ExitCode
}


$23H2EnablementCabURL = "https://raw.githubusercontent.com/gwblok/garytown/master/SoftwareUpdates/Windows11.0-kb5027397-x64.cab"
Invoke-WebRequest -UseBasicParsing -Uri $23H2EnablementCabURL -OutFile "$env:TEMP\Windows11.0-kb5027397-x64.cab"

if (Test-Path -Path "$env:TEMP\Windows11.0-kb5027397-x64.cab"){
    Install-Update -UpdatePath "$env:TEMP\Windows11.0-kb5027397-x64.cab"
}
