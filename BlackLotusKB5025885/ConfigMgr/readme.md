# KB5025885  - Black Lotus for ConfigMgr

- 25.5.13.13.6 - Updated ConfigMgr CI Scripts.  The Baseline & Scripts are all good to go

Two Baselines | Remediation | Monitoring

## Monitoring
Import the Black Lotus Monitoring.cab file to setup a read-only Baseline, which will just report back the status of each machine and their current status for each of the steps and pre-reqs

## Remediation

Import the Black Lotus Remediation.cab file to have everything setup for you, or create everything from scratch using the scripts, I suggest the import.

### Create Non-Compliant Collections

Run the script "KB5025885-CreateCMNonCompliantCollections.ps1" to create the collections.  You'll have to first connect to your CM environment in PowerShell before running.  If you're renamed the CIs, you'll need to update the script.  If you want to create Collections for both Baselines, you'll need to make slight modifications to the script to account for the different CI names.

![ConfigMgrNonCompliantCollectionCreation](media/ConfigMgrNonCompliantCollectionCreation-01.png)

![ConfigMgrNonCompliantCollectionCreation](media/ConfigMgrNonCompliantCollectionCreation-02.png)

Local Reports for machines at different stages:
![ConfigMgrBaselineCompliance](media/ConfigMgrBaselineCompliance.png)
![ConfigMgrBaselineCompliance](media/ConfigMgrBaselineCompliance-02.png)
![ConfigMgrBaselineCompliance](media/ConfigMgrBaselineCompliance-03.png)

