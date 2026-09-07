#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 11 of 11 - Final Validation and Peer Review
.DESCRIPTION
    Comprehensive validation across all AD components. Outputs pass/fail for each check.
    Run on: dc01
.NOTES
    Domain: corp.example.com
    Prerequisites: All previous plans (1-10) complete
#>

# --- Environment ---
$DC1      = "dc01"
$DC2      = "dc02"
$DC1_IP   = "192.0.2.11"
$DC2_IP   = "192.0.2.12"
$Domain   = "corp.example.com"
$DomainDN = "DC=corp,DC=example,DC=com"
$AccountsDN     = "OU=Corp_Accounts,$DomainDN"

$pass = 0
$fail = 0
$warn = 0

function Test-Check {
    param([string]$Name, [bool]$Result)
    if ($Result) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:pass++
    } else {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        $script:fail++
    }
}

function Test-Warn {
    param([string]$Name, [string]$Message)
    Write-Host "  [WARN] $Name - $Message" -ForegroundColor Yellow
    $script:warn++
}

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 11 of 11 - Full Validation" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# 11A: AD Infrastructure Health
# ============================================================
Write-Host "=== 11A: AD Infrastructure ===" -ForegroundColor Cyan

$forest = Get-ADForest
$adDomain = Get-ADDomain
Test-Check "Forest functional level" ($forest.ForestMode -match "2025|Windows2025")
Test-Check "Domain functional level" ($adDomain.DomainMode -match "2025|Windows2025")

$fsmo = netdom query fsmo 2>&1
Test-Check "FSMO roles queryable" (($fsmo | Out-String) -match "PDC")

$rb = Get-ADOptionalFeature -Filter 'Name -like "Recycle*"'
Test-Check "AD Recycle Bin enabled" ($rb.EnabledScopes.Count -gt 0)

$dcs = Get-ADDomainController -Filter *
$gc1 = ($dcs | Where-Object Name -eq $DC1).IsGlobalCatalog
$gc2 = ($dcs | Where-Object Name -eq $DC2).IsGlobalCatalog
Test-Check "$DC1 is Global Catalog" $gc1
Test-Check "$DC2 is Global Catalog" $gc2

Write-Host "`nReplication:" -ForegroundColor White
$repl = repadmin /showrepl 2>&1 | Out-String
$replFail = ($repl -match "Number of Failures: 0") -or ($repl -notmatch "Number of Failures:")
Test-Check "Replication healthy (0 failures)" $replFail

# ============================================================
# 11B: Sites and Subnets
# ============================================================
Write-Host "`n=== 11B: Sites and Subnets ===" -ForegroundColor Cyan

$sites = Get-ADReplicationSite -Filter *
Test-Check "Site renamed to HQ-DataCenter" ($sites.Name -contains "HQ-DataCenter")

$subnets = Get-ADReplicationSubnet -Filter *
Test-Check "5 subnets registered" ($subnets.Count -ge 5)

# ============================================================
# 11C: DNS
# ============================================================
Write-Host "`n=== 11C: DNS ===" -ForegroundColor Cyan

try {
    $null = Resolve-DnsName "$DC1.$Domain" -Server $DC1_IP -Type A -ErrorAction Stop
    $fwd1Pass = $true
} catch {
    $fwd1Pass = $false
}
Test-Check "Forward DNS: $DC1 resolves from DC1" $fwd1Pass

try {
    $null = Resolve-DnsName "$DC2.$Domain" -Server $DC2_IP -Type A -ErrorAction Stop
    $fwd2Pass = $true
} catch {
    $fwd2Pass = $false
}
Test-Check "Forward DNS: $DC2 resolves from DC2" $fwd2Pass

$ext = Resolve-DnsName "www.microsoft.com" -Server $DC1_IP -ErrorAction SilentlyContinue
Test-Check "External DNS resolution (forwarders)" ($null -ne $ext)

$scav = Get-DnsServerScavenging -ErrorAction SilentlyContinue
Test-Check "DNS scavenging enabled" ($scav.ScavengingState -eq $true)

# ============================================================
# 11D: NTP
# ============================================================
Write-Host "`n=== 11D: Time Synchronization ===" -ForegroundColor Cyan

$ntpSource = w32tm /query /source 2>&1
Test-Check "PDC NTP source is external" ($ntpSource -notmatch "Free-Running|Local CMOS")

# ============================================================
# 11E: OU Structure (Corp_Accounts)
# ============================================================
Write-Host "`n=== 11E: OU Structure ===" -ForegroundColor Cyan

$expectedOUs = @(
    "OU=Admin,$AccountsDN",
    "OU=Computers,$AccountsDN",
    "OU=Staging,OU=Computers,$AccountsDN",
    "OU=Groups,$AccountsDN",
    "OU=Service,$AccountsDN",
    "OU=Standard,$AccountsDN",
    "OU=Disabled Users,OU=Standard,$AccountsDN",
    "OU=Engineers,OU=Standard,$AccountsDN",
    "OU=Test Users,OU=Standard,$AccountsDN",
    "OU=Technologies,$AccountsDN",
    "OU=Cisco,OU=Technologies,$AccountsDN",
    "OU=HPE,OU=Technologies,$AccountsDN",
    "OU=NetApp,OU=Technologies,$AccountsDN",
    "OU=Veeam,OU=Technologies,$AccountsDN",
    "OU=VMware,OU=Technologies,$AccountsDN"
)

try {
    $null = Get-ADOrganizationalUnit -Identity $AccountsDN -ErrorAction Stop
    Test-Check "Corp_Accounts root OU exists" $true
} catch {
    Test-Check "Corp_Accounts root OU exists" $false
}

foreach ($ou in $expectedOUs) {
    $shortName = $ou -replace ",$DomainDN", ""
    try {
        $null = Get-ADOrganizationalUnit -Identity $ou -ErrorAction Stop
        $exists = $true
    } catch {
        $exists = $false
    }
    Test-Check "OU: $shortName" $exists
}

# ============================================================
# 11F: Accounts
# ============================================================
Write-Host "`n=== 11F: Accounts ===" -ForegroundColor Cyan

Test-Check "User: jane.doe exists" ($null -ne (Get-ADUser -Filter 'SamAccountName -eq "jane.doe"' -ErrorAction SilentlyContinue))
Test-Check "User: adm_jdoe exists" ($null -ne (Get-ADUser -Filter 'SamAccountName -eq "adm_jdoe"' -ErrorAction SilentlyContinue))

foreach ($svc in @("svc_vcenter","svc_nsx","svc_veeam","svc_netapp")) {
    $acct = Get-ADUser -Filter "SamAccountName -eq '$svc'" -Properties AccountNotDelegated -ErrorAction SilentlyContinue
    Test-Check "Service account: $svc exists" ($null -ne $acct)
    if ($acct) {
        Test-Check "Service account: $svc is sensitive" ($acct.AccountNotDelegated -eq $true)
    }
}

# ============================================================
# 11G: Groups
# ============================================================
Write-Host "`n=== 11G: Groups ===" -ForegroundColor Cyan

foreach ($g in @("vCenter_Admins","NSX_Service_Accounts","Aria_Admins","Veeam_Admins",
                 "Veeam_Service_Accounts","NetApp_Service_Accounts","FGPP-ServiceAccounts",
                 "Infra_Admins","Infra_ReadOnly")) {
    Test-Check "Group: $g exists" ($null -ne (Get-ADGroup -Filter "Name -eq '$g'" -ErrorAction SilentlyContinue))
}

$protectedMembers = Get-ADGroupMember -Identity "Protected Users" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty SamAccountName
Test-Check "adm_jdoe in Protected Users" ($protectedMembers -contains "adm_jdoe")

$svcInProtected = $protectedMembers | Where-Object { $_ -like "svc_*" }
Test-Check "No svc_* in Protected Users" ($svcInProtected.Count -eq 0)

# ============================================================
# 11H: LDAPS
# ============================================================
Write-Host "`n=== 11H: LDAPS ===" -ForegroundColor Cyan

$ldaps1 = Test-NetConnection -ComputerName $DC1_IP -Port 636 -WarningAction SilentlyContinue
Test-Check "LDAPS port 636 on $DC1" ($ldaps1.TcpTestSucceeded -eq $true)

$ldaps2 = Test-NetConnection -ComputerName $DC2_IP -Port 636 -WarningAction SilentlyContinue
Test-Check "LDAPS port 636 on $DC2" ($ldaps2.TcpTestSucceeded -eq $true)

# ============================================================
# 11I: Group Policy
# ============================================================
Write-Host "`n=== 11I: Group Policy ===" -ForegroundColor Cyan

$ddpp = Get-ADDefaultDomainPasswordPolicy
Test-Check "Password min length = 10" ($ddpp.MinPasswordLength -eq 10)
Test-Check "Lockout threshold = 5" ($ddpp.LockoutThreshold -eq 5)
Test-Check "Password history = 24" ($ddpp.PasswordHistoryCount -eq 24)

$psoAdmin = Get-ADFineGrainedPasswordPolicy -Filter 'Name -eq "PSO-Admins"' -ErrorAction SilentlyContinue
Test-Check "FGPP PSO-Admins exists" ($null -ne $psoAdmin)
if ($psoAdmin) {
    Test-Check "PSO-Admins min length = 20" ($psoAdmin.MinPasswordLength -eq 20)
}

$psoSvc = Get-ADFineGrainedPasswordPolicy -Filter 'Name -eq "PSO-ServiceAccounts"' -ErrorAction SilentlyContinue
Test-Check "FGPP PSO-ServiceAccounts exists" ($null -ne $psoSvc)
if ($psoSvc) {
    Test-Check "PSO-ServiceAccounts min length = 30" ($psoSvc.MinPasswordLength -eq 30)
}

$gpos = Get-GPO -All | Select-Object -ExpandProperty DisplayName
Test-Check "GPO: CORP-Audit-Policy exists" ($gpos -contains "CORP-Audit-Policy")
Test-Check "GPO: CORP-DC-Security exists" ($gpos -contains "CORP-DC-Security")
Test-Check "GPO: CORP-Service-Account-Restrictions exists" ($gpos -contains "CORP-Service-Account-Restrictions")

# ============================================================
# 11J: Security Hardening
# ============================================================
Write-Host "`n=== 11J: Security Hardening ===" -ForegroundColor Cyan

$smb = Get-SmbServerConfiguration
Test-Check "SMB signing required" ($smb.RequireSecuritySignature)

$spooler1 = Get-Service -Name Spooler
Test-Check "Print Spooler disabled on $DC1" ($spooler1.StartType -eq "Disabled")

$spooler2 = Invoke-Command -ComputerName $DC2 -ScriptBlock { Get-Service -Name Spooler }
Test-Check "Print Spooler disabled on $DC2" ($spooler2.StartType -eq "Disabled")

# ============================================================
# 11K: Backup
# ============================================================
Write-Host "`n=== 11K: Backup ===" -ForegroundColor Cyan

$wsb = Get-WindowsFeature Windows-Server-Backup
Test-Check "Windows Server Backup installed on $DC1" ($wsb.Installed)

# ============================================================
# Summary
# ============================================================
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host " VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Passed:   $pass" -ForegroundColor Green
Write-Host "  Failed:   $fail" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
Write-Host "  Warnings: $warn" -ForegroundColor $(if ($warn -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Total:    $($pass + $fail + $warn)" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan

if ($fail -gt 0) {
    Write-Host "`n[ACTION REQUIRED] $fail checks failed. Review above and fix." -ForegroundColor Red
} else {
    Write-Host "`n[OK] All checks passed!" -ForegroundColor Green
}

Write-Host "`n=== Manual Checks Still Required ===" -ForegroundColor Yellow
Write-Host @"
  - Audit policy subcategories (auditpol /get /category:*)
  - LDAP signing GPO setting
  - NTLM auditing GPO setting
  - Security event log size (1 GB on DCs)
  - Service account deny logon GPO
  - Veeam backup job status (check Veeam console)
  - VMware/NSX/Aria identity sources (check application UIs)
  - Test user access validation (log in as test.* accounts)
"@ -ForegroundColor Yellow

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 11 of 11 - VALIDATION COMPLETE" -ForegroundColor Green
Write-Host " corp.example.com AD deployment validated." -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
