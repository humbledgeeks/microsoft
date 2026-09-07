> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 10 of 11 — VMware, NetApp, and Veeam Integration

## Environment

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
CA:              Corp-Root-CA (Enterprise Root CA)
```

**Prerequisite:** LDAPS must be working (Plan 6 complete).

---

**Goal:** Configure AD as LDAPS identity source in vCenter, NSX, Aria, NetApp, and Veeam. Map RBAC groups to application roles.

## 10A. vCenter SSO — LDAPS Identity Source

Add via vCenter UI: `Administration > Single Sign-On > Configuration > Identity Providers > Add`

| Setting | Value |
|---|---|
| Type | Active Directory over LDAPS |
| Domain | corp.example.com |
| Base DN (Users) | DC=corp,DC=example,DC=com |
| Base DN (Groups) | DC=corp,DC=example,DC=com |
| Primary Server | ldaps://dc01.corp.example.com:636 |
| Secondary Server | ldaps://dc02.corp.example.com:636 |
| Service Account | svc_vcenter@corp.example.com |
| Certificate | Import Corp-Root-CA cert into vCenter trusted certs |

## 10B. vCenter Role Mapping

Configure via `Administration > Access Control > Global Permissions`:

| AD Group | vCenter Role |
|---|---|
| vCenter_Admins | Administrator |
| vCenter_ReadOnly | Read-Only |
| vCenter_Power_Users | Custom "Power User" role (see below) |

**Power User Custom Role:**
- Allowed: Power operations, console access
- Denied: VM deletion, network changes, storage changes

## 10C. NSX Manager Integration

| Setting | Value |
|---|---|
| Identity Source | corp.example.com (LDAPS) |
| Service Account | svc_nsx@corp.example.com |
| NSX_Admins | Enterprise Admin role |
| NSX_ReadOnly | Auditor role |

## 10D. VCF / SDDC Manager

Uses vCenter SSO identity source — no separate configuration. `VCF_Admins` provides access via vCenter role mapping.

## 10E. VCF Operations (Aria)

| Setting | Value |
|---|---|
| Auth Source | vCenter SSO (inherited) or direct LDAPS |
| Aria_Admins | Administrator role |
| Aria_ReadOnly | Read-Only role |

> If Aria uses direct LDAPS, create `svc_aria` service account (add to FGPP-ServiceAccounts).

## 10F. NetApp ONTAP

| Setting | Value |
|---|---|
| Domain | corp.example.com |
| Preferred DCs | 192.0.2.11, 192.0.2.12 |
| Service Account | svc_netapp (for CIFS/AD join) |
| NetApp_Admins | ontapadmin role |

## 10G. Veeam B&R

| Setting | Value |
|---|---|
| Credentials | svc_veeam@corp.example.com |
| Permissions Needed | Local admin on DCs (for app-aware processing) |
