
$NetworkGroups = Get-CimInstance -Namespace root\stifler -Query "Select * From NetworkGroups" 

foreach ($ng in $NetworkGroups)
{
    $Result = Invoke-CimMethod -InputObject $ng -MethodName GetSupportServers -Arguments @{Filter = [int]0}
    if ('{}' -eq $Result.ReturnValue){
        # NO Servers Listed
    }
    else {
        Write-Host "Network Group $($ng.Name) | $($ng.id)" -ForegroundColor Cyan
        write-Host " Found Support Server: $($Result.ReturnValue)" -ForegroundColor Yellow
    }
}
