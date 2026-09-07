> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 11 of 11 — Final Validation and Peer Review

## Environment

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
```

**Prerequisite:** All previous plans (1-10) must be complete.

---

**Goal:** Run comprehensive validation across all components. Walk through peer review checklist.

## 11A. AD Infrastructure Health

```powershell
dcdiag /v /c /e
repadmin /replsummary
repadmin /showrepl
netdom query fsmo
Get-ADForest | Select-Object ForestMode
Get-ADDomain | Select-Object DomainMode
Get-ADOptionalFeature -Filter 'Name -like "Recycle*"' | Select-Object EnabledScopes
Get-ADDomainController -Filter * | Select-Object Name, IsGlobalCatalog
```

## 11B. DNS

```powershell
Resolve-DnsName dc01.corp.example.com -Server 192.0.2.11
Resolve-DnsName dc02.corp.example.com -Server 192.0.2.12
Resolve-DnsName 192.0.2.11 -Server 192.0.2.11
Resolve-DnsName www.microsoft.com -Server 192.0.2.11
Get-DnsServerZone | Format-Table ZoneName, ZoneType, ReplicationScope
Get-DnsServerScavenging
```

## 11C. Time, LDAPS, GPO, Security

```powershell
w32tm /query /source
w32tm /query /status
Test-NetConnection dc01.corp.example.com -Port 636
Test-NetConnection dc02.corp.example.com -Port 636
Get-ADDefaultDomainPasswordPolicy
Get-ADFineGrainedPasswordPolicy -Filter *
Get-ADUserResultantPasswordPolicy -Identity "adm_jdoe"
Get-ADUserResultantPasswordPolicy -Identity "svc_vcenter"
auditpol /get /category:*
Get-ADGroupMember -Identity "Protected Users"
Get-SmbServerConfiguration | Select-Object RequireSecuritySignature
Get-Service -Name Spooler | Select-Object Name, Status, StartType
```

## 11D. Access Validation (Test Users)

- Log in as **test.poweruser**: verify vCenter power ops + console, no delete/network/storage
- Log in as **test.readonly**: verify view-only vCenter access
- Log in as **test.veeam_operator**: verify Veeam restore operator access
- Log in as **test.netapp_operator**: verify NetApp storage operator access
- Verify service accounts authenticate through each application
- Verify service accounts **cannot** log on interactively to any server

## 11E. Backup Verification

```powershell
Get-WBSummary
Get-WBJob -Previous 1
# Check Veeam B&R console for successful DC backup job
```

## Peer Review Checklist

| # | Check | Status |
|---|---|---|
| 1 | Forest/Domain functional level = Windows Server 2025 | [ ] |
| 2 | All 5 FSMO roles placed as designed | [ ] |
| 3 | AD Recycle Bin enabled | [ ] |
| 4 | Both DCs are Global Catalogs | [ ] |
| 5 | Site renamed HQ-DataCenter, 5 subnets registered | [ ] |
| 6 | DNS forward zones AD-integrated and replicating | [ ] |
| 7 | Reverse zones for 192.0.2.0/24, 198.51.100.0/25, 203.0.113.128/25 | [ ] |
| 8 | DNS forwarders: Cloudflare + Google on both DCs | [ ] |
| 9 | DNS scavenging on dc01 only, aging on all zones | [ ] |
| 10 | DC DNS client: own IP first, partner second (no 127.0.0.1) | [ ] |
| 11 | NTP: PDC external, secondary from domain hierarchy | [ ] |
| 12 | All OUs created with deletion protection | [ ] |
| 13 | Computer redirect to Staging OU | [ ] |
| 14 | All accounts created with correct naming convention | [ ] |
| 15 | Service accounts marked sensitive (cannot be delegated) | [ ] |
| 16 | All groups created (incl. NSX_Service_Accounts, Aria groups) | [ ] |
| 17 | All group memberships assigned per plan | [ ] |
| 18 | Enterprise Root CA: 4096-bit RSA, SHA256, 10-year | [ ] |
| 19 | LDAPS on port 636 responding on both DCs | [ ] |
| 20 | Auto-enrollment GPO enabled, DCs enrolled | [ ] |
| 21 | Password policy: 14 char, complexity, 90-day, 24 history | [ ] |
| 22 | Account lockout: 5 / 30 min / 30 min | [ ] |
| 23 | FGPP PSO-Admins: 20 char, no expiry, 3 / 60 min | [ ] |
| 24 | FGPP PSO-ServiceAccounts: 30 char, no expiry, no lockout | [ ] |
| 25 | Audit policy: 17 subcategories configured | [ ] |
| 26 | Security event log: 1 GB on DCs | [ ] |
| 27 | Service account deny logon GPO on computer OUs | [ ] |
| 28 | adm_jdoe in Protected Users | [ ] |
| 29 | No svc_* accounts in Protected Users | [ ] |
| 30 | LDAP signing required | [ ] |
| 31 | LDAP channel binding verified | [ ] |
| 32 | SMB signing required (Server 2025 default) | [ ] |
| 33 | Print Spooler disabled on both DCs | [ ] |
| 34 | NTLM auditing enabled (audit only) | [ ] |
| 35 | Veeam daily image backup with app-aware | [ ] |
| 36 | System State weekly backup | [ ] |
| 37 | repadmin /replsummary = 0 failures | [ ] |
| 38 | dcdiag all tests pass | [ ] |
| 39 | VMware/NSX/Aria identity sources configured | [ ] |
| 40 | All 4 test users validated with correct access | [ ] |
| 41 | All access via AD groups only (no direct permissions) | [ ] |
