<# 
 .SYNOPSIS 
     Document the selected SCCM task sequence in Excel

 .REQUIREMENTS
     CM Console Installed, so you have the CM PowerShell Commandlets
     Excel Installed, so you have Excel

 .DESCRIPTION 
     Orignal Idea from Gregory Bouchu, I started with his script out on technet (which is now gone), deleted a ton of code, copy and paste a ton to add additional cells, then updated it to use CM Commandlets and support child-task seqeunces

     Collections created:
        The Excel sheet will give you seven columns:
        - Id of the task (basically just an incremented number)
        - Name of the task step
        - Type of the task (Step or group).
        - Type of Step (Run Command Line, etc)
        - The description
        - If there is condition on the task (Yes or No)
        - If Continue on error is checked (Yes or No)
		- If Step / Group is disabled (Yes or No)
        - The Condition on the Steps
        - The Path of the Step
        - The Action in the Step

        - References
          - Packages
          - Applications
          - OS / Upgrade Media

        - TS General Info

    
 .PARAMETER SiteServer
    Your site server name. Mandatory

 .PARAMETER SiteCode
    Your site code. Mandatory

 .PARAMETER TSName
    The name of the TS you want to export. Mandatory

 .NOTES 
     Author : Gary Blok
     Website: GARYTOWN.COM
     Twitter: @gwblok

     Idea and Excel coding taken from:
     
     Author : Gregory Bouchu
     Website: http://microsoft-desktop.com/
     Twitter: @gbouchu

     Function help from Nathan @theznerd 

 .VERSION
    2021.02.25 - Initial Release of TS Steps
    2021.03.01 - Added References Tab
    2021.03.02 - Changed everything, created functions.  Added General Info Tab
    2021.03.30 - Added Check if you picked a Task Sequence name with more than one Task Sequence with that name in your CM
 

 .EXAMPLE 
     CMTSExportToExcel -Siteserver SCCM01 -Sitecode LAB -TSName Deployment_windows10

  #>


Param (
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter Primary Server Site Server")]
	$ProviderMachineName,
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter Primary Server Site code")]
	$SiteCode,
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter the name of the Task sequence you want to export")]
	$TSName
)

Function Set-TitleCells
    {
    Param (
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter Font Size")]
	$FontSize,
	[Parameter(Mandatory = $false, HelpMessage = "Bold Font?")]
	[switch]$FontBold,
	[Parameter(Mandatory = $True, HelpMessage = "Text Alignment")]
    [ValidateSet("Center","Right","Left")]
	$FontAlignment
    )
    if ($FontAlignment -eq "Center"){$HorizontalAlignment = -4108}
    elseif ($FontAlignment -eq "Right"){$HorizontalAlignment = -4152}
    elseif ($FontAlignment -eq "Left"){$HorizontalAlignment = -4131}
    else{$HorizontalAlignment = -4131}


    $TSSheet.Cells.Item($row, $column).Font.Size = $FontSize
    $TSSheet.Cells.Item($row, $column).Font.Bold = $FontBold
    $TSSheet.Cells.Item($row, $column).Font.Name = "Cooper Black"
    $TSSheet.Cells.Item($row, $column).Font.ThemeFont = 2
    $TSSheet.Cells.Item($row, $column).Font.ThemeColor = 2
    $TSSheet.Cells.Item($row, $column).Font.ColorIndex = 2
    $TSSheet.Cells.Item($row, $column).Font.Color = 2
    $TSSheet.Cells.Item($row, $column).Interior.ColorIndex = 41
    $TSSheet.Cells($row, $column).HorizontalAlignment = $HorizontalAlignment
    }

function New-RowItem {
    Param (
    [Parameter(Mandatory = $True, HelpMessage = "Content in Cell")]
	[string]$Content,	
    [Parameter(Mandatory = $True)]
	$row,
	[Parameter(Mandatory = $True)]
	$Column,
	[Parameter(Mandatory = $True)]
    [ValidateSet("Center","Right","Left")]
	$FontAlignment,
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter Font Size")]
	[int]$FontSize,
	[Parameter(Mandatory = $false, HelpMessage = "Bold Font?")]
	[switch]$FontBold
    )
    if ($FontAlignment -eq "Center"){$HorizontalAlignment = -4108}
    elseif ($FontAlignment -eq "Right"){$HorizontalAlignment = -4152}
    elseif ($FontAlignment -eq "Left"){$HorizontalAlignment = -4131}
    else{$HorizontalAlignment = -4131}

	$TSSheet.Cells.Item($row, $Column) = "$Content"
	$TSSheet.Cells.Item($row, $Column).font.bold = $FontBold
	$TSSheet.Cells.Item($row, $Column).font.size = $FontSize
	$TSSheet.Cells.Item($row, $Column).HorizontalAlignment = $HorizontalAlignment

}

Function Get-NodeTree
{
    param(
        [System.Xml.XmlElement]$parentNode,
        [string]$rootPath = "root"
    )
    $nodeTree = @()

    if($parentNode.LocalName -ne "sequence")
    {
        if($parentNode.type -ne $Null){$StepType = ($parentNode.type).replace("SMS_TaskSequence_","")}
        if($parentNode.condition -ne $Null){$Condition = "TRUE"}
        Else {$Condition = "FALSE"}
        if ($parentNode.disable -eq "true"){$StepStatus = "Disabled"}
        Else {$StepStatus = "Enabled"}
        if ($parentNode.continueOnError -eq "true"){$continueOnError = "TRUE"}
        Else {$continueOnError = "FALSE"}
        if ($parentnode.condition.operator)
            {
            $ConditionInfo = foreach ($expression in $parentnode.condition.operator.expression)
                {
                write-output ($expression.type).Replace("SMS_TaskSequence_","")
                foreach ($item in $expression.variable)
                    {
                    "$($item.Name) = $($item.'#text')"
                    }
                }
            }
        else
            {
            $ConditionInfo = foreach ($expression in $parentnode.condition.expression)
                {
                write-output "Type: $(($expression.type).Replace('SMS_TaskSequence_',''))"
                foreach ($item in $expression.variable)
                    {
                    "$($item.Name) = $($item.'#text')"
                    }
                }

            }
                $node = [PSCustomObject]@{
            Name = $parentNode.name
            Type = $parentNode.LocalName
            StepType = $StepType
            StepStatus = $StepStatus
            Description = $parentNode.description
            Condition = $Condition
            Path = $rootPath
            Action = $parentNode.action
            ConditionInfo = $ConditionInfo
            continueOnError = $continueOnError

        }
        
        $nodeTree += $node
        $rootPath = "$rootPath\$($node.Name)"
    }

    if($parentNode.LocalName -eq "subtasksequence")
    {
        #$subTSID = Get-CMTaskSequence -Name "
        $subTSID = ($parentNode.defaultVarList.variable | where {$_.name -eq "OSDSubTasksequencePackageID"}).'#text'
        #return $subTSID
        [xml]$subxml = (Get-CMTaskSequence -TaskSequencePackageId $subTSID).sequence
        $subsequence = $subxml.SelectNodes("//sequence")
        $nodeTree += Get-NodeTree -parentNode $subsequence[0] -rootPath "$rootPath"
        #TEST
    }
    elseif($parentNode.SelectNodes("step|group|subtasksequence").Count -gt 0)
    {
        foreach($childNode in $parentNode.SelectNodes("step|group|subtasksequence"))
        {
            #if(-not ($childNode.disable -eq "true"))
            #{
                $nodeTree += Get-NodeTree -parentNode $childNode -rootPath "$rootPath"
            #}
        }
    }
    return $nodeTree
}

#$TSName = "OS Deployment - RECAST SOFTWARE"

# Site configuration
#$SiteCode = "PS2" # Site code 
#$ProviderMachineName = "cm.corp.viamonstra.com" # SMS Provider machine name

# Customizations
$initParams = @{}

# Import the ConfigurationManager.psd1 module 
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}

# Connect to the site's drive if it is not already present
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName @initParams
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\" @initParams

$CurrentWorkingTS = Get-CMTaskSequence -Name $TSName
if ($CurrentWorkingTS.Count -gt 1){
    Write-Host "You have more than 1 Task Sequence with that Name, please don't do that, once resolved, you can try again" -ForegroundColor Red
    exit
    }

$SequenceXML = [XML]$CurrentWorkingTS.Sequence
$parentnode = $SequenceXML.sequence

#region Main Excel Sheet with Step Info

$TSStepInfo = Get-NodeTree -parentNode $SequenceXMl.sequence 

#$TSStepInfo

#Create excel COM object
$excel = New-Object -ComObject excel.application

#Make Visible
$excel.Visible = $True

# Add a workbook
$workbook = $excel.Workbooks.Add()

# Connect to worksheet, rename and make it active
$TSSheet = $workbook.Worksheets.Item(1)
$TSSheet.Name = "Export_TS"
$TSSheet.Activate() | Out-Null

# Create a Title for the first worksheet and adjust the font
$row = 1
$Column = 1
$TSSheet.Cells.Item($row, $column) = $TSName

$range = $TSSheet.Range("a1", "I1")
$range = $TSSheet.Range("a1", "K1")
$range.Merge() | Out-Null
$range.VerticalAlignment = -4160

Set-TitleCells -FontSize 26 -FontAlignment Left -FontBold

# Increment row
$row++
$initalRow = $row

# Create columns
$ColumnNames = @("ID","Name","Type", "Step Type", "Description", "Condition","Cont on error", "Enabled", "Condition Info", "Path", "Action")
$Column = 1
foreach ($ColumnName in $ColumnNames)#{}
    {
    New-RowItem -row $row -Column $Column -FontSize 16 -FontAlignment Left -Content $ColumnName
    $Column++
    }


$i = 0


foreach ($Step in $TSStepInfo)#{}

    {  
    $i = $i + 1
    $row++
    $Column = 1
    $StepConditioninfo = "{0}" -f $($step.ConditionInfo -join ' , ')
    New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $i
    $Column++
    if ($step.Name){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $step.Name}
    $Column++
    if ($step.Type){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $step.Type}
    $Column++
    if ($step.steptype){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $step.steptype}
    $Column++
    if ($step.description){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $step.description}
    $Column++
    if ($step.Condition){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $step.Condition}
    $Column++
    if ($step.continueOnError){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $step.continueOnError}
    $Column++
    if ($step.StepStatus){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $step.StepStatus}
    $Column++
    if ($StepConditioninfo){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $StepConditioninfo}
    $Column++
    if ($step.Path){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment right -Content $step.Path}
    $Column++
    if ($step.Action){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $step.Action}
    }


# Format columns
$TSsheet.columns.Item('A').EntireColumn.Columnwidth = 5
$TSsheet.columns.Item('B').EntireColumn.Columnwidth = 40
$TSsheet.columns.Item('C').EntireColumn.Columnwidth = 20
$TSsheet.columns.Item('D').EntireColumn.Columnwidth = 30
$TSsheet.columns.Item('E').EntireColumn.Columnwidth = 100
$TSsheet.columns.Item('F').EntireColumn.Columnwidth = 13
$TSsheet.columns.Item('G').EntireColumn.Columnwidth = 20
$TSsheet.columns.Item('H').EntireColumn.Columnwidth = 10
$TSsheet.columns.Item('I').EntireColumn.Columnwidth = 200
$TSsheet.columns.Item('J').EntireColumn.Columnwidth = 100
$TSsheet.columns.Item('K').EntireColumn.Columnwidth = 200

#endregion


#region 2nd Work Sheet with References

$ApplicationReferences = ($SequenceXML.sequence.referenceList.SelectNodes("//reference")) | Select-Object "application" | Where-Object {$_.Application}
$PackageReferences = ($SequenceXML.sequence.referenceList.SelectNodes("//reference")) | Select-Object "Package" | Where-Object {$_.Package}


# Connect to worksheet, rename and make it active
$TSSheet = $workbook.worksheets.add()
$TSSheet.Name = "References"
$TSSheet.Activate() | Out-Null


# Create a Title for the first worksheet and adjust the font
$row = 1
$Column = 1
$TSSheet.Cells.Item($row, $column) = "References for Task Sequence: $TSName"

#$range = $TSSheet.Range("a1", "I1")
$range = $TSSheet.Range("a1", "K1")
$range.Merge() | Out-Null
$range.VerticalAlignment = -4160

Set-TitleCells -FontSize 26 -FontAlignment Left -FontBold

#Package Info

$row++
$Column = 1

New-RowItem -row $row -Column $Column -FontAlignment Left -FontSize 20 -FontBold -Content "Packages"


# Increment row
$row++
$initalRow = $row


# Create columns
$ReferenceColumnNames = @("Count","Name","Package ID", "Package Size", "Description", "Manufacturer","Version", "Language", "Pkg Source Path", "Source Version", "Source Date")
$Column = 1
foreach ($ColumnName in $ReferenceColumnNames)#{}
    {
    New-RowItem -row $row -Column $Column -FontSize 16 -FontAlignment Left -Content $ColumnName
    $Column++
    }

$i = 0
Foreach ($PackageReference in $PackageReferences)
    {
    $PackageInfo = $Null
    $PackageInfo = Get-CMPackage -Fast -Id $PackageReference.package
    if ($PackageInfo)
        {
        $i = $i + 1
        $row++
        $Column = 1
        New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $i
        $Column++
        if ($PackageInfo.Name){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.Name}
        $Column++
        if ($PackageInfo.PackageID){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.PackageID}
        $Column++
        if ($PackageInfo.PackageSize){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.PackageSize}
        $Column++
        if ($PackageInfo.description){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.description}
        $Column++
        if ($PackageInfo.Manufacturer){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.Manufacturer}
        $Column++
        if ($PackageInfo.Version){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.Version}
        $Column++
        if ($PackageInfo.Language){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.Language}
        $Column++
        if ($PackageInfo.PkgSourcePath){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.PkgSourcePath}
        $Column++
        if ($PackageInfo.SourceVersion){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment right -Content $PackageInfo.SourceVersion}
        $Column++
        if ($PackageInfo.SourceDate){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.SourceDate}
	    	
        }
    }



# Application References
$row++ # Increment row
New-RowItem -row $row -Column 1 -FontAlignment Left -FontSize 20 -FontBold -Content "Applications"
$row++ # Increment row

# Create columns
$ReferenceColumnNames = @("Count","Name","Date Created", "Has Content", "Description", "Manufacturer","Version", "Modified by", "AppID", "CI Version", "Last Modified Date")
$Column = 1
foreach ($ColumnName in $ReferenceColumnNames)#{}
    {
    New-RowItem -row $row -Column $Column -FontSize 16 -FontAlignment Left -Content $ColumnName
    $Column++
    }
$i = 0
Foreach ($AppReference in $ApplicationReferences)
    {
    if ($AppReference)
        {
        $AppInfo = Get-CMApplication -Fast -ModelName $AppReference.application
        $i = $i + 1
        $row++
        $Column = 1
        New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $i
        $Column++
        if ($AppInfo.LocalizedDisplayName){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $AppInfo.LocalizedDisplayName}
        $Column++
        if ($AppInfo.DateCreated){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $AppInfo.DateCreated}
        $Column++
        if ($AppInfo.HasContent){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $AppInfo.HasContent}
        $Column++
        if ($AppInfo.LocalizedDescription){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $AppInfo.LocalizedDescription}
        $Column++
        if ($AppInfo.Manufacturer){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $AppInfo.Manufacturer}
        $Column++
        if ($AppInfo.SoftwareVersion){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $AppInfo.SoftwareVersion}
        $Column++
        if ($AppInfo.LastModifiedBy){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $AppInfo.LastModifiedBy}
        $Column++
        if ($AppInfo.ModelName){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $AppInfo.ModelName}
        $Column++
        if ($AppInfo.CIVersion){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment right -Content $AppInfo.CIVersion}
        $Column++
        if ($AppInfo.DateLastModified){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $AppInfo.DateLastModified}
        }
    }



# OS Media / IPU Media References
$row++ # Increment row
New-RowItem -row $row -Column 1 -FontAlignment Left -FontSize 20 -FontBold -Content "OS Media / Update Media"
$row++ # Increment row



# Create columns
$ReferenceColumnNames = @("Count","Name","Package ID", "Package Size", "Description", "Manufacturer","Version", "Source Date", "Pkg Path", "Source Version", "Last Modified Date")
$Column = 1
foreach ($ColumnName in $ReferenceColumnNames)#{}
    {
    New-RowItem -row $row -Column $Column -FontSize 16 -FontAlignment Left -Content $ColumnName
    $Column++
    }
$i = 0
Foreach ($PackageReference in $PackageReferences)
    {
    if (($PackageInfo = Get-CMOperatingSystemImage -Id  $PackageReference.package) -or ($PackageInfo = Get-CMOperatingSystemUpgradePackage -Id  $PackageReference.package))
        {
        $i = $i + 1
        $row++
        $Column = 1
        New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $i
        $Column++
        if ($PackageInfo.Name){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.Name}
        $Column++
        if ($PackageInfo.PackageID){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.PackageID}
        $Column++
        if ($PackageInfo.PackageSize){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.PackageSize}
        $Column++
        if ($PackageInfo.Version){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.Version}
        $Column++
        if ($PackageInfo.Manufacturer){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.Manufacturer}
        $Column++
        if ($PackageInfo.ImageOSVersion){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.ImageOSVersion}
        $Column++
        if ($PackageInfo.SourceDate){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.SourceDate}
        $Column++
        if ($PackageInfo.PkgSourcePath){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.PkgSourcePath}
        $Column++
        if ($PackageInfo.SourceVersion){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment right -Content $PackageInfo.SourceVersion}
        $Column++
        if ($PackageInfo.LastRefreshTime){New-RowItem -row $row -Column $Column -FontSize 12 -FontAlignment Left -Content $PackageInfo.LastRefreshTime}
        } 
    
    }


# Format columns
$TSsheet.columns.Item('A').EntireColumn.Columnwidth = 8
$TSsheet.columns.Item('B').EntireColumn.Columnwidth = 50
$TSsheet.columns.Item('C').EntireColumn.Columnwidth = 20
$TSsheet.columns.Item('D').EntireColumn.Columnwidth = 15
$TSsheet.columns.Item('E').EntireColumn.Columnwidth = 80
$TSsheet.columns.Item('F').EntireColumn.Columnwidth = 20
$TSsheet.columns.Item('G').EntireColumn.Columnwidth = 15
$TSsheet.columns.Item('H').EntireColumn.Columnwidth = 20
$TSsheet.columns.Item('I').EntireColumn.Columnwidth = 90
$TSsheet.columns.Item('J').EntireColumn.Columnwidth = 20
$TSsheet.columns.Item('K').EntireColumn.Columnwidth = 25

#endregion


#region 3rd Work Sheet with General Info

# Connect to worksheet, rename and make it active
$TSSheet = $workbook.worksheets.add()
$TSSheet.Name = "General Info"
$TSSheet.Activate() | Out-Null


# Create a Title for the first worksheet and adjust the font
$row = 1
$Column = 1
$TSSheet.Cells.Item($row, $column) = "General Info for Task Sequence: $TSName"

#$range = $TSSheet.Range("a1", "I1")
$range = $TSSheet.Range("a1", "K1")
$range.Merge() | Out-Null
$range.VerticalAlignment = -4160

Set-TitleCells -FontSize 20 -FontBold -FontAlignment Left

#TS Info
$TSDumpInfo = $CurrentWorkingTS | Select-Object -Property * -ExcludeProperty Sequence, References, Properties, NamedValueDictionary, ConnectionManager, PropertyList, MethodList, PropertyNames, ObjectClass, ManagedObject, EmbeddedProperties,EmbeddedPropertyLists,OverridingObjectClass, RegMultiStringLists,RetainObjectLock, SmsProviderObjectPath, SecuredScopeNames, SupportedOperatingSystems, SecurityVerbs, Count, TraceProperties,ActionInProgress
$TSDumpInfo.PSObject.Properties | ForEach-Object {
    if ($_.Value)
        {
        $row++
        New-RowItem -row $row -Column 1 -FontAlignment Left -FontSize 12 -Content ($_.Name).trim() -ErrorAction SilentlyContinue
        New-RowItem -row $row -Column 2 -FontAlignment Left -FontSize 12 -Content ($_.Value) -ErrorAction SilentlyContinue
        }
}
# Format columns
$TSsheet.columns.Item('A').EntireColumn.Columnwidth = 40
$TSsheet.columns.Item('B').EntireColumn.Columnwidth = 40

#endregion
