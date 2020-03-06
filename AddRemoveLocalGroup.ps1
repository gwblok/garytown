#SDE Add User to Local Group 
#v2.3 2020.03.06 - Complete rewrite- switched from net localgroup to all powershell 
#v2.2 2019.09.13 - Added Option to Delete Account
#v2.1 2019.08.20 - Added Write-Ouput Statements 
#v2.0 2018.08.15
#Add Account to Local Admin Group Of Machine (Break Glass Alternative)

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)][string] $UserID,
    [Parameter(Mandatory=$false)][string] $LocalGroup = "administrators",
    [Parameter(Mandatory=$false)][string] $Domain = "viamonstra",
    [Parameter(Mandatory=$false)][ValidateSet("ADD","REMOVE")][string] $Action= "REMOVE"
      )

$User = Get-LocalGroupMember -Group $LocalGroup -Member "$($Domain)\$($UserID)" -ErrorAction SilentlyContinue

if ($Action -eq "REMOVE")
    {
    if ($User)
        {
        Remove-LocalGroupMember -Group $LocalGroup -Member "$($Domain)\$($UserID)"
        $User = Get-LocalGroupMember -Group $LocalGroup -Member "$($Domain)\$($UserID)" -ErrorAction SilentlyContinue
        if ($User){Write-Output "Failed to Remove User $UserID"}
        else {Write-Output "Successfully removed $UserID from $LocalGroup"}
        }
    else {Write-Output "User $UserID was not in group $LocalGroup"}
    }

if ($Action -eq "ADD")
    {
    if ($User)
        {
        Write-Output "User $UserID was already in group $LocalGroup"
        }
    else {
        Add-LocalGroupMember -Group $LocalGroup -Member "$($Domain)\$($UserID)" -ErrorAction SilentlyContinue
        $User = Get-LocalGroupMember -Group $LocalGroup -Member "$($Domain)\$($UserID)" -ErrorAction SilentlyContinue
        if ($User){Write-Output "Successfully Added $UserID to $LocalGroup"}
        else {Write-Output "Failed to Add $UserID to $LocalGroup "}
        } 
    }

