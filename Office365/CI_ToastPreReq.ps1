<# Office 365 CI Setting #1 Discovery / Remediation Script
Gary Blok (@gwblok) & Mike Terril (@miketerrill)

Change log
2020.05.12 - Add logic to work around if machine / user has several deployments of the apps

#>
$O365ContentAssignmentName = "Microsoft 365 Content"
$InstallAssignmentName = "Microsoft 365 Office - Semi Annual Channel Enterprise_" #Used for finding the User Deployment Application Install Policy

$registryPath = "HKLM:\SOFTWARE\SWD\O365" #Sets Registry Location
$SCVisible = $false
$logfile = "$env:TEMP\o365_Baseline.log"

#region: CMTraceLog Function formats logging in CMTrace style
        function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "365 CI #1 Discovery / Remediate",
 
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		
		    [Parameter(Mandatory=$true)]
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

CMTraceLog -Message  "-------------------------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Starting Office 365 CI Setting #1 Discovery / Remediation Script" -Type 2 -LogFile $LogFile
CMTraceLog -Message  "-------------------------------------------------" -Type 1 -LogFile $LogFile

#Confirm Office 365 Content in CCMCache
$CIModel = Get-CimInstance -Namespace root/ccm/CIModels -ClassName CCM_AppDeliveryTypeSynclet | Where-Object {$_.AppDeliveryTypeName -match $O365ContentAssignmentName}
$ContentID = $CIModel.InstallAction.Content.ContentId | Sort-Object -Unique
foreach ($ID in $ContentID)
    {
    $Cache = Get-CimInstance -Namespace root/ccm/SoftMgmtAgent -ClassName CacheInfoEx | Where-Object {$_.ContentID -eq $ID}                                                                                                                                                                                    
    if ($Cache.ContentComplete -eq $true)
        {
        $CacheComplete = $true
        $CachCompleteID = $ID   
        }
    if ($ID){CMTraceLog -Message  "Content ID: $ID" -Type 1 -LogFile $LogFile}
    if ($CacheComplete){CMTraceLog -Message  "Cache Complete: $CacheComplete" -Type 1 -LogFile $LogFile}
    Else {CMTraceLog -Message  "Content not found in CCMCache" -Type 1 -LogFile $LogFile}
    }

if ($CacheComplete-eq $true) {CMTraceLog -Message  "Cache ID: $ID is Cache Complete" -Type 1 -LogFile $LogFile}

#Check if Office 365 is already installed
$O365 = Get-WmiObject -Namespace 'root\cimv2\sms' -Query "SELECT ProductName,ProductVersion FROM SMS_InstalledSoftware where ARPDisplayName like 'Microsoft Office 365 ProPlus%'"
if ($O365){CMTraceLog -Message  "Office 365 is already installed"-Type 1 -LogFile $LogFile}
else {CMTraceLog -Message "Office 365 is NOT installed"-Type 1 -LogFile $LogFile}


#Get Enable O365 Toast Notification Value
$Enable_O365_Toast = Get-ItemPropertyValue $registryPath Enable_O365_Toast -erroraction SilentlyContinue
if ($Enable_O365_Toast){CMTraceLog -Message "Enable_O365_Toast = $Enable_O365_Toast" -Type 1 -LogFile $LogFile}
else {CMTraceLog -Message  "Enable_O365_Toast Not Created Yet" -Type 1 -LogFile $LogFile}


#Check if the User Deployment Policy has been evaluated and if it has already been made visible in Software Center 
$CMUserPolicyItems = Get-CimInstance -Namespace root/ccm/Policy -ClassName __Namespace | Select-Object -Property Name | Where-Object {$_.Name -notin ("DefaultMachine", "DefaultUser", "Machine")}
$CMUserPolicyItems = $CMUserPolicyItems | Where-Object {$_.Name -notmatch "_Default"}
$CMUserPolicyItems = $CMUserPolicyItems | Where-Object {$_.Name -notmatch "S_1_1_0"}
$AppAssignments = @()
foreach ($Policy in $CMUserPolicyItems)
{
$namespace = "ROOT\ccm\Policy\$($Policy.name)\ActualConfig"
$classname = "CCM_ApplicationCIAssignment"
$CIMClass = Get-CimClass -ClassName $classname -Namespace $namespace -ErrorAction SilentlyContinue
if ($CIMClass){$Assignment = Get-WmiObject -Class $classname -Namespace $namespace | Where-Object {$_.AssignmentName -match $InstallAssignmentName} -ErrorAction SilentlyContinue}
if ($Assignment) 
    {
    $AppAssignments += $Assignment
    #Write-Host $Assignment.AssignmentName
    #Write-Host $Assignment.Assignmentid
    #Write-Host $Policy.Name
    CMTraceLog -Message  "Found Assignment $($Assignment.AssignmentName) " -Type 1 -LogFile $LogFile
    $AppDeployment = Get-WmiObject -Class $classname -Namespace $namespace | ? {$_.AssignmentID -eq $Assignment.AssignmentID}
    if ($AppDeployment.UserUIExperience -eq "TRUE")
        {
        $SCVisible = $true
        CMTraceLog -Message  "SCVisible = True" -Type 1 -LogFile $LogFile
        }
    Else {
        CMTraceLog -Message  "SCVisible = False" -Type 1 -LogFile $LogFile
        CMTraceLog -Message  "Policy user GUID: $($Policy.Name)" -Type 1 -LogFile $LogFile
        }
    }
if ($AppAssignments.Count -lt 1)
    {
    CMTraceLog -Message  "Did not find any assignments that matched $InstallAssignmentName" -Type 1 -LogFile $LogFile
    CMTraceLog -Message  "Unable to determine status for SCVisible" -Type 1 -LogFile $LogFile
    }

}

Function ConfigToastReg {
                [CmdletBinding()]
                Param (
                                [Parameter(Mandatory=$true)] $ToastRegValue
                )

    #Create Registry Keys if needed
    if ( -not ( test-path $registryPath ) ) { 
        new-item -ItemType directory -path $registryPath -force -erroraction SilentlyContinue | out-null
        }
    #Enable Toast Registry Setting
    New-ItemProperty -Path $registryPath -Name "Enable_O365_Toast" -Value $ToastRegValue -Force
    CMTraceLog -Message  " Setting $registryPath Enable_O365_Toast to $ToastRegValue" -Type 1 -LogFile $LogFile
    $Confirm = Get-ItemProperty -Path $registryPath -Name "Enable_O365_Toast"-ErrorAction SilentlyContinue
    if ($Confirm = $ToastRegValue){CMTraceLog -Message  " Successfullyset Enable_O365_Toast to $ToastRegValue" -Type 1 -LogFile $LogFile}
    else{CMTraceLog -Message  " Failed to set Enable_O365_Toast to $ToastRegValue" -Type 3 -LogFile $LogFile}
}

Function EnableSC {
#Enable the User Deployment Policy in Software Center 
$CMUserPolicyItems = Get-CimInstance -Namespace root/ccm/Policy -ClassName __Namespace | Select-Object -Property Name | Where-Object {$_.Name -notin ("DefaultMachine", "DefaultUser", "Machine")}
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
            #$Assignment.AssignmentName
            CMTraceLog -Message  "** Found Assignment $($Assignment.AssignmentName) ** " -Type 1 -LogFile $LogFile
            CMTraceLog -Message  "* Modifing WMI for Deployment *" -Type 1 -LogFile $LogFile
            CMTraceLog -Message  " Changing UserUIExperience to TRUE" -Type 1 -LogFile $LogFile
            CMTraceLog -Message  " Changing EnforcementDeadline to NULL" -Type 1 -LogFile $LogFile
            $AppDeployment = Get-WmiObject -Class $classname -Namespace $namespace | ? {$_.AssignmentID -eq $Assignment.AssignmentID}
            $AppDeployment.UserUIExperience = $true
            $AppDeployment.EnforcementDeadline = $null
            $AppDeployment.Put()
            #Confirm
            $AssignmentConfirm = Get-WmiObject -Class $classname -Namespace $namespace | Where-Object {$_.AssignmentName -match $InstallAssignmentName -and $_.AssignmentID -eq $Assignment.AssignmentID} -ErrorAction SilentlyContinue
            #$AppDeploymentConfirm = Get-WmiObject -Class $classname -Namespace $namespace | Where-Object {$_.AssignmentID -eq $AssignmentConfirm.AssignmentID}
            if ($AssignmentConfirm.UserUIExperience -eq $true) {CMTraceLog -Message  " Confirmed UserUIExperience now $($AssignmentConfirm.UserUIExperience)" -Type 1 -LogFile $LogFile}
            Else {CMTraceLog -Message  " Confirmed UserUIExperience now $($AssignmentConfirm.UserUIExperience)" -Type 3 -LogFile $LogFile}
            if (!$AssignmentConfirm.EnforcementDeadline){CMTraceLog -Message  " Confirmed EnforcementDeadline is NULL" -Type 1 -LogFile $LogFile}
            Else {CMTraceLog -Message  " EnforcementDeadline is $($AssignmentConfirm.EnforcementDeadline)" -Type 3 -LogFile $LogFile}
            }
        } 
    } 
}


#Case 1
If (($CacheComplete -eq "True") -AND (!$O365) -AND (!$SCVisible) -AND ($Enable_O365_Toast -ne "True"))
    {
    #Non-Compliant
    #Enable SC and Enable Toast
    #Write-Output "Non-Compliant:Case 1"
    CMTraceLog -Message  "Non-Compliant:Case 1 - Running Remediation"-Type 2 -LogFile $LogFile
    EnableSC
    ConfigToastReg -ToastRegValue "True"
    CMTraceLog -Message  "Finished running Remediation Functions"-Type 1 -LogFile $LogFile
    }
#Case 2
Elseif (($CacheComplete -eq "True") -AND (!$O365) -AND (!$SCVisible) -AND ($Enable_O365_Toast -eq "True"))
    {
    #Non-Compliant
    #Enable SC
    #Write-Output "Non-Compliant:Case 2"
    CMTraceLog -Message  "Non-Compliant:Case 2 - Running Remediation"-Type 2 -LogFile $LogFile
    EnableSC
    CMTraceLog -Message  "Finished running Remediation Functions"-Type 1 -LogFile $LogFile
    } 
#Case 3
Elseif (($CacheComplete -eq "True") -AND (!$O365) -AND ($SCVisible) -AND ($Enable_O365_Toast -ne "True"))
    {
    #Non-Compliant
    #Enable Toast
    #Write-Output "Non-Compliant:Case 3"
    CMTraceLog -Message  "Non-Compliant:Case 3 - Running Remediation"-Type 2 -LogFile $LogFile
    ConfigToastReg -ToastRegValue "True"
    CMTraceLog -Message  "Finished running Remediation Functions"-Type 1 -LogFile $LogFile
    } 
#Case 4
Elseif (($CacheComplete -eq "True") -AND (!$O365) -AND ($SCVisible) -AND ($Enable_O365_Toast -eq "True"))
    {
    #Compliant
    #Write-Output "Compliant"
    #Write-Output "Case 4"
    CMTraceLog -Message  "Compliant:Case 4"-Type 1 -LogFile $LogFile
    } 
#Case 5
Elseif (($CacheComplete -eq "True") -AND ($O365) -AND ($SCVisible) -AND ($Enable_O365_Toast -ne "True"))
    {
    #Compliant
    #Write-Output "Compliant"
    #Write-Output "Case 5"
    CMTraceLog -Message  "Compliant:Case 5"-Type 1 -LogFile $LogFile
    } 
#Case 6
Elseif (($CacheComplete -eq "True") -AND ($O365) -AND ($SCVisible) -AND ($Enable_O365_Toast -eq "True"))
    {
    #Non-Compliant
    #Disable Toast
    #Write-Output "Non-Compliant:Case 6"
    CMTraceLog -Message  "Non-Compliant:Case 6 - Running Remediation"-Type 2 -LogFile $LogFile
    ConfigToastReg -ToastRegValue "False"
    CMTraceLog -Message  "Finished running Remediation Functions"-Type 1 -LogFile $LogFile
    } 
#Case 7
Elseif (($CacheComplete -ne "True") -AND (!$O365) -AND (!$SCVisible) -AND ($Enable_O365_Toast -ne "True"))
    {
    #Compliant
    #Write-Output "Compliant"
    #Write-Output "Case 7"
    CMTraceLog -Message  "Compliant:Case 7"-Type 1 -LogFile $LogFile
    } 
#Case 8
Elseif (($CacheComplete -ne "True") -AND (!$O365) -AND (!$SCVisible) -AND ($Enable_O365_Toast -eq "True"))
    {
    #Non-Compliant
    #Disable Toast
    #Write-Output "Non-Compliant:Case 8"
    CMTraceLog -Message  "Non-Compliant:Case 8 - Running Remediation"-Type 2 -LogFile $LogFile
    ConfigToastReg -ToastRegValue "False"
    CMTraceLog -Message  "Finished running Remediation Functions"-Type 1 -LogFile $LogFile
    } 
#Case 9
Elseif (($CacheComplete -ne "True") -AND ($O365) -AND (!$SCVisible) -AND ($Enable_O365_Toast -ne "True"))
    {
    #Compliant
    #Write-Output "Compliant"
    #Write-Output "Case 9"
    CMTraceLog -Message  "Compliant:Case 9"-Type 1 -LogFile $LogFile
    } 
#Case 10
Elseif (($CacheComplete -ne "True") -AND ($O365) -AND (!$SCVisible) -AND ($Enable_O365_Toast -eq "True"))
    {
    #Non-Compliant
    #Disable Toast
    Write-Output "Non-Compliant:Case 10"
    CMTraceLog -Message  "Non-Compliant:Case 10 - Running Remediation"-Type 2 -LogFile $LogFile
    ConfigToastReg -ToastRegValue "False"
    CMTraceLog -Message  "Finished running Remediation Functions"-Type 1 -LogFile $LogFile
    } 
#Case 11
Elseif (($CacheComplete -ne "True") -AND ($O365) -AND ($SCVisible) -AND ($Enable_O365_Toast -ne "True"))
    {
    #Compliant
    #Write-Output "Compliant"
    #Write-Output "Case 11"
    CMTraceLog -Message  "Compliant:Case 11"-Type 1 -LogFile $LogFile
    } 
#Case 12
Elseif (($CacheComplete -ne "True") -AND ($O365) -AND ($SCVisible) -AND ($Enable_O365_Toast -eq "True"))
    {
    #Non-Compliant
    #Disable Toast
    #Write-Output "Non-Compliant:Case 12"
    CMTraceLog -Message  "Non-Compliant:Case 12 - Running Remediation"-Type 2 -LogFile $LogFile
    ConfigToastReg -ToastRegValue "False"
    CMTraceLog -Message  "Finished running Remediation Functions"-Type 1 -LogFile $LogFile
    } 
#Case 13
Elseif (($CacheComplete -ne "True") -AND (!$O365) -AND ($SCVisible) -AND ($Enable_O365_Toast -ne "True"))
    {
    #Compliant
    #Write-Output "Compliant"
    #Write-Output "Case 13"
    CMTraceLog -Message  "Compliant:Case 13"-Type 1 -LogFile $LogFile
    } 
#Case 14
Elseif (($CacheComplete -ne "True") -AND (!$O365) -AND ($SCVisible) -AND ($Enable_O365_Toast -eq "True"))
    {
    #Non-Compliant
    #Disable Toast
    #Write-Output "Non-Compliant:Case 14"
    CMTraceLog -Message  "Non-Compliant:Case 14 - Running Remediation"-Type 2 -LogFile $LogFile
    ConfigToastReg -ToastRegValue "False"
    CMTraceLog -Message  "Finished running Remediation Functions"-Type 1 -LogFile $LogFile
    } 
#Case 15
Elseif (($CacheComplete -eq "True") -AND ($O365) -AND (!$SCVisible) -AND ($Enable_O365_Toast -eq "True"))
    {
    #Non-Compliant
    #Disable Toast
    #Write-Output "Non-Compliant:Case 15"
    CMTraceLog -Message  "Non-Compliant:Case 15 - Running Remediation"-Type 2 -LogFile $LogFile
    ConfigToastReg -ToastRegValue "False"
    EnableSC
    CMTraceLog -Message  "Finished running Remediation Functions"-Type 1 -LogFile $LogFile
    } 
CMTraceLog -Message  "-------------------------------------------------" -Type 1 -LogFile $LogFile
CMTraceLog -Message  "Finished Office 365 CI Setting #1Discovery / Remediation Script" -Type 2 -LogFile $LogFile
CMTraceLog -Message  "-------------------------------------------------" -Type 1 -LogFile $LogFile
