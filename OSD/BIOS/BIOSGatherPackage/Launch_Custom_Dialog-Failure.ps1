$Script:TaskSequenceEnvironment = $null
$Script:TaskSequenceProgressUi = $null


#region TSEnvironment

function Confirm-TSEnvironmentSetup()
{
    <#
    .SYNOPSIS
    Verifies the TSEnvironment Com Object is initiated into an object.
    
    .DESCRIPTION
    Verifies the TSEnvironment Com Object is initiated into an object.

    .INPUTS
    None

    .OUTPUTS
    None
    
    .NOTE
    This module can be used statically to initiate the TSEnvironment module, however, simply running one of the commands will initate it for you.

    #>

    if ($Script:TaskSequenceEnvironment -eq $null)
    {
        try
        {
            $Script:TaskSequenceEnvironment = New-Object -ComObject Microsoft.SMS.TSEnvironment
        }
        catch
        {
            throw "Unable to connect to the Task Sequence Environment! Please verify you are in a running Task Sequence Environment.`n`nErrorDetails:`n$_"
        }
    }
}

function Get-TSVariables()
{
    <#
    .SYNOPSIS
    Get all Task Sequence Variable Names
    
    .DESCRIPTION
    Returns a string array of all Task Sequence Variable Names (not values).

    .INPUT
    None

    .OUTPUTS
    String[]

    .EXAMPLE
    $arrayOfVariableNames = Get-TSVariables

    #>
    Confirm-TSEnvironmentSetup

    $allVar = @()

    foreach ($variable in $Script:TaskSequenceEnvironment.GetVariables())
    {
        $allVar += $variable
    }

    return $allVar
}

function Get-TSValue()
{
    <#
    .SYNOPSIS
    Get a Task Sequence Variables Value
    
    .DESCRIPTION
    Obtains the value of a specific Task Sequence Variable.
    
    .PARAMETER Name
    Specifies the variable name to resolve.

    .INPUTS
    String

    .OUTPUTS
    String

    .EXAMPLE
    $OsdComputerName = Get-TSValue -Name "OSDComputerName"

    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name
    )

    Confirm-TSEnvironmentSetup

    return $Script:TaskSequenceEnvironment.Value($Name)
}

function Set-TSVariable()
{
    <#
    .SYNOPSIS
    Set or Create a Task Sequence Variables Value
    
    .DESCRIPTION
    Sets or Creates a Task Sequence Variables Value.
    Will return a boolean value indicating success or failure.
    
    .PARAMETER Name
    Specifies the variable name to set or create.

    .PARAMETER Value
    Specifies the variable value

    .INPUTS
     - Name: String
     - Value: System.Boolean

    .OUTPUTS
    System.Boolean

    .EXAMPLE
    Sets the OSDComputerName task sequence variable to "MyComputer123"
    $didSet = Set-TSVariable -Name "OSDComputerName" -Value "MyComputer123"

    .EXAMPLE
    Creates a new Task Sequence Variable, and sets its value
    $didSet = Set-TSVariable -Name "MyNewVar" -Value 'MyNewVarsValue"

    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $Name,
        [Parameter(Mandatory=$true)]
        [string] $Value
    )

    Confirm-TSEnvironmentSetup

    try
    {
        $Script:TaskSequenceEnvironment.Value($Name) = $Value
        return $true
    }
    catch
    {
        return $false
    }
}

function Get-TSAllValues()
{
    <#
    .SYNOPSIS
    Gets all Task Sequence Variables and Values
    
    .DESCRIPTION
    Gets all Task Sequence Variables with their associated values.

    .INPUTS
    None

    .OUTPUTS
    System.Object

    .EXAMPLE
    $TSVariableObject = Get-TSAllValues

    #>
    Confirm-TSEnvironmentSetup

    $Values = New-Object -TypeName System.Object

    foreach ($Variable in $Script:TaskSequenceEnvironment.GetVariables())
    {
        $Values | Add-Member -MemberType NoteProperty -Name $Variable -Value "$($Script:TaskSequenceEnvironment.Value($Variable))"
    }

    return $Values
}

#endregion

#region TSProgressUi

function Confirm-TSProgressUISetup()
{
    <#
    .SYNOPSIS
    Verifies the TSProgresUI Com Object is initiated into an object.
    
    .DESCRIPTION
    Verifies the TSProgresUI Com Object is initiated into an object.

    .INPUTS
    None

    .OUTPUTS
    None
    
    .NOTE
    This module can be used statically but is intended to be used by other functions.

    #>
    if ($Script:TaskSequenceProgressUi -eq $null)
    {
        try
        {
            $Script:TaskSequenceProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI
        }
        catch
        {
            throw "Unable to connect to the Task Sequence Progress UI! Please verify you are in a running Task Sequence Environment. Please note: TSProgressUI cannot be loaded during a prestart command.`n`nErrorDetails:`n$_"
        }
    }
}

function Show-TSErrorDialog()
{
<#
    .SYNOPSIS
    Shows the Task Sequence Error Dialog
    
    .DESCRIPTION
    Shows a task sequence error dialog allowing for custom failure pages.
    
    .PARAMETER OrganizationName
    Name of your Organization

    .PARAMETER CustomTitle
    Custom Error Title

    .PARAMETER ErrorMessage
    Message details of the error

    .PARAMETER ErrorCode
    Error Code the Task sequence will exit with

    .PARAMETER TimeoutInSeconds
    Timout for the Reboot Prompt

    .PARAMETER ForceReboot
    Indicates whether a reboot will be forced or not

    .INPUTS
     - OrganizationName: String
     - CustomTitle: String
     - ErrorMessage: String
     - ErrorCode: Long
     - TimeoutInSeconds: Long
     - ForceReboot: System.Boolean
     - TSStepName: String

    .OUTPUTS
    None

    .EXAMPLE
    Sets an Error but does not force a reboot
    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "That thing you tried...it didnt work" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $false
    
    .EXAMPLE
    Sets an Error and forces a reboot
    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "He's dead Jim!" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $true

    .EXAMPLE
    Adds TSStepName which is required for SCCM 1901 TP and newer
    Show-TSErrorDialog -OrganizationName "My Organization" -CustomTitle "An Error occured during the things" -ErrorMessage "That thing you tried...it didnt work" -ErrorCode 123456 -TimeoutInSeconds 90 -ForceReboot $false -TSStepName "My Step Name"
    
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $OrganizationName,
        [Parameter(Mandatory=$true)]
        [string] $CustomTitle,
        [Parameter(Mandatory=$true)]
        [string] $ErrorMessage,
        [Parameter(Mandatory=$true)]
        [long] $ErrorCode,
        [Parameter(Mandatory=$true)]
        [long] $TimeoutInSeconds,
        [Parameter(Mandatory=$true)]
        [bool] $ForceReboot,
        [Parameter()] #Required for SCCM 1901 Tech Preview and newer clients
        [string] $TSStepName
    )

    Confirm-TSProgressUISetup
    Confirm-TSEnvironmentSetup

    [int]$Reboot = Switch($ForceReboot) {
        $True {1}
        $False {0}
    }

    if([string]::IsNullOrEmpty($TSStepName)) {
        $Script:TaskSequenceProgressUi.ShowErrorDialog($OrganizationName, $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"), $CustomTitle, $ErrorMessage, $ErrorCode, $TimeoutInSeconds, $Reboot)
    }
    else {
        $Script:TaskSequenceProgressUi.ShowErrorDialog($OrganizationName, $Script:TaskSequenceEnvironment.Value("_SMSTSPackageName"), $CustomTitle, $ErrorMessage, $ErrorCode, $TimeoutInSeconds, $Reboot, $TSStepName)
    }
}


#endregion


#Run the Error Dialog
Confirm-TSEnvironmentSetup
$OrgName = $Script:TaskSequenceEnvironment.Value('_SMSTSOrgName')
$CustomTitle = $Script:TaskSequenceEnvironment.Value('_SMSTSPackageName')
$FailedStepName =  $Script:TaskSequenceEnvironment.Value('FailedStepName')
$FailedStepReturnCode =  $Script:TaskSequenceEnvironment.Value('FailedStepReturnCode')
$ErrorMessage = "An error occurred while running the BIOS Update Process. Please contact your Help Desk and provide the following information:`r`nFailed Step Name: $($FailedStepName) `r`nFailed Step ErrorCode: $($FailedStepReturnCode)"
$TSStepName = "Error Dialog"
$TimeoutInSeconds = 600

#Note, only Error Message really matters, most of the other things don't actually show up, which is why they are embedded in the "Error Message" above.
Show-TSErrorDialog -OrganizationName $OrgName -CustomTitle $CustomTitle -ErrorMessage $ErrorMessage -ErrorCode $FailedStepReturnCode -TSStepName $TSStepName -TimeoutInSeconds $TimeoutInSeconds -ForceReboot 0
exit $FailedStepReturnCode
