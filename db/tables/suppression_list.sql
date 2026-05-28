-- ============================================================
-- Table: SUPPRESSION_LIST
-- Permanent record of email addresses that must never be mailed.
-- Populated by: unsubscribe, hard bounce, erasure request.
--
-- On erasure (GDPR Art.17): personal data is removed from
-- SUBSCRIBERS but the email hash is retained here to prevent
-- accidental re-subscription. The raw email is retained only
-- where operationally necessary (bounce processing).
-- ============================================================
CREATE TABLE suppression_list (
    suppression_id        NUMBER          DEFAULT seq_subscribers.NEXTVAL
                                          CONSTRAINT pk_suppression PRIMARY KEY,

    -- Email stored in normalised lowercase for reliable matching
    email                 VARCHAR2(320)   NOT NULL,
    email_hash            VARCHAR2(64)    NOT NULL,   -- SHA-256 hex, for erasure-safe matching

    reason                VARCHAR2(20)    NOT NULL
                                          CONSTRAINT chk_supp_reason
                                          CHECK (reason IN ('UNSUBSCRIBED',
                                                            'HARD_BOUNCE',
                                                            'ERASURE_REQUEST',
                                                            'ADMIN')),

    -- Original subscriber FK — nullable, cleared on erasure
    subscriber_id         NUMBER          CONSTRAINT fk_supp_subscriber
                                          REFERENCES subscribers(subscriber_id)
                                          ON DELETE SET NULL,

    suppressed_ts         TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    notes                 VARCHAR2(500)   -- optional admin note
);

COMMENT ON TABLE  suppression_list            IS 'Permanent suppression list. Emails here are excluded from all future sends.';
COMMENT ON COLUMN suppression_list.email_hash IS 'SHA-256 of lowercased email. Retained after erasure to prevent re-subscription without storing PII.';
COMMENT ON COLUMN suppression_list.reason     IS 'UNSUBSCRIBED / HARD_BOUNCE / ERASURE_REQUEST / ADMIN.';
