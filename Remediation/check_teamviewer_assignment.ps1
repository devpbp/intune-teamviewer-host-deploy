<#
.SYNOPSIS
    Detects if TeamViewer is assigned to the organization.
    Checks for the 'Remote_Settings_TVClientSetting_Policy' registry value.
    This value is strictly present ONLY when the device is actively managed and a policy is applied.
#>
try {
    $IsAssigned = $false

    # Проверяем обе ветки реестра: стандартную (64-bit) и WOW6432Node (32-bit)
    $RegPaths = @(
        "HKLM:\SOFTWARE\TeamViewer",
        "HKLM:\SOFTWARE\WOW6432Node\TeamViewer"
    )

    foreach ($Path in $RegPaths) {
        if (Test-Path $Path) {
            $RegData = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
            
            # Проверяем наличие ключа корпоративной политики
            # Если он есть, устройство 100% привязано и управляется
            if ($null -ne $RegData.Remote_Settings_TVClientSetting_Policy) {
                $IsAssigned = $true
                break
            }
        }
    }

    if ($IsAssigned) {
        Write-Host "Success: TeamViewer is correctly assigned to the organization (Policy found)."
        exit 0 # Всё отлично, исправление не требуется
    } else {
        Write-Host "Error: TeamViewer management policy not found. Device is not assigned."
        exit 1 # Триггер для запуска скрипта исправления (Remediation)
    }
}
catch {
    Write-Host "Error: Script execution failed."
    exit 1
}