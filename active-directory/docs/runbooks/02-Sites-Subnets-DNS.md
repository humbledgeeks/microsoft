> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 2 of 11 — AD Sites, Subnets, and DNS Configuration

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

**Goal:** Rename default site, register all subnets, configure DNS forwarders and scavenging. Forward/reverse zones already exist — skip zone creation.

## 2A. Rename Default Site

This renames the AD Site object only (not the domain). The domain name corp.example.com does not change.

```powershell
Get-ADReplicationSite -Identity "Default-First-Site-Name" | Rename-ADObject -NewName "HQ-DataCenter"
```

## 2B. Register Subnets

```powershell
$subnets = @(
    @{ Name = "198.51.100.0/25";  Desc = "ESXi Management" },
    @{ Name = "198.51.100.128/25";  Desc = "vMotion" },
    @{ Name = "203.0.113.0/25";  Desc = "Application Servers" },
    @{ Name = "192.0.2.0/24";  Desc = "Server Management - DCs/DNS" },
    @{ Name = "203.0.113.128/25"; Desc = "Jump Servers" }
)

foreach ($s in $subnets) {
    New-ADReplicationSubnet -Name $s.Name -Site "HQ-DataCenter" -Description $s.Desc
}
```

## 2C. DNS Forwarders (run on BOTH DCs)

```powershell
Set-DnsServerForwarder -IPAddress @("1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4") -UseRootHint $false
```

## 2D. DNS Aging and Scavenging

```powershell
# Enable aging on forward zone (run on either DC — AD-integrated replicates the setting)
Set-DnsServerZoneAging -Name "corp.example.com" -Aging $true `
    -NoRefreshInterval 7.00:00:00 -RefreshInterval 7.00:00:00

# Enable aging on reverse zones
foreach ($zone in @("2.0.192.in-addr.arpa", "100.51.198.in-addr.arpa", "113.0.203.in-addr.arpa")) {
    Set-DnsServerZoneAging -Name $zone -Aging $true `
        -NoRefreshInterval 7.00:00:00 -RefreshInterval 7.00:00:00
}

# Enable scavenging on dc01 ONLY (one DC to avoid race conditions)
Set-DnsServerScavenging -ScavengingState $true -ScavengingInterval 7.00:00:00
```

## 2E. DNS Client Configuration on DCs

Each DC should point to its own IP first (not 127.0.0.1), partner second. Use `Get-NetAdapter` to find the correct interface alias.

```powershell
# On dc01
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" `
    -ServerAddresses @("192.0.2.11","192.0.2.12")

# On dc02
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" `
    -ServerAddresses @("192.0.2.12","192.0.2.11")
```

## Validation

```powershell
Get-ADReplicationSite -Filter * | Select-Object Name
Get-ADReplicationSubnet -Filter * | Select-Object Name, Site, Description
Get-DnsServerForwarder
Get-DnsServerZoneAging -Name "corp.example.com"
Get-DnsServerScavenging
Resolve-DnsName dc01.corp.example.com -Server 192.0.2.11
Resolve-DnsName dc02.corp.example.com -Server 192.0.2.12
Resolve-DnsName 192.0.2.11 -Server 192.0.2.11
Resolve-DnsName www.microsoft.com -Server 192.0.2.11
```
