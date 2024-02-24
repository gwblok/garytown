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
$SiteCode = "MCM"
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"

#Get Sub Task Sequence which hosts the Dynamic Variable that maps the Driver & BIOS CM Packages
$VarTSPackIDDrivers = "MEM0001B"
$VarTSPackIDBIOS = "MEM00040"
$VarTSRepoID = "MCM00239"

$MyManufacturers = @("Dell","Lenovo","Microsoft","HP")
$MyStages = @("Pre-Prod", "Prod")

function Update-VariableTS {
    [CmdletBinding()]
    Param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$TSPackageID,
        
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("Dell","Lenovo","Microsoft","HP","Intel")]
        [string]$Manufacturer,
        
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("Pre-Prod","Prod")]
        [string]$Stage,

        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("BIOS","DriverPack","UpdateRepo")]
        [string]$ContentType
      )

    Switch ($ContentType){
        "BIOS" {$type = "BIOS"}
        "DriverPack" {$type = "Driver"}
        "UpdateRepo" {$type = "Repo"}
    }
    $StepName = "Set $Manufacturer $Type Package Variables - $Stage"
    $VarTSObject = $null
    $VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $TSPackageID -Fast
    if ($VarTSObject){
        $SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "$StepName"}
        if ($SetTSDynVarStep){
            $DeviceTable = Get-CMPackage -Fast -Name "$($type)*" | Where-Object {$_.Manufacturer -eq $Manufacturer -and $_.MifName -eq $Stage}
            if ($DeviceTable){
                foreach ($Device in $DeviceTable){
                    Write-host -ForegroundColor Cyan "Starting: $($Device.Name)"
                    $ModelName = $Device.MIFFilename
                    $UniqueID = $Device.Language
                    $PackageID = $Device.PackageID
                    $PackageName = $Device.Name
                    $Version = $Device.Version
                    $Date = $Device.MIFVersion
                    $VarParams = $null
                    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
                    $VarParams.Add("$($Type)_ID","$PackageID")
                    $VarParams.Add("$($Type)_Date","$Date")
                    $VarParams.Add("$($Type)_Ver","$Version")
                    $VarParams.Add("MyName","$ModelName")
                    #$VarParams.Add("UniqueID","$UniqueID")
                    $NewRule = New-CMTSRule -ReferencedVariableName "UniqueID" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
                    if ($DeviceTable.Count -eq 1){
                        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
                        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
                    }
                    elseif ($Device.Name -eq $DeviceTable[0].Name) {
                        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
                        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
                        } 
                    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
                    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Device.Name) Info" -ForegroundColor Green

                }
            }
            else{
                Write-Host "No Packages Match your criteria: $Manufacturer, $type, $Stage" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Failed to find Task Sequence step matching: $StepName" -ForegroundColor Red
            Write-Host "  To resolve, copy another step in that TS and rename to: $StepName" -ForegroundColor Yellow
            Write-Host "  Also remember to update the conditions on that step for the proper OEM: $Manufacturer" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "Failed to find Task Sequence with PackageID: $TSPackageID" -ForegroundColor Red
    }
}


foreach ($MyManufacturer in $MyManufacturers){
    foreach ($MyStage in $MyStages){
        #BIOS Packages
        Update-VariableTS -TSPackageID $VarTSPackIDBIOS -Manufacturer $MyManufacturer -Stage $MyStage -ContentType BIOS
        #DriverPack Packages
        Update-VariableTS -TSPackageID $VarTSPackIDDrivers -Manufacturer $MyManufacturer -Stage $MyStage -ContentType DriverPack
        #Offline Repo Packages
        Update-VariableTS -TSPackageID $VarTSRepoID -Manufacturer $MyManufacturer -Stage $MyStage -ContentType UpdateRepo
    }
}

#Update-VariableTS -TSPackageID $VarTSPackIDDrivers -Manufacturer Dell -Stage Pre-Prod -ContentType DriverPack
#Update-VariableTS -TSPackageID $VarTSRepoID -Manufacturer Intel -Stage Pre-Prod -ContentType OfflineRepo



<# OLD

#region HP BIOS

#Grab All HP BIOS Packages
##_____________________________________________________________________________________t___________________________

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
    $VarParams.Add("UniqueID","$Product")
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
    $VarParams.Add("UniqueID","$Product")
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
    $PackVer = $HPModel.Version
    $TargetBiosDate = $HPModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PackVer","$PackVer")
    $VarParams.Add("UniqueID","$Product")
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
    $PackVer = $HPModel.Version
    $TargetBiosDate = $HPModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PackVer","$PackVer")
    $VarParams.Add("UniqueID","$Product")
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
$HPModelsTable = Get-CMPackage -Fast -Name "UpdateRepo*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSRepoID -Fast
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set HPIA Repo Package Variables - Prod"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($HPModel in $HPModelsTable)
    {
    Write-Host "$($HPModel.Name)"
    $Name = $HPModel.MIFFilename
    $Product = $HPModel.Language
    $PackageID = $HPModel.PackageID
    $PackageName = $HPModel.Name
    $PackVer = $HPModel.Version
    $TargetBiosDate = $HPModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("RepoID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "Product" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }


#Pre-Production (Pre-PROD)
$HPModelsTable = Get-CMPackage -Fast -Name "UpdateRepo*" | Where-Object {$_.Manufacturer -eq "HP" -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSRepoID -Fast
$SetTSDynVarStepHP = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set HPIA Repo Package Variables - Pre-Prod"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($HPModel in $HPModelsTable)
    {
    Write-Host "$($HPModel.Name)"
    $Name = $HPModel.MIFFilename
    $Product = $HPModel.Language
    $PackageID = $HPModel.PackageID
    $PackageName = $HPModel.Name
    $PackVer = $HPModel.Version
    $TargetBiosDate = $HPModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("RepoID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "Product" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($HPModel.Name -eq $HPModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepHP.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepHP.Name) with $($HPModel.Name) Info" -ForegroundColor Green
    }

#endregion


#region other


#region Dell Drivers
#Grab All Dell Driver Packages
##________________________________________________________________________________________________________________
$DellModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.MifName -eq "Prod"}

$VarTSObject = $null
$SetTSDynVarStepDell = $null


#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDDrivers -Fast
$SetTSDynVarStepDell = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set Dell Driver Package Variables - Prod"} 

#Changed 24.02.10 to change from Model to SKU
#For Each, Update the Dynamic Var Step with HP Info
foreach ($DellModel in $DellModelsTable)
    {
    Write-Host "$($DellModel.Name)"
    $Name = $DellModel.MIFFilename
    $UniqueID = $DellModel.Language
    $PackageID = $DellModel.PackageID
    $PackageName = $DellModel.Name
    $PackVer = $DellModel.Version
    $TargetBiosDate = $DellModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PackVer","$PackVer")
    $VarParams.Add("UniqueID","$UniqueID")
    $NewRule = New-CMTSRule -ReferencedVariableName "SystemSKUNumber" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($DellModel.Name -eq $DellModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepDell.Name) with $($DellModel.Name) Info" -ForegroundColor Green
    }

$DellModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.MifName -eq "Pre-Prod"}


#Grab TS To Update & The Dynamic Step for HPs

$VarTSObject = $null
$SetTSDynVarStepDell = $null

$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDDrivers -Fast
$SetTSDynVarStepDell = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set Dell Driver Package Variables - Pre-Prod"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($DellModel in $DellModelsTable)
    {
    Write-Host "$($DellModel.Name)"
    $Name = $DellModel.MIFFilename
    $UniqueID = $DellModel.Language
    $PackageID = $DellModel.PackageID
    $PackageName = $DellModel.Name
    $PackVer = $DellModel.Version
    $TargetBiosDate = $DellModel.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PackVer","$PackVer")
    $VarParams.Add("UniqueID","$UniqueID")
    $NewRule = New-CMTSRule -ReferencedVariableName "SystemSKUNumber" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($DellModel.Name -eq $DellModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepDell.Name) with $($DellModel.Name) Info" -ForegroundColor Green
    }

#endregion Dell Drivers

#region Dell BIOS
#Grab All Dell BIOS Packages
##________________________________________________________________________________________________________________

$VarTSObject = $null
$SetTSDynVarStepDell = $null

$DellModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDBIOS -Fast
$SetTSDynVarStepDell = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set Dell BIOS Package Variables - Prod"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($DellModel in $DellModelsTable)
    {
    Write-Host "$($DellModel.Name)"
    $Name = $DellModel.MIFFilename
    $UniqueID = $DellModel.Language
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
    $VarParams.Add("UniqueID","$UniqueID")
    $NewRule = New-CMTSRule -ReferencedVariableName "SystemSKUNumber" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($DellModel.Name -eq $DellModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepDell.Name) with $($DellModel.Name) Info" -ForegroundColor Green
    }

#Grab All Dell BIOS Packages Pre-Prod
##________________________________________________________________________________________________________________

$VarTSObject = $null
$SetTSDynVarStepDell = $null

$DellModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "Dell" -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDBIOS -Fast
$SetTSDynVarStepDell = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set Dell BIOS Package Variables - Pre-Prod"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($DellModel in $DellModelsTable)
    {
    Write-Host "$($DellModel.Name)"
    $Name = $DellModel.MIFFilename
    $UniqueID = $DellModel.Language
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
    $VarParams.Add("UniqueID","$UniqueID")
    $NewRule = New-CMTSRule -ReferencedVariableName "SystemSKUNumber" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($DellModel.Name -eq $DellModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStepDell.Name) with $($DellModel.Name) Info" -ForegroundColor Green
    }

#endregion Dell BIOS


#region Dell Offline Repo

#Grab All Dell Repo Packages
##________________________________________________________________________________________________________________



#Production (PROD)
$Manufacturer = "Dell"
$ModelsTable = Get-CMPackage -Fast -Name "UpdateRepo*" | Where-Object {$_.Manufacturer -eq $Manufacturer -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = $null
$SetTSDynVarStep = $null
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSRepoID -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set $Manufacturer Repo Package Variables - Prod"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $Product = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackVer = $Model.Version
    $TargetBiosDate = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("RepoID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "SystemSKUNumber" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($Model.Name -eq $ModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }


#Pre-Production (Pre-PROD)
$Manufacturer = "Dell"
$ModelsTable = Get-CMPackage -Fast -Name "UpdateRepo*" | Where-Object {$_.Manufacturer -eq $Manufacturer -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = $null
$SetTSDynVarStep = $null
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSRepoID -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set $Manufacturer Repo Package Variables - Pre-Prod"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $Product = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackVer = $Model.Version
    $TargetBiosDate = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("RepoID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "SystemSKUNumber" -ReferencedVariableOperator Equals -ReferencedVariableValue $Product -Variable $VarParams
    if ($Model.Name -eq $ModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }

#endregion


#region Lenovo Drivers
#Grab All Lenovo Driver Packages
##________________________________________________________________________________________________________________

#Lenovo Driver Production
$VarTSObject = $null
$SetTSDynVarStep = $null

$Manufacturer = "Lenovo"
$ModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq $Manufacturer  -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for Lenovo
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDDrivers -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set $Manufacturer Driver Package Variables - Prod"} 

#For Each, Update the Dynamic Var Step with Lenovo Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $UniqueID = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackVer = $Model.Version
    $TargetBiosDate = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PackVer","$PackVer")
    $VarParams.Add("UniqueID","$UniqueID")
    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "LenovoID" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($ModelsTable.Count -eq 1){
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
    }
    elseif ($Model.Name -eq $ModelsTable[0].Name) {
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
        } 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }



#Lenovo Driver Pre-Prod
$VarTSObject = $null
$SetTSDynVarStep = $null

$Manufacturer = "Lenovo"
$ModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq $Manufacturer  -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for Lenovo
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDDrivers -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set $Manufacturer Driver Package Variables - Pre-Prod"} 

#For Each, Update the Dynamic Var Step with Lenovo Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $UniqueID = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackVer = $Model.Version
    $TargetBiosDate = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PackVer","$PackVer")
    $VarParams.Add("UniqueID","$UniqueID")
    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "LenovoID" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($ModelsTable.Count -eq 1){
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
    }
    elseif ($Model.Name -eq $ModelsTable[0].Name) {
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
        } 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }

#endregion
#Grab All Lenovo Offline Repo Packages
##________________________________________________________________________________________________________________

#Lenovo Driver Production
$VarTSObject = $null
$SetTSDynVarStep = $null

$Manufacturer = "Lenovo"
$ModelsTable = Get-CMPackage -Fast -Name "UpdateRepo*" | Where-Object {$_.Manufacturer -eq $Manufacturer  -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for Lenovo
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSRepoID -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set $Manufacturer Repo Package Variables - Prod"} 

#For Each, Update the Dynamic Var Step with Lenovo Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $UniqueID = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackVer = $Model.Version
    $Date = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("RepoID","$PackageID")
    $VarParams.Add("DriverDate","$Date")
    $VarParams.Add("ModelName","$Name")
    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "LenovoID" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($ModelsTable.Count -eq 1){
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
    }
    elseif ($Model.Name -eq $ModelsTable[0].Name) {
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
        } 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }



#Lenovo Driver Pre-Prod
$VarTSObject = $null
$SetTSDynVarStep = $null

$Manufacturer = "Lenovo"
$ModelsTable = Get-CMPackage -Fast -Name "UpdateRepo*" | Where-Object {$_.Manufacturer -eq $Manufacturer  -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for Lenovo
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSRepoID -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set $Manufacturer Repo Package Variables - Pre-Prod"} 

#For Each, Update the Dynamic Var Step with Lenovo Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $UniqueID = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackVer = $Model.Version
    $Date = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("RepoID","$PackageID")
    $VarParams.Add("DriverDate","$Date")
    $VarParams.Add("ModelName","$Name")

    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "LenovoID" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($ModelsTable.Count -eq 1){
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
    }
    elseif ($Model.Name -eq $ModelsTable[0].Name) {
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
        } 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }

#endregion
#region Lenovo BIOS
#Grab All Lenovo BIOS Packages
##________________________________________________________________________________________________________________

$VarTSObject = $null
$SetTSDynVarStep = $null

$ModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "Lenovo" -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDBIOS -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set Lenovo BIOS Package Variables - Prod"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $UniqueID = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackageBIOSVer = $Model.Version
    $TargetBiosDate = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("BIOSPACKAGE","$PackageID")
    $VarParams.Add("BIOSDATE","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PACKBIOSVER","$PackageBIOSVer")
    $VarParams.Add("UniqueID","$UniqueID")
    $NewRule = New-CMTSRule -ReferencedVariableName "LenovoID" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($ModelsTable.Count -eq 1){Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule -CleanRule} 
    elseif ($Model.Name -eq $ModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }

#Grab All Dell BIOS Packages Pre-Prod
##________________________________________________________________________________________________________________

$VarTSObject = $null
$SetTSDynVarStep = $null

$ModelsTable = Get-CMPackage -Fast -Name "BIOS*" | Where-Object {$_.Manufacturer -eq "Lenovo" -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for HPs
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDBIOS -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set Lenovo BIOS Package Variables - Pre-Prod"} 

#For Each, Update the Dynamic Var Step with HP Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $UniqueID = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackageBIOSVer = $Model.Version
    $TargetBiosDate = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("BIOSPACKAGE","$PackageID")
    $VarParams.Add("BIOSDATE","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PACKBIOSVER","$PackageBIOSVer")
    $VarParams.Add("UniqueID","$UniqueID")
    $NewRule = New-CMTSRule -ReferencedVariableName "LenovoID" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($ModelsTable.Count -eq 1){Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStepDell.Name -AddRule $NewRule -CleanRule} 
    elseif ($Model.Name -eq $ModelsTable[0].Name) {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule} 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }

#endregion Lenovo BIOS

#region Microsoft Drivers
#Grab All Microsoft Driver Packages
##________________________________________________________________________________________________________________

#Microsoft Driver Production
$VarTSObject = $null
$SetTSDynVarStep = $null

$Manufacturer = "Microsoft"
$ModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq $Manufacturer  -and $_.MifName -eq "Prod"}

#Grab TS To Update & The Dynamic Step for Lenovo
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDDrivers -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set $Manufacturer Driver Package Variables - Prod"} 

#For Each, Update the Dynamic Var Step with Lenovo Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $UniqueID = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackVer = $Model.Version
    $TargetBiosDate = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PackVer","$PackVer")
    $VarParams.Add("UniqueID","$UniqueID")
    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "SystemSKUNumber" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($ModelsTable.Count -eq 1){
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
    }
    elseif ($Model.Name -eq $ModelsTable[0].Name) {
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
        } 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }



#Microsoft Driver Pre-Prod
$VarTSObject = $null
$SetTSDynVarStep = $null
$ModelsTable = Get-CMPackage -Fast -Name "Driver*" | Where-Object {$_.Manufacturer -eq $Manufacturer  -and $_.MifName -eq "Pre-Prod"}

#Grab TS To Update & The Dynamic Step for Lenovo
$VarTSObject = Get-CMTaskSequence -TaskSequencePackageId $VarTSPackIDDrivers -Fast
$SetTSDynVarStep = Get-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject | Where-Object {$_.Name -match "Set $Manufacturer Driver Package Variables - Pre-Prod"} 

#For Each, Update the Dynamic Var Step with Lenovo Info
foreach ($Model in $ModelsTable)
    {
    Write-Host "$($Model.Name)"
    $Name = $Model.MIFFilename
    $UniqueID = $Model.Language
    $PackageID = $Model.PackageID
    $PackageName = $Model.Name
    $PackVer = $Model.Version
    $TargetBiosDate = $Model.MIFVersion
    $VarParams = $null
    $VarParams = New-Object 'System.Collections.Generic.Dictionary[String,object]'
    $VarParams.Add("PackID","$PackageID")
    $VarParams.Add("DriverDate","$TargetBiosDate")
    $VarParams.Add("ModelName","$Name")
    $VarParams.Add("PackVer","$PackVer")
    $VarParams.Add("UniqueID","$UniqueID")
    #$VarParams.Add("PackVer","$PackVer")
    $NewRule = New-CMTSRule -ReferencedVariableName "SystemSKUNumber" -ReferencedVariableOperator Equals -ReferencedVariableValue $UniqueID  -Variable $VarParams
    if ($ModelsTable.Count -eq 1){
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
    }
    elseif ($Model.Name -eq $ModelsTable[0].Name) {
        #Write-Host "Reseting Step for $($Model.Manufacturer) driver variables" -ForegroundColor Cyan
        Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule -CleanRule
        } 
    else {Set-CMTaskSequenceStepSetDynamicVariable -InputObject $VarTSObject -StepName $SetTSDynVarStep.Name -AddRule $NewRule}
    Write-host "Updating VarStep $($SetTSDynVarStep.Name) with $($Model.Name) Info" -ForegroundColor Green
    }

#endregion

#endregion

#>
