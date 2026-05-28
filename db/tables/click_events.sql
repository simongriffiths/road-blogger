-- ============================================================
-- Table: CLICK_EVENTS
-- Recorded when a tracked link is clicked.
-- More reliable than open events — requires deliberate
-- human action. Primary engagement metric.
-- ============================================================
CREATE TABLE click_events (
    click_id              NUMBER          DEFAULT seq_click_events.NEXTVAL
                                          CONSTRAINT pk_click_events PRIMARY KEY,

    recipient_id          NUMBER          NOT NULL
                                          CONSTRAINT fk_ce_recipient
                                          REFERENCES send_recipients(recipient_id),

    link_id               NUMBER          NOT NULL
                                          CONSTRAINT fk_ce_link
                                          REFERENCES link_registry(link_id),

    -- Denormalised for query convenience
    send_id               NUMBER          NOT NULL,
    subscriber_id         NUMBER,

    clicked_ts            TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    user_agent            VARCHAR2(1000),
    ip_address            VARCHAR2(45)
);

COMMENT ON TABLE click_events IS 'Link click events. Requires deliberate human action — primary engagement metric.';
