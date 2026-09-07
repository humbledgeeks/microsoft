#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 1 of 11 - AD Core Infrastructure
.DESCRIPTION
    Set functional levels, place FSMO roles, enable Recycle Bin, verify Global Catalogs.
    Run on: dc01
.NOTES
    Domain: corp.example.com
    Prerequisites: Both DCs promoted and running Windows Server 2025
#>

# --- Environment ---
$DC1      = "dc01"
$DC2      = "dc02"
$Domain   = "corp.example.com"
$DomainDN = "DC=corp,DC=example,DC=com"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 1 of 11 - AD Core Infrastructure" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 1A: Verify Replication Health (must be healthy first)
# ============================================================
Write-Host "=== Step 1A: Verify Replication Health ===" -ForegroundColor Cyan

repadmin /replsummary

Write-Host "`nReview the output above. There should be 0 failures." -ForegroundColor Yellow
Read-Host "Press Enter to continue if replication is healthy"

# ============================================================
# Step 1B: Check and Raise Functional Levels
# ============================================================
Write-Host "`n=== Step 1B: Forest and Domain Functional Levels ===" -ForegroundColor Cyan

$forest = Get-ADForest
$adDomain = Get-ADDomain

Write-Host "Current Forest Mode: $($forest.ForestMode)" -ForegroundColor White
Write-Host "Current Domain Mode: $($adDomain.DomainMode)" -ForegroundColor White

if ($forest.ForestMode -ne "Windows2025Forest") {
    Write-Host "`nRaising Forest Functional Level to Windows Server 2025..." -ForegroundColor Yellow
    try {
        Set-ADForestMode -Identity $Domain -ForestMode Windows2025Forest -Confirm:$false
        Write-Host "[OK] Forest functional level raised." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to raise forest level: $_" -ForegroundColor Red
        Write-Host "Verify the exact enum value for your Server 2025 build." -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] Forest already at Windows2025Forest." -ForegroundColor Green
}

if ($adDomain.DomainMode -ne "Windows2025Domain") {
    Write-Host "Raising Domain Functional Level to Windows Server 2025..." -ForegroundColor Yellow
    try {
        Set-ADDomainMode -Identity $Domain -DomainMode Windows2025Domain -Confirm:$false
        Write-Host "[OK] Domain functional level raised." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to raise domain level: $_" -ForegroundColor Red
        Write-Host "Verify the exact enum value for your Server 2025 build." -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] Domain already at Windows2025Domain." -ForegroundColor Green
}

Read-Host "`nPress Enter to continue to FSMO placement"

# ============================================================
# Step 1C: FSMO Role Placement
# ============================================================
Write-Host "`n=== Step 1C: FSMO Role Placement ===" -ForegroundColor Cyan
Write-Host "Target layout:" -ForegroundColor White
Write-Host "  $DC1 : PDC Emulator, RID Master" -ForegroundColor White
Write-Host "  $DC2 : Schema Master, Domain Naming Master, Infrastructure Master" -ForegroundColor White

Write-Host "`nCurrent FSMO holders:" -ForegroundColor Yellow
netdom query fsmo

Write-Host "`nMoving roles to target DCs..." -ForegroundColor Yellow

try {
    Move-ADDirectoryServerOperationMasterRole -Identity $DC1 `
        -OperationMasterRole PDCEmulator, RIDMaster -Confirm:$false -ErrorAction Stop
    Write-Host "[OK] PDC Emulator and RID Master moved to $DC1" -ForegroundColor Green
}
catch {
    Write-Host "[INFO] PDC Emulator / RID Master may already be on $DC1 : $_" -ForegroundColor Yellow
}

try {
    Move-ADDirectoryServerOperationMasterRole -Identity $DC2 `
        -OperationMasterRole SchemaMaster, DomainNamingMaster, InfrastructureMaster -Confirm:$false -ErrorAction Stop
    Write-Host "[OK] Schema, Domain Naming, Infrastructure Master moved to $DC2" -ForegroundColor Green
}
catch {
    Write-Host "[INFO] Schema / Domain Naming / Infrastructure may already be on $DC2 : $_" -ForegroundColor Yellow
}

Write-Host "`nVerifying FSMO placement:" -ForegroundColor Yellow
netdom query fsmo

Read-Host "`nPress Enter to continue to Recycle Bin"

# ============================================================
# Step 1D: Enable AD Recycle Bin
# ============================================================
Write-Host "`n=== Step 1D: Enable AD Recycle Bin ===" -ForegroundColor Cyan

$recycleBin = Get-ADOptionalFeature -Filter 'Name -like "Recycle*"'
if ($recycleBin.EnabledScopes.Count -gt 0) {
    Write-Host "[OK] AD Recycle Bin is already enabled." -ForegroundColor Green
} else {
    Write-Host "Enabling AD Recycle Bin (irreversible)..." -ForegroundColor Yellow
    try {
        Enable-ADOptionalFeature -Identity $recycleBin.DistinguishedName `
            -Scope ForestOrConfigurationSet `
            -Target (Get-ADForest).RootDomain `
            -Confirm:$false
        Write-Host "[OK] AD Recycle Bin enabled." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to enable Recycle Bin: $_" -ForegroundColor Red
    }
}

Read-Host "`nPress Enter to continue to Global Catalog verification"

# ============================================================
# Step 1E: Verify Global Catalogs
# ============================================================
Write-Host "`n=== Step 1E: Verify Global Catalogs ===" -ForegroundColor Cyan

Get-ADDomainController -Filter * | Select-Object Name, IsGlobalCatalog | Format-Table -AutoSize

Write-Host "Both DCs must show IsGlobalCatalog = True." -ForegroundColor Yellow
Write-Host "If not, enable via AD Sites and Services -> Server -> NTDS Settings -> Global Catalog checkbox." -ForegroundColor Yellow

# ============================================================
# Final Validation
# ============================================================
Write-Host "`n=== Plan 1 - Final Validation ===" -ForegroundColor Cyan

Write-Host "`nFunctional Levels:" -ForegroundColor White
Get-ADForest | Select-Object ForestMode | Format-Table -AutoSize
Get-ADDomain | Select-Object DomainMode | Format-Table -AutoSize

Write-Host "FSMO Roles:" -ForegroundColor White
netdom query fsmo

Write-Host "`nRecycle Bin:" -ForegroundColor White
Get-ADOptionalFeature -Filter 'Name -like "Recycle*"' | Select-Object Name, EnabledScopes | Format-Table -AutoSize

Write-Host "Global Catalogs:" -ForegroundColor White
Get-ADDomainController -Filter * | Select-Object Name, IsGlobalCatalog | Format-Table -AutoSize

Write-Host "Replication:" -ForegroundColor White
repadmin /replsummary

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 1 of 11 - COMPLETE" -ForegroundColor Green
Write-Host " Next: Run 02-Sites-DNS.ps1 on $DC1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
