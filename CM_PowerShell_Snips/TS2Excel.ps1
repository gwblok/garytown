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
    2021.02.25
 
 .UPDATE


 .EXAMPLE 
     CMTSExportToExcel -Siteserver SCCM01 -Sitecode LAB -TSName Deployment_windows10

 .Gary's Notes for Excel junk
 Text Alignment"
    Center -4108;
    Right -4152
    Left -4131
  #>


Param (
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter Primary Server Site Server")]
	$ProviderMachineName,
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter Primary Server Site code")]
	$SiteCode,
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter the name of the Task sequence you want to export")]
	$TSName
)

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
$SequenceXML = [XML]$CurrentWorkingTS.Sequence
$parentnode = $SequenceXML.sequence

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

$TSSheet.Cells.Item($row, $column).Font.Size = 20
$TSSheet.Cells.Item($row, $column).Font.Bold = $true
$TSSheet.Cells.Item($row, $column).Font.Name = "Cooper Black"
$TSSheet.Cells.Item($row, $column).Font.ThemeFont = 2
$TSSheet.Cells.Item($row, $column).Font.ThemeColor = 2
$TSSheet.Cells.Item($row, $column).Font.ColorIndex = 2
$TSSheet.Cells.Item($row, $column).Font.Color = 2
$TSSheet.Cells.Item($row, $column).Interior.ColorIndex = 41
$TSSheet.Cells($row, $column).HorizontalAlignment = -4131


# Increment row
$row++
$initalRow = $row

# Create columns
$TSSheet.Cells.Item($row, $column) = 'ID'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Name'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Type'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Step Type'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Description'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Condition'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Continue on error'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Enabled'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Condition Info'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Path'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++
$TSSheet.Cells.Item($row, $column) = 'Action'
$TSSheet.Cells.Item($row, $column).Font.Bold = $false
$TSSheet.Cells.Item($row, $column).Font.Size = 16
$TSSheet.Cells($row, $column).HorizontalAlignment = -4108
$Column++

$i = 0


foreach ($Step in $TSStepInfo)#{}

    {  
    $i = $i + 1
    $row++
    $StepConditioninfo = "{0}" -f $($step.ConditionInfo -join ' , ')
	$TSSheet.Cells.Item($row, "A") = $i
	$TSSheet.Cells.Item($row, "A").font.bold = $false
	$TSSheet.Cells.Item($row, "A").font.size = 12
	$TSSheet.Cells.Item($row, "B") = $step.Name
	$TSSheet.Cells.Item($row, "B").font.bold = $false
	$TSSheet.Cells.Item($row, "B").font.size = 12
	$TSSheet.Cells.Item($row, "C") = $step.Type
	$TSSheet.Cells.Item($row, "C").font.bold = $false
	$TSSheet.Cells.Item($row, "C").font.size = 12
	$TSSheet.Cells.Item($row, "D") = $step.steptype
	$TSSheet.Cells.Item($row, "D").font.bold = $false
	$TSSheet.Cells.Item($row, "D").font.size = 12
	$TSSheet.Cells.Item($row, "E") = $step.description
	$TSSheet.Cells.Item($row, "E").font.bold = $false
	$TSSheet.Cells.Item($row, "E").font.size = 12
	$TSSheet.Cells.Item($row, "F") = $step.Condition
	$TSSheet.Cells.Item($row, "F").font.bold = $false
	$TSSheet.Cells.Item($row, "F").font.size = 12
	$TSSheet.Cells.Item($row, "G") = $step.continueOnError
	$TSSheet.Cells.Item($row, "G").font.bold = $false
	$TSSheet.Cells.Item($row, "G").font.size = 12
	$TSSheet.Cells.Item($row, "H") = $step.StepStatus
	$TSSheet.Cells.Item($row, "H").font.bold = $false
	$TSSheet.Cells.Item($row, "H").font.size = 12	
	$TSSheet.Cells.Item($row, "I") = $StepConditioninfo
	$TSSheet.Cells.Item($row, "I").font.bold = $false
	$TSSheet.Cells.Item($row, "I").font.size = 12	
	$TSSheet.Cells.Item($row, "J") = $Step.Path
	$TSSheet.Cells.Item($row, "J").font.bold = $false
	$TSSheet.Cells.Item($row, "J").font.size = 12
	$TSSheet.Cells.Item($row, "K") = $Step.Action
	$TSSheet.Cells.Item($row, "K").font.bold = $false
	$TSSheet.Cells.Item($row, "K").font.size = 12		
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
