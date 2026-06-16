# Automated TeamViewer Host Deployment via Microsoft Intune

This solution provides a reliable and fully automated method for deploying a custom TeamViewer Host module using Microsoft Intune. The scripts address common issues encountered during automated installations, such as service start-up delays and device assignment errors.

## 🚀 Key Features

- **High Reliability:** The installation script includes retry loops and wait logic, ensuring successful execution even on slower devices.
- **Full Automation:** Installation and account assignment run silently in the background (as `SYSTEM`), requiring no user interaction.
- **Detailed Logging:** A comprehensive log file is created on each device, making diagnostics and troubleshooting straightforward.
- **Versatility:** Works with the `.exe` installer, which is the standard for custom Host modules.
- **Auto-Repair (Proactive Remediations):** Includes scripts to automatically detect and fix devices that lose their corporate assignment.

## 📂 Files in This Repository

### `TeamViewer_Host_PBP.ps1`

**Purpose:** The main installation script.

**Logic:**
1.  Finds the `.exe` installer in the same directory and runs it silently (`/S`).
2.  Waits for the TeamViewer service to enter the "Running" state to prevent errors in the next step.
3.  Executes the device assignment command using your `ASSIGNMENT_ID`. It will retry up to 10 times with a 30-second delay on failure.
4.  Logs all actions to `C:\IntuneApps\TeamViewer\logs\install_log.txt`.

### `check_timeweaver.ps1`

**Purpose:** The detection script for the Intune Detection Rule.

**Logic:**
1.  Checks for the existence of `TeamViewer.exe` in the standard installation folders (`Program Files` and `Program Files (x86)`).
2.  Verifies that the TeamViewer service is running.

**Advantage:** This detection method is far more reliable than a simple file or registry check because it confirms the application is not just installed but fully operational.

### `check_teamviewer_assignment.ps1` (Auto-Repair)

**Purpose:** The detection script for Intune Proactive Remediations.

**Logic:** Checks the registry for the `Remote_Settings_TVClientSetting_Policy` key to ensure the device is actively managed by your organization.

### `remediate_teamviewer_assignment.ps1` (Auto-Repair)

**Purpose:** The remediation script to automatically fix unassigned devices.

**Logic:** Clears old "ghost" registry keys, forcefully restarts the TeamViewer service, and re-runs the assignment command with a 10-attempt retry loop to handle cloud-sync delays. Logs actions to `C:\IntuneApps\TeamViewer\logs\remediation_log.txt`.

## 🛠️ Step 1: Preparation and Configuration

Before packaging the application, you need to get your `.exe` installer and `ASSIGNMENT_ID`.

1.  **Download Your Custom Host Module:**
    -   Log in to your **TeamViewer Management Console**.
    -   Navigate to **Design & Deploy**.
    -   Find your custom Host module, click **Edit**, and copy the permanent link for the `.exe` file. Download it.

2.  **Get the Assignment ID:**
    -   In the same module edit window, find the `ASSIGNMENT_ID` parameter. It is located within the example PowerShell command block.
    -   Copy this long string value.

3.  **Configure the Installation Script:**
    -   Open the `TeamViewer_Host_PBP.ps1` file in an editor.
    -   Find the line `$AssignmentID = "..."` and replace the value in the quotes with your `ASSIGNMENT_ID`.
    ```powershell
    # --- Configuration ---
    $AssignmentID = "PASTE_YOUR_ID_HERE"
    ```

> **Important:** The detection script `check_timeweaver.ps1` does not require configuration. Remember to also add your `$AssignmentID` into the `remediate_teamviewer_assignment.ps1` script.

## 📦 Step 2: Packaging the Application into .intunewin Format

1.  **Prepare the folder structure:**
    -   Create a base folder, for example `C:\IntunePackaging`.
    -   Inside it, create `Input` and `Output` folders.
    -   Place two files into the `Input` folder:
        -   Your downloaded `TeamViewer_Host.exe` installer.
        -   The configured `TeamViewer_Host_PBP.ps1` script.

2.  **Run the Microsoft Win32 Content Prep Tool (`IntuneWinAppUtil.exe`):**
    -   Open PowerShell and navigate to the folder containing the utility.
    -   Execute the command:
        ```powershell
        .\IntuneWinAppUtil.exe
        ```
    -   Specify the paths when prompted by the tool:
        -   **Source folder:** `C:\IntunePackaging\Input`
        -   **Setup file:** `TeamViewer_Host_PBP.ps1`
        -   **Output folder:** `C:\IntunePackaging\Output`
        -   **Do you want to specify catalog folder?:** `N`

A ready-to-upload `TeamViewer_Host_PBP.intunewin` file will be created in the `Output` folder.

## ☁️ Step 3: Deployment in Microsoft Intune

1.  Sign in to the **Microsoft Intune admin center**.
2.  Navigate to **Apps -> Windows** and click **Add**.
3.  **App type:** select **Windows app (Win32)**.

### Application Configuration

**App information:**
-   **App package file:** Upload your `.intunewin` file.
-   Fill in the **Name**, **Description**, and **Publisher** fields (e.g., `TeamViewer`).

**Program:**
-   **Install command:** `powershell.exe -ExecutionPolicy Bypass -File .\TeamViewer_Host_PBP.ps1`
-   **Uninstall command:** `"%ProgramFiles%\TeamViewer\uninstall.exe" /S`
-   **Install behavior:** `System`

**Requirements:**
-   **Operating system architecture:** `64-bit`
-   **Minimum operating system:** `Windows 10 1607`

**Detection rules:**
-   **Rules format:** `Use a custom detection script`
-   **Script file:** Upload your `check_timeweaver.ps1` script.
-   **Run script as 32-bit process on 64-bit clients:** `No`

**Assignments:**
-   Assign the application to the required device group.

After saving, Intune will begin deploying the application.

## 🛡️ Step 4: Proactive Remediations (Auto-Repair)

Sometimes TeamViewer might lose its organizational assignment (e.g., after manual unlinking or software glitches). To ensure devices are always managed, use the provided Proactive Remediation scripts to automatically detect and repair broken assignments.

### Setup in Intune:

1.  Ensure your tenant has Windows license verification enabled (**Tenant administration -> Connectors and tokens -> Windows data**).
2.  Navigate to **Devices -> Scripts and remediations -> Remediations** and click **+ Create script package**.
3.  **Name:** e.g., `TeamViewer Host - Assignment Auto-Repair`.
4.  **Settings:**
    -   **Detection script file:** Upload `check_teamviewer_assignment.ps1`
    -   **Remediation script file:** Upload `remediate_teamviewer_assignment.ps1`
    -   **Run this script using the logged-on credentials:** `No` (Crucial: Must run as `SYSTEM` to restart services)
    -   **Enforce script signature check:** `No`
    -   **Run script in 64-bit PowerShell:** `Yes`
5.  **Assignments:** Assign to your TeamViewer deployment group with a **Daily** schedule.

## 🔍 Troubleshooting

If the installation or remediation fails on any device, the quickest way to diagnose the problem is to check the log files created by the scripts:

-   **Installation Log:** `C:\IntuneApps\TeamViewer\logs\install_log.txt`
-   **Remediation Log:** `C:\IntuneApps\TeamViewer\logs\remediation_log.txt`

These files will record step-by-step what the script was doing and at what stage the error occurred.