$Company = "GARYTOWN"


#region Create OUs

#Root OU (Company Name)
if (!(Get-ADOrganizationalUnit -Filter "Name -eq '$Company'")){
    Write-Host "Creating OU $Company" -ForegroundColor Green
    New-ADOrganizationalUnit -Name $Company
    }
else {Write-Host "OU $Company Already Exist" -ForegroundColor Yellow}
$RootOU = Get-ADOrganizationalUnit -Filter "Name -eq '$Company'"

$SubOUs = @(
@{Name = "Users & Groups"}
@{Name = "Workstations"}
@{Name = "Servers"}
)

ForEach ($OU in $SubOUs){
    $Name = $OU.Name
    if (!(Get-ADOrganizationalUnit -Filter "Name -eq '$Name'")){
        New-ADOrganizationalUnit -Name $Name
        Write-Host "Created OU $Name" -ForegroundColor Green
    }
    else {Write-Host "OU $Name Already Exist" -ForegroundColor Yellow}
    $WorkingOU = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'"
    Set-ADOrganizationalUnit -Identity $WorkingOU.DistinguishedName -ProtectedFromAccidentalDeletion:$false
    Move-ADObject -Identity $WorkingOU.DistinguishedName -TargetPath $RootOU.DistinguishedName

    New-Variable -Name "$($Name)OU" -Value (Get-ADOrganizationalUnit -Filter "Name -eq '$Name'") -Force
}


#endregion

#region Create Groups


$ADGroups = @(
@{Name = "CM Full Admins"; Description = "Full Administrators in ConfigMgr RBAC" }
@{Name = "SQL Admins"; Description = "Full Administrators in SQL"}
@{Name = "CM Servers"; Description = "Group of CM Servers"}
@{Name = "Local Admins Servers"; Description = "Group of Local Admins for Servers"}
@{Name = "Local Admins Workstations"; Description = "Group of Local Admins for Servers"}
@{Name = "CM App Deploy Users"; Description = "Group to Target Apps to in CM - Basically contains Domain Users"}
@{Name = "Certificate Admins"; Description = "Allows user sto enrool in the Web Server Certs"}
@{Name = "Web Server Cert Enrollment"; Description = "Group of CM Servers with IIS"}
#2Pint Groups:
@{Name = "StifleR Global Admins"; Description = "Full read and write right access to ALL objects"}
@{Name = "StifleR Dashboard Access"; Description = "Statistics, summary data etc. No WMI access  "}
@{Name = "StifleR Global Read"; Description = "Read Access on ALL locations. Must be member of Dashboard Access also "; Group = "StifleR Dashboard Access"}
)

$UsersGroupsOU = Get-ADOrganizationalUnit -Filter 'Name -eq "Users & Groups"'
ForEach ($ADGroup in $ADGroups){
    $Name = $ADGroup.Name
    $AddtoGroups = $ADGroup.Group
    if (!(Get-ADGroup -Filter "Name -eq '$Name'")){
        $Description = $ADGroup.Description
        New-ADGroup -Name $Name -Description $Description -GroupCategory Security -GroupScope Universal 
        $Group = Get-ADGroup -Identity $Name
        Move-ADObject -Identity $Group.DistinguishedName -TargetPath $UsersGroupsOU.DistinguishedName
        $Group = Get-ADGroup -Identity $Name
        Write-Host "Created Group $Name" -ForegroundColor Green
        if ($ADGroup.Group -ne $null){
            ForEach ($AddtoGroup in $AddtoGroups){
                $WorkingGroup = Get-ADGroup -Filter "Name -eq '$AddtoGroup'"
                Add-ADGroupMember -Identity $WorkingGroup.DistinguishedName -Members $Group.DistinguishedName
                Write-Host " Adding $Name to Group $AddtoGroup" -ForegroundColor DarkGray
            }
        }
    }
    else {Write-Host "Group $Name Already Exist" -ForegroundColor Yellow}
}

#endregion

#region Create Users
$ADUsers = @(
@{Name = "CMAdmin"; GivenName = "ConfigMgr"; Surname = "Admin" ; Description = "Full Administrator in ConfigMgr"; Group = @("CM Full Admins", "Certificate Admins") }
@{Name = "CM_SSRS"; GivenName = "SQL"; Surname = "Reporting Services" ; Description = "SSRS Account"; LogonWorkstations = "Null"; Group = "SQL Admins"}
@{Name = "CM_DJ"; GivenName = "ConfigMgr"; Surname = "Domain Join" ; Description = "Domain Join Account"}
@{Name = "CM_NA"; GivenName = "ConfigMgr"; Surname = "Network Access" ; Description = "Network Access Account"; LogonWorkstations = "Null"}
@{Name = "CM_CP_Servers"; GivenName = "ConfigMgr"; Surname = "ClientPush Servers" ; Description = "Client Push Servers"; Group = "Local Admins Servers"}
@{Name = "CM_CP_Workstations"; GivenName = "ConfigMgr"; Surname = "ClientPush Workstations" ; Description = "Client Push Workstations"; Group = "Local Admins Workstations"}

#SQL Accounts
@{Name = "SQLCMAgent"; GivenName = "SQL"; Surname = "CM Agent" ; Description = "SQL Agent in ConfigMgr Service Account"}
@{Name = "SQLCMSvc"; GivenName = "SQL"; Surname = "CM Service" ; Description = "SQL Service in ConfigMgr Service Account"}

#Test Accounts:
#@{Name = "Gary.Blok"; GivenName = "Gary"; Surname = "Blok" ; Description = "ME"; Group = @("Local Admins Workstations","Domain Admins", "CM Full Admins","CM App Deploy Users")}
#@{Name = "Mark.Godfrey"; GivenName = "Mark"; Surname = "Godfrey" ; Description = "Friend"; Group = @("Local Admins Workstations", "CM Full Admins","CM App Deploy Users")}
#@{Name = "David.Segura"; GivenName = "David"; Surname = "Segura" ; Description = "Friend"; Group = @("Local Admins Workstations","CM App Deploy Users")}
#@{Name = "Nathan.Ziehnert"; GivenName = "Nathan"; Surname = "Ziehnert" ; Description = "Friend"; Group = @("Domain Admins", "CM Full Admins","CM App Deploy Users")}
#@{Name = "Troy.Martin"; GivenName = "Troy"; Surname = "Martin" ; Description = "Friend"; Group = @("CM Full Admins","CM App Deploy Users")}
#@{Name = "Mike.Terrill"; GivenName = "Mike"; Surname = "Terrill" ; Description = "Friend"; Group = @("Local Admins Workstations","CM Full Admins","CM App Deploy Users")}
)

#Notes:  LogonWorkstation Null is set so those accounts can't be used to logon to any workstations.... unless you actually named a machine "Null"

$UsersGroupsOU = Get-ADOrganizationalUnit -Filter 'Name -eq "Users & Groups"'
$EmployeeNumber = 1000
ForEach ($ADUser in $ADUsers){
    $EmployeeNumber = $EmployeeNumber + 1
    $Name = $ADUser.Name
    $Groups = $ADUser.Group
    $Description = $ADUser.Description
    $Surname = $ADUser.Surname
    $GivenName = $ADUser.GivenName
    $LogonWorkstation = $AdUser.LogonWorkstations
    if (!(Get-ADUser -Filter "Name -eq '$Name'")){
        $Description = $ADUser.Description
        New-ADUser -Name $Name -Description $Description -PasswordNeverExpires:$true -AccountPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) -Enabled:$true -Company $Company -EmployeeNumber $EmployeeNumber -GivenName $GivenName -Surname $Surname -DisplayName "$GivenName $Surname" -UserPrincipalName $Name
        $User = Get-ADUser -Identity $Name
        Move-ADObject -Identity $User.DistinguishedName -TargetPath $UsersGroupsOU.DistinguishedName
        $User = Get-ADUser -Identity $Name
        ForEach ($Group in $Groups){
            $WorkingGroup = Get-ADGroup -Filter "Name -eq '$Group'"
            Add-ADGroupMember -Identity $WorkingGroup.DistinguishedName -Members $User.DistinguishedName
            Write-Host " Adding $Name to Group $Group" -ForegroundColor DarkGray
        }
        if ($LogonWorkstation){
        Set-ADUser -Identity $User.DistinguishedName -LogonWorkstations $LogonWorkstation
        Write-Host " Set LogonWorkstation to $LogonWorkstation" -ForegroundColor DarkCyan
        }
        Write-Host "Created User $Name" -ForegroundColor Green
        }
    else {Write-Host "User $Name Already Exist" -ForegroundColor Yellow}
}

#endregion

#region Domain Join Service Account - Add Rights to Workstation Collection.
$WorkstationsOU = Get-ADOrganizationalUnit -Filter 'Name -eq "Workstations"'
$OrganizationalUnit = $WorkstationsOU.DistinguishedName
$ServiceUserName = "CM_DJ"
Set-Location AD:
$Group = Get-ADuser -Identity $ServiceUserName
$GroupSID = [System.Security.Principal.SecurityIdentifier] $Group.SID
$ACL = Get-Acl -Path $OrganizationalUnit
$Identity = [System.Security.Principal.IdentityReference] $GroupSID
$Computers = [GUID]"bf967a86-0de6-11d0-a285-00aa003049e2"
$ResetPassword = [GUID]"00299570-246d-11d0-a768-00aa006e0529"
$ChangePassword = [GUID]"ab721a53-1e2f-11d0-9819-00aa0040529b"
$ValidatedDNSHostName = [GUID]"72e39547-7b18-11d1-adef-00c04fd8d5cd"
$ValidatedSPN = [GUID]"f3a64788-5306-11d1-a9c5-0000f80367c1"
$AccountRestrictions = [GUID]"4c164200-20c0-11d0-a768-00aa006e0529"
$RuleCreateAndDeleteComputer = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Identity, "CreateChild, DeleteChild, ListChildren, ReadProperty, ReadControl", "Allow", $Computers, "All")
$RuleResetPassword = New-Object System.DirectoryServices.ActiveDirectoryAccessRule ($Identity, "ExtendedRight", "Allow", $ResetPassword, "Descendents", $Computers)
$RuleChangePassword = New-Object System.DirectoryServices.ActiveDirectoryAccessRule ($Identity, "ExtendedRight", "Allow", $ChangePassword, "Descendents", $Computers)
$RuleValidatedDNSHostName = New-Object System.DirectoryServices.ActiveDirectoryAccessRule ($GroupSID, "Self", "Allow", $ValidatedDNSHostName, "Descendents", $Computers)
$RuleValidatedSPN = New-Object System.DirectoryServices.ActiveDirectoryAccessRule ($GroupSID, "Self", "Allow", $ValidatedSPN, "Descendents", $Computers)
$RuleAccountRestrictions = New-Object System.DirectoryServices.ActiveDirectoryAccessRule ($Identity, "ReadProperty, WriteProperty", "Allow", $AccountRestrictions, "Descendents", $Computers)
$ACL.AddAccessRule($RuleCreateAndDeleteComputer)
$ACL.AddAccessRule($RuleResetPassword)
$ACL.AddAccessRule($RuleChangePassword)
$ACL.AddAccessRule($RuleValidatedDNSHostName)
$ACL.AddAccessRule($RuleValidatedSPN)
$ACL.AddAccessRule($RuleAccountRestrictions)
Set-Acl -Path $OrganizationalUnit -AclObject $ACL

#endregion

#region Create GPOs
$GPOName = "All Servers"
if (!(Get-GPO -Name $GPOName)){
    New-GPO -Name $GPOName
    New-GPLink -Name $GPOName -Target $ServersOU.DistinguishedName
}
else {
    Write-Host "GPO $GPOName already Exist" -ForegroundColor Yellow
}

$GPOName = "ConfigMgr Servers"
if (!(Get-GPO -Name $GPOName)){
    New-GPO -Name $GPOName
    New-GPLink -Name $GPOName -Target $ServersOU.DistinguishedName
    Set-GPPermission -Name $GPOName -PermissionLevel GpoApply -TargetName "CM Servers" -TargetType Group
    Set-GPPermission -Name $GPOName -PermissionLevel GpoRead -TargetName "Authenticated Users" -TargetType Group -Replace
}
else {
    Write-Host "GPO $GPOName already Exist" -ForegroundColor Yellow
}

$GPOName = "Domain Machines"
if (!(Get-GPO -Name $GPOName)){
    $RootRootOU = $RootOU.DistinguishedName.Replace("OU=$company,","")
    New-GPO -Name $GPOName
    New-GPLink -Name $GPOName -Target $RootRootOU
    Set-GPPermission -Name $GPOName -PermissionLevel GpoRead -TargetName "Authenticated Users" -TargetType Group -Replace
    Set-GPPermission -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group
}
else {
    Write-Host "GPO $GPOName already Exist" -ForegroundColor Yellow
}

<#Building out GPOs... now Plan to Export, then ZIP, and allow others to import them to save time.. will be hosted on GitHub
Backup-GPO -Name "All Servers" -Path "c:\GPOBackups"
Backup-GPO -Name "ConfigMgr Servers" -Path "c:\GPOBackups"
Backup-GPO -Name "Domain Machines" -Path "c:\GPOBackups"

#>


#endregion
