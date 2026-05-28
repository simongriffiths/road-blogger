-- ============================================================
-- Table: OPEN_EVENTS
-- Recorded when the tracking pixel is loaded.
-- NOTE: unreliable due to Apple MPP and proxy pre-fetching.
-- Treat as directional only. Click events are authoritative.
-- ============================================================
CREATE TABLE open_events (
    open_id               NUMBER          DEFAULT seq_open_events.NEXTVAL
                                          CONSTRAINT pk_open_events PRIMARY KEY,

    recipient_id          NUMBER          NOT NULL
                                          CONSTRAINT fk_oe_recipient
                                          REFERENCES send_recipients(recipient_id),

    -- Denormalised for query convenience
    send_id               NUMBER          NOT NULL,
    subscriber_id         NUMBER,

    opened_ts             TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    user_agent            VARCHAR2(1000),
    ip_address            VARCHAR2(45)
);

COMMENT ON TABLE open_events IS 'Pixel-based open events. Unreliable due to privacy proxies — directional metric only.';
