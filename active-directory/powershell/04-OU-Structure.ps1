#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 4 of 11 - OU Structure
.DESCRIPTION
    Create Corp_Accounts OU hierarchy and redirect default computer container to Staging.
    Run on: dc01
.NOTES
    Domain: corp.example.com
    Prerequisites: Plan 1 complete
#>

# --- Environment ---
$DC1      = "dc01"
$DomainDN = "DC=corp,DC=example,DC=com"
$AccountsDN     = "OU=Corp_Accounts,$DomainDN"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 4 of 11 - OU Structure" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 4A: Create OU Structure
# ============================================================
Write-Host "=== Step 4A: Create OU Hierarchy ===" -ForegroundColor Cyan

function New-OUIfNotExists {
    param([string]$Name, [string]$Path, [string]$Description = "")
    $dn = "OU=$Name,$Path"
    try {
        $null = Get-ADOrganizationalUnit -Identity $dn -ErrorAction Stop
        Write-Host "[OK] Already exists: $Name" -ForegroundColor Green
    } catch {
        $params = @{
            Name = $Name
            Path = $Path
            ProtectedFromAccidentalDeletion = $true
        }
        if ($Description) { $params.Description = $Description }
        New-ADOrganizationalUnit @params
        Write-Host "[OK] Created: $Name ($Path)" -ForegroundColor Green
    }
}

Write-Host "`nRoot OU:" -ForegroundColor White
New-OUIfNotExists -Name "Corp_Accounts" -Path $DomainDN `
    -Description "Root OU for all managed accounts, groups, and computers - corp.example.com"

Write-Host "`nTop-level OUs:" -ForegroundColor White
New-OUIfNotExists -Name "Admin"        -Path $AccountsDN -Description "Administrative accounts and groups"
New-OUIfNotExists -Name "Computers"    -Path $AccountsDN -Description "Domain-joined computer objects"
New-OUIfNotExists -Name "Groups"       -Path $AccountsDN -Description "Cross-technology security and FGPP groups"
New-OUIfNotExists -Name "Service"      -Path $AccountsDN -Description "Service accounts for application integrations"
New-OUIfNotExists -Name "Standard"     -Path $AccountsDN -Description "Standard user accounts"
New-OUIfNotExists -Name "Technologies" -Path $AccountsDN -Description "Technology vendor-specific security groups"

Write-Host "`nComputer sub-OUs:" -ForegroundColor White
New-OUIfNotExists -Name "Staging" -Path "OU=Computers,$AccountsDN" `
    -Description "Default container for new domain joins (redircmp target)"

Write-Host "`nStandard sub-OUs:" -ForegroundColor White
New-OUIfNotExists -Name "Disabled Users" -Path "OU=Standard,$AccountsDN" -Description "Deactivated user accounts pending deletion"
New-OUIfNotExists -Name "Engineers"      -Path "OU=Standard,$AccountsDN" -Description "Engineering staff accounts"
New-OUIfNotExists -Name "Test Users"     -Path "OU=Standard,$AccountsDN" -Description "Test and validation accounts"

Write-Host "`nTechnology vendor OUs:" -ForegroundColor White
$techBase = "OU=Technologies,$AccountsDN"
New-OUIfNotExists -Name "Cisco"   -Path $techBase -Description "Cisco platform groups"
New-OUIfNotExists -Name "HPE"     -Path $techBase -Description "HPE platform groups"
New-OUIfNotExists -Name "NetApp"  -Path $techBase -Description "NetApp storage platform groups"
New-OUIfNotExists -Name "Veeam"   -Path $techBase -Description "Veeam backup platform groups"
New-OUIfNotExists -Name "VMware"  -Path $techBase -Description "VMware virtualization platform groups"

Write-Host "`nCisco sub-OUs:" -ForegroundColor White
New-OUIfNotExists -Name "UCS"    -Path "OU=Cisco,$techBase" -Description "Cisco UCS compute management groups"
New-OUIfNotExists -Name "Meraki" -Path "OU=Cisco,$techBase" -Description "Cisco Meraki network management groups"

Write-Host "`nHPE sub-OUs:" -ForegroundColor White
New-OUIfNotExists -Name "Synergy" -Path "OU=HPE,$techBase" -Description "HPE Synergy compute management groups"
New-OUIfNotExists -Name "Aruba"   -Path "OU=HPE,$techBase" -Description "HPE Aruba network management groups"

Read-Host "`nPress Enter to redirect default computer container"

# ============================================================
# Step 4B: Redirect Default Computer Container
# ============================================================
Write-Host "`n=== Step 4B: Redirect Default Computer Container ===" -ForegroundColor Cyan
Write-Host "New domain joins will land in Corp_Accounts -> Computers -> Staging instead of CN=Computers." -ForegroundColor White

redircmp "OU=Staging,OU=Computers,$AccountsDN"
Write-Host "[OK] Default computer container redirected to Staging." -ForegroundColor Green

# ============================================================
# Final Validation
# ============================================================
Write-Host "`n=== Plan 4 - Final Validation ===" -ForegroundColor Cyan

Write-Host "`nOU Structure:" -ForegroundColor White
Get-ADOrganizationalUnit -SearchBase $AccountsDN -Filter * |
    Select-Object @{N='OU Path';E={ $_.DistinguishedName -replace ",$DomainDN","" }} |
    Sort-Object 'OU Path' | Format-Table -AutoSize

Write-Host "Default Computer Container:" -ForegroundColor White
(Get-ADDomain).ComputersContainer

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 4 of 11 - COMPLETE" -ForegroundColor Green
Write-Host " Next: Run 05-Accounts-Groups.ps1 on $DC1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
