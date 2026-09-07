> **Example values.** This runbook uses synthetic documentation identifiers (corp.example.com, dc01/dc02, RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Replace them with your own environment values.

# Plan 6 of 11 — AD Certificate Services / LDAPS

## Environment

```
Domain:          corp.example.com
DC1:             dc01  — 192.0.2.11
DC2:             dc02  — 192.0.2.12
OS:              Windows Server 2025
```

---

**Goal:** Install Enterprise Root CA, configure auto-enrollment for DC certificates, enable LDAPS on port 636.

**Decision:** Install on dc02 (not the PDC Emulator). If a dedicated member server is available, use that instead.

## 6A. Install AD CS Role

```powershell
# On the CA server (dc02 or dedicated member server)
Install-WindowsFeature ADCS-Cert-Authority -IncludeManagementTools
```

## 6B. Configure Enterprise Root CA

```powershell
Install-AdcsCertificationAuthority `
    -CAType EnterpriseRootCA `
    -CACommonName "Corp-Root-CA" `
    -KeyLength 4096 `
    -HashAlgorithmName SHA256 `
    -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" `
    -ValidityPeriod Years `
    -ValidityPeriodUnits 10 `
    -Force
```

**Key parameters:**
- `EnterpriseRootCA` — integrates with AD, publishes CA cert automatically, enables auto-enrollment
- `4096-bit RSA` — adequate for a 10-year root
- `SHA256` — current standard
- `10-year validity` — appropriate for a small environment root CA

## 6C. Verify Certificate Templates

```powershell
certutil -CATemplates
# Must see: "KerberosAuthentication" and "DomainControllerAuthentication"

# If missing:
certutil -SetCATemplates +KerberosAuthentication
certutil -SetCATemplates +DomainControllerAuthentication
```

## 6D. Enable Auto-Enrollment via GPO

Configure on the **Default Domain Controllers Policy** via GPMC:

**Path:** `Computer Configuration > Policies > Windows Settings > Security Settings > Public Key Policies > Certificate Services Client - Auto-Enrollment`

- Set to **Enabled**
- Check "Renew expired certificates, update pending certificates, and remove revoked certificates"
- Check "Update certificates that use certificate templates"

```powershell
# Force policy update and trigger enrollment on each DC
Invoke-GPUpdate -Computer "dc01" -Force
Invoke-GPUpdate -Computer "dc02" -Force

# Trigger immediate certificate enrollment (run on EACH DC)
certutil -pulse
```

## 6E. Validate LDAPS

Wait 5 minutes after enrollment, then:

```powershell
# Port 636 must respond on both DCs
Test-NetConnection -ComputerName dc01.corp.example.com -Port 636
Test-NetConnection -ComputerName dc02.corp.example.com -Port 636

# Verify certificate on each DC
certutil -store My
# Look for EKU: Server Authentication / KDC Authentication

# Test LDAPS bind
$null = [System.DirectoryServices.DirectoryEntry]::new("LDAP://dc01.corp.example.com:636")
Write-Host "LDAPS connection successful"
```
