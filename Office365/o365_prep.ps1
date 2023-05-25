<#
.Synopsis
   Office 365 Prep Utility
.DESCRIPTION
   Utility script to remove previous Office Versions and related Office packages
.EXAMPLE
   #Deploy and run with ConfigMgr preceding an Office 365 Install
   #Log file will be made at "C:\Windows\Temp\Office365_Prep.log"
.NOTES
  Modified from code copyright 2018-2020 Brian Thorp - https://github.com/hypercube33/SCCM/blob/master/Detect_Report_Remove_1909_G3%20Scrubbed.ps1
#>
    Param
    (
        # Windows Version Info
        [Parameter(Mandatory=$false,                 
                   Position=0)]
        $OSVersion = "1909"
    )

$Global:ScriptVersion   = "0.5"
$Global:CMLogFilePath   = "C:\Windows\Temp\Office365_Prep.log"
$Global:CMLogFileSize   = "40"

#############################################################################
#If Powershell is running the 32-bit version on a 64-bit machine, we 
#need to force powershell to run in 64-bit mode .
#############################################################################
if ($env:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    write-warning "Y'arg Matey, we're off to 64-bit land....."
    if ($myInvocation.Line) {
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile $myInvocation.Line
    }else{
        &"$env:WINDIR\sysnative\windowspowershell\v1.0\powershell.exe" -NonInteractive -NoProfile -file "$($myInvocation.InvocationName)" $args
    }
exit $lastexitcode
}

function Start-CMTraceLog
{
    # Checks for path to log file and creates if it does not exist
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
            
    )

    $indexoflastslash = $Path.lastindexof('\')
    $directory = $Path.substring(0, $indexoflastslash)

    if (!(test-path -path $directory))
    {
        New-Item -ItemType Directory -Path $directory
    }
    else
    {
        # Directory Exists, do nothing    
    }
}

function Write-CMTraceLog
{
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
            
        [Parameter()]
        [ValidateSet(1, 2, 3)]
        [int]$LogLevel = 1,

        [Parameter()]
        [string]$Component,

        [Parameter()]
        [ValidateSet('Info','Warning','Error')]
        [string]$Type
    )
    $LogPath = $Global:CMLogFilePath

    Switch ($Type)
    {
        Info {$LogLevel = 1}
        Warning {$LogLevel = 2}
        Error {$LogLevel = 3}
    }

    # Get Date message was triggered
    $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"

    $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">'

    # When used as a module, this gets the line number and position and file of the calling script
    # $RunLocation = "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)"

    $LineFormat = $Message, $TimeGenerated, (Get-Date -Format MM-dd-yyyy), $Component, $LogLevel
    $Line = $Line -f $LineFormat

    # Write new line in the log file
    Add-Content -Value $Line -Path $LogPath

    # Roll log file over at size threshold
    if ((Get-Item $Global:CMLogFilePath).Length / 1KB -gt $Global:CMLogFileSize)
    {
        $log = $Global:CMLogFilePath
        Remove-Item ($log.Replace(".log", ".lo_"))
        Rename-Item $Global:CMLogFilePath ($log.Replace(".log", ".lo_")) -Force
    }
} 

# Start up the logs
Start-CMTraceLog -Path $Global:CMLogFilePath

Write-CMTraceLog -Message "=====================================================" -Type "Info" -Component "Main"
Write-CMTraceLog -Message "Starting Script version $Global:ScriptVersion..." -Type "Info" -Component "Main"
Write-CMTraceLog -Message "=====================================================" -Type "Info" -Component "Main"

# Function to find MSI-based Uninstallers and Run their uninstall silently
function Remove-OfficeBlocker
{
    param(
        [string]$DisplayName,
        [switch]$OfficeShim
    )

    Write-CMTraceLog -Message "Start Detection of: $DisplayName" -Type "Info" -Component "Main"
        
    # determine if X64 Process, used to know where to look for app information in the registry
    [boolean]$Is64Bit = [boolean]((Get-WmiObject -Class 'Win32_Processor' -ErrorAction 'SilentlyContinue' | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty 'AddressWidth') -eq 64)

    $path = "\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $pathwow6432 = "\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"

    # =============================================================================
    # -----------------------------------------------------------------------------
    # Run regular code to check for install status
    # Note that this code chunk probably should be updated to the 2020 version~
    # -----------------------------------------------------------------------------
    # Pre-Flight Null
    $32bit = $false
    $64bit = $false
    $Installed = $null
    $Installedwow6432 = $null
    # write-host "Software Name:    $DisplayName"
    # write-host "Software Version: $Version"

    $Installed = Get-ChildItem HKLM:$path -Recurse -ErrorAction Stop | Get-ItemProperty -name DisplayName -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like $DisplayName}
    if ($is64bit)
    {
        $Installedwow6432 = Get-ChildItem HKLM:$pathwow6432 -Recurse -ErrorAction Stop | Get-ItemProperty -name DisplayName -ErrorAction SilentlyContinue | Where-Object {$_.DisplayName -like $DisplayName}
    }

    # If found in registry,
    if ($null -ne $Installed)
    {
        Write-CMTraceLog -Message "   App detected in registry tree" -Type "Info" -Component "Main"

        foreach ($Entry in $Installed)
        {
            write-host "Removing $($Entry.displayname)"
            $Guid = $entry.Pschildname
            $RegistryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
            
            if ($OfficeShim) {
               $UninstallString = (Get-ItemPropertyValue -Path $RegistryPath -Name "UninstallString")
               }
            Else {
               $UninstallString = (Get-ItemPropertyValue -Path $RegistryPath -Name "UninstallString") + " /qn"
                
               if ($UninstallString -like("*/I*")){
               $UninstallString = $UninstallString -replace "/I", "/X"
               }
            }

            $filepath = $UninstallString.Split(" ","2")[0]
            $argumentlist = $UninstallString.Split(" ","2")[1]
            Write-Host $filepath $argumentlist
           
                Write-CMTraceLog -Message "   Attempting to uninstall $GUID | $UninstallString" -Type "Info" -Component "Main"

                $exitCode = (Start-process -FilePath $filepath -ArgumentList $argumentlist -Wait -passthru).ExitCode

                Write-CMTraceLog -Message "   Uninstall completed with exit code $($exitCode)" -Type "Info" -Component "Main"
            
        }
    }

    # If found in registry under Wow6432 path,
    if ($null -ne $Installedwow6432)
    {
        Write-CMTraceLog -Message "   App detected in Wow6432 registry tree" -Type "Info" -Component "Main"

        foreach ($Entry in $Installedwow6432)
        {
            write-host "Removing $($Entry.displayname)"
            $Guid = $entry.Pschildname
            $RegistryPath = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$GUID"
            if (Test-Path $RegistryPath)
            {
                if ($OfficeShim) {
                    $UninstallString = (Get-ItemPropertyValue -Path $RegistryPath -Name "UninstallString")
                }
                Else {
                    $UninstallString = (Get-ItemPropertyValue -Path $RegistryPath -Name "UninstallString") + " /qn"
                
                    if ($UninstallString -like("*/I*")){
                        $UninstallString = $UninstallString -replace "/I", "/X"
                    }
                }

                $filepath = $UninstallString.Split(" ","2")[0]
                $argumentlist = $UninstallString.Split(" ","2")[1]

                Write-CMTraceLog -Message "   Attempting to uninstall $GUID | $UninstallString" -Type "Info" -Component "Main"

                $exitCode = (Start-process -FilePath $filepath -ArgumentList $argumentlist -Wait -passthru).ExitCode

                Write-CMTraceLog -Message "   Uninstall completed with exit code $($exitCode)" -Type "Info" -Component "Main"
            }
        }
    }
}

#Remove-OfficeBlocker -DisplayName "Microsoft InfoPath*" 
#Remove-OfficeBlocker -DisplayName "Microsoft SharePoint Designer*" 
Remove-OfficeBlocker -DisplayName "Microsoft Access database engine*"
# Power Query is built-in to Excel now
Remove-OfficeBlocker -DisplayName "Microsoft Power Query for Excel" 
Remove-OfficeBlocker -DisplayName "Microsoft Visual Studio 2010 Tools for Office Runtime"
#Remove-OfficeBlocker -DisplayName "Skype for Business Web App Plug-in"
#Remove-OfficeBlocker -DisplayName "Microsoft Skype for Business MUI*"
#Remove-OfficeBlocker -DisplayName "Skype Meetings App"
Remove-OfficeBlocker -DisplayName "Phishme Reporter"
Remove-OfficeBlocker -DisplayName "Voltage Encryption v*"
Remove-OfficeBlocker -DisplayName "Office2016.ExcelCompatModeV1" -OfficeShim
Remove-OfficeBlocker -DisplayName "Office2016CompatMode" -OfficeShim

$appVPackages = @('VisioPro.2k7','Microsoft Office 2016 O365ProPlusRetail_en-us_x64','Microsoft_OfficeAccess2010SP2_ProPlus_14.0.7015.1000.19R3_V')
$AppvStatus = (Get-AppvStatus).AppvClientEnabled
If (-not $AppvStatus) {
    Write-CMTraceLog -Message "AppVClient not enabled...enabling AppVClient" -Type "Info" -Component "Main"
    Enable-Appv
    }

forEach($appvPackage in $appVPackages){
    Write-CMTraceLog -Message "Start Detection of App-V Package: $appvPackage" -Type "Info" -Component "Main"
    $PackageInfo = Get-AppvClientPackage -Name $appvPackage
    If ($PackageInfo){
        Write-CMTraceLog -Message "   Stopping App-V Package $PackageInfo" -Type "Info" -Component "Main"
        Stop-AppvClientPackage $PackageInfo
        Write-CMTraceLog -Message "   Removing App-V Package $PackageInfo" -Type "Info" -Component "Main"
        $exitCode = (Remove-AppvClientPackage $PackageInfo).ExitCode
        Write-CMTraceLog -Message "   Remove-AppvClientPackage completed with exit code $($exitCode)" -Type "Info" -Component "Main"
    }
}

#Info-Path Product Code
#$InfoPathProductCode = "{90160000-0044-0409-0000-0000000FF1CE}"
#Lync Product Code
$LyncProductCode = "{90160000-012B-0409-0000-0000000FF1CE}"
#SharePoint Designer Product Code
#$SharePointDesignerProductCode = "{90150000-0017-0409-0000-0000000FF1CE}"
#Office 2016 Uninstall Key and Product Code Property
$Office16Key = "HKLM:SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Office16.PROPLUS"
#SharePointDesigner Uninstall Key and Product Code Property
#$SharePointDesignerKey = "HKLM:SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Office15.SharePointDesigner"

#Office Setup Files
#$OfficeSetupFiles = "C:\Program Files (x86)\Common Files\microsoft shared\OFFICE16\Office Setup Controller"
#Office Setup Files - SharePoint Designer
#$OfficeSetupFilesSharePointDesigner = "C:\Program Files (x86)\Common Files\microsoft shared\OFFICE15\Office Setup Controller"
#Info-Path MUI Files
#$InfoPathMUIFiles = "C:\MSOCache\All Users\{90160000-0044-0409-0000-0000000FF1CE}-C"
#SharePoint Designer Files
#$SharePointDesignerFiles = "C:\MSOCache\All Users\{90150000-0017-0409-0000-0000000FF1CE}-C"
#Lync MUI Files
#$LyncMUIFiles = "C:\MSOCache\All Users\{90160000-012B-0409-0000-0000000FF1CE}-C"
#SharePoint Designer 2007 Registry Path
$SPD2007 = "HKLM:\SOFTWARE\Classes\Installer\Products\00002109710000000000000000F01FEC"

if ($InfoPathMUIFiles)
    {
    If ((Test-Path $InfoPathMUIFiles) -and (Test-Path $OfficeSetupFiles))
        {
        Write-CMTraceLog -Message "Copying InfoPath MUI Files from $InfoPathMUIFiles to $OfficeSetupFiles\InfoPath.en-us\" -Type "Info" -Component "Main"
        Copy-Item -Path "$InfoPathMUIFiles" -Destination "$OfficeSetupFiles\InfoPath.en-us" -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
if ($SharePointDesignerFiles)
    {
    If ((Test-Path $SharePointDesignerFiles) -and (Test-Path $OfficeSetupFilesSharePointDesigner))
        {
        Write-CMTraceLog -Message "Copying SharePoint Designer Files from $SharePointDesignerFiles to $OfficeSetupFilesSharePointDesigner\SharePointDesigner.en-us\" -Type "Info" -Component "Main"
        Copy-Item -Path "$SharePointDesignerFiles" -Destination "$OfficeSetupFilesSharePointDesigner\SharePointDesigner.en-us" -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
if ($LyncMUIFiles)
    {
    If ((Test-Path $LyncMUIFiles) -and (Test-Path $OfficeSetupFiles))
        {
        Write-CMTraceLog -Message "Copying Lync MUI Files from $LyncMUIFiles to $OfficeSetupFiles\Lync.en-us\" -Type "Info" -Component "Main"
        Copy-Item -Path "$LyncMUIFiles" -Destination "$OfficeSetupFiles\Lync.en-us" -Force -Recurse -ErrorAction SilentlyContinue
        }
    }

#Fix Office 2016 Registry
if ($Office16Key)
    {
    If (Test-Path $Office16Key) 
        {
        [System.Collections.ArrayList]$ProductCodes = (Get-ItemProperty -Path $Office16Key -Name "ProductCodes").("ProductCodes")
        }
    }

if ($InfoPathProductCode)
    {
    while ($ProductCodes -contains $InfoPathProductCode)
        {
        Write-CMTraceLog -Message "Removing the $InfoPathProductCode from $Office16Key\ProductCodes" -Type "Info" -Component "Main"
        $ProductCodes.Remove($InfoPathProductCode)
        }
    }
if ($LyncProductCode)
    {
    while ($ProductCodes -contains $LyncProductCode)
        {
        Write-CMTraceLog -Message "Removing the $LyncProductCode from $Office16Key\ProductCodes" -Type "Info" -Component "Main"
        $ProductCodes.Remove($LyncProductCode)
        }
    }

Set-ItemProperty -Path $Office16Key -Name "ProductCodes" -Value $ProductCodes

    #Fix SharePoint Designer Registry
 If ($SharePointDesignerKey)
    {
    If (Test-Path $SharePointDesignerKey) 
        {
        [System.Collections.ArrayList]$ProductCodes = (Get-ItemProperty -Path $SharePointDesignerKey -Name "ProductCodes").("ProductCodes")
        }
    }

if ($SharePointDesignerProductCode)
    {
    while ($ProductCodes -contains $SharePointDesignerProductCode)
        {
        Write-CMTraceLog -Message "Removing the $SharePointDesignerProductCode from $SharePointDesignerKey\ProductCodes" -Type "Info" -Component "Main"
        $ProductCodes.Remove($SharePointDesignerProductCode)
        }
    }

#Set-ItemProperty -Path $SharePointDesignerKey -Name "ProductCodes" -Value $ProductCodes

#Remove SharePoint Designer 2007 Registry Key
if ($SPD2007)
    {
    If (Test-Path $SPD2007)
       {
        Write-CMTraceLog -Message "Deleting SharePoint Designer 2007 Registry Key" -Type "Info" -Component "Main"
        Remove-Item -Path "$SPD2007" -Force -Recurse -ErrorAction SilentlyContinue
        }
    }

Write-CMTraceLog -Message "End Script" -Type "Info" -Component "Main"
