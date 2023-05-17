
### Associated Blog Posts (Basics):
1. [Office 365 Deployment Series with MEMCM - Post 1 - Intro & PreReqs](https://www.recastsoftware.com/blog/office-365-deployment-series-post-1)
2. [Office 365 Deployment Series with MEMCM - Post 2 - Creating the Office Installer - Simple](https://www.recastsoftware.com/blog/office-365-deployment-series-post-2-creating-the-office-installer-simple)
3. [Office 365 Deployment Series with MEMCM - Post 3 - Creating the Office Installer - Advanced](https://www.recastsoftware.com/blog/office-365-deployment-series-post-3-creating-the-office-installer-advanced)
4. [Office 365 Deployment Series with MEMCM - Post 4 - Deployment Methods](https://www.recastsoftware.com/blog/office-365-deployment-series-post-4-deployment-methods)
5. [Office 365 Deployment Series with MEMCM - Post 5 - Office Updates / ADR](https://www.recastsoftware.com/blog/office-365-deployment-series-with-memcm-post-5-office-updates-adr)
6. [Office 365 Deployment Series with MEMCM - Post 6 - Channel Info](https://www.recastsoftware.com/blog/office-365-deployment-series-with-memcm-post-6-channel-info)

### Associated Blog Posts (Lessons Learned):
1. [Office 365 Deployment Series with MEMCM - Enterprise Deployment Lessons Learned Part 1 - Content](https://www.recastsoftware.com/blog/office-365-deployment-series-with-memcm-enterprise-deployment-lessons-learned-part-1)
2. [Office 365 Deployment Series with MEMCM - Enterprise Deployment Lessons Learned Part 2 - Changing Channels](https://www.recastsoftware.com/blog/office-365-deployment-series-with-memcm-enterprise-deployment-lessons-learned-part-2-changing-channels)
3. [Office 365 Deployment Series with MEMCM - Enterprise Deployment Lessons Learned Part 3 - Deployments](https://www.recastsoftware.com/blog/office-365-deployment-series-with-memcm-enterprise-deployment-lessons-learned-part-3-deployments)
4. [Office 365 Deployment Series with MEMCM - Enterprise Deployment Lessons Learned Part 4 - Baseline - Toast Notifications](https://www.recastsoftware.com/blog/office-365-deployment-series-with-memcm-enterprise-deployment-lessons-learned-part-4-toast-notifications)



### o365_install.ps1
Logging: C:\windows\temp\Office365_Install.log

This file is configured to be used in when PreCache & Install take place in seperate Applications

1. Application 1 = o365_install.ps1 -precache -channel broad -companyvalue 'GARYTOWN'
- Note, in Precache mode, channel doens't mean anything, it's just a required parameter.
- This will run the script in mode that downloads the content to a local path.
- This gives you the ability to run in a required deployment to get the content downloaded ahead of time
- The source content is the entire payload for office 365
- Detection method: c:\programdata\o365_cache\office\data\v64_16.XXXXXXXX
  - You will need to update this every time you update the source content to make sure it matches.
  
2. Application 2 = o365_install.ps1 -channel SemiAnnual -companyvalue 'GARYTOWN'
3. Application 3 = o365_install.ps1 -access -channel SemiAnnual -companyvalue 'GARYTOWN'
4. Application 4 = o365_install.ps1 -visiopro -channel SemiAnnual -companyvalue 'GARYTOWN'
5. Application 5 = o365_install.ps1 -visiostd -channel SemiAnnual -companyvalue 'GARYTOWN'
6. Application 6 = o365_install.ps1 -projectpro -channel SemiAnnual -companyvalue 'GARYTOWN'
7. Application 7 = o365_install.ps1 -projectstd -channel SemiAnnual -companyvalue 'GARYTOWN'

- Apps 2 - 7 are setup identical content, a folder with the 3 scripts (install / prep / uninstall)
  - They would have have the same detection method, except 3-7 would include the EXE of the addtional program you're adding on.
  - The AppDT would have Application 1 (PreCache) set as a Dependency, to ensure that the installer is already downloaded.
- Apps 3 - 7 are meant to be run after app 2 as an add-on, but would technically work standalone, as it would install office first, then the additional application (Access, Visio, Project)


#### Deployment Scenario:  Deploying Office 365 as Available to User Collection: Office 365 Available.

Deploy Application 1 (PreCache) to "Office 365 Available" User Collection as Required, Deadline 10PM, Hidden, Not Shown in Software Center.
 - This will get all of the Content for the Office install to start pulling down that night
Deploy Application 2-7 or any combo to "Office 365 Available" User Collection as Available, starting a day or two out.
 - This will light up the Application for users to install in the Software Center.  Hopefully the machines have the content already downloaded after a couple days so when they trigger it, it checks to see if the dependancy is already installed, and then install office.  If not, it will trigger the dependancy to download first, then run the install.
 
Pros:
- Use the Same Office Content (PreCache) for all of the different App Installs, so they don't have to download multiple copies of the same content for each different install (Office / Access / Visio / Project)
- Adds flexiblity to PreCache content and provide better user experience for your Self-Service Users

Cons:
- Requires 1 addtional Application


### o365_prep.ps1
This file is used to help cleanup previous office software before the upgrade.  o365_install.ps1 calls this script unless it already finds office 365 installed, then skips the prep script

### o365_uninstall.ps1
This will dynamically uninstall office 365 based on parameters, pretty much the same as the install script.

### o365_Change_Channel_ConfigItem.ps1
This script can be used for a Baseline deployed to collection to set the Channel for office.
Use Same Script for Discovery & Remediation, just change $RunMode
