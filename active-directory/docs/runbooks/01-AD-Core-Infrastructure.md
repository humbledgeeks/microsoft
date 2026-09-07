> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 1 of 11 — AD Core Infrastructure

## Environment

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

---

**Goal:** Set functional levels, place FSMO roles, enable Recycle Bin, verify Global Catalogs.

## 1A. Verify and Raise Functional Levels

```powershell
# Check current levels
Get-ADForest | Select-Object ForestMode
Get-ADDomain | Select-Object DomainMode

# Verify replication is healthy FIRST
repadmin /replsummary

# Raise if needed (irreversible — confirm enum values match your Server 2025 build)
Set-ADForestMode -Identity "corp.example.com" -ForestMode Windows2025Forest -Confirm:$false
Set-ADDomainMode -Identity "corp.example.com" -DomainMode Windows2025Domain -Confirm:$false
```

## 1B. FSMO Role Placement

| Role | Target DC |
|---|---|
| PDC Emulator | dc01 |
| RID Master | dc01 |
| Schema Master | dc02 |
| Domain Naming Master | dc02 |
| Infrastructure Master | dc02 |

```powershell
# Check current placement
netdom query fsmo

# Move if needed
Move-ADDirectoryServerOperationMasterRole -Identity "dc01" `
    -OperationMasterRole PDCEmulator, RIDMaster -Confirm:$false

Move-ADDirectoryServerOperationMasterRole -Identity "dc02" `
    -OperationMasterRole SchemaMaster, DomainNamingMaster, InfrastructureMaster -Confirm:$false
```

## 1C. Enable AD Recycle Bin

```powershell
Enable-ADOptionalFeature -Identity "Recycle Bin Feature" `
    -Scope ForestOrConfigurationSet `
    -Target "corp.example.com" `
    -Confirm:$false
```

## 1D. Verify Global Catalogs

```powershell
Get-ADDomainController -Filter * | Select-Object Name, IsGlobalCatalog
# Both must show True
```

## Validation

```powershell
Get-ADForest | Select-Object ForestMode
Get-ADDomain | Select-Object DomainMode
netdom query fsmo
Get-ADOptionalFeature -Filter 'Name -like "Recycle*"' | Select-Object Name, EnabledScopes
Get-ADDomainController -Filter * | Select-Object Name, IsGlobalCatalog
repadmin /replsummary
```
