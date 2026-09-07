#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 10 of 11 - VMware, NetApp, and Veeam Integration Reference
.DESCRIPTION
    Configuration values for integrating AD with vCenter, NSX, Aria, NetApp, and Veeam.
    These are performed via application UIs, not PowerShell.
    This script outputs the values you need - no changes are made.
    Run on: any machine (reference only)
.NOTES
    Domain: corp.example.com
    Prerequisites: Plan 6 (LDAPS) must be complete and validated
#>

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 10 of 11 - Integration Reference" -ForegroundColor Yellow
Write-Host " This script makes NO changes." -ForegroundColor Yellow
Write-Host " It displays config values for application UIs." -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# 10A: vCenter SSO - LDAPS Identity Source
# ============================================================
Write-Host "=== 10A: vCenter SSO - LDAPS Identity Source ===" -ForegroundColor Cyan
Write-Host @"

  Add via: Administration > Single Sign-On > Configuration > Identity Providers > Add

  Type .................. Active Directory over LDAPS
  Domain ................ corp.example.com
  Base DN (Users) ....... DC=corp,DC=example,DC=com
  Base DN (Groups) ...... DC=corp,DC=example,DC=com
  Primary Server ........ ldaps://dc01.corp.example.com:636
  Secondary Server ...... ldaps://dc02.corp.example.com:636
  Service Account ....... svc_vcenter@corp.example.com
  Certificate ........... Import Corp-Root-CA cert into vCenter trusted certs

"@ -ForegroundColor White

# ============================================================
# 10B: vCenter Role Mapping
# ============================================================
Write-Host "=== 10B: vCenter Role Mapping ===" -ForegroundColor Cyan
Write-Host @"

  Configure via: Administration > Access Control > Global Permissions

  AD Group               vCenter Role
  --------------------    -----------------
  vCenter_Admins          Administrator
  vCenter_ReadOnly        Read-Only
  vCenter_Power_Users     Custom "Power User" role

  Power User Custom Role:
    Allowed: Power operations, console access
    Denied:  VM deletion, network changes, storage changes

"@ -ForegroundColor White

# ============================================================
# 10C: NSX Manager
# ============================================================
Write-Host "=== 10C: NSX Manager Integration ===" -ForegroundColor Cyan
Write-Host @"

  Identity Source .... corp.example.com (LDAPS)
  Service Account .... svc_nsx@corp.example.com
  NSX_Admins ......... Enterprise Admin role
  NSX_ReadOnly ....... Auditor role

"@ -ForegroundColor White

# ============================================================
# 10D: VCF / SDDC Manager
# ============================================================
Write-Host "=== 10D: VCF / SDDC Manager ===" -ForegroundColor Cyan
Write-Host @"

  Uses vCenter SSO identity source - no separate configuration.
  VCF_Admins provides access via vCenter role mapping.

"@ -ForegroundColor White

# ============================================================
# 10E: VCF Operations (Aria)
# ============================================================
Write-Host "=== 10E: VCF Operations (Aria) ===" -ForegroundColor Cyan
Write-Host @"

  Auth Source ........ vCenter SSO (inherited) or direct LDAPS
  Aria_Admins ........ Administrator role
  Aria_ReadOnly ...... Read-Only role

  If Aria uses direct LDAPS instead of SSO inheritance,
  create svc_aria service account and add to FGPP-ServiceAccounts.

"@ -ForegroundColor White

# ============================================================
# 10F: NetApp ONTAP
# ============================================================
Write-Host "=== 10F: NetApp ONTAP ===" -ForegroundColor Cyan
Write-Host @"

  Domain ............. corp.example.com
  Preferred DCs ...... 192.0.2.11, 192.0.2.12
  Service Account .... svc_netapp (for CIFS/AD join)
  NetApp_Admins ...... ontapadmin role

"@ -ForegroundColor White

# ============================================================
# 10G: Veeam B&R
# ============================================================
Write-Host "=== 10G: Veeam B&R ===" -ForegroundColor Cyan
Write-Host @"

  Credentials ........ svc_veeam@corp.example.com
  Permissions ........ Local admin on DCs (for app-aware processing)

"@ -ForegroundColor White

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 10 of 11 - REFERENCE COMPLETE" -ForegroundColor Green
Write-Host " Next: Run 11-Validate-All.ps1 on dc01" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
