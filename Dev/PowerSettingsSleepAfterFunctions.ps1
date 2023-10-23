<#
	Gary Blok | GARYTOWN.COM | @gwblok

    .SYNOPSIS
	Get & Set Sleep After Settings

	.PARAMETER Minutes
	Set the timeout in Minutes for when the computer Sleeps
    0 = Never idel to sleep
    
    .PARAMETER PowerSource
    set the minutes for if on Battery or AC

	.EXAMPLE Se "Do nothing"
	Set-SleepAfter -Minutes 120 -PowerSource AC

	.NOTES
	https://learn.microsoft.com/en-us/windows-hardware/customize/power-settings/sleep-settings-sleep-idle-timeout

    Thanks to @farag2 for a template:
    https://github.com/farag2/Utilities/blob/master/AD/Set-CloseLidAction.ps1
#>

function Get-PowerSettingSleepAfter{
    # Get active plan
    # Get-CimInstance won't work due to Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan doesn't have the "Activate" trigger as Get-WmiObject does
    $CurrentPlan = Get-WmiObject -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object -FilterScript {$_.IsActive}

    # Get "Lid closed" setting
    $SleepAfterSetting = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_Powersetting | Where-Object -FilterScript {$_.ElementName -eq "Sleep after"}

    # Get GUIDs
    $CurrentPlanGUID = [Regex]::Matches($CurrentPlan.InstanceId, "{.*}" ).Value
    $SleepAfterGUID = [Regex]::Matches($SleepAfterSetting.InstanceID, "{.*}" ).Value

    # Get "Plugged in lid" setting (DC)

    $DC = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerSettingDataIndex | Where-Object -FilterScript {
        ($_.InstanceID -eq "Microsoft:PowerSettingDataIndex\$CurrentPlanGUID\DC\$SleepAfterGUID")
        }
    # Get "Plugged in lid" setting (AC)

	    $AC = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerSettingDataIndex | Where-Object -FilterScript {
	    ($_.InstanceID -eq "Microsoft:PowerSettingDataIndex\$CurrentPlanGUID\AC\$SleepAfterGUID")
        }
    [int]$ACMinutes = $AC.SettingIndexValue / 60
    [int]$DCMinutes = $DC.SettingIndexValue / 60
    $ReturnResults = New-Object System.Object
    $ReturnResults | Add-Member -MemberType NoteProperty -Name "AC" -Value $ACMinutes -Force
    $ReturnResults | Add-Member -MemberType NoteProperty -Name "DC" -Value $DCMinutes -Force
    return $ReturnResults
}

function Set-PowerSettingSleepAfter
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[int] $Minutes,
        [Parameter(Mandatory = $true)]
        [ValidateSet(
			"AC",
			"Battery"
		)]
		[string]$PowerSource
	)

    #Get Seconds
    [int]$Seconds = $Minutes * 60
    if ($Seconds -gt 18000){
        $Seconds = 18000
        Write-Output "Max Time is 5 hours, settings to 300 minutes"
    }


	# Get active plan
	# Get-CimInstance won't work due to Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerPlan doesn't have the "Activate" trigger as Get-WmiObject does
	$CurrentPlan = Get-WmiObject -Namespace root\cimv2\power -ClassName Win32_PowerPlan | Where-Object -FilterScript {$_.IsActive}

	# Get "Lid closed" setting
	$SleepAfterSetting = Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_Powersetting | Where-Object -FilterScript {$_.ElementName -eq "Sleep after"}

	# Get GUIDs
	$CurrentPlanGUID = [Regex]::Matches($CurrentPlan.InstanceId, "{.*}" ).Value
	$SleepAfterGUID = [Regex]::Matches($SleepAfterSetting.InstanceID, "{.*}" ).Value

	# Get and set "Plugged in lid" setting (DC)
    if ($PowerSource -eq "Battery"){
	    Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerSettingDataIndex | Where-Object -FilterScript {
		    ($_.InstanceID -eq "Microsoft:PowerSettingDataIndex\$CurrentPlanGUID\DC\$SleepAfterGUID")
	    } | Set-CimInstance -Property @{SettingIndexValue = $Seconds}
    }
    # Get and set "Plugged in lid" setting (AC)
    if ($PowerSource -eq "AC"){
	    Get-CimInstance -Namespace root\cimv2\power -ClassName Win32_PowerSettingDataIndex | Where-Object -FilterScript {
		    ($_.InstanceID -eq "Microsoft:PowerSettingDataIndex\$CurrentPlanGUID\AC\$SleepAfterGUID")
	    } | Set-CimInstance -Property @{SettingIndexValue = $Seconds}
    }

	# Refresh
	# $CurrentPlan | Invoke-CimMethod -MethodName Activate results in "This method is not implemented in any class"
	$CurrentPlan.Activate
}

#Example
#Set-SleepAfter -Minutes 120 -PowerSource AC
