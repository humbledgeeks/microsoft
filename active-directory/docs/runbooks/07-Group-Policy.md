> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 7 of 11 — Group Policy

## Environment

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
```

**Prerequisites:** Plan 4 (OU Structure) and Plan 5 (Accounts/Groups) must be complete.

---

**Goal:** Configure Default Domain Policy (password + lockout), Fine-Grained Password Policies, Advanced Audit Policy, and service account logon restrictions.

## GPO Summary

| GPO Name | Linked To | Purpose |
|---|---|---|
| Default Domain Policy | Domain root | Password policy, account lockout |
| CORP-Audit-Policy | Domain root | Advanced audit policy subcategories |
| CORP-DC-Security | Domain Controllers OU | DC hardening, auto-enrollment, Print Spooler |
| CORP-Service-Account-Restrictions | CORP-Computers OU + Domain Controllers OU | Deny interactive/RDP logon for service accounts |

## 7A. Default Domain Policy — Password and Lockout

```powershell
Set-ADDefaultDomainPasswordPolicy -Identity "corp.example.com" `
    -ComplexityEnabled $true `
    -LockoutDuration "00:30:00" `
    -LockoutObservationWindow "00:30:00" `
    -LockoutThreshold 5 `
    -MaxPasswordAge "90.00:00:00" `
    -MinPasswordAge "1.00:00:00" `
    -MinPasswordLength 14 `
    -PasswordHistoryCount 24 `
    -ReversibleEncryptionEnabled $false
```

| Setting | Value |
|---|---|
| Min password length | 14 characters |
| Complexity | Enabled |
| Max age | 90 days |
| Min age | 1 day |
| History | 24 passwords |
| Lockout threshold | 5 attempts |
| Lockout duration | 30 minutes |
| Lockout reset | 30 minutes |

## 7B. Fine-Grained Password Policy — Admins

```powershell
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

Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-Admins" -Subjects "Domain Admins"
```

## 7C. Fine-Grained Password Policy — Service Accounts

```powershell
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

Add-ADFineGrainedPasswordPolicySubject -Identity "PSO-ServiceAccounts" -Subjects "FGPP-ServiceAccounts"
```

## 7D. Advanced Audit Policy GPO

```powershell
New-GPO -Name "CORP-Audit-Policy" -Comment "Advanced audit policy for corp.example.com"
New-GPLink -Name "CORP-Audit-Policy" -Target "DC=corp,DC=example,DC=com" -LinkEnabled Yes
```

Configure via GPMC (`Computer Configuration > Advanced Audit Policy Configuration`):

| Category | Subcategory | Setting |
|---|---|---|
| Account Logon | Credential Validation | Success, Failure |
| Account Logon | Kerberos Authentication Service | Success, Failure |
| Account Logon | Kerberos Service Ticket Operations | Success, Failure |
| Account Management | Computer Account Management | Success, Failure |
| Account Management | Security Group Management | Success, Failure |
| Account Management | User Account Management | Success, Failure |
| DS Access | Directory Service Access | Success, Failure |
| DS Access | Directory Service Changes | Success, Failure |
| Logon/Logoff | Logon | Success, Failure |
| Logon/Logoff | Logoff | Success |
| Logon/Logoff | Special Logon | Success |
| Logon/Logoff | Account Lockout | Success, Failure |
| Policy Change | Audit Policy Change | Success, Failure |
| Policy Change | Authentication Policy Change | Success |
| Privilege Use | Sensitive Privilege Use | Success, Failure |
| System | Security State Change | Success, Failure |
| System | Security System Extension | Success, Failure |

Also enable: `Audit: Force audit policy subcategory settings to override audit policy category settings = Enabled`

**Increase Security Event Log on DCs** (via separate CORP-DC-Security GPO linked to Domain Controllers OU):
- Maximum Security Log Size: **1048576 KB** (1 GB)
- Retention: Overwrite events as needed

## 7E. Service Account Logon Restriction GPO

> **Important:** User Rights Assignment is computer-level policy. Link to **computer OUs**, not Service Accounts OU.

```powershell
New-GPO -Name "CORP-Service-Account-Restrictions" `
    -Comment "Deny interactive logon for service accounts"

New-GPLink -Name "CORP-Service-Account-Restrictions" `
    -Target "OU=CORP-Computers,DC=corp,DC=example,DC=com" -LinkEnabled Yes

New-GPLink -Name "CORP-Service-Account-Restrictions" `
    -Target "OU=Domain Controllers,DC=corp,DC=example,DC=com" -LinkEnabled Yes
```

Configure via GPMC (`Computer Configuration > Security Settings > Local Policies > User Rights Assignment`):

| Setting | Value |
|---|---|
| Deny log on locally | CORP\FGPP-ServiceAccounts |
| Deny log on through Remote Desktop Services | CORP\FGPP-ServiceAccounts |

## Validation

```powershell
Get-ADDefaultDomainPasswordPolicy | Format-List *
Get-ADFineGrainedPasswordPolicy -Filter * | Select-Object Name, Precedence, MinPasswordLength, MaxPasswordAge
Get-ADUserResultantPasswordPolicy -Identity "adm_jdoe"
Get-ADUserResultantPasswordPolicy -Identity "svc_vcenter"
gpupdate /force
auditpol /get /category:*
```
