<# @gwblok 2024.04.15

Assumptions: 
    You created the Packages with the script I showed in the post

    This script grabs all Packages of the HP Offline Repos and update the Step with the proper information
    
    Make sure you update the VARTSRepoID with the Task Sequence ID of your TS.
    
    Note that step names in the TS need to aling with the function.
    StepName = "Set $Manufacturer $Type Package Variables - $Stage"
    Ex: Set HP OfflineRepo Package Variables - Dev
  #>

#Connect To Site
$SiteCode = "MCM"
Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
Set-Location -Path "$($SiteCode):"


$VarTSRepoID = "MCM003F0"

$MyManufacturers = @("HP")
$MyStages = @("Dev", "Prod")

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
        [ValidateSet("Dev","Prod")]
        [string]$Stage,

        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("BIOS","DriverPack","UpdateRepo")]
        [string]$ContentType
      )

    Switch ($ContentType){
        "UpdateRepo" {$type = "OfflineRepo"}
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
        #Offline Repo Packages
        Update-VariableTS -TSPackageID $VarTSRepoID -Manufacturer $MyManufacturer -Stage $MyStage -ContentType UpdateRepo
    }
}


