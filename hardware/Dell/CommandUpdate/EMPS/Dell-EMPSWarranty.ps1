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

    $ScratchDir = "$env:TEMP\Dell"
    if (-not (Test-Path $ScratchDir)) { New-Item -ItemType Directory -Path $ScratchDir |out-null }
    $DellWarrantyCLIPath = "C:\Program Files (x86)\Dell\CommandIntegrationSuite\DellWarranty-CLI.exe"

    if (-not(Test-Path $DellWarrantyCLIPath)){

        #Download and install Dell Command Integration Suite (DellWarranty-CLI.exe) and Install
        $DCWarrURL = 'http://dl.dell.com/FOLDER12624112M/1/Dell-Command-Integration-Suite-for-System-Center_G31J8_WIN64_6.6.0_A00.EXE'
        $DCWarrPath = "$ScratchDir\Dell-Command-Integration-Suite-for-System-Center_G31J8_WIN64_6.6.0_A00.EXE"
        Start-BitsTransfer -Source $DCWarrURL -Destination $DCWarrPath -CustomHeaders "User-Agent:BITS 42"
        Start-Process -FilePath $DCWarrPath -ArgumentList "/S /E=$ScratchDir" -Wait
        $DCWarrMSI = Get-ChildItem -Path $ScratchDir -Filter 'DCIS*.exe' | Select-Object -ExpandProperty FullName
        Start-Process -FilePath $DCWarrMSI -ArgumentList "/S /V/qn" -Wait -NoNewWindow
    }

    # Get the service tag
    if ($ServiceTag -eq $null) {
        $Manf = Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object -ExpandProperty Manufacturer
        if ($Manf -match "Dell") {
            $ServiceTag = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
        } else {
            Write-Host "This script is only for Dell systems, or pass it a ServiceTag" -ForegroundColor Red
            if ($Cleanup) {Start-Process -FilePath $DCWarrMSI -ArgumentList "/s /V/qn /x" -Wait -NoNewWindow}
            return
        }
    }
    
    $CSVPath = "$env:programdata\Dell\ServiceTag.csv"
    if (-not (Test-Path "$env:programdata\Dell")) { New-Item -ItemType Directory -Path "$env:programdata\Dell" |out-null }
    $ServiceTag | Out-File -FilePath $CSVPath -Encoding utf8 -Force
    $ExportPath = "$env:programdata\Dell\WarrantyExport.csv"
    Start-Process -FilePath $DellWarrantyCLIPath -ArgumentList "/I=$($CSVPath) /E=$($ExportPath)" -Wait -NoNewWindow -PassThru
    $Data = Get-Content -Path $ExportPath | ConvertFrom-Csv
    if ($Cleanup) {Start-Process -FilePath $DCWarrMSI -ArgumentList "/s /V/qn /x" -Wait -NoNewWindow}
    return $data
}