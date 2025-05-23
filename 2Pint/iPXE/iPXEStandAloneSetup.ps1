<#
Install iPXE

Install 2PXE

Post Changes:


1. Import the ca cert in C:\Program Files\2Pint Software\2PXE\x64 to Trusted Root CAs on the server

2. Install IIS & Enable Branch Cache:
Add-WindowsFeature Web-Server, Web-Http-Errors, Web-Static-Content, Web-Digest-Auth, Web-Windows-Auth, Web-Mgmt-Console, BranchCache 

3. Configure Virtual Directory:
New-WebVirtualDirectory -Site "Default Web Site" -Name Remoteinstall -PhysicalPath  "C:\ProgramData\2Pint Software\2PXE\Remoteinstall"

4. Set IIS Bindings on 443 to use the 2PINT Cert





#>




#region IIS MIME Types
#MIME SCRIPT for IIS
#Set the MIME types for the iPXE boot files, fonts etc. 

# wimboot.bin file  
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.bin';mimeType='application/octet-stream'}  
#EFI loader files  
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.efi';mimeType='application/octet-stream'}  
#BIOS boot loaders  
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.com';mimeType='application/octet-stream'}  
#BIOS loaders without F12 key press  
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.n12';mimeType='application/octet-stream'}  
#For the boot.sdi file  
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.sdi';mimeType='application/octet-stream'}  
#For the boot.bcd boot configuration files  & BCD file (with no extension)
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.bcd';mimeType='application/octet-stream'}
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.';mimeType='application/octet-stream'}   
#For the winpe images itself  
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.wim';mimeType='application/octet-stream'}  
#for the iPXE BIOS loader files  
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.pxe';mimeType='application/octet-stream'}  
#For the UNDIonly version of iPXE  
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.kpxe';mimeType='application/octet-stream'}  
#For the boot fonts  
add-webconfigurationproperty //staticContent -name collection -value @{fileExtension='.ttf';mimeType='application/octet-stream'} 


#EndRegion
