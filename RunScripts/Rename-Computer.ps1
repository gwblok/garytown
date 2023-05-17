Param
    (
    [parameter(Mandatory=$true,ValueFromPipeline=$false)]
    [string]$NewName,

    [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
    [ValidateSet("TRUE","FALSE")]
    [string]$RebootNow = "FALSE"
      )


Rename-Computer -NewName $NewName -Force
if ($RebootNow -eq "TRUE"){Restart-Computer -Force}
