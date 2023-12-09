#Code from https://learn.microsoft.com/en-us/powershell/scripting/samples/creating-a-custom-input-box?view=powershell-7.3

[scriptblock]$script = {

    $Text = 'Name your favorite TV show:'   
    $TSVarName = 'TSVarTVShow'
    $Title = 'Personal Info Request'

    Write-Output $Text
    #Initialize TS COM Environment
    try {
        $TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
        $TSProgressUI = New-Object -ComObject Microsoft.SMS.TSProgressUI
        $TSProgressUI.CloseProgressDialog()

        }
    catch { write-output "Not running in TS"}

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size(300,200)
    $form.StartPosition = 'CenterScreen'

    # This base64 string holds the bytes that make up the orange 'G' icon (just an example for a 32x32 pixel image)
    $iconBase64      = 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAiFJREFUOE+Nk99LU2EYx7/P6XA2PZtJLpNpFFS7KFBW7kZCiS76uaCiLsKbMN2F4Ai66R/wxhv1Rg8W3dhVkRBCBYFY0s0mZhDUKii0oTaHzh3dTtt54rzq2NlUeu/e9/t9Pu/z8n4fQsniyDU/wCEQnwPRUSEz/wTTBEAaBV7OFJfQ9oY/3KqAkhkEuAOgwrmdzwzQYxjOHmp5tmFpwiiKHZnXYLSWdrTjnvAOWedFC7IJiAZHANwT/F3uLnRa8PAINY930cmm0yF3pTSkZ5hMBhSZUO0iNHhk1B3YJ+oWknnMJ/JYSZswcgyJANVJnNK5m1Ymrwzf7VsOfZn7W9Ztz3U3JCL0v0iVab4GGU8eeDTi6NWvA2Npnza+ZjNZt0z110GSgJbwAkzTzui87ML9m+4Y8XQw+/G7odzpTdgcbY0ODIVrxFn3YBITsxmb/vShB/4TiiEAYCjP369j5psBkxn1Hhnt51VUuyRRtKqbGH2rYz6RE3v/cQW321TrDw3xBIB8//V9ZSaOEUeCwyCELC2VzmIuvopTvtodeZ9jSzjs3Y8ql2NTZ2gkokvm9HYCRsdmEV9cQ3OjF/WHqoTv92IK0U9xeGvdaL/RtAVnBufP2IIkoAxMRX7hzeQP/EnqwnywRsWF1mM4GzhSFLStIO0VZX3dEAC1UrE/qTTKBYiyMWBFeu9hwiMYFWHbMBXjOXLJD8i7jHNOo8Ar2zj/A+TW3Ys3A3pTAAAAAElFTkSuQmCC'
    $iconBytes       = [Convert]::FromBase64String($iconBase64)
    # initialize a Memory stream holding the bytes
    $stream          = [System.IO.MemoryStream]::new($iconBytes, 0, $iconBytes.Length)
    $Form.Icon       = [System.Drawing.Icon]::FromHandle(([System.Drawing.Bitmap]::new($stream).GetHIcon()))


    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(75,120)
    $okButton.Size = New-Object System.Drawing.Size(75,23)
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(150,120)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(10,20)
    $label.Size = New-Object System.Drawing.Size(280,20)
    $label.Text = $Text
    $form.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10,40)
    $textBox.Size = New-Object System.Drawing.Size(260,20)
    $form.Controls.Add($textBox)

    $form.Topmost = $true

    $form.Add_Shown({$textBox.Select()})
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $x = $textBox.Text
        if ($TSEnv){$tsenv.Value($TSVarName) = $x}
    }
}
start-process powershell.exe -ArgumentList "Invoke-Command -ScriptBlock $script" -NoNewWindow -Wait -PassThru
