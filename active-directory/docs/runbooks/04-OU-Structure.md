> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 4 of 11 — OU Structure

## Environment

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
```

---

**Goal:** Create the full OU hierarchy and redirect the default computer container to Staging.

## 4A. Create OU Structure

```powershell
$domainDN = "DC=corp,DC=example,DC=com"

# Top-level OUs
foreach ($ou in @("Admin", "CORP-Computers", "CORP-Users", "Service Accounts", "Groups")) {
    New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $true
}

# Admin sub-OUs
New-ADOrganizationalUnit -Name "Admin Users" -Path "OU=Admin,$domainDN" -ProtectedFromAccidentalDeletion $true
New-ADOrganizationalUnit -Name "Admin Groups" -Path "OU=Admin,$domainDN" -ProtectedFromAccidentalDeletion $true

# Computer sub-OUs
foreach ($ou in @("Member Servers", "Jump Servers", "Staging")) {
    New-ADOrganizationalUnit -Name $ou -Path "OU=CORP-Computers,$domainDN" -ProtectedFromAccidentalDeletion $true
}

# User sub-OUs
foreach ($ou in @("Standard Users", "Test Users", "Disabled Users")) {
    New-ADOrganizationalUnit -Name $ou -Path "OU=CORP-Users,$domainDN" -ProtectedFromAccidentalDeletion $true
}

# Group sub-OUs
foreach ($ou in @("VMware Groups", "Application Groups", "Security Groups")) {
    New-ADOrganizationalUnit -Name $ou -Path "OU=Groups,$domainDN" -ProtectedFromAccidentalDeletion $true
}
```

## 4B. Redirect Default Computer Container

```powershell
redircmp "OU=Staging,OU=CORP-Computers,DC=corp,DC=example,DC=com"
```

## OU Tree Reference

```
corp.example.com
+-- Admin
|   +-- Admin Users         (adm_* accounts)
|   +-- Admin Groups
+-- CORP-Computers
|   +-- Member Servers
|   +-- Jump Servers
|   +-- Staging             (default landing for new domain joins)
+-- CORP-Users
|   +-- Standard Users
|   +-- Test Users
|   +-- Disabled Users
+-- Service Accounts        (svc_* accounts)
+-- Groups
    +-- VMware Groups
    +-- Application Groups
    +-- Security Groups
```

> Domain Controllers stay in the built-in `Domain Controllers` OU. Do not move them.

## Validation

```powershell
Get-ADOrganizationalUnit -Filter * | Select-Object Name, DistinguishedName | Sort-Object DistinguishedName
```
