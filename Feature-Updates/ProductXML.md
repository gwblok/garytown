# Windows 10
Windows 10 Latest Cab: https://go.microsoft.com/fwlink/?LinkId=841361

Media Creation Tool: https://download.microsoft.com/download/9/e/a/9eac306f-d134-4609-9c58-35d1638c2363/MediaCreationTool22H2.exe

22H2 Product Cab: https://download.microsoft.com/download/3/c/9/3c959fca-d288-46aa-b578-2a6c6c33137a/products_win10_20230510.cab.cab



# Windows 11
Windows 11 Latest CAB: https://go.microsoft.com/fwlink/?LinkId=2156292

Media Creation Tool: https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/mediacreationtool.exe

21H2 Product Cab: https://download.microsoft.com/download/1/b/4/1b4e06e2-767a-4c9a-9899-230fe94ba530/products_Win11_20211115.cab

22H2 Product Cab: https://download.microsoft.com/download/b/1/9/b19bd7fd-78c4-4f88-8c40-3e52aee143c2/products_win11_20230510.cab.cab

23H2 Product Cab: https://download.microsoft.com/download/e/8/6/e86b4c6f-4ae8-40df-b983-3de63ea9502d/products_win11_202311109.cab

## Getting the fwlink:

Using 7Zip, open the MCT.exe -> SetupMgr.dll -> .text file.  Search for "f w l" and it will find any fwlinks in the dll.  Typically there are 2, and it's been the second one, but feel free to test both.

### Snip:

D o w n l o a d P r o d u c t s X m l     p r o d u c t s . c a b         h t t p s : / / g o . m i c r o s o f t . c o m / f w l i n k / ? L i n k I d = 6 2 4 7 3 6     h t t p s : / / g o . m i c r o s o f t . c o m / f w l i n k / ? L i n k I d = 2 1 5 6 2 9 2   S e t u p M g r :   E x p a n d i n g   c a b   [ % s ]   t o   [ % s ] .   p r o d u c t s . x m l   
