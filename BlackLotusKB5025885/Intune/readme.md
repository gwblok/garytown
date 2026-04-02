# 2023 Certificate Secure Boot Updates & Black Lotus for Intune

## Intune Remediation Script Setup

I'd personally recommend setting up several just to make reporting easier. If you want to be Secure, run all 4 steps, if you just want to not have stuff break, do steps 1 & 2

What do I mean by that?  

- Step 1 = Update the 4 Certificate items
- Step 2 = Update Boot Manager to be 2023 Signed

### Implement Remediation Scripts - Certs

This Remediation consists of the Detection & Remediation Scripts in the subfolder "IndividualSteps"

- Detection: SecureBoot-Step1-Certs-Detection.ps1
- Remediation: SecureBoot-Step1-Certs-Remediation.ps1

### Implement Remediation Scripts - Boot Manager

This Remediation consists of the Detection & Remediation Scripts in the subfolder "IndividualSteps"

- Detection: SecureBoot-Step2-BootMgr-Detection.ps1
- Remediation: SecureBoot-Step2-BootMgr-Remediation.ps1

### Implement Remediation Scripts

This will remediate steps 1 - 4 based on a true/false that you set at the top of the script.

- Detection: SecureBoot-Update-FullProcess-Detection.ps1
- Remediation: SecureBoot-Update-FullProcess-Remediation.ps1

## Monitor / Reporting Only for Intune

I've create a couple of scripts to help determine what exact Certificates are missing as well as which steps you've completed.  Since having data returned to a Remediation Script is ... um ... ugly at best, I've found it easier for viewing if I separate it out into a couple different processes.

### Monitor Only - Confirm which Certs are Missing

- Detection Script: 2023CertificateStatusMonitor.ps1
- Remediation Script: NA (Don't need one)

### Monitor Only - Overall Status

I've created this for you to get a high level overview of your devices and their situation without making any changes.  It will let you know if the device has any prereq issues (Secure Boot Disabled, or too old of OS), along with the current stage / step of the Remediation process it is currently on.

- Detection: SecureBoot-Update-PreCheck-BlackLotusStatusMonitor.ps1

### Change Log

- 25.5.15.12.38 - Updated Intune Scripts
- 25.8.11.15.56 - Updated UBR Check for July 2025 patch level per MS latest requirements
- 26.4.2 - Updated UBRs for March 2026
  - Now that we can detect SVN, added checks for that as well
  - Updated process to allow enabling Step 4 (SVN) if you want (please don't)
  - Added Lots of notes
  - Renamed a lot of files to make more generic.
  - Several Scripts now to do stuff, because info is good


## Extra Reading

aka.ms/SecureBoot

That's where all the good stuff is that goes into great detail and was used to create these scripts.