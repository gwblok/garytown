#Code From: https://learn.microsoft.com/en-us/powershell/scripting/samples/multiple-selection-list-boxes?view=powershell-7.3


[scriptblock]$script = {

#Initialize TS COM Environment
try { 
    $TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment 
    $TSProgressUI = New-Object -ComObject Microsoft.SMS.TSProgressUI
    $TSProgressUI.CloseProgressDialog()
}
catch { write-output "Not running in TS"}

if ($TSEnv){

    $Title = $tsenv.Value('TSListTitle')
    $Text = $tsenv.Value('TSListText')
    $ListOptions = $TSEnv.GetVariables() | Where-Object {$_ -match 'TSListOption'}
    $Icon = $tsenv.Value('TSListIcon')

}
else {

    $Title = 'Office Location'
    $Text = 'Choose your Office Location from the Drop Down, this will be used to match to the OU during Domain Join'
    $Icon = 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAiFJREFUOE+Nk99LU2EYx7/P6XA2PZtJLpNpFFS7KFBW7kZCiS76uaCiLsKbMN2F4Ai66R/wxhv1Rg8W3dhVkRBCBYFY0s0mZhDUKii0oTaHzh3dTtt54rzq2NlUeu/e9/t9Pu/z8n4fQsniyDU/wCEQnwPRUSEz/wTTBEAaBV7OFJfQ9oY/3KqAkhkEuAOgwrmdzwzQYxjOHmp5tmFpwiiKHZnXYLSWdrTjnvAOWedFC7IJiAZHANwT/F3uLnRa8PAINY930cmm0yF3pTSkZ5hMBhSZUO0iNHhk1B3YJ+oWknnMJ/JYSZswcgyJANVJnNK5m1Ymrwzf7VsOfZn7W9Ztz3U3JCL0v0iVab4GGU8eeDTi6NWvA2Npnza+ZjNZt0z110GSgJbwAkzTzui87ML9m+4Y8XQw+/G7odzpTdgcbY0ODIVrxFn3YBITsxmb/vShB/4TiiEAYCjP369j5psBkxn1Hhnt51VUuyRRtKqbGH2rYz6RE3v/cQW321TrDw3xBIB8//V9ZSaOEUeCwyCELC2VzmIuvopTvtodeZ9jSzjs3Y8ql2NTZ2gkokvm9HYCRsdmEV9cQ3OjF/WHqoTv92IK0U9xeGvdaL/RtAVnBufP2IIkoAxMRX7hzeQP/EnqwnywRsWF1mM4GzhSFLStIO0VZX3dEAC1UrE/qTTKBYiyMWBFeu9hwiMYFWHbMBXjOXLJD8i7jHNOo8Ar2zj/A+TW3Ys3A3pTAAAAAElFTkSuQmCC'
    $Locations = @(
        'Glenwood',
        'Starbuck',
        'Villard',
        'Cyrus',
        'Sauk Centre',
        'Alexandria',
        'Morris'
    )
}




Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = $Title
$form.Size = New-Object System.Drawing.Size(400,260)
$form.StartPosition = 'CenterScreen'

# This base64 string holds the bytes that make up the orange 'G' icon (just an example for a 32x32 pixel image)
$iconBase64      = $Icon
$iconBytes       = [Convert]::FromBase64String($iconBase64)
# initialize a Memory stream holding the bytes
$stream          = [System.IO.MemoryStream]::new($iconBytes, 0, $iconBytes.Length)
$Form.Icon       = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($stream).GetHIcon()))

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Point(215,180)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = 'OK'
$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $OKButton
$form.Controls.Add($OKButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Point(300,180)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = 'Cancel'
$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $CancelButton
$form.Controls.Add($CancelButton)

$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,20)
$label.Size = New-Object System.Drawing.Size(280,50)
$label.Text = $Text
$form.Controls.Add($label)

$listBox = New-Object System.Windows.Forms.Listbox
$listBox.Location = New-Object System.Drawing.Point(10,90)
$listBox.Size = New-Object System.Drawing.Size(360,40)

#$listBox.SelectionMode = 'MultiExtended'

<# Orginal Code
[void] $listBox.Items.Add('Item 1')
[void] $listBox.Items.Add('Item 2')
[void] $listBox.Items.Add('Item 3')
[void] $listBox.Items.Add('Item 4')
[void] $listBox.Items.Add('Item 5')
#>



if ($TSEnv){
     Foreach ($ListOption in $ListOptions){
        $Option = $tsenv.Value($ListOption)
        [void] $listBox.Items.Add($Option)
    }   
}
else {
    Foreach ($Location in $Locations){
        [void] $listBox.Items.Add($Location)
    }
}

$listBox.Height = 70
$form.Controls.Add($listBox)
$form.Topmost = $true

$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{
    $x = $listBox.SelectedItems[0]
    if ($TSEnv){$tsenv.Value('TSListOutPut') = $x}
    $x
}

}


start-process powershell.exe -ArgumentList "Invoke-Command -ScriptBlock {$script}" -NoNewWindow -Wait -PassThru -ErrorAction SilentlyContinue
