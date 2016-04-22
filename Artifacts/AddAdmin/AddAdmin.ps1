Param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$True)]
    [string] $domain,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$True)]
    [string] $userName,
)

<##################################################################################################
    Description
    ===========
    - This script adds a machine to a domain
    - The script expects 2 parameters:
        domain: The domain that the machine should be joining
        userName: Domain Administrator's user name
    - Log is generated in the same folder in which this script resides:
        - $PSScriptRoot\AddAdmin-{TimeStamp} folder
    Usage examples
    ==============
    
    Powershell -executionpolicy bypass -file AddAdmin.ps1 -domain myDomain -userName adminUser
    Pre-Requisites
    ==============
    - Please ensure that this script is run elevated.
    - Please ensure that the powershell execution policy is set to unrestricted or bypass.
    Known issues / Caveats
    ======================
    
    - No known issues.
    Coming soon / planned work
    ==========================
    
    - N/A.
##################################################################################################>

#
# Powershell Configurations
#

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.  
$ErrorActionPreference = "stop"

Enable-PSRemoting -Force -SkipNetworkProfileCheck

# Ensure that current process can run scripts. 
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force 

###################################################################################################

#
# Custom Configurations
#

# Location of the log files
$ScriptLogFolder = Join-Path $PSScriptRoot -ChildPath $("AddAdmin-" + [System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss"))
$ScriptLog = Join-Path -Path $ScriptLogFolder -ChildPath "AddAdmin.log"

# Default exit code
$ExitCode = 0

##################################################################################################

# 
# Description:
#  - Creates the folder structure which'll be used for dumping logs generated by this script and
#    the logon task.
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function InitializeFolders
{
    if ($false -eq (Test-Path -Path $ScriptLogFolder))
    {
        New-Item -Path $ScriptLogFolder -ItemType directory | Out-Null
    }
}

##################################################################################################

# 
# Description:
#  - Writes specified string to the console as well as to the script log (indicated by $ScriptLog).
#
# Parameters:
#  - $message: The string to write.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function WriteLog
{
    Param(
        <# Can be null or empty #> $message
    )

    $timestampedMessage = $("[" + [System.DateTime]::Now + "] " + $message) | % {  
        Write-Host -Object $_
        Out-File -InputObject $_ -FilePath $ScriptLog -Append
    }
}

##################################################################################################

# 
# Description:
#  - Add a domain account as local administrator.
#
# Parameters:
#  - $adminDomain: domain of account to be added as admin.
#
# Parameters:
#  - $adminName: user name of account to be added as admin.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function AddLocalAdministrator {
    param (
        [Parameter(Mandatory=$true)]
        $adminDomain,
        
        [Parameter(Mandatory=$true)]
        $adminName
    )
    
    # Get Localized Group Name - Once AD joined this will return null
    $localAdministratorsGroupName = (Get-WMIObject Win32_Group -filter "LocalAccount=True AND SID='S-1-5-32-544'").Name

    if($localAdministratorsGroupName)
    {
        $domainAlias = "$adminDomain\$adminName"
        [string[]] $currentLocalAdministrators = net localgroup $localAdministratorsGroupName

        if ($currentLocalAdministrators -notcontains $adminName -and $currentLocalAdministrators -notcontains $domainAlias) {
            $null = net localgroup $localAdministratorsGroupName /add $domainAlias
        }
    }
}
##################################################################################################

#
# 
#

try
{
    #
    InitializeFolders

    AddLocalAdministrator -adminDomain $domain -adminName $userName
}

catch
{
    if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
    {
        $errMsg = $Error[0].Exception.Message
        WriteLog $errMsg
        Write-Host $errMsg
    }

    # Important note: Throwing a terminating error (using $ErrorActionPreference = "stop") still returns exit 
    # code zero from the powershell script. The workaround is to use try/catch blocks and return a non-zero 
    # exit code from the catch block. 
    $ExitCode = -1
}

finally
{
    WriteLog $("This output log has been saved to: " + $ScriptLog)

    WriteLog $("Exiting with " + $ExitCode)
    exit $ExitCode
}