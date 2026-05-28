-- ============================================================
-- Table: NEWSLETTER_SENDS
-- One row per newsletter send job.
-- Content snapshot is stored at dispatch time — immutable
-- after dispatch begins, preserving send history accurately.
-- ============================================================
CREATE TABLE newsletter_sends (
    send_id               NUMBER          DEFAULT seq_newsletter_sends.NEXTVAL
                                          CONSTRAINT pk_newsletter_sends PRIMARY KEY,

    subject               VARCHAR2(500)   NOT NULL,
    body_text             CLOB            NOT NULL,   -- plain text version
    body_html             CLOB,                       -- optional HTML version (post-MVP)

    status                VARCHAR2(20)    DEFAULT 'DRAFT'
                                          NOT NULL
                                          CONSTRAINT chk_send_status
                                          CHECK (status IN ('DRAFT','QUEUED',
                                                            'IN_PROGRESS','COMPLETE',
                                                            'FAILED','CANCELLED')),

    -- Recipient snapshot counts (populated when QUEUED)
    total_recipients      NUMBER          DEFAULT 0,
    sent_count            NUMBER          DEFAULT 0,
    failed_count          NUMBER          DEFAULT 0,

    -- Timestamps
    created_ts            TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    queued_ts             TIMESTAMP,
    started_ts            TIMESTAMP,
    completed_ts          TIMESTAMP,

    -- Admin metadata
    created_by            VARCHAR2(100)   DEFAULT USER NOT NULL,
    notes                 VARCHAR2(1000)
);

COMMENT ON TABLE  newsletter_sends             IS 'Newsletter send jobs. One row per send. Content snapshotted at queue time.';
COMMENT ON COLUMN newsletter_sends.status      IS 'DRAFT=being composed; QUEUED=approved for send; IN_PROGRESS=scheduler processing; COMPLETE=all sent; FAILED=error; CANCELLED=aborted.';
COMMENT ON COLUMN newsletter_sends.body_text   IS 'Plain text email body. Stored as CLOB. Immutable once status moves past QUEUED.';
COMMENT ON COLUMN newsletter_sends.total_recipients IS 'Count of ACTIVE subscribers at time of queuing. Snapshot, not a live count.';
