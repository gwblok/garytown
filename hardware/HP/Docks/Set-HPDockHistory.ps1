<#
GARY BLOK | @gwblok | GARYTOWN.COM

.SYNOPSIS
	Sets information for HP Dock Connection History
   
.DESCRIPTION 
    This script will record HP Dock connections into WMI
   
.Requirements
    Requires that you have the HP WMI Provider Installed to get information from the currently installed HP Dock

.PARAMETER Registry
    This switch will add information to the following location:
        - Registry

.PARAMETER WMI
    This switch will add information to the following location:
        - WMI Repository
    
.EXAMPLE
     Set-HPDockHistory.ps1 -WMI -Registry

     Will add all information to the following locations:
        - Registry
        - WMI Repository 

.NOTES
    Script is an adaptation from Jason Sandy's Script for OSDInfo: 
      https://github.com/jason4tw/ConfigMgrScripts/blob/master/OSD/Set-OSDInfo.ps1
    Modified from the versions by Stephane van Gulick from www.powershellDistrict.com
	V1.1, 2016-5-6: Added, values for Dtae/Time, OS Image ID, UEFI, and Launch Mode

.LINK
	https://garytown.com

.NOTES
   Releases
   23.05.22 - Origial Release

	
#>
[cmdletBinding()]
Param(
        [Parameter(Mandatory=$false)][switch]$WMI,
        [Parameter(Mandatory=$false)][switch]$Registry,
        [Parameter(Mandatory=$false)][String]$Namespace = "HP\InstrumentedServices\v1",
        [Parameter(Mandatory=$false)][String]$Class = "HP_DockHistory",
        [Parameter(Mandatory=$false)][String]$ID,
        [Parameter(Mandatory=$false)][String]$AttributePrefix = "HP_"
)



#region Functions
Function Get-WMINamespace
{
  <#
	.SYNOPSIS
		Gets information about a specified WMI namespace.

	.DESCRIPTION
		Returns information about a specified WMI namespace.

    .PARAMETER  Namespace
		Specify the name of the namespace where the class resides in (default is "root\cimv2").

	.EXAMPLE
		Get-WMINamespace
        Lists all WMI namespaces.

	.EXAMPLE
		Get-WMINamespace -Namespace cimv2
        Returns the cimv2 namespace.

	.NOTES
		Version: 1.0

	.LINK
		http://blog.configmgrftw.com

#>
[CmdletBinding()]
	Param
    (
        [Parameter(Mandatory=$false,valueFromPipeLine=$true)][string]$Namespace
	)  
    begin
	{
		Write-Verbose "Getting WMI namespace $Namespace"
    }
    Process
	{
        if ($Namespace)
        {
            $Root = $Namespace | Split-Path
            $filterNameSpace = $Namespace.Replace("$Root\","")
            $filter = "Name = '$filterNameSpace'"
            $return = Get-WmiObject -Namespace "Root\$Root" -Class "__namespace" -filter $filter
        }
		else
		{
            $return = Get-WmiObject -Namespace ROOT -Class __namespace
        }
    }
    end
	{
        return $return
    }
}

Function New-WMINamespace
{
<#
	.SYNOPSIS
		This function creates a new WMI namespace.

	.DESCRIPTION
		The function creates a new WMI namespsace.

    .PARAMETER Namespace
		Specify the name of the namespace that you would like to create.

	.EXAMPLE
		New-WMINamespace -Namespace "ITLocal"
        Creates a new namespace called "ITLocal"
		
	.NOTES
		Version: 1.0

	.LINK
		http://blog.configmgrftw.com

#>
[CmdletBinding()]
	Param(
        [Parameter(Mandatory=$true,valueFromPipeLine=$true)][string]$Namespace
	)

	if (!(Get-WMINamespace -Namespace "$Namespace"))
	{
		Write-Verbose "Attempting to create namespace $($Namespace)"

		$newNamespace = ""
		$rootNamespace = [wmiclass]'ROOT\HP\InstrumentedServices:__namespace'
        $newNamespace = $rootNamespace.CreateInstance()
		$newNamespace.Name = $Namespace
		$newNamespace.Put() | out-null
		
		Write-Verbose "Namespace $($Namespace) created."

	}
	else
	{
		Write-Verbose "Namespace $($Namespace) is already present. Skipping.."
	}
}

Function Get-WMIClass
{
  <#
	.SYNOPSIS
		Gets information about a specified WMI class.

	.DESCRIPTION
		Returns the listing of a WMI class.

	.PARAMETER  ClassName
		Specify the name of the class that needs to be queried.

    .PARAMETER  Namespace
		Specify the name of the namespace where the class resides in (default is "root\cimv2").

	.EXAMPLE
		get-wmiclass
        List all the Classes located in the root\cimv2 namespace (default location).

	.EXAMPLE
		get-wmiclass -classname win32_bios
        Returns the Win32_Bios class.

	.EXAMPLE
		get-wmiclass -Class MyCustomClass
        Returns information from MyCustomClass class located in the default namespace (root\cimv2).

    .EXAMPLE
		Get-WMIClass -Namespace ccm -Class *
        List all the classes located in the root\ccm namespace

	.EXAMPLE
		Get-WMIClass -NameSpace ccm -Class ccm_client
        Returns information from the cm_client class located in the root\ccm namespace.

	.NOTES
		Version: 1.0

	.LINK
		http://blog.configmgrftw.com

#>
[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory=$false,valueFromPipeLine=$true)][string]$Class,
        [Parameter(Mandatory=$false)][string]$Namespace = "cimv2"
	)  
    begin
	{
		Write-Verbose "Getting WMI class $Class"
    }
    Process
	{
		if (Get-WMINamespace -Namespace $Namespace)
		{
			$namespaceFullName = "root\$Namespace"

            Write-Verbose $namespaceFullName
		
			if (!$Class)
			{
				$return = Get-WmiObject -Namespace $namespaceFullName -Class * -list
			}
			else
			{
				$return = Get-WmiObject -Namespace $namespaceFullName -Class $Class -list
			}
		}
		else
		{
			Write-Verbose "WMI namespace $Namespace does not exist."
			
			$return = $null
		}
    }
    end
	{
        return $return
    }
}

Function New-WMIClass
{
<#
	.SYNOPSIS
		This function creates a new WMI class.

	.DESCRIPTION
		The function create a new WMI class in the specified namespace.
        It does not create a new namespace however.

	.PARAMETER Class
		Specify the name of the class that you would like to create.

    .PARAMETER Namespace
		Specify the namespace where class the class should be created.
        If not specified, the class will automatically be created in "root\cimv2"

    .PARAMETER Attributes
		Specify the attributes for the new class.

    .PARAMETER Key
		Specify the names of the key attribute (or attributes) for the new class.

	.EXAMPLE
		New-WMIClass -ClassName "OSD_Info"
        Creates a new class called "OSD_Info"
    .EXAMPLE
        New-WMIClass -ClassName "OSD_Info1","OSD_Info2"
        Creates two classes called "OSD_Info1" and "OSD_Info2" in the root\cimv2 namespace

	.NOTES
		Version: 1.0

	.LINK
		http://blog.configmgrftw.com

#>
[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,valueFromPipeLine=$true)][string]$Class,
        [Parameter(Mandatory=$false)][string]$Namespace = "cimv2",
        [Parameter(Mandatory=$false)][System.Management.Automation.PSVariable[]]$Attributes,
        [Parameter(Mandatory=$false)][string[]]$Key
	)

	$namespaceFullName = "root\$Namespace"
	
	if (!(Get-WMINamespace -Namespace $Namespace))
	{
		Write-Verbose "WMI namespace $Namespace does not exist."

	}

    elseif (!(Get-WMIClass -Class $Class -NameSpace $Namespace))
	{
		Write-Verbose "Attempting to create class $($Class)"
			
		$newClass = ""
		$newClass = New-Object System.Management.ManagementClass($namespaceFullName, [string]::Empty, $null)
		$newClass.name = $Class

        foreach ($attr in $Attributes)
        {
            $attr.Name -match "$AttributePrefix(?<attributeName>.*)" | Out-Null
            $attrName = $matches['attributeName']

            $newClass.Properties.Add($attrName, [System.Management.CimType]::String, $false)
            Write-Verbose "   added attribute: $attrName"
        }

        foreach ($keyAttr in $Key)
        {
            $newClass.Properties[$keyAttr].Qualifiers.Add("Key", $true)
            Write-Verbose "   added key: $keyAttr"
        }


		$newClass.Put() | out-null
			
		Write-Verbose "Class $($Class) created."
	}
	else
	{
		Write-Verbose "Class $($Class) is already present. Skipping..."
    }

}

Function New-WMIClassInstance
{
    <#
	.SYNOPSIS
		Creates a new WMI class instance.

	.DESCRIPTION
		The function creates a new instance of the specified WMI class.

	.PARAMETER  Class
		Specify the name of the class to create a new instance of.

	.PARAMETER Namespace
        Specify the name of the namespace where the class is located (default is Root\cimv2).

	.PARAMETER Attributes
        Specify the attributes and their values using PSVariables.

	.EXAMPLE
        $MyNewInstance = New-WMIClassInstance -Class OSDInfo
        
        Creates a new instance of the WMI class "OSDInfo" and sets its attributes.
		
	.NOTES
		Version: 1.0

	.LINK
		http://blog.configmgrftw.com

#>

[CmdletBinding()]
	Param
    (
		[Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -ne ""
        })][string]$Class,
        [Parameter(Mandatory=$false)][string]$Namespace="cimv2",
        [Parameter(Mandatory=$false)][System.Management.Automation.PSVariable[]]$Attributes
	)

    $classPath = "root\$($Namespace):$($Class)"
    $classObj = [wmiclass]$classPath
    $classInstance = $classObj.CreateInstance()

    Write-Verbose "Created instance of $Class class."

    foreach ($attr in $Attributes)
    {
        $attr.Name -match "$AttributePrefix(?<attributeName>.*)" #| Out-Null
        $attrName = $matches['attributeName']

        if ($attr.Value) 
        {
            $attrVal = $attr.Value
        } 
        else 
        {
            $attrVal = ""
        }
        
        $classInstance[$attrName] = $attrVal
        Write-Verbose "   added attribute value for $($attrName): $($attrVal)"
    }

    $classInstance.Put()
}

Function New-RegistryItem
{
<#
.SYNOPSIS
	Sets a registry value in the specified key under HKLM\Software.
   
.DESCRIPTION 
    Sets a registry value in the specified key under HKLM\Software.
	
	
.PARAMETER Key
    Species the registry path under HKLM\SOFTWARE\ to create.
    Defaults to OperatingSystemDeployment.


.PARAMETER ValueName
    This parameter specifies the name of the Value to set.

.PARAMETER Value
    This parameter specifies the value to set.
    
.Example
     New-RegistryItem -ValueName Test -Value "abc"

.NOTES
	-Version: 1.0
	
#>



    [cmdletBinding()]
    Param(


        [Parameter(Mandatory=$false)]
        [string]$Key = "OperatingSystemDeployment",

        [Parameter(Mandatory=$true)]
        [string]$ValueName,

        [Parameter(Mandatory=$false)]
        [string]$Value
        
    )
    begin
    {
        $registryPath = "HKLM:SOFTWARE\$($Key)"
    }
    Process
    {
        if ($registryPath -eq "HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\")
        {
            write-verbose "The registry path that is tried to be created is the uninstall string.HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\."
            write-verbose "Creating this here would have as consequence to erase the whole content of the Uninstall registry hive."
                        
            exit 
        }

        ##Creating the registry node
        if (!(test-path $registryPath))
        {
            write-verbose "Creating the registry key at : $($registryPath)."
            
            try
            {
                New-Item -Path $registryPath -force -ErrorAction stop | Out-Null
            }
            catch [System.Security.SecurityException]
            {
                write-warning "No access to the registry. Please launch this function with elevated privileges."
            }
            catch
            {
                write-host "An unknowed error occured : $_ "
            }
        }
        else
        {
            write-verbose "The registry key already exists at $($registryPath)"
        }

        ##Creating the registry string and setting its value
        write-verbose "Setting the registry string $($ValueName) with value $($Value) at path : $($registryPath) ."

        try
        {
            New-ItemProperty -Path $registryPath  -Name $ValueName -PropertyType STRING -Value $Value -Force -ErrorAction Stop | Out-Null
        }
        catch [System.Security.SecurityException]
        {
            write-host "No access to the registry. Please launch this function with elevated privileges."
        }
        catch
        {
            write-host "An unknown error occured : $_ "
        }
    }

    End
    {
    }
}


#endregion Functions


# START SCRIPT
$classname = "HP_DockAccessory"
$ConnectedDock = Get-WmiObject -Class $classname  -Namespace "Root\$namespace"

if ($ConnectedDock){

    [String]$ProductName = $($ConnectedDock.ProductName)
    $ProductName = $ProductName.Replace(" ","")
    $ID = "$($ProductName)_$($ConnectedDock.SerialNumber)"
    $Date = (get-date -uformat "%Y%m%d_%T")
    $keyValue = "ID"

    New-Variable -Name "$($AttributePrefix)$keyValue" -Value $ID -Force
    New-Variable -Name "$($AttributePrefix)SerialNumber" -Value $ConnectedDock.SerialNumber -Force
    New-Variable -Name "$($AttributePrefix)FirmwarePackageVersion" -Value $ConnectedDock.FirmwarePackageVersion -Force
    New-Variable -Name "$($AttributePrefix)ProductName" -Value $ConnectedDock.ProductName -Force
    New-Variable -Name "$($AttributePrefix)MACAddress" -Value $ConnectedDock.MACAddress -Force
	New-Variable -Name "$($AttributePrefix)LastDateTime" -Value $Date -Force

    $customAttributes = Get-Variable -Name "$AttributePrefix*"

    if ($PSBoundParameters.ContainsKey("WMI"))
    {
        New-WMINamespace -Namespace $Namespace
        New-WMIClass -Namespace $Namespace -Class $Class -Attributes $customAttributes -Key $keyValue
        New-WMIClassInstance -Namespace $Namespace -Class $Class -Attributes $customAttributes
    }

    if ($PSBoundParameters.ContainsKey("Registry"))
    {
        foreach ($attr in $customAttributes)
        {
            $attr.Name -match "$AttributePrefix(?<attributeName>.*)" | Out-Null
            $attrName = $matches['attributeName']

            if ($attr.Value) 
            {
                $attrVal = $attr.Value
            } 
            else 
            {
                $attrVal = ""
            }
        
            Write-Verbose "Setting registry value named $attrName to $attrVal"



            New-RegistryItem -Key "\HP\$($Class)\$ID" -ValueName $attrName -Value $attrVal

        }
    }
}