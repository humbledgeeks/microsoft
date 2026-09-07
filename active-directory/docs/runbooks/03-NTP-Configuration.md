> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 3 of 11 — Time Synchronization (NTP)

## Environment

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11 (PDC Emulator)
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
```

---

**Goal:** Configure PDC Emulator (dc01) to sync from reliable external NTP. Secondary DC syncs from domain hierarchy. All domain-joined machines automatically sync from DCs. Non-domain devices (ESXi, switches, appliances) should be pointed to 192.0.2.11 and 192.0.2.12 as their NTP servers.

## 3A. PDC Emulator — External NTP (dc01 only)

```powershell
w32tm /config /manualpeerlist:"time.cloudflare.com time.google.com time.windows.com" `
    /syncfromflags:manual /reliable:yes /update
Restart-Service w32time
w32tm /resync /force
```

## 3B. Secondary DC — Domain Hierarchy (dc02)

```powershell
w32tm /config /syncfromflags:domhier /update
Restart-Service w32time
```

## NTP Hierarchy

```
External NTP (Cloudflare, Google, Microsoft)
    |
    v
dc01 (PDC Emulator) — 192.0.2.11
    |
    v
dc02 — 192.0.2.12
    |
    v
All domain-joined machines (automatic via Windows Time Service)

Non-domain devices (ESXi, switches, storage) --> point to 192.0.2.11 / 192.0.2.12
```

## Validation

```powershell
# On dc01 — should show one of the external NTP servers
w32tm /query /source
w32tm /query /status

# On dc02 — should show dc01.corp.example.com
w32tm /query /source
w32tm /query /peers
```
