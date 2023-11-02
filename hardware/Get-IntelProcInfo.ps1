$Processor = (Get-CimInstance -ClassName Win32_Processor).Name
$ProcID = $Processor.Split(" ") | where-Object {$_ -match "-"}
$ProcBrand = $ProcID.Split("-")[0]
$ProcTemp = $ProcID.Split("-")[1]
$ProcSuffix = $ProcTemp.Substring($ProcSuffix.Length -1,1)
$ProcSKU = ($ProcTemp.Substring($ProcSuffix.Length -4,4)).SubString(0,3)
$ProcGen = $ProcTemp.Substring(0,$ProcSuffix.Length -4)
