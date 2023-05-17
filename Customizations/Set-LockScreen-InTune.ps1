<#
.SYNOPSIS
    --.Replaces Lock Screen images with your own
.DESCRIPTION
    This script takes ownership and set persmissions on files located: c:\windows\web\screen
    This script will replace C:\windows\web\Screen\img100.jpg &  C:\windows\web\Screen\img105.jpg with .\lockscreen.jpg
    Designed to work in Task Sequence, but would work in Application Model or Package as well.
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by @gwblok
.LINK
    https://garytown.com
.LINK
    https://www.recastsoftware.com
.COMPONENT
    --
.FUNCTIONALITY
    --
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

$ScriptVersion = "21.3.8.1"
$BrandingFiles = "https://docs.recastsoftware.com/ConfigMgr-Docs/Community-Tools/media/RecastBrandingFiles.zip"
$whoami = (whoami).split("\") | Select-Object -Last 1
$LogFile = "$env:ProgramData\Intune\Logs\LockScreen.log"
#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

        function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "Intune - LockScreen",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
		    $LogFile = "$env:ProgramData\Intune\Logs\LockScreen.log"
	    )
    <#
    Type: 1 = Normal, 2 = Warning (yellow), 3 = Error (red)
    #>
	    $Time = Get-Date -Format "HH:mm:ss.ffffff"
	    $Date = Get-Date -Format "MM-dd-yyyy"
 
	    if ($ErrorMessage -ne $null) {$Type = 3}
	    if ($Component -eq $null) {$Component = " "}
	    if ($Type -eq $null) {$Type = 1}
 
	    $LogMessage = "<![LOG[$Message $ErrorMessage" + "]LOG]!><time=`"$Time`" date=`"$Date`" component=`"$Component`" context=`"`" type=`"$Type`" thread=`"`" file=`"`">"
	    $LogMessage | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }

function enable-privilege {
 param(
  ## The privilege to adjust. This set is taken from
  ## http://msdn.microsoft.com/en-us/library/bb530716(VS.85).aspx
  [ValidateSet(
   "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege",
   "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege", "SeCreatePagefilePrivilege",
   "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
   "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
   "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege",
   "SeLockMemoryPrivilege", "SeMachineAccountPrivilege", "SeManageVolumePrivilege",
   "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege", "SeRemoteShutdownPrivilege",
   "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
   "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege",
   "SeTakeOwnershipPrivilege", "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege",
   "SeUndockPrivilege", "SeUnsolicitedInputPrivilege")]
  $Privilege,
  ## The process on which to adjust the privilege. Defaults to the current process.
  $ProcessId = $pid,
  ## Switch to disable the privilege, rather than enable it.
  [Switch] $Disable
 )

 ## Taken from P/Invoke.NET with minor adjustments.
 $definition = @'
 using System;
 using System.Runtime.InteropServices;
  
 public class AdjPriv
 {
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
   ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
  
  [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
  internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
  [DllImport("advapi32.dll", SetLastError = true)]
  internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
  [StructLayout(LayoutKind.Sequential, Pack = 1)]
  internal struct TokPriv1Luid
  {
   public int Count;
   public long Luid;
   public int Attr;
  }
  
  internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
  internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
  internal const int TOKEN_QUERY = 0x00000008;
  internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
  public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
  {
   bool retVal;
   TokPriv1Luid tp;
   IntPtr hproc = new IntPtr(processHandle);
   IntPtr htok = IntPtr.Zero;
   retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
   tp.Count = 1;
   tp.Luid = 0;
   if(disable)
   {
    tp.Attr = SE_PRIVILEGE_DISABLED;
   }
   else
   {
    tp.Attr = SE_PRIVILEGE_ENABLED;
   }
   retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
   retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
   return retVal;
  }
 }
'@

 $processHandle = (Get-Process -id $ProcessId).Handle
 $type = Add-Type $definition -PassThru
 $type[0]::EnablePrivilege($processHandle, $Privilege, $Disable)
}

function Set-Owner{

Param (
    [Parameter(Mandatory=$true)][string] $identity,
    [Parameter(Mandatory=$true)][String] $filepath
      )

$file = Get-Item -Path $filepath
$acl = $file.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
$me = [System.Security.Principal.NTAccount]$identity
$acl.SetOwner($me)
$file.SetAccessControl($acl)

# After you have set owner you need to get the acl with the perms so you can modify it.
$acl = $file.GetAccessControl()
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity,"FullControl","Allow")
$acl.SetAccessRule($rule)
$file.SetAccessControl($acl)
#$file.Close()
}

function Set-Permission{

Param (
    [Parameter(Mandatory=$true)][string] $identity,
    [Parameter(Mandatory=$true)][String] $filepath,
    [Parameter(Mandatory=$true)][string] $FilesSystemRights,
    [Parameter(Mandatory=$true)][String] $type
      )
$file = Get-Item -Path $filepath
$newacl = $file.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)

# Create new rule
$FilesSystemAccessRuleArgumentList = $identity, $FilesSystemRights, $type
$FilesSystemAccessRule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $FilesSystemAccessRuleArgumentList
# Apply new rule
$NewAcl.SetAccessRule($FilesSystemAccessRule)
Set-Acl -Path $file.FullName -AclObject $NewAcl
}

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

CMTraceLog -Message  "---------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Starting LockScreen Script" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Running as $whoami" -Type 1 -LogFile $LogFile


if ($whoami -match "SYSTEM")
    {
    CMTraceLog -Message  "Taking OwnerShip of Files" -Type 1 -LogFile $LogFile
    #Take OwnerShip
    enable-privilege SeTakeOwnershipPrivilege 
    #Set Permissions on Files
    $files = Get-ChildItem -Path C:\Windows\Web\Screen
    $identity = "BUILTIN\Administrators"
    foreach ($filechild in $files)
        {
        CMTraceLog -Message  " Taking ownership of file: $($filechild.name)" -Type 1 -LogFile $LogFile
        Set-Owner -identity $identity -filepath $filechild.fullname
        }

    #Grant Rights to Admin & System
    # Set Adminstrators of Full Control of File
    CMTraceLog -Message  "Grant Rights to Admin & System" -Type 1 -LogFile $LogFile
    CMTraceLog -Message  " Setting Full Control Rights for Administrators" -Type 1 -LogFile $LogFile
    $identity = "BUILTIN\Administrators"
    $FilesSystemRights = "FullControl"
    $type = "Allow"
    foreach ($filechild in $files)
        {
        CMTraceLog -Message  "  Updating Control of file: $($filechild.name)" -Type 1 -LogFile $LogFile
        Set-Permission -identity $identity -type $type -FilesSystemRights $FilesSystemRights -filepath $filechild.fullname
        }

    # Set SYSTEM to Full Control of Registry Item
    CMTraceLog -Message  " Setting Full Control Rights for Administrators" -Type 1 -LogFile $LogFile
    $identity = "NT AUTHORITY\SYSTEM"
    $FilesSystemRights = "FullControl"
    $type = "Allow"
    foreach ($filechild in $files)
        {
        CMTraceLog -Message  "  Updating Control of file: $($filechild.name)" -Type 1 -LogFile $LogFile
        Set-Permission -identity $identity -type $type -FilesSystemRights $FilesSystemRights -filepath $filechild.fullname
        }

    #Download Branding Files:

    $OutFilePath = "$env:ProgramData\Intune\Branding\"
    $OutFile = "$OutFilePath\Intune\BrandingFiles.zip"
    if (!(Test-Path -Path $OutFilePath)){$NewFolder = New-Item -Path $OutFilePath -ItemType Directory -Force}
    if (Test-Path -Path $OutFile){Remove-Item -Path $OutFile -Force}
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    CMTraceLog -Message  "Downloading File: $BrandingFiles to $OutFile" -Type 1 -LogFile $LogFile
    Invoke-WebRequest -UseBasicParsing -Uri $BrandingFiles -OutFile $OutFile

    if (!(Test-Path -Path $OutFile))
    {Write-Output "Failed to Download Branding Files"}
    else
        {
        CMTraceLog -Message  "Expanding files to $OutFilePath" -Type 1 -LogFile $LogFile
        Expand-Archive -Path $OutFile -DestinationPath $OutFilePath -Force
        }


    #Copy the 2 files into place
    CMTraceLog -Message  "Overwriting Files" -Type 1 -LogFile $LogFile
    $LockScreenHash = Get-Filehash -Algorithm MD5 -Path $OutFilePath\WallPapersLockScreens\lockscreen.jpg 
    Copy-Item "$OutFilePath\WallPapersLockScreens\lockscreen.jpg" C:\windows\web\Screen\img100.jpg -Force -Verbose
    Copy-Item "$OutFilePath\WallPapersLockScreens\lockscreen.jpg" C:\windows\web\Screen\img105.jpg -Force -Verbose
    $img100Hash = Get-Filehash -Algorithm MD5 -Path C:\windows\web\Screen\img100.jpg 
    $img105Hash = Get-Filehash -Algorithm MD5 -Path C:\windows\web\Screen\img105.jpg

    if ($img100Hash -eq $LockScreenHash -and $img105Hash -eq $LockScreenHash)
        {
        CMTraceLog -Message  "Successfully Overwrote LockScreen Images with Custom ones" -Type 1 -LogFile $LogFile
        }
    else
        {
        CMTraceLog -Message  "FAILED to overwrite LockScreen Images with Custom ones" -Type 3 -LogFile $LogFile
        }
    }
else
    {
    Write-output "Not running as system, running as $whoami, exiting Script"
    CMTraceLog -Message  "Not running as system, running as $whoami, exiting Script" -Type 3 -LogFile $LogFile
    }

exit $exitcode
#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
