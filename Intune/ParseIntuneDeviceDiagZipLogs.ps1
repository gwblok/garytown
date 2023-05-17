<#Script to Extract the Intune Device Diagnostic Logs then run Windows Update Log 

Gary Blok | @gwblok | GARYTOWN.COM
2022.06.16

Function taken from: https://techcommunity.microsoft.com/t5/intune-customer-success/intune-public-preview-windows-10-device-diagnostics/ba-p/2179712

WindowsUpdateLog.log will be in the Extracted Folder "expanded"

Several modifications because I've been getting different folder structures and files on the different Downloads I've been getting when collecting Logs from Intune.


To use, copy the ZIP files to a folder, then update the $DiagZipFilesPath
I created a folder called Diags in my Downloads directory, and used that, but do whatever tickles your fancy.

#>

#Path Zip Files are downloaded to: 
$DiagZipFilesPath = "$($env:USERPROFILE)\Downloads\Diags"

function Extract-DiagnosticLogZip{
param($DiagnosticArchiveZipPath) 
 
#region Formatting Choices 
$flatFileNameTemplate = '({0:D2}) {1} {2}' 
$maxLengthForInputTextPassedToOutput = 80 
#endregion 
 
#region Create Output Folders and Expand Zip 

#Create Expanded Folder
$diagnosticArchiveTempUnzippedPath = $DiagnosticArchiveZipPath + "_expanded" 
if(Test-Path $diagnosticArchiveTempUnzippedPath){Remove-Item $diagnosticArchiveTempUnzippedPath -Force -Recurse}
Start-Sleep -Seconds 1 
if(-not (Test-Path $diagnosticArchiveTempUnzippedPath)){mkdir $diagnosticArchiveTempUnzippedPath} 
Expand-Archive -Path $DiagnosticArchiveZipPath -DestinationPath $diagnosticArchiveTempUnzippedPath -Force

$Items = Get-ChildItem -Path $diagnosticArchiveTempUnzippedPath
if ($Items | where-object {$_.Name -Like "(?)*"}){}
else {

    #Create "Formatted Structure"
    $reformattedArchivePath = $DiagnosticArchiveZipPath + "_formatted" 
    if(Test-Path $reformattedArchivePath){Remove-Item $reformattedArchivePath -Force -Recurse}
    Start-Sleep -Seconds 1 
    if(-not (Test-Path $reformattedArchivePath)){mkdir $reformattedArchivePath} 

    #endregion 
 
    #region Discover and Move/rename Files 
    $resultElements = ([xml](Get-Content -Path (Join-Path -Path $diagnosticArchiveTempUnzippedPath -ChildPath "results.xml"))).Collection.ChildNodes | Foreach-Object{ $_ } 
    $n = 1 
 
    # only process supported directives 
    $supportedDirectives = @('Command', 'Events', 'FoldersFiles', 'RegistryKey') 
    foreach( $element in $resultElements) { 
      # only process supported directives, skip unsupported ones 
      if(!$supportedDirectives.Contains($element.Name)) { continue } 
 
      $directiveNumber = $n 
      $n++ 
      $directiveType = $element.Name 
      $directiveStatus = [int]$element.Attributes.ItemOf('HRESULT').psbase.Value 
      $directiveUserInputRaw = $element.InnerText 
 
      # trim the path to only include the actual command - not the full path 
      if ($element.Name -eq 'Command') { 
        $lastIndexOfSlash = $directiveUserInputRaw.LastIndexOf('\'); 
        $directiveUserInputRaw = $directiveUserInputRaw.substring($lastIndexOfSlash+1); 
      } 
 
      $directiveUserInputFileNameCompatible = $directiveUserInputRaw -replace '[\\|/\[\]<>\:"\?\*%\.\s]','_' 
      $directiveUserInputTrimmed = $directiveUserInputFileNameCompatible.substring(0, [System.Math]::Min($maxLengthForInputTextPassedToOutput, $directiveUserInputFileNameCompatible.Length)) 
      $directiveSummaryString = $flatFileNameTemplate -f $directiveNumber,$directiveType,$directiveUserInputTrimmed 
      $directiveOutputFolder = Join-Path -Path $diagnosticArchiveTempUnzippedPath -ChildPath $directiveNumber 
      $directiveOutputFiles = Get-ChildItem -Path $directiveOutputFolder -File 
      foreach( $file in $directiveOutputFiles) { 
        $leafSummaryString = $directiveSummaryString,$file.Name -join ' ' 
        Copy-Item $file.FullName -Destination (Join-Path -Path $reformattedArchivePath -ChildPath $leafSummaryString) 
      } 
    } 
    #endregion  
    #Remove-Item -Path $diagnosticArchiveTempUnzippedPath -Force -Recurse
    }
return (Join-Path -Path $reformattedArchivePath -ChildPath $leafSummaryString)
}

#Prompt for Zip File to Extract & Run Commands:
$ZipFile = Get-ChildItem -Path $DiagZipFilesPath | where-Object {$_.Attributes -eq "Archive"} | Out-GridView -PassThru

#Run Extract Function
$ExtractPath = Extract-DiagnosticLogZip -DiagnosticArchiveZipPath $ZipFile.FullName

#Get Extracted Folder | Non-Modified Version
$ExtractFolder = $ExtractPath | Where-Object {$_.name -match "expanded"}
$WindowsLogFolder = get-childitem -Path $ExtractFolder | Where-Object {$_.name -Match "54"}


#Run Command to compile Log, places it in the extract folder
Get-WindowsUpdateLog -ETLPath $WindowsLogFolder.FullName -LogPath "$($ExtractFolder)\WindowsUpdateLog.Log"

