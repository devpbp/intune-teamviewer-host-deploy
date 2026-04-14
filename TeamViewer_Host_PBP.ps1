<#
.SYNOPSIS
    Installs and assigns TeamViewer Host using the .exe installer. This version
    includes a robust service check, a retry loop for assignment, and detailed file logging.
#>

# --- Step 0: Logging Setup ---
$LogDir = "C:\IntuneApps\TeamViewer\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$LogFile = Join-Path -Path $LogDir -ChildPath "install_log.txt"

function Write-Log {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    
    # Write to console for Intune logs
    Write-Host $LogMessage -ForegroundColor $Color
    
    # Write to file for local diagnostics
    Add-Content -Path $LogFile -Value $LogMessage
}

function Get-TeamViewerExePath {
    $pathX64 = Join-Path $env:ProgramFiles "TeamViewer\TeamViewer.exe"
    $pathX86 = Join-Path ${env:ProgramFiles(x86)} "TeamViewer\TeamViewer.exe"
    if (Test-Path $pathX64) { return $pathX64 }
    if (Test-Path $pathX86) { return $pathX86 }
    return $null
}

Write-Log "--- Starting TeamViewer EXE Installation Script ---" -Color Yellow

# --- Configuration ---
$AssignmentID = "0001CoABChBb66ZQb0kR7rD0xLsRZ8TQEigIACAAAgAJAJJTYsKd5hfUbOhRd7s4sEVBS7xowvcpw_xkRz0wXvaSGkBluEeGJwsbcB8xRWbFzrh1z0MeBLuLj6f6CgaRU_4j1zysnRY0UJXfDGQ3jM8ZSncmCB2FbKvDBYpAXPsqf_ipIAEQstL45gY="

# --- Step 1: Install EXE silently ---
$ExeFile = Get-ChildItem -Path $PSScriptRoot -Filter "*.exe" | Select-Object -First 1
if (-not $ExeFile) {
    Write-Log "ERROR: EXE installer not found in the script's directory." -Color Red
    exit 1
}
Write-Log "[OK] Installer found: $($ExeFile.FullName)" -Color Green

$InstallArguments = "/S"
Write-Log "Executing command: $($ExeFile.FullName) $InstallArguments"
$Process = Start-Process -FilePath $ExeFile.FullName -ArgumentList $InstallArguments -Wait -PassThru

if ($Process.ExitCode -ne 0) {
    Write-Log "ERROR: EXE installation failed with exit code $($Process.ExitCode)." -Color Red
    exit $Process.ExitCode
}
Write-Log "[OK] EXE installation completed successfully." -Color Green

# --- Step 2: Wait for the service to be in 'Running' state ---
Write-Log "Waiting for TeamViewer service to confirm it is running..." -Color Yellow
$ServiceName = "TeamViewer"
$Timeout = New-TimeSpan -Minutes 2
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
do {
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($service.Status -eq 'Running') {
        Write-Log "[OK] TeamViewer service is running." -Color Green
        $Stopwatch.Stop()
        break
    }
    Write-Log "Service status is '$($service.Status)'. Waiting..." -Color Yellow
    Start-Sleep -Seconds 5
} while ($Stopwatch.Elapsed -lt $Timeout)

if ($Stopwatch.IsRunning) {
    $Stopwatch.Stop()
    Write-Log "ERROR: Timeout reached while waiting for the TeamViewer service to start." -Color Red
    exit 1
}

# --- Step 3: Assign the device with a Retry Loop ---
Write-Log "Attempting to assign the device..." -Color Yellow

$TV_Exe_Path = Get-TeamViewerExePath

if (Test-Path $TV_Exe_Path) {
    $AssignmentArguments = "assignment --id $AssignmentID"
    $maxRetries = 10
    $retryCount = 0
    $assignmentSuccess = $false

    for ($retryCount = 1; $retryCount -le $maxRetries; $retryCount++) {
        Write-Log "Executing assignment command (Attempt $retryCount of $maxRetries)..."
        $AssignProcess = Start-Process -FilePath $TV_Exe_Path -ArgumentList $AssignmentArguments -Wait -PassThru

        if ($AssignProcess.ExitCode -eq 0) {
            Write-Log "[OK] Device assignment completed successfully." -Color Green
            $assignmentSuccess = $true
            break # Exit loop on success
        } else {
            Write-Log "Assignment failed on attempt $retryCount with exit code $($AssignProcess.ExitCode)." -Color Yellow
            if ($retryCount -lt $maxRetries) {
                Write-Log "Waiting 30 seconds before retrying..." -Color Yellow
                Start-Sleep -Seconds 30
            }
        }
    }

    if (-not $assignmentSuccess) {
        Write-Log "ERROR: Device assignment failed after $maxRetries attempts." -Color Red
        exit 1 # Exit with an error code if assignment ultimately fails
    }

} else {
    Write-Log "ERROR: Could not find TeamViewer.exe to perform assignment." -Color Red
    exit 1
}

Write-Log "--- Script finished successfully. ---" -Color Green
exit 0