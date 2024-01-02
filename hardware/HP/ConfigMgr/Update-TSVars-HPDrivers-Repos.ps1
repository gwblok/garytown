<# @gwblok 2020.04.15
Updates the CM Task Squence "Module" that maps Driver & BIOS Packs to Models that get downloaded and applied during IPU.
 - See: https://garytown.com/driver-pack-mapping-and-pre-cache

Assumptions: 
    Packages were created using the Scripts in my github

    TS Steps are named:
    Set HP Driver Package Variables
    Set HPIA Repo Package Variables
    Set HP BIOS Package Variables

    This script grabs all Packages for each one of those items (HP BIOS/Drivers & Dell BIOS/Drivers) and updates the TS Steps

    If you're doing Pre-Prod & Prod Packages, you'll need to double this script and add some additional conditions, if you find yourself in this situation and are having trouble, hit me up.
#>

#Connect To Site
$SiteCode = "MCM"
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

#Get Sub Task Sequence which hosts the Dynamic Variable that maps the Driver & BIOS CM Packages
$VarTSPackIDDrivers = "MEM0001B" #Module - Variables - Drivers
$VarTSPackIDBIOS = "MEM00040" #Module - Variables - BIOS
$VarTSHPRepoID = "MCM00239" #Module - Variables - HPIA Repo

#region HP BIOS

#Grab All HP BIOS Packages
##________________________________________________________________________________________________________________

$HPModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDBIOS -Fast
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set HP BIOS Package Variables - Prod"} 

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
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }

#Grab All HP BIOS Packages Pre-Prod
##________________________________________________________________________________________________________________

$HPModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDBIOS -Fast
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set HP BIOS Package Variables - Pre-Prod"} 

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
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }

#endregion

#region HP Driver Packs

#Grab All HP Driver Packages
##________________________________________________________________________________________________________________

$HPModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDDrivers -Fast
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set HP Driver Package Variables - Prod"} 

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
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("DriverPackID","$DriverPackID")
    $NewRule = New-CMTSRule -ReferencedVariableName "Product" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }


$HPModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDDrivers -Fast
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set HP Driver Package Variables - Pre-Prod"} 

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
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("DriverPackID","$DriverPackID")
    $NewRule = New-CMTSRule -ReferencedVariableName "Product" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }

#endregion

#region HP Image Assistant Offline Repo

#Grab All HP Image Assistant Repo Packages
##________________________________________________________________________________________________________________


#Production (PROD)
$HPModelsTable = Get-CMPackage -Fast -Name "HPIARepo*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSHPRepoID -Fast
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set HPIA Repo Package Variables - Prod"} 

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
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    #$VarParams.Add("DriverPackID","$DriverPackID")
    $NewRule = New-CMTSRule -ReferencedVariableName "Product" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }


#Pre-Production (Pre-PROD)
$HPModelsTable = Get-CMPackage -Fast -Name "HPIARepo*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSHPRepoID -Fast
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set HPIA Repo Package Variables - Pre-Prod"} 

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
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    #$VarParams.Add("DriverPackID","$DriverPackID")
    $NewRule = New-CMTSRule -ReferencedVariableName "Product" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }

#endregion
