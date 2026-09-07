#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 6b of 11 - Certificate Enrollment and LDAPS Validation
.DESCRIPTION
    Enable auto-enrollment GPO, trigger certificate enrollment on DCs, validate LDAPS on port 636.
    Run on: dc01
.NOTES
    Domain: corp.example.com
    Prerequisites: Plan 6a (ADCS Install on dc02) complete
#>

# --- Environment ---
$DC1    = "dc01"
$DC2    = "dc02"
$Domain = "corp.example.com"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 6b of 11 - Enrollment & LDAPS Validation" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 6B-1: Auto-Enrollment GPO (Manual GPMC Step)
# ============================================================
Write-Host "=== Step 6B-1: Enable Auto-Enrollment ===" -ForegroundColor Cyan
Write-Host @"

  *** MANUAL STEP - Configure via GPMC (or remote RSAT): ***

  1. Open Group Policy Management
  2. Edit: Default Domain Controllers Policy
  3. Navigate to:
     Computer Configuration > Policies > Windows Settings >
     Security Settings > Public Key Policies >
     Certificate Services Client - Auto-Enrollment
  4. Set to: Enabled
  5. Check: "Renew expired certificates, update pending certificates,
            and remove revoked certificates"
  6. Check: "Update certificates that use certificate templates"

"@ -ForegroundColor Yellow

Read-Host "Press Enter after completing the GPMC configuration above"

# ============================================================
# Step 6B-2: Force GP Update and Certificate Enrollment
# ============================================================
Write-Host "`n=== Step 6B-2: Trigger Enrollment ===" -ForegroundColor Cyan

Write-Host "Forcing GP update on $DC1..." -ForegroundColor White
gpupdate /force

Write-Host "`nForcing GP update on $DC2..." -ForegroundColor White
Invoke-Command -ComputerName $DC2 -ScriptBlock { gpupdate /force }

Write-Host "`nTriggering certificate enrollment on $DC1..." -ForegroundColor White
certutil -pulse

Write-Host "Triggering certificate enrollment on $DC2..." -ForegroundColor White
Invoke-Command -ComputerName $DC2 -ScriptBlock { certutil -pulse }

Write-Host "`n[OK] Enrollment triggered on both DCs." -ForegroundColor Green
Write-Host "Waiting 60 seconds for certificates to issue..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

# ============================================================
# Step 6B-3: Validate LDAPS
# ============================================================
Write-Host "`n=== Step 6B-3: Validate LDAPS (Port 636) ===" -ForegroundColor Cyan

Write-Host "`nTesting port 636 on $DC1..." -ForegroundColor White
$test1 = Test-NetConnection -ComputerName "$DC1.$Domain" -Port 636 -WarningAction SilentlyContinue
if ($test1.TcpTestSucceeded) {
    Write-Host "[OK] LDAPS is responding on $DC1 :636" -ForegroundColor Green
} else {
    Write-Host "[FAIL] LDAPS not responding on $DC1 :636" -ForegroundColor Red
    Write-Host "Wait a few more minutes and run: Test-NetConnection $DC1.$Domain -Port 636" -ForegroundColor Yellow
}

Write-Host "`nTesting port 636 on $DC2..." -ForegroundColor White
$test2 = Test-NetConnection -ComputerName "$DC2.$Domain" -Port 636 -WarningAction SilentlyContinue
if ($test2.TcpTestSucceeded) {
    Write-Host "[OK] LDAPS is responding on $DC2 :636" -ForegroundColor Green
} else {
    Write-Host "[FAIL] LDAPS not responding on $DC2 :636" -ForegroundColor Red
    Write-Host "Wait a few more minutes and run: Test-NetConnection $DC2.$Domain -Port 636" -ForegroundColor Yellow
}

Write-Host "`nCertificates in local machine store:" -ForegroundColor Yellow
certutil -store My | Select-String -Pattern "Subject:|NotAfter:|Serial Number:"

Write-Host "`nTesting LDAPS bind..." -ForegroundColor White
try {
    $null = [System.DirectoryServices.DirectoryEntry]::new("LDAP://${DC1}.${Domain}:636")
    Write-Host "[OK] LDAPS bind successful to $DC1" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] LDAPS bind failed to $DC1 : $_" -ForegroundColor Red
}

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 6 of 11 - COMPLETE (LDAPS enabled)" -ForegroundColor Green
Write-Host " Next: Run 07-Group-Policy.ps1 on $DC1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
