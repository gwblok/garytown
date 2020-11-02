<# @GWBLOK - GARYTOWN - RECAST SOFTWARE ConfigMgr Docs
Sample Script during OSD For Launching Button

This script you can use during OSD to leverage the native Message Box, MS DOCS:
https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/clients/client-classes/iprogressui--showmessageex-method

You need to provide:
Type, Title, Message, and the Variable Name you want the Output to go to.
Examples:

-ButtonType '4' -Title 'Message Box' -Message 'You like this Message Box' -TSVarName 'UserLikeBox'

Check out Samples online here: https://docs.recastsoftware.com/ConfigMgr-Docs/TaskSequence/TSComObject.html


The value corresponding to one of the following possible values for the buttons:

0 - Ok
1 - Ok/Cancel
2 - Abort/Retry/Ignore
3 - Yes/No/Cancel
4 - Yes/No
5 - Retry/Cancel
6 - Cancel/Try Again/Continue


Returns
1 = OK
2 = Cancel
4 = Retry
6 = YES
7 = NO
10 = Try Again
11 = Continue
#>

[CmdletBinding()]
Param(
[Parameter(Mandatory=$true,Position=1,HelpMessage="Button Type")]
[ValidateNotNullOrEmpty()]
[ValidateSet("0", "1", "2", "3", "4", "5", "6")]
[int]$ButtonType,
 
[Parameter(Mandatory=$true,Position=2,HelpMessage="Title")]
[ValidateNotNullOrEmpty()]
[string]$Title,

[Parameter(Mandatory=$true,Position=3,HelpMessage="Message")]
[ValidateNotNullOrEmpty()]
[string]$Message,

[Parameter(Mandatory=$true,Position=3,HelpMessage="TS Variable Output Name")]
[ValidateNotNullOrEmpty()]
[string]$TSVarName
)

$ButtonTypeValuesTable= @(

@{ "0" = 'OK'}
@{ "1" = 'Ok/Cancel'}
@{ "2" = 'Abort/Retry/Ignore'}
@{ "3" = 'Yes/No/Cancel'}
@{ "4" = 'Yes/No'}
@{ "5" = 'Retry/Cancel'}
@{ "6" = 'Cancel/Try Again/Continue'}
)


$ButtonValuesTable = @(

@{ "1" = 'OK'}
@{ "2" = 'Cancel'}
@{ "4" = 'Retry'}
@{ "6" = 'Yes'}
@{ "7" = 'No'}
@{ "10" = 'Try Again'}
@{ "11" = 'Continue'}
)



if (!($Message)){$Message = "Can you see this message?"}
if (!($Title)){$Title = "Contoso IT"}
$Type = $ButtonType
$Output = 0

$TaskSequenceProgressUi = New-Object -ComObject "Microsoft.SMS.TSProgressUI" #Connect to TS Progress UI
$TaskSequenceProgressUi.CloseProgressDialog() #Close Progress Bar

$TaskSequenceProgressUi.ShowMessageEx($Message, $Title, $Type, [ref]$Output) #Trigger Message Dialog
 
$TSEnv = New-Object -ComObject "Microsoft.SMS.TSEnvironment"  #Connect to TS Environment
$FriendlyOutput = $ButtonValuesTable.$Output

Write-Output ----------------------------------------
Write-Output "Leveraging TS Show Message Ex"
Write-Output "https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/clients/client-classes/iprogressui--showmessageex-method"
Write-Output "Button Type = $($ButtonTypeValuesTable.$ButtonType)"
Write-Output "Title: $Title"
Write-Output "Message: $Message"
Write-Output "User Responce: $FriendlyOutput"
Write-Output "Setting TS Var $TSVarName to $FriendlyOutput"
Write-Output ----------------------------------------

$TSEnv.Value("$TSVarName") = $FriendlyOutput

