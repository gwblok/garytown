<# 
 2019-08-09 - Fixed Typo - Thanks @SuneThomsenDK
 2019-03-20 Modified by @gwblok
 Added Several Text Boxes  (3 & 4)
 Text Box 3 = TS Step Name (Pulled from TS Variable)
 Text Box 4 = Windows Setup Engine % Complete (Pulled from Registry)

 This now pulls in the Rotating Text from the Task Sequence variables.. use "Set Dynamic Task Sequence Variable" Step, then create as many as you like.
  - Variable Name must start with SA_ ex: (SA Splash Array)
    SA_001 This Line never actually displays
    SA_002 We're upgrading you to Windows 10 %SMSTS_BUILD%
    SA_003 It may take 60 - 120 minutes
    WindowBackGroundDefault
 This now pulls colors from the Task Sequence variables as well. Example TS Vars SC_ (SC Splash Color)
    SC_WindowBackGroundDefault = Default Color of Back Ground
    SC_ColourBrighterAnimation1 = Starting Color -> Fades to SC_ColourBrighterAnimation2
    SC_ColourBrighterAnimation2
    SC_ColourDarkerAnimation1 = Starting Color -> Fades to SC_ColourDarkerAnimation2
    SC_ColourDarkerAnimation2

        SC_ColourBrighterAnimation1 Should be set the same as SC_ColourDarkerAnimation2
        SC_ColourBrighterAnimation2 Should be set the same as SC_ColourDarkerAnimation1

 SMSAgent https://smsagent.blog/2018/08/21/create-a-custom-splash-screen-for-a-windows-10-in-place-upgrade/
 Creates a full screen 'background' styled for a Windows 10 upgrade, and hides the task bar
 Called by the "Show-OSUpgradeBackground" script
#>

Param($DeviceName)

try
{
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
    #New-Item C:\temp\ScreenBackground.log -ItemType File
}
catch
{
	Write-Verbose "Not running in a task sequence."
}

# Add required assemblies
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms,System.Drawing
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
Add-Type -Path "$PSSCriptRoot\bin\MahApps.Metro.dll"
Add-Type -Path "$PSSCriptRoot\bin\System.Windows.Interactivity.dll"

# Find screen by DeviceName
$Screens = [System.Windows.Forms.Screen]::AllScreens
$Screen = $Screens | Where {$_.DeviceName -eq $DeviceName}

# Add custom type to hide the taskbar
# Thanks to https://stackoverflow.com/questions/25499393/make-my-wpf-application-full-screen-cover-taskbar-and-title-bar-of-window
$Source = @"
using System;
using System.Runtime.InteropServices;

public class Taskbar
{
    [DllImport("user32.dll")]
    private static extern int FindWindow(string className, string windowText);
    [DllImport("user32.dll")]
    private static extern int ShowWindow(int hwnd, int command);

    private const int SW_HIDE = 0;
    private const int SW_SHOW = 1;

    protected static int Handle
    {
        get
        {
            return FindWindow("Shell_TrayWnd", "");
        }
    }

    private Taskbar()
    {
        // hide ctor
    }

    public static void Show()
    {
        ShowWindow(Handle, SW_SHOW);
    }

    public static void Hide()
    {
        ShowWindow(Handle, SW_HIDE);
    }
}
"@
Add-Type -ReferencedAssemblies 'System', 'System.Runtime.InteropServices' -TypeDefinition $Source -Language CSharp

# Find the user identity from the domain if possible
Try
{
    $PrincipalContext = [System.DirectoryServices.AccountManagement.PrincipalContext]::new([System.DirectoryServices.AccountManagement.ContextType]::Domain, [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain())
    $GivenName = ([System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($PrincipalContext,[System.DirectoryServices.AccountManagement.IdentityType]::SamAccountName,[Environment]::UserName)).GivenName
    $PrincipalContext.Dispose()
}
Catch {}

# Create a WPF window
$Window = New-Object System.Windows.Window
if ($TSENV){$window.Background = $tsenv.Value('SC_WindowBackGroundDefault')}
Else{$window.Background = "#012a47"}
$Window.WindowStyle = [System.Windows.WindowStyle]::None
$Window.ResizeMode = [System.Windows.ResizeMode]::NoResize
$Window.Foreground = [System.Windows.Media.Brushes]::White
$window.Topmost = $True

# Get the bounds of the primary screen
$Bounds = $Screen.Bounds

# Assemble a grid
$Grid = New-object System.Windows.Controls.Grid
$Grid.Width = "NaN"
$Grid.Height = "NaN"
$Grid.HorizontalAlignment = "Stretch"
$Grid.VerticalAlignment = "Stretch"

# Add a column
$Column = New-Object System.Windows.Controls.ColumnDefinition
$Grid.ColumnDefinitions.Add($Column)

# Add rows
$Row = New-Object System.Windows.Controls.RowDefinition
$Row.Height = "1*"
$Grid.RowDefinitions.Add($Row)
$Row = New-Object System.Windows.Controls.RowDefinition
$Row.Height = [System.Windows.GridLength]::Auto
$Grid.RowDefinitions.Add($Row)
$Row = New-Object System.Windows.Controls.RowDefinition
$Row.Height = [System.Windows.GridLength]::Auto
$Grid.RowDefinitions.Add($Row)
$Row = New-Object System.Windows.Controls.RowDefinition
$Row.Height = "1*"
$Grid.RowDefinitions.Add($Row)

# Add a progress ring
$ProgressRing = [MahApps.Metro.Controls.ProgressRing]::new()
$ProgressRing.Opacity = 0
$ProgressRing.IsActive = $false
$ProgressRing.Margin = "0,0,0,60"
$Grid.AddChild($ProgressRing)
$ProgressRing.SetValue([System.Windows.Controls.Grid]::RowProperty,1)

# Add a textblock
$TextBlock = New-Object System.Windows.Controls.TextBlock
If ($GivenName)
{
    $TextBlock.Text = "Hi $GivenName"
}
Else
{
    $TextBlock.Text = "Hey Team Member"
}
$TextBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap
$TextBlock.MaxWidth = $Bounds.Width
$TextBlock.Margin = "0,0,0,120"
$TextBlock.FontSize = 50
$TextBlock.FontWeight = [System.Windows.FontWeights]::Light
$TextBlock.VerticalAlignment = "Top"
$TextBlock.HorizontalAlignment = "Center"
$TextBlock.Opacity = 0
$Grid.AddChild($TextBlock)
$TextBlock.SetValue([System.Windows.Controls.Grid]::RowProperty,2)

# Add a textblock
$TextBlock2 = New-Object System.Windows.Controls.TextBlock
$TextBlock2.Margin = "0,0,0,60"
$TextBlock2.Text = "Don't turn off your PC"
$TextBlock2.TextWrapping = [System.Windows.TextWrapping]::Wrap
$TextBlock2.MaxWidth = $Bounds.Width
$TextBlock2.FontSize = 25
$TextBlock2.FontWeight = [System.Windows.FontWeights]::Light
$TextBlock2.VerticalAlignment = "Bottom"
$TextBlock2.HorizontalAlignment = "Center"
$TextBlock2.Opacity = 0
$Grid.AddChild($TextBlock2)
$TextBlock2.SetValue([System.Windows.Controls.Grid]::RowProperty,3)

# Add a textblock (@gwblok Change)
$TextBlock3 = New-Object System.Windows.Controls.TextBlock
$TextBlock3.Margin = "0,0,0,120"
$TextBlock3.Text = "Task Sequence Step Should be Here"
$TextBlock3.TextWrapping = [System.Windows.TextWrapping]::Wrap
$TextBlock3.MaxWidth = $Bounds.Width
$TextBlock3.FontSize = 15
$TextBlock3.FontWeight = [System.Windows.FontWeights]::Light
$TextBlock3.VerticalAlignment = "Bottom"
$TextBlock3.HorizontalAlignment = "Center"
$TextBlock3.Opacity = 0
$Grid.AddChild($TextBlock3)
$TextBlock3.SetValue([System.Windows.Controls.Grid]::RowProperty,4)

# Add a textblock (@gwblok Change)
$TextBlock4 = New-Object System.Windows.Controls.TextBlock
$TextBlock4.Margin = "0,0,60,60"
$TextBlock4.Text = "Windows Setup Engine: 0%"
$TextBlock4.TextWrapping = [System.Windows.TextWrapping]::Wrap
$TextBlock4.MaxWidth = $Bounds.Width
$TextBlock4.FontSize = 20
$TextBlock4.FontWeight = [System.Windows.FontWeights]::Light
$TextBlock4.VerticalAlignment = "Bottom"
$TextBlock4.HorizontalAlignment = "Right"
$TextBlock4.Opacity = 0
$TextBlock4.Visibility = 'Hidden'
$Grid.AddChild($TextBlock4)
$TextBlock4.SetValue([System.Windows.Controls.Grid]::RowProperty,5)

# Add to window
$Window.AddChild($Grid)

# Create some animations
if ($TSENV)
    {
    $FadeinAnimation = [System.Windows.Media.Animation.DoubleAnimation]::new(0,1,[System.Windows.Duration]::new([Timespan]::FromSeconds(3)))
    $FadeOutAnimation = [System.Windows.Media.Animation.DoubleAnimation]::new(1,0,[System.Windows.Duration]::new([Timespan]::FromSeconds(3)))
    $ColourBrighterAnimation = [System.Windows.Media.Animation.ColorAnimation]::new($tsenv.Value('SC_ColourBrighterAnimation1'),$tsenv.Value('SC_ColourBrighterAnimation2'),[System.Windows.Duration]::new([Timespan]::FromSeconds(5)))
    $ColourDarkerAnimation = [System.Windows.Media.Animation.ColorAnimation]::new($tsenv.Value('SC_ColourDarkerAnimation1'),$tsenv.Value('SC_ColourDarkerAnimation2'),[System.Windows.Duration]::new([Timespan]::FromSeconds(5)))
    }
Else
    {
    $FadeinAnimation = [System.Windows.Media.Animation.DoubleAnimation]::new(0,1,[System.Windows.Duration]::new([Timespan]::FromSeconds(3)))
    $FadeOutAnimation = [System.Windows.Media.Animation.DoubleAnimation]::new(1,0,[System.Windows.Duration]::new([Timespan]::FromSeconds(3)))
    $ColourBrighterAnimation = [System.Windows.Media.Animation.ColorAnimation]::new("#012a47","#1271b5",[System.Windows.Duration]::new([Timespan]::FromSeconds(5)))
    $ColourDarkerAnimation = [System.Windows.Media.Animation.ColorAnimation]::new("#1271b5","#012a47",[System.Windows.Duration]::new([Timespan]::FromSeconds(5)))
    }



if ($TSENV)
    {
    $TextArrayVars = (New-Object -COMObject Microsoft.SMS.TSEnvironment).GetVariables() | Where-Object {$_ -Like "SA_*"}
    $TextArray = foreach ($Values in $TextArrayVars) {$tsenv.Value($Values)}
    }
Else
    {
    # An array of sentences to display, in order. Leave the first one blank as the 0 index gets skipped.
    $TextArray = @(
        "This Line never actually displays"
        "We're upgrading you to Windows 10 $($TSENV.Value('SMSTS_BUILD'))"
        "It may take 60 - 120 minutes"
        "Your PC will restart several times"
        "Should anything go wrong, contact your..."
        "... Line of Business Help Desk."
        )
    }
$script:i = 0
# Start a dispatcher timer. This is used to control when the sentences are changed.
$TimerCode = {

    $ProgressRing.IsActive = $True
    
    # The IF statement number should equal the number of sentences in the TextArray
    $NumberofElements = $TextArray.Count -1
    If ($script:i -lt $NumberofElements)
    {
        $FadeoutAnimation.Add_Completed({            
            $TextBlock.Opacity = 0
            $TextBlock.Text = $TextArray[$script:i]
            $TextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)

        })   
        $TextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeoutAnimation) 
    }
    # The final sentence to display ongoing
    ElseIf ($script:i -eq $NumberofElements)
    {
        $script:i = 0
        $FadeoutAnimation.Add_Completed({            
            $TextBlock.Opacity = 0
            $TextBlock.Text = "We're upgrading this PC to Windows 10 $($TSENV.Value('SMSTS_BUILD'))"
            $TextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)

        })   
        $TextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeoutAnimation) 
    }
    Else
        {
        # Restore the taskbar
        [Taskbar]::Show()

        # Restore the mouse cursor
        [System.Windows.Forms.Cursor]::Show()

        $DispatcherTimer.Stop()
        $DispatcherTimerTS.Stop()
        exit
        }

    
    if ($tsenv)
        {
        #If Error Window Launches, Exit Splash Screen - Make sure your Error Dialog step is named below
        #Using this Method for Error Handling: https://www.asquaredozen.com/2018/12/14/building-an-even-better-task-sequence/
        if ($tsenv.Value('_SMSTSCurrentActionName') -eq "Launch Custom Dialog") 
            {
            # Restore the taskbar
            [Taskbar]::Show()

            # Restore the mouse cursor
            [System.Windows.Forms.Cursor]::Show()

            $DispatcherTimer.Stop()
            $DispatcherTimerTS.Stop()
            Exit
            }
         #Stop the TS Timer, set new Text Message for the Step Name, and "Activate" the % Complete Text Box
         if ($DispatcherTimerTS.IsEnabled -and $tsenv.Value('_SMSTSCurrentActionName') -eq "Upgrade Operating System. DO NOT TURN OFF YOUR PC") 
            {
            $DispatcherTimerTS.Stop()
            $TextBlock3.Text = "Windows 10 Setup Engine Running Upgrade Process"
            $TextBlock4.Visibility = 'Visible'
            }
          if ($DispatcherTimerTS.IsEnabled -and $tsenv.Value('_SMSTSCurrentActionName') -eq "Upload Inventory Data") 
            {
            $DispatcherTimerTS.Stop()
            $TextBlock3.Text = "Nearly Complete, just one more reboot, right after it displays the logon screen."
            }        
         
         if ($DispatcherTimerUpgrade.IsEnabled -eq $false -and $tsenv.Value('_SMSTSCurrentActionName') -eq "Upgrade Operating System. DO NOT TURN OFF YOUR PC") 
            {
            $DispatcherTimerUpgrade.Start()
            }
        }
    #If Not in TS... Exit!
    Else 
        {
         Restore the taskbar
        [Taskbar]::Show()

         Restore the mouse cursor
        [System.Windows.Forms.Cursor]::Show()

        $DispatcherTimer.Stop()
        $DispatcherTimerTS.Stop()
        Exit
        }

    $ColourBrighterAnimation.Add_Completed({            
        $Window.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty,$ColourDarkerAnimation)
    })   
    $Window.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty,$ColourBrighterAnimation)

    $Script:i++
}
#Main Text Timer
$DispatcherTimer = New-Object -TypeName System.Windows.Threading.DispatcherTimer
$DispatcherTimer.Interval = [TimeSpan]::FromSeconds(10)
$DispatcherTimer.Add_Tick($TimerCode)

#Step Name Timer Controls
#Runs at every 1/2 second to try to make sure it catches all of the step names.
$TimerCodeTS = {
        
        $TestInfo = $tsenv.Value('_SMSTSCurrentActionName')
        $TextBlock3.Text = $TestInfo

}
$DispatcherTimerTS = New-Object -TypeName System.Windows.Threading.DispatcherTimer
$DispatcherTimerTS.Interval = [TimeSpan]::FromMilliseconds(500)
$DispatcherTimerTS.Add_Tick($TimerCodeTS)

#Timer for Upgrade % - Should be inactivate until activated in the Main Text Timer when it reaches the upgrade step.    
$TimerCodeUpgrade = {
        
        
        $TestInfoUpgrade = Get-ItemPropertyValue -Path "HKLM:\SYSTEM\Setup\MoSetup\Volatile" -Name "SetupProgress"
        if ($TestInfoUpgrade) {$TextBlock4.Text = "Windows Setup Engine: $($TestInfoUpgrade) %"}
        else {$TextBlock4.Text = "Windows Setup Engine: Initializing"}


}
$DispatcherTimerUpgrade = New-Object -TypeName System.Windows.Threading.DispatcherTimer
$DispatcherTimerUpgrade.Interval = [TimeSpan]::FromSeconds(5)
$DispatcherTimerUpgrade.Add_Tick($TimerCodeUpgrade)



# Event: Window loaded
$Window.Add_Loaded({
    
    # Activate the window to bring it to the fore
    $This.Activate()

    # Fill the screen
    $Bounds = $screen.Bounds
    $Window.Left = $Bounds.Left
    $Window.Top = $Bounds.Top
    $Window.Height = $Bounds.Height
    $Window.Width = $Bounds.Width

    # Hide the taskbar
    [TaskBar]::Hide()

    # Hide the mouse cursor
    [System.Windows.Forms.Cursor]::Hide()

    # Begin animations
    $TextBlock.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $TextBlock2.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $TextBlock3.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $TextBlock4.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $ProgressRing.BeginAnimation([System.Windows.Controls.TextBlock]::OpacityProperty,$FadeinAnimation)
    $ColourBrighterAnimation.Add_Completed({            
        $Window.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty,$ColourDarkerAnimation)
    })   
    $Window.Background.BeginAnimation([System.Windows.Media.SolidColorBrush]::ColorProperty,$ColourBrighterAnimation)

})

# Event: Window closing
$Window.Add_Closing({

    # Restore the taskbar
    [Taskbar]::Show()

    # Restore the mouse cursor
    [System.Windows.Forms.Cursor]::Show()

    $DispatcherTimer.Stop()
    $DispatcherTimerTS.Stop()
})

# Event: Allows to close the window on right-click (uncomment for testing)
<#
$Window.Add_MouseRightButtonDown({

    $This.Close()

})
#>

# Display the window
$DispatcherTimer.Start()
$DispatcherTimerTS.Start()
$DispatcherTimerUpgrade.Start()
$Window.ShowDialog()
