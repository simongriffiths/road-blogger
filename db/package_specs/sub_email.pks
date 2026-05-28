-- ============================================================
-- Package: SUB_EMAIL
-- Transactional email only:
--   - Double opt-in confirmation
--   - Unsubscribe acknowledgement
--
-- Bulk newsletter dispatch is in SUB_NEWSLETTER.
-- All email sent via OCI Email Delivery / UTL_SMTP.
-- ============================================================
CREATE OR REPLACE PACKAGE sub_email AS

    -- --------------------------------------------------------
    -- Configuration constants
    -- Override at install time via package body constants.
    -- --------------------------------------------------------
    -- SMTP endpoint for your OCI region (port 587, STARTTLS)
    -- London:    smtp.email.uk-london-1.oci.oraclecloud.com
    -- Frankfurt: smtp.email.eu-frankfurt-1.oci.oraclecloud.com
    SMTP_HOST     CONSTANT VARCHAR2(200) := 'smtp.email.uk-london-1.oci.oraclecloud.com';
    SMTP_PORT     CONSTANT PLS_INTEGER   := 587;
    SMTP_CRED     CONSTANT VARCHAR2(100) := 'OCI_SMTP';   -- credential object name

    -- Sender identity — must match OCI approved sender
    FROM_ADDRESS  CONSTANT VARCHAR2(320) := 'newsletter@yourdomain.com';
    FROM_NAME     CONSTANT VARCHAR2(200) := 'Simon Griffiths';

    -- Blog base URL — used to construct links in emails
    BLOG_BASE_URL CONSTANT VARCHAR2(200) := 'https://yourdomain.com';

    -- --------------------------------------------------------
    -- Send confirmation email to a new PENDING subscriber.
    -- Called from sub_api.subscribe after INSERT.
    -- --------------------------------------------------------
    PROCEDURE send_confirmation (
        p_subscriber_id IN NUMBER
    );

    -- --------------------------------------------------------
    -- Send unsubscribe acknowledgement.
    -- Called from sub_api.unsubscribe after status update.
    -- Optional — can be disabled if too noisy.
    -- --------------------------------------------------------
    PROCEDURE send_unsubscribe_ack (
        p_subscriber_id IN NUMBER
    );

    -- --------------------------------------------------------
    -- Low-level send — used internally and by sub_newsletter.
    -- p_to_address  : recipient email
    -- p_to_name     : recipient name (for To: header)
    -- p_subject     : email subject line
    -- p_body_html   : HTML body
    -- p_body_text   : plain text fallback (auto-generated if NULL)
    -- Returns TRUE on success, FALSE on failure.
    -- --------------------------------------------------------
    FUNCTION send_email (
        p_to_address  IN VARCHAR2,
        p_to_name     IN VARCHAR2,
        p_subject     IN VARCHAR2,
        p_body_html   IN CLOB,
        p_body_text   IN CLOB DEFAULT NULL
    ) RETURN BOOLEAN;

    -- --------------------------------------------------------
    -- Shared branded email shell renderer.
    -- Exposed for SUB_NEWSLETTER, which renders bulk-send
    -- content before delegating transport to SEND_EMAIL.
    -- --------------------------------------------------------
    FUNCTION render_email_wrapper (
        p_content     IN CLOB,
        p_preheader   IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB;

END sub_email;
/
