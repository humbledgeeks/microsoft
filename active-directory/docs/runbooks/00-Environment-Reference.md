> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Active Directory Implementation — Environment Reference

Copy this block along with each plan when sending to Sonnet for execution.

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
Subnets:
  198.51.100.0/25   — ESXi Management
  198.51.100.128/25   — vMotion
  203.0.113.0/25   — Application Servers
  192.0.2.0/24   — Server Management (DCs/DNS)
  203.0.113.128/25  — Jump Servers
Already Done:    Forward and reverse DNS lookup zones created
```

## Execution Order

| Plan | Description | Can Run After |
|---|---|---|
| 1 | AD Core (functional levels, FSMO, Recycle Bin, GC) | Immediately |
| 2 | Sites, Subnets, DNS (forwarders, scavenging, client config) | Plan 1 |
| 3 | NTP | Plan 1 |
| 4 | OU Structure | Plan 1 |
| 5 | Accounts, Groups, Memberships | Plan 4 |
| 6 | AD Certificate Services / LDAPS | Plan 1 |
| 7 | Group Policy | Plans 4 + 5 |
| 8 | Security Hardening | Plans 5 + 7 |
| 9 | Backup Configuration | Plans 5 + 6 |
| 10 | VMware/NetApp/Veeam Integration | Plan 6 |
| 11 | Final Validation + 41-item Checklist | All above |
