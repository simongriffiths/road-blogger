-- ============================================================
-- Package: SUB_GDPR
-- GDPR compliance functions:
--   - Right to erasure (Article 17)
--   - Consent audit record (Article 7)
--   - Data export for portability (Article 20)
-- ============================================================
CREATE OR REPLACE PACKAGE sub_gdpr AS

    -- --------------------------------------------------------
    -- ERASE_SUBSCRIBER
    -- Handles a right-to-erasure request for a given email.
    --
    -- Actions taken:
    --   1. Locates subscriber record by email
    --   2. Removes all personal data from SUBSCRIBERS row
    --   3. Retains email hash on SUPPRESSION_LIST to prevent
    --      re-subscription (no PII retained — hash only)
    --   4. Nulls subscriber_id FK on SEND_RECIPIENTS
    --      (send history retained for analytics integrity,
    --       personal data removed)
    --   5. Deletes subscriber row
    --
    -- p_status OUT:
    --   'ok'          — erasure completed
    --   'not_found'   — no record for this email
    --   'error'       — unexpected error
    -- --------------------------------------------------------
    PROCEDURE erase_subscriber (
        p_email   IN  VARCHAR2,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    );

    -- --------------------------------------------------------
    -- GET_CONSENT_RECORD
    -- Returns the GDPR consent audit record for a subscriber.
    -- Used to demonstrate proof of consent if challenged.
    -- Output is a JSON object.
    -- --------------------------------------------------------
    FUNCTION get_consent_record (
        p_email IN VARCHAR2
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- EXPORT_SUBSCRIBER_DATA
    -- Returns all personal data held for a subscriber
    -- as a JSON object — for data portability requests.
    -- --------------------------------------------------------
    FUNCTION export_subscriber_data (
        p_email IN VARCHAR2
    ) RETURN CLOB;

END sub_gdpr;
/


