#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 5 of 11 - Accounts, Groups, and Memberships
.DESCRIPTION
    Create user accounts, service accounts, test accounts, security groups, and assign memberships.
    All objects placed under Corp_Accounts OU structure.
    Run on: dc01
.NOTES
    Domain: corp.example.com
    Prerequisites: Plan 4 (OU Structure) complete
#>

# --- Environment ---
$DC1      = "dc01"
$Domain   = "corp.example.com"
$DomainDN = "DC=corp,DC=example,DC=com"
$AccountsDN     = "OU=Corp_Accounts,$DomainDN"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 5 of 11 - Accounts, Groups, Memberships" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 5A: Create User Accounts
# ============================================================
Write-Host "=== Step 5A: Create User Accounts ===" -ForegroundColor Cyan

# Standard user - placed in Admin OU
if (-not (Get-ADUser -Filter 'SamAccountName -eq "jane.doe"' -ErrorAction SilentlyContinue)) {
    $pw = Read-Host -AsSecureString "Enter password for jane.doe"
    New-ADUser -Name "Jane Doe" -SamAccountName "jane.doe" `
        -UserPrincipalName "jane.doe@$Domain" `
        -Path "OU=Admin,$AccountsDN" `
        -Description "Primary standard user account - Jane Doe" `
        -AccountPassword $pw -Enabled $true
    Write-Host "[OK] Created jane.doe" -ForegroundColor Green
} else {
    Write-Host "[OK] jane.doe already exists." -ForegroundColor Green
}

# Admin account
if (-not (Get-ADUser -Filter 'SamAccountName -eq "adm_jdoe"' -ErrorAction SilentlyContinue)) {
    $pw = Read-Host -AsSecureString "Enter password for adm_jdoe"
    New-ADUser -Name "ADM Jane Doe" -SamAccountName "adm_jdoe" `
        -UserPrincipalName "adm_jdoe@$Domain" `
        -Path "OU=Admin,$AccountsDN" `
        -Description "Administrative account - Jane Doe (Domain Admin, Protected Users)" `
        -AccountPassword $pw -Enabled $true
    Write-Host "[OK] Created adm_jdoe" -ForegroundColor Green
} else {
    Write-Host "[OK] adm_jdoe already exists." -ForegroundColor Green
}

Read-Host "`nPress Enter to create service accounts"

# ============================================================
# Step 5B: Create Service Accounts
# ============================================================
Write-Host "`n=== Step 5B: Create Service Accounts ===" -ForegroundColor Cyan

$svcOU = "OU=Service,$AccountsDN"

$svcDescriptions = @{
    "svc_vcenter" = "VMware vCenter service account - used for vCenter Server authentication"
    "svc_nsx"     = "VMware NSX service account - used for NSX Manager authentication"
    "svc_veeam"   = "Veeam Backup service account - used for Veeam B&R operations"
    "svc_netapp"  = "NetApp ONTAP service account - used for storage management"
}

foreach ($svc in @("svc_vcenter", "svc_nsx", "svc_veeam", "svc_netapp")) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$svc'" -ErrorAction SilentlyContinue)) {
        $pw = Read-Host -AsSecureString "Enter password for $svc (min 30 chars recommended)"
        New-ADUser -Name $svc -SamAccountName $svc `
            -UserPrincipalName "$svc@$Domain" `
            -Path $svcOU `
            -Description $svcDescriptions[$svc] `
            -AccountPassword $pw `
            -PasswordNeverExpires $true `
            -CannotChangePassword $true `
            -Enabled $true
        Set-ADAccountControl -Identity $svc -AccountNotDelegated $true
        Write-Host "[OK] Created $svc (sensitive, cannot be delegated)" -ForegroundColor Green
    } else {
        Write-Host "[OK] $svc already exists." -ForegroundColor Green
    }
}

Read-Host "`nPress Enter to create test accounts"

# ============================================================
# Step 5C: Create Test Accounts
# ============================================================
Write-Host "`n=== Step 5C: Create Test Accounts ===" -ForegroundColor Cyan

$testOU = "OU=Test Users,OU=Standard,$AccountsDN"

$testDescriptions = @{
    "test.poweruser"        = "Test account - vCenter Power Users validation"
    "test.readonly"         = "Test account - vCenter read-only access validation"
    "test.veeam_operator"   = "Test account - Veeam Operators access validation"
    "test.netapp_operator"  = "Test account - NetApp Storage Operators validation"
}

$testPW = Read-Host -AsSecureString "Enter a shared password for all test accounts"

foreach ($test in @("test.poweruser", "test.readonly", "test.veeam_operator", "test.netapp_operator")) {
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$test'" -ErrorAction SilentlyContinue)) {
        New-ADUser -Name $test -SamAccountName $test `
            -UserPrincipalName "$test@$Domain" `
            -Path $testOU `
            -Description $testDescriptions[$test] `
            -AccountPassword $testPW -Enabled $true
        Write-Host "[OK] Created $test" -ForegroundColor Green
    } else {
        Write-Host "[OK] $test already exists." -ForegroundColor Green
    }
}

Read-Host "`nPress Enter to create security groups"

# ============================================================
# Step 5D: Create Security Groups
# ============================================================
Write-Host "`n=== Step 5D: Create Security Groups ===" -ForegroundColor Cyan

$techBase = "OU=Technologies,$AccountsDN"
$vmwareOU = "OU=VMware,$techBase"
$veeamOU  = "OU=Veeam,$techBase"
$netappOU = "OU=NetApp,$techBase"
$groupsOU = "OU=Groups,$AccountsDN"

function New-GroupIfNotExists {
    param([string]$Name, [string]$Path, [string]$Description = "")
    if (-not (Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue)) {
        $params = @{
            Name          = $Name
            GroupScope    = "Global"
            GroupCategory = "Security"
            Path          = $Path
        }
        if ($Description) { $params.Description = $Description }
        New-ADGroup @params
        Write-Host "[OK] Created group: $Name" -ForegroundColor Green
    } else {
        Write-Host "[OK] Group exists: $Name" -ForegroundColor Green
    }
}

Write-Host "`nVMware Groups:" -ForegroundColor White
New-GroupIfNotExists -Name "vCenter_Admins"           -Path $vmwareOU -Description "Full administrative access to VMware vCenter"
New-GroupIfNotExists -Name "vCenter_ReadOnly"          -Path $vmwareOU -Description "Read-only access to VMware vCenter"
New-GroupIfNotExists -Name "vCenter_Power_Users"       -Path $vmwareOU -Description "Power user access to VMware vCenter (VM management)"
New-GroupIfNotExists -Name "vCenter_Service_Accounts"  -Path $vmwareOU -Description "Service accounts for vCenter API and automation"
New-GroupIfNotExists -Name "vCenter_Full_Admins"       -Path $vmwareOU -Description "Full administrator role in VMware vCenter"
New-GroupIfNotExists -Name "vCenter_Network_Admins"    -Path $vmwareOU -Description "Network administrator role in VMware vCenter"
New-GroupIfNotExists -Name "NSX_Admins"               -Path $vmwareOU -Description "Full administrative access to VMware NSX"
New-GroupIfNotExists -Name "NSX_ReadOnly"             -Path $vmwareOU -Description "Read-only access to VMware NSX"
New-GroupIfNotExists -Name "NSX_Service_Accounts"     -Path $vmwareOU -Description "Service accounts for NSX API and automation"
New-GroupIfNotExists -Name "VCF_Admins"              -Path $vmwareOU -Description "Full administrative access to VMware Cloud Foundation"
New-GroupIfNotExists -Name "VCF_ReadOnly"            -Path $vmwareOU -Description "Read-only access to VMware Cloud Foundation"
New-GroupIfNotExists -Name "Aria_Admins"             -Path $vmwareOU -Description "Full administrative access to VMware Aria Operations"
New-GroupIfNotExists -Name "Aria_ReadOnly"           -Path $vmwareOU -Description "Read-only access to VMware Aria Operations"

Write-Host "`nVeeam Groups:" -ForegroundColor White
New-GroupIfNotExists -Name "Veeam_Admins"            -Path $veeamOU  -Description "Full administrative access to Veeam Backup and Replication"
New-GroupIfNotExists -Name "Veeam_Operators"         -Path $veeamOU  -Description "Operator access to Veeam (backup and restore jobs)"
New-GroupIfNotExists -Name "Veeam_ReadOnly"          -Path $veeamOU  -Description "Read-only access to Veeam console"
New-GroupIfNotExists -Name "Veeam_Service_Accounts"  -Path $veeamOU  -Description "Service accounts for Veeam API and automation"

Write-Host "`nNetApp Groups:" -ForegroundColor White
New-GroupIfNotExists -Name "NetApp_Admins"            -Path $netappOU -Description "Full administrative access to NetApp ONTAP storage"
New-GroupIfNotExists -Name "NetApp_Storage_Operators"  -Path $netappOU -Description "Operator access to NetApp storage (volume management)"
New-GroupIfNotExists -Name "NetApp_ReadOnly"           -Path $netappOU -Description "Read-only access to NetApp ONTAP storage"
New-GroupIfNotExists -Name "NetApp_Service_Accounts"   -Path $netappOU -Description "Service accounts for NetApp API and automation"

Write-Host "`nCross-Technology Groups:" -ForegroundColor White
New-GroupIfNotExists -Name "FGPP-ServiceAccounts" -Path $groupsOU -Description "Fine-grained password policy target group - PSO-ServiceAccounts (30 char min)"
New-GroupIfNotExists -Name "Infra_Admins"         -Path $groupsOU -Description "Cross-platform infrastructure administrators"
New-GroupIfNotExists -Name "Infra_ReadOnly"       -Path $groupsOU -Description "Cross-platform infrastructure read-only access"

Read-Host "`nPress Enter to assign group memberships"

# ============================================================
# Step 5E: Assign Group Memberships
# ============================================================
Write-Host "`n=== Step 5E: Assign Group Memberships ===" -ForegroundColor Cyan

function Add-MemberSafe {
    param([string]$Group, [string]$Member)
    try {
        Add-ADGroupMember -Identity $Group -Members $Member -ErrorAction Stop
        Write-Host "[OK] $Member -> $Group" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -like "*already a member*") {
            Write-Host "[OK] $Member already in $Group" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] $Member -> ${Group}: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nAdmin memberships (adm_jdoe):" -ForegroundColor White
foreach ($g in @("Domain Admins","Enterprise Admins","vCenter_Admins","NSX_Admins",
                 "VCF_Admins","Aria_Admins","Veeam_Admins","NetApp_Admins","Infra_Admins")) {
    Add-MemberSafe -Group $g -Member "adm_jdoe"
}

Write-Host "`nService account memberships:" -ForegroundColor White
Add-MemberSafe -Group "vCenter_Service_Accounts" -Member "svc_vcenter"
Add-MemberSafe -Group "NSX_Service_Accounts"     -Member "svc_nsx"
Add-MemberSafe -Group "vCenter_Service_Accounts"  -Member "svc_nsx"
Add-MemberSafe -Group "Veeam_Service_Accounts"    -Member "svc_veeam"
Add-MemberSafe -Group "NetApp_Service_Accounts"   -Member "svc_netapp"

Write-Host "`nFGPP target group (all svc_* accounts):" -ForegroundColor White
foreach ($svc in @("svc_vcenter","svc_nsx","svc_veeam","svc_netapp")) {
    Add-MemberSafe -Group "FGPP-ServiceAccounts" -Member $svc
}

Write-Host "`nTest account memberships:" -ForegroundColor White
Add-MemberSafe -Group "vCenter_Power_Users"      -Member "test.poweruser"
Add-MemberSafe -Group "vCenter_ReadOnly"          -Member "test.readonly"
Add-MemberSafe -Group "Veeam_Operators"           -Member "test.veeam_operator"
Add-MemberSafe -Group "NetApp_Storage_Operators"  -Member "test.netapp_operator"

# ============================================================
# Final Validation
# ============================================================
Write-Host "`n=== Plan 5 - Final Validation ===" -ForegroundColor Cyan

Write-Host "`nService Accounts:" -ForegroundColor White
Get-ADUser -Filter * -SearchBase "OU=Service,$AccountsDN" | Select-Object Name, Enabled | Format-Table -AutoSize

Write-Host "Admin Accounts:" -ForegroundColor White
Get-ADUser -Filter * -SearchBase "OU=Admin,$AccountsDN" | Select-Object Name, Enabled | Format-Table -AutoSize

Write-Host "Service account delegation flags:" -ForegroundColor White
Get-ADUser -Filter 'SamAccountName -like "svc_*"' -Properties AccountNotDelegated |
    Select-Object Name, AccountNotDelegated | Format-Table -AutoSize

Write-Host "Group membership summary:" -ForegroundColor White
foreach ($g in @("vCenter_Admins","NSX_Service_Accounts","Veeam_Service_Accounts","FGPP-ServiceAccounts")) {
    $members = (Get-ADGroupMember -Identity $g | Select-Object -ExpandProperty Name) -join ", "
    Write-Host "  $g : $members" -ForegroundColor White
}

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 5 of 11 - COMPLETE" -ForegroundColor Green
Write-Host " Next: Run 06a-ADCS-Install.ps1 on $DC2" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
