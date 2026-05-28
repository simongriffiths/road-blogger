-- ============================================================
-- OCI Email Delivery Pre-requisites
-- Run ONCE as ADMIN user before any email can be sent.
--
-- Steps covered:
--   1. Network ACL — allow schema user to connect to OCI SMTP
--   2. Credential object — SMTP username/password from OCI console
--
-- OCI Console pre-requisites (manual, outside this script):
--   a. OCI Email Delivery service enabled in tenancy home region
--   b. Approved sender address configured
--      e.g. newsletter@yourdomain.com
--   c. SPF and DKIM DNS records added to sending domain
--   d. SMTP credentials generated for an OCI IAM user:
--      OCI Console → Identity → Users → [user] → SMTP Credentials
--      Note the username (looks like: ocid1.user.oc1...) and password
--   e. OCI SMTP endpoint for your region, e.g.:
--      smtp.email.eu-frankfurt-1.oci.oraclecloud.com  (Frankfurt)
--      smtp.email.uk-london-1.oci.oraclecloud.com     (London)
--      smtp.email.us-ashburn-1.oci.oraclecloud.com    (Ashburn)
--      Port: 587 (STARTTLS)
-- ============================================================

-- ============================================================
-- Step 1: Network ACL
-- Grant schema user access to OCI SMTP host on port 587.
-- Replace :schema_user with your ADB schema name.
-- Replace :smtp_host with your region's SMTP endpoint.
-- ============================================================
BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host       => '&smtp_host',   -- e.g. smtp.email.uk-london-1.oci.oraclecloud.com
        lower_port => 587,
        upper_port => 587,
        ace        => xs$ace_type(
                          privilege_list => xs$name_list('connect', 'resolve'),
                          principal_name => '&schema_user',
                          principal_type => xs_acl.ptype_db
                      )
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('ACL granted to &schema_user for &smtp_host:587');
END;
/

-- ============================================================
-- Step 2: Credential Object
-- Store OCI SMTP credentials securely in the database.
-- Replace values with your actual OCI SMTP credentials.
-- credential_name 'OCI_SMTP' is referenced in sub_email package.
-- ============================================================
BEGIN
    DBMS_CREDENTIAL.CREATE_CREDENTIAL(
        credential_name => 'OCI_SMTP',
        username        => '&smtp_username',   -- OCI SMTP username (ocid1.user...)
        password        => '&smtp_password'    -- OCI SMTP password (generated secret)
    );
    DBMS_OUTPUT.PUT_LINE('Credential OCI_SMTP created.');
END;
/

-- ============================================================
-- Verify ACL (run as ADMIN to confirm)
-- ============================================================
SELECT host, lower_port, upper_port
FROM   dba_network_acl_privileges
WHERE  principal = UPPER('&schema_user');
