-- ============================================================
-- Package Body: SUB_NEWSLETTER
-- ============================================================
CREATE OR REPLACE PACKAGE BODY sub_newsletter AS

    -- Base URL for tracker endpoints — relative within same origin
    -- Full URL needed in emails (relative URLs don't work in email clients)
    TRACKER_BASE CONSTANT VARCHAR2(200) := sub_email.BLOG_BASE_URL || '/ords/blog/tracker';

    -- --------------------------------------------------------
    -- EMAILS_SENT_TODAY
    -- Count of SENT records across all sends today.
    -- Includes transactional emails via a sentinel send_id=-1
    -- convention — for MVP, approximate count is sufficient.
    -- --------------------------------------------------------
    FUNCTION emails_sent_today RETURN NUMBER IS
        l_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO   l_count
        FROM   send_recipients
        WHERE  status  = 'SENT'
        AND    sent_ts >= TRUNC(SYSTIMESTAMP AT TIME ZONE 'UTC');
        RETURN NVL(l_count, 0);
    END emails_sent_today;

    -- --------------------------------------------------------
    -- REGISTER_LINKS
    -- Scans newsletter body_text for URLs, registers each
    -- unique URL in LINK_REGISTRY with a short token.
    -- Returns count of links registered.
    -- --------------------------------------------------------
    FUNCTION register_links (
        p_send_id  IN NUMBER,
        p_body     IN CLOB
    ) RETURN NUMBER IS
        l_pattern  VARCHAR2(200) := 'https?://[^ \t\r\n<>"]+';
        l_pos      PLS_INTEGER   := 1;
        l_match    VARCHAR2(4000);
        l_token    VARCHAR2(32);
        l_count    NUMBER        := 0;
    BEGIN
        LOOP
            l_match := REGEXP_SUBSTR(p_body, l_pattern, l_pos);
            EXIT WHEN l_match IS NULL;

            -- Deduplicate within this send
            DECLARE
                l_exists NUMBER;
            BEGIN
                SELECT COUNT(*) INTO l_exists
                FROM   link_registry
                WHERE  send_id     = p_send_id
                AND    original_url = l_match;

                IF l_exists = 0 THEN
                    l_token := LOWER(SUBSTR(RAWTOHEX(SYS_GUID()), 1, 16));
                    INSERT INTO link_registry (send_id, link_token, original_url)
                    VALUES (p_send_id, l_token, l_match);
                    l_count := l_count + 1;
                END IF;
            END;

            l_pos := REGEXP_INSTR(p_body, l_pattern, l_pos) + LENGTH(l_match);
        END LOOP;

        RETURN l_count;
    END register_links;

    -- --------------------------------------------------------
    -- QUEUE_SEND
    -- Validates send, snapshots recipients, registers links.
    -- --------------------------------------------------------
    PROCEDURE queue_send (
        p_send_id IN NUMBER
    ) IS
        l_status        VARCHAR2(20);
        l_body          CLOB;
        l_recipient_count NUMBER := 0;
    BEGIN
        -- Validate send exists and is in DRAFT
        SELECT status, body_text
        INTO   l_status, l_body
        FROM   newsletter_sends
        WHERE  send_id = p_send_id
        FOR UPDATE;

        IF l_status != 'DRAFT' THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Cannot queue send_id=' || p_send_id
                || ': status is ' || l_status || ', expected DRAFT.');
        END IF;

        -- Snapshot active subscribers into SEND_RECIPIENTS
        INSERT INTO send_recipients (
            send_id,
            subscriber_id,
            status,
            open_token,
            unsub_token
        )
        SELECT p_send_id,
               subscriber_id,
               'PENDING',
               LOWER(RAWTOHEX(SYS_GUID()) || RAWTOHEX(SYS_GUID())),  -- open token
               LOWER(RAWTOHEX(SYS_GUID()) || RAWTOHEX(SYS_GUID()))   -- unsub token
        FROM   v_active_subscribers;

        l_recipient_count := SQL%ROWCOUNT;

        -- Register links for click tracking
        DECLARE
            l_link_count NUMBER;
        BEGIN
            l_link_count := register_links(p_send_id, l_body);
        END;

        -- Update send record
        UPDATE newsletter_sends
        SET    status           = 'QUEUED',
               total_recipients = l_recipient_count,
               queued_ts        = SYSTIMESTAMP
        WHERE  send_id          = p_send_id;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END queue_send;

    -- --------------------------------------------------------
    -- RENDER_NEWSLETTER
    -- Builds the HTML for one recipient:
    --   - Rewrites tracked URLs through /tracker/click
    --   - Injects open pixel
    --   - Injects per-recipient unsubscribe link
    -- --------------------------------------------------------
    FUNCTION render_newsletter (
        p_send_id      IN NUMBER,
        p_recipient_id IN NUMBER
    ) RETURN CLOB IS

        l_body_text     CLOB;
        l_subject       VARCHAR2(500);
        l_open_token    VARCHAR2(64);
        l_unsub_token   VARCHAR2(64);
        l_sub_email     VARCHAR2(320);
        l_sub_name      VARCHAR2(100);
        l_pixel_url     VARCHAR2(500);
        l_unsub_url     VARCHAR2(500);
        l_content       CLOB;
        l_html          CLOB;

        -- Replace plain URLs with tracked redirect URLs
        FUNCTION rewrite_links (p_text IN CLOB, p_send_id IN NUMBER) RETURN CLOB IS
            l_result  CLOB := p_text;
            l_pattern VARCHAR2(200) := 'https?://[^ \t\r\n<>"]+';
            l_match   VARCHAR2(4000);
            l_token   VARCHAR2(32);
            l_tracked VARCHAR2(500);
            l_pos     PLS_INTEGER := 1;
        BEGIN
            LOOP
                l_match := REGEXP_SUBSTR(l_result, l_pattern, l_pos);
                EXIT WHEN l_match IS NULL;

                -- Don't rewrite tracker URLs (would create infinite loops)
                IF l_match NOT LIKE '%/tracker/%' THEN
                    BEGIN
                        SELECT link_token INTO l_token
                        FROM   link_registry
                        WHERE  send_id     = p_send_id
                        AND    original_url = l_match;

                        l_tracked := TRACKER_BASE
                                  || '/click?s=' || p_send_id
                                  || '&l=' || l_token;

                        l_result := REPLACE(l_result, l_match, l_tracked);
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN NULL;
                    END;
                END IF;

                l_pos := REGEXP_INSTR(l_result, l_pattern, l_pos) + LENGTH(l_match);
            END LOOP;
            RETURN l_result;
        END rewrite_links;

    BEGIN
        -- Fetch send content
        SELECT subject, body_text
        INTO   l_subject, l_body_text
        FROM   newsletter_sends
        WHERE  send_id = p_send_id;

        -- Fetch recipient tokens and subscriber details
        SELECT sr.open_token, sr.unsub_token,
               s.email, s.first_name
        INTO   l_open_token, l_unsub_token,
               l_sub_email, l_sub_name
        FROM   send_recipients sr
        JOIN   subscribers     s ON s.subscriber_id = sr.subscriber_id
        WHERE  sr.recipient_id = p_recipient_id;

        -- Build URLs
        l_pixel_url := TRACKER_BASE || '/pixel?t=' || l_open_token;
        l_unsub_url := sub_email.BLOG_BASE_URL
                    || '/ords/blog/subscriber/unsubscribe?token='
                    || l_unsub_token;

        -- Rewrite links in body
        l_body_text := rewrite_links(l_body_text, p_send_id);

        -- Convert plain text body to basic HTML paragraphs
        -- Split on double newlines to create paragraphs
        DECLARE
            l_para VARCHAR2(32767);
        BEGIN
            l_content := '';
            FOR i IN (
                SELECT TRIM(column_value) AS para
                FROM   TABLE(
                    CAST(
                        MULTISET(
                            SELECT REGEXP_SUBSTR(l_body_text,
                                                 '[^' || CHR(10) || CHR(10) || ']+',
                                                 1, LEVEL)
                            FROM   DUAL
                            CONNECT BY REGEXP_SUBSTR(l_body_text,
                                                     '[^' || CHR(10) || CHR(10) || ']+',
                                                     1, LEVEL) IS NOT NULL
                        ) AS SYS.ODCIVARCHAR2LIST
                    )
                )
                WHERE TRIM(column_value) IS NOT NULL
            ) LOOP
                l_content := l_content
                    || '<p style="margin:0 0 16px;font-size:16px;'
                    || 'line-height:1.7;color:#222222;">'
                    || i.para
                    || '</p>' || CHR(10);
            END LOOP;
        END;

        -- Append unsubscribe footer
        l_content := l_content ||
'<div style="margin-top:32px;padding-top:16px;border-top:1px solid #d8d2c7;">
  <p style="margin:0;font-size:12px;line-height:1.6;color:#8a847a;">
    <a href="' || l_unsub_url || '"
       style="color:#8a847a;text-decoration:underline;">Unsubscribe</a>
    &nbsp;&middot;&nbsp;
    <a href="' || sub_email.BLOG_BASE_URL || '"
       style="color:#8a847a;text-decoration:underline;">'
    || sub_email.BLOG_BASE_URL || '</a>
  </p>
</div>

<!-- Open tracking pixel -->
<img src="' || l_pixel_url || '"
     width="1" height="1" border="0"
     style="display:block;width:1px;height:1px;"
     alt="">';

        -- Wrap in branded shell
        l_html := sub_email.render_email_wrapper(
            p_content   => l_content,
            p_preheader => l_subject
        );

        RETURN l_html;

    EXCEPTION
        WHEN OTHERS THEN RETURN NULL;
    END render_newsletter;

    -- --------------------------------------------------------
    -- PROCESS_QUEUE
    -- Called by scheduler every 15 minutes.
    -- Dispatches pending recipients up to daily cap.
    -- --------------------------------------------------------
    PROCEDURE process_queue IS
        l_sent_today    NUMBER;
        l_remaining     NUMBER;
        l_dispatched    NUMBER := 0;
        l_html          CLOB;
        l_ok            BOOLEAN;

        CURSOR c_pending IS
            SELECT sr.recipient_id,
                   sr.send_id,
                   sr.subscriber_id,
                   s.email,
                   s.first_name,
                   ns.subject
            FROM   send_recipients  sr
            JOIN   subscribers      s  ON s.subscriber_id  = sr.subscriber_id
            JOIN   newsletter_sends ns ON ns.send_id        = sr.send_id
            WHERE  sr.status  = 'PENDING'
            AND    ns.status  IN ('QUEUED', 'IN_PROGRESS')
            ORDER BY ns.queued_ts, sr.recipient_id   -- oldest send first
            FOR UPDATE OF sr.status SKIP LOCKED;

    BEGIN
        l_sent_today := emails_sent_today();
        l_remaining  := DAILY_SEND_CAP - l_sent_today;

        IF l_remaining <= 0 THEN
            RETURN;  -- Daily cap reached — scheduler will retry tomorrow
        END IF;

        FOR r IN c_pending LOOP
            EXIT WHEN l_dispatched >= l_remaining;

            -- Mark send IN_PROGRESS on first recipient
            UPDATE newsletter_sends
            SET    status     = 'IN_PROGRESS',
                   started_ts = CASE WHEN started_ts IS NULL THEN SYSTIMESTAMP ELSE started_ts END
            WHERE  send_id    = r.send_id
            AND    status     = 'QUEUED';

            -- Check subscriber still active (not unsubscribed since queue time)
            DECLARE
                l_status VARCHAR2(20);
            BEGIN
                SELECT status INTO l_status
                FROM   subscribers
                WHERE  subscriber_id = r.subscriber_id;

                IF l_status != 'ACTIVE' THEN
                    UPDATE send_recipients
                    SET    status = 'SUPPRESSED'
                    WHERE  recipient_id = r.recipient_id;
                    COMMIT;
                    CONTINUE;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    UPDATE send_recipients
                    SET    status = 'SUPPRESSED'
                    WHERE  recipient_id = r.recipient_id;
                    COMMIT;
                    CONTINUE;
            END;

            -- Render personalised HTML
            l_html := render_newsletter(r.send_id, r.recipient_id);

            IF l_html IS NULL THEN
                UPDATE send_recipients
                SET    status         = 'FAILED',
                       failed_ts      = SYSTIMESTAMP,
                       failure_reason = 'render_newsletter returned NULL'
                WHERE  recipient_id   = r.recipient_id;
                COMMIT;
                CONTINUE;
            END IF;

            -- Send
            l_ok := sub_email.send_email(
                p_to_address => r.email,
                p_to_name    => r.first_name,
                p_subject    => r.subject,
                p_body_html  => l_html
            );

            IF l_ok THEN
                UPDATE send_recipients
                SET    status  = 'SENT',
                       sent_ts = SYSTIMESTAMP
                WHERE  recipient_id = r.recipient_id;

                -- Update sent count on parent send
                UPDATE newsletter_sends
                SET    sent_count = sent_count + 1
                WHERE  send_id    = r.send_id;

                l_dispatched := l_dispatched + 1;
            ELSE
                UPDATE send_recipients
                SET    status         = 'FAILED',
                       failed_ts      = SYSTIMESTAMP,
                       failure_reason = 'UTL_SMTP send failed'
                WHERE  recipient_id   = r.recipient_id;

                UPDATE newsletter_sends
                SET    failed_count = failed_count + 1
                WHERE  send_id      = r.send_id;
            END IF;

            COMMIT;
        END LOOP;

        -- Mark any fully-dispatched sends as COMPLETE
        UPDATE newsletter_sends ns
        SET    status       = 'COMPLETE',
               completed_ts = SYSTIMESTAMP
        WHERE  status       = 'IN_PROGRESS'
        AND    NOT EXISTS (
            SELECT 1 FROM send_recipients sr
            WHERE  sr.send_id = ns.send_id
            AND    sr.status  = 'PENDING'
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            -- Log but don't raise — scheduler job must not error repeatedly
            DBMS_OUTPUT.PUT_LINE('sub_newsletter.process_queue error: ' || SQLERRM);
    END process_queue;

END sub_newsletter;
/
