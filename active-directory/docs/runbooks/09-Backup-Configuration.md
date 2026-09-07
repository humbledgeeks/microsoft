> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 9 of 11 — Backup Configuration

## Environment

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
```

**Prerequisites:** Plans 5 (Accounts/Groups) and 6 (AD CS/LDAPS) must be complete.

---

**Goal:** Configure Veeam image-level backup for DCs and Windows Server Backup for system state.

## 9A. Veeam Image-Level Backup

Configure in Veeam B&R console:

| Setting | Value |
|---|---|
| Job Type | VMware backup (image-level) |
| VMs | dc01, dc02 |
| Application-Aware Processing | Enabled |
| Guest Credentials | svc_veeam@corp.example.com (needs local admin on DCs) |
| Schedule | Daily |
| Retention | 30 days |

## 9B. Windows Server Backup — System State

```powershell
# Install on EACH DC
Install-WindowsFeature Windows-Server-Backup -IncludeManagementTools

# Configure weekly system state backup
$policy = New-WBPolicy
Add-WBSystemState -Policy $policy
$target = New-WBBackupTarget -NetworkPath "\\fileserver01\AD-SystemState" `
    -Credential (Get-Credential)
Add-WBBackupTarget -Policy $policy -Target $target
Set-WBSchedule -Policy $policy -Schedule 02:00
Set-WBPolicy -Policy $policy -Force
```

> **Note:** Adjust the network share path (`\\fileserver01\AD-SystemState`) to match your NetApp or Veeam repository.

## Backup Summary

| Backup Type | Frequency | Retention | Tool |
|---|---|---|---|
| Full VM image | Daily | 30 days | Veeam B&R |
| System State | Weekly | 60 days | Windows Server Backup |

## Recovery Quick Reference

- **Deleted object:** AD Recycle Bin first, then Veeam Explorer for AD
- **Full DC recovery:** Restore VM from Veeam, boot, run `dcdiag`
- **Forest recovery:** Follow Microsoft forest recovery guide

## Validation

```powershell
Get-WBSummary
Get-WBJob -Previous 1
```
