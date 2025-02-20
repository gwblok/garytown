<# Notes
This script will download and install Dell Command Integration Suite if it is not already installed, then get the warranty information for the system
If you do NOT want to download and install the Dell Command Integration Suite, you can do it on a single test machine,
and then copy the C:\Program Files (x86)\Dell\CommandIntegrationSuite\ folder (yes, all of the stuff in the folder) to your own "package".

Since I'm hosting this script on GitHub, I didn't want to host the Dell Warranty CLI files, so I'm downloading the entire Suite Installer from Dell's site.

If my explaination of how you could create your own package to use doesn't make sense, let me know, and I'll try to explain it better.
#>


function Get-DellWarrantyInfo {
    #This will download and install Dell Command Integration Suite if it is not already installed, then get the warranty information for the system
    #Dell Command Integration Suite needs to be installed on the system
    #https://dl.dell.com/topicspdf/command-integration-suite_users-guide2_en-us.pdf

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ServiceTag,
        [switch]$Cleanup #Uninstalls Dell Command Integration Suite after running
    )
    # Get the service tag
    if (!($ServiceTag)) {
        $Manf = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Manufacturer
        Write-Verbose -Message "Manufacturer: $Manf"
        if ($Manf -match "Dell") {
            $ServiceTag = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
            
        } else {
            Write-Host "This script is only for Dell systems, or pass it a ServiceTag" -ForegroundColor Red
            if ($Cleanup) {
                write-verbose "Cleanup"
                Write-Verbose -Message "Start-Process -FilePath $DCWarrMSI -ArgumentList `"/s /V/qn /x`" -Wait -NoNewWindow"        
                Start-Process -FilePath $DCWarrMSI -ArgumentList "/s /V/qn /x" -Wait -NoNewWindow
            }
            return
        }
    }
    Write-Verbose -Message "Service Tag: $ServiceTag"

    $ScratchDir = "$env:TEMP\Dell"
    if (-not (Test-Path $ScratchDir)) { New-Item -ItemType Directory -Path $ScratchDir |out-null }
    $DellWarrantyCLIPath = "C:\Program Files (x86)\Dell\CommandIntegrationSuite\DellWarranty-CLI.exe"

    if (-not(Test-Path $DellWarrantyCLIPath)){

        #Download and install Dell Command Integration Suite (DellWarranty-CLI.exe) and Install
        $DCWarrURL = 'http://dl.dell.com/FOLDER12624112M/1/Dell-Command-Integration-Suite-for-System-Center_G31J8_WIN64_6.6.0_A00.EXE'
        $DCWarrPath = "$ScratchDir\Dell-Command-Integration-Suite-for-System-Center_G31J8_WIN64_6.6.0_A00.EXE"
        Write-Verbose -Message "Downloading Dell Command Integration Suite"
        Start-BitsTransfer -Source $DCWarrURL -Destination $DCWarrPath -CustomHeaders "User-Agent:BITS 42"
        Write-Verbose -Message "Installing Dell Command Integration Suite"
        write-verbose -Message "Start-Process -FilePath $DCWarrPath -ArgumentList `"/S /E=$ScratchDir`" -Wait -NoNewWindow"
        Start-Process -FilePath $DCWarrPath -ArgumentList "/S /E=$ScratchDir" -Wait -NoNewWindow
        $DCWarrMSI = Get-ChildItem -Path $ScratchDir -Filter 'DCIS*.exe' | Select-Object -ExpandProperty FullName
        write-verbose -Message "Start-Process -FilePath $DCWarrMSI -ArgumentList `"/S /V/qn`" -Wait -NoNewWindow"
        Start-Process -FilePath $DCWarrMSI -ArgumentList "/S /V/qn" -Wait -NoNewWindow
    }


    $CSVPath = "$env:programdata\Dell\ServiceTag.csv"
    if (-not (Test-Path "$env:programdata\Dell")) { New-Item -ItemType Directory -Path "$env:programdata\Dell" |out-null }
    if ($ServiceTag){$ServiceTag | Out-File -FilePath $CSVPath -Encoding utf8 -Force}
    else{Write-Host "No Service Tag found" -ForegroundColor Red; return}
    $ExportPath = "$env:programdata\Dell\WarrantyExport.csv"
    Write-Verbose -Message "CSV Path: $CSVPath"
    write-verbose -Message "Export Path: $ExportPath"
    write-verbose -Message "Start-Process -FilePath $DellWarrantyCLIPath -ArgumentList `"/I=$($CSVPath) /E=$($ExportPath)`" -Wait -NoNewWindow"
    Start-Process -FilePath $DellWarrantyCLIPath -ArgumentList "/I=$($CSVPath) /E=$($ExportPath)" -Wait -NoNewWindow
    $Data = Get-Content -Path $ExportPath | ConvertFrom-Csv
    if ($Cleanup) {
        write-verbose "Cleanup"
        Write-Verbose -Message "Start-Process -FilePath $DCWarrMSI -ArgumentList `"/s /V/qn /x`" -Wait -NoNewWindow"        
        Start-Process -FilePath $DCWarrMSI -ArgumentList "/s /V/qn /x" -Wait -NoNewWindow
    }
    return $data
}