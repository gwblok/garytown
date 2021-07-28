<# Gary Blok @gwblok Recast Software
This script will get the VMs on a HyperV host based on critera then shut down the VM and optimize the attached VHDx File.

There is also a script block that can be set to run on the VM while it's still online to clear up space on the VM itself.  This only works if DNS is properly working, which in my lab it isn't, but this worked great at work.

21.07.27
#>

$RemoteScript = 
{  
Clear-BCCache -Force
$CMObject = New-Object -ComObject 'UIResource.UIResourceMgr' 
 
# Using GetCacheInfo method to return cache properties 
$CMCacheObjects = $CMObject.GetCacheInfo() 
 
# Delete Cache item 
$CMCacheObjects.GetCacheElements() | ForEach-Object { 
    $CMCacheObjects.DeleteCacheElement($_.CacheElementID)
    }   

}
$VMs = Get-VM | Where-Object {$_.State -eq "Running" -and $_.Name -notmatch "Server"}
$VMNetNames = @()
Foreach ($VM in $VMs)#{}
    {
    $IPAddress = (Get-VM -Name "$($VM.Name)" | Select -ExpandProperty networkadapters).IPAddresses | Select-Object -First 1
    if (Get-VMSnapshot -VMName $VM.Name){
        Write-Host "$($VM.Name) has SnapShots, remove first then re-run" -ForegroundColor Yellow
        }
    else
        {
        Write-Host "$($VM.Name) | $IPAddress" -ForegroundColor Magenta
        <#
        #DNS isn't working right in my lab, this isn't working to get the hostname.
        If it was working, then it would grab the hostname based on the IP Address and invoke a PowerShell Script ($RemoteScript) which you can use to do some cleanup.

        $VMNetName = [System.Net.Dns]::GetHostByAddress($IPAddress).Hostname
        Write-Host "$($VM.Name) = $VMNetName | $IPAddress" -ForegroundColor Magenta
        $VMNetNames += $VMNetName | Where-Object {$_ -notmatch "ent.wfb.bank.qa"}
        Invoke-Command -ScriptBlock $RemoteScript -ComputerName $VMNetName -ErrorAction Stop
        #>
        
        #Get The VMs and Stop them so you can Optimize the VHDx files     
        $VHDXPaths = $VM.HardDrives.path | Where-Object {$VM.HardDrives.DiskNumber -eq $null}
        if ($VHDXPaths){
            Get-VM -Name $VM.Name | Stop-VM -Force
            ForEach ($VHDXPath in $VHDXPaths)
                {
                $SizeBefore = (Get-Item -Path $VHDXPath).length
                Write-Host " Size of $((Get-Item -Path $VHDXPath).Name) = $($SizeBefore/1GB) GB" -ForegroundColor Green
                Write-Host " Optimzing VHD $VHDXPath on $($VM.Name)" -ForegroundColor Green
                Optimize-VHD -Path $VHDXPath -Mode Full
                $SizeAfter = (Get-Item -Path $VHDXPath).length
                $Diff = $SizeBefore - $SizeAfter
                Write-Host " Size After: $($SizeAfter/1GB) GB | Saving $($Diff /1GB) GB" -ForegroundColor Green
                }
            Get-VM -Name $VM.Name | Start-VM
            }
        else{ Write-Host "$($VM.Name) Has no associated VHDx Files" -ForegroundColor Yellow
            }
        }
    }
