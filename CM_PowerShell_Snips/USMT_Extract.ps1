<
@gwblok @recastsoftware
#Requires the following files from the USMT Package in the amd64 folder

migcore.dll
migstore.dll
unbcl.dll
usmtutils.exe

Assumption is that you put those files on the machine you're using to extract the .MIG file in the folder c:\USMT\x64

More info: http://docs.recastsoftware.com/BlogDocs/TaskSequence/SCCM_TaskSequence_Step_UserState_ComboStep.html
#>


#This key is captured in the CM Console in the \Assets and Compliance\Overview\User State Migration -> User State Recovery Information
$Key = "k9jKO5dD8yz7giskT1sKXmrLwGvD+vxTC6VpKDDKRi+deB1Kcox+gqX7xcGaSXJH6KEYJuxiVnxYPwtKH/y2OxwVOGCT8TkTkGJj8+06+j6cIrKhvX/GptrMmdGLywrr+ycUWJG6vgHtFQthEKkYw5QgkykiepI1B9IG61lZyq6rHYHVOq2ilEiDxXm4rSyxcc6sBoRvfoe6Nfxhx0iPWemK4Vd/jHJH4OpkOtAd5KjsIvEIFuyjUmIxp9TBRen2"

#Copy the MIG File from the server location to a temp location, or set the location of the $DataFile to the file location on the Server
#$DataFile = "C:\USMT\USMT.MIG"
$DataFile = "\\CM.corp.viamonstra.com\SMPSTOREE_CE6C69CE$\7B7083AB42DE63FE3D17BD04F45520BCB534F521AE79F3C2262B4DDAD8625988\USMT\USMT.MIG"

#Temporary Place to extract the files so you can grab them
$ExtractPath = "$env:TEMP\USMTExtract"
if (Test-Path $ExtractPath)
    {
    Remove-Item -Path $ExtractPath -Recurse -Force
    $NewFolder = New-Item -Path $ExtractPath -ItemType Directory -Force
    }
else{$NewFolder = New-Item -Path $ExtractPath -ItemType Directory -Force}
$logFile = "$ExtractPath\usmtutil.log"

Start-Process -FilePath $NewFolder


#The Path of the usmtutils.exe file
$USMTUtil = "C:\USMT\x64\usmtutils.exe" 

#Trigger the Extract Process
Start-Process -FilePath $USMTUtil -ArgumentList "/extract $DataFile $ExtractPath /c /l:$($logFile) /decrypt /key:$($Key)"
