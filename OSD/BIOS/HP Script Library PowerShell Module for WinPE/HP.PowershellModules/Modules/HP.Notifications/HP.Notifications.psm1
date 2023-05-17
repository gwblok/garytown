if ($PSEdition -eq "Core") {
  Add-Type -Assembly $PSScriptRoot\refs\Microsoft.Windows.SDK.NET.dll
}
else {
  [void][Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime]
  [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
}

$interop = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace Impersonate
{
    internal class NativeHelpers
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct PROCESS_INFORMATION
        {
            public IntPtr hProcess;
            public IntPtr hThread;
            public int dwProcessId;
            public int dwThreadId;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct STARTUPINFO
        {
            public int cb;
            public String lpReserved;
            public String lpDesktop;
            public String lpTitle;
            public uint dwX;
            public uint dwY;
            public uint dwXSize;
            public uint dwYSize;
            public uint dwXCountChars;
            public uint dwYCountChars;
            public uint dwFillAttribute;
            public uint dwFlags;
            public short wShowWindow;
            public short cbReserved2;
            public IntPtr lpReserved2;
            public IntPtr hStdInput;
            public IntPtr hStdOutput;
            public IntPtr hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct WTS_SESSION_INFO
        {
            public readonly UInt32 SessionID;

            [MarshalAs(UnmanagedType.LPStr)]
            public readonly String pWinStationName;

            public readonly uint State;
        }
    }

    internal class NativeMethods
    {
        [DllImport("kernel32", SetLastError = true)]
        public static extern int WaitForSingleObject(
          IntPtr hHandle,
          int dwMilliseconds);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(
            IntPtr hSnapshot);

        [DllImport("userenv.dll", SetLastError = true)]
        public static extern bool CreateEnvironmentBlock(
            ref IntPtr lpEnvironment,
            IntPtr hToken,
            bool bInherit);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CreateProcessAsUserW(
            IntPtr hToken,
            string lpApplicationName,
            StringBuilder lpCommandLine,
            IntPtr lpProcessAttributes,
            IntPtr lpThreadAttributes,
            bool bInheritHandle,
            uint dwCreationFlags,
            IntPtr lpEnvironment,
            string lpCurrentDirectory,
            ref NativeHelpers.STARTUPINFO lpStartupInfo,
            out NativeHelpers.PROCESS_INFORMATION lpProcessInformation);

        [DllImport("userenv.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool DestroyEnvironmentBlock(
            IntPtr lpEnvironment);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern bool DuplicateTokenEx(
            IntPtr ExistingTokenHandle,
            uint dwDesiredAccess,
            IntPtr lpThreadAttributes,
            uint ImpersonationLevel,
            uint TokenType,
            out IntPtr DuplicateTokenHandle);

        [DllImport("wtsapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool WTSEnumerateSessions(
            IntPtr hServer,
            int Reserved,
            int Version,
            ref IntPtr ppSessionInfo,
            ref int pCount);

        [DllImport("wtsapi32.dll")]
        public static extern void WTSFreeMemory(
            IntPtr pMemory);

        [DllImport("Wtsapi32.dll", SetLastError = true)]
        public static extern bool WTSQueryUserToken(
            uint SessionId,
            out IntPtr phToken);
    }

    public static class ProcessExtensions
    {
        private const int CREATE_UNICODE_ENVIRONMENT = 0x00000400;
        private const int CREATE_NO_WINDOW = 0x08000000;
        private const int CREATE_NEW_CONSOLE = 0x00000010;

        public static void StartProcessAsCurrentUser(string appPath, string cmdLine = null, string workDir = null)
        {
            uint activeSessionId = 0;
            var pSessionInfo = IntPtr.Zero;
            var sessionCount = 0;

            // Get a handle to the user access token for the current active session.
            if (NativeMethods.WTSEnumerateSessions(IntPtr.Zero, 0, 1, ref pSessionInfo, ref sessionCount))
            {
                var arrayElementSize = Marshal.SizeOf(typeof(NativeHelpers.WTS_SESSION_INFO));
                var current = pSessionInfo;

                for (var i = 0; i < sessionCount; i++)
                {
                    var si = (NativeHelpers.WTS_SESSION_INFO) Marshal.PtrToStructure(current, typeof(NativeHelpers.WTS_SESSION_INFO));
                    current = IntPtr.Add(current, arrayElementSize);

                    if (si.State == 0)
                    {
                        activeSessionId = si.SessionID;
                        break;
                    }
                }
            }
            NativeMethods.WTSFreeMemory(pSessionInfo);

            IntPtr dupTokenHandle = IntPtr.Zero;
            IntPtr hImpersonationToken = IntPtr.Zero;
            if (NativeMethods.WTSQueryUserToken(activeSessionId, out hImpersonationToken))
            {
                NativeMethods.DuplicateTokenEx(hImpersonationToken, 0, IntPtr.Zero, 2, 1, out dupTokenHandle);
            }

            StringBuilder commandLine = new StringBuilder(cmdLine);

            var startInfo = new NativeHelpers.STARTUPINFO();
            startInfo.cb = Marshal.SizeOf(startInfo);

            //uint dwCreationFlags = CREATE_UNICODE_ENVIRONMENT | (uint) CREATE_NEW_CONSOLE;
            //startInfo.wShowWindow = 5;
            uint dwCreationFlags = CREATE_UNICODE_ENVIRONMENT | (uint)CREATE_NO_WINDOW;
            startInfo.wShowWindow = 0;

            IntPtr pEnv = IntPtr.Zero;
            NativeMethods.CreateEnvironmentBlock(ref pEnv, dupTokenHandle, false);
            NativeHelpers.PROCESS_INFORMATION procInfo;
            NativeMethods.CreateProcessAsUserW(
                dupTokenHandle,
                appPath,
                commandLine,
                IntPtr.Zero,
                IntPtr.Zero,
                false,
                dwCreationFlags,
                pEnv,
                workDir,
                ref startInfo,
                out procInfo);
            
            NativeMethods.WaitForSingleObject(procInfo.hProcess, -1);
            NativeMethods.CloseHandle(procInfo.hThread);
            NativeMethods.CloseHandle(procInfo.hProcess);
            NativeMethods.DestroyEnvironmentBlock(pEnv);
            NativeMethods.CloseHandle(dupTokenHandle);
        }
    }
}
"@

Add-Type $interop -Passthru

<#
    .SYNOPSIS
    Create a logo object
    .DESCRIPTION
    This function creates a toaster logo from a file image.
    .PARAMETER Image
    The URL to the image.Http images must be 200 KB or less in size. Not all URL formats are supported in all scenarios.
    .PARAMETER Crop
    Specify how you would like the image to be cropped.
    .EXAMPLE
    PS>  $logo = New-HPPrivateToastNotificationLogo .\logo.png
    .OUTPUTS
    This function returns the object representing the logo image.
#>
function New-HPPrivateToastNotificationLogo
{
  param(
    [Parameter(Position = 0,Mandatory = $True,ValueFromPipeline = $True)]
    [string]$Image,
    [Parameter(Position = 1,Mandatory = $False)]
    [ValidateSet('None','Default','Circle')]
    [string]$Crop
  )

  [xml]$xml = New-Object System.Xml.XmlDocument
  $child = $xml.CreateElement("image")
  $child.SetAttribute('src',$Image)
  $child.SetAttribute('placement','appLogoOverride')
  if ($LogoCrop) { $child.SetAttribute('hint-crop',$LogoCrop.ToLower()) }
  $child
}

<#
    .SYNOPSIS
    Create a toast image object
    .DESCRIPTION
    This function creates a toaster image from a file image. This image may be shown in the body of a toast message.
    .PARAMETER Image
    The URL to the image. Http images must be 200 KB or less in size.  Not all URL formats are supported in all scenarios.
    .PARAMETER Position
     Toasts can display a 'fixed' image, which is a featured ToastGenericHeroImage displayed prominently within the toast banner and while inside Action Center. Image dimensions are 364x180 pixels at 100% scaling.
     Alternately use 'inline' to display a full-width inline-image that appears when you expand the toast.

    .EXAMPLE
    PS>  $logo = New-HPPrivateToastNotificationLogo .\hero.png
    .OUTPUTS
    This function returns the object representing the image.
    .LINK
    [ToastGenericHeroImage](https://docs.microsoft.com/en-us/windows/uwp/design/shell/tiles-and-notifications/toast-schema#toastgenericheroimage)
#>
function New-HPPrivateToastNotificationImage
{
  param(
    [Parameter(Position = 0,Mandatory = $True,ValueFromPipeline = $True)]
    [string]$Image,
    [Parameter(Position = 1,Mandatory = $False)]
    [ValidateSet('Inline','Fixed')]
    [string]$Position = 'Fixed'
  )
  [xml]$xml = New-Object System.Xml.XmlDocument
  $child = $xml.CreateElement("image")
  $child.SetAttribute('src',$Image)
  #$child.SetAttribute('placement','appLogoOverride') is this needed?

  if ($Position -eq 'Fixed') {
    $child.SetAttribute('placement','hero')
  }
  else
  {
    $child.SetAttribute('placement','inline')
  }
  $child
}

<#
    .SYNOPSIS
    Specify the toast message alert sound
    .DESCRIPTION
    This function allows defining the sound to play on toast notification.
    .PARAMETER Sound
    The sound to play
    .PARAMETER Loop
    If true, the sound will be looped

    .EXAMPLE
    PS>  $logo = New-HPPrivateToastSoundPreference -Sound "Alarm6" -Loop
    .OUTPUTS
    This function returns the object representing the sound preference.
    .LINK
    [ToastAudio](https://docs.microsoft.com/en-us/windows/uwp/design/shell/tiles-and-notifications/toast-schema#ToastAudio)
#>
function New-HPPrivateToastSoundPreference
{
  param(
    [Parameter(Position = 1,Mandatory = $False)]
    [ValidateSet('None','Default','IM','Mail','Reminder','SMS',
      'Alarm','Alarm2','Alarm3','Alarm4','Alarm5','Alarm6','Alarm7','Alarm8','Alarm9','Alarm10',
      'Call','Call2','Call3','Call4','Call5','Call6','Call7','Call8','Call9','Call10')]
    [string]$Sound = "Default",
    [Parameter(Position = 2,Mandatory = $False)]
    [switch]$Loop
  )
  [xml]$xml = New-Object System.Xml.XmlDocument
  $child = $xml.CreateElement("audio")
  if ($Sound -eq "None") {
    $child.SetAttribute('silent',"$true".ToLower())
    Write-Verbose "Setting audio notification to Muted"
  }
  else
  {
    $soundPath = "ms-winsoundevent:Notification.$Sound"
    if ($Sound.StartsWith('Alarm') -or $Sound.StartsWith('Call'))
    {
      $soundPath = 'winsoundevent:Notification.Looping.' + $Sound
    }
    Write-Verbose "Setting audio notification to: $soundPath"
    $child.SetAttribute('src',$soundPath)
    $child.SetAttribute('loop',([string]$Loop.IsPresent).ToLower())
    Write-Verbose "Looping audio: $($Loop.IsPresent)"
  }
  $child
}

<#
    .SYNOPSIS
    Create a toast button
    .DESCRIPTION
    Create a toast button for the toast
    .PARAMETER Sound
    The sound to play
    .PARAMETER Image
    For a graphical button, specify the button image
    .PARAMETER Arguments
    App-defined string of arguments that the app will later receive if the user clicks this button.
    .OUTPUTS
    This function returns the object representing the button
    .LINK
    [ToastButton](https://docs.microsoft.com/en-us/windows/uwp/design/shell/tiles-and-notifications/toast-schema#ToastButton)
#>
function New-HPPrivateToastButton
{
    [Cmdletbinding()]
    param(
        [string]$Caption,
        [string]$Image, # leave out for normal button
        [string]$Arguments,
        [ValidateSet('Background','Protocol','System')]
        [string]$ActivationType = 'background'
    )

    Write-Verbose "Creating new Toast button with caption $Caption"
    if ($Image) {
        ([xml]"<action content=`"$Caption`" imageUri=`"$Image`" arguments=`"$Arguments`" activationType=`"$ActivationType`" />").DocumentElement
    } else {
        ([xml]"<action content=`"$Caption`" arguments=`"$Arguments`" activationType=`"$ActivationType`" />").DocumentElement

    }
}

<#
    .SYNOPSIS
    Create a toast action
    .DESCRIPTION
    Create a toast action for the toast
    .PARAMETER SnoozeOrDismiss
      Automatically constructs a selection box for snooze intervals, and snooze/dismiss buttons, all automatically localized, and snoozing logic is automatically handled by the system.
    .PARAMETER Image
    For a graphical button, specify the button image
    .PARAMETER Arguments
    App-defined string of arguments that the app will later receive if the user clicks this button.
    .OUTPUTS
    This function returns the object representing the button
#>
function New-HPPrivateToastActions
{
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = 'DismissSuppress',Position = 1,Mandatory = $True)]
    [switch]$SnoozeOrDismiss,

    [Parameter(ParameterSetName = 'DismissSuppress',Position = 2,Mandatory = $True)]
    [int]$SnoozeMinutesDefault,


    [Parameter(ParameterSetName = 'DismissSuppress',Position = 3,Mandatory = $True)]
    [int[]]$SnoozeMinutesOptions,

    [Parameter(ParameterSetName = 'CustomButtons',Position = 1,Mandatory = $True)]
    [switch]$CustomButtons,

    [Parameter(ParameterSetName = 'CustomButtons',Position = 2,Mandatory = $True)]
    [System.Xml.XmlElement[]]$Buttons,

    [Parameter(ParameterSetName = 'CustomButtons',Position = 3,Mandatory = $false)]
    [switch]$NoDismiss

  )
  [xml]$xml = New-Object System.Xml.XmlDocument
  $child = $xml.CreateElement("actions")

  switch ($PSCmdlet.ParameterSetName) {
    'DismissSuppress' {
      Write-Verbose "Creating system-handled snoozable notification"

      $i = $xml.CreateElement("input")
      [void]$child.AppendChild($i)

      $i.SetAttribute('id',"snoozeTime")
      $i.SetAttribute('type','selection')
      $i.SetAttribute('defaultInput',$SnoozeMinutesDefault)

      Write-Verbose "Notification snooze default: SnoozeMinutesDefault"
      $SnoozeMinutesOptions | ForEach-Object {
        $s = $xml.CreateElement("selection")
        $s.SetAttribute('id',"$_")
        $s.SetAttribute('content',"$_ minute")
        [void]$i.AppendChild($s)
      }

      $action = $xml.CreateElement("action")
      $action.SetAttribute('ActivationType','system')
      $action.SetAttribute('arguments','snooze')
      $action.SetAttribute('hint-inputId','snoozeTime')
      $action.SetAttribute('content','Snooze')
      [void]$child.AppendChild($action)

      $action = $xml.CreateElement("action")
      $action.SetAttribute('ActivationType','system')
      $action.SetAttribute('arguments','dismiss')
      $action.SetAttribute('content','Dismiss')
      [void]$child.AppendChild($action)
    }

    'CustomButtons' { # customized buttons
      Write-Verbose "Creating custom buttons toast"
      $Buttons | ForEach-Object {
        $node = $xml.ImportNode($_,$true)
        [void]$child.AppendChild($node)
      }

      if (-not $NoDismiss.IsPresent) {
        $action = $xml.CreateElement("action")
        $action.SetAttribute('ActivationType','system')
        $action.SetAttribute('arguments','dismiss')
        $action.SetAttribute('content','Dismiss')
        [void]$child.AppendChild($action)
      }
    }

    default {

    }
  }

  $child
}

<#
    .SYNOPSIS
    Show a toast message
    .DESCRIPTION
    This function shows a toast message, and optionally registers a response handler.
    .PARAMETER Message
      The message to show
    .PARAMETER Title
    The title of the message to show
    .PARAMETER Logo
    A logo object create with New-HPPrivateToastNotificationLogo
    .PARAMETER Image
    A logo object create with New-HPPrivateToastNotificationImage
    .PARAMETER Expiration
    A timeout for the toast to remove itself
    .PARAMETER Tag
    A tag value for the toast
    .PARAMETER Group
    A group value for the toast
    .PARAMETER Attribution
    The toast owner
    .PARAMETER Sound
    A sound notification preference created with New-HPPrivateToastSoundPreference
    .PARAMETER Actions
    .PARAMETER Persist
#>
function New-HPPrivateToastNotification
{
  [CmdletBinding()]
  param(
    [Parameter(ParameterSetName = 'TextOnly',Position = 0,Mandatory = $True,ValueFromPipeline = $True)]
    [string]$Message,

    [Parameter(Position = 1,Mandatory = $False)]
    [string]$Title,

    [Parameter(Position = 3,Mandatory = $False)]
    [System.Xml.XmlElement]$Logo,

    [Parameter(Position = 4,Mandatory = $False)]
    [int]$Expiration,

    [Parameter(Position = 5,Mandatory = $False)]
    [string]$Tag = "hp-cmsl",

    [Parameter(Position = 6,Mandatory = $False)]
    [string]$Group = "hp-cmsl",

    [Parameter(Position = 8,Mandatory = $False)]
    [System.Xml.XmlElement]$Sound,

    # Apparently can't do URLs with non-uwp
    [Parameter(Position = 11,Mandatory = $False)]
    [System.Xml.XmlElement]$Image,

    [Parameter(Position = 13,Mandatory = $False)]
    [System.Xml.XmlElement]$Actions,

    [Parameter(Position = 14,Mandatory = $False)]
    [switch]$Persist
  )

  [xml]$xml = '<toast><visual><binding template="ToastGeneric"><text></text><text></text></binding></visual></toast>'

  $binding = $xml.GetElementsByTagName("toast")
  if ($Sound) {
    $node = $xml.ImportNode($Sound,$true)
    [void]$binding.AppendChild($node)
  }

  if ($Persist.IsPresent)
  {
    $binding.SetAttribute('scenario','reminder')
  }


  if ($Actions) {
    $node = $xml.ImportNode($Actions,$true)
    [void]$binding.AppendChild($node)
  }


  $binding = $xml.GetElementsByTagName("binding")
  if ($Logo) {
    $node = $xml.ImportNode($Logo,$true)
    [void]$binding.AppendChild($node)
  }

  if ($Image) {
    $node = $xml.ImportNode($Image,$true)
    [void]$binding.AppendChild($node)
  }


  $binding = $xml.GetElementsByTagName("text")
  if ($Title) {
    [void]$binding[0].AppendChild($xml.CreateTextNode($Title.trim()))
  }

  [void]$binding[1].AppendChild($xml.CreateTextNode($Message.trim()))


  Write-Verbose "Submitting toast with XML: $($xml.OuterXml)"


  $toast = [Windows.Data.Xml.Dom.XmlDocument]::new()
  $toast.LoadXml($xml.OuterXml)


  $toast = [Windows.UI.Notifications.ToastNotification]::new($toast)
  $toast.Tag = $Tag
  $toast.Group = $Group

  if ($Expiration) {
    $toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes($Expiration)
  }

  return $toast
}

function Show-ToastNotification {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0,Mandatory = $False,ValueFromPipeline = $true)]
    $Toast,

    [Parameter(Position = 1,Mandatory = $False)]
    [string]$Attribution = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
  )

  $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($Attribution)
  $notifier.Show($toast)
}

function Register-HPPrivateScriptProtocol {
  [CmdletBinding()]
  param(
    [string]$ScriptPath,
    [string]$Name
  )

  try {
    New-Item "HKCU:\Software\Classes\$($Name)\shell\open\command" -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\Software\Classes\$($Name)" -Name 'URL Protocol' -Value '' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\Software\Classes\$($Name)" -Name '(default)' -Value "url:$($Name)" -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\Software\Classes\$($Name)" -Name 'EditFlags' -Value 2162688 -PropertyType Dword -Force -ErrorAction SilentlyContinue | Out-Null
    New-ItemProperty -LiteralPath "HKCU:\Software\Classes\$($Name)\shell\open\command" -Name '(default)' -Value $ScriptPath -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
  }
  catch {
    Write-Host $_.Exception.Message
  }
}

function Invoke-HPPrivateRebootNotificationAsUser {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0,Mandatory = $false)]
    [string]$Title = "A System Reboot is Required",

    [Parameter(Position = 1,Mandatory = $false)]
    [string]$Message = "Please reboot now to keep your device compliant with the security policies.",

    [Parameter(Position = 2,Mandatory = $false)]
    [string]$LogoImage
  )

  Register-HPPrivateScriptProtocol -ScriptPath "C:\Windows\System32\shutdown.exe -r -t 0 -f" -Name "rebootnow"
  $rebootButton = New-HPPrivateToastButton -Caption "Reboot now" -Image $null -Arguments "rebootnow:" -ActivationType "Protocol"

  $params = @{
    Message = $Message
    Title = $Title
    Expiration = 100
    Actions = New-HPPrivateToastActions -CustomButtons -Buttons $rebootButton
    Sound = New-HPPrivateToastSoundPreference -Sound IM
    #Logo = New-HPPrivateToastNotificationLogo -Image $img_logo -Crop Circle
    #Image = New-HPPrivateToastNotificationImage -Image $img_hero -Position Inline
  }

  if ($LogoImage) {
    $params.Logo = New-HPPrivateToastNotificationLogo -Image $LogoImage -Crop Circle
  }

  New-HPPrivateToastNotification @params -Persist | Show-ToastNotification

  return
}


<#
.SYNOPSIS
  Invoke-RebootNotification

.DESCRIPTION
  This function shows a toast message asking the user to reboot the system

.PARAMETER Message
  The message to show

.PARAMETER Title
  The title of the message to show

.PARAMETER LogoImage
  Image file path to be displayed

.EXAMPLE
  Invoke-RebootNotification -Title "My title" -Message "My message"
#>
function Invoke-RebootNotification {
  [CmdletBinding(HelpUri = "https://developers.hp.com/hp-client-management/doc/Invoke%E2%80%90RebootNotification")]
  param(
    [Parameter(Position = 0,Mandatory = $False)]
    [string]$Title = "A System Reboot is Required",

    [Parameter(Position = 1,Mandatory = $False)]
    [string]$Message = "Please reboot now to keep your device compliant with the security policies.",

    [Parameter(Position = 2,Mandatory = $false)]
    [string]$LogoImage
  )

  $privs = whoami /priv /fo csv | ConvertFrom-Csv | Where-Object { $_. 'Privilege Name' -eq 'SeDelegateSessionUserImpersonatePrivilege' }
  if ($privs.State -eq "Disabled") {
    Write-Verbose "Running with user privileges"
    Invoke-HPPrivateRebootNotificationAsUser -Title $Title -Message $Message -LogoImage $LogoImage
  }
  else {
    Write-Verbose "Running with system privileges"
    try {
      $psPath = (Get-Process -Id $pid).Path
      # Passing the parameters as environment variable because the following block executes in a different context
      [System.Environment]::SetEnvironmentVariable('HPRebootTitle',$Title,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPRebootMessage',$Message,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPRebootLogoImage',$LogoImage,[System.EnvironmentVariableTarget]::Machine)
      [scriptblock]$scriptBlock = {
        $path = $pwd.Path
        Import-Module -Force $path\HP.Notifications.psd1
        Invoke-HPPrivateRebootNotificationAsUser -Title $env:HPRebootTitle -Message $env:HPRebootMessage -LogoImage $env:HPRebootLogoImage
      }
      $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptBlock))
      $psCommand = "-ExecutionPolicy Bypass -Window Normal -EncodedCommand $($encodedCommand)"
      [Impersonate.ProcessExtensions]::StartProcessAsCurrentUser($psPath,"`"$psPath`" $psCommand",$PSScriptRoot)
      [System.Environment]::SetEnvironmentVariable('HPRebootTitle',$null,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPRebootMessage',$null,[System.EnvironmentVariableTarget]::Machine)
      [System.Environment]::SetEnvironmentVariable('HPRebootLogoImage',$null,[System.EnvironmentVariableTarget]::Machine)
    }
    catch {
      Write-Error -Message "Could not execute as currently logged on user: $($_.Exception.Message)" -Exception $_.Exception
    }
  }

  return
}

# SIG # Begin signature block
# MIIaygYJKoZIhvcNAQcCoIIauzCCGrcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCT7dLYlxrgTxJH
# eXrJgbEYL/gMMBvI4+OwnY6smHvbZ6CCCm8wggUwMIIEGKADAgECAhAECRgbX9W7
# ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMzEwMjIxMjAwMDBa
# Fw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lD
# ZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4Rr2d3B9MLMUkZz9D7RZmxOttE9X/l
# qJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrwnIal2CWsDnkoOn7p0WfTxvspJ8fT
# eyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnCwlLyFGeKiUXULaGj6YgsIJWuHEqH
# CN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8y5Kh5TsxHM/q8grkV7tKtel05iv+
# bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM0SAlI+sIZD5SlsHyDxL0xY4PwaLo
# LFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6fpjOp/RnfJZPRAgMBAAGjggHNMIIB
# yTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0fBHow
# eDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJl
# ZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBPBgNVHSAESDBGMDgGCmCGSAGG/WwA
# AgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNlcnQuY29tL0NQUzAK
# BghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHwYDVR0j
# BBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDQYJKoZIhvcNAQELBQADggEBAD7s
# DVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+C2D9wz0PxK+L/e8q3yBVN7Dh9tGS
# dQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119EefM2FAaK95xGTlz/kLEbBw6RFfu6
# r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR4pwUR6F6aGivm6dcIFzZcbEMj7uo
# +MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4vcn4c10lFluhZHen6dGRrsutmQ9qz
# sIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwHgfqL2vmCSfdibqFT+hKUGIUukpHq
# aGxEMrJmoecYpJpkUe8wggU3MIIEH6ADAgECAhAFUi3UAAgCGeslOwtVg52XMA0G
# CSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0
# IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcgQ0EwHhcNMjEwMzIyMDAwMDAw
# WhcNMjIwMzMwMjM1OTU5WjB1MQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZv
# cm5pYTESMBAGA1UEBxMJUGFsbyBBbHRvMRAwDgYDVQQKEwdIUCBJbmMuMRkwFwYD
# VQQLExBIUCBDeWJlcnNlY3VyaXR5MRAwDgYDVQQDEwdIUCBJbmMuMIIBIjANBgkq
# hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtJ+rYUkseHcrB2M/GyomCEyKn9tCyfb+
# pByq/Jyf5kd3BGh+/ULRY7eWmR2cjXHa3qBAEHQQ1R7sX85kZ5sl2ukINGZv5jEM
# 04ERNfPoO9+pDndLWnaGYxxZP9Y+Icla09VqE/jfunhpLYMgb2CuTJkY2tT2isWM
# EMrKtKPKR5v6sfhsW6WOTtZZK+7dQ9aVrDqaIu+wQm/v4hjBYtqgrXT4cNZSPfcj
# 8W/d7lFgF/UvUnZaLU5Z/+lYbPf+449tx+raR6GD1WJBAzHcOpV6tDOI5tQcwHTo
# jJklvqBkPbL+XuS04IUK/Zqgh32YZvDnDohg0AEGilrKNiMes5wuAQIDAQABo4IB
# xDCCAcAwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0OBBYE
# FD4tECf7wE2l8kA6HTvOgkbo33MvMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAK
# BggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdpY2Vy
# dC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2NybDQu
# ZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwSwYDVR0gBEQwQjA2
# BglghkgBhv1sAwEwKTAnBggrBgEFBQcCARYbaHR0cDovL3d3dy5kaWdpY2VydC5j
# b20vQ1BTMAgGBmeBDAEEATCBhAYIKwYBBQUHAQEEeDB2MCQGCCsGAQUFBzABhhho
# dHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTgYIKwYBBQUHMAKGQmh0dHA6Ly9jYWNl
# cnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJBc3N1cmVkSURDb2RlU2lnbmlu
# Z0NBLmNydDAMBgNVHRMBAf8EAjAAMA0GCSqGSIb3DQEBCwUAA4IBAQBZca1CZfgn
# DucOwEDZk0RXqb8ECXukFiih/rPQ+T5Xvl3bZppGgPnyMyQXXC0fb94p1socJzJZ
# fn7rEQ4tHxL1vpBvCepB3Jq+i3A8nnJFHSjY7aujglIphfGND97U8OUJKt2jwnni
# EgsWZnFHRI9alEvfGEFyFrAuSo+uBz5oyZeOAF0lRqaRht6MtGTma4AEgq6Mk/iP
# LYIIZ5hXmsGYWtIPyM8Yjf//kLNPRn2WeUFROlboU6EH4ZC0rLTMbSK5DV+xL/e8
# cRfWL76gd/qj7OzyJR7EsRPg92RQUC4RJhCrQqFFnmI/K84lPyHRgoctAMb8ie/4
# X6KaoyX0Z93PMYIPsTCCD60CAQEwgYYwcjELMAkGA1UEBhMCVVMxFTATBgNVBAoT
# DERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UE
# AxMoRGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQQIQBVIt
# 1AAIAhnrJTsLVYOdlzANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCDeRTBI4Mbo24ylLJMS65csmBl+F1Ky
# ldeAYc2YgR7TTzANBgkqhkiG9w0BAQEFAASCAQAXlTqaE65eKzv2h5yIKA1WujQp
# QkLmeNBu/746hvzf6HcHHuXQppeV5UTTt24kVvnmj42gvD1xNu//rqTDzKBoc+Lg
# Og4SuFEMmjF9mmKIZgo275pysEz+HDbhef9Rx27E2zx4f0rGchWtK9la6lT7PJt6
# 4odVwOjqBHHZJiVuPWJNPT1hbOtyrGRXPTTSnHsrnXCinFceRIOxL72bfscFqotU
# 5HgAV67/6VtXvo4wxGEsGDFB8RGDMiXB/qs4yN+T9bfQ8FtmDNUdxMBC75/LUR4a
# P3T7DQEWIbFJDDnsg3r0POSkt/I1V4GW+Db3hPP/ZWPV8UDQ9uz5bny0zNi0oYIN
# fTCCDXkGCisGAQQBgjcDAwExgg1pMIINZQYJKoZIhvcNAQcCoIINVjCCDVICAQMx
# DzANBglghkgBZQMEAgEFADB3BgsqhkiG9w0BCRABBKBoBGYwZAIBAQYJYIZIAYb9
# bAcBMDEwDQYJYIZIAWUDBAIBBQAEICEOof9uSy4kuk99gwbmMXsq459sjCfNOSbw
# pHi7dLlRAhBRDaELkpYpSMxJBFvvjCaDGA8yMDIxMTEyMjE5MTkwM1qgggo3MIIE
# /jCCA+agAwIBAgIQDUJK4L46iP9gQCHOFADw3TANBgkqhkiG9w0BAQsFADByMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQg
# VGltZXN0YW1waW5nIENBMB4XDTIxMDEwMTAwMDAwMFoXDTMxMDEwNjAwMDAwMFow
# SDELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMSAwHgYDVQQD
# ExdEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMTCCASIwDQYJKoZIhvcNAQEBBQADggEP
# ADCCAQoCggEBAMLmYYRnxYr1DQikRcpja1HXOhFCvQp1dU2UtAxQtSYQ/h3Ib5Fr
# DJbnGlxI70Tlv5thzRWRYlq4/2cLnGP9NmqB+in43Stwhd4CGPN4bbx9+cdtCT2+
# anaH6Yq9+IRdHnbJ5MZ2djpT0dHTWjaPxqPhLxs6t2HWc+xObTOKfF1FLUuxUOZB
# OjdWhtyTI433UCXoZObd048vV7WHIOsOjizVI9r0TXhG4wODMSlKXAwxikqMiMX3
# MFr5FK8VX2xDSQn9JiNT9o1j6BqrW7EdMMKbaYK02/xWVLwfoYervnpbCiAvSwnJ
# laeNsvrWY4tOpXIc7p96AXP4Gdb+DUmEvQECAwEAAaOCAbgwggG0MA4GA1UdDwEB
# /wQEAwIHgDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEEG
# A1UdIAQ6MDgwNgYJYIZIAYb9bAcBMCkwJwYIKwYBBQUHAgEWG2h0dHA6Ly93d3cu
# ZGlnaWNlcnQuY29tL0NQUzAfBgNVHSMEGDAWgBT0tuEgHf4prtLkYaWyoiWyyBc1
# bjAdBgNVHQ4EFgQUNkSGjqS6sGa+vCgtHUQ23eNqerwwcQYDVR0fBGowaDAyoDCg
# LoYsaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC10cy5jcmww
# MqAwoC6GLGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtdHMu
# Y3JsMIGFBggrBgEFBQcBAQR5MHcwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBPBggrBgEFBQcwAoZDaHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0U0hBMkFzc3VyZWRJRFRpbWVzdGFtcGluZ0NBLmNydDANBgkq
# hkiG9w0BAQsFAAOCAQEASBzctemaI7znGucgDo5nRv1CclF0CiNHo6uS0iXEcFm+
# FKDlJ4GlTRQVGQd58NEEw4bZO73+RAJmTe1ppA/2uHDPYuj1UUp4eTZ6J7fz51Kf
# k6ftQ55757TdQSKJ+4eiRgNO/PT+t2R3Y18jUmmDgvoaU+2QzI2hF3MN9PNlOXBL
# 85zWenvaDLw9MtAby/Vh/HUIAHa8gQ74wOFcz8QRcucbZEnYIpp1FUL1LTI4gdr0
# YKK6tFL7XOBhJCVPst/JKahzQ1HavWPWH1ub9y4bTxMd90oNcX6Xt/Q/hOvB46NJ
# ofrOp79Wz7pZdmGJX36ntI5nePk2mOHLKNpbh6aKLzCCBTEwggQZoAMCAQICEAqh
# JdbWMht+QeQF2jaXwhUwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEk
# MCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTE2MDEwNzEy
# MDAwMFoXDTMxMDEwNzEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
# Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMo
# RGlnaUNlcnQgU0hBMiBBc3N1cmVkIElEIFRpbWVzdGFtcGluZyBDQTCCASIwDQYJ
# KoZIhvcNAQEBBQADggEPADCCAQoCggEBAL3QMu5LzY9/3am6gpnFOVQoV7YjSsQO
# B0UzURB90Pl9TWh+57ag9I2ziOSXv2MhkJi/E7xX08PhfgjWahQAOPcuHjvuzKb2
# Mln+X2U/4Jvr40ZHBhpVfgsnfsCi9aDg3iI/Dv9+lfvzo7oiPhisEeTwmQNtO4V8
# CdPuXciaC1TjqAlxa+DPIhAPdc9xck4Krd9AOly3UeGheRTGTSQjMF287Dxgaqwv
# B8z98OpH2YhQXv1mblZhJymJhFHmgudGUP2UKiyn5HU+upgPhH+fMRTWrdXyZMt7
# HgXQhBlyF/EXBu89zdZN7wZC/aJTKk+FHcQdPK/P2qwQ9d2srOlW/5MCAwEAAaOC
# Ac4wggHKMB0GA1UdDgQWBBT0tuEgHf4prtLkYaWyoiWyyBc1bjAfBgNVHSMEGDAW
# gBRF66Kv9JLLgjEtUYunpyGd823IDzASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBQ
# BgNVHSAESTBHMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzALBglghkgBhv1sBwEwDQYJKoZIhvcNAQELBQAD
# ggEBAHGVEulRh1Zpze/d2nyqY3qzeM8GN0CE70uEv8rPAwL9xafDDiBCLK938ysf
# DCFaKrcFNB1qrpn4J6JmvwmqYN92pDqTD/iy0dh8GWLoXoIlHsS6HHssIeLWWywU
# NUMEaLLbdQLgcseY1jxk5R9IEBhfiThhTWJGJIdjjJFSLK8pieV4H9YLFKWA1xJH
# cLN11ZOFk362kmf7U2GJqPVrlsD0WGkNfMgBsbkodbeZY4UijGHKeZR+WfyMD+Nv
# tQEmtmyl7odRIeRYYJu6DC0rbaLEfrvEJStHAgh8Sa4TtuF8QkIoxhhWz0E0tmZd
# tnR79VYzIi8iNrJLokqV2PWmjlIxggKGMIICggIBATCBhjByMQswCQYDVQQGEwJV
# UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
# Y29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgVGltZXN0YW1w
# aW5nIENBAhANQkrgvjqI/2BAIc4UAPDdMA0GCWCGSAFlAwQCAQUAoIHRMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjExMTIyMTkx
# OTAzWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTh14Ko4ZG+72vKFpG1qrSUpiSb
# 8zAvBgkqhkiG9w0BCQQxIgQgXtDNUawRWgWlxVc4Nlhf4qr19viEqwjuS5b9Gbhl
# MW0wNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgsxCQBrwK2YMHkVcp4EQDQVyD4ykr
# YU8mlkyNNXHs9akwDQYJKoZIhvcNAQEBBQAEggEAez3fjdB3cjxe3iDbBwG6Dp4X
# JXMNC6J8PMq+38E4WsV4kjd59I28LONooQbUCdj9pFUb2Dcb324PIB3SKcr8qURZ
# yhFegF7SmX1YgD4ci8H66ghsWJFVsqW/8aLhcqobbCBo9jlK6hqx7wR9ieLf+kPg
# utR4dTfH4n+W6Ar5wFCVEaqca56LKzxqThuyEAuHyUZCB3M3xTtFzfRaU929i0iT
# XspxHQJdNupfbsKJjfkX9BvOUH+1Y10xPpVm5XeCHEQF+lT7XxAT6HfWWVUolA6A
# DJeQGg0R2Rdai+rbz4einwVx3OCTQ+R5UNqO0MtTzXfbvEEIikhy2Pg4X+8GHA==
# SIG # End signature block
