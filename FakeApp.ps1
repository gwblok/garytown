<#
Gary Blok - GARYTOWN.COM - @gwblok

Used for Testing Application Deployment Ideas
This "App" Install Script sets a registry key and that's it... the detection is the registry key
Everything else is testing ideas, changing policies, setting reboots, etc.

Change Log
2020.05.29 - Initial Release of CM App Deployment Testing Script

#>

[CmdletBinding()] 
param (

        [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][ValidateSet("Install", "Uninstall")][string]$Method
 
    ) 

$InstallAssignmentName = "FakeApp" #Used for finding the User Deployment Application Install Policy 
$RegistryPath = "HKLM:\SOFTWARE\SWD"
$LogFile = "C:\Windows\Temp\FakeApp_Install.log"

#CMTraceLog Function formats logging in CMTrace style
function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = $InstallAssignmentName,
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$false)]
		    $LogFile
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

#Used to set Exit Code in way that CM registers
function ExitWithCode
{
    param
    (
        $exitcode
    )

    $host.SetShouldExit($exitcode)
    exit
}

#Function that calls the Restart Package Program.  You MUST have set this up and deployed to machines prior to running this, or it won't do anything
function TriggerRebootProgram
    {
    $RestartProgram = Get-CimInstance -ClassName "CCM_SoftwareDistribution" -Namespace "ROOT\ccm\policy\machine\actualconfig" | Where-Object {$_.PKG_Name  -match "Restart Computer" -and $_.PRG_ProgramName -match "Exit Force Restart"}
    if ($RestartProgram)
        {
        CMTraceLog -Message  "Found Restart Package, Triggering Now" -Type 1 -LogFile $LogFile
        $RestartProgramDeployID = $RestartProgram.ADV_AdvertisementID
        $RestartProgramPackageID = $RestartProgram.PKG_PackageID
        $RestartProgramProgramID = $RestartProgram.PRG_ProgramID

        [XML]$XML = $RestartProgram.PRG_Requirements
        $Schedule = $xml.SWDReserved.ScheduledMessageID

        $Program = ([wmi]"ROOT\ccm\policy\machine\actualconfig:CCM_SoftwareDistribution.ADV_AdvertisementID='$($RestartProgramDeployID)',PKG_PackageID='$($RestartProgramPackageID)',PRG_ProgramID='$($RestartProgramProgramID)'")
        $Program.ADV_RepeatRunBehavior = 'RerunAlways'
        $Program.ADV_MandatoryAssignments = 'True'
        $Program.put()

        ([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule($Schedule)
        }
    else {CMTraceLog -Message  "Did not find Package / Program named: Restart Computer - Exit Force Restart" -Type 3 -LogFile $LogFile}
    }

#Not used, but here for reference
Function SetDeadline {
#Enable the User Deployment Policy in Software Center 
$CMUserPolicyItems = Get-CimInstance -Namespace root/ccm/Policy -ClassName __Namespace | Select-Object -Property Name | Where-Object {$_.Name -notin ("DefaultMachine", "DefaultUser")}
$CMUserPolicyItems = $CMUserPolicyItems | Where-Object {$_.Name -notmatch "_Default"}
$CMUserPolicyItems = $CMUserPolicyItems | Where-Object {$_.Name -notmatch "S_1_1_0"}
#$CMUserPolicyItems = Get-CimInstance -Namespace root/ccm/Policy -ClassName __Namespace | Select-Object -Property Name | Where-Object {$_.Name -eq "S_1_5_21_1960408961_287218729_839522115_29201717"} 
#$CMUserPolicyItems = $CMUserPolicyItems | Where-Object {$_.Name -match "S_1_5_21_1123561945_1708537768_1801674531_6347474"}
$Deadline = "20190528024500.000000+***"
foreach ($Policy in $CMUserPolicyItems)
    {
    $Policy.Name
    $namespace = "ROOT\ccm\Policy\$($Policy.name)\ActualConfig"
    $classname = "CCM_ApplicationCIAssignment"
    #Get-CimInstance -Namespace
    $CIMClass = Get-CimClass -ClassName $classname -Namespace $namespace -ErrorAction SilentlyContinue
    
    
    if ($CIMClass){$Assignments = Get-WmiObject -Class $classname -Namespace $namespace | Where-Object {$_.AssignmentName -match $InstallAssignmentName} -ErrorAction SilentlyContinue}

    if ($Assignments) 
        {
        foreach ($Assignment in $Assignments)
            {
            #Write-Output "Assignement Found!!"
            $Assignment.AssignmentName
            CMTraceLog -Message  "** Found Assignment $($Assignment.AssignmentName) ** " -Type 1 -LogFile $LogFile
            CMTraceLog -Message  "** Current Policy: $($Policy.Name) ** " -Type 1 -LogFile $LogFile
            CMTraceLog -Message  "* Modifing WMI for Deployment *" -Type 1 -LogFile $LogFile
            #CMTraceLog -Message  " Changing UserUIExperience to TRUE" -Type 1 -LogFile $LogFile
            CMTraceLog -Message  " Changing EnforcementDeadline to $deadline" -Type 1 -LogFile $LogFile
            $AppDeployment = Get-WmiObject -Class $classname -Namespace $namespace | ? {$_.AssignmentID -eq $Assignment.AssignmentID}
            #$AppDeployment.UserUIExperience
            #$AppDeployment.UserUIExperience = $true
            #$AppDeployment.EnforcementDeadline
            if ($AppDeployment.EnforcementDeadline -ne $null)
                {
                $DeadlineInfo = $AppDeployment.EnforcementDeadline
                CMTraceLog -Message  " Deadline for Deployment was $($AppDeployment.EnforcementDeadline)" -Type 1 -LogFile $LogFile
                }
            else {CMTraceLog -Message  " Deployment had no previous deadline" -Type 2 -LogFile $LogFile}

            $AppDeployment.EnforcementDeadline = $deadline
            $AppDeployment.Put()
            
            #Confirm
            $AssignmentConfirm = Get-WmiObject -Class $classname -Namespace $namespace | Where-Object {$_.AssignmentName -match $InstallAssignmentName -and $_.AssignmentID -eq $Assignment.AssignmentID} -ErrorAction SilentlyContinue
            $AppDeploymentConfirm = Get-WmiObject -Class $classname -Namespace $namespace | Where-Object {$_.AssignmentID -eq $AssignmentConfirm.AssignmentID}
            if ($AppDeploymentConfirm.EnforcementDeadline -ne $null)
                {
                $DeadlineInfo = $AppDeploymentConfirm.EnforcementDeadline
                if ($DeadlineInfo -eq $Deadline){CMTraceLog -Message  " Deadline for Deployment is now $($AppDeploymentConfirm.EnforcementDeadline)" -Type 1 -LogFile $LogFile}
                else{CMTraceLog -Message  " Deadline for Deployment failed to change, still: $($AppDeploymentConfirm.EnforcementDeadline)" -Type 3 -LogFile $LogFile}
                }
            else {CMTraceLog -Message  "Deployment Deadline failed to set, no deadline currently set" -Type 3 -LogFile $LogFile}
            Write-Host "Confirm deadline: $($AppDeployment.EnforcementDeadline)"
            [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000121}') #App Eval
            }

        }  
         
    }
} 

#Not used, but here for reference
Function ClearDeadline {
#Enable the User Deployment Policy in Software Center 
$CMUserPolicyItems = Get-CimInstance -Namespace root/ccm/Policy -ClassName __Namespace | Select-Object -Property Name | Where-Object {$_.Name -notin ("DefaultMachine", "DefaultUser")}
$CMUserPolicyItems = $CMUserPolicyItems | Where-Object {$_.Name -notmatch "_Default"}
$CMUserPolicyItems = $CMUserPolicyItems | Where-Object {$_.Name -notmatch "S_1_1_0"}
#$CMUserPolicyItems = Get-CimInstance -Namespace root/ccm/Policy -ClassName __Namespace | Select-Object -Property Name | Where-Object {$_.Name -eq "S_1_5_21_1960408961_287218729_839522115_29201717"} 
#$CMUserPolicyItems = $CMUserPolicyItems | Where-Object {$_.Name -match "S_1_5_21_1123561945_1708537768_1801674531_6347474"}
foreach ($Policy in $CMUserPolicyItems)
    {
    #$Policy.Name
    $namespace = "ROOT\ccm\Policy\$($Policy.name)\ActualConfig"
    $classname = "CCM_ApplicationCIAssignment"
    #Get-CimInstance -Namespace
    $CIMClass = Get-CimClass -ClassName $classname -Namespace $namespace -ErrorAction SilentlyContinue
    

    if ($CIMClass){$Assignments = Get-WmiObject -Class $classname -Namespace $namespace | Where-Object {$_.AssignmentName -match $InstallAssignmentName} -ErrorAction SilentlyContinue}

    if ($Assignments) 
        {
        foreach ($Assignment in $Assignments)
            {
            #Write-Output "Assignement Found!!"
            $Assignment.AssignmentName
            CMTraceLog -Message  "** Found Assignment $($Assignment.AssignmentName) ** " -Type 1 -LogFile $LogFile
            CMTraceLog -Message  "** Current Policy: $($Policy.Name) ** " -Type 1 -LogFile $LogFile
            CMTraceLog -Message  "* Modifing WMI for Deployment *" -Type 1 -LogFile $LogFile
            #CMTraceLog -Message  " Changing UserUIExperience to TRUE" -Type 1 -LogFile $LogFile
            CMTraceLog -Message  " Changing EnforcementDeadline to NULL" -Type 1 -LogFile $LogFile
            $AppDeployment = Get-WmiObject -Class $classname -Namespace $namespace | ? {$_.AssignmentID -eq $Assignment.AssignmentID}
            $AppDeployment.UserUIExperience = $true
            #$AppDeployment.UserUIExperience
            #$AppDeployment.EnforcementDeadline
            $AppDeployment.EnforcementDeadline = $null
            $AppDeployment.Put()
            #Confirm
            $AssignmentConfirm = Get-WmiObject -Class $classname -Namespace $namespace | Where-Object {$_.AssignmentName -match $InstallAssignmentName -and $_.AssignmentID -eq $Assignment.AssignmentID} -ErrorAction SilentlyContinue
            #$AppDeploymentConfirm = Get-WmiObject -Class $classname -Namespace $namespace | Where-Object {$_.AssignmentID -eq $AssignmentConfirm.AssignmentID}
            #if ($AssignmentConfirm.UserUIExperience -eq $true) {CMTraceLog -Message  " Confirmed UserUIExperience now $($AssignmentConfirm.UserUIExperience)" -Type 1 -LogFile $LogFile}
            #Else {CMTraceLog -Message  " Confirmed UserUIExperience now $($AssignmentConfirm.UserUIExperience)" -Type 3 -LogFile $LogFile}
            if (!$AssignmentConfirm.EnforcementDeadline){CMTraceLog -Message  " Confirmed EnforcementDeadline is NULL" -Type 1 -LogFile $LogFile}
            Else {CMTraceLog -Message  " EnforcementDeadline is $($AssignmentConfirm.EnforcementDeadline)" -Type 3 -LogFile $LogFile}
            [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000121}') #App Eval
            }
        } 
    } 
}

#Not used, but here for reference
Function TriggerAppEval
    {
    #Includes 2 Methods, but both only seem to trigger Machine Evals, was unable to get it to trigger User App Eval
    #Method 1
    [Void]([wmiclass]'ROOT\ccm:SMS_Client').TriggerSchedule('{00000000-0000-0000-0000-000000000121}') #App Eval
    #Method 2
    $SCCMClient = New-Object -COM 'CPApplet.CPAppletMgr'
    ($SCCMClient.GetClientActions() | Where-Object {$_.Name -match "Application"}).PerformAction()
    }

if ($Method -eq "Install")
    {
    if (!(Test-Path $RegistryPath)){New-Item -Path $RegistryPath}
    #Set the Registry Key, used for Detection
    Set-ItemProperty -Path $RegistryPath -Name "FakeApp" -Value "True" -Force
    
    TriggerRebootProgram #Triggers the Package Program that tells CM to Restart Computer
    
    #SetDeadline  #No longer used, this Idea did not pan out
    CMTraceLog -Message "Exit Script with code: 3010" -Type 1 -LogFile $LogFile
    ExitWithCode -exitcode 3010 #Triggers Restart Dialog and sets the Software Center Status to "Restart"
    }


if ($Method -eq "Uninstall")
    {
    #Switch the Value to False to make the detection think the "App" is not installed.
    Set-ItemProperty -Path $RegistryPath -Name "FakeApp" -Value "False" -Force
    #ClearDeadline #No longer used, this Idea did not pan out
    }
