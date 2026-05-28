-- ============================================================
-- ORDS Module Definitions — Subscriber Module
-- Run as schema owner after package compilation.
--
-- Modules defined:
--   subscriber  → /subscriber/  (subscription lifecycle)
--   tracker     → /tracker/     (analytics endpoints)
--
-- All endpoints are unauthenticated (public).
-- CORS: same-origin — blog and ORDS on same ADB instance.
-- ============================================================

BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => USER,
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'blog',
        p_auto_rest_auth      => FALSE
    );
END;
/

BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'subscriber');
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'tracker');
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- ============================================================
-- MODULE: subscriber
-- ============================================================
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'subscriber',
        p_base_path      => '/subscriber/',
        p_items_per_page => 0,
        p_status         => 'PUBLISHED',
        p_comments       => 'Subscriber lifecycle endpoints: subscribe, confirm, unsubscribe'
    );
END;
/

-- ------------------------------------------------------------
-- POST /subscriber/subscribe
-- Accepts JSON body: {email, first_name, website (honeypot)}
-- Returns JSON: {status, message}
-- ------------------------------------------------------------
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'subscriber',
        p_pattern        => 'subscribe'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'subscriber',
        p_pattern        => 'subscribe',
        p_method         => 'POST',
        p_source_type    => ORDS.SOURCE_TYPE_PLSQL,
        p_mimes_allowed  => 'application/json',
        p_source         => '
DECLARE
    l_body      CLOB    := :body_text;
    l_json      JSON_OBJECT_T;
    l_email     VARCHAR2(320);
    l_name      VARCHAR2(100);
    l_honeypot  VARCHAR2(200);
    l_ip        VARCHAR2(45);
    l_source    VARCHAR2(2000);
    l_status    VARCHAR2(50);
    l_message   VARCHAR2(500);
BEGIN
    -- Parse JSON body
    l_json     := JSON_OBJECT_T.PARSE(l_body);
    l_email    := l_json.get_string(''email'');
    l_name     := l_json.get_string(''first_name'');
    l_honeypot := l_json.get_string(''website'');   -- honeypot field
    l_ip       := OWA_UTIL.get_cgi_env(''REMOTE_ADDR'');
    l_source   := OWA_UTIL.get_cgi_env(''HTTP_REFERER'');

    sub_api.subscribe(
        p_email       => l_email,
        p_first_name  => l_name,
        p_honeypot    => l_honeypot,
        p_ip_address  => l_ip,
        p_source_url  => l_source,
        p_status      => l_status,
        p_message     => l_message
    );

    -- Return JSON response
    HTP.p(JSON_OBJECT(
        ''status''  VALUE l_status,
        ''message'' VALUE l_message
    ));

    :status_code := CASE l_status
        WHEN ''ok''            THEN 200
        WHEN ''invalid_email'' THEN 400
        ELSE                        500
    END;
END;
        '
    );
END;
/

-- ------------------------------------------------------------
-- GET /subscriber/confirm?token=xxx
-- Double opt-in confirmation link from email.
-- Redirects to Hugo confirmation page on completion.
-- ------------------------------------------------------------
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'subscriber',
        p_pattern        => 'confirm'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'subscriber',
        p_pattern        => 'confirm',
        p_method         => 'GET',
        p_source_type    => ORDS.SOURCE_TYPE_PLSQL,
        p_source         => '
DECLARE
    l_token  VARCHAR2(200) := :token;
    l_ip     VARCHAR2(45)  := OWA_UTIL.get_cgi_env(''REMOTE_ADDR'');
    l_status VARCHAR2(50);
BEGIN
    IF l_token IS NULL THEN
        OWA_UTIL.redirect_url(''/subscribe/confirmed?result=invalid'');
        RETURN;
    END IF;

    sub_api.confirm_subscription(
        p_token      => l_token,
        p_ip_address => l_ip,
        p_status     => l_status
    );

    -- All outcomes redirect to the same Hugo page
    -- result param allows Hugo to show appropriate message
    OWA_UTIL.redirect_url(
        ''/subscribe/confirmed?result='' || l_status
    );
END;
        '
    );

    -- Declare token as URI parameter
    ORDS.DEFINE_PARAMETER(
        p_module_name        => 'subscriber',
        p_pattern            => 'confirm',
        p_method             => 'GET',
        p_name               => 'token',
        p_bind_variable_name => 'token',
        p_source_type        => 'HEADER',
        p_param_type         => 'STRING',
        p_access_method      => 'IN'
    );
END;
/

-- ------------------------------------------------------------
-- GET /subscriber/unsubscribe?token=xxx
-- Unsubscribe link from email footer.
-- Redirects to Hugo unsubscribe confirmation page.
-- ------------------------------------------------------------
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'subscriber',
        p_pattern        => 'unsubscribe'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'subscriber',
        p_pattern        => 'unsubscribe',
        p_method         => 'GET',
        p_source_type    => ORDS.SOURCE_TYPE_PLSQL,
        p_source         => '
DECLARE
    l_token  VARCHAR2(200) := :token;
    l_status VARCHAR2(50);
BEGIN
    IF l_token IS NULL THEN
        OWA_UTIL.redirect_url(''/subscribe/unsubscribed?result=invalid'');
        RETURN;
    END IF;

    sub_api.unsubscribe(
        p_token  => l_token,
        p_status => l_status
    );

    OWA_UTIL.redirect_url(
        ''/subscribe/unsubscribed?result='' || l_status
    );
END;
        '
    );
END;
/

-- ============================================================
-- MODULE: tracker
-- ============================================================
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'tracker',
        p_base_path      => '/tracker/',
        p_items_per_page => 0,
        p_status         => 'PUBLISHED',
        p_comments       => 'Email analytics: open pixel and click redirect'
    );
END;
/

-- ------------------------------------------------------------
-- GET /tracker/pixel?t=open_token
-- 1x1 transparent GIF. Records open event.
-- Cache-control headers prevent email client caching.
-- Must respond fast — in critical path of email render.
-- ------------------------------------------------------------
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'tracker',
        p_pattern        => 'pixel'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'tracker',
        p_pattern        => 'pixel',
        p_method         => 'GET',
        p_source_type    => ORDS.SOURCE_TYPE_PLSQL,
        p_source         => '
DECLARE
    -- Minimal 1x1 transparent GIF (43 bytes)
    l_gif_hex CONSTANT VARCHAR2(100) :=
        ''47494638396101000100800000FFFFFF00000021F9040000000000002C00000000''||
        ''010001000002024401003B'';
    l_gif     RAW(100) := HEXTORAW(l_gif_hex);
    l_token   VARCHAR2(200) := :t;
    l_ua      VARCHAR2(1000) := OWA_UTIL.get_cgi_env(''HTTP_USER_AGENT'');
    l_ip      VARCHAR2(45)   := OWA_UTIL.get_cgi_env(''REMOTE_ADDR'');
BEGIN
    -- Record open event (silent — never raises)
    IF l_token IS NOT NULL THEN
        sub_api.track_open(
            p_open_token => l_token,
            p_user_agent => l_ua,
            p_ip_address => l_ip
        );
    END IF;

    -- Set headers to prevent caching
    OWA_UTIL.mime_header(''image/gif'', FALSE);
    HTP.p(''Cache-Control: no-cache, no-store, must-revalidate'');
    HTP.p(''Pragma: no-cache'');
    HTP.p(''Expires: 0'');
    OWA_UTIL.http_header_close();

    -- Serve the pixel
    WPG_DOCLOAD.download_file(l_gif);
END;
        '
    );
END;
/

-- ------------------------------------------------------------
-- GET /tracker/click?s=send_id&l=link_token&r=recipient_token
-- Click redirect. Records click, issues 302 to original URL.
-- Falls back to blog home if token invalid.
-- ------------------------------------------------------------
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name    => 'tracker',
        p_pattern        => 'click'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'tracker',
        p_pattern        => 'click',
        p_method         => 'GET',
        p_source_type    => ORDS.SOURCE_TYPE_PLSQL,
        p_source         => '
DECLARE
    l_send_id   NUMBER         := TO_NUMBER(:s);
    l_link_tok  VARCHAR2(100)  := :l;
    l_rec_tok   VARCHAR2(200)  := :r;
    l_ua        VARCHAR2(1000) := OWA_UTIL.get_cgi_env(''HTTP_USER_AGENT'');
    l_ip        VARCHAR2(45)   := OWA_UTIL.get_cgi_env(''REMOTE_ADDR'');
    l_target    VARCHAR2(4000);
BEGIN
    l_target := sub_api.track_click(
        p_link_token      => l_link_tok,
        p_send_id         => l_send_id,
        p_recipient_token => l_rec_tok,
        p_user_agent      => l_ua,
        p_ip_address      => l_ip
    );

    -- 302 redirect — never cache
    :status_code := 302;
    OWA_UTIL.redirect_url(
        NVL(l_target, ''/'')   -- fallback to blog home
    );
END;
        '
    );
END;
/

COMMIT;
PROMPT Subscriber ORDS modules published.
