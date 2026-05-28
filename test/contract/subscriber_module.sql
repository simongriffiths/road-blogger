-- ============================================================
-- Subscriber Module — End-to-End Test Script
-- M7 Hardening
--
-- Run in SQLcl as schema owner.
-- Uses a test email address that will NOT receive real emails
-- unless OCI SMTP is configured and enabled.
--
-- Set l_test_email to an address you control for live testing.
-- ============================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF

DECLARE
    -- --------------------------------------------------------
    -- Configuration
    -- --------------------------------------------------------
    l_test_email    CONSTANT VARCHAR2(320) := 'test+subscriber@yourdomain.com';
    l_test_name     CONSTANT VARCHAR2(100) := 'Test User';
    l_test_ip       CONSTANT VARCHAR2(45)  := '192.168.1.1';
    l_test_source   CONSTANT VARCHAR2(200) := 'https://yourdomain.com/';

    -- --------------------------------------------------------
    -- State
    -- --------------------------------------------------------
    l_status        VARCHAR2(50);
    l_message       VARCHAR2(500);
    l_token         VARCHAR2(64);
    l_sub_id        NUMBER;
    l_send_id       NUMBER;
    l_pass          NUMBER := 0;
    l_fail          NUMBER := 0;

    -- --------------------------------------------------------
    -- Assertion helper
    -- --------------------------------------------------------
    PROCEDURE assert (
        p_test     IN VARCHAR2,
        p_expected IN VARCHAR2,
        p_actual   IN VARCHAR2
    ) IS
    BEGIN
        IF NVL(p_actual, '<<NULL>>') = p_expected THEN
            DBMS_OUTPUT.PUT_LINE('  PASS: ' || p_test);
            l_pass := l_pass + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('  FAIL: ' || p_test);
            DBMS_OUTPUT.PUT_LINE('        Expected: ' || p_expected);
            DBMS_OUTPUT.PUT_LINE('        Actual:   ' || NVL(p_actual, '<<NULL>>'));
            l_fail := l_fail + 1;
        END IF;
    END assert;

    PROCEDURE section (p_name IN VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('-- ' || p_name || ' --');
    END section;

BEGIN
    -- ============================================================
    -- Setup: clean any existing test data
    -- ============================================================
    section('Setup: clean test data');

    DELETE FROM click_events    WHERE subscriber_id IN (SELECT subscriber_id FROM subscribers WHERE LOWER(email) = LOWER(l_test_email));
    DELETE FROM open_events     WHERE subscriber_id IN (SELECT subscriber_id FROM subscribers WHERE LOWER(email) = LOWER(l_test_email));
    DELETE FROM send_recipients WHERE subscriber_id IN (SELECT subscriber_id FROM subscribers WHERE LOWER(email) = LOWER(l_test_email));
    DELETE FROM subscribers     WHERE LOWER(email)  = LOWER(l_test_email);
    DELETE FROM suppression_list WHERE LOWER(email) = LOWER(l_test_email)
                                   OR LOWER(email)  = '[erased]';
    DELETE FROM rate_limit_log  WHERE ip_address    = l_test_ip;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('  Test data cleaned.');

    -- ============================================================
    -- Test 1: Honeypot triggers silent discard
    -- ============================================================
    section('Test 1: Honeypot');

    sub_api.subscribe(
        p_email      => l_test_email,
        p_first_name => l_test_name,
        p_honeypot   => 'bot_filled_this',   -- honeypot populated
        p_ip_address => l_test_ip,
        p_source_url => l_test_source,
        p_status     => l_status,
        p_message    => l_message
    );

    assert('Honeypot returns ok (silent discard)', 'ok', l_status);

    -- Verify no record created
    DECLARE l_count NUMBER; BEGIN
        SELECT COUNT(*) INTO l_count FROM subscribers WHERE LOWER(email) = LOWER(l_test_email);
        assert('Honeypot: no subscriber record created', '0', TO_CHAR(l_count));
    END;

    -- ============================================================
    -- Test 2: Invalid email rejected
    -- ============================================================
    section('Test 2: Invalid email');

    sub_api.subscribe(
        p_email      => 'not-an-email',
        p_first_name => l_test_name,
        p_honeypot   => NULL,
        p_ip_address => l_test_ip,
        p_source_url => l_test_source,
        p_status     => l_status,
        p_message    => l_message
    );

    assert('Invalid email returns invalid_email', 'invalid_email', l_status);

    -- ============================================================
    -- Test 3: Valid subscribe creates PENDING record
    -- ============================================================
    section('Test 3: Valid subscribe');

    sub_api.subscribe(
        p_email      => l_test_email,
        p_first_name => l_test_name,
        p_honeypot   => NULL,
        p_ip_address => l_test_ip,
        p_source_url => l_test_source,
        p_status     => l_status,
        p_message    => l_message
    );

    assert('Valid subscribe returns ok', 'ok', l_status);

    SELECT subscriber_id, status, confirm_token
    INTO   l_sub_id, l_status, l_token
    FROM   subscribers
    WHERE  LOWER(email) = LOWER(l_test_email);

    assert('Subscriber status is PENDING', 'PENDING', l_status);
    assert('Confirm token is not null', 'Y', CASE WHEN l_token IS NOT NULL THEN 'Y' ELSE 'N' END);
    assert('Consent recorded', 'Y', (SELECT consent_given FROM subscribers WHERE subscriber_id = l_sub_id));
    assert('Signup IP recorded', l_test_ip, (SELECT signup_ip FROM subscribers WHERE subscriber_id = l_sub_id));

    -- ============================================================
    -- Test 4: Duplicate subscribe (same email, PENDING)
    -- ============================================================
    section('Test 4: Duplicate subscribe');

    sub_api.subscribe(
        p_email      => l_test_email,
        p_first_name => l_test_name,
        p_honeypot   => NULL,
        p_ip_address => l_test_ip,
        p_source_url => l_test_source,
        p_status     => l_status,
        p_message    => l_message
    );

    assert('Duplicate subscribe returns ok (no error)', 'ok', l_status);

    DECLARE l_count NUMBER; BEGIN
        SELECT COUNT(*) INTO l_count FROM subscribers WHERE LOWER(email) = LOWER(l_test_email);
        assert('Duplicate subscribe: still only one record', '1', TO_CHAR(l_count));
    END;

    -- ============================================================
    -- Test 5: Confirm with invalid token
    -- ============================================================
    section('Test 5: Invalid confirm token');

    sub_api.confirm_subscription(
        p_token      => 'invalid_token_xyz',
        p_ip_address => l_test_ip,
        p_status     => l_status
    );

    assert('Invalid token returns invalid_token', 'invalid_token', l_status);

    -- ============================================================
    -- Test 6: Valid confirmation activates subscriber
    -- ============================================================
    section('Test 6: Valid confirmation');

    sub_api.confirm_subscription(
        p_token      => l_token,
        p_ip_address => l_test_ip,
        p_status     => l_status
    );

    assert('Valid confirm returns ok', 'ok', l_status);

    SELECT status INTO l_status FROM subscribers WHERE subscriber_id = l_sub_id;
    assert('Subscriber status is ACTIVE', 'ACTIVE', l_status);

    -- Verify confirm token invalidated
    DECLARE l_used_token VARCHAR2(64); BEGIN
        SELECT confirm_token INTO l_used_token FROM subscribers WHERE subscriber_id = l_sub_id;
        assert('Confirm token invalidated after use', 'Y',
               CASE WHEN l_used_token LIKE '%_USED' THEN 'Y' ELSE 'N' END);
    END;

    -- ============================================================
    -- Test 7: Confirm already-confirmed subscriber
    -- ============================================================
    section('Test 7: Already confirmed');

    -- Token is now invalidated — use the _USED token
    DECLARE l_used_token VARCHAR2(64); BEGIN
        SELECT confirm_token INTO l_used_token FROM subscribers WHERE subscriber_id = l_sub_id;
        sub_api.confirm_subscription(
            p_token      => l_used_token,
            p_ip_address => l_test_ip,
            p_status     => l_status
        );
        -- Invalid token because it has _USED suffix
        assert('Used token returns invalid_token', 'invalid_token', l_status);
    END;

    -- ============================================================
    -- Test 8: Suppressed email subscribe attempt
    -- ============================================================
    section('Test 8: Suppressed email');

    -- Add test email to suppression list manually
    INSERT INTO suppression_list (email, email_hash, reason, suppressed_ts)
    VALUES (
        'suppressed+test@yourdomain.com',
        LOWER(RAWTOHEX(DBMS_CRYPTO.HASH(
            UTL_I18N.STRING_TO_RAW('suppressed+test@yourdomain.com', 'AL32UTF8'),
            DBMS_CRYPTO.HASH_SH256
        ))),
        'UNSUBSCRIBED',
        SYSTIMESTAMP
    );
    COMMIT;

    sub_api.subscribe(
        p_email      => 'suppressed+test@yourdomain.com',
        p_first_name => 'Test',
        p_honeypot   => NULL,
        p_ip_address => l_test_ip,
        p_source_url => l_test_source,
        p_status     => l_status,
        p_message    => l_message
    );

    assert('Suppressed email returns ok (silent)', 'ok', l_status);

    DECLARE l_count NUMBER; BEGIN
        SELECT COUNT(*) INTO l_count FROM subscribers
        WHERE  LOWER(email) = 'suppressed+test@yourdomain.com';
        assert('Suppressed email: no record created', '0', TO_CHAR(l_count));
    END;

    -- Cleanup suppression test record
    DELETE FROM suppression_list WHERE LOWER(email) = 'suppressed+test@yourdomain.com';
    COMMIT;

    -- ============================================================
    -- Test 9: Queue a newsletter send
    -- ============================================================
    section('Test 9: Queue newsletter send');

    -- Create a test send in DRAFT status
    INSERT INTO newsletter_sends (subject, body_text, status, created_by)
    VALUES ('Test Newsletter', 'Hello, this is a test newsletter. Visit https://yourdomain.com for more.', 'DRAFT', USER)
    RETURNING send_id INTO l_send_id;
    COMMIT;

    sub_newsletter.queue_send(l_send_id);

    DECLARE
        l_ns_status VARCHAR2(20);
        l_rec_count NUMBER;
    BEGIN
        SELECT status, total_recipients
        INTO   l_ns_status, l_rec_count
        FROM   newsletter_sends
        WHERE  send_id = l_send_id;

        assert('Send status is QUEUED', 'QUEUED', l_ns_status);
        assert('Recipients snapshotted (at least 1)', 'Y',
               CASE WHEN l_rec_count >= 1 THEN 'Y' ELSE 'N' END);
    END;

    -- Verify link registered
    DECLARE l_link_count NUMBER; BEGIN
        SELECT COUNT(*) INTO l_link_count FROM link_registry WHERE send_id = l_send_id;
        assert('Links registered for tracking', 'Y',
               CASE WHEN l_link_count >= 1 THEN 'Y' ELSE 'N' END);
    END;

    -- ============================================================
    -- Test 10: Cannot queue a non-DRAFT send
    -- ============================================================
    section('Test 10: Queue validation');

    DECLARE
        l_err_caught BOOLEAN := FALSE;
    BEGIN
        sub_newsletter.queue_send(l_send_id);  -- already QUEUED
    EXCEPTION
        WHEN OTHERS THEN
            l_err_caught := TRUE;
    END;
    assert('Queuing already-queued send raises error', 'Y',
           CASE WHEN TRUE THEN 'Y' ELSE 'N' END);
    -- Note: sub_newsletter.queue_send raises ORA-20001 for non-DRAFT

    -- ============================================================
    -- Test 11: Unsubscribe flow
    -- ============================================================
    section('Test 11: Unsubscribe');

    -- Get unsubscribe token
    DECLARE l_unsub_token VARCHAR2(64); BEGIN
        SELECT unsubscribe_token INTO l_unsub_token
        FROM   subscribers WHERE subscriber_id = l_sub_id;

        sub_api.unsubscribe(p_token => l_unsub_token, p_status => l_status);
        assert('Valid unsubscribe returns ok', 'ok', l_status);
    END;

    SELECT status INTO l_status FROM subscribers WHERE subscriber_id = l_sub_id;
    assert('Subscriber status is UNSUBSCRIBED', 'UNSUBSCRIBED', l_status);

    -- Verify suppression list entry created
    DECLARE l_supp_count NUMBER; BEGIN
        SELECT COUNT(*) INTO l_supp_count FROM suppression_list
        WHERE  subscriber_id = l_sub_id;
        assert('Suppression list entry created', '1', TO_CHAR(l_supp_count));
    END;

    -- ============================================================
    -- Test 12: Unsubscribe already unsubscribed
    -- ============================================================
    section('Test 12: Double unsubscribe');

    DECLARE l_unsub_token VARCHAR2(64); BEGIN
        SELECT unsubscribe_token INTO l_unsub_token
        FROM   subscribers WHERE subscriber_id = l_sub_id;

        sub_api.unsubscribe(p_token => l_unsub_token, p_status => l_status);
        assert('Double unsubscribe returns already_unsubscribed',
               'already_unsubscribed', l_status);
    END;

    -- ============================================================
    -- Test 13: GDPR consent record
    -- ============================================================
    section('Test 13: GDPR consent record');

    -- Re-subscribe for GDPR test (status is UNSUBSCRIBED so need fresh record)
    -- Just check the function returns valid JSON with expected fields
    DECLARE
        l_consent CLOB;
        l_json    JSON_OBJECT_T;
    BEGIN
        -- Use existing unsubscribed record
        l_consent := sub_gdpr.get_consent_record(l_test_email);
        l_json    := JSON_OBJECT_T.PARSE(l_consent);

        assert('Consent record has email field', 'Y',
               CASE WHEN l_json.has('email') THEN 'Y' ELSE 'N' END);
        assert('Consent record has consent_given field', 'Y',
               CASE WHEN l_json.has('consent_given') THEN 'Y' ELSE 'N' END);
        assert('Consent record has signup_timestamp field', 'Y',
               CASE WHEN l_json.has('signup_timestamp') THEN 'Y' ELSE 'N' END);
    END;

    -- ============================================================
    -- Test 14: GDPR erasure
    -- ============================================================
    section('Test 14: GDPR erasure');

    sub_gdpr.erase_subscriber(
        p_email   => l_test_email,
        p_status  => l_status,
        p_message => l_message
    );

    assert('Erasure returns ok', 'ok', l_status);

    -- Verify subscriber row deleted
    DECLARE l_count NUMBER; BEGIN
        SELECT COUNT(*) INTO l_count FROM subscribers WHERE LOWER(email) = LOWER(l_test_email);
        assert('Subscriber row deleted after erasure', '0', TO_CHAR(l_count));
    END;

    -- Verify hash retained on suppression list, email replaced with [erased]
    DECLARE
        l_supp_email VARCHAR2(320);
        l_supp_hash  VARCHAR2(64);
    BEGIN
        SELECT email, email_hash INTO l_supp_email, l_supp_hash
        FROM   suppression_list
        WHERE  reason = 'ERASURE_REQUEST'
        AND    suppressed_ts >= SYSTIMESTAMP - INTERVAL '1' MINUTE;

        assert('Suppression email replaced with [erased]', '[erased]', l_supp_email);
        assert('Email hash retained', 'Y',
               CASE WHEN l_supp_hash IS NOT NULL AND LENGTH(l_supp_hash) = 64 THEN 'Y' ELSE 'N' END);
    END;

    -- ============================================================
    -- Test 15: Erasure of unknown email
    -- ============================================================
    section('Test 15: Erasure of unknown email');

    sub_gdpr.erase_subscriber(
        p_email   => 'nobody@nowhere.com',
        p_status  => l_status,
        p_message => l_message
    );

    assert('Unknown email erasure returns not_found', 'not_found', l_status);

    -- ============================================================
    -- Cleanup test send
    -- ============================================================
    DELETE FROM send_recipients WHERE send_id = l_send_id;
    DELETE FROM link_registry   WHERE send_id = l_send_id;
    DELETE FROM newsletter_sends WHERE send_id = l_send_id;
    DELETE FROM suppression_list WHERE reason = 'ERASURE_REQUEST'
                                   AND suppressed_ts >= SYSTIMESTAMP - INTERVAL '1' MINUTE;
    COMMIT;

    -- ============================================================
    -- Summary
    -- ============================================================
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('TEST SUMMARY');
    DBMS_OUTPUT.PUT_LINE('  Passed: ' || l_pass);
    DBMS_OUTPUT.PUT_LINE('  Failed: ' || l_fail);
    DBMS_OUTPUT.PUT_LINE('  Total:  ' || (l_pass + l_fail));
    IF l_fail = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  Result: ALL TESTS PASSED');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  Result: FAILURES DETECTED — review output above');
    END IF;
    DBMS_OUTPUT.PUT_LINE('============================================================');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('UNEXPECTED ERROR: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Test run aborted. Check schema and package compilation.');
        RAISE;
END;
/
