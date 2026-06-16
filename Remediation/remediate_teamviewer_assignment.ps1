<#
.SYNOPSIS
    Proactive Remediation script for TeamViewer Full/Host Client.
    Forcefully re-registers the device to the corporate account.
#>

# --- 1. SETTINGS & CONFIGURATION ---
# Ваш API Токен для TeamViewer
$AssignmentID = "0001CoABChBb66ZQb0kR7rD0xLsRZ8TQEigIACAAAgAJAJJTYsKd5hfUbOhRd7s4sEVBS7xowvcpw_xkRz0wXvaSGkBluEeGJwsbcB8xRWbFzrh1z0MeBLuLj6f6CgaRU_4j1zysnRY0UJXfDGQ3jM8ZSncmCB2FbKvDBYpAXPsqf_ipIAEQstL45gY="

$RegPaths = @(
    "HKLM:\SOFTWARE\TeamViewer", 
    "HKLM:\SOFTWARE\WOW6432Node\TeamViewer"
)

# --- 2. LOGGING SETUP ---
$LogDir = "C:\IntuneApps\TeamViewer\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}
$LogFile = Join-Path -Path $LogDir -ChildPath "remediation_log.txt"

function Write-Log {
    param ([string]$Message)
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] $Message"
    
    # Write-Output гарантирует, что Intune добавит это в колонку RemediationScriptOutputDetails
    Write-Output $Message 
    
    # Записываем в локальный файл для удобства диагностики
    Add-Content -Path $LogFile -Value $LogMessage
}

Write-Log "--- Starting TeamViewer Remediation Process ---"

# --- 3. PRE-FLIGHT CHECKS ---
$TVPath = "C:\Program Files\TeamViewer\TeamViewer.exe"
if (-not (Test-Path $TVPath)) {
    $TVPath = "C:\Program Files (x86)\TeamViewer\TeamViewer.exe"
}

if (-not (Test-Path $TVPath)) {
    Write-Log "ERROR: TeamViewer.exe not found on the device. Cannot remediate."
    exit 1
}
Write-Log "[OK] Found TeamViewer executable at: $TVPath"


# --- 4. CLEANUP GHOST REGISTRY KEYS ---
Write-Log "Clearing old assignment registry keys to force a clean state..."
foreach ($Path in $RegPaths) {
    if (Test-Path $Path) {
        Remove-ItemProperty -Path $Path -Name "Device_Auto_Assigned_To_Account" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $Path -Name "ManagedDeviceV2AssignmentId" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $Path -Name "AssignmentData" -ErrorAction SilentlyContinue
    }
}


# --- 5. FORCE RESTART SERVICE ---
Write-Log "Forcefully restarting TeamViewer service to apply clean state..."
Stop-Service -Name "TeamViewer" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5
Get-Process -Name "TeamViewer" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Service -Name "TeamViewer"


# --- 6. ASSIGNMENT RETRY LOOP ---
$Arguments = "assignment --id $AssignmentID"
$maxRetries = 10
$assignmentSuccess = $false

for ($retryCount = 1; $retryCount -le $maxRetries; $retryCount++) {
    Write-Log "Executing assignment command (Attempt $retryCount of $maxRetries)..."
    
    $Process = Start-Process -FilePath $TVPath -ArgumentList $Arguments -Wait -PassThru
    
    if ($Process.ExitCode -eq 0) {
        Write-Log "[OK] Command accepted. Waiting 15 seconds for policy to sync from cloud..."
        Start-Sleep -Seconds 15

        # Проверяем реестр на наличие скачанной политики
        foreach ($Path in $RegPaths) {
            if (Test-Path $Path) {
                $RegData = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
                if ($null -ne $RegData.Remote_Settings_TVClientSetting_Policy) {
                    $assignmentSuccess = $true
                    break
                }
            }
        }

        if ($assignmentSuccess) {
            Write-Log "SUCCESS: TeamViewer has been successfully re-assigned and policy is active."
            break # Выходим из цикла при успехе
        } else {
            Write-Log "WARNING: Command succeeded locally, but cloud policy not found in registry yet. Will retry."
        }
    } else {
        Write-Log "WARNING: Assignment command rejected with exit code $($Process.ExitCode)."
    }
    
    # Ожидание перед следующей попыткой (для обработки задержек ответа сервера 403)
    if ($retryCount -lt $maxRetries) {
        Write-Log "Waiting 30 seconds before next attempt..."
        Start-Sleep -Seconds 30
    }
}

# --- 7. FINAL EVALUATION ---
if (-not $assignmentSuccess) {
    Write-Log "ERROR: Device assignment failed to pull policy after $maxRetries attempts."
    exit 1
} else {
    Write-Log "--- Remediation completed successfully ---"
    exit 0
}