-- ============================================================
-- Table: SEND_RECIPIENTS
-- One row per subscriber per send.
-- Holds per-recipient delivery status and unique tokens
-- for open tracking pixel and unsubscribe link.
-- ============================================================
CREATE TABLE send_recipients (
    recipient_id          NUMBER          DEFAULT seq_send_recipients.NEXTVAL
                                          CONSTRAINT pk_send_recipients PRIMARY KEY,

    send_id               NUMBER          NOT NULL
                                          CONSTRAINT fk_sr_send
                                          REFERENCES newsletter_sends(send_id),

    subscriber_id         NUMBER
                                          CONSTRAINT fk_sr_subscriber
                                          REFERENCES subscribers(subscriber_id),

    -- Delivery status
    status                VARCHAR2(20)    DEFAULT 'PENDING'
                                          NOT NULL
                                          CONSTRAINT chk_sr_status
                                          CHECK (status IN ('PENDING','SENT',
                                                            'FAILED','SUPPRESSED')),

    -- Unique per-recipient tokens embedded in this send's email
    -- open_token   : in the tracking pixel URL
    -- unsub_token  : in this email's unsubscribe link
    --   (separate from subscriber.unsubscribe_token —
    --    allows per-send unsubscribe attribution)
    open_token            VARCHAR2(64)    NOT NULL,
    unsub_token           VARCHAR2(64)    NOT NULL,

    -- Delivery timestamps
    sent_ts               TIMESTAMP,
    failed_ts             TIMESTAMP,
    failure_reason        VARCHAR2(500),

    CONSTRAINT uq_sr_send_subscriber UNIQUE (send_id, subscriber_id)
);

COMMENT ON TABLE  send_recipients              IS 'Per-recipient dispatch record for each newsletter send.';
COMMENT ON COLUMN send_recipients.open_token   IS 'Unique token for the tracking pixel URL in this specific email. One-use.';
COMMENT ON COLUMN send_recipients.unsub_token  IS 'Unique unsubscribe token for this specific email. Enables per-send unsubscribe attribution.';
COMMENT ON COLUMN send_recipients.status       IS 'PENDING=queued; SENT=dispatched; FAILED=error; SUPPRESSED=on suppression list at dispatch time.';
