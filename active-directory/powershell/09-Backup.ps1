#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 9 of 11 - Backup Configuration
.DESCRIPTION
    Install Windows Server Backup on both DCs and configure system state backup.
    Veeam image-level backup is configured via the Veeam console (see reference).
    Run on: dc01 (remotes to dc02 for WSB install)
.NOTES
    Domain: corp.example.com
    Prerequisites: Plans 5 (Accounts) and 6 (LDAPS) complete
#>

# --- Environment ---
$DC1 = "dc01"
$DC2 = "dc02"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 9 of 11 - Backup Configuration" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 9A: Install Windows Server Backup on Both DCs
# ============================================================
Write-Host "`n=== Step 9A: Install Windows Server Backup ===" -ForegroundColor Cyan

Write-Host "Installing on $DC1..." -ForegroundColor White
$wsbDC1 = Get-WindowsFeature Windows-Server-Backup
if ($wsbDC1.Installed) {
    Write-Host "[OK] Windows Server Backup already installed on $DC1." -ForegroundColor Green
} else {
    Install-WindowsFeature Windows-Server-Backup -IncludeManagementTools
    Write-Host "[OK] Windows Server Backup installed on $DC1." -ForegroundColor Green
}

Write-Host "`nInstalling on $DC2..." -ForegroundColor White
Invoke-Command -ComputerName $DC2 -ScriptBlock {
    $wsb = Get-WindowsFeature Windows-Server-Backup
    if ($wsb.Installed) {
        Write-Host "[OK] Windows Server Backup already installed on $using:DC2."
    } else {
        Install-WindowsFeature Windows-Server-Backup -IncludeManagementTools
        Write-Host "[OK] Windows Server Backup installed on $using:DC2."
    }
}

Read-Host "`nPress Enter to configure system state backup"

# ============================================================
# Step 9C: Configure Weekly System State Backup
# ============================================================
Write-Host "`n=== Step 9B: Configure System State Backup ===" -ForegroundColor Cyan

Write-Host @"

  Configure system state backup on each DC.
  Adjust the network path to match your NetApp or Veeam repository.

  The following commands will prompt for credentials to access the network share.
  Schedule: Weekly at 02:00 AM

"@ -ForegroundColor White

$sharePath = Read-Host "Enter network share path for system state backups (e.g., \\fileserver01\AD-SystemState)"

if ($sharePath) {
    Write-Host "`nConfiguring backup policy on $DC1..." -ForegroundColor White
    try {
        $cred = Get-Credential -Message "Credentials for $sharePath"
        $policy = New-WBPolicy
        Add-WBSystemState -Policy $policy
        $target = New-WBBackupTarget -NetworkPath $sharePath -Credential $cred
        Add-WBBackupTarget -Policy $policy -Target $target
        Set-WBSchedule -Policy $policy -Schedule 02:00
        Set-WBPolicy -Policy $policy -Force
        Write-Host "[OK] System state backup configured on $DC1." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to configure backup on ${DC1}: $_" -ForegroundColor Red
    }

    Write-Host "`nTo configure on $DC2, RDP to $DC2 and run the same commands," -ForegroundColor Yellow
    Write-Host "or use Invoke-Command (requires CredSSP for credential delegation)." -ForegroundColor Yellow
} else {
    Write-Host "[SKIP] No share path provided. Configure manually later." -ForegroundColor Yellow
}

# ============================================================
# Backup Summary
# ============================================================
Write-Host "`n=== Backup Summary ===" -ForegroundColor Cyan
Write-Host @"

  Backup Type      Frequency   Retention   Tool
  -------------    ---------   ---------   ----------------------
  Full VM image    Daily       30 days     Veeam B&R
  System State     Weekly      60 days     Windows Server Backup

  Recovery Priority:
  1. Deleted object -> AD Recycle Bin (no restore needed)
  2. Deleted object beyond retention -> Veeam Explorer for AD
  3. Full DC recovery -> Restore VM from Veeam, boot, run dcdiag
  4. Forest recovery -> Microsoft forest recovery guide

"@ -ForegroundColor White

# ============================================================
# Final Validation
# ============================================================
Write-Host "=== Plan 9 - Final Validation ===" -ForegroundColor Cyan

Write-Host "`nWindows Server Backup feature:" -ForegroundColor White
Get-WindowsFeature Windows-Server-Backup | Select-Object Name, Installed | Format-Table -AutoSize

if (Get-Command Get-WBSummary -ErrorAction SilentlyContinue) {
    Write-Host "Backup summary:" -ForegroundColor White
    Get-WBSummary
}

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 9 of 11 - COMPLETE" -ForegroundColor Green
Write-Host " Next: Configure integrations (Plan 10)" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
