#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 8 of 11 - Security Hardening
.DESCRIPTION
    Protected Users, LDAP signing verify, SMB signing verify, Print Spooler disable, NTLM auditing.
    Run on: dc01 (remotes to dc02 for Print Spooler)
.NOTES
    Domain: corp.example.com
    Prerequisites: Plans 5 (Accounts) and 7 (GPO) complete
#>

# --- Environment ---
$DC1 = "dc01"
$DC2 = "dc02"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 8 of 11 - Security Hardening" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 8A: Protected Users Group
# ============================================================
Write-Host "=== Step 8A: Protected Users Group ===" -ForegroundColor Cyan

try {
    Add-ADGroupMember -Identity "Protected Users" -Members "adm_jdoe" -ErrorAction Stop
    Write-Host "[OK] adm_jdoe added to Protected Users." -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already a member*") {
        Write-Host "[OK] adm_jdoe already in Protected Users." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] $_" -ForegroundColor Red
    }
}

Write-Host "`nProtected Users members:" -ForegroundColor White
Get-ADGroupMember -Identity "Protected Users" | Select-Object Name | Format-Table -AutoSize

Write-Host "[WARNING] Do NOT add service accounts (svc_*) to Protected Users." -ForegroundColor Red
Write-Host "It blocks NTLM and limits Kerberos, breaking service authentication." -ForegroundColor Red

Read-Host "`nPress Enter to continue to LDAP signing"

# ============================================================
# Step 8B: LDAP Signing
# ============================================================
Write-Host "`n=== Step 8B: LDAP Signing ===" -ForegroundColor Cyan

Write-Host @"

  *** MANUAL STEP - Configure via GPO: ***

  On Domain Controllers OU (Default Domain Controllers Policy or CORP-DC-Security):
    Computer Configuration > Security Settings > Local Policies > Security Options
      Domain controller: LDAP server signing requirements = Require signing

  On all member servers/clients (Default Domain Policy or separate GPO):
    Computer Configuration > Security Settings > Local Policies > Security Options
      Network security: LDAP client signing requirements = Require signing

  NOTE: LDAPS (port 636) already provides TLS encryption.
  LDAP signing adds integrity for port 389 traffic.
  Verify vCenter, NSX, NetApp, Veeam support signing before enforcing.

"@ -ForegroundColor Yellow

Read-Host "Press Enter to continue to LDAP channel binding"

# ============================================================
# Step 8C: LDAP Channel Binding (verify Server 2025 default)
# ============================================================
Write-Host "`n=== Step 8C: LDAP Channel Binding ===" -ForegroundColor Cyan

$cbValue = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" `
    -Name "LdapEnforceChannelBinding" -ErrorAction SilentlyContinue

if ($cbValue.LdapEnforceChannelBinding -eq 2) {
    Write-Host "[OK] LDAP Channel Binding = Always (value 2). Server 2025 default intact." -ForegroundColor Green
} elseif ($null -eq $cbValue.LdapEnforceChannelBinding) {
    Write-Host "[OK] LdapEnforceChannelBinding not set - Server 2025 defaults to enforcing." -ForegroundColor Green
} else {
    Write-Host "[WARN] LdapEnforceChannelBinding = $($cbValue.LdapEnforceChannelBinding). Expected 2." -ForegroundColor Yellow
}

Read-Host "`nPress Enter to continue to SMB signing"

# ============================================================
# Step 8D: SMB Signing (verify Server 2025 default)
# ============================================================
Write-Host "`n=== Step 8D: SMB Signing ===" -ForegroundColor Cyan

$smb = Get-SmbServerConfiguration
if ($smb.RequireSecuritySignature) {
    Write-Host "[OK] SMB signing required (RequireSecuritySignature = True)." -ForegroundColor Green
} else {
    Write-Host "[WARN] SMB signing NOT required. Server 2025 should default to True." -ForegroundColor Yellow
}

Read-Host "`nPress Enter to disable Print Spooler on both DCs"

# ============================================================
# Step 8E: Disable Print Spooler on DCs
# ============================================================
Write-Host "`n=== Step 8E: Disable Print Spooler (PrintNightmare mitigation) ===" -ForegroundColor Cyan

Write-Host "Disabling on $DC1..." -ForegroundColor White
Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
Set-Service -Name Spooler -StartupType Disabled
Write-Host "[OK] Print Spooler disabled on $DC1." -ForegroundColor Green

Write-Host "Disabling on $DC2..." -ForegroundColor White
Invoke-Command -ComputerName $DC2 -ScriptBlock {
    Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    Set-Service -Name Spooler -StartupType Disabled
}
Write-Host "[OK] Print Spooler disabled on $DC2." -ForegroundColor Green

Read-Host "`nPress Enter to configure NTLM auditing"

# ============================================================
# Step 8F: NTLM Auditing (audit only - do not block)
# ============================================================
Write-Host "`n=== Step 8F: NTLM Auditing ===" -ForegroundColor Cyan

Write-Host @"

  *** MANUAL STEP - Configure via GPO on domain root: ***

  Edit: Default Domain Policy (or create CORP-NTLM-Audit GPO)
  Path: Computer Configuration > Security Settings >
        Local Policies > Security Options

    Network security: Restrict NTLM:
      Audit NTLM authentication in this domain = Enable all
      Audit Incoming NTLM Traffic = Enable auditing for all accounts

  DO NOT block NTLM yet - VMware and other products may require it.
  Review Event ID 4624 (AuthenticationPackageName = NTLM) periodically.

"@ -ForegroundColor Yellow

Read-Host "Press Enter after configuring NTLM auditing"

# ============================================================
# Final Validation
# ============================================================
Write-Host "`n=== Plan 8 - Final Validation ===" -ForegroundColor Cyan

Write-Host "`nProtected Users:" -ForegroundColor White
Get-ADGroupMember -Identity "Protected Users" | Select-Object Name | Format-Table -AutoSize

Write-Host "Print Spooler ($DC1):" -ForegroundColor White
Get-Service -Name Spooler | Select-Object Name, Status, StartType | Format-Table -AutoSize

Write-Host "Print Spooler ($DC2):" -ForegroundColor White
Invoke-Command -ComputerName $DC2 -ScriptBlock {
    Get-Service -Name Spooler | Select-Object Name, Status, StartType
} | Format-Table -AutoSize

Write-Host "SMB Signing:" -ForegroundColor White
Get-SmbServerConfiguration | Select-Object RequireSecuritySignature | Format-Table -AutoSize

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 8 of 11 - COMPLETE" -ForegroundColor Green
Write-Host " Next: Run 09-Backup.ps1 on $DC1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
