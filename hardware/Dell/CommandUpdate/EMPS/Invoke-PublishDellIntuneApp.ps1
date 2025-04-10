#https://github.com/dell/Endpoint-Management-Script-Library/blob/main/Intune%20Scripts/EnterpriseAppDeployment/Dell_Intune_App_Publish_1.0.ps1


Function Invoke-PublishDellIntuneApp {
    <#
_author_ = Poluka, Muni Sekhar <muni.poluka@dell.com>
_version_ = 1.0
#>

<#
/********************************************************************************

/* DELL PROPRIETARY INFORMATION

*
* This software contains the intellectual property of Dell Inc. Use of this software and the intellectual property
* contained therein is expressly limited to the terms and conditions of the License Agreement under which it is
* provided by or on behalf of Dell Inc. or its subsidiaries.

*

* Copyright 2025 Dell Inc. or its subsidiaries. All Rights Reserved.

*

*  DELL INC. MAKES NO REPRESENTATIONS OR WARRANTIES ABOUT THE SUITABILITY OF THE SOFTWARE, EITHER
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.  DELL SHALL NOT BE LIABLE FOR ANY DAMAGES
* SUFFERED BY LICENSEE AS A RESULT OF USING, MODIFYING OR DISTRIBUTING THIS SOFTWARE OR ITS
* DERIVATIVES.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

*/
#>

<#
.Synopsis
    This script helps Dell Customers to Publish Dell Applications to the respective Intune Tenant.

.Description
     This file when invoked will do the below tasks
        1. show the UI to user to select required application
        2. Download the application that is posted for admin portal production to customer system
        3. Extract the contents and read the CreateAPPConfig.json file
        4. create win32_Lob App in intune
        5. Get APP file version
        6. Upload and commit intunewin file to Azure Storage Blob
        7. Update the file version in the Intune application

#>

# The below code defines the parameters that accepts the input from user
param(
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [System.String] $ClientId,
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [System.String] $TenantId,
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [System.String] $ClientSecret,
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [System.String] $CertThumbprint,
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [System.String] $AppName,
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [System.String] $CabPath,
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [System.String] $proxy,
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [switch] $help,
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [switch] $supportedapps,
    [Parameter(Mandatory = $False, Position = 0, ValueFromPipeline = $false)] [switch] $logpath
)

$error_code_mapping = @{"Success" = 0; "Invalid_App_Name" = 1; "Invalid_Parameters_passed_to_script" = 2; "File_Download_Failure" = 3; "Content_Extraction_Failure" = 4; "json_file_parsing_failure" = 5; "MSAL_Token_Generation_error" = 6; "Win32_LOB_App_creation_error" = 7; "Win32_file_version_creation_error" = 8; "Win32_Lob_App_Place_holder_ID_creation_error" = 9; "Azure_Storage_URI_creation_error" = 10; "file_chunk_calculating_uploading_error" = 11; "upload_chunks_failure" = 12; "committing_file_upload_error" = 13; "Win32_App_file_version_updation_error" = 14; "Sig_verification_failure" = 15; "Prerequisite_check_failure" = 16; "Admin_Privilege_Required" = 17; "Directory_path_not_Exist" = 18; "dependency_update_failure" = 19; "Certificate_Not_Found" = 20;"SectionName_Not_present" = 21}

$Global:intune_config_file_download_url = "https://dellupdater.dell.com/non_du/ClientService/endpointmgmt/Intune_Config.cab"

function secure_dir_file_creation {
    # The below statements are to define global variables
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH_mm_ss"
    $basedir1 = Join-Path -Path $env:ProgramData -ChildPath "Dell" 
    $basedir2 = Join-Path -Path $env:ProgramData -ChildPath "Dell\Intune_App_Publish_Script"
    $GLobal:logdir = Join-Path -Path $env:ProgramData -ChildPath "Dell\Intune_App_Publish_Script\Log" 
    $Global:downloads_dir = Join-Path -Path $env:ProgramData -ChildPath "Dell\Intune_App_Publish_Script\Downloads"
    
    $dirs_list = @($basedir2, $Global:logdir, $Global:downloads_dir)
    if (Test-Path -Path $Global:logdir) {
            $Global:log_file_path = Join-Path -Path $Global:logdir -ChildPath "Intune_App_Publish_log_$timestamp.txt"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Path $Global:logdir exists and hence not creating and re-applying ACL's"
            
        }   
    if (Test-Path -Path $basedir1) {
        $Global:log_file_path = Join-Path -Path $Global:logdir -ChildPath "Intune_App_Publish_log_$timestamp.txt"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Path $basedir1 exists and hence not creating and re-applying ACL's"
    }
    else {
        New-Item -Path $basedir1 -ItemType Directory
        $Global:log_file_path = Join-Path -Path $Global:logdir -ChildPath "Intune_App_Publish_log_$timestamp.txt"
    }
    foreach ($dir in $dirs_list) {
        if ((-Not (Test-Path $dir))) {
            New-Item -Path $dir -ItemType Directory
            Set-CustomAcl -Path $dir
        }
        else {
            Set-CustomAcl -Path $dir 
                
        }
    }
    $Global:log_file_path = Join-Path -Path $GLobal:logdir -ChildPath "Intune_App_Publish_log_$timestamp.txt"
    
}

# The below function also to create directory or file and set ACl's and also verify symlinks if the directory already exists
# The below function is to verify the ACL's of the folder and if not reset to the desired ACL's
# Desired ACL's
# System: Full Permisions
# Administrator: Full Permissions
# User: Read & Execute Permissions
function Set-CustomAcl {
    param (
        [string]$Path
    )
    # Check if the provided path exists
    if (-Not (Test-Path $Path)) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The specified path does not exist: $Path"
    }
    # Determine if the path is a directory or a file
    $isDirectory = (Get-Item $Path).PSIsContainer
    # Get the parent directory and item name
    $parentDir = (Get-Item $Path).PSParentPath -replace 'Microsoft.PowerShell.Core\\FileSystem::', ''
    $itemName = (Get-Item $Path).Name
    # Handle symlinks and existing items
    if ((Get-Item $Path).Attributes -match "ReparsePoint") {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Removing Symlink: $Path"
        Remove-Item -LiteralPath $Path -Force -Recurse -Confirm:$false
        $newPath = Join-Path -Path $parentDir -ChildPath $itemName
        if ($isDirectory) {
            # If it's a directory, recreate the directory
            $null = New-Item -Path $newPath -ItemType Directory -Force
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Recreating directory: $newPath"
        }
        else {
            # If it's a file, recreate the file
            $null = New-Item -Path $newPath -ItemType File -Force
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Recreating file: $newPath"
        }
        $Path = $newPath
    } 

    # Get the ACL for the newly created directory or file
    $ACL = Get-Acl -Path $Path 
    # Remove inheritance and strip all existing permissions
    $ACL.SetAccessRuleProtection($true, $false) # Enable protection but do not preserve inherited rules
    $ACL.Access | ForEach-Object { $ACL.RemoveAccessRule($_) } > $null  
    # Add the specified access rules
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "NT AUTHORITY\SYSTEM",
        "FullControl",
        "ContainerInherit, ObjectInherit",
        "None",
        "Allow"
    )
    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "BUILTIN\Administrators",
        "FullControl",
        "ContainerInherit, ObjectInherit",
        "None",
        "Allow"
    )
    $UserRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "BUILTIN\Users",
        "ReadAndExecute",
        "ContainerInherit, ObjectInherit",
        "None",
        "Allow"
    )
    $UserRule1 = New-Object System.Security.AccessControl.FileSystemAccessRule(
        "BUILTIN\Users",
        "Write",
        "ContainerInherit, ObjectInherit",
        "None",
        "Allow"
    )

    $ACL.AddAccessRule($systemRule)
    $ACL.AddAccessRule($adminRule)
    $ACL.AddAccessRule($UserRule)
    $ACL.AddAccessRule($UserRule1)

    # Apply the modified ACL back to the directory or file
    Set-Acl -Path $Path -AclObject $ACL
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Permissions updated for: $Path"
}

# The below function is to enable logging module
function Write-Log {
    
    Add-Content -Path $Global:log_file_path -Value $Global:logMessages
}

# The below function is to verify if the script is running with admin privileges
function verify_admin_privileges {
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "You do not have Administrator rights to run this script. Please re-run this script as an Administrator.", $error_code_mapping.Admin_Privilege_Required
        Exit $error_code_mapping.Admin_Privilege_Required
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script is running with admin privileges"
    }
}

function prerequisite_verification {
    # The below check is for checking if MSAL library is installed or not
    if (Get-Module -ListAvailable -Name "MSAL.PS") {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - MSAL.PS PowerShell module exists"
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - MSAL.PS does not exist on system, please install and try again"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Exeution terminated with return code ", $error_code_mapping.Prerequisite_check_failure
        Write-Log
        Exit $error_code_mapping.Prerequisite_check_failure
    }
}


# The below function is to verify the digital signature of the file
function sig_verification {
    param (
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    $signature = Get-AuthenticodeSignature -FilePath $FilePath

    if ($signature.Status -eq "Valid") {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The digital signature of $FilePath is valid."
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Digital Signature check Failed for $FilePath"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Exeution terminated with return code ", $error_code_mapping.Sig_verification_failure
        Write-Log
        Exit $error_code_mapping.Sig_verification_failure

    }
}

# The below fucntion is to get the respective application intune cabinet file URL from Intune_Config.json file based on User entered data
function input_processing {
    param (
        [Parameter(Mandatory = $true)] [string] $AppName
    )
    # The below code is to download the config json cabinet file
    $download_files_response = download_files -downloadurl $Global:intune_config_file_download_url -downloadPath $Global:downloads_dir -proxy $proxy
    $json_downloadPath = $download_files_response.downloadPath
    $json_filename = $download_files_response.filename

    # The below code is to extract the config json cabinet file
    $Extract_Cabinet_path = Extract_CabinetFile -downloadPath $json_downloadPath -filename $json_filename

    # The below code is to read the specific app section from the config json file based on user entred app name
    $intune_config_json_data = read_json_section -json_file_path $Extract_Cabinet_path -SectionName $AppName

    # The below is to pasre and read the version and download URL from the config json file
    $intune_config_json_data = $intune_config_json_data | ConvertFrom-Json
    $DependentApp_Version = $null
    foreach ($item1 in $intune_config_json_data) {
        $dependencyAppDisplayname = $null
        $dependencyAppversion = $null
        $dependencyAppOperator = $null
        if ($null -eq $DependentApp_Version) {
            $DependentApp_displayname = $item1.displayname
            $DependentApp_Version = $item1.version
            $DependentAppdownloadurl = $item1.downloadurl
        }
        elseif ($item1.version -gt $DependentApp_Version) {
            $DependentApp_displayname = $item1.displayname
            $DependentApp_Version = $item1.version
            $DependentAppdownloadurl = $item1.downloadurl
        }
        
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Displayname and version from config json file is ", $DependentApp_displayname, $DependentApp_Version
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Download URL from config json file is ", $DependentAppdownloadurl

        if ($item1.dependencyApp) {
            # The below code is to fetch the dependency app name, version, operator from the config json file
            $parsedData = $item1.dependencyApp | ForEach-Object {
                if ($_ -match "@{(.+)}") {
                    $obj = @{}
                    $_ -match "@{(.+)}" | Out-Null
                    $pairs = $matches[1] -split "; "
                    foreach ($pair in $pairs) {
                        $key, $value = $pair -split "="
                        $obj[$key.Trim()] = $value.Trim()
                    }
                    [PSCustomObject]$obj
                } else {
                    $_
                }
            }
            $dependencyAppDisplayname = $parsedData[0].name
            $dependencyAppversion = $parsedData[0].version
            $dependencyAppOperator = $parsedData[0].operator
        }
    }
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency App name and version from config json file is ", $dependencyAppDisplayname, $dependencyAppversion
    if ($null -eq $dependencyAppDisplayname) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - No dependency app found in config json file"
    }
    else {
        $final_dependency_App_download_url = ""
        # The below code is to read the specific app section from the config json file based on user entred app name
        $Dependency_App_intune_config_json_data = read_json_section -json_file_path $Extract_Cabinet_path -SectionName $dependencyAppDisplayname

        foreach ($item2 in $Dependency_App_intune_config_json_data) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Displayname and version from dependency app config json file is ", $item2.displayname, $item2.version
            $item2 = $item2 | ConvertFrom-Json
            if ($dependencyAppOperator.ToLower() -eq "equal") {
                if ($item2.version -eq $dependencyAppversion) {
                    $final_dependency_App_Version = $item2.version
                    $final_dependency_App_download_url = $item2.downloadurl
                }
            }
            elseif ($dependencyAppOperator.ToLower() -eq "greaterthan") {
                if ($item2.version -gt $dependencyAppversion) {
                    if ($null -eq $final_dependency_App_Version) {
                        $final_dependency_App_Version = $item2.version
                        $final_dependency_App_download_url = $item2.downloadurl
                    }
                    elseif ($item2.version -gt $final_dependency_App_Version) {
                        $final_dependency_App_Version = $item2.version
                        $final_dependency_App_download_url = $item2.downloadurl
                    }
                }
            }

            elseif ($dependencyAppOperator.ToLower() -eq "greaterthanequal") {
                if ($item2.version -ge $dependencyAppversion) {
                    if ($null -eq $final_dependency_App_Version) {
                        $final_dependency_App_Version = $item2.version
                        $final_dependency_App_download_url = $item2.downloadurl
                    }
                    elseif ($item2.version -ge $final_dependency_App_Version) {
                        $final_dependency_App_Version = $item2.version
                        $final_dependency_App_download_url = $item2.downloadurl
                    }
                }
            }
        }

    }
    $download_url_responses = @{
        "dependantAppURL"  = $DependentAppdownloadurl;
        "dependencyAppURL" = $final_dependency_App_download_url
    }
    return $download_url_responses
    
}

# The below function is resposible to download the application that is posted for admin portal production to customer system based on user-selection from UI
function download_files {
    param(
        [Parameter(Mandatory = $true)] [string] $downloadurl,
        [Parameter(Mandatory = $true)] [string] $downloadPath,
        [Parameter(Mandatory = $false)] [string] $proxy
    )
    try {
        $filename = ($downloadurl -split "/")[-1]
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Filename from downlod files function is ", $filename
        $downloadPath1 = Join-Path -Path $downloadPath -ChildPath ($filename.Replace(".cab", ""))
        $null=New-item -ItemType Directory -Path $downloadPath1 -Force
        Get-ChildItem -Path $downloadPath1 -Include *.* -File -Recurse | ForEach-Object { $_.Delete() }
        $download_full_path = Join-Path -Path $downloadPath1 -ChildPath $filename
        $userAgent = 'Mozilla/5.0 (Windows NT 11.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36'
        if ($proxy -ne "") {
            Invoke-WebRequest -Uri $downloadurl -OutFile $download_full_path -UserAgent $userAgent -Proxy $proxy 
        }
        else {
            $download_status = Invoke-WebRequest -Uri $downloadurl -OutFile $download_full_path -UserAgent $userAgent -PassThru
            
        }
        if ($?) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Downloaded the file successfully in location ", $downloadPath
            if ([System.IO.File]::Exists($download_full_path)) {
                sig_verification -FilePath $download_full_path
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - File exists in the location ", $download_full_path
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Download path without filename, inside download files function ", $downloadPath1
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Filename inside download files function ", $filename
                $downloaad_files_response = @{
                    "downloadPath" = $downloadPath1;
                    "filename"     = $filename
                }
                return $downloaad_files_response
            }
            else {
                
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - File does not exists in the location ", $download_full_path
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Exeution terminated with return code ", $error_code_mapping.File_Download_Failure
                Write-Log
                Exit $error_code_mapping.File_Download_Failure
            }
        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to download the file"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Exeution terminated with return code ", $error_code_mapping.File_Download_Failure
            Write-Log
            Exit $error_code_mapping.File_Download_Failure
        }
    }
    catch {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Exception during file download process ", $_.Exception.Message
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Exeution terminated with return code ", $error_code_mapping.File_Download_Failure
        Write-Log
        Exit $error_code_mapping.File_Download_Failure
    }
}

# The below function is resposible to extract the contents on the end-user system
function Extract_Archive {
    param (
        [Parameter(Mandatory = $true)] [string] $downloadPath,
        [Parameter(Mandatory = $true)] [string] $filename
    )
    $intunewinzipfilePath = Join-Path -Path $downloadPath -ChildPath $filename
    Expand-Archive -LiteralPath $intunewinzipfilePath -DestinationPath $downloadPath -Force
    if ($?) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Extracted the contents successfully in location $downloadPath"
        $intunewinfilepath = Join-Path -Path $downloadPath -ChildPath "IntunePackage.intunewin"
        $CreateAPPConfigPath = Join-Path -Path $downloadPath -ChildPath "AppConfig.json"
        if ((Test-Path $intunewinfilepath) -and (Test-Path $CreateAPPConfigPath)) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Extracted the contents successfully in location $downloadPath"
            return $intunewinfilepath, $CreateAPPConfigPath
        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Extracted the contents successfully in location $downloadPath"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with return code ", $error_code_mapping.Content_Extraction_Failure
            Write-Log
            Exit $error_code_mapping.Content_Extraction_Failure
        }
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to extract the Archive contents"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with return code ", $error_code_mapping.Content_Extraction_Failure
        Write-Log
        Exit $error_code_mapping.Content_Extraction_Failure
    }
}

# The below function is responsible to extract the contents inside a cabinet file
function Extract_CabinetFile {
    param (
        [Parameter(Mandatory = $true)] [string] $downloadPath,
        [Parameter(Mandatory = $true)] [string] $filename
    )
    
    $intunewincabfilePath = Join-Path -Path $downloadPath -ChildPath $filename
    $cabFile = New-Object -ComObject Shell.Application
    $cabFile.Namespace($downloadPath).CopyHere($cabFile.Namespace($intunewincabfilePath).Items())
    if ($?) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Extracted the cabinet file contents successfully in location $downloadPath"
        $intunewinfilepath = Join-Path -Path $downloadPath -ChildPath "IntunePackage.intunewin"
        $CreateAPPConfigPath = Join-Path -Path $downloadPath -ChildPath "AppConfig.json"
        $intune_config_file = Join-Path -Path $downloadPath -ChildPath "Intune_Config.json"
        if ((Test-Path $intunewinfilepath) -and (Test-Path $CreateAPPConfigPath)) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Extracted the cabinet file contents successfully in location $downloadPath"
            return $intunewinfilepath, $CreateAPPConfigPath
        }
        elseif (Test-Path $intune_config_file) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Extracted the cabinet file contents successfully in location $downloadPath"
            return $intune_config_file
            
        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Extraction of cabinet file contents is unsuccessful $downloadPath"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with return code ", $error_code_mapping.Content_Extraction_Failure
            Write-Log
            Exit $error_code_mapping.Content_Extraction_Failure
        }
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to extract the Cabinet file contents"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with return code ", $error_code_mapping.Content_Extraction_Failure
        Write-Log
        Exit $error_code_mapping.Content_Extraction_Failure
    }
}

# The below function is resposible to read the CreateAPPConfig.json file
function read_json_section {
    param (
        [Parameter(Mandatory = $true)] [string] $json_file_path,
        [Parameter(Mandatory = $true)] [string] $SectionName
    )
    $json_data = Get-Content -Path $json_file_path | ConvertFrom-Json
    if ($?) {
        if (-not $json_data.PSObject.Properties[$sectionName]) {
            Write-Log
            Exit $error_code_mapping.SectionName_Not_present
        }
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Read the CreateAPPConfig.json file successfully"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Display Name that is being read is : $($json_data.$sectionName)"
        $section_data = $json_data.$sectionName | ConvertTo-Json
        return $section_data
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to read the CreateAPPConfig.json file"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution terminated with return code ", $error_code_mapping.json_file_parsing_failure
        Write-Log
        Exit $error_code_mapping.json_file_parsing_failure
    }
}

# The below function is resposible to create the Access token by using the client id, tenant id and client secret
function generate_access_token_using_Client_Secret {
    param (
        [Parameter(Mandatory = $true)] [string] $ClientId,
        [Parameter(Mandatory = $true)] [string] $TenantId,
        [Parameter(Mandatory = $true)] [string] $ClientSecret
    )
    # Create the Connection details
    $Global:connectionDetails = @{
        'TenantId'     = $TenantId;
        'ClientId'     = $ClientId;
        'ClientSecret' = $ClientSecret | ConvertTo-SecureString -AsPlainText -Force
    }
    try{
        $token = Get-MsalToken @Global:connectionDetails
    }
    catch{
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to generate the Access token"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with return code ", $error_code_mapping.MSAL_Token_Generation_error
        Write-Log
        Exit $error_code_mapping.MSAL_Token_Generation_error
    }
    if ($?) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Generated the Access token successfully"
        $tokenauthorizationheader = $token.CreateAuthorizationHeader()
        return $tokenauthorizationheader
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to generate the Access token"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with return code ", $error_code_mapping.MSAL_Token_Generation_error
        Write-Log
        Exit $error_code_mapping.MSAL_Token_Generation_error
    }  
}

# The below function is resposible to create the Access token by using the client id, tenant id and client secret
function generate_access_token_using_Client_Cert_Thumbprint {
    param (
        [Parameter(Mandatory = $true)] [string] $ClientId,
        [Parameter(Mandatory = $true)] [string] $TenantId,
        [Parameter(Mandatory = $true)] [string] $CertThumbprint
    )

    $clientCertificate = Get-Item "Cert:\CurrentUser\My\$CertThumbprint" -ErrorAction SilentlyContinue
    if ($clientCertificate) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Certificate found with thumbprint under current user cert store "

    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Certificate not found with thumbprint under current user cert store "
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with return code ", $error_code_mapping.Certificate_Not_Found
        Write-Log
        Exit $error_code_mapping.Certificate_Not_Found
        
    }
    $token = Get-MsalToken -ClientId $ClientId -TenantId $TenantId -ClientCertificate $clientCertificate
    if ($?) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Generated the Access token successfully"
        $tokenauthorizationheader = $token.CreateAuthorizationHeader()
        return $tokenauthorizationheader
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to generate the Access token"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with return code ", $error_code_mapping.MSAL_Token_Generation_error
        Write-Log
        Exit $error_code_mapping.MSAL_Token_Generation_error
    }
    
}

# The below function is resopsible to create the win32_Lob App in intune
function win32_LobApp_creation {
    
    param (
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader,
        [Parameter(Mandatory = $true)] [string] $createAppConfig_createApp
    )
        $authHeader = @{
            'Authorization' = $tokenauthorizationheader
        }
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - inside win32_LobApp_creation"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Createapp content is:", $createAppConfig_createApp
        
        $win32LobUrl = 'https://graph.microsoft.com/beta/deviceAppManagement/mobileApps'
        $win32LobApp = Invoke-RestMethod -Uri $win32LobUrl -Body $createAppConfig_createApp -Headers $authHeader -Method "POST" -ContentType 'application/json'
        if ($?) {
            $win32LobAppId = $win32LobApp.id
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Created the win32_Lob App successfully and the win32LobAppId is ", $win32LobAppId
            return $win32LobAppId

        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to create the win32_Lob App"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.Win32_LOB_App_creation_error
            Write-Log
            Exit $error_code_mapping.Win32_LOB_App_creation_error
        }
}

# The below function is resposible to get APP file version
function win32_LobApp_file_version {

    param (
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader,
        [Parameter(Mandatory = $true)] [string] $win32LobAppId
    )
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Inside win32_LobApp_file_version"
    $authHeader = @{
        'Authorization' = $tokenauthorizationheader
    }
    $Win32LobVersionUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions" -f $win32LobAppId
    $win32LobAppVersionRequest = Invoke-RestMethod -Uri $Win32LobVersionUrl -Method "POST" -Body "{}" -Headers $authHeader -ContentType 'application/json'
    if ($?) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - APP file version request successful"
        $win32LobAppVersion = $win32LobAppVersionRequest.id
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - APP file version is", $win32LobAppVersion
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Got the APP file version successfully"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Got the APP file version successfully"
        return  $win32LobAppVersion
        
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to get the APP file version"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.Win32_file_version_creation_error
        Write-Log
        Exit $error_code_mapping.Win32_file_version_creation_error
    }    
}

# This function code is reponsible for creating the place holder for intune file version and create the intune URI for file.
function win32LobApp_placeholder {
    param (
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader,
        [Parameter(Mandatory = $true)] [string] $createAppConfig_createFile,
        [Parameter(Mandatory = $true)] [string] $win32LobAppId,
        [Parameter(Mandatory = $true)] [string] $win32LobAppVersionId
    )
    $authHeader = @{
        'Authorization' = $tokenauthorizationheader
    }

    $Win32LobFileUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files" -f $win32LobAppId, $win32LobAppVersionId
    
    $Win32LobPlaceHolder = Invoke-RestMethod -Uri $Win32LobFileUrl -Method "POST" -Body $createAppConfig_createFile -Headers $authHeader -ContentType 'application/json'
    if ($?) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Created the place holder for intune file version successfully"
        $Win32LobPlaceHolderId = $Win32LobPlaceHolder.id
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32placeholderId:", $Win32LobPlaceHolderId
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Created the place holder for intune file version successfully"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - **********************: ", $Win32LobPlaceHolder.size
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - **********************: ", $Win32LobPlaceHolder.sizeEncrypted
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Created the place holder for intune file version successfully"
        return $Win32LobPlaceHolderId
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to create the place holder for intune file version"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.Win32_Lob_App_Place_holder_ID_creation_error
        Write-Log
        Exit $error_code_mapping.Win32_Lob_App_Place_holder_ID_creation_error
    }
}

# The below function is to check if the above function for creating the place holder is handled properly or not.
function  check_win32LobApp_placeholder_status {
    param (
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader,
        [Parameter(Mandatory = $true)] [string] $win32LobAppId,
        [Parameter(Mandatory = $true)] [string] $win32LobAppVersionId,
        [parameter(Mandatory = $true)] [string] $Win32LobPlaceHolderId
    )
    $authHeader = @{
        'Authorization' = $tokenauthorizationheader
    }
    $azure_upload_state = ""
    while ($azure_upload_state -ne "azureStorageUriRequestSuccess") {
        $storageCheckUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files/{2}" -f $win32LobAppId, $win32LobAppVersionId, $Win32LobPlaceHolderId
        $storageCheck = Invoke-RestMethod -Uri $storageCheckUrl -Method "GET" -Headers $authHeader
        if ($?) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Checked the status of the place holder for intune file version successfully"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The status of the place holder for intune file version is ", $storageCheck
            $azure_upload_state = $storageCheck.uploadState
            $azureStorageUri = $storageCheck.azureStorageUri
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The azure storage URI is ", $azureStorageUri
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Checked the status of the place holder for intune file version successfully"
            if ($storageCheck.uploadState -eq "azureStorageUriRequestSuccess") {
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Azure storage status is success"
                return $azureStorageUri
            }
            
        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to check the status of the place holder for intune file version"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.Azure_Storage_URI_creation_error
            Write-Log
            Exit $error_code_mapping.Azure_Storage_URI_creation_error
        }
    }
}

# The below set of functions is to upload the file to Win32LobApp in Intune and this contains the below functions
# 1. Extract intunewin file to an unencrypted file ( this will be skipped as IWCS already gives us the unencrypted file)
# 2. Chunk extracted file
# 3. Upload the chunks
# 4. Commit the upload
# 5. Update the file version in the Intune application

# 1. The below function is to extract intunewin file to an unencrypted file ( this will be skipped as IWCS already gives us the unencrypted file)

# 2., 3. The below function is to chunk extracted file
function calculate_create_upload_chunks {
    param (
        [Parameter(Mandatory = $true)] [string] $intunewinfilepath,
        [Parameter(Mandatory = $true)] [string] $azureStorageUri,
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader
    )
    $authHeader = @{
        'Authorization' = $tokenauthorizationheader
    }
    # Calculate the chunk size
    $ChunkSizeInBytes = 1024l * 1024l * 6l;
    $SASRenewalTimer = [System.Diagnostics.Stopwatch]::StartNew()
    $FileSize = (Get-Item -Path $intunewinfilepath).Length
    $ChunkCount = [System.Math]::Ceiling($FileSize / $ChunkSizeInBytes)
    $BinaryReader = New-Object -TypeName System.IO.BinaryReader([System.IO.File]::Open($intunewinfilepath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite))

    # create and upload the chunks
    $ChunkIDs = @()
    for ($Chunk = 0; $Chunk -lt $ChunkCount; $Chunk++) {
        $ChunkID = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Chunk.ToString("0000")))
        $ChunkIDs += $ChunkID
        $Start = $Chunk * $ChunkSizeInBytes
        $Length = [System.Math]::Min($ChunkSizeInBytes, $FileSize - $Start)
        $Bytes = $BinaryReader.ReadBytes($Length)
        $CurrentChunk = $Chunk + 1

        $Uri = "{0}&comp=block&blockid={1}" -f $azureStorageUri, $ChunkID
        $ISOEncoding = [System.Text.Encoding]::GetEncoding("iso-8859-1")
        $EncodedBytes = $ISOEncoding.GetString($Bytes)
        $Headers = @{
            "x-ms-blob-type" = "BlockBlob"
        }
        $UploadResponse = Invoke-WebRequest $Uri -Method "Put" -Headers $Headers -Body $EncodedBytes
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - upload response from calculate_create_upload_chunks function is : ", $UploadResponse.StatusCode
        if ($UploadResponse.StatusCode -eq 201) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Uploaded the chunk $CurrentChunk of $ChunkCount"
        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to upload the chunk $CurrentChunk of $ChunkCount"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.file_chunk_calculating_uploading_error
            $BinaryReader.Close()
            $BinaryReader.Dispose()
            Write-Log
            Exit $error_code_mapping.file_chunk_calculating_uploading_error
        }
    }

    # finalise the chunk list and send XML list to the storage location
    $finalChunkUri = "{0}&comp=blocklist" -f $azureStorageUri
    $XML = '<?xml version="1.0" encoding="utf-8"?><BlockList>'
    foreach ($Chunk in $ChunkIDs) {
        $XML += "<Latest>$($Chunk)</Latest>"
    }
    $XML += '</BlockList>'
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - XML file content is : $XML"

    $uploadresponse1 = Invoke-WebRequest -Uri $finalChunkUri -Method "Put" -Body $XML
    if ($?) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Uploaded the chunks successfully"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The upload status is ", $uploadresponse1.StatusCode
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Response from calculate_create_upload_chunks function for finalise chunk list and send xml storage location is : ", $uploadresponse1.statusCode
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Uploaded the chunks successfully"
        if ($uploadresponse1.StatusCode -eq 201) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Uploaded the chunks successfully"
            $BinaryReader.Close()
            $BinaryReader.Dispose()
            return $ChunkIDs
        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to upload the chunks"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.upload_chunks_failure
            $BinaryReader.Close()
            $BinaryReader.Dispose()
            Write-Log
            Exit $error_code_mapping.upload_chunks_failure
        }
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to upload the chunks"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.upload_chunks_failure
        $BinaryReader.Close()
        $BinaryReader.Dispose()
        Write-Log
        Exit $error_code_mapping.upload_chunks_failure
    }
    
}

# 4. The below function is to commit the upload
function commit_upload_status {
    param (
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader,
        [Parameter(Mandatory = $true)] [string] $createAppConfig_commitFile,
        [Parameter(Mandatory = $true)] [string] $win32LobAppId,
        [Parameter(Mandatory = $true)] [string] $win32LobAppVersionId,
        [Parameter(Mandatory = $true)] [string] $Win32LobPlaceHolderId
    )
    $authHeader = @{
        'Authorization' = $tokenauthorizationheader
    }

    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - createAppConfig_commitFile from commit_upload_status function is - $createAppConfig_commitFile"
    # The below code is to commit the commit the upload
    $storageCheckUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/microsoft.graph.win32LobApp/contentVersions/{1}/files/{2}" -f $win32LobAppId, $win32LobAppVersionId, $Win32LobPlaceHolderId

    $CommitResourceUri = "{0}/commit" -f $storageCheckUrl

    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - CommitResourceUri is - ", $CommitResourceUri
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - tokenauthorizationheader is - ", $tokenauthorizationheader

    $commit_upload_status_respnse = Invoke-RestMethod -uri $CommitResourceUri -Method "POST" -Body $createAppConfig_commitFile -Headers $authHeader -ContentType 'application/json'
    if ($?) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The commit status is ", $commit_upload_status_respnse
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Committed the upload successfully"
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to commit the upload"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.commit_upload_status
        Write-Log
        Exit $error_code_mapping.commit_upload_status
    }
    # The below code is to check the commit status
    $commit_status_upload_state = ""
    $i = 0
    while ($commit_status_upload_state -ne "commitFileSuccess") {
        $CommitStatus = Invoke-RestMethod -uri $storageCheckUrl  -Method "GET" -Headers $authHeader
        if ($?) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The upload is committed successfully"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The commit status is $CommitStatus"
            $commit_status_upload_state = $CommitStatus.uploadState
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The commit status from commit_upload_status function is $commit_status_upload_state"
            
            Start-Sleep -Milliseconds 5000
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $i seconds elapsed"
            $i += 1
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The value of i is $i"
            if ($i -eq 5) {
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The upload is not committed successfully"
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.commit_upload_status
                Write-Log
                Exit $error_code_mapping.commit_upload_status
            }
        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to get the commit status"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.commit_upload_status
            Write-Log
            Exit $error_code_mapping.commit_upload_status
        }
    }
    return $commit_status_upload_state
}

# 5. The below function is to update the file version in the Intune application
function update_file_version {
    param (
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader,
        [Parameter(Mandatory = $true)] [string] $win32LobAppId,
        [Parameter(Mandatory = $true)] [string] $win32LobAppVersionId
    )
    $authHeader = @{
        'Authorization' = $tokenauthorizationheader
    }
    $Win32AppCommitBody = [ordered]@{
        "@odata.type"             = "#microsoft.graph.win32LobApp"
        "committedContentVersion" = $win32LobAppVersionId
    } | ConvertTo-Json
    $win32LobUrl = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps"
    $Win32AppUrl = "{0}/{1}" -f $win32LobUrl, $win32LobAppId
    $j = 0
    while ($j -lt 5) {
        $update_file_version_response = Invoke-WebRequest -uri $Win32AppUrl -Method "PATCH" -Body $Win32AppCommitBody -Headers $authHeader -ContentType 'application/json'
        
        if ($update_file_version_response.StatusCode -eq 204) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Updated the file version in the Intune application successfully"
            $Global:logMessages += $update_file_version_response.uploadState
            Start-Sleep -Milliseconds 5000 
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - $i seconds elapsed"
            $j += 1
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The value of i is $j"
            $update_file_version_published_state = Invoke-WebRequest -uri $Win32AppUrl -Method "GET" -Headers $authHeader -ContentType 'application/json'
            $update_file_version_published_state_response = $update_file_version_published_state.Content | ConvertFrom-Json
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The file version is updated successfully"
            if ($update_file_version_published_state.StatusCode -eq 200 -And $update_file_version_published_state_response.publishingState -eq "published") {
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The file version is updated successfully"
                return $update_file_version_published_state_response.publishingState
            }
            
            if ($j -eq 5) {
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The upload is not committed successfully"
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.Win32_App_file_version_updation_error
                Write-Log
                Exit $error_code_mapping.Win32_App_file_version_updation_error
            }
        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to update the file version in the Intune application"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.Win32_App_file_version_updation_error
            Write-Log
            Exit $error_code_mapping.Win32_App_file_version_updation_error
        }
    }
    if ($update_file_version_published_state_response.publishingState -ne "published") {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - The file version is not updated successfully"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution Terminated with error code ", $error_code_mapping.Win32_App_file_version_updation_error
        Write-Log
        Exit $error_code_mapping.Win32_App_file_version_updation_error
    }
}

function Intune_App_Publish {

    param (
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader,
        [Parameter(Mandatory = $true)] [string] $CreateAPPConfigfilePath,
        [Parameter(Mandatory = $true)] [string] $intunewinfilepath
    )

    # The below function call is to read the create App section of the JSON file
    $createAppConfig_createApp = read_json_section -json_file_path $CreateAPPConfigfilePath -SectionName "createApp"
        
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - ***********************"
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Create App section data from createappconfig file from main function is : $createAppConfig_createApp"

    # The below function call is to create the win32_Lob App in intune
    $win32LobAppId = win32_LobApp_creation -tokenauthorizationheader $tokenauthorizationheader -createAppConfig_createApp $createAppConfig_createApp
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32LobAppId for the intune instance from main function is : $win32LobAppId"
    
    # The below function call is to get win32_LobApp file version
    $win32LobAppVersionId = win32_LobApp_file_version -tokenauthorizationheader $tokenauthorizationheader -win32LobAppId $win32LobAppId

    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32LobAppVersionID from main function is : $win32LobAppVersionId"
    
    # The below fucntion call is to fetch the createFile data from the createAppConfig.json file
    $createAppConfig_createFile = read_json_section -json_file_path $CreateAPPConfigfilePath -SectionName "createFile"
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Succesfully read the createappconfig json file createfile section from main fucntion is : $createAppConfig_createFile"

    # The below function call is to create place holder for intune file version
    $Win32LobPlaceHolderId = win32LobApp_placeholder -tokenauthorizationheader $tokenauthorizationheader -createAppConfig_createFile $createAppConfig_createFile -win32LobAppId $win32LobAppId -win32LobAppVersionId $win32LobAppVersionId
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32LobPlaceHolderId from main function is : $Win32LobPlaceHolderId"

    # The below fucntion call is to check if the above function for creating the place holder is handled properly or not.
    $azureStorageUri = check_win32LobApp_placeholder_status -tokenauthorizationheader $tokenauthorizationheader -win32LobAppId $win32LobAppId -win32LobAppVersionId $win32LobAppVersionId -Win32LobPlaceHolderId $Win32LobPlaceHolderId
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Azure Storage URI from main function is : $azureStorageUri"
    
    # 2., 3. The below function call is to calculate , create and upload chunks of the intunewin file
    calculate_create_upload_chunks -intunewinfilepath $intunewinfilepath -azureStorageUri $azureStorageUri -tokenauthorizationheader $tokenauthorizationheader
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Successfully uploaded the chunks of the intunewin file from main function"

    # The below function call is to fetch the commitFile section data from the createAppConfig.json file
    $createAppConfig_commitFile = read_json_section -json_file_path $CreateAPPConfigfilePath -SectionName "commitFile"
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - CommitFile section data from createappconfig json file from main function is : $createAppConfig_commitFile"

    # 4. The below function call is to commit the upload and check commit status
    $commit_status_upload_state = commit_upload_status -tokenauthorizationheader $tokenauthorizationheader -createAppConfig_commitFile $createAppConfig_commitFile -win32LobAppId $win32LobAppId -win32LobAppVersionId $win32LobAppVersionId -Win32LobPlaceHolderId $Win32LobPlaceHolderId
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Commit status upload state from main function is : $commit_status_upload_state"

    # 5. The below function call is to update the file version in the Intune application
    $upload_file_version_upload_state = update_file_version -tokenauthorizationheader $tokenauthorizationheader -win32LobAppId $win32LobAppId -win32LobAppVersionId $win32LobAppVersionId

    # The below function is check if win32 app has been successfully published or not
    return $win32LobAppId
}

function check_win32_App_Existenece_in_Intune {
    param (
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader,
        [Parameter(Mandatory = $true)] [string] $dependencyAppConfigfilepath
    )

    $authHeader = @{
        'Authorization' = $tokenauthorizationheader
    }
    $createAppConfig_createApp = read_json_section -json_file_path $dependencyAppConfigfilepath -SectionName "createApp"
    # Ftech the detection rules key from the createApp section
    
    $detectionRuletype = $createAppConfig_createApp | ConvertFrom-Json
    $detectionRuleInfo = $detectionRuletype.detectionRules
    $detectionRuletype = $detectionRuletype.detectionRules."@odata.type"
    $win32_App_Publisher_Filter = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?$filter=contains(publisher,'Dell')"
    $win32Apps_response_intune = Invoke-RestMethod -Uri $win32_App_Publisher_Filter -Method "GET" -Headers $authHeader -ContentType 'application/json'
    $win32Apps_response_intune1 = Invoke-WebRequest -Uri $win32_App_Publisher_Filter -Method "GET" -Headers $authHeader -ContentType 'application/json'
    if ($win32Apps_response_intune1.StatusCode -eq 200) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32 app found in Intune"
        
        $win32Apps_data_intune = $win32Apps_response_intune.value
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Total Win32 apps found in Intune : ", $win32Apps_data_intune.count
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32 apps found in Intune : ", $win32Apps_data_intune

        if ($win32Apps_data_intune.count -ge 1) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32 app found in Intune"
            foreach ($appdata_intune in $win32Apps_data_intune) {
                $global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32 app found in Intune"

                $win32app_id_intune = $appdata_intune.id
                $publishingState_intune = $appdata_intune.publishingState
                $detectionRules_intune = $appdata_intune.detectionRules
                $Global:logMessages += $detectionRules_intune
        
                foreach ($detectionRule_intune in $detectionRules_intune) {
                    $Global:logMessages += $detectionRule_intune."@odata.type"
                    if ($detectionRuletype -eq $detectionRule_intune."@odata.type") {
                        if ($detectionRuletype -eq "#microsoft.graph.win32LobAppRegistryDetection") {
                            
                            if ($detectionRuleInfo.keyPath -eq $detectionRule_intune.keyPath) {
                                if ($publishingState_intune -eq "Published") {
                                    return $win32app_id_intune
                                }
                            }
                        }
                        elseif ($detectionRuletype -eq "#microsoft.graph.win32LobAppPowerShellScriptDetection") {
                            if ($detectionRuleInfo.scriptContent -eq $detectionRule_intune.scriptContent) {
                                if ($publishingState_intune -eq "Published") {
                                    return $win32app_id_intune
                                }
                            }
                        }
                        elseif ($detectionRuletype -eq "#microsoft.graph.win32LobAppProductCodeDetection") {
                            if ($detectionRuleInfo.productCode -eq $detectionRule_intune.productCode) {
                                if ($publishingState_intune -eq "Published") {
                                    return $win32app_id_intune
                                }   
                            } 
                        }
                    }        
                }
            }
        }
        else {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32 app not found in Intune"
        }
        
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Unable to fetch win32 apps from Intune through graph API"
        return $False
    }
    
}

function Win32_App_Dependency_Update {
    param (
        [Parameter(Mandatory = $true)] [string] $tokenauthorizationheader,
        [Parameter(Mandatory = $true)] [string] $dependencyAppID,
        [Parameter(Mandatory = $true)] [string] $dependentAppID
    )
    $authHeader = @{
        'Authorization' = $tokenauthorizationheader
    }
    $dependency_update_url = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/{0}/UpdateRelationships" -f $dependentAppID
    $body = @{
        relationships = @(
            [PSCustomObject]@{
                targetId       = $dependencyAppID
                dependencyType = "autoInstall"
                "@odata.type"  = "#microsoft.graph.mobileAppDependency"
            }
        )
    }

    # Convert to JSON with proper depth
    $dependency_update_body = $body | ConvertTo-Json -Depth 10 -Compress    
    $dependency_update = Invoke-RestMethod -Uri $dependency_update_url -Method "POST" -Body $dependency_update_body -Headers $authHeader -ContentType 'application/json'
    if ($?) {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency updated successfully"
        $global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency ID is : ", $dependency_update.id
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency update failed"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script execution terminated with error code ", $error_code_mapping.dependency_update_failure
        Write-Log
        Exit $error_code_mapping.dependency_update_failure
    }

}

function Show-Help {
    @"
    Usage:
    --> powershell.exe -file "Dell_Intune_App_Publish_V1.0.ps1" -ClientId "12345678-1234-1234-1234-123456789012" -TenantId "d66b5b8b-8b60-4b0f-8b60-123456789012" -ClientSecret "z98b5b8b8b604b0f8b60123456789012" -AppName "dcu" -proxy "http://proxy.local:80"
    --> powershell.exe -file "Dell_Intune_App_Publish_V1.0.ps1" -ClientId "12345678-1234-1234-1234-123456789012" -TenantId "d66b5b8b-8b60-4b0f-8b60-123456789012" -CertificateThumbprint "z98b5b8b8b604b0f8b60123456789012" -AppName "dcu" -proxy "http://proxy.local:80"
    --> powershell.exe -file "Dell_Intune_App_Publish_V1.0.ps1" -ClientId "12345678-1234-1234-1234-123456789012" -TenantId "d66b5b8b-8b60-4b0f-8b60-123456789012" -ClientSecret "z98b5b8b8b604b0f8b60123456789012" -CabPath "C:\temp\dcu.cab" -proxy "http://proxy.local:80"
    --> powershell.exe -file "Dell_Intune_App_Publish_V1.0.ps1" -ClientId "12345678-1234-1234-1234-123456789012" -TenantId "d66b5b8b-8b60-4b0f-8b60-123456789012" -CertificateThumbprint "z98b5b8b8b604b0f8b60123456789012" -CabPath "C:\temp\dcu.cab" -proxy "http://proxy.local:80"
    --> powershell.exe -file "Dell_Intune_App_Publish_V1.0.ps1" -help
    --> powershell.exe -file "Dell_Intune_App_Publish_V1.0.ps1" -supportedapps
    --> powershell.exe -file "Dell_Intune_App_Publish_V1.0.ps1" -supportedapps -Proxy "http://proxy.local:80"

    Description:
        This script helps Dell Customers to Publish Dell Applications to the respective Intune Tenant.

    Parameters:
        -help                      : displays this help content
        -supportedapps             : List the application names, supported versions and its AppName that needs to be passed to script
        -ClientId                  : Microsoft Intune Client identification string that needs to be passed to the script
        -TenantId                  : Microsoft Intune Tenant identification string that needs to be passed to the script
        -ClientSecret              : Microsoft Intune Client Secret string that needs to be passed to the script
        -CertificateThumbprint     : Microsoft Intune Certificate Thumbprint string that needs to be passed to the script
        -CabPath                   : Path of the cab file that needs to be published to Microsoft Intune
        -AppName                   : Application Name that needs to be published to Microsoft Intune
        -proxy                     : Proxy URL that needs to be passed to the script for downloading the files
        -logpath                   : FolderPath To store log Files.

"@ | Write-Host
}

function Show-SupportedApps {
    @"
    Supported applications and its AppName that needs to be passed to scipt are as below:
    Supported Application Name | Version   | AppName     
"@ | Write-Host
    # The below code is to download the config json cabinet file
    if ($proxy) {
        $download_files_response = download_files -downloadurl $Global:intune_config_file_download_url -downloadPath $Global:downloads_dir -proxy $proxy
    }
    else {
        $download_files_response = download_files -downloadurl $Global:intune_config_file_download_url -downloadPath $Global:downloads_dir
    }
    
    $json_downloadPath = $download_files_response.downloadPath
    $json_filename = $download_files_response.filename
    
    # The below code is to extract the config json cabinet file
    $Intune_Config_File_Path = Extract_CabinetFile -downloadPath $json_downloadPath -filename $json_filename
    
    # The below code is to read the JSON data in a loop to display the supported Application Name, Version and App Name
    $json_data = Get-Content -Path $Intune_Config_File_Path | ConvertFrom-Json
    
    if ($?) {
        # Loop through the parsed data and print displayname and version
        foreach ($key in $json_data.PSObject.Properties.Name) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Key Name that is being read is : $key"
            foreach ($app in $json_data.$key) {
                foreach ($appdetails in $app) {
                    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Display Name that is being read is : $($appdetails.displayname)"
                    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Version that is being read is : $($appdetails.version)"

                    $tes = "{0} | {1} | {2}" -f $appdetails.displayname, $appdetails.version, $key
                    Write-Output $tes
                }
            }
        }
    Write-Log
    }
    else {
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to read the Intune Config.json file"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Execution terminated with return code ", $error_code_mapping.json_file_parsing_failure
        Write-Log
        Exit $error_code_mapping.json_file_parsing_failure
    }
}

function File_download_Extract {
    param (
        [Parameter(Mandatory = $true)] [string] $Appdownloadurl
    )

    # The below function call is to download the Application from the URL
    $download_files_response = download_files -downloadurl $Appdownloadurl -downloadPath $Global:downloads_dir -proxy $proxy

    $downloadPath1 = $download_files_response.downloadPath
    $filename1 = $download_files_response.filename
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Downloaded file full path from main function is : $downloadPath1"
    
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Downloaded the file successfully and the filename from main fucntion is : $filename1"

    # The below function call is to extract the contents on the end-user system in downloads_temp folder under CWD
    $intunewinfilepath, $CreateAPPConfigfilePath = Extract_CabinetFile -downloadPath $downloadPath1 -filename $filename1

    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - intunewin file path is : $intunewinfilepath"

    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - CreateAPPConfig file path is : $CreateAPPConfigfilePath"

    $extracted_file_paths = @{
        intunewinfilepath       = $intunewinfilepath
        CreateAPPConfigfilePath = $CreateAPPConfigfilePath

    }
    return $extracted_file_paths
    
}

#----------------------------------------------------------------------------------------------------------

# The below function is the starting point of the script
function main {

    secure_dir_file_creation
    $Global:logMessages = "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Started and inside main function"
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - **************************************************"
    if ((($ClientId) -and ($TenantId) -and ($ClientSecret) -and ($AppName)) -or (($ClientId) -and ($TenantId) -and ($CertThumbprint) -and ($AppName)) -or (($ClientId) -and ($TenantId) -and ($ClientSecret) -and ($CabPath)) -or (($ClientId) -and ($TenantId) -and ($CertThumbprint) -and ($CabPath))) {

        # Pre-requesites check
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Checking Prerequisites"
        prerequisite_verification

        if ($AppName) {
            # intialization
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Current working directory is : $Global:downloads_dir"
            
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Log Path location is : $Global:log_file_path"
            
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Application Name is : $AppName"
            
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Proxy is : $proxy"
        
            # The below fucntion call is to get the respective application intune zip file URL based on User entered data
            
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Application Name is $appName.ToUpper()"
            $Appdownloadurl = input_processing -AppName $AppName

            $dependentAppDownloadURL = $Appdownloadurl.dependantAppURL
            $dependencyAppDownloadURL = $Appdownloadurl.dependencyAppURL
            
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependent App Download URL for the user selected application is : $dependentAppDownloadURL"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency App Download URL for the user selected application is : $dependencyAppDownloadURL"

            if ($ClientSecret) {
                # The below function call is to create the Access token by using the client id, tenant id and client secret that is passed by user
                $tokenauthorizationheader = generate_access_token_using_Client_Secret -ClientId $ClientId -TenantId $TenantId -ClientSecret $ClientSecret
            }
            elseif ($CertThumbprint) {
                # The below function call is to create the Access token by using the client id, tenant id and client certificate that is passed by user
                $tokenauthorizationheader = generate_access_token_using_Client_Cert_Thumbprint -ClientId $ClientId -TenantId $TenantId -CertThumbprint $CertThumbprint
            }
            
            $dependencywin32lobappID = ""
            $dependentwin32lobappID = ""

            if ($null -ne $dependencyAppDownloadURL) {
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency App Download URL is available for the user selected application"
                $dependencyAppExtractPaths = File_download_Extract -Appdownloadurl $dependencyAppDownloadURL
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency App Intune win file path is : $dependencyAppExtractPaths.intunewinfilepath"
                
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency App CreateAPPConfig file path is : $dependencyAppExtractPaths.CreateAPPConfigfilePath"

                # The below code is to check if the dependency app exists in intune or not
                $dependencywin32lobappID = check_win32_App_Existenece_in_Intune -tokenauthorizationheader $tokenauthorizationheader -dependencyAppConfigfilepath $dependencyAppExtractPaths.CreateAPPConfigfilePath
                
                $dependencywin32lobappID = $dependencywin32lobappID -split " "
                $dependencywin32lobappID = $dependencywin32lobappID[-1]
                if ($dependencywin32lobappID -ne "") {
                    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency App exists in Intune, hence skipping the intune app publish"
                }
                else {
                    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency App does not exists in Intune, hence going ahead with intune app publish"

                    $dependencywin32lobappID = Intune_App_Publish -tokenauthorizationheader $tokenauthorizationheader -CreateAPPConfigfilePath $dependencyAppExtractPaths.CreateAPPConfigfilePath -intunewinfilepath $dependencyAppExtractPaths.intunewinfilepath
                    $dependencywin32lobappID = $dependencywin32lobappID -split " "

                    # Get the last element
                    $dependencywin32lobappID = $dependencywin32lobappID[-1]
                    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency App ID is : $dependencywin32lobappID"
                }
                
            }
            elseif ($dependentAppDownloadURL -eq "") {
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - No dependency app found for the user selected application"
            }

            if ($dependentAppDownloadURL -ne "") {
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependent App Download URL is available for the user selected application"
                $dependentAppExtractPaths = File_download_Extract -Appdownloadurl $dependentAppDownloadURL
                
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependent App Intune win file path is : $dependentAppExtractPaths.intunewinfilepath"
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependent App CreateAPPConfig file path is : $dependentAppExtractPaths.CreateAPPConfigfilePath"
                
                $dependentwin32lobappID = Intune_App_Publish -tokenauthorizationheader $tokenauthorizationheader -CreateAPPConfigfilePath $dependentAppExtractPaths.CreateAPPConfigfilePath -intunewinfilepath $dependentAppExtractPaths.intunewinfilepath
                $dependentwin32lobappID = $dependentwin32lobappID -split " "

                    # Get the last element
                $dependentwin32lobappID = $dependentwin32lobappID[-1]
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependent App win32lobappID is : $dependentwin32lobappID"

            }
            elseif ($dependencyAppDownloadURL -eq "") {
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - No dependency app found for the user selected application"
            }
            # The below code is to update the app dependency in Intune.
            if ($dependencywin32lobappID -ne "") {
                Win32_App_Dependency_Update -tokenauthorizationheader $tokenauthorizationheader -dependencyAppID $dependencywin32lobappID -dependentAppID $dependentwin32lobappID
                if($?){
                    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Dependency updated successfully"
                    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script execution completed successfully", $error_code_mapping.success
                    Write-Log
                    Exit $error_code_mapping.success

                }
                else{
                    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Failed to update the dependency in Intune"
                    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script execution terminated with error code ", $error_code_mapping.dependency_update_failure
                    Write-Log
                    Exit $error_code_mapping.dependency_update_failure
                }
            }    

        }
        elseif ($CabPath) {
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - CAB path provided by user is : $CabPath"
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - For Local CAB Path Flow, App Dependecies wont be published to Intune"

            if (!(Test-Path $CabPath)) {
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - CAB path provided by user is not valid"
                Write-Log
                Exit $error_code_mapping.Directory_path_not_Exist
            }
            else {

                $filename1 = $CabPath.Split("\")[-1]

                $downloadPath1 = $CabPath.Replace("\" + $filename1, "")
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Downloaded file full path from main function is : $downloadPath1"
            
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Downloaded the file successfully and the filename from main fucntion is : $filename1"

                # The below fucntion call is to extract the contents on the end-user system in downloads_temp folder under CWD
                $intunewinfilepath, $CreateAPPConfigfilePath = Extract_CabinetFile -downloadPath $downloadPath1 -filename $filename1
            
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - intunewin file path is : $intunewinfilepath"
            
                $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - CreateAPPConfig file path is : $CreateAPPConfigfilePath"
                
            }    
        
            if ($ClientSecret) {
                # The below function call is to create the Access token by using the client id, tenant id and client secret that is passed by user
                $tokenauthorizationheader = generate_access_token_using_Client_Secret -ClientId $ClientId -TenantId $TenantId -ClientSecret $ClientSecret
            }
            elseif ($CertThumbprint) {
                # The below function call is to create the Access token by using the client id, tenant id and client certificate that is passed by user
                $tokenauthorizationheader = generate_access_token_using_Client_Cert_Thumbprint -ClientId $ClientId -TenantId $TenantId -CertThumbprint $CertThumbprint
            }
            
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - --------------------------------"
            
            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Intune token authorization header from main function is : $tokenauthorizationheader"

            # The below function call is to publish the app to Intune
            $win32LobAppId = Intune_App_Publish -tokenauthorizationheader $tokenauthorizationheader -CreateAPPConfigfilePath $CreateAPPConfigfilePath -intunewinfilepath $intunewinfilepath

            $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Win32LobAppId from main function for local CAB path publishing is : $win32LobAppId"
        }
    }
    elseif ($help) {
        Show-Help
    }
    elseif ($supportedapps) {
        # The below code is to create the secure directory and files for downloading and logging purposes
        
        Show-SupportedApps
    }
    else {
        # The below code is to create the secure directory and files for downloading and logging purposes
        # secure_dir_file_creation

        Write-Host "Invalid parameters passed. Please pass the correct parameters"
        Write-Host "For more details on script usage, Please run the script with -help parameter as below"
        Write-Host 'powershell.exe -file Dell_Intune_App_Publish_V1.0.ps1 -help'
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Invalid parameters passed. Please pass the correct parameters"
        $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - For more details on script usage, Please run the script with -help parameter as below"
        $Global:logMessages += "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - powershell.exe -file Dell_Intune_App_Publish_V1.0.ps1 -help"
        Write-Log
        Exit $error_code_mapping.Invalid_Parameters_passed_to_script
    }
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - **************************************************"
    $Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Ended"
    Write-Log
}

# to verify if the script is being run as admin
verify_admin_privileges

$Global:logMessages += "`n$timestamp - Logging Started"
$Global:logMessages += "`n$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - Script Started"

main






# SIG # Begin signature block
# MIIq1wYJKoZIhvcNAQcCoIIqyDCCKsQCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBtBj4KDFxG9kHz
# MmBYdK+vWG/BtEdAeE+yLU8OsPdjh6CCEnkwggXfMIIEx6ADAgECAhBOQOQ3VO3m
# jAAAAABR05R/MA0GCSqGSIb3DQEBCwUAMIG+MQswCQYDVQQGEwJVUzEWMBQGA1UE
# ChMNRW50cnVzdCwgSW5jLjEoMCYGA1UECxMfU2VlIHd3dy5lbnRydXN0Lm5ldC9s
# ZWdhbC10ZXJtczE5MDcGA1UECxMwKGMpIDIwMDkgRW50cnVzdCwgSW5jLiAtIGZv
# ciBhdXRob3JpemVkIHVzZSBvbmx5MTIwMAYDVQQDEylFbnRydXN0IFJvb3QgQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHMjAeFw0yMTA1MDcxNTQzNDVaFw0zMDEx
# MDcxNjEzNDVaMGkxCzAJBgNVBAYTAlVTMRYwFAYDVQQKDA1FbnRydXN0LCBJbmMu
# MUIwQAYDVQQDDDlFbnRydXN0IENvZGUgU2lnbmluZyBSb290IENlcnRpZmljYXRp
# b24gQXV0aG9yaXR5IC0gQ1NCUjEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIK
# AoICAQCngY/3FEW2YkPy2K7TJV5IT1G/xX2fUBw10dZ+YSqUGW0nRqSmGl33VFFq
# gCLGqGZ1TVSDyV5oG6v2W2Swra0gvVTvRmttAudFrnX2joq5Mi6LuHccUk15iF+l
# OhjJUCyXJy2/2gB9Y3/vMuxGh2Pbmp/DWiE2e/mb1cqgbnIs/OHxnnBNCFYVb5Cr
# +0i6udfBgniFZS5/tcnA4hS3NxFBBuKK4Kj25X62eAUBw2DtTwdBLgoTSeOQm3/d
# vfqsv2RR0VybtPVc51z/O5uloBrXfQmywrf/bhy8yH3m6Sv8crMU6UpVEoScRCV1
# HfYq8E+lID1oJethl3wP5bY9867DwRG8G47M4EcwXkIAhnHjWKwGymUfe5SmS1dn
# DH5erXhnW1XjXuvH2OxMbobL89z4n4eqclgSD32m+PhCOTs8LOQyTUmM4OEAwjig
# nPqEPkHcblauxhpb9GdoBQHNG7+uh7ydU/Yu6LZr5JnexU+HWKjSZR7IH9Vybu5Z
# HFc7CXKd18q3kMbNe0WSkUIDTH0/yvKquMIOhvMQn0YupGaGaFpoGHApOBGAYGuK
# Q6NzbOOzazf/5p1nAZKG3y9I0ftQYNVc/iHTAUJj/u9wtBfAj6ju08FLXxLq/f0u
# DodEYOOp9MIYo+P9zgyEIg3zp3jak/PbOM+5LzPG/wc8Xr5F0wIDAQABo4IBKzCC
# AScwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQEwHQYDVR0lBBYw
# FAYIKwYBBQUHAwMGCCsGAQUFBwMIMDsGA1UdIAQ0MDIwMAYEVR0gADAoMCYGCCsG
# AQUFBwIBFhpodHRwOi8vd3d3LmVudHJ1c3QubmV0L3JwYTAzBggrBgEFBQcBAQQn
# MCUwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLmVudHJ1c3QubmV0MDAGA1UdHwQp
# MCcwJaAjoCGGH2h0dHA6Ly9jcmwuZW50cnVzdC5uZXQvZzJjYS5jcmwwHQYDVR0O
# BBYEFIK61j2Xzp/PceiSN6/9s7VpNVfPMB8GA1UdIwQYMBaAFGpyJnrQHu995ztp
# UdRsjZ+QEmarMA0GCSqGSIb3DQEBCwUAA4IBAQAfXkEEtoNwJFMsVXMdZTrA7LR7
# BJheWTgTCaRZlEJeUL9PbG4lIJCTWEAN9Rm0Yu4kXsIBWBUCHRAJb6jU+5J+Nzg+
# LxR9jx1DNmSzZhNfFMylcfdbIUvGl77clfxwfREc0yHd0CQ5KcX+Chqlz3t57jpv
# 3ty/6RHdFoMI0yyNf02oFHkvBWFSOOtg8xRofcuyiq3AlFzkJg4sit1Gw87kVlHF
# VuOFuE2bRXKLB/GK+0m4X9HyloFdaVIk8Qgj0tYjD+uL136LwZNr+vFie1jpUJuX
# bheIDeHGQ5jXgWG2hZ1H7LGerj8gO0Od2KIc4NR8CMKvdgb4YmZ6tvf6yK81MIIG
# HjCCBAagAwIBAgIQL09K+R/wy2FbIlVDX6BBmTANBgkqhkiG9w0BAQ0FADBPMQsw
# CQYDVQQGEwJVUzEWMBQGA1UEChMNRW50cnVzdCwgSW5jLjEoMCYGA1UEAxMfRW50
# cnVzdCBDb2RlIFNpZ25pbmcgQ0EgLSBPVkNTMjAeFw0yNDA4MDYxNDA5MzNaFw0y
# NTA4MDYxNDA5MzJaMIGaMQswCQYDVQQGEwJVUzEOMAwGA1UECBMFVGV4YXMxEzAR
# BgNVBAcTClJvdW5kIFJvY2sxHzAdBgNVBAoTFkRlbGwgVGVjaG5vbG9naWVzIElu
# Yy4xJDAiBgNVBAsTG0RVUCBDbGllbnQgQ3JlYXRpb24gU2VydmljZTEfMB0GA1UE
# AxMWRGVsbCBUZWNobm9sb2dpZXMgSW5jLjCCAaIwDQYJKoZIhvcNAQEBBQADggGP
# ADCCAYoCggGBANGE9Y/pBVViqeAbA5PkjcqN0EICbH2axxWuDutuZTBAUdsWUZf/
# 8i+P7UV9xRfO0g2QuBK4SiqRsiUMXcURFXwzy/LUOCkqm0DmJhru3xSQvu6sKCIg
# 0wk+20JzwPeDZaWZHPy9gAFAspxpQn7V+srg/KdOb1ZNfSRu1a6YYyZy2h1njmdq
# S8n2Ul/urhrC4ozZO7C62zDaf5C5y/i/FzrhrEkVpg6d/kgqghgmwJBWZgkPvHja
# uxfmkaP1T6oRsebYTuIn2/JcvZDW5YIYb5Ep5V3AjZxKwV0Auj7IaDbq2hzrEFxM
# M0MkLJgxMcqt/l0jkxHxaEoxUqRiBQF4kYuS9IPYt6JzAx+c9Xu4+hVpa+jl27YJ
# LqQb20z1eCd/8w+AdVVY+ed9ymcUBZ5HclUP3J9/6B9okc4WOIXPxfI51xDh0aGh
# ZTq8Fuqzk8euwkVKPf4LelXi278twvy243LqI34Kx/YPGlfhdYxUV/RF6gn5TRhH
# k47KGOVLhjZl2wIDAQABo4IBKDCCASQwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU
# 74LQg/KGXUeDQVRN5n73hk9zUvUwHwYDVR0jBBgwFoAU75+6ebBz8iUeeJwDUpwb
# U4Teje0wZwYIKwYBBQUHAQEEWzBZMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5l
# bnRydXN0Lm5ldDAyBggrBgEFBQcwAoYmaHR0cDovL2FpYS5lbnRydXN0Lm5ldC9v
# dmNzMi1jaGFpbi5wN2MwMQYDVR0fBCowKDAmoCSgIoYgaHR0cDovL2NybC5lbnRy
# dXN0Lm5ldC9vdmNzMi5jcmwwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMDMBMGA1UdIAQMMAowCAYGZ4EMAQQBMA0GCSqGSIb3DQEBDQUAA4ICAQBx
# iigXMm85IJ9kGLj6e5ksQotlxhFtDEAhIAI2ir3nVr7BJ97C+lsgA66Sjk+eyUq6
# FgDh7Rr+kIhfSJp4/QISUtbYSD21i5oLgioBUdJNPs4pD+pChbF2CgiMHqgdV/wb
# dxJMQ4oHpvM+pNg13ZkSvaICozEelRKJl2u7RmeSXbL3H/iSc8jSz1aH9+7p7lYj
# yUYt8iStOvc9p07Z31RnKge0OiL2O3pZiK657yuV+WqknpY5JVL+cPvWc88IriiP
# 9Uic+B72KWujvbUiWke1bvTiJpi+/zn5VuoDQQScOJb7m1lmZs/G75HDkSMG0qiX
# Ee5Vi25/qargcG2JON5VW8AzCMeSlHR9HOBpYL4hgYExxS7awvJYez1sQWJRoTCg
# T8JDBnrHVYCkoHu4N5qgA2CgQP/+Rfb3OlJQp0AJvpTQaLtLQ18b0xWwTCWxS1m2
# C6UUB8j1pPbppQiLW0mH/SoGGsx3aEeT9uJGeQzKAgLsnn7iMIlcvFqXYWPfFv5v
# 5F9cWALHsnTxE0FKGJ1HmVOk+ig0I6LuIEchLj2NWg2XMpxWPlokBXL6jHLRsyCS
# IsPJtpT6k0nPfD5RNCLetAZeURaj2fTznSoRSQ/Elodg1RWVlrC9ojW5Dkc5LVf2
# fAN3OsnZ8K0AOWfa6tt3YcHdpxJdCwRi5EPCchj+EzCCBnAwggRYoAMCAQICEHHv
# VXSvNVTDWixp9m9La80wDQYJKoZIhvcNAQENBQAwaTELMAkGA1UEBhMCVVMxFjAU
# BgNVBAoMDUVudHJ1c3QsIEluYy4xQjBABgNVBAMMOUVudHJ1c3QgQ29kZSBTaWdu
# aW5nIFJvb3QgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBDU0JSMTAeFw0yMTA1
# MDcxOTIwNDVaFw00MDEyMjkyMzU5MDBaME8xCzAJBgNVBAYTAlVTMRYwFAYDVQQK
# Ew1FbnRydXN0LCBJbmMuMSgwJgYDVQQDEx9FbnRydXN0IENvZGUgU2lnbmluZyBD
# QSAtIE9WQ1MyMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAnpl2Fxqe
# VhcIYyyTTYNhhDM0ArbZYqDewg65IEzIV50P3VRbDQzWAd0vSOGRCeHbyBUEgrZ7
# 8NjWMDsZcXD7qKaX9ildpAyp9FM+V9sMTm78dttfJOmqX0Pjk+cOz8olvMRMMAta
# D+YG9OVuDJlmWE+DYcJzfFwibwFFxQ/3QE9kS9AXCqkOHgIvoY9M8mdQ2z7kn8JP
# P3TrMaTQlNCZvDCSCWrLJM2i2HZS0E51mE9kWtJeg/RYwF1qdcTYP2Q6ixQN2Hbh
# 6rlr5xFwSRE4YxNu8cb6vRBFNQfmdhXQdRaqwkNX/qv+Y3NGIqC48+THcEYJ+ak3
# QZqzS2wfcHKjB/Y1knQRZG75AtXAkpXxl1l+De6iJfJxVbibjb/N7q7d+wznrjJO
# UI2h39Fzv8HOf3Xaq7/QrYI4xeeI7aJtOoYRt9ew4aiLOwxBF5pf5FuYyJ0An/dz
# 0sPpnwWHeSGD1gvt0cwIn+DxxclYulNf1Iexi1mo0l7NadA++sQ5Ca+0te3nPPoi
# h9Zz+ReVasMc9VV4X9T6C8BbP4x4FQ5aTDpu5SaY0CfMIN/Ahjt6jWVGftlhXqn0
# rj7U/K9FxzqzhQRKi8gJXbN7AihZ44Z9gKJYQGZi4DhVg6ufKUEmurvp2GT4trso
# c80VSteec+NmTLFRnYEji8iGd7K2LDcicCECAwEAAaOCASwwggEoMBIGA1UdEwEB
# /wQIMAYBAf8CAQAwHQYDVR0OBBYEFO+funmwc/IlHnicA1KcG1OE3o3tMB8GA1Ud
# IwQYMBaAFIK61j2Xzp/PceiSN6/9s7VpNVfPMDMGCCsGAQUFBwEBBCcwJTAjBggr
# BgEFBQcwAYYXaHR0cDovL29jc3AuZW50cnVzdC5uZXQwMQYDVR0fBCowKDAmoCSg
# IoYgaHR0cDovL2NybC5lbnRydXN0Lm5ldC9jc2JyMS5jcmwwDgYDVR0PAQH/BAQD
# AgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMEUGA1UdIAQ+MDwwMAYEVR0gADAoMCYG
# CCsGAQUFBwIBFhpodHRwOi8vd3d3LmVudHJ1c3QubmV0L3JwYTAIBgZngQwBBAEw
# DQYJKoZIhvcNAQENBQADggIBAF7zhpk1wXnu8BCv15JD0oXQW+CYoOBxUckUy1Ca
# YA6wBCZJsc/pupsIodpDXdRvI6K5+EDHR/5NAQtIkD/I3Gq0PlM1KL5ASkeFah53
# QMyAf2G0PE95qOajpqB+RIZxvxIblYFy9w2l0N5nn8aiuPFq+fz+dGbGZOZ5PWoD
# YU5LH8wgYssCGOxj7X5xP5a6C15oImfsH8DSBRZmsbKk6vzFlaONEqX1je8bIM2Z
# 9+cy81lxH92U5nnlUiMQVir8WTi/v3klkmrH/atnd3GxBH01rRTBPqj8IxdWCBh8
# 13oia5FqzDVFbU87nUOdBbid8/w0IVwEGDJXODTByoMjRqaIIyHGfhSAq7Hvuwus
# CT/uU5Exs+JURKq1fTA8LCOc6D+jWOpACBejIF96wAzbqv8DFgMNdGQimpReMDV2
# E/XT4ePgB8rZ6kWIRpxU1RDi8zIJQLbnXBcy/syv623PYDx18+5cYEBVG7VZr3Ij
# aE2cdAQMEMmvUFunDWYPluWaleAgohrQsO44SZ4qZ56RlmyY28QQbWB8Hm5I57Z+
# rzMHEnHvvZU7vqmD1EJ9t6c011+GkbWvVljaVX0Xvdu8zWRBFY0xUQZPtC6yiz2c
# 803jWANUzKyI+FI8TktGCSUZ/xXnp5hGLn266uPjfP/5uRmVvna5DXmyAlEaSsif
# iMJDMYIXtDCCF7ACAQEwYzBPMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNRW50cnVz
# dCwgSW5jLjEoMCYGA1UEAxMfRW50cnVzdCBDb2RlIFNpZ25pbmcgQ0EgLSBPVkNT
# MgIQL09K+R/wy2FbIlVDX6BBmTANBglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcC
# AQwxAjAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsx
# DjAMBgorBgEEAYI3AgEVMC8GCSqGSIb3DQEJBDEiBCBkuZcdPe/ywm930aimkw+9
# ghMKBlOxkkouEj4+26xGFzANBgkqhkiG9w0BAQEFAASCAYC4o9RIjIGDtcl+byrM
# UvRnVQcUzROMnO+I8lPLP4PaH36QVbP6ckh8XcTPyPxEXWcUl0xRZSzVDNjTR21M
# WWnFGIESVlvPkacFdYC+6NarILcW7/6mdi+unCkP4lPEdt5NjleirgXG//ev/Ldk
# FyXoxdujQKCaGmngHnRj/yKFCOwOX/TwxeYwdGpq//R0Z3FPKPvlPvpx0RlyLw1R
# uo+4AgYJMf24bZ2OsNiM51mPcTZ1zw+T6yDmZb9149t39pJGqcje7C/j8S5tu9Wo
# k0EGVPjPdavvkEjEuuyIsshWBIjO2Gc7rKvCypxzyGkQAv1o7d4zHq1ICBXuNcp1
# fucFnSAkso7TAXKk09YubIusZDh3bnTwtsInsGQxK7uce5VB8PVBVDiTQ7N7928p
# NkxaE92+qya/PwFVnUqukgQRqu0RDh+CF5ma9KeWgRSEKN+6Q67C3qq8/+NIv6TW
# DXps9tjApGVCzJeexu2qFgJmjNPjbyFlPGqGLR5/WF1i/kKhghUkMIIVIAYKKwYB
# BAGCNwMDATGCFRAwghUMBgkqhkiG9w0BBwKgghT9MIIU+QIBAzENMAsGCWCGSAFl
# AwQCATCB0QYLKoZIhvcNAQkQAQSggcEEgb4wgbsCAQEGCmCGSAGG+mwKAwUwMTAN
# BglghkgBZQMEAgEFAAQgBtUwPf64a/Xkm5XzMj1SP8yCveY7wVVLLWEK94B+YjIC
# CQCgi4wmb0yHexgPMjAyNTAzMjgwNTU0MzBaMAMCAQGgVqRUMFIxCzAJBgNVBAYT
# AlVTMRYwFAYDVQQKEw1FbnRydXN0LCBJbmMuMSswKQYDVQQDEyJFbnRydXN0IFRp
# bWVzdGFtcCBBdXRob3JpdHkgLSBUU0ExoIIPbTCCBCowggMSoAMCAQICBDhj3vgw
# DQYJKoZIhvcNAQEFBQAwgbQxFDASBgNVBAoTC0VudHJ1c3QubmV0MUAwPgYDVQQL
# FDd3d3cuZW50cnVzdC5uZXQvQ1BTXzIwNDggaW5jb3JwLiBieSByZWYuIChsaW1p
# dHMgbGlhYi4pMSUwIwYDVQQLExwoYykgMTk5OSBFbnRydXN0Lm5ldCBMaW1pdGVk
# MTMwMQYDVQQDEypFbnRydXN0Lm5ldCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSAo
# MjA0OCkwHhcNOTkxMjI0MTc1MDUxWhcNMjkwNzI0MTQxNTEyWjCBtDEUMBIGA1UE
# ChMLRW50cnVzdC5uZXQxQDA+BgNVBAsUN3d3dy5lbnRydXN0Lm5ldC9DUFNfMjA0
# OCBpbmNvcnAuIGJ5IHJlZi4gKGxpbWl0cyBsaWFiLikxJTAjBgNVBAsTHChjKSAx
# OTk5IEVudHJ1c3QubmV0IExpbWl0ZWQxMzAxBgNVBAMTKkVudHJ1c3QubmV0IENl
# cnRpZmljYXRpb24gQXV0aG9yaXR5ICgyMDQ4KTCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBAK1NS6kShrLqoyAHFRZkKitL0b8LSk2O7YB2pWe3eEDAc0LI
# aMDbUyvdXrh2mDWTixqdfBM6Dh9btx7P5SQUHrGBqY19uMxrSwPxAgzcq6VAJAB/
# dJShnQgps4gL9Yd3nVXN5MN+12pkq4UUhpVblzJQbz3IumYM4/y9uEnBdolJGf3A
# qL2Jo2cvxp+8cRlguC3pLMmQdmZ7lOKveNZlU1081pyyzykD+S+kULLUSM4FMlWK
# /bJkTA7kmAd123/fuQhVYIUwKfl7SKRphuM1Px6GXXp6Fb3vAI4VIlQXAJAmk7wO
# SWiRv/hH052VQsEOTd9vJs/DGCFiZkNw1tXAB+ECAwEAAaNCMEAwDgYDVR0PAQH/
# BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFFXkgdERgL7YibkIozH5
# oSQJFrlwMA0GCSqGSIb3DQEBBQUAA4IBAQA7m49WmzDnU5l8enmnTZfXGZWQ+wYf
# yjN8RmOPlmYk+kAbISfK5nJz8k/+MZn9yAxMaFPGgIITmPq2rdpdPfHObvYVEZSC
# DO4/la8Rqw/XL94fA49XLB7Ju5oaRJXrGE+mH819VxAvmwQJWoS1btgdOuHWntFs
# eV55HBTF49BMkztlPO3fPb6m5ZUaw7UZw71eW7v/I+9oGcsSkydcAy1vMNAethqs
# 3lr30aqoJ6b+eYHEeZkzV7oSsKngQmyTylbe/m2ECwiLfo3q15ghxvPnPHkvXpzR
# TBWN4ewiN8yaQwuX3ICQjbNnm29ICBVWz7/xK3xemnbpWZDFfIM1EWVRMIIFEzCC
# A/ugAwIBAgIMWNoT/wAAAABRzg33MA0GCSqGSIb3DQEBCwUAMIG0MRQwEgYDVQQK
# EwtFbnRydXN0Lm5ldDFAMD4GA1UECxQ3d3d3LmVudHJ1c3QubmV0L0NQU18yMDQ4
# IGluY29ycC4gYnkgcmVmLiAobGltaXRzIGxpYWIuKTElMCMGA1UECxMcKGMpIDE5
# OTkgRW50cnVzdC5uZXQgTGltaXRlZDEzMDEGA1UEAxMqRW50cnVzdC5uZXQgQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkgKDIwNDgpMB4XDTE1MDcyMjE5MDI1NFoXDTI5
# MDYyMjE5MzI1NFowgbIxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1FbnRydXN0LCBJ
# bmMuMSgwJgYDVQQLEx9TZWUgd3d3LmVudHJ1c3QubmV0L2xlZ2FsLXRlcm1zMTkw
# NwYDVQQLEzAoYykgMjAxNSBFbnRydXN0LCBJbmMuIC0gZm9yIGF1dGhvcml6ZWQg
# dXNlIG9ubHkxJjAkBgNVBAMTHUVudHJ1c3QgVGltZXN0YW1waW5nIENBIC0gVFMx
# MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2SPmFKTofEuFcVj7+IHm
# cotdRsOIAB840Irh1m5WMOWv2mRQfcITOfu9ZrTahPuD0Cgfy3boYFBpm/POTxPi
# wT7B3xLLMqP4XkQiDsw66Y1JuWB0yN5UPUFeQ18oRqmmt8oQKyK8W01bjBdlEob9
# LHfVxaCMysKD4EdXfOdwrmJFJzEYCtTApBhVUvdgxgRLs91oMm4QHzQRuBJ4ZPHu
# qeD347EijzRaZcuK9OFFUHTfk5emNObQTDufN0lSp1NOny5nXO2W/KW/dFGI46qO
# vdmxL19QMBb0UWAia5nL/+FUO7n7RDilCDkjm2lH+jzE0Oeq30ay7PKKGawpsjiV
# dQIDAQABo4IBIzCCAR8wEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMC
# AQYwOwYDVR0gBDQwMjAwBgRVHSAAMCgwJgYIKwYBBQUHAgEWGmh0dHA6Ly93d3cu
# ZW50cnVzdC5uZXQvcnBhMDMGCCsGAQUFBwEBBCcwJTAjBggrBgEFBQcwAYYXaHR0
# cDovL29jc3AuZW50cnVzdC5uZXQwMgYDVR0fBCswKTAnoCWgI4YhaHR0cDovL2Ny
# bC5lbnRydXN0Lm5ldC8yMDQ4Y2EuY3JsMBMGA1UdJQQMMAoGCCsGAQUFBwMIMB0G
# A1UdDgQWBBTDwnHSe9doBa47OZs0JQxiA8dXaDAfBgNVHSMEGDAWgBRV5IHREYC+
# 2Im5CKMx+aEkCRa5cDANBgkqhkiG9w0BAQsFAAOCAQEAHSTnmnRbqnD8sQ4xRdcs
# AH9mOiugmjSqrGNtifmf3w13/SQj/E+ct2+P8/QftsH91hzEjIhmwWONuld307ga
# HshRrcxgNhqHaijqEWXezDwsjHS36FBD08wo6BVsESqfFJUpyQVXtWc26Dypg+9B
# wSEW0373LRFHZnZgghJpjHZVcw/fL0td6Wwj+Af2tX3WaUWcWH1hLvx4S0NOiZFG
# RCygU6hFofYWWLuRE/JLxd8LwOeuKXq9RbPncDDnNI7revbTtdHeaxOZRrOL0k2T
# dbXxb7/cACjCJb+856NlNOw/DR2XjPqqiCKkGDXbBY524xDIKY9j0K6sGNnaxJ9R
# EjCCBiQwggUMoAMCAQICEQCYQHxeFs+HwenB//m0CoiNMA0GCSqGSIb3DQEBCwUA
# MIGyMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNRW50cnVzdCwgSW5jLjEoMCYGA1UE
# CxMfU2VlIHd3dy5lbnRydXN0Lm5ldC9sZWdhbC10ZXJtczE5MDcGA1UECxMwKGMp
# IDIwMTUgRW50cnVzdCwgSW5jLiAtIGZvciBhdXRob3JpemVkIHVzZSBvbmx5MSYw
# JAYDVQQDEx1FbnRydXN0IFRpbWVzdGFtcGluZyBDQSAtIFRTMTAeFw0yNTAxMjIx
# NzQyMzNaFw0yOTA2MjEyMzU5NTlaMFIxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1F
# bnRydXN0LCBJbmMuMSswKQYDVQQDEyJFbnRydXN0IFRpbWVzdGFtcCBBdXRob3Jp
# dHkgLSBUU0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5vYheRFR
# 7uvr2GHcsrihxoR+W8Fj6EAL+fWJDVEus00+UOJksItdWZ4EX6mg9BPwWEbCx+8l
# la/yuswy8fs6915A69rWFIJa52eMWvgbY5JA9uuLy2GKghcB8xPagZq61F65YpNQ
# 1yf//f/s/R1G8xcSVFHFdtnbc+P/siKWW3o3iKv4OohcebNZRTuN9UBtINHzA5hw
# 018Z/xGJx58ZR8ftRdlzQt2R8yafDArqEgt2pan/R8fhlOTaKF59WdLuZIWqfFFQ
# 9BEux83g4v+p3DeYEzdPqubUM6Wx//XcMeosrHUf16pPm+KOOTf17qq/UZmM/CFA
# 68sfVRs+pB77NwDOlIT13AKzlF4uWWdv+fOUtXv4fSghbUg4VXh0hA+VPxhakQI7
# zu8l6nhZe3T7gRAAcUV0DnmfPO1X01hdM46umk/w511A5/J91DZ3M5xQTYS/gqij
# wH8ImJAbyfCcSrcDzUXI34YGWdQekuZZZrz5XMJ/HgBN6XpFW2pbYsz4i6CVB5ng
# UZL/leR3mF2QFbej7wS55DyP3/Jf/yH/Xxl8IJ7u6TKq6EXptKoguw9mdrCKR3C9
# Ge6rhYQ92Gq/Psl2oigbKq0DQcd2fxR9MH4TLVYl2/2Sl32gJjuaaYlDa8cY3X8E
# AcMsM44XmPOdHvGjBHxnCyh1MmJ266HX9b0CAwEAAaOCAZIwggGOMAwGA1UdEwEB
# /wQCMAAwHQYDVR0OBBYEFNHNAQdigUaWXKnwvU/gxQCfer7cMB8GA1UdIwQYMBaA
# FMPCcdJ712gFrjs5mzQlDGIDx1doMA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDBoBggrBgEFBQcBAQRcMFowIwYIKwYBBQUHMAGGF2h0dHA6
# Ly9vY3NwLmVudHJ1c3QubmV0MDMGCCsGAQUFBzAChidodHRwOi8vYWlhLmVudHJ1
# c3QubmV0L3RzMS1jaGFpbjI1Ni5jZXIwMQYDVR0fBCowKDAmoCSgIoYgaHR0cDov
# L2NybC5lbnRydXN0Lm5ldC90czFjYS5jcmwwTAYDVR0gBEUwQzAIBgZngQwBBAIw
# NwYKYIZIAYb6bAoBBzApMCcGCCsGAQUFBwIBFhtodHRwczovL3d3dy5lbnRydXN0
# Lm5ldC9ycGEwKwYDVR0QBCQwIoAPMjAyNTAxMjIxNzQyMzNagQ8yMDI2MDQyMTE3
# NDIzMlowDQYJKoZIhvcNAQELBQADggEBAFCTB5EmwT6fQLBU0t/GWCk7zP7guLkW
# yW/lyPJpIxxAvCoysEcQaaF3UvC1GXnqNsS06gTqsGHNpJ7I5n3wSzL5jrzl5hqJ
# a38ZgFfAtQF418I3nTf9r3smKTQCP5taaQmXt20iatijFGTZ2sawaJvGV/MlVgZa
# g5vkiO/Ur1oWgMIXUHVdFMNk5x7kznAxmTDKUeQllwXvCL2Nyj2MhpHirXfQ4ZA0
# 5tgkykis5aSJI3jVCHzLhvy2DGQpbrbrMelF0ggY3T/rrVNXzJbh77uno4UP4Apb
# JmyyyOF1kNPKt3rEk8LGd5+OAXQxZ9SFB5h+lRD7TewSk10K0r1jr+gxggSeMIIE
# mgIBATCByDCBsjELMAkGA1UEBhMCVVMxFjAUBgNVBAoTDUVudHJ1c3QsIEluYy4x
# KDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5uZXQvbGVnYWwtdGVybXMxOTA3BgNV
# BAsTMChjKSAyMDE1IEVudHJ1c3QsIEluYy4gLSBmb3IgYXV0aG9yaXplZCB1c2Ug
# b25seTEmMCQGA1UEAxMdRW50cnVzdCBUaW1lc3RhbXBpbmcgQ0EgLSBUUzECEQCY
# QHxeFs+HwenB//m0CoiNMAsGCWCGSAFlAwQCAaCCAagwGgYJKoZIhvcNAQkDMQ0G
# CyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNTAzMjgwNTU0MzBaMCsGCSqG
# SIb3DQEJNDEeMBwwCwYJYIZIAWUDBAIBoQ0GCSqGSIb3DQEBCwUAMC8GCSqGSIb3
# DQEJBDEiBCC9Bx6EXUUBdnakCG/HfRy/UdTIft+1Wj0mhmr0Y1mSgTCCAQwGCyqG
# SIb3DQEJEAIvMYH8MIH5MIH2MIHzBCCjihinyaLXcfcfvJBKguPxY5rIFAxOE1W1
# +8JxmUz+ujCBzjCBuKSBtTCBsjELMAkGA1UEBhMCVVMxFjAUBgNVBAoTDUVudHJ1
# c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5uZXQvbGVnYWwtdGVy
# bXMxOTA3BgNVBAsTMChjKSAyMDE1IEVudHJ1c3QsIEluYy4gLSBmb3IgYXV0aG9y
# aXplZCB1c2Ugb25seTEmMCQGA1UEAxMdRW50cnVzdCBUaW1lc3RhbXBpbmcgQ0Eg
# LSBUUzECEQCYQHxeFs+HwenB//m0CoiNMA0GCSqGSIb3DQEBCwUABIICAOTfJ/h1
# 7cOxwAe5CU1ooUcEWO8Eo4Q+x+KHPGMI1nd4OAqf5AI8qo9FnPYGunJ63a8wNoHw
# Ke/Kth0692OFuWoXI6WpTM7r3hot8DQJYptVAQDsUDGD6sf8S+OyiJuAVVCPTsBn
# rs2alI1aNvqwwuAu6gjN2znf8nw2zALynkQ607dc8vGrCCp2UaNqjGISPwhzymeb
# AYx10yBefStTh5Dwk4bkazj0ez8NXw0K6TSXRSxIStRrbDSMiAoB9Fcg7yruXDAc
# 7T07OsLJTMEcI/CzJNzAnSvV1Ly6maVuZs6hAlL0gBqy8mbRSyaG8oUeg23o1+kI
# 9dly10C4zsUC7zEDQLuHXvrSMuhG0/7dzbXiZYnjoE8fOAV2kBOh/mrjFwBMnkgG
# T+P3oXcIAeyDaApMFJjDnqb6ouUtOV4QPadEMdB6TCUnjIAF8pv9ZLMjPf7+R3Dw
# Q2AFCvvDnf/f9Imku6Elp9YfN+bUVs0R342coKQ4+ZikLkgHUNALDX0dl8DVIWMW
# ULR2R15NWiTn1i3TunVQommyodzmlo71PgLBkTMrkMaGl6u85gZXxZcLEVMn9Kfr
# Gr68KEyUIXucbvKcKsr2wUPDK9nO1gObBD/8mxKA2JxQSFHKUsm51AoccgmjCCIi
# ntTXTyZRyg5cqOZK3BBYC9gOJQgwgHEVu1V/
# SIG # End signature block
}