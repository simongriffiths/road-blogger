-- ============================================================
-- Table: LINK_REGISTRY
-- Registry of original URLs rewritten for click tracking.
-- One row per unique URL per send.
-- The ORDS click redirect endpoint resolves lid → original_url,
-- logs the event, then issues HTTP 302.
-- ============================================================
CREATE TABLE link_registry (
    link_id               NUMBER          DEFAULT seq_link_registry.NEXTVAL
                                          CONSTRAINT pk_link_registry PRIMARY KEY,

    send_id               NUMBER          NOT NULL
                                          CONSTRAINT fk_lr_send
                                          REFERENCES newsletter_sends(send_id),

    -- Short token embedded in the rewritten URL
    link_token            VARCHAR2(32)    NOT NULL,

    original_url          VARCHAR2(4000)  NOT NULL,
    link_label            VARCHAR2(200),  -- human-readable label for analytics display

    created_ts            TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,

    CONSTRAINT uq_lr_send_token UNIQUE (send_id, link_token)
);

COMMENT ON TABLE  link_registry             IS 'Registry of tracked links per send. Original URLs resolved here at click time.';
COMMENT ON COLUMN link_registry.link_token  IS 'Short random token used in the rewritten click-tracking URL.';
COMMENT ON COLUMN link_registry.link_label  IS 'Optional descriptive label shown in analytics (e.g. "Read more: Post Title").';
