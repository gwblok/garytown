  
<#GARYTOWN.COM @GWBLOK
Low Disk Space Remediation Script & JIRA Task Creation
This script will try several different disk cleanup items and checking in between section before continuing.
You can add more cleanup items in if you like by replicating and modifying an  "if ((Get-FreeSpace) -lt $MinFreeSpace)" Section
At the end, if it still doesn't have enough free space, it create a report of the large folders based on the diskhog script
It then creates the Jira Task and attaches the logs.
#>

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
$MinFreeSpace = 25GB #GB
$ScriptLogPath = "$env:ProgramData\Intune\DiskManagement\DiskManagement.log"
$CleanDiskLogPath = "$env:ProgramData\Intune\DiskManagement\DiskCleanup.log"
$DiskHogLog = "$env:ProgramData\Intune\DiskManagement\DiskHog.XML"

<#
#Connection Creds to JIRA Cloud
#https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/
$JiraName = "jira@garytown.com" #Not Real Email, Just Example
$JiraToken = 'kdjlkj2423jlk2j32lk3j' | ConvertTo-SecureString -Force -AsPlainText #Not real Token, just example
if (!($Credential)){$Credential = New-Object System.Management.Automation.PsCredential("$JiraName",$JiraToken)}
$JiraConfigServer = "https://garytown.atlassian.net" #This is real... you'll want to replace with your own
$JiraProjectID = 'IPR' #Replace with your Project ID in Jira
#>
<#Functions 

CMTraceLog: https://github.com/gwblok/garytown/blob/master/CM_PowerShell_Snips/Function-CMTracelog.ps1 
CleanDisk: https://github.com/joshuaallenshaw/KISS-PSScripts/blob/master/KISS-PSScripts/Invoke-CleanDisk.ps1
DiskHog: https://gist.github.com/keithga/79b2441b2d75eeefb77f3321e749599e

#>
function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
		    [Parameter(Mandatory=$false)]
		    $Component = "Script",
		    [Parameter(Mandatory=$false)]
		    [int]$Type,
		    [Parameter(Mandatory=$true)]
		    $LogFile = "$env:ProgramData\Logs\IForgotToName.log"
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
	    $LogMessage.Replace("`0","") | Out-File -Append -Encoding UTF8 -FilePath $LogFile
    }
Function Invoke-CleanDisk {
	<#
    .SYNOPSIS
		Cleans the disk of files and fodlers that can be removed.

	.DESCRIPTION
		Optionally cleans various areas of windows file systems.  Defaults to a 7 day retention for safety.
		User Mode tasks are safe to run frequently. These tasks focus on the current user and are intended to be run as a logon or logoff script.
		System Mode tasks are more aggressive and should not be run too frequently.  Some of these tasks are designed to be run when storage is low
		or maintenance is needed.

		Author - Joshua Allen Shaw

	.PARAMETER Mode
		User or System. Determines the time of action performed for many of the other parameters.
		System Mode requires administrative permissions.

	.PARAMETER TheWorks
		System Mode   Performs an a aggressive clean with 1 parameter. Equivalent to -ResetCompStore -EmptyWinLogs
		              -EmptyWinUpdDownload -EmptyRecycleBin -EmptyUserTemp -EmptyWinTemp -EmptyTempInternet -EmptyRDPCache -EmptyUserDownload

	.PARAMETER RetentionTime
		Integer.  Set the number of days to retain during empty.
		Defaults to 7 Days.

	.PARAMETER ReportStats
		Switch.  Reports the space Freed.

	.PARAMETER LogPath
		String. Enables logging to path specified.

	.PARAMETER ResetCompStore
		System Mode   Integrate previous updates into current store and clear the udpate folder of archives.

		You will not be able to rollback previously installed updates, but you free up a lot of space.

	.PARAMETER EmptyWinLogs
		System Mode   Removes CBS persist logs and DISM logs.

		A frequent need to clear the persist logs indicates that you have a problem with Windows.

	.PARAMETER EmptyWinDumpFiles
		System Mode   Removes memory dump files.

		Removing a dump file reduces the ability to troubleshoot a crash.  It is not recommended on machines with issues.

	.PARAMETER RemoveChkDskFragments
		System Mode   Removes fragment files created by chkdsk.

		Removing a dump file reduces the ability to troubleshoot a crash.  It is not recommended on machines with issues.

	.PARAMETER EmptyWinUpdDownload
		System Mode   Switch to empty the Download folder for Windows Update.  Respects "RetentionTime" Parameter.

		This should always be run with or after ResetCompStore parameter.  Used too frequently will impede WU performance.

	.PARAMETER RemoveWinOld
		System Mode   Switch to delete the Windows.Old folder left behind after large updates.

		You will not be able to roll back to the previous version of Windows, but you free up a lot of space.

	.PARAMETER EmptyRecycleBin
		User Mode     Empty the Recycle Bin for the current user. Respects "RetentionTime" Parameter.
		System Mode   Empty the Recycle Bin for all users. Respects "RetentionTime" Parameter.

	.PARAMETER EmptyUserTemp
		User Mode     Empty the current user's temporary folder. Respects "RetentionTime" Parameter.
		System Mode   Empty all users' temporary folder. Respects "RetentionTime" Parameter.

	.PARAMETER EmptyWinTemp
		System Mode   Empty the Windows Temporary folder.  Do not run this too frequently. Respects "RetentionTime" Parameter.

	.PARAMETER EmptyTempInternet
		User Mode     Empty IE, Chrome, and Firefox temporary internet files for the current user.
		System Mode   Empty IE, Chrome, and Firefox temporary internet files for all users.

		Edge browser uses Windows Temp folder.

	.PARAMETER EmptyRDPCache
		User Mode     Remove old RDP cache files from current user profile. Respects "RetentionTime" Parameter.
		System Mode   Remove old RDP cache files from all user profiles. Respects "RetentionTime" Parameter.

		Not advised with 0 retention time while currently connected to RDP Session.

	.PARAMETER EmptyUserDownload
		User Mode     Switch to empty the Download folder for the current user. Respects "RetentionTime" Parameter.
		System Mode   Switch to empty the Download folder for all users. Respects "RetentionTime" Parameter.

	.PARAMETER RemoveJunkFolders
		System Mode   Attempts to find and removed junk folders left behind by installers. Respects "RetentionTime" Parameter.

		Uses Regex to identify folders.  There is a possibility that root folders not present on most machines could get caught up.
		It is suggested to test this with -WhatIf before rolling it out to automation.

	.PARAMETER OtherFilesFolders
		String Array.  Array of files to remove.  Be mindful of mode used with respect to the files being removed.

	.PARAMETER DiskCleanTool
		Specifies a SageRun value to run the Windows Disk Cleanup Tool with (see https://support.microsoft.com/en-us/kb/253597).
		This option is a little safer than some of the more forceful methods of this script.

	.PARAMETER WhatIf
		Dry Run.

	.EXAMPLE
		Invoke-CleanDisk -Mode System -EmptyRecycleBin -EmptyWinTemp -EmptyUserTemp

		Empty the Recycle Bin, the Windows TEMP folder and the user TEMP folder for all users.

	.EXAMPLE
		Invoke-CleanDisk -Mode System -EmptyRecycleBin -OtherFilesFolders @("c:\test*.txt","c:\video*.mp4","c:\temp",c:\admintools") -DiskCleanTool 6

		Empty the Recycle Bin, remove custom set of files and folders asnd run the Windows Disk Cleanup Tool with SageRun value of 6.

	.OUTPUTS
		The -Verbose argument passed to the script and logging.

	.NOTES

		Idea based on the the following scripts.
		https://gallery.technet.microsoft.com/scriptcenter/Disk-Cleanup-Using-98ad13bc
		https://github.com/pauby
		https://github.com/pauby/posh-diskclean

	.LINKS
		https://joshuaallenshaw.com/kiss/
		https://github.com/joshuaallenshaw/KISS-PSScripts

	.NOTES
		Requires a Minimum PowerShell Version 3.0.
		Adapted from https://gist.github.com/altrive/5329377, though most of it has been re-written over time.

	#>
	#Deletes Files so we need WhatIf
	[CmdletBinding(SupportsShouldProcess)]

	Param (
		[parameter(Mandatory=$true)]
		[ValidateSet('User','System')]
		[string]$Mode,
		[switch]$TheWorks,

		# System only Parameters
		[switch]$EmptyWinLogs,
		[switch]$ResetCompStore,
		[switch]$EmptyWinTemp,
		[switch]$RemoveWinOld,
		[switch]$RemoveChkDskFragments,
		[switch]$EmptyWinUpdDownload,
		[switch]$RemoveJunkFolders,

		# Parameters for both User and System
		[switch]$EmptyRecycleBin,
		[switch]$EmptyUserTemp,
		[switch]$EmptyTempInternet,
		[switch]$EmptyRDPCache,
		[switch]$EmptyUserDownload,

		# Extras
		[ValidateNotNullOrEmpty()]
		[array]$OtherFilesFolders,
		[int]$DiskCleanTool,
		[int]$RetentionTime = 7,
		[switch]$ReportStats,
		[string]$LogPath = $null
	)
	Begin
	{
		# Start Logging.
		if($LogPath)
		{
			try
			{
				$logFolder = Split-Path $LogPath -Parent
				if (!(Test-Path $logFolder))
				{
					New-Item -ItemType Directory -Force -Path $logFolder
				}
				# Lets attempt a stop, just in case you hit Ctrl+C as soon as you started the first time around.
				try
				{
					Stop-Transcript | Out-Null
				}
				catch{}
				finally
				{
					$oVP = $VerbosePreference
					$VerbosePreference = 'continue'
					$oWP = $WarningPreference
					$WarningPreference = 'continue'
					$transcript = Start-Transcript -Path $LogPath -Force -Append
				}
			}
			catch
			{
				Write-Verbose $_.Exception.Message
				$LogPath = $null
			}
		}
		# Set Retention Values
		$retentionDate = (Get-Date).AddDays(-$RetentionTime)
		# Make sure we have admin permissions
		if ($Mode -eq 'System' -and !([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")))
		{
			$Mode = 'User'
			Write-Verbose "Cannot run in System mode without administrative permissions."
		}
		Write-Verbose "Executing in $($Mode) Mode."
		Write-Verbose "Cleaning files/folders older than $retentionDate."
		# Gather Stats
		if ($ReportStats)
		{
			$reportData = Get-WmiObject Win32_Volume | Where-Object {
				$_.Name -match '\D:\\' } | Select-Object Name, FreeSpace, NewFreeSpace
		}
		# Helper function to grant access to system folders
		Function Remove-SystemFiles
		{
			Param(
			# PassThru Path
			[Parameter(ValueFromPipeLineByPropertyName)]
			[Alias('FullName')]
			[string]$Paths
			)
			Process
			{
				Foreach($path in $Paths)
				{
					# Safety catch for am empty path
					If($path -eq $null){continue}
					# Need to cap this off to prevent a perpetual loop, 5 should be enough for most circumstances.
					$maxRetry = 5
					$isDirectory = ((Get-Item $path) -is [System.IO.DirectoryInfo])
					$takeOwnCmd = "TAKEOWN.exe /F $path /A"
					if($isDirectory)
					{
						 $takeOwnCmd += " /R /D Y"
					}

					Do
					{
						$getPermissions = $takeOwnResult = $icaclsResult = $attribResult = $removeResult = $null
						# Force Owner
						Write-Verbose "Executing $takeOwnCmd"
						$takeOwnResult = Invoke-Expression $takeOwnCmd
						$takeOwnResult | Write-Verbose
						# Grant Permissions
						Write-Verbose "Executing icacls.exe `"$path`" /grant Administrators:F /inheritance:e /T /Q /C /L"
						$icaclsResult = icacls.exe "$path" /grant Administrators:F /inheritance:e /T /Q /C /L
						$takeOwnResult | Write-Verbose
						# Remove System Properties
						Write-Verbose 'Resetting Attributes.'
						Write-Verbose "Executing ATTRIB.exe -a `"$path`" /S /D /L"
						$attribResult = ATTRIB.exe -a "$path" /S /D /L
						# The pure powershell version works, but it's slow.
						# $attribResult =  Get-ChildItem $oldWinPath -Recurse | ForEach-Object {
						#	($_ | Get-Item).Attributes = 'Normal'
						#}
						# Try to remove the folder
						Write-Verbose "Removing $path."
						try
						{
							Remove-Item -Path $path -Force -Recurse -Verbose:$VerbosePreference -ea SilentlyContinue -Confirm:$false | Write-Verbose
						}
						catch
						{
							$removeResult = $_.Exception.Message
						}

						$getPermissions = ( $takeOwnResult + $icaclsResult + $attribResult + $removeResult) | Select-String -Pattern 'Access is denied'
					}
					While($getPermissions -ne $null -or (--$maxRetry -le 0))
					return $FilePath
				}
			}
		}
	}

	Process
	{
		# Remove Windows dump files
		if (($EmptyWinDumpFiles -or $TheWorks) -and $Mode -eq 'System')
		{
			Write-Verbose "Removing Windows memory dump files."
			$winDmpPaths = ((Join-Path -Path $env:SystemDrive -ChildPath "*.dmp"), (Join-Path -Path $env:SystemRoot -ChildPath "*.dmp"), (Join-Path -Path $env:SystemRoot -ChildPath "LiveKernelReports\*.dmp"))
			Get-ChildItem $winDmpPaths -Force -ea SilentlyContinue | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File') -and ($_.FullName -ne $null)
			} | Remove-SystemFiles
		}

		# Remove CHKDSK Disk Fragment Files
		if (($RemoveChkDskFragments -or $TheWorks) -and $Mode -eq 'System')
		{
			Write-Verbose "Removing CHKDSK disk fragment files."
			$chkDskFragmentPath = ((Join-Path -Path $env:SystemDrive -ChildPath "File*.chk"),(Join-Path -Path $env:SystemDrive -ChildPath "Found.*\*.chk"))
			Get-ChildItem $chkDskFragmentPath -Force -ea SilentlyContinue | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File') -and ($_.FullName -ne $null)
			} | Remove-SystemFiles
		}
		elseif (($RemoveChkDskFragments -or $TheWorks) -and $Mode -eq 'User')
		{
			Write-Verbose "-RemoveChkDskFragments requires 'System' Mode."
		}

		# Remove some of the large windows logs
		if (($EmptyWinLogs -or $TheWorks) -and $Mode -eq 'System')
		{
			# Clear the old (large) CBS logs
			Write-Verbose "Removing large Windows logs."
			$winLogPaths = ((Join-Path -Path $env:SystemRoot -ChildPath "Logs\CBS\*persist*"), (Join-Path -Path $env:SystemRoot -ChildPath "Logs\DISM\*"))
			Get-ChildItem $winLogPaths -Force -ea SilentlyContinue | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File') -and ($_.FullName -ne $null)
			} | Remove-SystemFiles
		}
		elseif (($EmptyWinLogs -or $TheWorks) -and $Mode -eq 'User')
		{
			Write-Verbose "-EmptyWinLogs requires 'System' Mode."
		}

		# Reset Windows update base to current version and purge unecessary setup files. Windows 10 only.
		if (($ResetCompStore -or $TheWorks) -and $Mode -eq 'System')
		{
			if (([System.Environment]::OSVersion.Version).Major -gt 6) {
				Write-Verbose "Running DISM to clean Component Store."
				if ($PSCmdlet.ShouldProcess('Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase','Execute'))
				{
					$dismLog = Join-Path -Path $env:TEMP -ChildPath 'DISM.Log'
					$dismJob = Start-Job -ScriptBlock {param($dismLog) Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-File $dismLog } -ArgumentList $dismLog
					# This step can take a while so we'll employ a progress update in Verbose Mode.
					Do
					{
						Start-Sleep -Seconds 10
						Get-Content -Path $dismLog -Tail 3 | Select-String -Pattern '%' | Select-Object -Last 1
					}
					While ((Get-Job $dismJob.Id).State -eq 'Running' )
					if ((Get-Job $dismJob.Id).State -eq 'Completed')
					{
						Remove-Job $dismJob -ErrorAction SilentlyContinue
						$dismResult = Get-Content -Path $dismLog
						$dismError = $dismResult | Select-String -Pattern 'Error'
						if ($dismError -eq $null)
						{
							Write-Verbose "DISM job completed successfully."
						}
						else
						{
							Write-Verbose "DISM job completed with the following error:"
							Write-Verbose $dismError
						}
					}
					Remove-Job $dismJob -ErrorAction SilentlyContinue
					Remove-Item $dismLog -ErrorAction SilentlyContinue -Confirm:$false
				}
			}
		}
		elseif (($ResetCompStore -or $TheWorks) -and $Mode -eq 'User')
		{
			Write-Verbose "-ResetCompStore requires 'System' Mode."
		}

		# Remove Old versions of Windows files, from Major Updates
		if (($RemoveWinOld -or $TheWorks) -and $Mode -eq 'System')
		{
			$oldWinPath = Join-Path -Path $env:SystemDrive -ChildPath "Windows.old"
			if(Test-Path $oldWinPath)
			{
				if($PSCmdlet.ShouldProcess("$oldWinPath", 'Remove Folder'))
				{
					Remove-SystemFiles $oldWinPath
				}
			}
			else
			{
				Write-Verbose "$oldWinPath not present."
			}
		}
		elseif (($RemoveWinOld -or $TheWorks) -and $Mode -eq 'User')
		{
			Write-Verbose "-RemoveWinOld requires 'System' Mode."
		}

		# Empty the RecycleBin
		if ($EmptyRecycleBin -or $TheWorks)
		{
			Switch ($Mode)
			{
				'System'
				{
					Write-Verbose "Emptying Recycle Bin for all users."
					Get-PSDrive -PSProvider FileSystem | ForEach-Object {
						$recyclerPath = Join-Path $_.Root -ChildPath '$Recycle.Bin\'
						if (Test-Path $recyclerPath)
						{
							Write-Verbose "Emptying Recycle for $($_.Root)"
							Get-ChildItem (Join-Path -Path $RecyclerPath -ChildPath '*\$I*') -Force -Recurse | Where-Object {
								($_.CreationTime -lt $retentionDate)
							} | ForEach-Object {
								if($PSCmdlet.ShouldProcess("$($_.FullName.Replace('$I','$R'))", 'Remove File'))
								{
									Remove-Item $($_.FullName.Replace('$I','$R')) -Force -Recurse -Confirm:$false -Verbose:$VerbosePreference -ea SilentlyContinue | Write-Verbose
								}
								if($PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File'))
								{
									$_ | Remove-Item -Force -Recurse -Confirm:$false -Verbose:$VerbosePreference -ea SilentlyContinue | Write-Verbose
								}
							}
						}
						else
						{
							Write-Verbose "$($_.Root) does not contain a Recycle Bin (normal for removable media)."
						}
					}
				}

				'User'
				{
					# See http://baldwin-ps.blogspot.be/2013/07/empty-recycle-bin-with-retention-time.html for info on this code.
					# This method is less effective at clearing space but it works for the non admin.
					$objShell = New-Object -ComObject Shell.Application
					$global:Recycler = $objShell.Namespace(0xA)
					foreach($item in $Recycler.Items())
					{
						$deletedDate = $Recycler.GetDetailsOf($item,2) -replace "\u200f|\u200e",""	#Invisible Unicode Characters
						$deletedDate_datetime = get-date $deletedDate
						[Int]$deletedDays = (New-TimeSpan -Start $deletedDate_datetime -End $(Get-Date)).Days | Write-Verbose
						If($deletedDays -ge $RetentionTime)
						{
							if($PSCmdlet.ShouldProcess("$($item.Path)", 'Remove File'))
							{
								Remove-Item -Path $item.Path -Confirm:$false -Force -Recurse -Verbose:$VerbosePreference -ea SilentlyContinue | Write-Verbose
							}
						}
					}
					[System.Runtime.Interopservices.Marshal]::ReleaseComObject($objShell)  | Write-Verbose
				}

				default
				{
					Write-Verbose "Mode not handled for EmptyRecycleBin."
				}
			}
		}

		if ($EmptyUserTemp -or $TheWorks)
		{
			# Set the Path string
			Switch ($Mode)
			{
				'System'
				{
					Write-Verbose "Emptying all user's temp folders."
					$userTempPath = $env:TEMP
				}
				'User'
				{
					Write-Verbose "Emptying current user's temp folder."
					$userTempPath = Join-Path -Path "$(Split-Path -Parent $env:USERPROFILE)\*" -ChildPath "AppData\Local\Temp\*"
				}
				default
				{
					Write-Verbose "Mode not handled for EmptyUserTemp."
				}
			}
			# Empty user temp directory(s)

			# Flush the files first
			Get-ChildItem $userTempPath -Force -Recurse -File -ea SilentlyContinue | Where-Object {
				($_.PSIsContainer = $False -and $_.CreationTime -lt $retentionDate)
			} | Where-Object  {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File')
			} | Remove-Item -Force -Verbose:$VerbosePreference -Confirm:$false -ea SilentlyContinue

			# Remove only folders that are both old and empty. Doesn't truly recurse, but empty folders do not consume much space.
			Get-ChildItem $userTempPath -Force -Recurse -Directory -ea SilentlyContinue | Where-Object {
				($_.PSIsContainer = $True -and $_.GetFiles().Count -eq 0 -and $_.GetDirectories().count -eq 0)
			} | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File')
			} | Remove-Item -Force -Verbose:$VerbosePreference -ea SilentlyContinue -Confirm:$false
		}

		if ($EmptyTempInternet -or $TheWorks)
		{
			# Set the Path string array
			[string[]]$tempInternetPath = @()
			Switch ($Mode)
			{
				'System'
				{
					Write-Verbose "Emptying all user's temp internet files."
					$tempInternetPath = Join-Path -Path $env:USERPROFILE -ChildPath "AppData\Local\Microsoft\Windows\INetCache\IE\*"
					$tempInternetPath += Join-Path -Path $env:USERPROFILE -ChildPath "AppData\Local\Google\Chrome\User Data\Default\Cache\*"
					$tempInternetPath += Join-Path -Path $env:USERPROFILE -ChildPath "AppData\Local\Mozilla\Firefox\profiles\*.default\Cache\*"
				}
				'User'
				{
					Write-Verbose "Emptying current user's temp internet files."
					$tempInternetPath = Join-Path -Path "$(Split-Path -Parent $env:USERPROFILE)\*" -ChildPath "AppData\Local\Microsoft\Windows\INetCache\IE\*"
					$tempInternetPath += Join-Path -Path "$(Split-Path -Parent $env:USERPROFILE)\*" -ChildPath "AppData\Local\Google\Chrome\User Data\Default\Cache\*"
					$tempInternetPath += Join-Path -Path "$(Split-Path -Parent $env:USERPROFILE)\*" -ChildPath "AppData\Local\Mozilla\Firefox\profiles\*.default\Cache\*"
				}
				default
				{
					Write-Verbose "Mode not handled for EmptyTempInternet."
				}
			}

			# Empty users temp internet directory(s)
			$tempInternetPath | Get-ChildItem -Force -ea SilentlyContinue | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File')
			} | Remove-Item -Recurse -Force -Verbose:$VerbosePreference -Confirm:$false -ea SilentlyContinue
		}

		if ($EmptyRDPCache -or $TheWorks)
		{
			# Set the Path string
			Switch ($Mode)
			{
				'System'
				{
					Write-Verbose "Emptying all user's RDP Cache Files."
					$cachePath = Join-Path -Path $env:USERPROFILE -ChildPath "AppData\Local\Microsoft\Terminal Server Client\Cache\*.bin"
				}
				'User'
				{
					Write-Verbose "Emptying current user's RDP Cache Files."
					$cachePath = Join-Path -Path "$(Split-Path -Parent $env:USERPROFILE)\*" -ChildPath "AppData\Local\Microsoft\Terminal Server Client\Cache\*.bin"
				}
				default
				{
					Write-Verbose "Mode not handled for EmptyRDPCache."
				}
			}
			# Empty RDP cache files
			# There is no need to honor the retention time here, but we don't want to deleate an active file.
			$cacheRetention = (Get-Date).AddDays(-1)
			$cachePath | Get-ChildItem -Force -ea SilentlyContinue | Where-Object {
				$_.LastWriteTime -lt $cacheRetention
			} | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File')
			} | Remove-Item -Force -Verbose:$VerbosePreference -Confirm:$false -ea SilentlyContinue
		}

		if ($EmptyUserDownload -or $TheWorks)
		{
			# Set the Path string
			Switch ($Mode)
			{
				'System'
				{
					Write-Verbose "Emptying all user's download folder."
					$downloadPath = Join-Path -Path $env:USERPROFILE -ChildPath "Downloads\*"
				}
				'User'
				{
					Write-Verbose "Emptying current user's download folder."
					$downloadPath = Join-Path -Path "$(Split-Path -Parent $env:USERPROFILE)\*" -ChildPath "Downloads\*"
				}
				default
				{
					Write-Verbose "Mode not handled for EmptyUserDownload."
				}
			}

			# Empty user's download directory(s)
			$downloadPath | Get-ChildItem -Force -ea SilentlyContinue | Where-Object {
				$_.LastWriteTime -lt $retentionDate
			} | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File/Folder')
			} | Remove-Item -Recurse -Force -Verbose:$VerbosePreference -Confirm:$false -ea SilentlyContinue
		}

		if (($EmptyWinUpdDownload -or $TheWorks) -and $Mode -eq 'System')
		{
			if($PSCmdlet.ShouldProcess('Windows Update Service', 'Stopping'))
			{
				#Stop the windows update service so the files are not open
				Stop-Service 'wuauserv' -Force -Verbose:$VerbosePreference -ea SilentlyContinue
				$ExitTimer = 15
				Do
				{
					sleep 5;
					$ExitTimer -= 1
				} While ((Get-Service 'wuauserv').Status -eq 'Running' -and $ExitTimer > 0)
			}
				#Remove the Windows update downloaded files.
			if ((Get-Service 'wuauserv').Status -ne 'Running')
			{
				Write-Verbose "Emptying Windows Update download folder."
				Get-ChildItem (Join-Path $env:SystemRoot -ChildPath 'SoftwareDistribution\Download') | Where-Object {
					$_.LastWriteTime -lt $retentionDate
				} | Where-Object {
					$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File/Folder') -and ($_.FullName -ne $null)
				} | Remove-SystemFiles
			}
			else
			{
				Write-Verbose "Windows Update Services failed to Stop."
			}
		}
		elseif (($EmptyWinUpdDownload -or $TheWorks) -and $Mode -eq 'User')
		{
			Write-Verbose "-EmptyWinUpdDownload requires 'System' Mode."
		}

		if (($EmptyWinTemp -or $TheWorks) -and $Mode -eq 'System')
		{
			# Empty Windows Temp Directory
			Write-Verbose "Emptying Windows TEMP folder."
			Get-ChildItem (Join-Path $env:SystemRoot "TEMP") -Force -ea SilentlyContinue | Where-Object {
				$_.LastWriteTime -lt $retentionDate
			} | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File/Folder') -and ($_.FullName -ne $null)
			} | Remove-SystemFiles
		}
		elseif (($EmptyWinTemp -or $TheWorks) -and $Mode -eq 'User')
		{
			Write-Verbose "-EmptyWinTemp requires 'System' Mode."
		}

		if (($RemoveJunkFolders) -and $Mode -eq 'System')
		{
			# Remove junk folders from windows directory.
			Write-Verbose "Removing Junk Folders from the Windows directory."
			Get-ChildItem $env:SystemRoot -Force -Directory -ea SilentlyContinue | Where-Object {
				($_.Name -match "^\{\w{8}-\w{4}-\w{4}-\w{4}-\w{12}\}$") -and ($_.Name -notmatch "win|prog|res|rec|driv") -and ($_.LastWriteTime -lt $retentionDate)
			} | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File/Folder') -and ($_.FullName -ne $null)
			} | Remove-SystemFiles

			# Remove junk folders from root directory.
			Write-Verbose "Removing Junk Folders from the Root directory."
			Get-ChildItem $env:SystemDrive -Force -Directory -ea SilentlyContinue | Where-Object {
				($_.Name -notmatch "win|prog|res|rec|driv") -and ($_.Name -match "^[a-z0-9]{15,}$") -and ((("$($_.Name)" -replace '[0-9]','').Length *.9 ) -lt ("$($_.Name)" -replace '[^0-9]','').Length) -and ($_.LastWriteTime -lt $retentionDate)
			} | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File/Folder') -and ($_.FullName -ne $null)
			} | Remove-SystemFiles
		}
		elseif (($RemoveJunkFolders -or $TheWorks) -and $Mode -eq 'User')
		{
			Write-Verbose "-RemoveJunkFolders requires 'System' Mode."
		}

		if ($OtherFilesFolders)
		{
			Write-Verbose "Removing $($OtherFilesFolders)."
			$OtherFilesFolders | Get-ChildItem -force -ea SilentlyContinue | Where-Object {
				$PSCmdlet.ShouldProcess("$($_.FullName)", 'Remove File')
			} | Remove-Item -Verbose:$VerbosePreference -Recurse -Force -Confirm:$false -ea SilentlyContinue }

		if ($DiskCleanTool -and (Get-Command cleanmgr -EA SilentlyContinue))
		{
			# Running Disk Clean up Tool
			Write-Verbose "Running Windows disk Clean up Tool with SageSet $DiskCleanTool ..."
			if ($PSCmdLet.ShouldProcess('cleanmgr /sagerun:$DiskCleanTool','Execute'))
			{
				cleanmgr /sagerun:$DiskCleanTool
			}
		}
	}
	End
	{
		#Reports Stats
		if($ReportStats)
		{
			# Collect the new data
			Get-WmiObject Win32_Volume | Where-Object {
				$_.Name -match '\D:\\' } | Select-Object Name, FreeSpace | ForEach-Object {
					$volume = $_.Name
					$reportDataRow = $reportData | Where-Object {$_.Name -eq $volume}
					$reportDataRow.NewFreeSpace = $_.FreeSpace
			}
			# Output results
			$reportData | ForEach-Object {
				$freedValue = ($_.NewFreeSpace - $_.FreeSpace)/1MB
				Write-Output "$freedValue MB freed on $($_.Name)."
			}
		}
		# Stop Logging if it was started.
		if($transcript)
		{
			try
			{
				if ($oVP -ne $null -or $oWP -ne $null)
				{
					$VerbosePreference = $oVP
					$WarningPreference = $oWP
				}
				Stop-Transcript
			}
			catch
			{
				Write-Verbose $_.Exception.Message
			}
		}
	}
}
Function Invoke-DiskHog {

    <#
     .SYNOPSIS
    Report on Disk Hogs
    .DESCRIPTION
    Returns a list of the largest directories in use on the local machine
    .NOTES
    Copyright Keith Garner, All rights reserved.
    Really Updated for Windows 7 and Optimized for !!!SPEED!!!
    .PARAMETER Path
    Start of the search, usually c:\
    .PARAMETER IncludeManifest
    Include basic info about the memory, OS, and Disk in the manifest
    .PARAMETER OutFile
    CLIXML file used to store results
    Location of a custom rules *.csv file, otherwise use the default table
    .LINK
    http://keithga.wordpress.com
    #>

[cmdletbinding()]
param(
    $path = 'c:\',
    [switch] $IncludeManifest,
    $OutFile = $DiskHogLog
)

###########################################################

$WatchList = @( 
    @{ Folder = 'c:\'; SizeMB = '0' }
    @{ Folder = 'c:\*'; SizeMB = '500' }
    @{ Folder = 'C:\$Recycle.Bin'; SizeMB = '100' }
    @{ Folder = 'c:\Program Files'; SizeMB = '0' }
    @{ Folder = 'C:\Program Files\*'; SizeMB = '1000' }
    @{ Folder = 'C:\Program Files (x86)'; SizeMB = '0' }
    @{ Folder = 'C:\Program Files (x86)\Adobe\*'; SizeMB = '1000' }
    @{ Folder = 'C:\Program Files (x86)\*'; SizeMB = '1000' }
    @{ Folder = 'C:\ProgramData\*'; SizeMB = '1000' }
    @{ Folder = 'C:\ProgramData'; SizeMB = '0' }
    @{ Folder = 'C:\Windows'; SizeMB = '0' }
    @{ Folder = 'C:\Windows\*'; SizeMB = '1000' }
    @{ Folder = 'c:\users'; SizeMB = '0' }
    @{ Folder = 'C:\Users\*'; SizeMB = '100' }
    @{ Folder = 'C:\Users\*\*'; SizeMB = '500' }
    @{ Folder = 'C:\Users\*\AppData\Local\Microsoft\*'; SizeMB = '1000' }
    @{ Folder = 'C:\Users\*\AppData\Local\*'; SizeMB = '400' }
)

###########################################################

Add-Type -TypeDefinition @"

    public class EnumFolder
    {


        public static System.Collections.Generic.Dictionary<string, long> ListDir(string Path, System.Collections.Generic.Dictionary<string, long> ControlList)
        {
            System.Collections.Generic.Dictionary<string, long> Results = new System.Collections.Generic.Dictionary<string, long>();

            System.IO.DirectoryInfo Root = new System.IO.DirectoryInfo(Path);
            ListDirRecursive(Root, Results, ControlList);
            return Results;
        }

        private static long ListDirRecursive
        (
            System.IO.DirectoryInfo Path,
            System.Collections.Generic.Dictionary<string, long> Results,
            System.Collections.Generic.Dictionary<string, long> ControlList
        )
        {
            try
            {
                long Total = 0;
                foreach (System.IO.DirectoryInfo Directory in Path.GetDirectories())
                    if ((Directory.Attributes & System.IO.FileAttributes.ReparsePoint) == 0)
                        Total += ListDirRecursive(Directory, Results, ControlList);

                foreach (System.IO.FileInfo file in Path.GetFiles())
                {
                    if ((file.Attributes & System.IO.FileAttributes.ReparsePoint) == 0)
                    {
                        if (ControlList.ContainsKey(file.FullName))
                        {
                            if ((ControlList[file.FullName] * 1024 * 1024) < file.Length)
                            {
                                Results.Add(file.FullName, file.Length);
                            }
                            else
                            {
                                Total += file.Length;
                            }
                        }
                        else
                        {
                            Total += file.Length;
                        }
                    }
                }

                if (ControlList.ContainsKey(Path.FullName))
                {
                    if ((ControlList[Path.FullName] * 1024 * 1024) < Total)
                    {
                        Results.Add(Path.FullName, Total);
                        Total = 0;
                    }
                }
                return Total;
            }
            catch
            {
                return 0;
            }
        }
    }
"@

###########################################################

$start = [datetime]::Now
$ControlList = new-object -TypeName 'System.Collections.Generic.Dictionary[String,int64]'

foreach ( $Item in $WatchList ) { 
    if ( $item.Folder.EndsWith('*') ) {
        get-childitem $Item.Folder.TrimEnd('*') -force -ErrorAction SilentlyContinue |
            ForEach-Object { 
                $_.FullName.Substring(0,1).ToLower() + $_.FullName.Substring(1)
            } | 
            Where-Object { -not $ControlList.ContainsKey( $_  ) } |
            foreach-object { $ControlList.Add($_,0 + $Item.SizeMB) }
    }
    else {
        get-item $Item.Folder -force -ErrorAction SilentlyContinue | 
            ForEach-Object { 
                $_.FullName.Substring(0,1).ToLower() + $_.FullName.Substring(1)
            } | 
            Where-Object { -not $ControlList.ContainsKey( $_  ) } |
            foreach-object { $ControlList.Add($_,0 + $Item.SizeMB) }
    }

} 

$ControlList.Keys | write-verbose

###################

$Global:Results = [EnumFolder]::ListDir($Path.ToLower(), $ControlList )

$Results | write-output

([datetime]::now - $Start).TotalSeconds | Write-verbose

###################

if ( $OutFile ) {
    new-item -ItemType Directory -Path ( split-path $OutFile ) -ErrorAction SilentlyContinue | Out-Null
    if ( $IncludeManifest ) {
        @{ 
            OS   = GWMI Win32_OPeratingSystem | Select OSarchitecture,OSLanguage,InstallDate,Version
            Mem  = GWMI Win32_PhysicalMemory | Select Capacity
            Vol  = GWMI Win32_LogicalDisk -Filter "DeviceID='$($path.Substring(0,1))`:'" | Select Size,FreeSpace,VolumeName
            Data = $Results 
        } | Export-Clixml -Path $OutFile
        GWMI Win32_OPeratingSystem | Select OSarchitecture,OSLanguage,InstallDate,Version | Out-File -FilePath "$($OutFile).log"
        GWMI Win32_PhysicalMemory | Select Capacity | Out-File -FilePath "$($OutFile).log" -Append
        GWMI Win32_LogicalDisk -Filter "DeviceID='$($path.Substring(0,1))`:'" | Select Size,FreeSpace,VolumeName | Out-File -FilePath "$($OutFile).log" -Append
        $Results | Out-File -FilePath "$($OutFile).log" -Append

    }
    else {
        $Results | Export-Clixml -Path $OutFile
        $Results | Out-File -FilePath "$($OutFile).log"
    }
}
}
Function Get-FreeSpace {$DriveInfo = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'"; $Global:FreeSpace = $DriveInfo.FreeSpace; return $FreeSpace}



#Remediation Area

CMTraceLog -Message "-----------------------------------------------------------------" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Starting Disk Management Remediation Script" -Component "Disk Management" -LogFile $ScriptLogPath

if (!(Test-Path -Path (split-path -Path $ScriptLogPath))){$NULL = New-Item -Path (split-path -Path $ScriptLogPath) -ItemType Directory -Force}

#Directories I just don't want on my machines  If they exist, I want to delete them.  This is a detection script, so if they exist, it will return a 1 and the remediation script will run.  If they don't exist, it will return a 0 and the remediation script won't run.
$Directories = @("C:\Drivers","C:\OSDCloud")
foreach ($Directory in $Directories){
    if (Test-Path $Directory){
        Remove-Item -Path $Directory -Recurse -Force -ErrorAction SilentlyContinue
		CMTraceLog -Message "Removed $Directory" -Component "Disk Management" -LogFile $ScriptLogPath
    }
}

if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "  Current Freespace = $([MATH]::Round(((Get-Freespace)/1GB),2))" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Running Action: Invoke-CleanDisk -Mode System -EmptyWinLogs -RemoveWinOld -EmptyWinTemp -RemoveChkDskFragments -ReportStats -LogPath $CleanDiskLogPath" -Component "Disk Management" -LogFile $ScriptLogPath
Invoke-CleanDisk -Mode System -EmptyWinLogs -RemoveWinOld -EmptyWinTemp -RemoveChkDskFragments -ReportStats -LogPath $CleanDiskLogPath
}

if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "  Current Freespace = $([MATH]::Round(((Get-Freespace)/1GB),2))" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Running Action: Invoke-CleanDisk -Mode System -EmptyWinUpdDownload -ReportStats -LogPath $CleanDiskLogPath " -Component "Disk Management" -LogFile $ScriptLogPath
Invoke-CleanDisk -Mode System -EmptyWinUpdDownload -ReportStats -LogPath $CleanDiskLogPath 
}

if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "  Current Freespace = $([MATH]::Round(((Get-Freespace)/1GB),2))" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Running Action: Invoke-CleanDisk -Mode System -ResetCompStore -ReportStats -LogPath $CleanDiskLogPath " -Component "Disk Management" -LogFile $ScriptLogPath
Invoke-CleanDisk -Mode System -ResetCompStore -ReportStats -LogPath $CleanDiskLogPath 
}

if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "  Current Freespace = $([MATH]::Round(((Get-Freespace)/1GB),2))" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Running Action: Invoke-CleanDisk -Mode System -RemoveJunkFolders -ReportStats -LogPath $CleanDiskLogPath" -Component "Disk Management" -LogFile $ScriptLogPath
Invoke-CleanDisk -Mode System -RemoveJunkFolders -ReportStats -LogPath $CleanDiskLogPath 
}

if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "  Current Freespace = $([MATH]::Round(((Get-Freespace)/1GB),2))" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Running Action: Invoke-CleanDisk -Mode System -EmptyRecycleBin -ReportStats -LogPath $CleanDiskLogPath" -Component "Disk Management" -LogFile $ScriptLogPath
Invoke-CleanDisk -Mode System -EmptyRecycleBin -ReportStats -LogPath $CleanDiskLogPath 
}

if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "  Current Freespace = $([MATH]::Round(((Get-Freespace)/1GB),2))" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Running Action: Invoke-CleanDisk -Mode System -DiskCleanTool -ReportStats -LogPath $CleanDiskLogPath " -Component "Disk Management" -LogFile $ScriptLogPath
Invoke-CleanDisk -Mode System -DiskCleanTool -ReportStats -LogPath $CleanDiskLogPath 
}

if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "  Current Freespace = $([MATH]::Round(((Get-Freespace)/1GB),2))" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Running Action: Invoke-CleanDisk -Mode System -EmptyUserTemp -EmptyTempInternet -EmptyRDPCache -ReportStats -LogPath $CleanDiskLogPath " -Component "Disk Management" -LogFile $ScriptLogPath
Invoke-CleanDisk -Mode System -EmptyUserTemp -EmptyTempInternet -EmptyRDPCache -ReportStats -LogPath $CleanDiskLogPath 
}

if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "  Current Freespace = $([MATH]::Round(((Get-Freespace)/1GB),2))" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Running Action: Invoke-CleanDisk -Mode System -EmptyUserTemp -EmptyTempInternet -EmptyRDPCache -ReportStats -LogPath $CleanDiskLogPath " -Component "Disk Management" -LogFile $ScriptLogPath
Invoke-CleanDisk -Mode System -EmptyUserTemp -EmptyTempInternet -EmptyRDPCache -ReportStats -LogPath $CleanDiskLogPath 
}


if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "  Current Freespace = $([MATH]::Round(((Get-Freespace)/1GB),2))" -Component "Disk Management" -LogFile $ScriptLogPath
CMTraceLog -Message "Running Action: Invoke-DiskHog -IncludeManifest -OutFile $DiskHogLog " -Component "Disk Management" -LogFile $ScriptLogPath
Invoke-DiskHog -IncludeManifest -OutFile $DiskHogLog
CMTraceLog -Message "See DiskHog logs for more information: $DiskHogLog" -Component "Disk Management" -LogFile $ScriptLogPath
}


#Summary - Submit Jira Task
<#
if ((Get-FreeSpace) -lt $MinFreeSpace){
CMTraceLog -Message "Connecting to Jira to create task" -Component "Disk Management" -LogFile $ScriptLogPath


    #Setup PowerShell
    if (!((Get-PackageProvider -ListAvailable).Name -contains "NuGet")){
        Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -Scope AllUsers
        }

    if (!((Get-Module -ListAvailable).Name -contains "JiraPS")){
        Install-Module -Name JiraPS -AllowClobber -SkipPublisherCheck -Force -Confirm:$false
        }
    Set-JiraConfigServer -Server $JiraConfigServer
    New-JiraSession -Credential $Credential
    #Get-JiraProject -Project $JiraProjectID #Test to confirm Project is there.


    $Description = "Machine $env:COMPUTERNAME
    Current Free Disk Space: $([MATH]::Round(((Get-Freespace)/1GB),2))
    Required: $($MinFreeSpace / 1GB)
    Machine has attempted Proactive Remediation and still has low disk space, see attached logs for additional details
    "
    $Summary = "Low Disk Space: Machine $env:COMPUTERNAME"
    $JiraIssue = New-JiraIssue -Project $JiraProjectID -IssueType "Task" -Summary $Summary -Description $Description
    $Comment = $Results | Out-String
    Add-JiraIssueComment -Comment $Comment -Issue $JiraIssue.Key
    $Logs = Get-ChildItem -Path (Split-Path -Path $ScriptLogPath)
    foreach ($log in $logs)
        {
        Add-JiraIssueAttachment -Issue $JiraIssue.Key -FilePath $log.FullName
        }
    if ($JiraIssue){CMTraceLog -Message "Created Jira Task $($JiraIssue.Key)" -Component "Disk Management" -LogFile $ScriptLogPath}
    else {CMTraceLog -Message "Failed to create Jira Task" -Component "Disk Management" -LogFile $ScriptLogPath}
    }
#>	
if ((Get-FreeSpace) -lt $MinFreeSpace){
    CMTraceLog -Message "Completed Disk Cleanup Remediation Script and machine Non-Compliant" -Type 2 -Component "Disk Management" -LogFile $ScriptLogPath
    exit 1
    }
else {
    CMTraceLog -Message "Completed Disk Cleanup Remediation Script and machine Compliant" -Component "Disk Management" -LogFile $ScriptLogPath
    }
