# microsoft

Reusable **Microsoft** infrastructure automation and documentation. The first recovered technology area is
**Active Directory**; the layout leaves room for other Microsoft technologies later, but nothing beyond
Active Directory exists in this repository today.

## Layout

```
active-directory/
  powershell/      build, hardening, backup, integration and validation scripts (Windows PowerShell 5.1, RSAT AD/DNS/GPO modules)
  docs/runbooks/   the matching 11-plan runbook set (environment reference + plans 01–11)
```

## Active Directory content

An end-to-end, two-domain-controller Active Directory build expressed as eleven ordered plans, each with a
runbook and a script. Every script is standalone (environment values at the top) and can also dot-source
`00-Environment.ps1`.

| Plan | Script | Runbook | What it does | Effect |
|---|---|---|---|---|
| 0 | `00-Environment.ps1` | `00-Environment-Reference.md` | shared environment values (domain, DCs, subnets, OU paths, service accounts, NTP) | none |
| 1 | `01-AD-Core.ps1` | `01-AD-Core-Infrastructure.md` | functional levels, FSMO placement, Recycle Bin, Global Catalog checks | **changes the forest/domain** |
| 2 | `02-Sites-DNS.ps1` | `02-Sites-Subnets-DNS.md` | site rename, subnet registration, DNS forwarders, scavenging, DC DNS client | **changes AD/DNS** |
| 3 | `03-NTP.ps1` | `03-NTP-Configuration.md` | PDC emulator external NTP, secondary DC hierarchy | **changes DCs** |
| 4 | `04-OU-Structure.ps1` | `04-OU-Structure.md` | OU hierarchy, default computer container redirect | **changes AD** |
| 5 | `05-Accounts-Groups.ps1` | `05-Accounts-Groups-Memberships.md` | users, service accounts, test accounts, security groups, memberships | **changes AD** |
| 6a/6b | `06a-ADCS-Install.ps1`, `06b-ADCS-Enroll-Validate.ps1` | `06-AD-Certificate-Services-LDAPS.md` | enterprise root CA, auto-enrollment, LDAPS validation | **installs AD CS / changes GPO** |
| 7 | `07-Group-Policy.ps1` | `07-Group-Policy.md` | password/lockout policy, fine-grained password policies, audit policy, service-account logon restrictions | **changes GPO** |
| 8 | `08-Security-Hardening.ps1` | `08-Security-Hardening.md` | Protected Users, LDAP/SMB signing checks, Print Spooler, NTLM auditing | **changes DCs** |
| 9 | `09-Backup.ps1` | `09-Backup-Configuration.md` | Windows Server Backup system-state schedule (Veeam via its console) | **changes DCs** |
| 10 | `10-Integration-Reference.ps1` | `10-VMware-NetApp-Veeam-Integration.md` | prints the values needed to wire AD/LDAPS into vCenter, NSX, Aria, NetApp and Veeam | read-only |
| 11 | `11-Validate-All.ps1` | `11-Final-Validation-Peer-Review.md` | pass/fail validation across all components | read-only |
| — | `14-LDAPS-Integration.ps1` | — | root CA export and per-platform LDAPS configuration steps | **exports a certificate; platform steps are manual** |

Most scripts pause with a prompt between sections; several install roles or change domain-wide settings.
Read each runbook first and run in a lab before production.

## Example values

All identifiers are synthetic documentation values: domain `corp.example.com` / `CORP`, domain controllers
`dc01` and `dc02`, RFC 5737 TEST-NET addresses, `Corp_Accounts` OU root, `CORP-*` GPO names, example user
`jane.doe`. Each file says so in its header. Replace them with your own values (start with
`00-Environment.ps1`) before use.

## Prerequisites

Windows Server 2022/2025 domain controllers, run as a domain administrator in an elevated PowerShell 5.1
session with the RSAT `ActiveDirectory`, `DnsServer`, `GroupPolicy` and `ADCSDeployment` modules. Plan 9's
share and credentials are prompted at run time.

## Credentials and safety

No credentials are stored here. Scripts prompt (`Read-Host`, `Get-Credential`) where input is needed; user
account passwords are set interactively. Never commit environment files with real values, exported
certificates, key material or backup output (see `.gitignore`).

## Provenance

Recovered from the preserved local `infra-automation` workspace during the 2026 LabOps repository cleanup
(MICROSOFT-1). This repository starts with a fresh history; the original environment-specific versions are
retained privately.
