-- ============================================================
-- ORDS Admin Module — GDPR Endpoints
-- Protected — requires ORDS First Party Auth.
-- Base path: /admin/
--
-- Endpoints:
--   POST /admin/gdpr/erase        — right to erasure
--   GET  /admin/gdpr/consent      — consent audit record
--   GET  /admin/gdpr/export       — data portability export
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
    ORDS.DELETE_MODULE(p_module_name => 'admin');
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- Create or extend the admin module
BEGIN
    -- Admin module may already exist from M5 — use DEFINE which is idempotent
    BEGIN
        ORDS.DEFINE_MODULE(
            p_module_name    => 'admin',
            p_base_path      => '/admin/',
            p_items_per_page => 0,
            p_status         => 'PUBLISHED',
            p_comments       => 'Protected admin endpoints. Requires ORDS First Party Auth.'
        );
    EXCEPTION
        WHEN OTHERS THEN NULL;  -- Module already exists
    END;
END;
/

-- ------------------------------------------------------------
-- Privilege: protect all /admin/ endpoints
-- ------------------------------------------------------------
DECLARE
    l_roles    OWA.VC_ARR;
    l_patterns OWA.VC_ARR;
    l_modules  OWA.VC_ARR;
BEGIN
    l_roles(1)    := 'SQL Developer';   -- ORDS built-in role
    l_patterns(1) := '/admin/*';

    ORDS.DEFINE_PRIVILEGE(
        p_privilege_name => 'admin.privilege',
        p_roles          => l_roles,
        p_patterns       => l_patterns,
        p_modules        => l_modules,
        p_label          => 'Admin',
        p_description    => 'Access to admin endpoints',
        p_comments       => NULL
    );
END;
/

-- ------------------------------------------------------------
-- POST /admin/gdpr/erase
-- Body: {"email": "address@example.com"}
-- Returns: {"status": "ok|not_found|error", "message": "..."}
-- ------------------------------------------------------------
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'admin',
        p_pattern     => 'gdpr/erase'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name   => 'admin',
        p_pattern       => 'gdpr/erase',
        p_method        => 'POST',
        p_source_type   => ORDS.SOURCE_TYPE_PLSQL,
        p_mimes_allowed => 'application/json',
        p_source        => '
DECLARE
    l_body    CLOB   := :body_text;
    l_json    JSON_OBJECT_T;
    l_email   VARCHAR2(320);
    l_status  VARCHAR2(50);
    l_message VARCHAR2(500);
BEGIN
    l_json  := JSON_OBJECT_T.PARSE(l_body);
    l_email := l_json.get_string(''email'');

    IF l_email IS NULL THEN
        HTP.p(JSON_OBJECT(''status'' VALUE ''error'',
                          ''message'' VALUE ''email is required''));
        :status_code := 400;
        RETURN;
    END IF;

    sub_gdpr.erase_subscriber(
        p_email   => l_email,
        p_status  => l_status,
        p_message => l_message
    );

    HTP.p(JSON_OBJECT(
        ''status''  VALUE l_status,
        ''message'' VALUE l_message
    ));

    :status_code := CASE l_status
        WHEN ''ok''        THEN 200
        WHEN ''not_found'' THEN 404
        ELSE                    500
    END;
END;
        '
    );
END;
/

-- ------------------------------------------------------------
-- GET /admin/gdpr/consent?email=address@example.com
-- Returns JSON consent audit record.
-- ------------------------------------------------------------
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'admin',
        p_pattern     => 'gdpr/consent'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name  => 'admin',
        p_pattern      => 'gdpr/consent',
        p_method       => 'GET',
        p_source_type  => ORDS.SOURCE_TYPE_PLSQL,
        p_source       => '
DECLARE
    l_email  VARCHAR2(320) := :email;
    l_result CLOB;
BEGIN
    IF l_email IS NULL THEN
        HTP.p(JSON_OBJECT(''error'' VALUE ''email parameter required''));
        :status_code := 400;
        RETURN;
    END IF;

    l_result := sub_gdpr.get_consent_record(l_email);
    HTP.p(l_result);
    :status_code := 200;
END;
        '
    );
END;
/

-- ------------------------------------------------------------
-- GET /admin/gdpr/export?email=address@example.com
-- Returns JSON data portability export.
-- ------------------------------------------------------------
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'admin',
        p_pattern     => 'gdpr/export'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name  => 'admin',
        p_pattern      => 'gdpr/export',
        p_method       => 'GET',
        p_source_type  => ORDS.SOURCE_TYPE_PLSQL,
        p_source       => '
DECLARE
    l_email  VARCHAR2(320) := :email;
    l_result CLOB;
BEGIN
    IF l_email IS NULL THEN
        HTP.p(JSON_OBJECT(''error'' VALUE ''email parameter required''));
        :status_code := 400;
        RETURN;
    END IF;

    l_result := sub_gdpr.export_subscriber_data(l_email);
    HTP.p(l_result);
    :status_code := 200;
END;
        '
    );
END;
/

COMMIT;
PROMPT GDPR admin endpoints published.
