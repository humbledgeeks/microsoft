> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 5 of 11 — Accounts, Groups, and Memberships

## Environment

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
```

**Prerequisite:** Plan 4 (OU Structure) must be complete.

---

**Goal:** Create all user accounts, service accounts, test accounts, security groups, and assign memberships.

## 5A. Create User Accounts

```powershell
$domainDN = "DC=corp,DC=example,DC=com"

# Standard user
New-ADUser -Name "Jane Doe" -SamAccountName "jane.doe" `
    -UserPrincipalName "jane.doe@corp.example.com" `
    -Path "OU=Standard Users,OU=CORP-Users,$domainDN" `
    -AccountPassword (Read-Host -AsSecureString "Password for jane.doe") `
    -Enabled $true

# Admin account
New-ADUser -Name "ADM Jane Doe" -SamAccountName "adm_jdoe" `
    -UserPrincipalName "adm_jdoe@corp.example.com" `
    -Path "OU=Admin Users,OU=Admin,$domainDN" `
    -AccountPassword (Read-Host -AsSecureString "Password for adm_jdoe") `
    -Enabled $true
```

## 5B. Create Service Accounts

```powershell
$svcOU = "OU=Service Accounts,$domainDN"

$serviceAccounts = @("svc_vcenter", "svc_nsx", "svc_veeam", "svc_netapp")

foreach ($svc in $serviceAccounts) {
    New-ADUser -Name $svc -SamAccountName $svc `
        -UserPrincipalName "$svc@corp.example.com" `
        -Path $svcOU `
        -AccountPassword (Read-Host -AsSecureString "Password for $svc") `
        -PasswordNeverExpires $true `
        -CannotChangePassword $true `
        -Enabled $true

    # Mark as sensitive (cannot be delegated)
    Set-ADAccountControl -Identity $svc -AccountNotDelegated $true
}
```

## 5C. Create Test Accounts

```powershell
$testOU = "OU=Test Users,OU=CORP-Users,$domainDN"
$testAccounts = @("test.poweruser", "test.readonly", "test.veeam_operator", "test.netapp_operator")

foreach ($test in $testAccounts) {
    New-ADUser -Name $test -SamAccountName $test `
        -UserPrincipalName "$test@corp.example.com" `
        -Path $testOU `
        -AccountPassword (Read-Host -AsSecureString "Password for $test") `
        -Enabled $true
}
```

## 5D. Create Security Groups

```powershell
$vmwareOU = "OU=VMware Groups,OU=Groups,$domainDN"
$appOU    = "OU=Application Groups,OU=Groups,$domainDN"
$secOU    = "OU=Security Groups,OU=Groups,$domainDN"

# VMware Groups
$vmwareGroups = @(
    "vCenter_Admins", "vCenter_ReadOnly", "vCenter_Power_Users", "vCenter_Service_Accounts",
    "NSX_Admins", "NSX_ReadOnly", "NSX_Service_Accounts",
    "VCF_Admins", "VCF_ReadOnly",
    "Aria_Admins", "Aria_ReadOnly"
)
foreach ($g in $vmwareGroups) {
    New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $vmwareOU
}

# Application Groups
$appGroups = @(
    "Veeam_Admins", "Veeam_Operators", "Veeam_ReadOnly", "Veeam_Service_Accounts",
    "NetApp_Admins", "NetApp_Storage_Operators", "NetApp_ReadOnly", "NetApp_Service_Accounts"
)
foreach ($g in $appGroups) {
    New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $appOU
}

# Security Groups
$secGroups = @("FGPP-ServiceAccounts", "Infra_Admins", "Infra_ReadOnly")
foreach ($g in $secGroups) {
    New-ADGroup -Name $g -GroupScope Global -GroupCategory Security -Path $secOU
}
```

## 5E. Assign Group Memberships

```powershell
# Admin memberships
$adminGroups = @(
    "Domain Admins", "Enterprise Admins",
    "vCenter_Admins", "NSX_Admins", "VCF_Admins", "Aria_Admins",
    "Veeam_Admins", "NetApp_Admins", "Infra_Admins"
)
foreach ($g in $adminGroups) {
    Add-ADGroupMember -Identity $g -Members "adm_jdoe"
}

# Service account memberships
Add-ADGroupMember -Identity "vCenter_Service_Accounts" -Members "svc_vcenter"
Add-ADGroupMember -Identity "NSX_Service_Accounts" -Members "svc_nsx"
Add-ADGroupMember -Identity "vCenter_Service_Accounts" -Members "svc_nsx"   # NSX-vCenter integration
Add-ADGroupMember -Identity "Veeam_Service_Accounts" -Members "svc_veeam"
Add-ADGroupMember -Identity "NetApp_Service_Accounts" -Members "svc_netapp"

# All service accounts into FGPP target group
Add-ADGroupMember -Identity "FGPP-ServiceAccounts" -Members @("svc_vcenter","svc_nsx","svc_veeam","svc_netapp")

# Test account memberships
Add-ADGroupMember -Identity "vCenter_Power_Users" -Members "test.poweruser"
Add-ADGroupMember -Identity "vCenter_ReadOnly" -Members "test.readonly"
Add-ADGroupMember -Identity "Veeam_Operators" -Members "test.veeam_operator"
Add-ADGroupMember -Identity "NetApp_Storage_Operators" -Members "test.netapp_operator"
```

## Validation

```powershell
# Verify accounts
Get-ADUser -Filter * -SearchBase "OU=Service Accounts,DC=corp,DC=example,DC=com" | Select-Object Name, Enabled
Get-ADUser -Filter * -SearchBase "OU=Admin Users,OU=Admin,DC=corp,DC=example,DC=com" | Select-Object Name, Enabled

# Verify groups and members
Get-ADGroup -Filter * -SearchBase "OU=Groups,DC=corp,DC=example,DC=com" | ForEach-Object {
    Write-Host "`n$($_.Name):" -ForegroundColor Cyan
    Get-ADGroupMember -Identity $_ | Select-Object Name
}

# Verify service accounts are sensitive
Get-ADUser -Filter 'SamAccountName -like "svc_*"' -Properties AccountNotDelegated |
    Select-Object Name, AccountNotDelegated
```
