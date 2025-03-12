$CurrentUnattendLocation = "C:\Users\GaryBlok\OneDrive - 2Pint Software\unattend.xml"

[XML]$XML = get-content $CurrentUnattendLocation
$XML.unattend.settings.component
$NewSpecializeNodeElement = $XML.CreateElement("RunSynchronousCommand")

$NewSpecializeNodeElement.SetAttribute("Order", "1")  #Set the Order to 1
$NewSpecializeNodeElement.SetAttribute("Path", "cmd /c echo Hello World > C:\HelloWorld.txt")  #Set the Path to the command you want to run
$XML.unattend.settings.component | Where-Object {$_.name -eq "Microsoft-Windows-Deployment"} | ForEach-Object {
    $_.appendChild($NewSpecializeNodeElement)
}


$XML.Save("C:\Users\GaryBlok\OneDrive - 2Pint Software\unattendTest.xml")