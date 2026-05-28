-- ============================================================
-- Package: SUB_NEWSLETTER
-- Bulk newsletter dispatch:
--   - Queue a send (snapshot recipients, rewrite links, inject pixels)
--   - Process send queue (paced at OCI daily limit)
--   - Render newsletter HTML template
-- ============================================================
CREATE OR REPLACE PACKAGE sub_newsletter AS

    -- Daily send cap — leaves headroom for transactional emails
    -- OCI Always Free limit is 100/day total
    DAILY_SEND_CAP   CONSTANT PLS_INTEGER := 90;

    -- --------------------------------------------------------
    -- Queue a newsletter send.
    -- Snapshots ACTIVE subscribers into SEND_RECIPIENTS,
    -- registers all links in LINK_REGISTRY,
    -- moves send status from DRAFT to QUEUED.
    -- Called from admin UI when owner approves send.
    -- --------------------------------------------------------
    PROCEDURE queue_send (
        p_send_id IN NUMBER
    );

    -- --------------------------------------------------------
    -- Process the send queue.
    -- Called by DBMS_SCHEDULER every 15 minutes.
    -- Dispatches up to remaining daily allowance.
    -- --------------------------------------------------------
    PROCEDURE process_queue;

    -- --------------------------------------------------------
    -- Render newsletter HTML for a given send.
    -- Rewrites links through tracker/click endpoint.
    -- Injects open tracking pixel.
    -- Called per-recipient during process_queue.
    -- --------------------------------------------------------
    FUNCTION render_newsletter (
        p_send_id      IN NUMBER,
        p_recipient_id IN NUMBER
    ) RETURN CLOB;

    -- --------------------------------------------------------
    -- Returns count of emails sent today (all types).
    -- Used to enforce daily cap.
    -- --------------------------------------------------------
    FUNCTION emails_sent_today RETURN NUMBER;

END sub_newsletter;
/
