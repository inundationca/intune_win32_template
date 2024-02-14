<#
.SYNOPSIS

  Script that determines how PSADT should be configured when installing or uninstalling an application via Microsoft Intune.

.DESCRIPTION

  Script is the first in a chain that installs or uninstalls an application via Microsoft Intune:

  1. ./Configure.ps1 determines how PSADT should be deployed, whether interactively or silently and whether to prompt the user or wait until next deployment.
  2. ServiceUI.exe ensures that any interactive prompts appear to the user as Intune runs as the system account.
  3. Deploy-Application.exe executes the installation of the application whether interactively or silently.

  This scripts primary function is to determine if PSADT should be deployed interactively or silently based upon if the provided process is running or not. It 
  also includes the ability to exit rather than prompt the user if the application is found to be in use at the time of deployment.


.PARAMETER <Parameter_Name>

    -Install            - Indicates to install the application.
    -Uninstall          - Indiciates to uninstall the application.
    -TargetProcess      - Name of process, excluding any file extension (ex. 'zoom' rather than 'zoom.exe'). ** Multiple processes is not currently supported. **
    -DoNotDisturb       - If the application is found to be running, do not prompt the user; quit and retry on next deployment.
    -ForceInteractive   - Forces PSADT to use interactive mode.

    *Note that ForceInteractive does not cause PSADT to appear during uninstallations when the process is not found to be running.

.INPUTS

  None

.OUTPUTS

  Log file stored in C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\ConfigurePSADT-[DATE].log

.NOTES

  Version:        1.0
  Author:         inundation.ca
  Creation Date:  September 19th, 2023
  
.EXAMPLE

  # Install the program silently without verifying that any processes need to be closed.
  Powershell.exe -ExecutionPolicy Bypass -File .\Configure.ps1 -Install

  # Install a program silently, prompting if the process outlook.exe is running.
  Powershell.exe -ExecutionPolicy Bypass -File .\Configure.ps1 -Install -TargetProcess outlook

  # Install the program forcing interactive mode within PSADT.
  Powershell.exe -ExecutionPolicy Bypass -File .\Configure.ps1 -Install -ForceInteractive

  # Uninstall the program, cancelling if the process outlook.exe is found to be running.
  Powershell.exe -ExecutionPolicy Bypass -File .\Configure.ps1 -Uninstall -DoNotDisturb -TargetProcess outlook

#>

#---------------------------------------------------------[Initializations]--------------------------------------------------------

param (
    [string]$TargetProcess = "",
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$DoNotDisturb,
    [switch]$ForceInteractive
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Script Version
$sScriptVersion = "1.0"

#Log File Info
$sLogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$sLogName = "ConfigurePSADT-$(get-date -f yyyy-MM-dd).log"
$sLogFile = Join-Path -Path $sLogPath -ChildPath $sLogName

#------------------------------------------------------------[Function]------------------------------------------------------------

function CallPSADT {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory)]
        [string]$DeploymentType,
        [string]$DeployMode
    )

    Try {  
        .\ServiceUI.exe -Process:explorer.exe Deploy-Application.exe -DeploymentType $DeploymentType -DeployMode $DeployMode
    } Catch {
        $ErrorMessage = $_.Exception.Message
        return $ErrorMessage
    }

}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Start-Transcript -Path $sLogFile -Append

# Verify only one installation options has been set.
If ( ($Install) -and ($Uninstall) ) {
    Write-Host "Both -Install and -Uninstall set, only one argument may be used at a time. Exiting..."
    exit 1
}

# Determine if the application is running.
$ProcessRunning = Get-Process -name $TargetProcess -ErrorAction SilentlyContinue

# If the application is running and DoNotDisturb is set, cancel installation to avoid interrupting the user.
if ( ($ProcessRunning) -and ($DoNotDisturb -eq $true) ) {
    Write-Host "Process running and Do Not Disturb set. Exiting..."
    exit 60012
} elseif ($DoNotDisturb -eq $true) {
    Write-Host "Do Not Disturb set. No process found, continuing..."
}

# If the Uninstall flag is given, configure the deployment to uninstall the application, else default to install.
If ($Uninstall) {
    Write-Host "Uninstall flag given. Setting PSADT to uninstall."
    $DeploymentType = "Uninstall"
} else {
    $DeploymentType = "Install"
}

# If the process is running or the ForceInteractive flag is given, deploy interactively rather than silently. Silent is the default.
If ( !($ProcessRunning -eq $null) -or ($ForceInteractive -eq $true) ) {
    $DeployMode = "Interactive"
} else {
    $DeployMode = "Silent"
}

Write-Host "DeploymentType: $DeploymentType, DeployMode: $DeployMode, TargetProcess: $TargetProcess"

# Call PSADT.
CallPSADT -DeploymentType $DeploymentType -DeployMode $DeployMode

# Output the last exit code.
Write-Output "Install Exit Code = $LASTEXITCODE"
Stop-Transcript

Exit $LASTEXITCODE