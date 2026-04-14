<#
.SYNOPSIS
    Detects if TeamViewer is installed by checking for the executable and ensuring the service is running.
    This is a more robust method than checking the file version.
#>
try {
    # Check for the executable in both 64-bit and 32-bit paths
    $path = "C:\Program Files\TeamViewer\TeamViewer.exe"
    if (-not (Test-Path $path)) {
        $path = "C:\Program Files (x86)\TeamViewer\TeamViewer.exe"
        if (-not (Test-Path $path)) {
            # File not found, exit without success code
            return
        }
    }

    # Check if the TeamViewer service is running
    $service = Get-Service -Name "TeamViewer" -ErrorAction SilentlyContinue
    if ($null -eq $service -or $service.Status -ne 'Running') {
        # Service not found or not running, installation is not fully complete
        return
    }

    # If both checks pass, output a success message and exit with code 0 for Intune
    Write-Host "TeamViewer executable found and service is running."
    exit 0
}
catch {
    # In case of any script error, assume the application is not detected
    return
}
