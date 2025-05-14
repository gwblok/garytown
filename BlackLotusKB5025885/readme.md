# KB5025885  - Black Lotus

I'll be keeping this updated with latest scripts for both ConfigMgr Configuration Items (CIs) and for Intune Remediation Scripts.  I'll also keep other useful scripts here.

I'll plan to create a change log, which will be listed on this page, once I get there.

Things are working, but I need to do a rewrite based on the May 5, 2025 changes Microsoft released.  The current scripts are based on the 2 reboots per step, which has now changed.  You can use them, but I will be updating soon... so stay tuned.

## References from Microsoft

- [How to manage the Windows Boot Manager revocations for Secure Boot changes associated with CVE-2023-24932](https://support.microsoft.com/en-us/topic/how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932-41a975df-beb2-40c1-99a3-b3ff139f832d)
- [Enterprise Deployment Guidance for CVE-2023-24932](https://support.microsoft.com/en-us/topic/enterprise-deployment-guidance-for-cve-2023-24932-88b8f034-20b7-4a45-80cb-c6049b0f9967)
- [Updating Windows bootable media to use the PCA2023 signed boot manager](https://support.microsoft.com/en-us/topic/updating-windows-bootable-media-to-use-the-pca2023-signed-boot-manager-d4064779-0e4e-43ac-b2ce-24f434fcfa0f)
- [Secure Boot DB and DBX variable update events](https://support.microsoft.com/en-us/topic/secure-boot-db-and-dbx-variable-update-events-37e47cf8-608b-4a87-8175-bdead630eb69)
- [What's new in the ADK tools](https://learn.microsoft.com/en-us/windows-hardware/get-started/what-s-new-in-kits-and-tools)

## References from the Community

- [KB5025885: How to manage the Windows Boot Manager revocations for Secure Boot changes associated with CVE-2023-24932 – GARYTOWN](https://garytown.com/configmgr-task-sequence-kb5025885-how-to-manage-the-windows-boot-manager-revocations-for-secure-boot-changes-associated-with-cve-2023-24932)
- [KB5025885: Dealing with CVE-2023-24932 via Proactive Remediation & Configuration Items – GARYTOWN](https://garytown.com/kb5025885-dealing-cve-2023-24932-with-proactive-remediation-configuration-items)
- [Slightly clear the fog around BlackLotus mitigations - Red Pill Blogs](https://technet.blogs.ms/blacklotus/)

# TO DO (Updated 25.5.13)

- Update Scripts for the May 5th Changes
  - Intune Remediation Scripts [Working on]
  - Standalone Functions

# Change Log

- 25.5.13 - Created readme page
- 25.5.13.13.6 - Updated ConfigMgr CI Scripts.  The Baseline & Scripts are all good to go
- 25.5.13.17.9 - Updated Intune Scripts, changed entire process.  Testing FullProcess Remediation Scripts in my lab currently.
