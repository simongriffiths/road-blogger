-- ============================================================
-- Table: RATE_LIMIT_LOG
-- Tracks subscription attempts per IP for spam protection.
-- Nightly scheduler job purges records older than 24 hours.
-- ============================================================
CREATE TABLE rate_limit_log (
    log_id                NUMBER          DEFAULT seq_rate_limit_log.NEXTVAL
                                          CONSTRAINT pk_rate_limit PRIMARY KEY,
    ip_address            VARCHAR2(45)    NOT NULL,
    attempt_ts            TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE rate_limit_log IS 'Subscribe attempt log for IP-based rate limiting. Max 3 attempts per IP per hour. Purged nightly.';
