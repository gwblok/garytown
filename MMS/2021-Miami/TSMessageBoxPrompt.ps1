#https://www.recastsoftware.com/resources/configmgr-docs/task-sequence-basics/task-sequence-com-object/
#https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/core/clients/client-classes/iprogressui--showmessageex-method
#https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-messagebox#return-value

$ReturnTable= @(

@{ ID = 'IDABORT'; Friendly = 'Abort' ; Description = "The Abort button was selected."; Code = 3}
@{ ID = 'IDCANCEL'; Friendly = 'Cancel' ; Description = "The Cancel button was selected."; Code = 2}
@{ ID = 'IDCONTINUE'; Friendly = 'Continue' ; Description = "The Continue button was selected."; Code = 11}
@{ ID = 'IDIGNORE'; Friendly = 'Ignore' ; Description = "The Ignore button was selected."; Code = 5}
@{ ID = 'IDNO'; Friendly = 'No' ; Description = "The No button was selected."; Code = 7}
@{ ID = 'IDOK'; Friendly = 'OK' ; Description = "The OK button was selected."; Code = 1}
@{ ID = 'IDRETRY'; Friendly = 'Retry' ; Description = "The Retry button was selected."; Code = 4}
@{ ID = 'IDTRYAGAIN'; Friendly = 'Try Again' ; Description = "The Try Again button was selected."; Code = 10}
@{ ID = 'IDYES'; Friendly = 'Yes' ; Description = "The Yes button was selected."; Code = 6}
)

$Message = "Are you going to fill out your survey?"
$Title = "Message Box"
$Type = 4
$Output = 0
#Connect to TS Progress UI
$TaskSequenceProgressUi = New-Object -ComObject "Microsoft.SMS.TSProgressUI"
#Close Progress Bar
$TaskSequenceProgressUi.CloseProgressDialog()  
#Trigger Message Dialog
$TaskSequenceProgressUi.ShowMessageEx($Message, $Title, $Type, [ref]$Output) 

If ($Output -eq 7) {
    $Message = "Lets try that again... are you going to fill out the survey?"
    
    do
        {
        $TaskSequenceProgressUi.ShowMessageEx($Message, $Title, $Type, [ref]$Output) 
        }
    while
        (
        $output -eq 7
        )
    }
$TSEnv = New-Object -ComObject "Microsoft.SMS.TSEnvironment"
$Button = ($ReturnTable | Where-Object {$_.code -eq $Output}).Friendly

$TSEnv.Value("TS-UserPressedButton") = $Button

Write-Output "User chose: $($TSEnv.Value("TS-UserPressedButton"))"



