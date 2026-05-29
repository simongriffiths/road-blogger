-- ============================================================
-- Package Body: SUB_API
-- ============================================================
CREATE OR REPLACE PACKAGE BODY sub_api AS

    -- --------------------------------------------------------
    -- GENERATE_TOKEN
    -- Returns a 64-char hex UUID using SYS_GUID()
    -- --------------------------------------------------------
    FUNCTION generate_token RETURN VARCHAR2 IS
    BEGIN
        RETURN LOWER(RAWTOHEX(SYS_GUID()) || RAWTOHEX(SYS_GUID()));
    END generate_token;

    -- --------------------------------------------------------
    -- IS_VALID_EMAIL
    -- Basic structural validation — not exhaustive.
    -- --------------------------------------------------------
    FUNCTION is_valid_email (p_email IN VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        RETURN REGEXP_LIKE(
            p_email,
            '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'
        );
    END is_valid_email;

    -- --------------------------------------------------------
    -- IS_SUPPRESSED
    -- Check suppression list before any subscribe attempt.
    -- --------------------------------------------------------
    FUNCTION is_suppressed (p_email IN VARCHAR2) RETURN BOOLEAN IS
        l_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO   l_count
        FROM   suppression_list
        WHERE  LOWER(email) = LOWER(p_email);
        RETURN l_count > 0;
    END is_suppressed;

    -- --------------------------------------------------------
    -- SUBSCRIBE
    -- --------------------------------------------------------
    PROCEDURE subscribe (
        p_email           IN  VARCHAR2,
        p_first_name      IN  VARCHAR2,
        p_honeypot        IN  VARCHAR2,
        p_ip_address      IN  VARCHAR2,
        p_source_url      IN  VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2
    ) IS
        l_count  NUMBER;
        l_sub_id NUMBER;
    BEGIN
        -- Honeypot check — silent discard, return ok to deceive bots
        IF p_honeypot IS NOT NULL AND LENGTH(TRIM(p_honeypot)) > 0 THEN
            p_status  := 'ok';
            p_message := 'Check your inbox to confirm your subscription.';
            RETURN;
        END IF;

        -- Basic email validation
        IF NOT is_valid_email(p_email) THEN
            p_status  := 'invalid_email';
            p_message := 'Please enter a valid email address.';
            RETURN;
        END IF;

        -- Suppression check
        IF is_suppressed(p_email) THEN
            -- Return ok — don't reveal suppression list membership
            p_status  := 'ok';
            p_message := 'Check your inbox to confirm your subscription.';
            RETURN;
        END IF;

        -- Check for existing record
        SELECT COUNT(*), MAX(subscriber_id)
        INTO   l_count, l_sub_id
        FROM   subscribers
        WHERE  LOWER(email) = LOWER(p_email);

        IF l_count > 0 THEN
            -- Already exists — check status
            DECLARE
                l_status VARCHAR2(20);
            BEGIN
                SELECT status INTO l_status
                FROM   subscribers
                WHERE  subscriber_id = l_sub_id;

                IF l_status = 'ACTIVE' THEN
                    -- Don't reveal they're already subscribed
                    p_status  := 'ok';
                    p_message := 'Check your inbox to confirm your subscription.';
                ELSIF l_status = 'PENDING' THEN
                    -- Resend confirmation
                    -- (email send delegated to sub_email package, M3)
                    p_status  := 'ok';
                    p_message := 'Check your inbox to confirm your subscription.';
                END IF;
            END;
            RETURN;
        END IF;

        -- Insert new PENDING subscriber
        INSERT INTO subscribers (
            email,
            first_name,
            status,
            confirm_token,
            unsubscribe_token,
            signup_ts,
            signup_ip,
            signup_source_url,
            consent_given
        ) VALUES (
            TRIM(p_email),
            TRIM(p_first_name),
            'PENDING',
            generate_token(),
            generate_token(),
            SYSTIMESTAMP,
            p_ip_address,
            p_source_url,
            'Y'
        );

        COMMIT;

        -- Send double opt-in confirmation email
        -- Called after COMMIT so email failure cannot roll back the INSERT
        DECLARE
            l_new_id NUMBER;
        BEGIN
            SELECT subscriber_id INTO l_new_id
            FROM   subscribers
            WHERE  LOWER(email) = LOWER(TRIM(p_email));
            sub_email.send_confirmation(l_new_id);
        EXCEPTION
            WHEN OTHERS THEN NULL;  -- Email failure never blocks subscription
        END;

        p_status  := 'ok';
        p_message := 'Check your inbox to confirm your subscription.';

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            -- Race condition — another session inserted same email
            p_status  := 'ok';
            p_message := 'Check your inbox to confirm your subscription.';
        WHEN OTHERS THEN
            ROLLBACK;
            p_status  := 'error';
            p_message := 'Something went wrong. Please try again.';
    END subscribe;

    -- --------------------------------------------------------
    -- CONFIRM_SUBSCRIPTION
    -- --------------------------------------------------------
    PROCEDURE confirm_subscription (
        p_token      IN  VARCHAR2,
        p_ip_address IN  VARCHAR2,
        p_status     OUT VARCHAR2
    ) IS
        l_sub_id NUMBER;
        l_status VARCHAR2(20);
    BEGIN
        -- Look up token
        BEGIN
            SELECT subscriber_id, status
            INTO   l_sub_id, l_status
            FROM   subscribers
            WHERE  confirm_token = p_token;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_status := 'invalid_token';
                RETURN;
        END;

        IF l_status = 'ACTIVE' THEN
            p_status := 'already_confirmed';
            RETURN;
        END IF;

        IF l_status IN ('UNSUBSCRIBED', 'BOUNCED') THEN
            p_status := 'invalid_token';
            RETURN;
        END IF;

        -- Activate
        UPDATE subscribers
        SET    status       = 'ACTIVE',
               confirm_ts   = SYSTIMESTAMP,
               confirm_ip   = p_ip_address,
               -- Invalidate confirm token — single use
               confirm_token = generate_token() || '_USED',
               updated_ts   = SYSTIMESTAMP
        WHERE  subscriber_id = l_sub_id;

        COMMIT;
        p_status := 'ok';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'error';
    END confirm_subscription;

    -- --------------------------------------------------------
    -- UNSUBSCRIBE
    -- Handles both subscriber-level token (from email link)
    -- and send-level token (from SEND_RECIPIENTS).
    -- Tries subscriber token first, then send-level token.
    -- --------------------------------------------------------
    PROCEDURE unsubscribe (
        p_token  IN  VARCHAR2,
        p_status OUT VARCHAR2
    ) IS
        l_sub_id    NUMBER;
        l_sub_status VARCHAR2(20);
    BEGIN
        -- Try subscriber-level unsubscribe token first
        BEGIN
            SELECT subscriber_id, status
            INTO   l_sub_id, l_sub_status
            FROM   subscribers
            WHERE  unsubscribe_token = p_token;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Try send-level token in SEND_RECIPIENTS
                BEGIN
                    SELECT sr.subscriber_id, s.status
                    INTO   l_sub_id, l_sub_status
                    FROM   send_recipients sr
                    JOIN   subscribers s ON s.subscriber_id = sr.subscriber_id
                    WHERE  sr.unsub_token = p_token;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        p_status := 'invalid_token';
                        RETURN;
                END;
        END;

        IF l_sub_status = 'UNSUBSCRIBED' THEN
            p_status := 'already_unsubscribed';
            RETURN;
        END IF;

        -- Mark unsubscribed
        UPDATE subscribers
        SET    status          = 'UNSUBSCRIBED',
               unsubscribed_ts = SYSTIMESTAMP,
               updated_ts      = SYSTIMESTAMP
        WHERE  subscriber_id   = l_sub_id;

        -- Add to suppression list
        MERGE INTO suppression_list tgt
        USING (
            SELECT subscriber_id,
                   email,
                   LOWER(RAWTOHEX(
                       DBMS_CRYPTO.HASH(
                           UTL_I18N.STRING_TO_RAW(LOWER(email), 'AL32UTF8'),
                           DBMS_CRYPTO.HASH_SH256
                       )
                   )) AS email_hash
            FROM   subscribers
            WHERE  subscriber_id = l_sub_id
        ) src
        ON    (tgt.subscriber_id = src.subscriber_id)
        WHEN NOT MATCHED THEN
            INSERT (email, email_hash, reason, subscriber_id, suppressed_ts)
            VALUES (src.email, src.email_hash, 'UNSUBSCRIBED', src.subscriber_id, SYSTIMESTAMP);

        COMMIT;
        p_status := 'ok';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status := 'error';
    END unsubscribe;

    -- --------------------------------------------------------
    -- TRACK_OPEN
    -- Records pixel load. Never raises — tracking must not
    -- break email rendering.
    -- --------------------------------------------------------
    PROCEDURE track_open (
        p_open_token IN  VARCHAR2,
        p_user_agent IN  VARCHAR2,
        p_ip_address IN  VARCHAR2
    ) IS
        l_recipient_id NUMBER;
        l_send_id      NUMBER;
        l_sub_id       NUMBER;
    BEGIN
        -- Resolve token
        SELECT recipient_id, send_id, subscriber_id
        INTO   l_recipient_id, l_send_id, l_sub_id
        FROM   send_recipients
        WHERE  open_token = p_open_token
        AND    status     = 'SENT';

        INSERT INTO open_events (
            recipient_id, send_id, subscriber_id,
            opened_ts, user_agent, ip_address
        ) VALUES (
            l_recipient_id, l_send_id, l_sub_id,
            SYSTIMESTAMP, SUBSTR(p_user_agent, 1, 1000), p_ip_address
        );

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN NULL;  -- Silent — never break pixel response
    END track_open;

    -- --------------------------------------------------------
    -- TRACK_CLICK
    -- Records click, returns original URL for redirect.
    -- Returns NULL if token invalid (caller redirects to home).
    -- --------------------------------------------------------
    FUNCTION track_click (
        p_link_token      IN  VARCHAR2,
        p_send_id         IN  NUMBER,
        p_recipient_token IN  VARCHAR2,
        p_user_agent      IN  VARCHAR2,
        p_ip_address      IN  VARCHAR2
    ) RETURN VARCHAR2 IS
        l_link_id      NUMBER;
        l_original_url VARCHAR2(4000);
        l_recipient_id NUMBER;
        l_sub_id       NUMBER;
    BEGIN
        -- Resolve link
        SELECT link_id, original_url
        INTO   l_link_id, l_original_url
        FROM   link_registry
        WHERE  link_token = p_link_token
        AND    send_id    = p_send_id;

        -- Resolve recipient (best effort — don't fail the redirect)
        BEGIN
            SELECT recipient_id, subscriber_id
            INTO   l_recipient_id, l_sub_id
            FROM   send_recipients
            WHERE  open_token = p_recipient_token  -- reuse open token for recipient id
            AND    send_id    = p_send_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN NULL;
        END;

        -- Record click
        IF l_recipient_id IS NOT NULL THEN
            INSERT INTO click_events (
                recipient_id, link_id, send_id, subscriber_id,
                clicked_ts, user_agent, ip_address
            ) VALUES (
                l_recipient_id, l_link_id, p_send_id, l_sub_id,
                SYSTIMESTAMP, SUBSTR(p_user_agent, 1, 1000), p_ip_address
            );
            COMMIT;
        END IF;

        RETURN l_original_url;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
        WHEN OTHERS        THEN RETURN NULL;
    END track_click;

END sub_api;
/
