# 2Pint iPXE WebService + 2PXE Standalone Quick Start

This page is going to cover setting up the iPXE / 2PXE setup for running a standalone server that you'd have your own custom boot media for.  Much of this process is identical to using a ConfigMgr integrated setup, but I'll cover that in a different page.

# Table of contents

- [2Pint iPXE WebService + 2PXE Standalone Quick Start](#2pint-ipxe-webservice--2pxe-standalone-quick-start)
- [Table of contents](#table-of-contents)
  - [Pre-Setup - Server 2025 + SQLExpress ](#pre-setup---server-2025--sqlexpress-)
    - [Extra things I installed because they are useful and my preference ](#extra-things-i-installed-because-they-are-useful-and-my-preference-)
    - [Lab Information ](#lab-information-)
    - [SQL Permissions Setup ](#sql-permissions-setup-)
    - [iPXE WebService \& 2PXE install Docs ](#ipxe-webservice--2pxe-install-docs-)
  - [Install Process Walk-Through ](#install-process-walk-through-)
    - [SQL Express 2022 ](#sql-express-2022-)
    - [SQL Server Management Studio ](#sql-server-management-studio-)
    - [SQL Server Latest CU ](#sql-server-latest-cu-)
    - [Extra Features \& SQL DB Permissions ](#extra-features--sql-db-permissions-)
  - [2Pint iPXE WebService \& 2PXE Setup ](#2pint-ipxe-webservice--2pxe-setup-)
    - [iPXE Web Service ](#ipxe-web-service-)
    - [2PXE Install ](#2pxe-install-)
  - [Post Install Configuration Changes ](#post-install-configuration-changes-)
    - [Certificate time - Import Root CA ](#certificate-time---import-root-ca-)
    - [IIS Modifications - MIME Types | Cert | Virtual Directory ](#iis-modifications---mime-types--cert--virtual-directory-)
      - [Bind Cert ](#bind-cert-)
      - [Create Virtual Directory ](#create-virtual-directory-)
      - [MIME Types ](#mime-types-)
  - [Now we need a bunch of PowerShell Scripts ](#now-we-need-a-bunch-of-powershell-scripts-)
  - [Working PXE ](#working-pxe-)
  - [WinPE - Create a Folder and Copy the Required Files ](#winpe---create-a-folder-and-copy-the-required-files-)
  - [Modifying PowerShell Scripts for your Environment ](#modifying-powershell-scripts-for-your-environment-)
    - [Booting Hyper-V via iPXE and Generic ADK WinPE ](#booting-hyper-v-via-ipxe-and-generic-adk-winpe-)

## Pre-Setup - Server 2025 + SQLExpress <a name="PreSetup"></a>

Install Server 2025 Standard with Desktop Experience and then I installed:

- SQL Express [download](https://www.microsoft.com/en-us/download/details.aspx?id=104781&lc=1033&msockid=2cc2ce8f36b866c40a56db7b37e76743)
  - Set Firewall Rules: [MS Learn](https://learn.microsoft.com/en-us/sql/sql-server/install/configure-the-windows-firewall-to-allow-sql-server-access?view=sql-server-ver16)

- SQL 2022 Latest CU [download](https://www.microsoft.com/en-US/download/details.aspx?id=105013&msockid=2cc2ce8f36b866c40a56db7b37e76743)
- SQL Management Studio [MS Learn](https://learn.microsoft.com/en-us/ssms/install/install)
- Additional Features (WebServer (IIS) & BranchCache)

### Extra things I installed because they are useful and my preference <a name="Extras"></a>

- VSCode
- Notepad++
- PowerShell 7

### Lab Information <a name="LabInfo"></a>

I've created a new subnet just for this setup as to not mess with my other installation of iPXE.  I create a 192.168.214.0 network, and that is where I will be placing this new iPXE server, and my test clients.  I'm setting the Server's IP Address to 192.168.214.5, and Name to 214-iPXE, and domain = 2p.garytown.com

### SQL Permissions Setup <a name="SQLPerms"></a>

You need to make sure SYSTEM has the correct permissions: <https://ipxews.docs.2pintsoftware.com/planning/permissions>

I'll cover this in the guide below, and show details on how to do it, just wanted to point it out now.

### iPXE WebService & 2PXE install Docs <a name="Official"></a>

I originally followed these directions: <https://ipxews.docs.2pintsoftware.com/> and <https://2pxe.docs.2pintsoftware.com/>, they are much more in-depth and will contain links to relative information.  I'd recommend looking them over when you can.  I however will provide my walk through below.

## Install Process Walk-Through <a name="WalkThrough"></a>

### SQL Express 2022 <a name="SQLExpress"></a>

I just went with straight up defaults to get it installed:
![Image01](media/SQLExpressSetup01.png)
![Image02](media/SQLExpressSetup02.png)
![Image03](media/SQLExpressSetup03.png)
![Image04](media/SQLExpressSetup04.png)

Before we move on, lets just get this done, Firewall Rules:

```PowerShell
New-NetFirewallRule -DisplayName "SQLServer default instance" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "SQLServer Browser service" -Direction Inbound -LocalPort 1434 -Protocol UDP -Action Allow
```

![Image05](media/SQLExpressSetup05.png)

### SQL Server Management Studio <a name="SSMS"></a>

Once you download and trigger, I just went with defaults again. Keeping it simple:

![Image01](media/SSMS01.png)
![Image02](media/SSMS02.png)
![Image03](media/SSMS03.png)

We'll reboot in a minute, but lets first do the CU

### SQL Server Latest CU <a name="SQLCU"></a>

Download from MS.. I typically just Google "SQL Latest CU" and it brings me here: <https://www.microsoft.com/en-US/download/details.aspx?id=105013&msockid=13edcc8571866d890205d97170d06c11>

![Image01](media/SQLCU01.png)

For me, that was SQLServer2022-KB5054531-x64.  Launch after download and start clicking Next  and update until it's done!

![Image02](media/SQLCU02.png)
![Image03](media/SQLCU03.png)
![Image04](media/SQLCU04.png)

Now Lets Reboot!

### Extra Features & SQL DB Permissions <a name="FeaturesDBPerms"></a>

Lets go ahead and setup the extra features that iPXE/2PXE will need, IIS & BranchCache

```PowerShell
Add-WindowsFeature Web-Server, Web-Http-Errors, Web-Static-Content, Web-Digest-Auth, Web-Windows-Auth, Web-Mgmt-Console, BranchCache 
```

![Image01](media/OSOptions01.png)
And now with that done, lets make sure SQL has the permissions needed for the iPXE Web Service installer to create the database it will use:

Alright, I think we're ready to get to the reason we started this, the 2Pint software.

- You need to make sure SYSTEM has the correct permissions: <https://ipxews.docs.2pintsoftware.com/planning/permissions>

![Image04](media/SSMS04.png)

From the docs: "If SQL is installed on the same machine as the iPXE Any Where Web Service, the account: NT AUTHORITY\SYSTEM must be granted dbcreator permissions. The service will also grant the local system account db_owner permissions to the iPXE Anywhere database."  So lets add dbceator:
![Image05](media/SSMS05.png)

## 2Pint iPXE WebService & 2PXE Setup <a name="2PintSetup"></a>

This section will go over the 2 different installs to have a 2PXE server integrated with the iPXE Web Service.  We'll start by installing the Web Service.

### iPXE Web Service <a name="iPXESetup"></a>

I like to open an elevated prompt, and in my case PowerShell by default, and run the command to create a log file as well.  So I will first change directory (cd) to where I have the installer extracted and then launch the installer

``` cmd
 msiexec -i iPXEAnywhere.WebService.Installer64.msi /l*v iPXEInstall.log
```

![Image01](media/iPXEInstall01.png)

Check the Box and click "Next"

![Image02](media/iPXEInstall02.png)

Add your License if you have one, or keep it on trial and click Next

![Image03](media/iPXEInstall03.png)

Leave the defaults unless you plan to use a custom Cert, for testing, I'd just use the default Self-Signed, which is what I'll be doing.

![Image04](media/iPXEInstall04.png)

Type in your Database Connection String (ServerName\SQLExpress), if you're following this Guide.

![Image05](media/iPXEInstall05.png)

I like to set this as the name, but feel free to do what you will.

![Image06](media/iPXEInstall06.png)

Test Connection and Click Next:

![Image07](media/iPXEInstall07.png)

And now Defaults rest of the way

![Image08](media/iPXEInstall08.png)
![Image09](media/iPXEInstall09.png)
![Image10](media/iPXEInstall10.png)

Yippee.. we have this installed!  Now if you go back into SQL Server Management Studio, you can confirm it did create a database:

![Image11](media/iPXEInstall11.png)

### 2PXE Install <a name="2PXESetup"></a>

Once again, I like to do it via the command line

``` cmd
msiexec -i '2Pint Software 2PXE Service (x64).msi' -l*v 2PXEInstall.log
```

![Image01](media/2PXEInstall01.png)
![Image02](media/2PXEInstall02.png)
![Image03](media/2PXEInstall03.png)

Here were will select the "PowerShell Integrated Installation" and check the box to use HTTP(s) server for iPXE to 2PXE Communication, and Bind to the IP we set on the host.

![Image04](media/2PXEInstall04.png)

Here we will set the FQDN of the server we installed the iPXE Webservice, which happens to be this same server.

![Image05](media/2PXEInstall05.png)

Leave Defaults

![Image06](media/2PXEInstall06.png)

Click "Test" and then Next

![Image07](media/2PXEInstall07.png)

Leave the Default

![Image08](media/2PXEInstall08.png)

Leave the Default

![Image09](media/2PXEInstall09.png)

Clear out the Default and leave it blank

![Image10](media/2PXEInstall10.png)

![Image11](media/2PXEInstall11.png)
![Image12](media/2PXEInstall12.png)

Now we have the 2PXE Software installed!  Lets take a look at the services and make sure they are running.  If they are not running, typically that means something was configured wrong during the installation.

![Image01](media/Services01.png)

## Post Install Configuration Changes <a name="PICC"></a>

### Certificate time - Import Root CA <a name="RootCA"></a>

When the 2PXE service starts, it generates the certificates you need.  One you need to import into trusted CAs on the machine itself, and one you need to bind HTTPS 443 to in IIS.

Go do your Certificate Manager for the Machine (certlm.msc) and then to Trusted Root Certification Authorities, Right Click -> All Tasks -> Import...

![Image01](media/PostInstallConfig01.png)

Leave Default, just make sure it's showing Local Machine

![Image02](media/PostInstallConfig02.png)

Browse to C:\Program Files\2Pint Software\2PXE\x64 and select the ca.crt

![Image03](media/PostInstallConfig03.png)

Leave Default: Place all certficates into the following Store: Trusted Root Certification Authorities:

![Image04](media/PostInstallConfig04.png)

![Image05](media/PostInstallConfig05.png)

Confirm the 2PintSoftware cert is there.

![Image06](media/PostInstallConfig06.png)

### IIS Modifications - MIME Types | Cert | Virtual Directory <a name="IISMods"></a>

#### Bind Cert <a name="BindCert"></a>

- Open IIS, Right Click on "Default Web Site" and choose "Edit Bindings..."
- Click "Add"
- From the Type: drop down box, choose https
- click "Select..." to choose a SSL certficiate, I only had one available, so it was easy
- click "View..." to confirm it is the Cert created by the 2PXE installer and signed by 2PintSoftware
- Click Ok and close out.  Feel free to go back into bindings and confirm.
  
![Image01](media/PostInstallIIS01.png)

#### Create Virtual Directory <a name="VirtualDir"></a>

We need to tell IIS where to get content, so to do that we are going to create a virtual directory in the 2Pint Software 2PXE PROGRAMDATA folder.  This folder is a bit bare at the moment, but this is where you'll be creating folders to put your WinPE / WinRE images.

![Image02](media/PostInstallIIS02.png)

You can create the virtual directory in IIS or in PowerShell.  I'll provide the PS first, and if you want to do it via the GUI, that's fine too.

```PowerShell
New-WebVirtualDirectory -Site "Default Web Site" -Name "Remoteinstall" -PhysicalPath 'C:\ProgramData\2Pint Software\2PXE\Remoteinstall\'
```

![Image03](media/PostInstallIIS03.png)

GUI:

- Open IIS, Right Click on "Default Web Site" and choose "Add Virtual Directory..."
- Alias: Remoteinstall
- PhysicalPath = C:\ProgramData\2Pint Software\2PXE\Remoteinstall

Once you have added it, it will show up in the console, and if you drill down you'll see the extra subfolders, and if you check the Advanced Properties you can confirm the path

![Image04](media/PostInstallIIS04.png)

#### MIME Types <a name="MIME"></a>

Ok, by default IIS doesn't support all of the boot files we need, so we have a script that will go through and add them... sure, you can do this via the GUI, but I'm not going to cover it, go ahead and google it if you must.

Now this script was designed back on older versions of IIS, and since then, Microsoft has added a couple of these as defaults, so they will already be there and will throw an error because it's already there... I'm going to ignore that because I don't care, and I want to keep this simple instead making a really long script that has a bunch of checks... which at end end of the day bought me nothing.

```PowerShell
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

```

In action, like I said, you can look over the errors, but basically it's saying that it can't duplicate what's already there, so it errors.  No big deal.

![Image05](media/PostInstallIIS05.png)

To confirm, you can go into the GUI,

- Open IIS, Click "Default Web Site" and Double Click on MIME Types to get the list.  Confirm the ones above are added.  I confirmed one and assumed everything was good.

![Image06](media/PostInstallIIS06.png)

## Now we need a bunch of PowerShell Scripts <a name="PSImport"></a>

So we have the majority of this done, but we need to grab some default scripts hosted on 2Pint's GitHub to populate into the Server. [2Pint GitHub Repo](https://github.com/2pintsoftware/2Pint-iPXEAnywhere)

This is spelled out really well in the official docs here: <https://ipxews.docs.2pintsoftware.com/installation/ipxe-anywhere-web-service-install#adding-the-scripts-folder>

Stolen directly from there docs:

![Image01](media/PostInstallAddScripts01.png)

So here I go downloading the Zip File:

![Image02](media/PostInstallAddScripts02.png)

After you download, make sure the zip file is NOT blocked before you extract and copy the scripts folder into place

![Image03](media/PostInstallAddScripts03.png)

Go ahead any Extract that Zip File, then move that scripts folder (ONLY THE SCRIPTS FOLDER) over to : C:\Program Files\2Pint Software\iPXE AnywhereWS
![Image04](media/PostInstallAddScripts04.png)

When you're done, you should have a structure like this:

![Image05](media/PostInstallAddScripts05.png)

## Working PXE <a name="WorkingPXE"></a>

At this point you'll have a working iPXE deployment on your subnet.

![Image01](media/iPXEBoot01.png)
![Image02](media/iPXEBoot02.png)

Note, the default pin is '42'
Once you choose Pin, and type 42, and hit enter, the menu will progress.

These menus are controlled with the PowerShell files you just imported.  So lets get at least 1 boot image setup before we end this guide!

## WinPE - Create a Folder and Copy the Required Files <a name="WinPE"></a>

First, lets create a WinPE folder in the Remoteinstall folder, so it's available via our IIS to iPXE - "C:\ProgramData\2Pint Software\2PXE\Remoteinstall\WinPE"

Now lets gather the files we need from a simple ADK installation.  From any machine you have the ADK installed on (I'm using the 24H2 Dec Release of the ADK), grab the following files and place into the WinPE folder:

C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\Media\Boot

- BCD
- boot.sdi

C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us

- winpe.wim

C:\ProgramData\2Pint Software\2PXE\Remoteinstall\Boot

- wimboot.x86_64.efi

Once you've gathered there required files, your new folder should look like:

![Image01](media/FirstBootImage01.png)

Ok, you now have the bare basics for your WinPE environment to boot from, now we need to modify some scripts to look for these new files.

## Modifying PowerShell Scripts for your Environment <a name="PSMods"></a>

This is why I like to have VSCode installed, I launch it as an admin, then open the FOLDER scripts.
We're going to look at 2 scripts and keep this super basic for this POC.  We need to modify the iPXEboot.ps1 file, as that's the file that is your main menu and will kick off sub scripts to launch different WinPE environments.

We then also modify the winpe.ps1 file, and leverage that to boot up our newly created winpe folder with winpe.wim inside.

![Image01](media/ModifyScripts01.png)

First off, what I'm going to do is make a copy of the original iPXEboot.ps1 file for a backup, because ... i tend to break stuff

Then I'm going  to modify a few items to use our Generic WinPE

Few things about the layout of iPXE syntax, it's not the most fun.  I'm still learning it, but once you learn how this all works, you can pretty much achieve anything in your boot process.

looking at line 31, we have key m, this means you could use m as a short key in the menu, I don't know anyone who uses this, but it's possible.  Next is the 'anchor' that rest of the item is tied to, basically a short name variable that represents the menu item.  Next is the Friendly name that shows in the Menu.

now that we have an anchor variable winpe in our updated script, we will use that to set the menu to default to winpe booting, instead of exiting, then on line 40, (:winpe), that tells the script to run the next part if winpe was choosen in the menu, and when winpe is chosen, it will run the script Custom\winpe.ps1 based on line 41.

This is how you'd have several options which would load different media.  I'll try to get into that later.

![Image02](media/ModifyScripts02.png)

So now we have a modified iPXEboot.ps1 file with a menu item that will launch the Custom\winpe.ps1 script, so we now need to look at that and update it to make sure it launches our newly created contents.

So in this script, it's almost already exactly what we need, I'm going to update the $toolserver variable with my server, and ensure the path looks right.

![Image03](media/ModifyScripts03.png)

So now at this point, we should have everything setup to boot a device into WinPE!  Lets give it a try...

### Booting Hyper-V via iPXE and Generic ADK WinPE <a name="Success"></a>

Ok, you can see the new Menu item is there, and it's now the default instead of "Exit..."

![Image03](media/iPXEBoot03.png)

Here you can see that it is successfully finding the files we added to that folder and downloading them to the device.

![Image04](media/iPXEBoot04.png)

And looky looky, we have WinPE loaded up!

![Image05](media/iPXEBoot05.png)

Ok, so that was a bit, but we got there, you now have a functional 2Pint iPXE / 2PXE setup, and you can start to go crazy with using it to boot up whatever you want.  
