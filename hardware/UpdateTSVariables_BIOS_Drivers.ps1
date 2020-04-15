<# @gwblok 2020.04.15
Updates the CM Task Squence "Module" that maps Driver & BIOS Packs to Models that get downloaded and applied during IPU.
 - See: https://garytown.com/driver-pack-mapping-and-pre-cache

Assumptions: 
    CM Packages are created using this method: https://github.com/gwblok/garytown/blob/master/hardware/CreateCMPackages_BIOS_Drivers.ps1
    CM Packages for HP BIOS Populated with: https://github.com/gwblok/garytown/blob/master/hardware/HP_PopulateCMPackage.ps1
    CM Packages for Dell BIOS Populated with: https://github.com/gwblok/garytown/blob/master/hardware/Dell_PopulateCMPackage.ps1
    CM Packaegs for HP Drivers Polulated with: https://github.com/gwblok/garytown/blob/master/hardware/HPDriver_PopulateCMPackage.ps1
    CM Packaegs for Dell Drivers Polulated with: https://github.com/gwblok/garytown/blob/master/hardware/DellDriver_PopulateCMPackages.ps1

    TS Steps are named:
    Set Dell Driver Package Variables
    Set Dell BIOS Package Variables
    Set HP Driver Package Variables
    Set HP BIOS Package Variables

    This script grabs all Packages for each one of those items (HP BIOS/Drivers & Dell BIOS/Drivers) and updates the TS Steps

    If you're doing Pre-Prod & Prod Packages, you'll need to double this script and add some additional conditions, if you find yourself in this situation and are having trouble, hit me up.
#>

#Connect To Site
$SiteCode = "PS2"
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

#Get Sub Task Sequence which hosts the Dynamic Variable that maps the Driver & BIOS CM Packages
$VarTSPackID = "PS20006E"



#Grab All HP BIOS Packages
##________________________________________________________________________________________________________________

$HPModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "HP"}

#Grab TS To Update & The Dynamic Step for HPs
$BIOSVarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackID
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject | Where-Object {$_.Name -match "HP BIOS"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($HPModel in $HPModelsTable)
    {
    Write-Host "$($HPModel.Name)"
    $Name = $HPModel.MIFFilename
    $Product = $HPModel.Language
    $PackageID = $HPModel.PackageID
    $PackageName = $HPModel.Name
    $PackageBIOSVer = $HPModel.Version
    $TargetBiosDate = $HPModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("BIOSPACKAGE","$PackageID")
    $VarParams.Add("BIOSDATE","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PACKBIOSVER","$PackageBIOSVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "Product" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }


#Grab All HP Driver Packages
##________________________________________________________________________________________________________________

$HPModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "HP"}

#Grab TS To Update & The Dynamic Step for HPs
$BIOSVarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackID
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject | Where-Object {$_.Name -match "HP Driver"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($HPModel in $HPModelsTable)
    {
    Write-Host "$($HPModel.Name)"
    $Name = $HPModel.MIFFilename
    $Product = $HPModel.Language
    $PackageID = $HPModel.PackageID
    $PackageName = $HPModel.Name
    $DriverPackID = $HPModel.Version
    $TargetBiosDate = $HPModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("W10X64DRIVERPACKAGE","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("DriverPackID","$DriverPackID")
    $NewRule = New-CMTSRule -ReferencedVariableName "Product" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }


#Grab All Dell Driver Packages
##________________________________________________________________________________________________________________


$DellModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "Dell"}

#Grab TS To Update & The Dynamic Step for HPs
$BIOSVarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackID
$SetTSDynVarStepDell = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject | Where-Object {$_.Name -match "Dell Driver"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($DellModel in $DellModelsTable)
    {
    Write-Host "$($DellModel.Name)"
    $Name = $DellModel.MIFFilename
    $Product = $DellModel.Language
    $PackageID = $DellModel.PackageID
    $PackageName = $DellModel.Name
    $DriverPackID = $DellModel.Version
    $TargetBiosDate = $DellModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("W10X64DRIVERPACKAGE","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("DriverPackID","$DriverPackID")
    $NewRule = New-CMTSRule -ReferencedVariableName "Model" -ReferencedVariableOperator Equals -ReferencedVariableValue $Name  -Variable $VarParams
    if ($DellModel.Name -eq $DellModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepDell.Name) with $($DellModel.Name) Info" -ForegroundColor Green
    }



#Grab All Dell BIOS Packages
##________________________________________________________________________________________________________________


$DellModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "Dell"}

#Grab TS To Update & The Dynamic Step for HPs
$BIOSVarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackID
$SetTSDynVarStepDell = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject | Where-Object {$_.Name -match "Dell BIOS"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($DellModel in $DellModelsTable)
    {
    Write-Host "$($DellModel.Name)"
    $Name = $DellModel.MIFFilename
    $Product = $DellModel.Language
    $PackageID = $DellModel.PackageID
    $PackageName = $DellModel.Name
    $PackageBIOSVer = $DellModel.Version
    $TargetBiosDate = $DellModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("BIOSPACKAGE","$PackageID")
    $VarParams.Add("BIOSDATE","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PACKBIOSVER","$PackageBIOSVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "Model" -ReferencedVariableOperator Equals -ReferencedVariableValue $Name  -Variable $VarParams
    if ($DellModel.Name -eq $DellModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $BIOSVarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepDell.Name) with $($DellModel.Name) Info" -ForegroundColor Green
    }
