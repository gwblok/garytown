# ConfigMgr Baselines

## Active Cache Management

These scripts can be used to control and manage your CCMCache
- Set Cache Size based on Drive Size
  - This requires that you're not setting it via Client Settings, which will overwrite what this CI does
  - You can set the CCMCache size initially when you install the CM Client, then leverage this baseline to dynamcially assign a size or %
- Groom Cache based on Drive Free space, age and type of content.
- Remove Duplicate packages (older versions of same content)

BranchCache Management coming in the future.


## Package Content Compliance

This will monitor a specific Task Sequence that is deployed to the device and confirm the Task Sequence Content is in the CCMCache

## Other Baselines

There will be other items here, I'll try to update the page with some info as I add them... no promises.
