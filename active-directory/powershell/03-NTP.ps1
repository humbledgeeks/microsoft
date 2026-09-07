#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 3 of 11 - Time Synchronization (NTP)
.DESCRIPTION
    Configure PDC Emulator with external NTP. Secondary DC syncs from domain hierarchy.
    Domain-joined machines sync automatically from DCs.
    Non-domain devices (ESXi, switches, storage) should point to 192.0.2.11 / 192.0.2.12.
    Run on: dc01 (remotes to dc02)
.NOTES
    Domain: corp.example.com
    Prerequisites: Plan 1 complete (FSMO roles placed)
#>

# --- Environment ---
$DC1 = "dc01"
$DC2 = "dc02"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 3 of 11 - NTP Configuration" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 3A: PDC Emulator - External NTP
# ============================================================
Write-Host "=== Step 3A: Configure External NTP on PDC ($DC1) ===" -ForegroundColor Cyan

Write-Host "Disabling VM time provider (hypervisor should not override PDC NTP)..." -ForegroundColor White
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\VMICTimeProvider" -Name "Enabled" -Value 0

w32tm /config /manualpeerlist:"time.cloudflare.com time.google.com time.windows.com" /syncfromflags:manual /reliable:yes /update
Restart-Service w32time
w32tm /resync /force

Write-Host "`n[OK] External NTP configured on $DC1, VM time provider disabled." -ForegroundColor Green

Write-Host "`nVerifying NTP source on $DC1 :" -ForegroundColor Yellow
w32tm /query /source
w32tm /query /status

Read-Host "`nPress Enter to configure $DC2"

# ============================================================
# Step 3B: Secondary DC - Domain Hierarchy
# ============================================================
Write-Host "`n=== Step 3B: Configure Domain Hierarchy NTP on $DC2 ===" -ForegroundColor Cyan

Invoke-Command -ComputerName $DC2 -ScriptBlock {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders\VMICTimeProvider" -Name "Enabled" -Value 0
    w32tm /config /syncfromflags:domhier /update
    Restart-Service w32time
    $dc2Name = $using:DC2
    Write-Host "NTP source on ${dc2Name}:"
    w32tm /query /source
}

Write-Host "[OK] $DC2 configured to sync from domain hierarchy." -ForegroundColor Green

# ============================================================
# Final Validation
# ============================================================
Write-Host "`n=== Plan 3 - Final Validation ===" -ForegroundColor Cyan

Write-Host "`n$DC1 NTP source (should be external):" -ForegroundColor Yellow
w32tm /query /source

Write-Host "`n$DC2 NTP source (should be $DC1):" -ForegroundColor Yellow
Invoke-Command -ComputerName $DC2 -ScriptBlock { w32tm /query /source }

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 3 of 11 - COMPLETE" -ForegroundColor Green
Write-Host " Next: Run 04-OU-Structure.ps1 on $DC1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
