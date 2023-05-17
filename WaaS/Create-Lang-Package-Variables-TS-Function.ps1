<# @gwblok 2020.04.15
Updates the CM Task Squence "Module" that maps Language Pack Packages that get downloaded and applied during IPU.
Requires that Language Packs were created with specific information
When you run, you set the "Build" to the OS Release ID that you used when creating the packages, I'm using 20H2 in this script currently, you'll want to update that ($ReleaseID)
Requires that you have a TS already named "Module - Download Language Pack 20H2"
Requires that the TS has a Step Called "Set Language Variables"

If you download my WaaS TS Pack, it will be included

#>

#Connect To Site
$SiteCode = "PS2"
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

#Get Sub Task Sequence which hosts the Dynamic Variable that maps the Driver & BIOS CM Packages
#$VarTSPackID = "MEM00A01"

#This is the Module that has both Drivers & BIOS in one.

$TSNameLang = "Module - Download Language Pack 20H2"
$Stepname = "Set Language Variables"
$ReleaseID = "20H2"

Function Get-LanguagePackages {
    [cmdletbinding()]
    param ( [string] $Build)

    $Global:LanguagePackages = Get-CMPackage -Fast -Name "*Language Pack*" | Where-Object {$_.Version -eq $Build}
    #return $LanguagePackages
}


Function Get-TSStepName {
    [cmdletbinding()]
    param ( $TSObject, [string]$StepName)

    #$Global:SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $TSObject | Where-Object {$_.Name -match "Set $Manufacturer $Stage $Type Package Variables"} 
    $Global:SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $TSObject | Where-Object {$_.Name -match $StepName} 

    #Return $SetTSDynVarStep
}

Function Update-TSDynamicVars {
    [cmdletbinding()]
    param ( [string]$Build)
    Write-Host "$Build"

    $Global:TSObject = Get-CMTaskSequence -Name $TSNameLang | Where-Object {$_.name -match $build}
    Get-LanguagePackages -Build $build
    $Global:CMPackages = $LanguagePackages
    #write-host $CMPackages.Name
    #Write-Host $Type -ForegroundColor Magenta


    Get-TSStepName -TSObject $TSObject -StepName $Stepname
    
    foreach ($CMPackage in $CMPackages)#{Write-Host "$($CMPackage.Name)"}
    {
    Write-Host "$($CMPackage.Name)"
    
    
    #$Global:RefVariable = "SMSTS_WinSystemLocale"
    $Global:RefVariableValue = $CMPackage.Language
    $Global:RefVariable = "Lang_$($RefVariableValue)"
    #$Name = $CMPackage.MIFFilename
    #$Stage = $CMPackage.MIFName
    #$Product = $CMPackage.Language
    $Global:PackageID = $CMPackage.PackageID
    $Global:PackageName = $CMPackage.Name
    $Global:PackageVersion = $CMPackage.Version
    $Global:Info_LocName = $CMPackage.MIFName
    $Global:GeoID = $CMPackage.MIFPublisher
    $Global:KeyboardLocale = $CMPackage.description
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("GEOID","$GeoID")
    $VarParams.Add("KeyboardLocale","$KeyboardLocale")
    $VarParams.Add("W10X64LANGPACKAGE","$PackageID")
    $VarParams.Add("LANGPACKID_$($RefVariableValue)","$PackageID")
    $VarParams.Add("PRECACHELANG_$($RefVariableValue)001","$($PackageID):Pre-cache")
#    $Global:NewRule = New-CMTSRule -ReferencedVariableName $RefVariable -ReferencedVariableOperator Equals -ReferencedVariableValue $RefVariableValue  -Variable $VarParams
    $Global:NewRule = New-CMTSRule -ReferencedVariableName $RefVariable -ReferencedVariableOperator Exists -Variable $VarParams


    #Get First Model of Manufacture, which will let it know that it can clear the TS Step if first model, then add first model then append after.
    if ($CMPackages.Count -gt 1){$FirstCMPackageName = $CMPackages[0].Name}
    else {$FirstCMPackageName = $CMPackages.Name}
    if ($CMPackage.Name -eq $FirstCMPackageName) 
        {
        #Remove a previous rule for model if found
        Write-host " Clearing Step and Setting First Model" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $TSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
        } 
    else 
        {
        Write-host " Appending Language Info" -ForegroundColor yellow
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $TSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule
        
        }
    Write-host "Updated VarStep $($SetTSDynVarStep.Name) with $($CMPackage.Name) Info" -ForegroundColor Green
    
    }



}




#Set Language Packages Variables
Write-Host "Starting Update for Language Packs" -ForegroundColor Magenta
Update-TSDynamicVars -Build $ReleaseID
Write-Host "--------------------------------------" -ForegroundColor DarkMagenta
