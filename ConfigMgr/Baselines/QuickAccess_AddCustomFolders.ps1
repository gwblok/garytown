<# Gary Blok @gwblok Recast SOftware
Add Folders Specific Quick Access Folders

!!!This MUST be run in user context!!! - Set the CI to: Run scripts by using the logged on user credentials
 (CI Settings -> Edit -> General Tab)
 
Place the folders you want into the $Folders variable.
I've set folders that I use all the time in my lab, like my CM Source location as example & CM Logs

Change the Variable for Dicovery or Remediation
Discovery = $Remediate = $false
Remediation = $Remediate = $True

#>


$Compliant = $true
$Remediate = $true

$Namespace = "shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}"
$QuickAccess = New-Object -ComObject shell.application
$RecentFiles = $QuickAccess.Namespace($Namespace).Items()

$Folders = @("\\src\src$","\\nas","C:\Windows\CCM\Logs")


foreach ($Folder in $Folders)
    {
    $SelectFolder = $RecentFiles | Where-Object {$_.Path -eq $Folder}
    if (!($SelectFolder)){
        $Compliant = $false
        }
    }

if ($Compliant -eq $false){
    if ($Remediate -eq $true){
        foreach ($Folder in $Folders)
            {
            Write-Output "Adding $Folder to Quick Access"
            $QuickAccess.Namespace($Folder).Self.InvokeVerb("pintohome")
            }
        }
    else
        {
        Write-Output "Non-Compliant"
        }
    }
else
    {
    Write-Output "Compliant"
    }
