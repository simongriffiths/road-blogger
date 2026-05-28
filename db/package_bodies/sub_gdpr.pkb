CREATE OR REPLACE PACKAGE BODY sub_gdpr AS

    -- --------------------------------------------------------
    -- ERASE_SUBSCRIBER
    -- --------------------------------------------------------
    PROCEDURE erase_subscriber (
        p_email   IN  VARCHAR2,
        p_status  OUT VARCHAR2,
        p_message OUT VARCHAR2
    ) IS
        l_sub_id     NUMBER;
        l_sub_status VARCHAR2(20);
        l_email_norm VARCHAR2(320);
        l_email_hash VARCHAR2(64);
    BEGIN
        l_email_norm := LOWER(TRIM(p_email));

        -- Locate subscriber
        BEGIN
            SELECT subscriber_id, status
            INTO   l_sub_id, l_sub_status
            FROM   subscribers
            WHERE  LOWER(email) = l_email_norm;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Check suppression list — may have been erased already
                DECLARE
                    l_supp_count NUMBER;
                BEGIN
                    SELECT COUNT(*) INTO l_supp_count
                    FROM   suppression_list
                    WHERE  LOWER(email) = l_email_norm;

                    IF l_supp_count > 0 THEN
                        p_status  := 'ok';
                        p_message := 'No personal data found. Address is on suppression list.';
                    ELSE
                        p_status  := 'not_found';
                        p_message := 'No subscriber record found for this email address.';
                    END IF;
                END;
                RETURN;
        END;

        -- Compute email hash before deletion
        l_email_hash := LOWER(RAWTOHEX(
            DBMS_CRYPTO.HASH(
                UTL_I18N.STRING_TO_RAW(l_email_norm, 'AL32UTF8'),
                DBMS_CRYPTO.HASH_SH256
            )
        ));

        -- Ensure email hash is on suppression list
        -- (may already be there if unsubscribed)
        MERGE INTO suppression_list tgt
        USING (SELECT l_sub_id AS sid FROM DUAL) src
        ON    (tgt.subscriber_id = src.sid)
        WHEN MATCHED THEN
            UPDATE SET
                reason        = 'ERASURE_REQUEST',
                email         = l_email_norm,     -- retained until row updated
                email_hash    = l_email_hash,
                suppressed_ts = SYSTIMESTAMP
        WHEN NOT MATCHED THEN
            INSERT (email, email_hash, reason, subscriber_id, suppressed_ts)
            VALUES (l_email_norm, l_email_hash, 'ERASURE_REQUEST', l_sub_id, SYSTIMESTAMP);

        -- Null out personal data in SEND_RECIPIENTS
        -- Send history rows are retained for analytics integrity
        -- but the subscriber FK is cleared
        UPDATE send_recipients
        SET    subscriber_id = NULL
        WHERE  subscriber_id = l_sub_id;

        -- Null out personal data in event tables
        UPDATE open_events
        SET    subscriber_id = NULL
        WHERE  subscriber_id = l_sub_id;

        UPDATE click_events
        SET    subscriber_id = NULL
        WHERE  subscriber_id = l_sub_id;

        -- Delete the subscriber row — all PII removed
        DELETE FROM subscribers
        WHERE  subscriber_id = l_sub_id;

        -- Remove raw email from suppression list now subscriber row is gone
        -- Retain only the hash
        UPDATE suppression_list
        SET    email         = '[erased]',
               subscriber_id = NULL
        WHERE  subscriber_id = l_sub_id;

        COMMIT;

        p_status  := 'ok';
        p_message := 'Subscriber data erased. Email hash retained on suppression list.';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_status  := 'error';
            p_message := 'Erasure failed: ' || SQLERRM;
    END erase_subscriber;

    -- --------------------------------------------------------
    -- GET_CONSENT_RECORD
    -- --------------------------------------------------------
    FUNCTION get_consent_record (
        p_email IN VARCHAR2
    ) RETURN CLOB IS
        l_result CLOB;
    BEGIN
        SELECT JSON_OBJECT(
            'email'            VALUE email,
            'status'           VALUE status,
            'consent_given'    VALUE consent_given,
            'signup_timestamp' VALUE TO_CHAR(signup_ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'signup_ip'        VALUE signup_ip,
            'signup_source'    VALUE signup_source_url,
            'confirmed_timestamp' VALUE TO_CHAR(confirm_ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
            'confirmed_ip'     VALUE confirm_ip
            RETURNING CLOB
        )
        INTO  l_result
        FROM  subscribers
        WHERE LOWER(email) = LOWER(TRIM(p_email));

        RETURN l_result;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN JSON_OBJECT('error' VALUE 'No subscriber record found for this email.');
        WHEN OTHERS THEN
            RETURN JSON_OBJECT('error' VALUE SQLERRM);
    END get_consent_record;

    -- --------------------------------------------------------
    -- EXPORT_SUBSCRIBER_DATA
    -- --------------------------------------------------------
    FUNCTION export_subscriber_data (
        p_email IN VARCHAR2
    ) RETURN CLOB IS
        l_sub_id NUMBER;
        l_result CLOB;
    BEGIN
        SELECT subscriber_id INTO l_sub_id
        FROM   subscribers
        WHERE  LOWER(email) = LOWER(TRIM(p_email));

        SELECT JSON_OBJECT(
            'subscriber' VALUE JSON_OBJECT(
                'email'          VALUE email,
                'first_name'     VALUE first_name,
                'status'         VALUE status,
                'signup_date'    VALUE TO_CHAR(signup_ts, 'YYYY-MM-DD'),
                'confirmed_date' VALUE TO_CHAR(confirm_ts, 'YYYY-MM-DD'),
                'consent_given'  VALUE consent_given,
                'signup_source'  VALUE signup_source_url
            ),
            'sends_received' VALUE (
                SELECT COUNT(*)
                FROM   send_recipients
                WHERE  subscriber_id = l_sub_id
                AND    status        = 'SENT'
            ),
            'opens_recorded' VALUE (
                SELECT COUNT(*)
                FROM   open_events
                WHERE  subscriber_id = l_sub_id
            ),
            'clicks_recorded' VALUE (
                SELECT COUNT(*)
                FROM   click_events
                WHERE  subscriber_id = l_sub_id
            )
            RETURNING CLOB
        )
        INTO  l_result
        FROM  subscribers
        WHERE subscriber_id = l_sub_id;

        RETURN l_result;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN JSON_OBJECT('error' VALUE 'No subscriber record found.');
        WHEN OTHERS THEN
            RETURN JSON_OBJECT('error' VALUE SQLERRM);
    END export_subscriber_data;

END sub_gdpr;
/
