-- ============================================================
-- Table: SUBSCRIBERS
-- Core subscriber records.
-- status lifecycle: PENDING → ACTIVE → UNSUBSCRIBED | BOUNCED
-- ============================================================
CREATE TABLE subscribers (
    subscriber_id         NUMBER          DEFAULT seq_subscribers.NEXTVAL
                                          CONSTRAINT pk_subscribers PRIMARY KEY,

    -- Identity
    email                 VARCHAR2(320)   NOT NULL,   -- RFC 5321 max
    first_name            VARCHAR2(100),

    -- Lifecycle status
    -- PENDING       : confirmed opt-in email sent, awaiting click
    -- ACTIVE        : confirmed, eligible for sends
    -- UNSUBSCRIBED  : opted out, on suppression list
    -- BOUNCED       : hard bounce received, on suppression list
    status                VARCHAR2(20)    DEFAULT 'PENDING'
                                          NOT NULL
                                          CONSTRAINT chk_sub_status
                                          CHECK (status IN ('PENDING','ACTIVE',
                                                            'UNSUBSCRIBED','BOUNCED')),

    -- Opt-in tokens
    confirm_token         VARCHAR2(64)    NOT NULL,   -- UUID, used once
    unsubscribe_token     VARCHAR2(64)    NOT NULL,   -- UUID, stable per subscriber

    -- Consent audit trail (GDPR Article 7)
    signup_ts             TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    signup_ip             VARCHAR2(45)    NOT NULL,   -- IPv4 or IPv6
    signup_source_url     VARCHAR2(2000),             -- page where form was submitted
    consent_given         CHAR(1)         DEFAULT 'Y'
                                          NOT NULL
                                          CONSTRAINT chk_consent
                                          CHECK (consent_given = 'Y'),

    -- Confirmation audit
    confirm_ts            TIMESTAMP,
    confirm_ip            VARCHAR2(45),

    -- Unsubscribe / bounce audit
    unsubscribed_ts       TIMESTAMP,
    bounce_ts             TIMESTAMP,
    bounce_type           VARCHAR2(10)    CONSTRAINT chk_bounce_type
                                          CHECK (bounce_type IN ('HARD','SOFT')),

    -- Housekeeping
    created_ts            TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_ts            TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE  subscribers                IS 'Core subscriber records. One row per email address in the active pipeline.';
COMMENT ON COLUMN subscribers.subscriber_id  IS 'Surrogate PK.';
COMMENT ON COLUMN subscribers.email          IS 'Subscriber email address. Stored as entered; uniqueness enforced case-insensitively.';
COMMENT ON COLUMN subscribers.status         IS 'Lifecycle status: PENDING / ACTIVE / UNSUBSCRIBED / BOUNCED.';
COMMENT ON COLUMN subscribers.confirm_token  IS 'Single-use UUID token embedded in the double opt-in confirmation email link.';
COMMENT ON COLUMN subscribers.unsubscribe_token IS 'Stable UUID token embedded in every outbound email unsubscribe link. Rotated on resubscription.';
COMMENT ON COLUMN subscribers.signup_ip      IS 'IP address at time of subscription form submission. Part of GDPR consent record.';
COMMENT ON COLUMN subscribers.signup_source_url IS 'URL of the page where the subscription form was submitted.';
COMMENT ON COLUMN subscribers.consent_given  IS 'Y = subscriber checked the consent checkbox. Constrained to Y only — no record created without consent.';
