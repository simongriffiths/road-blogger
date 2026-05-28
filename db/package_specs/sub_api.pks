-- ============================================================
-- Package: SUB_API
-- Subscriber module core business logic.
-- Called by ORDS handlers — keeps handler code thin.
-- ============================================================
CREATE OR REPLACE PACKAGE sub_api AS

    -- --------------------------------------------------------
    -- Subscribe: validate, honeypot check, insert PENDING,
    -- return status for JSON response.
    -- p_status OUT: 'ok' | 'already_subscribed' | 'invalid_email'
    -- --------------------------------------------------------
    PROCEDURE subscribe (
        p_email           IN  VARCHAR2,
        p_first_name      IN  VARCHAR2,
        p_honeypot        IN  VARCHAR2,
        p_ip_address      IN  VARCHAR2,
        p_source_url      IN  VARCHAR2,
        p_status          OUT VARCHAR2,
        p_message         OUT VARCHAR2
    );

    -- --------------------------------------------------------
    -- Confirm: validate token, activate subscriber.
    -- p_status OUT: 'ok' | 'already_confirmed' | 'invalid_token' | 'expired'
    -- --------------------------------------------------------
    PROCEDURE confirm_subscription (
        p_token           IN  VARCHAR2,
        p_ip_address      IN  VARCHAR2,
        p_status          OUT VARCHAR2
    );

    -- --------------------------------------------------------
    -- Unsubscribe: validate token, mark unsubscribed,
    -- add to suppression list.
    -- p_status OUT: 'ok' | 'already_unsubscribed' | 'invalid_token'
    -- --------------------------------------------------------
    PROCEDURE unsubscribe (
        p_token           IN  VARCHAR2,
        p_status          OUT VARCHAR2
    );

    -- --------------------------------------------------------
    -- Track open: record open event from pixel load.
    -- Silent — never raises exceptions to caller.
    -- --------------------------------------------------------
    PROCEDURE track_open (
        p_open_token      IN  VARCHAR2,
        p_user_agent      IN  VARCHAR2,
        p_ip_address      IN  VARCHAR2
    );

    -- --------------------------------------------------------
    -- Track click: record click event, return original URL
    -- for redirect. Returns NULL if token invalid.
    -- --------------------------------------------------------
    FUNCTION track_click (
        p_link_token      IN  VARCHAR2,
        p_send_id         IN  NUMBER,
        p_recipient_token IN  VARCHAR2,
        p_user_agent      IN  VARCHAR2,
        p_ip_address      IN  VARCHAR2
    ) RETURN VARCHAR2;

    -- --------------------------------------------------------
    -- Internal helpers
    -- --------------------------------------------------------
    FUNCTION is_valid_email    (p_email IN VARCHAR2) RETURN BOOLEAN;
    FUNCTION generate_token    RETURN VARCHAR2;
    FUNCTION is_suppressed     (p_email IN VARCHAR2) RETURN BOOLEAN;

END sub_api;
/
