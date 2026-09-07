#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Shared environment variables for corp.example.com AD deployment
.DESCRIPTION
    Dot-source this file from other scripts: . .\00-Environment.ps1
    Or each script has these variables hardcoded at the top for standalone use.
.NOTES
    Domain: corp.example.com
#>

$DC1        = "dc01"
$DC2        = "dc02"
$DC1_IP     = "192.0.2.11"
$DC2_IP     = "192.0.2.12"
$Domain     = "corp.example.com"
$DomainDN   = "DC=corp,DC=example,DC=com"
$DomainNB   = "CORP"

# Subnet definitions
$Subnets = @(
    @{ Name = "198.51.100.0/25";  Desc = "ESXi Management" },
    @{ Name = "198.51.100.128/25";  Desc = "vMotion" },
    @{ Name = "203.0.113.0/25";  Desc = "Application Servers" },
    @{ Name = "192.0.2.0/24";  Desc = "Server Management - DCs/DNS" },
    @{ Name = "203.0.113.128/25"; Desc = "Jump Servers" }
)

# Reverse DNS zones (vMotion and App Servers omitted intentionally)
$ReverseZones = @("2.0.192.in-addr.arpa", "100.51.198.in-addr.arpa", "113.0.203.in-addr.arpa")

# OU Structure (Corp_Accounts)
$AccountsDN           = "OU=Corp_Accounts,$DomainDN"
$AdminOU        = "OU=Admin,$AccountsDN"
$ComputersOU    = "OU=Computers,$AccountsDN"
$StagingOU      = "OU=Staging,$ComputersOU"
$GroupsOU       = "OU=Groups,$AccountsDN"
$ServiceOU      = "OU=Service,$AccountsDN"
$StandardOU     = "OU=Standard,$AccountsDN"
$TestUsersOU    = "OU=Test Users,$StandardOU"
$TechOU         = "OU=Technologies,$AccountsDN"

# Service accounts
$ServiceAccounts = @("svc_vcenter", "svc_nsx", "svc_veeam", "svc_netapp")

# NTP servers
$NTPServers = "time.cloudflare.com time.google.com time.windows.com"

Write-Host "[OK] Environment variables loaded for $Domain" -ForegroundColor Green
