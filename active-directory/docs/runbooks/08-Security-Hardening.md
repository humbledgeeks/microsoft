> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 8 of 11 — Security Hardening

## Environment

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
```

**Prerequisites:** Plans 5 (Accounts/Groups) and 7 (Group Policy) must be complete.

---

**Goal:** Protected Users, LDAP signing, SMB signing verification, disable Print Spooler on DCs, enable NTLM auditing.

## 8A. Protected Users Group

```powershell
Add-ADGroupMember -Identity "Protected Users" -Members "adm_jdoe"

# Validate
Get-ADGroupMember -Identity "Protected Users" | Select-Object Name
```

> **Warning:** Do NOT add service accounts (svc_*) to Protected Users. It will break their authentication.

## 8B. LDAP Signing

Configure via GPO on **Domain Controllers OU** (Default Domain Controllers Policy or CORP-DC-Security GPO):

| Setting | Value |
|---|---|
| Domain controller: LDAP server signing requirements | Require signing |

On member servers/clients:

| Setting | Value |
|---|---|
| Network security: LDAP client signing requirements | Require signing |

> **Note:** LDAPS (port 636) already provides TLS encryption. LDAP signing adds integrity for any port 389 traffic. Verify vCenter, NSX, NetApp, and Veeam support signing before enforcing on port 389.

## 8C. LDAP Channel Binding

Server 2025 enforces this by default. Verify it hasn't been disabled:

```powershell
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" `
    -Name "LdapEnforceChannelBinding" -ErrorAction SilentlyContinue
# Value 2 = Always (recommended)
```

## 8D. SMB Signing

Server 2025 requires SMB signing by default. Verify:

```powershell
Get-SmbServerConfiguration | Select-Object RequireSecuritySignature
# Expected: True
```

## 8E. Disable Print Spooler on DCs (PrintNightmare mitigation)

```powershell
# Run on EACH DC
Stop-Service -Name Spooler -Force
Set-Service -Name Spooler -StartupType Disabled
```

## 8F. NTLM Auditing (Audit Only — Do Not Block)

Configure via GPO on domain root:

| Setting | Value |
|---|---|
| Network security: Restrict NTLM: Audit NTLM authentication in this domain | Enable all |
| Network security: Restrict NTLM: Audit Incoming NTLM Traffic | Enable auditing for all accounts |

Review Event ID 4624 with `AuthenticationPackageName = NTLM` periodically. Migrate apps to Kerberos before restricting NTLM.

## Validation

```powershell
Get-ADGroupMember -Identity "Protected Users" | Select-Object Name
Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters" -Name "LDAPServerIntegrity" -ErrorAction SilentlyContinue
Get-SmbServerConfiguration | Select-Object RequireSecuritySignature
Get-Service -Name Spooler | Select-Object Name, Status, StartType
```
