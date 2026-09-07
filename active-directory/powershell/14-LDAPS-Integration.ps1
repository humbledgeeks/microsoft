#Requires -RunAsAdministrator
# EXAMPLE VALUES: this script uses synthetic documentation identifiers (corp.example.com, dc01/dc02,
# RFC 5737 TEST-NET addresses, Corp_/CORP- names, jane.doe). Edit the ENVIRONMENT values before use.
<#
.SYNOPSIS
    LDAPS Integration - Export Root CA cert and configure platform connections
.DESCRIPTION
    Step 1: Export Corp-Root-CA certificate (run once)
    Step 2: Platform-specific LDAPS configuration (NetApp, vCenter, NSX, Veeam)
    Run on: dc02 (CA server) for export, then follow platform steps
.NOTES
    Domain: corp.example.com
    CA: Corp-Root-CA (on dc02)
    Prerequisites: 06a/06b (AD CS) complete, LDAPS validated on port 636
#>

# --- Environment ---
$DC1      = "dc01"
$DC2      = "dc02"
$DC1_IP   = "192.0.2.11"
$DC2_IP   = "192.0.2.12"
$Domain   = "corp.example.com"
$DomainDN = "DC=corp,DC=example,DC=com"
$CertExportPath = "C:\Certs"

Write-Host "`n============================================" -ForegroundColor Yellow
Write-Host " LDAPS Integration Workflow" -ForegroundColor Yellow
Write-Host " Run on: $DC2 (CA server)" -ForegroundColor Yellow
Write-Host "============================================`n" -ForegroundColor Yellow

# ============================================================
# Step 1: Export Root CA Certificate
# ============================================================
Write-Host "=== Step 1: Export Root CA Certificate ===" -ForegroundColor Cyan
Write-Host "This exports the CA cert that every platform needs to trust." -ForegroundColor White

if (-not (Test-Path $CertExportPath)) {
    New-Item -ItemType Directory -Path $CertExportPath -Force | Out-Null
    Write-Host "[OK] Created $CertExportPath" -ForegroundColor Green
}

$caCert = Get-ChildItem -Path Cert:\LocalMachine\CA | Where-Object { $_.Subject -match "Corp-Root-CA" }

if (-not $caCert) {
    Write-Host "[INFO] CA cert not found in local store. Trying remote export from $DC2..." -ForegroundColor Yellow
    $caCert = Invoke-Command -ComputerName $DC2 -ScriptBlock {
        Get-ChildItem -Path Cert:\LocalMachine\CA | Where-Object { $_.Subject -match "Corp-Root-CA" }
    }
}

if ($caCert) {
    # Export as DER (.cer)
    $derPath = "$CertExportPath\Corp-Root-CA.cer"
    [System.IO.File]::WriteAllBytes($derPath, $caCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))
    Write-Host "[OK] Exported DER format: $derPath" -ForegroundColor Green

    # Export as Base64 PEM (.pem) - needed by NetApp, VMware, Linux
    $pemPath = "$CertExportPath\Corp-Root-CA.pem"
    $base64 = [System.Convert]::ToBase64String($caCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert), "InsertLineBreaks")
    $pemContent = "-----BEGIN CERTIFICATE-----`n$base64`n-----END CERTIFICATE-----"
    Set-Content -Path $pemPath -Value $pemContent -Encoding ASCII
    Write-Host "[OK] Exported PEM format: $pemPath" -ForegroundColor Green

    Write-Host "`nCertificate details:" -ForegroundColor White
    Write-Host "  Subject:    $($caCert.Subject)" -ForegroundColor White
    Write-Host "  Thumbprint: $($caCert.Thumbprint)" -ForegroundColor White
    Write-Host "  Expires:    $($caCert.NotAfter)" -ForegroundColor White
} else {
    Write-Host "[ERROR] Corp-Root-CA certificate not found." -ForegroundColor Red
    Write-Host "Run this script on $DC2 (the CA server) or verify the CA name." -ForegroundColor Yellow
    return
}

Write-Host "`n[INFO] Copy these files to a location accessible from each platform:" -ForegroundColor Yellow
Write-Host "  .cer (DER) - Windows platforms (Veeam)" -ForegroundColor White
Write-Host "  .pem (Base64) - NetApp ONTAP, VMware vCenter/NSX" -ForegroundColor White

Read-Host "`nPress Enter to view NetApp LDAPS integration steps"

# ============================================================
# Step 2: NetApp ONTAP - LDAPS Integration
# ============================================================
Write-Host "`n=== Step 2: NetApp ONTAP LDAPS ===" -ForegroundColor Cyan
Write-Host "Target: netapp01.corp.example.com (203.0.113.30)" -ForegroundColor White

Write-Host @"

  Connect to NetApp ONTAP CLI (SSH to 203.0.113.30) and run:

  1. Install the Root CA certificate:
     -----------------------------------------------------------
     security certificate install -type server-ca -vserver <svm-name>
     -----------------------------------------------------------
     When prompted, paste the FULL contents of Corp-Root-CA.pem
     (including BEGIN/END lines), then press Enter twice.

  2. Create LDAP client config with LDAPS:
     -----------------------------------------------------------
     ldap client create -client-config corp-ldaps ^
       -ad-domain corp.example.com ^
       -preferred-ad-servers 192.0.2.11,192.0.2.12 ^
       -schema AD-IDMU ^
       -port 636 ^
       -use-start-tls false ^
       -session-security seal ^
       -base-dn "DC=corp,DC=example,DC=com" ^
       -bind-dn "svc_netapp@corp.example.com" ^
       -bind-password <password> ^
       -vserver <svm-name>
     -----------------------------------------------------------

  3. Apply LDAP client to SVM:
     -----------------------------------------------------------
     ldap client show
     -----------------------------------------------------------

  4. Test LDAP connectivity:
     -----------------------------------------------------------
     ldap check -vserver <svm-name>
     -----------------------------------------------------------

  Replace <svm-name> with your data SVM name.
  Replace <password> with the svc_netapp password.
  Port 636 = LDAPS (TLS-encrypted). No start-tls needed.

"@ -ForegroundColor White

Read-Host "Press Enter to view vCenter LDAPS integration steps"

# ============================================================
# Step 3: VMware vCenter - LDAPS Identity Source
# ============================================================
Write-Host "`n=== Step 3: VMware vCenter LDAPS ===" -ForegroundColor Cyan

Write-Host @"

  A. Import Root CA cert into vCenter trust store:
     1. Log into vCenter (https://<vcenter-fqdn>/ui) as administrator@vsphere.local
     2. Go to: Administration -> Certificates -> Certificate Management
        (or Administration -> Certificates -> Trusted Root Certificates)
     3. Click "Add" and upload Corp-Root-CA.pem

  B. Add LDAPS Identity Source:
     1. Go to: Administration -> Single Sign-On -> Configuration
     2. Click "Identity Providers" -> "Add"
     3. Configure:

        Type .................. Active Directory over LDAPS
        Name .................. corp.example.com
        Base DN (Users) ....... DC=corp,DC=example,DC=com
        Base DN (Groups) ...... DC=corp,DC=example,DC=com
        Primary Server URL .... ldaps://dc01.corp.example.com:636
        Secondary Server URL .. ldaps://dc02.corp.example.com:636
        Username .............. svc_vcenter@corp.example.com
        Password .............. <svc_vcenter password>

     4. Click "Test Connection" before saving
     5. After adding, go to Global Permissions and assign:
        - vCenter_Admins -> Administrator role
        - vCenter_ReadOnly -> Read-Only role
        - vCenter_Power_Users -> your custom Power User role

"@ -ForegroundColor White

Read-Host "Press Enter to view NSX LDAPS integration steps"

# ============================================================
# Step 4: NSX Manager - LDAPS Identity Source
# ============================================================
Write-Host "`n=== Step 4: NSX Manager LDAPS ===" -ForegroundColor Cyan

Write-Host @"

  A. Import Root CA cert:
     1. Log into NSX Manager (https://<nsx-fqdn>) as admin
     2. Go to: System -> Certificates -> Import -> Import CA Certificate
     3. Paste the contents of Corp-Root-CA.pem

  B. Configure LDAPS Identity Source:
     1. Go to: System -> User Management -> LDAP
     2. Click "Add Identity Source"
     3. Configure:

        Name .................. corp.example.com
        Domain ................ corp.example.com
        Base DN ............... DC=corp,DC=example,DC=com
        Type .................. Active Directory over LDAPS

     4. Add LDAP Servers:
        Hostname .............. dc01.corp.example.com
        Port .................. 636
        Protocol .............. LDAPS
        Bind Identity ......... svc_nsx@corp.example.com
        Password .............. <svc_nsx password>
        Certificate ........... Select the imported CA cert

        (Add second server: dc02.corp.example.com:636)

     5. Click "Test Connection" for each server
     6. Under Role Assignments:
        - NSX_Admins -> Enterprise Admin
        - NSX_ReadOnly -> Auditor

"@ -ForegroundColor White

Read-Host "Press Enter to view Veeam LDAPS integration steps"

# ============================================================
# Step 5: Veeam Backup and Replication - LDAPS
# ============================================================
Write-Host "`n=== Step 5: Veeam B&R LDAPS ===" -ForegroundColor Cyan
Write-Host "Target: veeam01.corp.example.com (203.0.113.190)" -ForegroundColor White
Write-Host "Status: Workgroup (not domain-joined) - manual CA cert import required" -ForegroundColor Yellow

Write-Host @"

  Since veeam01 is NOT domain-joined, you need to manually
  import the Root CA cert so it trusts LDAPS connections to your DCs.

  Step A: Import Root CA certificate on Veeam server
  -----------------------------------------------
  1. Copy Corp-Root-CA.cer to veeam01
     (use SCP, shared folder, USB, etc. to get the file there)

  2. On veeam01, open PowerShell as Administrator and run:

     Import-Certificate -FilePath "C:\Certs\Corp-Root-CA.cer" `
         -CertStoreLocation Cert:\LocalMachine\Root

  3. Verify it imported:

     Get-ChildItem Cert:\LocalMachine\Root | Where-Object {
         $_.Subject -match "Corp"
     } | Select-Object Subject, NotAfter

  What this does: Adds your Enterprise CA to the Windows trusted root
  store on the Veeam server. After this, the server trusts any cert
  issued by Corp-Root-CA, including your DC LDAPS certificates.

  Step B: Add AD credentials to Veeam
  -----------------------------------------------
  Since the server is not domain-joined, Veeam needs explicit AD
  credentials to browse and authenticate against the domain.

  1. Open Veeam Backup and Replication Console on veeam01
  2. Click the hamburger menu (top-left) -> Manage Credentials
  3. Click "Add..." -> "Standard account"
  4. Enter: CORP\adm_jdoe (or svc_veeam@corp.example.com)
     with password - this lets Veeam browse AD for groups

  Step C: Add AD groups to Veeam roles
  -----------------------------------------------
  1. Click the hamburger menu -> Users and Roles
  2. Click "Add..."
  3. In the search box, type "CORP\" and browse for each group:

     CORP\Veeam_Admins ..... assign "Veeam Backup Administrator"
     CORP\Veeam_Operators .. assign "Veeam Backup Operator"
     CORP\Veeam_ReadOnly ... assign "Veeam Restore Operator" (read-only)

  4. Click OK to save

  What this does:
  - Veeam console login will accept AD credentials (domain\user format)
  - Members of Veeam_Admins can manage everything in the Veeam console
  - Members of Veeam_Operators can run/stop backup/restore jobs
  - Members of Veeam_ReadOnly can view job status and reports only

  Step D: Configure backup job credentials
  -----------------------------------------------
  When creating or editing backup jobs that need VM/host access:
  1. Go to: Manage Credentials (or add inline when creating a job)
  2. Add: svc_veeam@corp.example.com with its password
  3. Use this credential for guest processing, application-aware jobs, etc.

  The svc_veeam account needs:
  - Local admin rights on VMs for application-aware processing
  - vCenter permissions via Veeam_Service_Accounts group (already assigned)

"@ -ForegroundColor White

Write-Host @"

  =================================================================
  NOTE: Workgroup Veeam is Veeam's recommended hardened configuration
  =================================================================
  Your setup follows Veeam best practice. Benefits:
  - If AD is compromised (ransomware), attacker cannot pivot to backups
  - Backup credentials are stored locally in Veeam's encrypted database
  - Veeam v12 Hardened Repository features protect files from deletion
  - You still get full AD group-based access control via explicit creds
  =================================================================

"@ -ForegroundColor Yellow

Read-Host "Press Enter to continue to verification"

# ============================================================
# Step 6: Verification Commands
# ============================================================
Write-Host "`n=== Step 6: Verify LDAPS Connectivity ===" -ForegroundColor Cyan

Write-Host "`nLDAPS port check (DCs):" -ForegroundColor White
$ldaps1 = Test-NetConnection -ComputerName $DC1_IP -Port 636 -WarningAction SilentlyContinue
$ldaps2 = Test-NetConnection -ComputerName $DC2_IP -Port 636 -WarningAction SilentlyContinue
Write-Host "  $DC1 (636): $($ldaps1.TcpTestSucceeded)" -ForegroundColor $(if ($ldaps1.TcpTestSucceeded) { "Green" } else { "Red" })
Write-Host "  $DC2 (636): $($ldaps2.TcpTestSucceeded)" -ForegroundColor $(if ($ldaps2.TcpTestSucceeded) { "Green" } else { "Red" })

Write-Host "`nDC certificates:" -ForegroundColor White
Get-ChildItem Cert:\LocalMachine\My | Where-Object {
    $_.EnhancedKeyUsageList.FriendlyName -contains "Server Authentication"
} | Select-Object Subject, NotAfter, Thumbprint | Format-Table -AutoSize

Write-Host "`nVeeam server connectivity:" -ForegroundColor White
$veeamConn = Test-NetConnection -ComputerName "203.0.113.190" -Port 9392 -WarningAction SilentlyContinue
Write-Host "  veeam01 (9392 - Veeam API): $($veeamConn.TcpTestSucceeded)" -ForegroundColor $(if ($veeamConn.TcpTestSucceeded) { "Green" } else { "Yellow" })

Write-Host "`nNetApp connectivity:" -ForegroundColor White
$netappConn = Test-NetConnection -ComputerName "203.0.113.30" -Port 443 -WarningAction SilentlyContinue
Write-Host "  netapp01 (443 - ONTAP API): $($netappConn.TcpTestSucceeded)" -ForegroundColor $(if ($netappConn.TcpTestSucceeded) { "Green" } else { "Yellow" })

Write-Host "`nVeeam CA trust check:" -ForegroundColor White
Write-Host "  veeam01 is workgroup - verify CA cert imported manually:" -ForegroundColor White
Write-Host "  On the Veeam server, run:" -ForegroundColor White
Write-Host "    Get-ChildItem Cert:\LocalMachine\Root | Where-Object { `$_.Subject -match 'Corp' }" -ForegroundColor White

Write-Host "`n============================================" -ForegroundColor Green
Write-Host " LDAPS Integration Workflow - COMPLETE" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host @"

  Summary:
  ------------------------------------------------------------------
  Platform    Cert needed?    How LDAPS is used
  ----------  ------------   -------------------------------------------
  NetApp      Import PEM     ONTAP authenticates users via LDAPS to DCs
  vCenter     Import PEM     SSO identity source over LDAPS
  NSX         Import PEM     User management LDAP over LDAPS
  Veeam       Import CER     Workgroup server - manual trust required
  ------------------------------------------------------------------

  Files exported to $CertExportPath :
    Corp-Root-CA.pem ... NetApp ONTAP, vCenter, NSX
    Corp-Root-CA.cer ... Backup copy (DER format)

  Service accounts:
    vCenter .... svc_vcenter@corp.example.com
    NSX ........ svc_nsx@corp.example.com
    NetApp ..... svc_netapp@corp.example.com
    Veeam ...... svc_veeam@corp.example.com

"@ -ForegroundColor White
