<# @gwblok - GARYTOWN.COM
2020.02.03 - Initial Release

This script takes the TS's you specify and creates copies of it and any task sequences that it calls (Run Task Sequence Step)
It then builds folders structures for it to maintain versioning.
The first run, you might see some errors as it might look for the previous export, and you won't have one yet.
You'll need to update Server Paths for where you will be keeping the logs and the exports.
You'll need to update the SFTP info (at the end) if you plan to upload to SFTP server.
It also exports the Packages you set as well, so you'd need to update that list.
Look over the script, I've got comments along the way that help explain what is going on.
I don't claim this is pretty, but it works for me.

#>


# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

#Get SiteCode
$SiteCode = Get-PSDrive -PSProvider CMSITE
$ProviderMachineName = (Get-PSDrive -PSProvider CMSITE).Root


# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams
$Comment = "Exported from GARYTOWN.COM"
$TimeStamp = Get-Date -Format yyyy.MM.dd
$ExportFolderParent ="\\src\src$\OSD\TSExports"
$ExportLocation = "$($ExportFolderParent)\$($TimeStamp)"
$LastExportLocation = "$($ExportFolderParent)\LastExport" 
$Logfile = "$($ExportLocation)\WaaS_TS_Export.log"
$CompareExportLog = "$($ExportLocation)\WaaS_TS_CompareExportLog.log"
$ChangeLog = "$($ExportLocation)\WaaS_TS_ChangeLog.log"
$ChangeLogCombine = "$($ExportFolderParent)\WaaS_TS_ChangeLogCombine.log"
#Reset Vars
$TSObjectLastRun = $null
$ContentObjectLastRun = $null
$WaaSBaselineLastRun = $null
$FolderDate = get-date -Format "yyyyMMdd"
$FolderName = "WaaS_Export_$($FolderDate)"
$NewFolderPath = "PS2:\TaskSequence\$($FolderName)"


if (!(Test-path -Path $NewFolderPath))
    {
    New-Item -Name $FolderName -Path 'PS2:\TaskSequence'
    Write-Host "Created CM Folder $NewFolderPath" -ForegroundColor Green
    }


#region: CMTraceLog Function formats logging in CMTrace style
        function CMTraceLog {
         [CmdletBinding()]
    Param (
		    [Parameter(Mandatory=$false)]
		    $Message,
 
		    [Parameter(Mandatory=$false)]
		    $ErrorMessage,
 
		    [Parameter(Mandatory=$false)]
		    $Component = "WaaS Exporter",
 
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

#Set-Location -Path "$($SiteCode):"

        $TaskSequenceTable= @(
        @{ TSName = 'DebugMode'; Folder = "DebugModeTS"; TSPackageID = "PS200038"; Comment = "GARYTOWN.COM - Exported: $FolderDate - This Task Sequence is useful for Debugging"}
        @{ TSName = 'PreCache'; Folder = "WaaS_PreCacheTS"; TSPackageID = "PS200072"; Comment = "GARYTOWN.COM - Exported: $FolderDate - This is the PreCache / CompatScan TS"}
        @{ TSName = 'OSUninstall'; Folder = "WaaS_OSUninstall"; TSPackageID = "PS200084"; Comment = "GARYTOWN.COM - Exported: $FolderDate - This is the OSUninstall TS"}
        @{ TSName = 'Upgrade'; Folder = "WaaS_UpgradeTS"; TSPackageID = "PS200081"; Comment = "GARYTOWN.COM - Exported: $FolderDate - This is the Upgrade TS"}
        )

        $ContentPackageTable=@(
        @{ ContentName = 'OSD TS Scripts & Tools'; Folder = "TSScriptsTools"; PackageID = "PS20006A"; Comment = "GARYTOWN.COM - Main Package for Scripts & Tools Used in IPU"}
        @{ ContentName = 'WaaS_Scripts'; Folder = "WaaSScripts"; PackageID = "PS1000B2"; Comment = "GARYTOWN.COM - Package from Previous IPU, Basically just Branding Now"}
        @{ ContentName = 'Custom Splash Screen'; Folder = "SplashScreen"; PackageID = "PS20003E"; Comment = "GARYTOWN.COM - Fancy Splash Screen Replacement"}
        @{ ContentName = 'DebugMode'; Folder = "DebugMode"; PackageID = "PS200071"; Comment = "GARYTOWN.COM - Debug Tools"}
        @{ ContentName = 'LockScreen'; Folder = "LockScreen"; PackageID = "PS200070"; Comment = "GARYTOWN.COM - LockScreen Images"}
        )
Set-Location -Path "C:"
if (-Not(Test-Path -Path $ExportLocation)){New-Item -ItemType directory -Path $ExportLocation}
if (-Not(Test-Path -Path $LastExportLocation))
    {New-Item -ItemType directory -Path $LastExportLocation}
Else #Backup Last Run, because you know you need to.
    {Copy-Item -Path $LastExportLocation -Destination "$($LastExportLocation)$($TimeStamp)" -Recurse}
if (Test-Path -Path $LogFile){Remove-Item -Path $LogFile}
if (Test-Path -Path $CompareExportLog){Remove-Item -Path $CompareExportLog}

CMTraceLog -Message "----- Exporting WaaS Task Sequences FOR THE WIN ------" -Type 3 -LogFile $LogFile -Component "WaaS TS Export"
CMTraceLog -Message "---- Change Log Run from $TimeStamp ----" -Type 3 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
CMTraceLog -Message "---- Change Log Run from $TimeStamp ----" -Type 3 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"

$TSInfoDatabase = @()
$RunTSInfoDatabase = @()
$ExportedTSDatabase = @()

Set-Location -Path "$($SiteCode):"    
foreach ($TaskSequence in $TaskSequenceTable)
    {
    Write-Host "Gathering Sub Task Sequences and adding to Export Database for $($TaskSequence.TSName)" -ForegroundColor Green
    $CurrentWorkingTS = Get-CMTaskSequence -TaskSequencePackageId $TaskSequence.TSPackageID
    $RUnTSSteps = Get-CMTaskSequenceStepRunTaskSequence -InputObject $CurrentWorkingTS
    $RUnTSSteps = $RUnTSSteps | Select Name, TsPackageID -Unique
    $RunTSInfoDatabase += $RUnTSSteps
    Write-Host "Copying TS $($CurrentWorkingTS.Name)" -ForegroundColor Green
    $ExportTS = Copy-CMTaskSequence -InputObject $CurrentWorkingTS
    $ExportTSName = ($ExportTS.Name).Replace("-$($ExportTS.PackageID)","-$FolderDate")
    Start-Sleep -Seconds 1
    Set-CMTaskSequence -TaskSequenceId $ExportTS.PackageID -NewName $ExportTSName -Description $TaskSequence.Comment
    $ExportTSObject = New-Object PSObject -Property @{
        NewExportName    = $ExportTSName
        NewExportPackageId     = $ExportTS.PackageID
        NewExportComment = $TaskSequence.Comment
        Folder = $TaskSequence.Folder 
        OldTSPackageID = $TaskSequence.TSPackageID
        }
    $ExportedTSDatabase += $ExportTSObject
    Write-Host "New TS Created with name $ExportTSName" -ForegroundColor Green
    Move-CMObject -ObjectId $ExportTS.PackageID -FolderPath $NewFolderPath
    Write-Host ____________________________________ -ForegroundColor Gray
    }


    #Build Database of Sub TS Steps
    $RunTSInfoDatabase = $RunTSInfoDatabase | Select Name, TsPackageID -Unique
    foreach ($RunTS in $RunTSInfoDatabase)
        {
        #$CurrentTS = Get-CMTaskSequence -TaskSequencePackageId $RunTS.TsPackageID
        Write-Host "Copying Sub-TS $($RunTS.Name)" -ForegroundColor Green
        $NewTS = Copy-CMTaskSequence -Id $RunTS.TsPackageID
        $NewTSName = ($NewTS.Name).Replace("-$($NewTS.PackageID)","-$FolderDate")  
        Start-Sleep -Seconds 2
        Set-CMTaskSequence -TaskSequenceId $NewTS.PackageID -NewName $NewTSName -Description "Exported from GARYTOWN.COM on $FolderDate"
        Start-Sleep -Seconds 1 
        #Added this section because sometimes it wasn't renaming properly, so I'm just doing a check and name update if it didn't rename properly
        $NewTSTest = Get-CMTaskSequence -TaskSequencePackageId $NewTS.PackageID
        if (!($NewTSTest.Name -eq $NewTSName)){Set-CMTaskSequence -TaskSequenceId $NewTS.PackageID -NewName $NewTSName -Description "Exported from GARYTOWN.COM on $FolderDate"}
        Write-Host "New TS Created with name $NewTSName" -ForegroundColor Green
        Move-CMObject -ObjectId $NewTS.PackageID -FolderPath $NewFolderPath
        Write-Host "Moved to Folder $FolderName " -ForegroundColor Green
        Write-Host ____________________________________ -ForegroundColor Gray
        $TSInfoObject = New-Object PSObject -Property @{
            OldPackageID     = $RunTS.TsPackageID
            NewPackageId     = $NewTS.PackageID
            OldTSName        = $RunTS.Name
            NewTSName        = $NewTSName
            }
        $TSInfoDatabase += $TSInfoObject
        }


    #Replace old TS Steps with the New Exported Steps
    foreach ($ExportedTS in $ExportedTSDatabase)
        {
        Write-Host "Updating TS: $($ExportedTS.NewExportName) to use newly exported Sub Tasksequences" -ForegroundColor Cyan
        $CopiedRUnTSSteps = Get-CMTaskSequenceStepRunTaskSequence -TaskSequenceName $($ExportedTS.NewExportName)
        foreach ($CopiedRUnTSStep in $CopiedRUnTSSteps)
            {
            $ReplacementStep = ($TSInfoDatabase | Where-Object {$_.OldPackageID -eq $CopiedRUnTSStep.TsPackageID})
            Write-host "Updating Run TS Step with Name: $($ReplacementStep.OldTSName) to $($ReplacementStep.NewTSName) with ID: $($ReplacementStep.NewPackageID)" -ForegroundColor Green
            $UpdatedTS = Get-CMTaskSequence -TaskSequencePackageId $ReplacementStep.NewPackageId
            Set-CMTaskSequenceStepRunTaskSequence -TaskSequenceName $ExportedTS.NewExportName -StepName $ReplacementStep.OldTSName -RunTaskSequence $UpdatedTS -NewStepName $ReplacementStep.NewTSName
            Write-Host ____________________________________ -ForegroundColor DarkGray

            }

         Write-Host ____________________________________ -ForegroundColor Cyan
        }


#This section does the Comparison between the previous export and the current production TS.
foreach ($TaskSequence in $TaskSequenceTable)
    {
    Set-Location -Path "$($SiteCode):"
    $TSObject = Get-CMTaskSequence -TaskSequencePackageId $TaskSequence.TSPackageID
    Set-Location -Path "C:"
    if (Test-Path "$($LastExportLocation)\$($TSObject.Name).xml"){$TSObjectLastRun = Import-Clixml -Path "$($LastExportLocation)\$($TSObject.Name).xml"}
    #Export the TS as XML Data into the Last Export Folder for Reference the next time you run script
    Export-Clixml -InputObject $TSObject -Path "$($LastExportLocation)\$($TSObject.Name).xml" -Force
    if (-not($TSObjectLastRun -eq $null))
        {
        if ($TSObject.LastRefreshTime -eq $TSObjectLastRun.LastRefreshTime)
            {
            CMTraceLog -Message "TS: $($TSObject.Name) - No Changes since last Export" -Type 1 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
            CMTraceLog -Message "    TS: $($TSObject.Name) - Last Refresh: $($TSObject.LastRefreshTime.ToString("yyyy-MM-dd")) " -Type 1 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
            }
        Else
            {
            
            #Lots happening here... 
            #This goes through and compares the TS(s) with the last time the export was done (XML Files in the Last Export location Folder)
            #It will list a few basics of each steps, and you'll have to pull out the change visually.  
            #For Exmaple, if you don't see 2 instances of a step (Current & Previous), then it was an Add or Remove
                #Current = Added
                #Previous = Removed
            #If you see both Current & Previous listed, but don't see a change to the step in the log, then it's one of the things I don't log (Continue on Error, Disabled, Conditions, etc)
                #You'll have to dig through the XML Files of the changed Step to find the difference. (If you really want to know)
            CMTraceLog -Message "TS: $($TSObject.Name) - New Changes since last Export" -Type 3 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
            CMTraceLog -Message "    TS: $($TSObject.Name) - New Refresh: $($TSObject.LastRefreshTime.ToString("yyyy-MM-dd")) from :$($TSObjectLastRun.LastRefreshTime.ToString("yyyy-MM-dd")) " -Type 1 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
            CMTraceLog -Message "TS: $($TSObject.Name) - New Refresh: $($TSObject.LastRefreshTime.ToString("yyyy-MM-dd")) from :$($TSObjectLastRun.LastRefreshTime.ToString("yyyy-MM-dd"))" -Type 2 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
            CMTraceLog -Message "TS: $($TSObject.Name) - New Refresh: $($TSObject.LastRefreshTime.ToString("yyyy-MM-dd")) from :$($TSObjectLastRun.LastRefreshTime.ToString("yyyy-MM-dd"))" -Type 2 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
            Export-Clixml -InputObject $TSObjectLastRun.Sequence -Path "\\src\src$\OSD\TSExports\ExportLastRun.XML"
            Export-Clixml -InputObject $TSObject.Sequence -Path "\\src\src$\OSD\TSExports\ExportCurrentRun.XML"

            
            [xml]$XML1 = $TSObjectLastRun.Sequence
            [xml]$XML2 = $TSObject.Sequence

            #Grabs all Steps from All TS
            $steps1 = $XML1.GetElementsByTagName('step')
            $Steps2 = $XML2.GetElementsByTagName('step')
            #Grabs all groups from All TS
            $groups1 = $XML1.GetElementsByTagName('group')
            $groups2 = $XML2.GetElementsByTagName('group')
            
            #Gets the Differences in the Steps / Groups
            $diffStep = Compare-Object -ReferenceObject $steps1.outerxml -DifferenceObject $steps2.outerxml
            $diffgroup = Compare-Object -ReferenceObject $groups1.name -DifferenceObject $groups2.name

            CMTraceLog -Message "   ---- Starting Details of Step Differences Since last Export ----" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
            CMTraceLog -Message "   ---- Starting Details of Step Differences Since last Export ----" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
            #Build more "Friendly" Array of the Data in XML to make logging easier
            if ($diffStep -ne $null)
                {

                $stepobject = @()
                Foreach ($step in $diffStep)
                    {$obj = New-Object -TypeName PSObject
                    [XML]$stepXML = $step.InputObject
                    if ($step.SideIndicator -eq "<="){$status = "Previous Export"} Else {$status = "Current Export"}
                    $obj | Add-Member -MemberType NoteProperty -Name 'Indicator' -Value $step.SideIndicator
                    $obj | Add-Member -MemberType NoteProperty -Name 'Status' -Value $status
                    $obj | Add-Member -MemberType NoteProperty -Name 'StepName' -Value $stepXML.step.name
                    $obj | Add-Member -MemberType NoteProperty -Name 'StepType' -Value $stepXML.step.type
                    $obj | Add-Member -MemberType NoteProperty -Name 'StepAction' -Value $stepXML.step.action
                    $obj | Add-Member -MemberType NoteProperty -Name 'StepDescription' -Value $stepXML.step.description
                    $stepobject += $obj}
            
                #Sort the Data by Step Name
                $stepobject = $stepobject | Sort-Object -Property "StepName"
            
                #Create the Logs for Changes in Steps
                foreach ($step in $stepobject)
                    {
                    
                    CMTraceLog -Message "        ---- ---- ---- ----" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                    CMTraceLog -Message "        ---- ---- ---- ----" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                    if ($step.Indicator -eq "=>")
                        {
                        Write-Host "Current Export - Step Name: $($step.StepName)" -ForegroundColor Yellow
                        CMTraceLog -Message "        Current Export - Step Name: $($step.StepName)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Current Export - Step Name: $($step.StepName)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        Write-Host "Current Export - Step Type: $($step.StepType)"   -ForegroundColor Cyan
                        CMTraceLog -Message "        Current Export - Step Type: $($step.StepType)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Current Export - Step Type: $($step.StepType)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        Write-Host "Current Export - Step Action: $($step.StepAction)"   -ForegroundColor Cyan
                        CMTraceLog -Message "        Current Export - Step Action: $($step.StepAction)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Current Export - Step Action: $($step.StepAction)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        Write-Host "Current Export - Step Decription: $($step.StepDescription)"   -ForegroundColor Cyan
                        CMTraceLog -Message "        Current Export - Step Decription: $($step.StepDescription)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Current Export - Step Decription: $($step.StepDescription)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        }
                    if ($step.Indicator -eq "<=")
                        {
                        Write-Host "Previous Export - Step Name: $($step.StepName)" -ForegroundColor Yellow
                        CMTraceLog -Message "        Previous Export - Step Name: $($step.StepName)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Previous Export - Step Name: $($step.StepName)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        Write-Host "Previous Export - Step Type: $($step.StepType)"   -ForegroundColor Cyan
                        CMTraceLog -Message "        Previous Export - Step Type: $($step.StepType)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Previous Export - Step Type: $($step.StepType)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        Write-Host "Previous Export - Step Action: $($step.StepAction)"   -ForegroundColor Cyan
                        CMTraceLog -Message "        Previous Export - Step Action: $($step.StepAction)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Previous Export - Step Action: $($step.StepAction)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        Write-Host "Previous Export - Step Decription: $($step.StepDescription)"   -ForegroundColor Cyan
                        CMTraceLog -Message "        Previous Export - Step Decription: $($step.StepDescription)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Previous Export - Step Decription: $($step.StepDescription)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        }
                    }
                CMTraceLog -Message "        ---- ---- Step Changes End---- ----" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        ---- ---- Step Changes End---- ----" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                }        
            #Create the Logs for Changes in groups
            if ($diffgroup -ne $null)
                {
                CMTraceLog -Message "         ---- ---- Group Changes Start - Group Name Only ---- ----" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "         ---- ---- Group Changes Start - Group Name Only ---- ----" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                foreach ($group in $diffgroup)
                    {
                    CMTraceLog -Message "        --- --- --- ---" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                    CMTraceLog -Message "        --- --- --- ---" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                    if ($group.SideIndicator -eq "=>")
                        {
                        CMTraceLog -Message "        Current Export Group Name: $($group.InputObject)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Current Export Group Name: $($group.InputObject)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        }
                    
                    if ($group.SideIndicator -eq "<=")
                        {
                        CMTraceLog -Message "        Previous Export Group Name: $($group.InputObject)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                        CMTraceLog -Message "        Previous Export Group Name: $($group.InputObject)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                        }
                    }
                CMTraceLog -Message "        ---- ---- ---- ----" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        ---- ---- ---- ----" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                CMTraceLog -Message "   ---- Finished Details of Differences Since last Export ----" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "   ---- Finished Details of Differences Since last Export ----" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                }
            
            }
        }
    $TSSourceDate = $TSObject.LastRefreshTime.ToString("yyyyMMdd")
    $TSExportDir = "$($ExportLocation)\TaskSequences\$($TaskSequence.Folder)"
    $TSExportName = "$($TaskSequence.Folder)_GARYTOWN_$($TSSourceDate).zip"
    
    if (-Not(Test-Path -Path $TSExportDir)){New-Item -ItemType directory -Path $TSExportDir}
    CMTraceLog -Message "----- Exporting TS: $($TSObject.Name) ------" -Type 1 -LogFile $LogFile -Component "WaaS TS Export"
    Set-Location -Path "$($SiteCode):"
    #Grabs the Copied Task Sequence Object to export the copy instead of the orginal.
    $CopiedExportTS = $ExportedTSDatabase | Where-Object {$_.OldTSPackageID -eq $TSObject.PackageID}
    $CopiedExportTSObject = Get-CMTaskSequence -TaskSequencePackageId $CopiedExportTS.NewExportPackageId
    $Comment = "$($CopiedExportTSObject.Description) | Date Last Modified: $($TSObject.LastRefreshTime)"
    Export-CMTaskSequence -InputObject $CopiedExportTSObject -ExportFilePath "$($TSExportDir)\$($TSExportName)" -Comment $Comment -WithDependence $true -WithContent $false -Force
    Set-Location -Path "C:"
    CMTraceLog -Message "Exported TS: $($TaskSequence.Folder) on $($TimeStamp) with a Last Modified Date of: $($TSSourceDate)" -Type 2 -LogFile $LogFile -Component "WaaS TS Export"
    Write-Output "Exported TS: $($CopiedExportTSObject.Name) on $($TimeStamp) with a Last Modified Date of: $($TSSourceDate)"
    Set-Location -Path "$($SiteCode):"
    
    #List & Log References for each TS
    if (($TSObject.References).count -ge 1)
       { 
        Set-Location -Path "C:"
        CMTraceLog -Message "----- Listing References ------" -Type 1 -LogFile $LogFile -Component "WaaS TS Reference"
        Set-Location -Path "$($SiteCode):"
        foreach ($Reference in $TSObject.References)
            {
            $TSReferenceObject = Get-CMTaskSequence -TaskSequencePackageId $Reference.Package -ErrorAction SilentlyContinue
            if ($TSReferenceObject -ne $null) 
                {
                $TSReferenceSourceDate = $TSReferenceObject.LastRefreshTime.ToString("yyyyMMdd")
                Set-Location -Path "C:"
                CMTraceLog -Message "     Exported Reference TS: $($TSReferenceObject.Name) with a Last Modified Date of: $($TSReferenceSourceDate)" -Type 1 -LogFile $LogFile -Component "WaaS TS Reference"
                Write-Output "Exported Reference TS: $($TSReferenceObject.Name) with a Last Modified Date of: $($TSReferenceSourceDate)"
                Set-Location -Path "$($SiteCode):"
                }
            }
        foreach ($Reference in $TSObject.References)
            {    
            $TSReferencePackageObject = Get-CMPackage -Id $Reference.Package -fast -ErrorAction SilentlyContinue
            if ($TSReferencePackageObject -ne $null) 
                {
                $TSReferencePackageSourceDate = $TSReferencePackageObject.LastRefreshTime.ToString("yyyyMMdd")
                Set-Location -Path "C:"
                CMTraceLog -Message "     Exported Reference Package: $($TSReferencePackageObject.Name) with a Last Modified Date of: $($TSReferencePackageSourceDate) - NO CONTENT" -Type 1 -LogFile $LogFile -Component "WaaS TS Reference"
                Write-Output "Exported Reference Package: $($TSReferencePackageObject.Name) with a Last Modified Date of: $($TSReferencePackageSourceDate) - NO CONTENT"
                Set-Location -Path "$($SiteCode):"
                }

            }    
        Set-Location -Path "C:"
        CMTraceLog -Message "----- Finished Listing References ------" -Type 1 -LogFile $LogFile -Component "WaaS TS Reference"
        Set-Location -Path "$($SiteCode):"
        }
    
    }


#Export Package Section.
Set-Location -Path "C:"
CMTraceLog -Message "----- Exporting WaaS Packages WITH CONTENT ------" -Type 3 -LogFile $LogFile -Component "WaaS Package Export"
#Get Package File Information from the last run.  It will then be replaced after this with the Files from the current run, then get compared to find the differences.
$PackageContentsOld = Get-ChildItem -Path "$($LastExportLocation)\Packages" -Recurse

foreach ($Content in $ContentPackageTable)
    {
    CMTraceLog -Message "       Exporting Package $($content.ContentName)" -Type 1 -LogFile $LogFile -Component "WaaS Package Export"
    Set-Location -Path "$($SiteCode):"
    $ContentObject = Get-CMPackage -Id $Content.PackageID -fast
    Set-Location -Path "C:"
    if (Test-Path "$($LastExportLocation)\$($ContentObject.Name).xml"){$ContentObjectLastRun = Import-Clixml -Path "$($LastExportLocation)\$($ContentObject.Name).xml"}
    Export-Clixml -InputObject $ContentObject -Path "$($LastExportLocation)\$($ContentObject.Name).xml" -Force
    if (-not($ContentObjectLastRun -eq $null))
        {
        if ($ContentObject.LastRefreshTime -eq $ContentObjectLastRun.LastRefreshTime)
            {
            CMTraceLog -Message "Package: $($ContentObject.Name) - No Changes since last Export" -Type 1 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
            CMTraceLog -Message "    Package: $($ContentObject.Name) - Last Refresh: $($ContentObject.LastRefreshTime.ToString("yyyy-MM-dd")) " -Type 1 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
            }
        Else
            {
            CMTraceLog -Message "Package: $($ContentObject.Name) - New Changes since last Export" -Type 3 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
            CMTraceLog -Message "    Package: $($ContentObject.Name) - New Refresh: $($ContentObject.LastRefreshTime.ToString("yyyy-MM-dd")) from :$($ContentObjectLastRun.LastRefreshTime.ToString("yyyy-MM-dd")) " -Type 1 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
            CMTraceLog -Message "Package: $($ContentObject.Name) - New Refresh: $($ContentObject.LastRefreshTime.ToString("yyyy-MM-dd")) from :$($ContentObjectLastRun.LastRefreshTime.ToString("yyyy-MM-dd")) " -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
            }
        }
    $ContentSourceDate = $ContentObject.LastRefreshTime.ToString("yyyyMMdd")
    $ContentExportDir = "$($ExportLocation)\Packages\$($Content.Folder)"
    $ContentExportName = "$($Content.Folder)_GARYTOWN_$($ContentSourceDate).zip"
    Set-Location -Path "C:"
    
    if (-Not(Test-Path -Path $ContentExportDir)){New-Item -ItemType directory -Path $ContentExportDir}
    
    #Export CM Package For Upload
    Set-Location -Path "$($SiteCode):"
    Export-CMPackage -InputObject $ContentObject -FileName "$($ContentExportDir)\$($ContentExportName)" -Comment $Comment.Comment -WithContent $true -Force
    
    Set-Location -Path  "C:"
    if (Test-Path -Path "$($LastExportLocation)\Packages\$($Content.Folder)")
        {
        Remove-Item -Path "$($LastExportLocation)\Packages\$($Content.Folder)" -Recurse -Force
        New-Item -ItemType directory -Path "$($LastExportLocation)\Packages\$($Content.Folder)"
        }
    Copy-Item -Path "$($ContentExportDir)\$($Content.Folder)_GARYTOWN_$($ContentSourceDate)_files\*" -Recurse -Destination "$($LastExportLocation)\Packages\$($Content.Folder)" -Force
    
    
    #Export cm package for Compare
    #Export-CMPackage -InputObject $ContentObject -FileName "$($LastExportLocation)\Packages\$($Content.Folder).zip" -Comment $Comment.Comment -WithContent $true -Force
    #Remove-Item -Path "$($LastExportLocation)\Packages$($Content.Folder)_GARYTOWN_$($ContentSourceDate)_Files\*"($Content.Folder).zip" -Force
    
    #CMTraceLog -Message "Exported Package: $($Content.Folder) on $($TimeStamp) with a Last Modified Date of: $($ContentSourceDate)" -Type 1 -LogFile $LogFile -Component "WaaS Package Export"
    #Write-Host "$($TestDiff[0].name) Time Stamp Changed from Date $($testdiff[0].LastWriteTime) to $($testdiff[1].LastWriteTime)"
    #Write-Output "Exported Package: $($Content.Folder) on $($TimeStamp) with a Last Modified Date of: $($ContentSourceDate)"
    #Set-Location -Path "$($SiteCode):"
    
    } 
    Set-Location -Path "C:"
    #Grabs Info from The Current Export of packages to be able to create the Differences
    $PackageContentsNew = Get-ChildItem -Path "$($LastExportLocation)\Packages" -Recurse
    $PackageDiff = Compare-Object $PackageContentsold $PackageContentsnew -Property Name, LastWriteTime, Length | Where-Object {$_.Length -ge "1"}
    
    if ($PackageDiff -ne $null)
        {
        Write-Host "Package Changes Start Here" -ForegroundColor Cyan
        CMTraceLog -Message "         ---- ---- Package Changes Start ---- ----" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
        CMTraceLog -Message "         ---- ---- Package Changes Start ---- ----" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
        foreach ($PackDiff in $PackageDiff)
            {
            CMTraceLog -Message "        --- --- --- ---" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
            CMTraceLog -Message "        --- --- --- ---" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
            if ($PackDiff.SideIndicator -eq "=>")
                {
                Write-Host "Current Package File Name: $($PackDiff.Name)" -ForegroundColor Cyan
                CMTraceLog -Message "        Current Package File Name: $($PackDiff.Name)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Current Package File Name: $($PackDiff.Name)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Current Package File LastWriteTime: $($PackDiff.LastWriteTime)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Current Package File LastWriteTime: $($PackDiff.LastWriteTime)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Current Package File Size: $($PackDiff.Length)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Current Package File Size: $($PackDiff.Length)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                }
                    
            if ($PackDiff.SideIndicator -eq "<=")
                {
                Write-Host "Previous Package File Name: $($PackDiff.Name)" -ForegroundColor Cyan
                CMTraceLog -Message "        Previous Package File Name: $($PackDiff.Name)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Previous Package File Name: $($PackDiff.Name)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Previous Package File LastWriteTime: $($PackDiff.LastWriteTime)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Previous Package File LastWriteTime: $($PackDiff.LastWriteTime)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Previous Package File Size: $($PackDiff.Length)" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
                CMTraceLog -Message "        Previous Package File Size: $($PackDiff.Length)" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
                }
            }
        CMTraceLog -Message "        ---- ---- ---- ----" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
        CMTraceLog -Message "        ---- ---- ---- ----" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
        Write-Host "Package Changes Finished" -ForegroundColor Cyan
        CMTraceLog -Message "         ---- ---- Package Changes Finish ---- ----" -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
        CMTraceLog -Message "         ---- ---- Package Changes Finish ---- ----" -Type 1 -LogFile $ChangeLogCombine -Component "WaaS TS Export Changes"
        }

CMTraceLog -Message "----- Exporting WaaS Packages WITH CONTENT Complete ------" -Type 3 -LogFile $LogFile -Component "WaaS Package Export"
#Export Waas Baseline
Set-Location -Path "$($SiteCode):"
$WaaSBaseline = Get-CMBaseline -Name "WaaS*"
Set-Location -Path "C:"
if (Test-Path "$($LastExportLocation)\$($WaaSBaseline.LocalizedDisplayName).xml"){$WaaSBaselineLastRun = Import-Clixml -Path "$($LastExportLocation)\$($WaaSBaseline.LocalizedDisplayName).xml"}
Export-Clixml -InputObject $WaaSBaseline -Path "$($LastExportLocation)\$($WaaSBaseline.LocalizedDisplayName).xml" -Force
if (-Not($WaaSBaselineLastRun -eq $null))
    {
    if ($WaaSBaseline.CIVersion -eq $WaaSBaselineLastRun.CIVersion)
        {
        CMTraceLog -Message "Baseline: $($WaaSBaseline.LocalizedDisplayName) - No Changes since last Export" -Type 1 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
        CMTraceLog -Message "    Baseline: $($WaaSBaseline.LocalizedDisplayName) - Version: $($WaaSBaselineLastRun.CIVersion) Last Refresh: $($WaaSBaseline.DateLastModified.ToString("yyyy-MM-dd")) " -Type 1 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
        }
    Else
        {
        CMTraceLog -Message "Baseline: $($WaaSBaseline.LocalizedDisplayName) - New Changes since last Export" -Type 3 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
        CMTraceLog -Message "    Baseline: $($WaaSBaseline.LocalizedDisplayName) - New Version: $($WaaSBaselineLastRun.CIVersion) from: $($WaaSBaselineLastRun.CIVersion) on $($WaaSBaseline.DateLastModified.ToString("yyyy-MM-dd")) " -Type 1 -LogFile $CompareExportLog -Component "WaaS TS Export Changes"
        CMTraceLog -Message "Baseline: $($WaaSBaseline.LocalizedDisplayName) - New Version: $($WaaSBaselineLastRun.CIVersion) from: $($WaaSBaselineLastRun.CIVersion) on $($WaaSBaseline.DateLastModified.ToString("yyyy-MM-dd")) " -Type 1 -LogFile $ChangeLog -Component "WaaS TS Export Changes"
        }
    }

$WaaSBaselineModDate = $WaaSBaseline.DateLastModified.ToString("yyyyMMdd")
$WaaSBaselineExportDir = "$($ExportLocation)\Baseline"
Set-Location -Path "C:"
if (-Not(Test-Path -Path $WaaSBaselineExportDir)){New-Item -ItemType directory -Path $WaaSBaselineExportDir}
Write-Output "Exporting Baseline: $($WaaSBaseline.LocalizedDisplayName) version: $($WaaSBaseline.CIVersion) with a Last Modified Date of: $($WaaSBaselineModDate)"    
CMTraceLog -Message "Started Export of $($WaaSBaseline.LocalizedDisplayName)" -Type 1 -LogFile $LogFile -Component "WaaS Baseline Export"
Set-Location -Path "$($SiteCode):"
Export-CMBaseline -InputObject $WaaSBaseline -Path "$($WaaSBaselineExportDir)\WaaS_PreAssessment_v$($WaaSBaseline.CIVersion)_$($WaaSBaselineModDate).cab"
Set-Location -Path "C:"
CMTraceLog -Message "Exported Baseline: $($WaaSBaseline.LocalizedDisplayName) version: $($WaaSBaseline.CIVersion) with a Last Modified Date of: $($WaaSBaselineModDate)" -Type 2 -LogFile $LogFile -Component "WaaS Baseline Export"

# Copy ReadMe File into Export Folder
Copy-Item -Path "$($ExportFolderParent)\ReadMe.txt" -Destination $ExportLocation -Force -Verbose
Copy-Item -Path "$($ExportFolderParent)\ReadMeManualChangeLog.txt" -Destination $ExportLocation -Force -Verbose
Copy-Item -Path "$($ExportFolderParent)\WaaS_TS_ChangeLogCombine.log" -Destination $ExportLocation -Force -Verbose
if (-not(Test-Path "$($ExportLocation)\REG2MOF")){New-Item -ItemType Directory -Path "$($ExportLocation)\REG2MOF"}
Copy-Item -Path "$($ExportFolderParent)\REG2MOF\*" -Destination "$ExportLocation\REG2MOF" -Force -Verbose  -Recurse
CMTraceLog -Message "----- WaaS Export Process Complete ------" -Type 3 -LogFile $LogFile -Component "WaaS Package Export"
#Zip Up Export Folder:
$Now = $([datetime]::now.Tostring('s').Replace(':','-'))
Compress-Archive -path "$ExportLocation\*" -DestinationPath "$ExportFolderParent\WaaSExport-$($now).zip" -Force -Verbose



$sftphost = "mywebsite-data.host"
$Password = ConvertTo-SecureString 'secretpassword' -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ('myuserid', $Password)

# Set local file path, SFTP path, and the backup location path which I assume is an SMB path
$FilePath = "$ExportFolderParent\WaaSExport-$($now).zip"
$SftpPath = '/GARYTOWNTECHBLOG/Downloads/WaaS'
#$SmbPath = '\\filer01\Backup'

# Set the IP of the SFTP server
#$SftpIp = '10.209.26.105'

# Load the Posh-SSH module
Install-Module -Name Posh-SSH -Force -SkipPublisherCheck

# Establish the SFTP connection
$ThisSession = New-SFTPSession -ComputerName $sftphost -Credential $Credential

# Upload the file to the SFTP path
Set-SFTPFile -SessionId ($ThisSession).SessionId -LocalFile $FilePath -RemotePath $SftpPath

#Disconnect all SFTP Sessions
Get-SFTPSession | % { Remove-SFTPSession -SessionId ($_.SessionId) }

