<# 
 .SYNOPSIS 
     Document the selected SCCM Boot Images in Excel

 .REQUIREMENTS
     CM Console Installed, so you have the CM PowerShell Commandlets
     Excel Installed, so you have Excel

 .DESCRIPTION 


    
 .PARAMETER SiteServer
    Your site server name. Mandatory

 .PARAMETER SiteCode
    Your site code. Mandatory


 .NOTES 
     Author : Gary Blok
     Website: GARYTOWN.COM
     Twitter: @gwblok


 .VERSION

    2021.03.02 - Initial Creation
 

 .EXAMPLE 
     CMBootImageExportToExcel -Siteserver SCCM01 -Sitecode LAB

  #>


  Param (
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter Primary Server Site Server")]
	$ProviderMachineName,
	[Parameter(Mandatory = $True, HelpMessage = "Please Enter Primary Server Site code")]
	$SiteCode
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

#used to know which components were added to boot images.  The boot Image provide a number, which requires a lookup.
$LangTable= @(
@{ Region = 'Arabic (Saudi Arabia)' ; Tag = 'ar-SA' ; DecimalID = '1025'}
@{ Region = 'Bulgarian (Bulgaria)' ; Tag = 'bg-BG' ; DecimalID = '1026'}
@{ Region = 'Chinese (Hong Kong SAR)' ; Tag = 'zh-HK' ; DecimalID = '3076'}
@{ Region = 'Chinese (PRC)' ; Tag = 'zh-CN' ; DecimalID = '2052'}
@{ Region = 'Chinese (Taiwan)' ; Tag = 'zh-TW' ; DecimalID = '1028'}
@{ Region = 'Croatian (Croatia)' ; Tag = 'hr-HR' ; DecimalID = '1050'}
@{ Region = 'Czech (Czech Republic)' ; Tag = 'cs-CZ' ; DecimalID = '1029'}
@{ Region = 'Danish (Denmark)' ; Tag = 'da-DK' ; DecimalID = '1030'}
@{ Region = 'Dutch (Netherlands)' ; Tag = 'nl-NL' ; DecimalID = '1043'}
@{ Region = 'English (United States)' ; Tag = 'en-US' ; DecimalID = '1033'}
@{ Region = 'English (United Kingdom)' ; Tag = 'en-GB' ; DecimalID = '2057'}
@{ Region = 'Estonian (Estonia)' ; Tag = 'et-EE' ; DecimalID = '1061'}
@{ Region = 'Finnish (Finland)' ; Tag = 'fi-FI' ; DecimalID = '1035'}
@{ Region = 'French (Canada)' ; Tag = 'fr-CA' ; DecimalID = '3084'}
@{ Region = 'French (France)' ; Tag = 'fr-FR' ; DecimalID = '1036'}
@{ Region = 'German (Germany)' ; Tag = 'de-DE' ; DecimalID = '1031'}
@{ Region = 'Greek (Greece)' ; Tag = 'el-GR' ; DecimalID = '1032'}
@{ Region = 'Hebrew (Israel)' ; Tag = 'he-IL' ; DecimalID = '1037'}
@{ Region = 'Hungarian (Hungary)' ; Tag = 'hu-HU' ; DecimalID = '1038'}
@{ Region = 'Italian (Italy)' ; Tag = 'it-IT' ; DecimalID = '1040'}
@{ Region = 'Japanese (Japan)' ; Tag = 'ja-JP' ; DecimalID = '1041'}
@{ Region = 'Korean (Korea)' ; Tag = 'ko-KR' ; DecimalID = '1042'}
@{ Region = 'Latvian (Latvia)' ; Tag = 'lv-LV' ; DecimalID = '1062'}
@{ Region = 'Lithuanian (Lithuania)' ; Tag = 'lt-LT' ; DecimalID = '1063'}
@{ Region = 'Norwegian, Bokmål (Norway)' ; Tag = 'nb-NO' ; DecimalID = '1044'}
@{ Region = 'Polish (Poland)' ; Tag = 'pl-PL' ; DecimalID = '1045'}
@{ Region = 'Portuguese (Brazil)' ; Tag = 'pt-BR' ; DecimalID = '1046'}
@{ Region = 'Portuguese (Portugal)' ; Tag = 'pt-PT' ; DecimalID = '2070'}
@{ Region = 'Romanian (Romania)' ; Tag = 'ro-RO' ; DecimalID = '1048'}
@{ Region = 'Russian (Russia)' ; Tag = 'ru-RU' ; DecimalID = '1049'}
@{ Region = 'Serbian (Latin, Serbia)' ; Tag = 'sr-Latn-CS' ; DecimalID = '2074'}
@{ Region = 'Serbian (Latin, Serbia)' ; Tag = 'sr-Latn-RS' ; DecimalID = '9242'}
@{ Region = 'Slovak (Slovakia)' ; Tag = 'sk-SK' ; DecimalID = '1051'}
@{ Region = 'Slovenian (Slovenia)' ; Tag = 'sl-SI' ; DecimalID = '1060'}
@{ Region = 'Spanish (Mexico)' ; Tag = 'es-MX' ; DecimalID = '2058'}
@{ Region = 'Spanish (Spain)' ; Tag = 'es-ES' ; DecimalID = '3082'}
@{ Region = 'Swedish (Sweden)' ; Tag = 'sv-SE' ; DecimalID = '1053'}
@{ Region = 'Thai (Thailand)' ; Tag = 'th-TH' ; DecimalID = '1054'}
@{ Region = 'Turkish (Turkey)' ; Tag = 'tr-TR' ; DecimalID = '1055'}
@{ Region = 'Ukrainian (Ukraine)' ; Tag = 'uk-UA' ; DecimalID = '1058'}

)
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

#Create excel COM object
$excel = New-Object -ComObject excel.application

#Make Visible
$excel.Visible = $True

# Add a workbook
$workbook = $excel.Workbooks.Add()


$BootImages = Get-CMBootImage
foreach($BootImage in $BootImages)#{}
    {
    $row = 1
    $Column = 1
    $TSSheet = $workbook.worksheets.add()
    $TSSheet.Name = $BootImage.PackageID
    $TSSheet.Activate() | Out-Null

    $Name = $BootImage.Name
    $PackageID = $BootImage.PackageID
    New-RowItem -row $row -Column 1 -FontAlignment Left -FontSize 16 -Content "Bootimage Info: $name | $PackageID"
    #if ($BootImage.ReferencedDrivers){$Drivers = $BootImage.ReferencedDrivers}
    [XML]$ImageProperty = $BootImage.ImageProperty
    $LangText = ($ImageProperty.WIM.IMAGE.Property | Where-Object {$_.Name -eq "Language"}).'#text'
    $LangCode = ($LangTable | Where-Object {$_.Tag -eq $LangText}).DecimalID
    
    if ($BootImage.OptionalComponents)
        {
        $row++
        New-RowItem -row $row -Column 1 -FontAlignment Left -FontSize 14 -Content "Additional Components"
        foreach($Component in $BootImage.OptionalComponents)
            {
            $row++
            $ComponentName = (Get-CMWinPEOptionalComponentInfo -UniqueId $Component | Where-Object {$_.LanguageID -eq $LangCode}).Name
            New-RowItem -row $row -Column 2 -FontAlignment Left -FontSize 12 -Content $ComponentName
            }
        }
    $row++
    if ($BootImage.ReferencedDrivers)
        {
        New-RowItem -row $row -Column 1 -FontAlignment Left -FontSize 14 -Content "Drivers"
        # Create columns
        $ColumnNames = @("Name","INF", "Version", "Path")
        $Column = 2
        $row ++
        foreach ($ColumnName in $ColumnNames)#{}
            {
            New-RowItem -row $row -Column $Column -FontSize 14 -FontAlignment Left -Content $ColumnName
            $Column++
            }
        foreach ($Driver in $BootImage.ReferencedDrivers)
            {
            $DriverInfo = Get-CMDriver -Id $Driver.ID
            $Column = 2
            $row++
            New-RowItem -row $row -Column $Column -FontAlignment Left -FontSize 12 -Content $DriverInfo.LocalizedDisplayName
            $Column++
            New-RowItem -row $row -Column $Column -FontAlignment Left -FontSize 12 -Content $DriverInfo.DriverINFFile
            $Column++
            New-RowItem -row $row -Column $Column -FontAlignment Left -FontSize 12 -Content $DriverInfo.DriverVersion
            $Column++
            New-RowItem -row $row -Column $Column -FontAlignment Left -FontSize 12 -Content $DriverInfo.ContentSourcePath

            }
        }
    $row++
    New-RowItem -row $row -Column 1 -FontAlignment Left -FontSize 14 -Content "General Info"
    $row++
    $BootImage = $BootImage | Select-Object -Property * -ExcludeProperty SecuredScopeNames, OptionalComponents, ImageProperty, ExtendedData, SmsProviderObjectPath, NamedValueDictionary, properties, ConnectionManager, PropertyList, EmbeddedProperties, EmbeddedPropertyLists, ManagedObject, ReferencedDrivers, OverridingObjectClass, RegMultiStringLists, MethodList, ObjectClass, PropertyNames



    $BootImage.PSObject.Properties | ForEach-Object {
        if ($_.Value)
            {
            $row++
            New-RowItem -row $row -Column 2 -FontAlignment Left -FontSize 12 -Content ($_.Name).trim()
            New-RowItem -row $row -Column 3 -FontAlignment Left -FontSize 12 -Content ($_.Value)
            }
        }
    $row++
    $row++
    $TSsheet.columns.Item('A').EntireColumn.Columnwidth = 5
    $TSsheet.columns.Item('B').EntireColumn.Columnwidth = 40
    $TSsheet.columns.Item('C').EntireColumn.Columnwidth = 30
    $TSsheet.columns.Item('D').EntireColumn.Columnwidth = 20
    $TSsheet.columns.Item('E').EntireColumn.Columnwidth = 130
    
    


    }
#Cleanup originally openned Sheet
$worksheet = $workbook.worksheets | where {$_.name -eq 'Sheet1'}
$worksheet.Delete()