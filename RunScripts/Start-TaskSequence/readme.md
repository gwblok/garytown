# Start-TaskSequence

This script is meant to be used as a RunScript in ConfigMgr, however you can steal the code for whatever you want.

There is a switch in the script that checks the execution history for the task sequence, if already successfully ran, will exit out of the script.  You can override this by switching to "TRUE".

## Demos

### Demo - Already Successfully Ran Previously - Exit Script

[![StartTS01](StartTS01.png)](StartTS01.png)
[![StartTS02](StartTS02.png)](StartTS02.png)

### Demo - Already Successfully Ran Previously - Force Re-run

[![StartTS03](StartTS03.png)](StartTS03.png)
[![StartTS05](StartTS05.png)](StartTS05.png)
