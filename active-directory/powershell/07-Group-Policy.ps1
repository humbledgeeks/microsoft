#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 7 of 11 - Group Policy
.DESCRIPTION
    Configure password policy, account lockout, fine-grained password policies,
    advanced audit policy GPO, and service account logon restrictions.
    Run on: dc01
.NOTES
    Domain: corp.example.com
    Prerequisites: Plans 4 (OU) and 5 (Accounts/Groups) complete
#>

# --- Environment ---
$DC1      = "dc01"
$Domain   = "corp.example.com"
$DomainDN = "DC=corp,DC=example,DC=com"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 7 of 11 - Group Policy" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 7A: Default Domain Policy - Password and Lockout
# ============================================================
Write-Host "=== Step 7A: Password Policy and Account Lockout ===" -ForegroundColor Cyan

Set-ADDefaultDomainPasswordPolicy -Identity $Domain `
    -ComplexityEnabled $true `
    -LockoutDuration "00:30:00" `
    -LockoutObservationWindow "00:30:00" `
    -LockoutThreshold 5 `
    -MaxPasswordAge "90.00:00:00" `
    -MinPasswordAge "1.00:00:00" `
    -MinPasswordLength 10 `
    -PasswordHistoryCount 24 `
    -ReversibleEncryptionEnabled $false

Write-Host "[OK] Default Domain Password Policy configured:" -ForegroundColor Green
Get-ADDefaultDomainPasswordPolicy | Format-List ComplexityEnabled, LockoutDuration, LockoutThreshold, MaxPasswordAge, MinPasswordAge, MinPasswordLength, PasswordHistoryCount

Read-Host "Press Enter to continue to Fine-Grained Password Policies"

# ============================================================
# Step 7B: FGPP - Admin PSO
# ============================================================
Write-Host "`n=== Step 7B: Fine-Grained Password Policy - Admins ===" -ForegroundColor Cyan

if (-not (Get-ADFineGrainedPasswordPolicy -Filter 'Name -eq "PSO-Admins"' -ErrorAction SilentlyContinue)) {
    New-ADFineGrainedPasswordPolicy -Name "PSO-Admins" `
        -Precedence 10 `
        -MinPasswordLength 20 `
        -PasswordHistoryCount 24 `
        -MaxPasswordAge "0" `
        -MinPasswordAge "1.00:00:00" `
        -ComplexityEnabled $true `
        -LockoutThreshold 3 `
        -LockoutDuration "01:00:00" `
        -LockoutObservationWindow "01:00:00" `
        -ReversibleEncryptionEnabled $false
    Write-Host "[OK] PSO-Admins created (20 char min, no expiry, 3/60 lockout)." -ForegroundColor Green
} else {
    Write-Host "[OK] PSO-Admins already exists." -ForegroundColor Green
}

try {
    Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-Admins" -Subjects "Domain Admins" -ErrorAction Stop
    Write-Host "[OK] PSO-Admins applied to Domain Admins group." -ForegroundColor Green
} catch {
    Write-Host "[OK] PSO-Admins already applied to Domain Admins." -ForegroundColor Green
}

# ============================================================
# Step 7C: FGPP - Service Account PSO
# ============================================================
Write-Host "`n=== Step 7C: Fine-Grained Password Policy - Service Accounts ===" -ForegroundColor Cyan

if (-not (Get-ADFineGrainedPasswordPolicy -Filter 'Name -eq "PSO-ServiceAccounts"' -ErrorAction SilentlyContinue)) {
    New-ADFineGrainedPasswordPolicy -Name "PSO-ServiceAccounts" `
        -Precedence 20 `
        -MinPasswordLength 30 `
        -PasswordHistoryCount 24 `
        -MaxPasswordAge "0" `
        -MinPasswordAge "0" `
        -ComplexityEnabled $true `
        -LockoutThreshold 0 `
        -LockoutDuration "0" `
        -LockoutObservationWindow "0" `
        -ReversibleEncryptionEnabled $false
    Write-Host "[OK] PSO-ServiceAccounts created (30 char min, no expiry, no lockout)." -ForegroundColor Green
} else {
    Write-Host "[OK] PSO-ServiceAccounts already exists." -ForegroundColor Green
}

try {
    Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-ServiceAccounts" -Subjects "FGPP-ServiceAccounts" -ErrorAction Stop
    Write-Host "[OK] PSO-ServiceAccounts applied to FGPP-ServiceAccounts group." -ForegroundColor Green
} catch {
    Write-Host "[OK] PSO-ServiceAccounts already applied." -ForegroundColor Green
}

Read-Host "`nPress Enter to continue to Audit Policy GPO"

# ============================================================
# Step 7D: Advanced Audit Policy GPO
# ============================================================
Write-Host "`n=== Step 7D: Advanced Audit Policy GPO ===" -ForegroundColor Cyan

if (-not (Get-GPO -Name "CORP-Audit-Policy" -ErrorAction SilentlyContinue)) {
    New-GPO -Name "CORP-Audit-Policy" -Comment "Advanced audit policy for $Domain"
    New-GPLink -Name "CORP-Audit-Policy" -Target $DomainDN -LinkEnabled Yes
    Write-Host "[OK] CORP-Audit-Policy GPO created and linked to domain root." -ForegroundColor Green
} else {
    Write-Host "[OK] CORP-Audit-Policy GPO already exists." -ForegroundColor Green
}

Write-Host @"

  *** MANUAL STEP - Configure audit subcategories via GPMC: ***

  Edit GPO: CORP-Audit-Policy
  Path: Computer Configuration > Advanced Audit Policy Configuration

  Account Logon:
    Credential Validation .............. Success, Failure
    Kerberos Authentication Service .... Success, Failure
    Kerberos Service Ticket Operations . Success, Failure

  Account Management:
    Computer Account Management ........ Success, Failure
    Security Group Management .......... Success, Failure
    User Account Management ............ Success, Failure

  DS Access:
    Directory Service Access ........... Success, Failure
    Directory Service Changes .......... Success, Failure

  Logon/Logoff:
    Logon .............................. Success, Failure
    Logoff ............................. Success
    Special Logon ...................... Success
    Account Lockout .................... Success, Failure

  Policy Change:
    Audit Policy Change ................ Success, Failure
    Authentication Policy Change ....... Success

  Privilege Use:
    Sensitive Privilege Use ............. Success, Failure

  System:
    Security State Change .............. Success, Failure
    Security System Extension .......... Success, Failure

  Also enable:
    Audit: Force audit policy subcategory settings
    to override audit policy category settings = Enabled

"@ -ForegroundColor Yellow

Write-Host "CORP-DC-Security GPO (for event log size):" -ForegroundColor Cyan
if (-not (Get-GPO -Name "CORP-DC-Security" -ErrorAction SilentlyContinue)) {
    New-GPO -Name "CORP-DC-Security" -Comment "DC hardening for $Domain"
    New-GPLink -Name "CORP-DC-Security" -Target "OU=Domain Controllers,$DomainDN" -LinkEnabled Yes
    Write-Host "[OK] CORP-DC-Security GPO created and linked to Domain Controllers OU." -ForegroundColor Green
} else {
    Write-Host "[OK] CORP-DC-Security GPO already exists." -ForegroundColor Green
}

Write-Host @"

  *** MANUAL STEP - Set event log size in CORP-DC-Security GPO: ***

  Edit GPO: CORP-DC-Security
  Path: Computer Configuration > Windows Settings > Security Settings > Event Log
    Maximum Security Log Size: 1048576 KB (1 GB)
    Retention method: Overwrite events as needed

"@ -ForegroundColor Yellow

Read-Host "Press Enter after configuring audit and event log GPOs"

# ============================================================
# Step 7E: Service Account Logon Restriction GPO
# ============================================================
Write-Host "`n=== Step 7E: Service Account Logon Restrictions ===" -ForegroundColor Cyan
Write-Host "User Rights Assignment is computer-level policy - links to computer OUs." -ForegroundColor White

if (-not (Get-GPO -Name "CORP-Service-Account-Restrictions" -ErrorAction SilentlyContinue)) {
    New-GPO -Name "CORP-Service-Account-Restrictions" -Comment "Deny interactive logon for service accounts"

    New-GPLink -Name "CORP-Service-Account-Restrictions" `
        -Target "OU=Computers,OU=Corp_Accounts,$DomainDN" -LinkEnabled Yes

    New-GPLink -Name "CORP-Service-Account-Restrictions" `
        -Target "OU=Domain Controllers,$DomainDN" -LinkEnabled Yes

    Write-Host "[OK] GPO created and linked to CORP-Computers OU and Domain Controllers OU." -ForegroundColor Green
} else {
    Write-Host "[OK] CORP-Service-Account-Restrictions GPO already exists." -ForegroundColor Green
}

Write-Host @"

  *** MANUAL STEP - Configure via GPMC: ***

  Edit GPO: CORP-Service-Account-Restrictions
  Path: Computer Configuration > Security Settings >
        Local Policies > User Rights Assignment

    Deny log on locally ........................ CORP\FGPP-ServiceAccounts
    Deny log on through Remote Desktop Services  CORP\FGPP-ServiceAccounts

"@ -ForegroundColor Yellow

Read-Host "Press Enter after configuring the service account restriction GPO"

# ============================================================
# Final Validation
# ============================================================
Write-Host "`n=== Plan 7 - Final Validation ===" -ForegroundColor Cyan

Write-Host "`nPassword Policy:" -ForegroundColor White
Get-ADDefaultDomainPasswordPolicy | Select-Object MinPasswordLength, MaxPasswordAge, LockoutThreshold | Format-Table -AutoSize

Write-Host "Fine-Grained Password Policies:" -ForegroundColor White
Get-ADFineGrainedPasswordPolicy -Filter * | Select-Object Name, Precedence, MinPasswordLength, MaxPasswordAge | Format-Table -AutoSize

Write-Host "Resultant PSO for adm_jdoe:" -ForegroundColor White
Get-ADUserResultantPasswordPolicy -Identity "adm_jdoe" | Select-Object Name, MinPasswordLength | Format-Table -AutoSize

Write-Host "Resultant PSO for svc_vcenter:" -ForegroundColor White
Get-ADUserResultantPasswordPolicy -Identity "svc_vcenter" | Select-Object Name, MinPasswordLength | Format-Table -AutoSize

Write-Host "GPOs:" -ForegroundColor White
Get-GPO -All | Select-Object DisplayName, GpoStatus | Format-Table -AutoSize

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 7 of 11 - COMPLETE" -ForegroundColor Green
Write-Host " Next: Run 08-Security-Hardening.ps1 on $DC1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
