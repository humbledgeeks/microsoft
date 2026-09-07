#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    Plan 2 of 11 - AD Sites, Subnets, and DNS Configuration
.DESCRIPTION
    Rename default site, register subnets, configure DNS forwarders, scavenging, and DC DNS client.
    Forward/reverse DNS zones already exist - skip zone creation.
    Run on: dc01 (remotes to dc02 for DNS client and forwarders)
.NOTES
    Domain: corp.example.com
    Prerequisites: Plan 1 complete
#>

# --- Environment ---
$DC1      = "dc01"
$DC2      = "dc02"
$DC1_IP   = "192.0.2.11"
$DC2_IP   = "192.0.2.12"
$Domain   = "corp.example.com"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " Plan 2 of 11 - Sites, Subnets, and DNS" -ForegroundColor Yellow
Write-Host " Run on: $DC1" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 2A: Rename Default Site
# ============================================================
Write-Host "=== Step 2A: Rename Default Site ===" -ForegroundColor Cyan
Write-Host "This renames the AD Site object only. Domain name does NOT change." -ForegroundColor White

try {
    $site = Get-ADReplicationSite -Identity "Default-First-Site-Name" -ErrorAction Stop
    $site | Rename-ADObject -NewName "HQ-DataCenter"
    Write-Host "[OK] Site renamed to HQ-DataCenter." -ForegroundColor Green
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Host "[OK] Default-First-Site-Name not found - likely already renamed." -ForegroundColor Green
    $existing = Get-ADReplicationSite -Filter * | Select-Object -ExpandProperty Name
    Write-Host "Existing sites: $($existing -join ', ')" -ForegroundColor White
}
catch {
    Write-Host "[ERROR] $_" -ForegroundColor Red
}

Read-Host "`nPress Enter to continue to subnet registration"

# ============================================================
# Step 2B: Register Subnets
# ============================================================
Write-Host "`n=== Step 2B: Register Subnets ===" -ForegroundColor Cyan

$subnets = @(
    @{ Name = "198.51.100.0/25";  Desc = "ESXi Management" },
    @{ Name = "198.51.100.128/25";  Desc = "vMotion" },
    @{ Name = "203.0.113.0/25";  Desc = "Application Servers" },
    @{ Name = "192.0.2.0/24";  Desc = "Server Management - DCs/DNS" },
    @{ Name = "203.0.113.128/25"; Desc = "Jump Servers" }
)

foreach ($s in $subnets) {
    try {
        New-ADReplicationSubnet -Name $s.Name -Site "HQ-DataCenter" -Description $s.Desc -ErrorAction Stop
        Write-Host "[OK] Subnet $($s.Name) - $($s.Desc)" -ForegroundColor Green
    }
    catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "[OK] Subnet $($s.Name) already exists." -ForegroundColor Green
        } else {
            Write-Host "[ERROR] Subnet $($s.Name): $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nRegistered subnets:" -ForegroundColor Yellow
Get-ADReplicationSubnet -Filter * | Select-Object Name, Site, Description | Format-Table -AutoSize

Read-Host "`nPress Enter to continue to DNS forwarders"

# ============================================================
# Step 2C: DNS Forwarders (both DCs)
# ============================================================
Write-Host "`n=== Step 2C: DNS Forwarders ===" -ForegroundColor Cyan

$forwarders = @("1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4")

Write-Host "Setting forwarders on $DC1..." -ForegroundColor White
Set-DnsServerForwarder -IPAddress $forwarders -UseRootHint $false
Write-Host "[OK] Forwarders set on $DC1." -ForegroundColor Green

Write-Host "Setting forwarders on $DC2..." -ForegroundColor White
Invoke-Command -ComputerName $DC2 -ScriptBlock {
    Set-DnsServerForwarder -IPAddress $using:forwarders -UseRootHint $false
}
Write-Host "[OK] Forwarders set on $DC2." -ForegroundColor Green

Read-Host "`nPress Enter to continue to DNS aging and scavenging"

# ============================================================
# Step 2D: DNS Aging and Scavenging
# ============================================================
Write-Host "`n=== Step 2D: DNS Aging and Scavenging ===" -ForegroundColor Cyan

Write-Host "Enabling aging on forward zone..." -ForegroundColor White
Set-DnsServerZoneAging -Name $Domain -Aging $true `
    -NoRefreshInterval 7.00:00:00 -RefreshInterval 7.00:00:00
Write-Host "[OK] Aging enabled on $Domain." -ForegroundColor Green

$reverseZones = @("2.0.192.in-addr.arpa", "100.51.198.in-addr.arpa", "113.0.203.in-addr.arpa")
foreach ($zone in $reverseZones) {
    try {
        Set-DnsServerZoneAging -Name $zone -Aging $true `
            -NoRefreshInterval 7.00:00:00 -RefreshInterval 7.00:00:00 -ErrorAction Stop
        Write-Host "[OK] Aging enabled on $zone." -ForegroundColor Green
    }
    catch {
        Write-Host "[WARN] Could not set aging on ${zone}: $_" -ForegroundColor Yellow
    }
}

Write-Host "`nEnabling scavenging on $DC1 ONLY..." -ForegroundColor White
Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00
Write-Host "[OK] Scavenging enabled on $DC1." -ForegroundColor Green

Read-Host "`nPress Enter to continue to DNS client configuration"

# ============================================================
# Step 2E: DNS Client Configuration on DCs
# ============================================================
Write-Host "`n=== Step 2E: DNS Client Configuration ===" -ForegroundColor Cyan
Write-Host "Each DC points to itself first, then partner. No 127.0.0.1." -ForegroundColor White

Write-Host "`nCurrent NIC on $DC1 :" -ForegroundColor Yellow
Get-NetAdapter | Select-Object Name, Status, InterfaceDescription | Format-Table -AutoSize

$nic = (Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1).Name
Write-Host "Using NIC: $nic" -ForegroundColor White

Set-DnsClientServerAddress -InterfaceAlias $nic -ServerAddresses @($DC1_IP, $DC2_IP)
Write-Host "[OK] $DC1 DNS: Primary=$DC1_IP, Secondary=$DC2_IP" -ForegroundColor Green

Write-Host "`nConfiguring DNS client on $DC2..." -ForegroundColor White
Invoke-Command -ComputerName $DC2 -ScriptBlock {
    $nic = (Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1).Name
    Set-DnsClientServerAddress -InterfaceAlias $nic -ServerAddresses @($using:DC2_IP, $using:DC1_IP)
    Write-Host "[OK] $using:DC2 DNS: Primary=$using:DC2_IP, Secondary=$using:DC1_IP"
}
Write-Host "[OK] DNS client configured on both DCs." -ForegroundColor Green

# ============================================================
# Final Validation
# ============================================================
Write-Host "`n=== Plan 2 - Final Validation ===" -ForegroundColor Cyan

Write-Host "`nSites:" -ForegroundColor White
Get-ADReplicationSite -Filter * | Select-Object Name | Format-Table -AutoSize

Write-Host "Subnets:" -ForegroundColor White
Get-ADReplicationSubnet -Filter * | Select-Object Name, Site, Description | Format-Table -AutoSize

Write-Host "Forwarders ($DC1):" -ForegroundColor White
Get-DnsServerForwarder | Select-Object -ExpandProperty IPAddress | Format-Table -AutoSize

Write-Host "Zone Aging:" -ForegroundColor White
Get-DnsServerZoneAging -Name $Domain | Format-Table -AutoSize

Write-Host "Scavenging:" -ForegroundColor White
Get-DnsServerScavenging | Format-Table -AutoSize

Write-Host "DNS Resolution Tests:" -ForegroundColor White
Resolve-DnsName "$DC1.$Domain" -Server $DC1_IP -ErrorAction SilentlyContinue | Select-Object Name, IPAddress | Format-Table -AutoSize
Resolve-DnsName "$DC2.$Domain" -Server $DC2_IP -ErrorAction SilentlyContinue | Select-Object Name, IPAddress | Format-Table -AutoSize
Resolve-DnsName "www.microsoft.com" -Server $DC1_IP -ErrorAction SilentlyContinue | Select-Object -First 1 Name, IPAddress | Format-Table -AutoSize

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " Plan 2 of 11 - COMPLETE" -ForegroundColor Green
Write-Host " Next: Run 03-NTP.ps1 on $DC1" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
