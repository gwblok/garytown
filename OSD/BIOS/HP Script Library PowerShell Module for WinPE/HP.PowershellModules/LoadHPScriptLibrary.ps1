try
{
    $tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
}
catch
{
	Write-Verbose "Not running in a task sequence."
}

$PSPath = $env:PSModulePath.Split(";")
$PSPath = $PSPath | Where-Object {$_ -like "*:\Program Files\WindowsPowerShell*"}
$CopyDestination = $PSPath.Substring(0,$PSPath.Length-8)

Copy-Item ".\HP.PowershellModules\Modules" -Destination $CopyDestination -Recurse -Force
Copy-Item ".\HP.PowershellModules\Scripts" -Destination $CopyDestination -Recurse -Force

$tsenv.value('HPCMSL') = $true
