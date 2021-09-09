<# @gwblok - https://garytown.com/waas-1909-ts-download
This script is meant to be used in the TS to set the variable RSAT_Installed to either TRUE or FALSE in a "Run PowerShell" Step
#>

$RSAT_FoD = Get-WindowsCapability -Online | Where-Object Name -like 'RSAT*'

Foreach ($RSAT_FoD_Item in $RSAT_FoD)

    {
    if ($RSAT_FoD_Item.State -eq "Installed")
        {
        $RSATInstalled = $TRUE
        }
    }

if ($RSATInstalled -eq $TRUE)
    {
    Write-Output "TRUE"
    }
else
    {
    Write-Output "FALSE"
    }
