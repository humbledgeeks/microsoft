#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 6a of 11 - AD Certificate Services Install
.DESCRIPTION
    Install Enterprise Root CA and configure certificate templates.
    *** Run on: dc02 (or dedicated CA member server) ***
.NOTES
    Domain: corp.example.com
    Prerequisites: Plan 1 complete
#>

# --- Environment ---
$DC1    = "dc01"
$DC2    = "dc02"
$Domain = "corp.example.com"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 6a of 11 - AD CS Install" -ForegroundColor Yellow
Write-Host " *** Run on: $DC2 ***" -ForegroundColor Red
Write-Host "============================================`n" -ForegroundColor Yellow

$currentHost = $env:COMPUTERNAME
if ($currentHost -ne $DC2) {
    Write-Host "[WARNING] This script should run on $DC2, but you are on $currentHost." -ForegroundColor Red
    $confirm = Read-Host "Continue anyway? (y/N)"
    if ($confirm -ne "y") { exit }
}

# ============================================================
# Step 6A-1: Install AD CS Role
# ============================================================
Write-Host "=== Step 6A-1: Install AD CS Role ===" -ForegroundColor Cyan

$feature = Get-WindowsFeature ADCS-Cert-Authority
if ($feature.Installed) {
    Write-Host "[OK] ADCS-Cert-Authority already installed." -ForegroundColor Green
} else {
    Write-Host "Installing AD CS role..." -ForegroundColor Yellow
    Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools
    Write-Host "[OK] AD CS role installed." -ForegroundColor Green
}

Read-Host "`nPress Enter to configure the CA"

# ============================================================
# Step 6A-2: Configure Enterprise Root CA
# ============================================================
Write-Host "`n=== Step 6A-2: Configure Enterprise Root CA ===" -ForegroundColor Cyan
Write-Host "CA Name: Corp-Root-CA" -ForegroundColor White
Write-Host "Key: 4096-bit RSA, SHA256, 10-year validity" -ForegroundColor White

try {
    Install-AdcsCertificationAuthority `
        -CAType EnterpriseRootCA `
        -CACommonName "Corp-Root-CA" `
        -KeyLength 4096 `
        -HashAlgorithmName SHA256 `
        -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
        -ValidityPeriod Years `
        -ValidityPeriodUnits 10 `
        -Force
    Write-Host "[OK] Enterprise Root CA configured successfully." -ForegroundColor Green
}
catch {
    if ($_.Exception.Message -like "*already configured*" -or $_.Exception.Message -like "*already installed*") {
        Write-Host "[OK] CA already configured." -ForegroundColor Green
    } else {
        Write-Host "[ERROR] CA configuration failed: $_" -ForegroundColor Red
        Write-Host "If the CA was partially configured, you may need to remove and reconfigure." -ForegroundColor Yellow
    }
}

Read-Host "`nPress Enter to verify certificate templates"

# ============================================================
# Step 6A-3: Verify and Publish Certificate Templates
# ============================================================
Write-Host "`n=== Step 6A-3: Verify Certificate Templates ===" -ForegroundColor Cyan

Write-Host "Checking published templates..." -ForegroundColor White
$templates = certutil -CATemplates 2>&1
Write-Host $templates

if ($templates -match "KerberosAuthentication") {
    Write-Host "[OK] KerberosAuthentication template published." -ForegroundColor Green
} else {
    Write-Host "Publishing KerberosAuthentication template..." -ForegroundColor Yellow
    certutil -SetCATemplates +KerberosAuthentication
}

if ($templates -match "DomainControllerAuthentication") {
    Write-Host "[OK] DomainControllerAuthentication template published." -ForegroundColor Green
} else {
    Write-Host "Publishing DomainControllerAuthentication template..." -ForegroundColor Yellow
    certutil -SetCATemplates +DomainControllerAuthentication
}

# ============================================================
# Verify CRL Distribution
# ============================================================
Write-Host "`n=== Verify CRL Distribution ===" -ForegroundColor Cyan
certutil -getreg CA\CRLPublicationURLs

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 6a of 11 - COMPLETE (CA installed on $DC2)" -ForegroundColor Green
Write-Host " Next: Run 06b-ADCS-Enroll-Validate.ps1 on $DC1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
