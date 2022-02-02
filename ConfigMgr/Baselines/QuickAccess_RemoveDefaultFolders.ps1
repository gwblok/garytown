<# Gary Blok @gwblok Recast SOftware
Clears out Specific Quick Access Folders

!!!This MUST be run in user context!!! - Set the CI to: Run scripts by using the logged on user credentials
 (CI Settings -> Edit -> General Tab)

Place the folders you want removed into the $Folders variable.
My Defaults = Videos, Music, Pictures

Change the Variable for Dicovery or Remediation
Discovery = $Remediate = $false
Remediation = $Remediate = $True

#>


$Compliant = $true
$Remediate = $false

$Namespace = "shell:::{679f85cb-0220-4080-b29b-5540cc05aab6}"
$QuickAccess = New-Object -ComObject shell.application
$RecentFiles = $QuickAccess.Namespace($Namespace).Items()

$Folders = @("Videos", "Music", "Pictures")


foreach ($Folder in $Folders)
    {
    $SelectFolder = $RecentFiles | Where-Object {$_.Path -match $Folder}
    if ($SelectFolder){
        $Compliant = $false
        }
    }

if ($Compliant -eq $false){
    if ($Remediate -eq $true){
        foreach ($Folder in $Folders)
            {
            $SelectFolder = $RecentFiles | Where-Object {$_.Path -match $Folder}
            if ($SelectFolder){
                Write-Output "Removing $Folder from Quick Access"
                $SelectFolder.InvokeVerb("unpinfromhome")
                $SelectFolder.InvokeVerb("removefromhome")
                }
            else {
                Write-Output "$Folder does not exsit in Quick Access"
                }
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

   
