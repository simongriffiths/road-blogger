-- ============================================================
-- Package Body: SUB_EMAIL
-- ============================================================
CREATE OR REPLACE PACKAGE BODY sub_email AS

    -- --------------------------------------------------------
    -- RENDER_EMAIL_WRAPPER
    -- Wraps content in the branded email shell.
    -- Single-column, inline styles, no images.
    -- Palette from simongriffiths.io CSS variables.
    -- --------------------------------------------------------
    FUNCTION render_email_wrapper (
        p_content     IN CLOB,
        p_preheader   IN VARCHAR2 DEFAULT NULL
    ) RETURN CLOB IS
        l_html CLOB;
    BEGIN
        l_html :=
'<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Simon Griffiths</title>
</head>
<body style="margin:0;padding:0;background-color:#efe9de;font-family:ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,''Segoe UI'',sans-serif;">

  <!--[if mso]><table width="600" align="center" cellpadding="0" cellspacing="0"><tr><td><![endif]-->

  <!-- Preheader (hidden preview text) -->';

        IF p_preheader IS NOT NULL THEN
            l_html := l_html ||
'  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">'
|| p_preheader ||
'</div>';
        END IF;

        l_html := l_html ||
'
  <!-- Outer wrapper -->
  <table width="100%" cellpadding="0" cellspacing="0" border="0"
         style="background-color:#efe9de;padding:32px 16px;">
    <tr>
      <td align="center">

        <!-- Email container -->
        <table width="600" cellpadding="0" cellspacing="0" border="0"
               style="max-width:600px;width:100%;background-color:#f4f1ea;
                      border:1px solid #d8d2c7;">

          <!-- Header -->
          <tr>
            <td style="background-color:#2a3a33;padding:24px 32px;">
              <p style="margin:0;font-family:ui-serif,Georgia,Cambria,''Times New Roman'',serif;
                        font-size:20px;font-weight:normal;color:#f4f1ea;letter-spacing:0.02em;">
                Simon Griffiths
              </p>
              <p style="margin:4px 0 0;font-size:12px;color:#8a847a;letter-spacing:0.05em;
                        text-transform:uppercase;">
                Notes on technology &amp; practice
              </p>
            </td>
          </tr>

          <!-- Body content -->
          <tr>
            <td style="padding:32px 32px 24px;">
' || p_content || '
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:16px 32px 32px;border-top:1px solid #d8d2c7;">
              <p style="margin:0;font-size:12px;color:#8a847a;line-height:1.6;">
                You are receiving this because you subscribed at
                <a href="' || BLOG_BASE_URL || '"
                   style="color:#8c6a43;text-decoration:none;">'
                || BLOG_BASE_URL || '</a>.
              </p>
            </td>
          </tr>

        </table>
        <!-- /Email container -->

      </td>
    </tr>
  </table>

  <!--[if mso]></td></tr></table><![endif]-->

</body>
</html>';

        RETURN l_html;
    END render_email_wrapper;

    -- --------------------------------------------------------
    -- RENDER_BUTTON
    -- Bulletproof button — works in Outlook via VML fallback.
    -- --------------------------------------------------------
    FUNCTION render_button (
        p_url   IN VARCHAR2,
        p_label IN VARCHAR2
    ) RETURN VARCHAR2 IS
    BEGIN
        RETURN
'<table cellpadding="0" cellspacing="0" border="0" style="margin:24px 0;">
  <tr>
    <td align="center" bgcolor="#8c6a43"
        style="border-radius:3px;">
      <!--[if mso]>
      <v:roundrect xmlns:v="urn:schemas-microsoft-com:vml"
                   href="' || p_url || '"
                   style="height:44px;v-text-anchor:middle;width:220px;"
                   arcsize="7%" stroke="f" fillcolor="#8c6a43">
        <w:anchorlock/>
        <center style="color:#f4f1ea;font-family:sans-serif;
                       font-size:15px;font-weight:bold;">'
                       || p_label ||
                      '</center>
      </v:roundrect>
      <![endif]-->
      <!--[if !mso]><!-->
      <a href="' || p_url || '"
         style="display:inline-block;padding:12px 28px;
                background-color:#8c6a43;color:#f4f1ea;
                font-size:15px;font-weight:600;text-decoration:none;
                border-radius:3px;font-family:ui-sans-serif,system-ui,sans-serif;">
        ' || p_label || '
      </a>
      <!--<![endif]-->
    </td>
  </tr>
</table>';
    END render_button;

    -- --------------------------------------------------------
    -- SEND_EMAIL
    -- Core UTL_SMTP send function.
    -- Sends multipart/alternative (HTML + plain text fallback).
    -- --------------------------------------------------------
    FUNCTION send_email (
        p_to_address  IN VARCHAR2,
        p_to_name     IN VARCHAR2,
        p_subject     IN VARCHAR2,
        p_body_html   IN CLOB,
        p_body_text   IN CLOB DEFAULT NULL
    ) RETURN BOOLEAN IS

        l_conn        UTL_SMTP.CONNECTION;
        l_boundary    VARCHAR2(50) := 'BOUNDARY_' || REPLACE(SYS_GUID(), '-', '');
        l_date        VARCHAR2(100);
        l_to_header   VARCHAR2(500);
        l_text_body   CLOB;

        -- Write CLOB to SMTP connection in chunks
        PROCEDURE write_clob (p_conn IN OUT UTL_SMTP.CONNECTION,
                               p_clob IN CLOB) IS
            l_offset  PLS_INTEGER := 1;
            l_chunk   VARCHAR2(32767);
            l_len     PLS_INTEGER := DBMS_LOB.GETLENGTH(p_clob);
            l_read    PLS_INTEGER := 8000;
        BEGIN
            WHILE l_offset <= l_len LOOP
                l_chunk  := DBMS_LOB.SUBSTR(p_clob, l_read, l_offset);
                UTL_SMTP.WRITE_DATA(p_conn, l_chunk);
                l_offset := l_offset + LENGTH(l_chunk);
            END LOOP;
        END write_clob;

    BEGIN
        -- Build plain text fallback if not provided
        -- Strip HTML tags crudely — good enough for fallback
        l_text_body := NVL(
            p_body_text,
            REGEXP_REPLACE(p_body_html, '<[^>]+>', '')
        );

        l_date      := TO_CHAR(SYSTIMESTAMP AT TIME ZONE 'UTC',
                               'Dy, DD Mon YYYY HH24:MI:SS "GMT"', 'NLS_DATE_LANGUAGE=ENGLISH');
        l_to_header := CASE
                           WHEN p_to_name IS NOT NULL
                           THEN '"' || p_to_name || '" <' || p_to_address || '>'
                           ELSE p_to_address
                       END;

        -- Open SMTP connection via OCI Email Delivery
        l_conn := UTL_SMTP.OPEN_CONNECTION(
                      host       => SMTP_HOST,
                      port       => SMTP_PORT,
                      wallet_path => NULL   -- OCI managed TLS
                  );

        UTL_SMTP.EHLO(l_conn, SMTP_HOST);

        -- STARTTLS
        UTL_SMTP.STARTTLS(l_conn);
        UTL_SMTP.EHLO(l_conn, SMTP_HOST);

        -- Authenticate using credential object
        UTL_SMTP.AUTH(
            c          => l_conn,
            username   => DBMS_CREDENTIAL.GET_USERNAME(SMTP_CRED),
            password   => DBMS_CREDENTIAL.GET_PASSWORD(SMTP_CRED),
            schemes    => 'LOGIN'
        );

        -- Envelope
        UTL_SMTP.MAIL(l_conn, FROM_ADDRESS);
        UTL_SMTP.RCPT(l_conn, p_to_address);

        -- Headers + multipart body
        UTL_SMTP.OPEN_DATA(l_conn);
        UTL_SMTP.WRITE_DATA(l_conn,
            'Date: '    || l_date           || UTL_TCP.CRLF ||
            'From: "'   || FROM_NAME || '" <' || FROM_ADDRESS || '>' || UTL_TCP.CRLF ||
            'To: '      || l_to_header      || UTL_TCP.CRLF ||
            'Subject: ' || p_subject        || UTL_TCP.CRLF ||
            'MIME-Version: 1.0'             || UTL_TCP.CRLF ||
            'Content-Type: multipart/alternative; boundary="' || l_boundary || '"' || UTL_TCP.CRLF ||
            'X-Mailer: simongriffiths.io/sub_email' || UTL_TCP.CRLF ||
            UTL_TCP.CRLF
        );

        -- Plain text part
        UTL_SMTP.WRITE_DATA(l_conn,
            '--' || l_boundary || UTL_TCP.CRLF ||
            'Content-Type: text/plain; charset=UTF-8' || UTL_TCP.CRLF ||
            'Content-Transfer-Encoding: quoted-printable' || UTL_TCP.CRLF ||
            UTL_TCP.CRLF
        );
        write_clob(l_conn, l_text_body);
        UTL_SMTP.WRITE_DATA(l_conn, UTL_TCP.CRLF);

        -- HTML part
        UTL_SMTP.WRITE_DATA(l_conn,
            '--' || l_boundary || UTL_TCP.CRLF ||
            'Content-Type: text/html; charset=UTF-8' || UTL_TCP.CRLF ||
            'Content-Transfer-Encoding: quoted-printable' || UTL_TCP.CRLF ||
            UTL_TCP.CRLF
        );
        write_clob(l_conn, p_body_html);
        UTL_SMTP.WRITE_DATA(l_conn, UTL_TCP.CRLF);

        -- Close boundary
        UTL_SMTP.WRITE_DATA(l_conn, '--' || l_boundary || '--' || UTL_TCP.CRLF);
        UTL_SMTP.CLOSE_DATA(l_conn);
        UTL_SMTP.QUIT(l_conn);

        RETURN TRUE;

    EXCEPTION
        WHEN UTL_SMTP.TRANSIENT_ERROR OR UTL_SMTP.PERMANENT_ERROR THEN
            BEGIN UTL_SMTP.QUIT(l_conn); EXCEPTION WHEN OTHERS THEN NULL; END;
            RETURN FALSE;
        WHEN OTHERS THEN
            BEGIN UTL_SMTP.QUIT(l_conn); EXCEPTION WHEN OTHERS THEN NULL; END;
            RETURN FALSE;
    END send_email;

    -- --------------------------------------------------------
    -- SEND_CONFIRMATION
    -- Double opt-in confirmation email.
    -- --------------------------------------------------------
    PROCEDURE send_confirmation (
        p_subscriber_id IN NUMBER
    ) IS
        l_email       VARCHAR2(320);
        l_name        VARCHAR2(100);
        l_token       VARCHAR2(64);
        l_confirm_url VARCHAR2(500);
        l_content     CLOB;
        l_html        CLOB;
        l_ok          BOOLEAN;
        l_greeting    VARCHAR2(200);
    BEGIN
        SELECT email, first_name, confirm_token
        INTO   l_email, l_name, l_token
        FROM   subscribers
        WHERE  subscriber_id = p_subscriber_id
        AND    status        = 'PENDING';

        l_confirm_url := BLOG_BASE_URL
                      || '/ords/blog/subscriber/confirm?token='
                      || l_token;

        l_greeting := CASE
                          WHEN l_name IS NOT NULL
                          THEN 'Hi ' || l_name || ','
                          ELSE 'Hello,'
                      END;

        l_content :=
'<p style="margin:0 0 16px;font-size:16px;line-height:1.7;color:#222222;">'
|| l_greeting || '</p>

<p style="margin:0 0 16px;font-size:16px;line-height:1.7;color:#222222;">
  Thanks for subscribing to my weekly newsletter — notes on technology,
  practice, and building things that matter.
</p>

<p style="margin:0 0 8px;font-size:16px;line-height:1.7;color:#222222;">
  Please confirm your subscription by clicking the button below.
  The link expires in 30 days.
</p>'
|| render_button(l_confirm_url, 'Confirm subscription') ||
'<p style="margin:16px 0 0;font-size:13px;line-height:1.6;color:#8a847a;">
  If the button does not work, copy and paste this link into your browser:<br>
  <a href="' || l_confirm_url || '"
     style="color:#8c6a43;word-break:break-all;">'
  || l_confirm_url || '</a>
</p>

<p style="margin:24px 0 0;font-size:13px;line-height:1.6;color:#8a847a;">
  If you did not subscribe, you can ignore this email.
  You will not receive anything further.
</p>';

        l_html := render_email_wrapper(
            p_content   => l_content,
            p_preheader => 'Please confirm your subscription to Simon Griffiths.'
        );

        l_ok := send_email(
            p_to_address => l_email,
            p_to_name    => l_name,
            p_subject    => 'Please confirm your subscription',
            p_body_html  => l_html
        );

        IF NOT l_ok THEN
            -- Log failure — don't raise, caller should not fail on email error
            DBMS_OUTPUT.PUT_LINE('sub_email.send_confirmation: failed for subscriber_id=' || p_subscriber_id);
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;  -- subscriber not found or not PENDING
        WHEN OTHERS THEN NULL;         -- never propagate email errors
    END send_confirmation;

    -- --------------------------------------------------------
    -- SEND_UNSUBSCRIBE_ACK
    -- Brief acknowledgement after unsubscribe.
    -- --------------------------------------------------------
    PROCEDURE send_unsubscribe_ack (
        p_subscriber_id IN NUMBER
    ) IS
        l_email   VARCHAR2(320);
        l_name    VARCHAR2(100);
        l_content CLOB;
        l_html    CLOB;
        l_ok      BOOLEAN;
        l_greeting VARCHAR2(200);
    BEGIN
        SELECT email, first_name
        INTO   l_email, l_name
        FROM   subscribers
        WHERE  subscriber_id = p_subscriber_id;

        l_greeting := CASE
                          WHEN l_name IS NOT NULL
                          THEN 'Hi ' || l_name || ','
                          ELSE 'Hello,'
                      END;

        l_content :=
'<p style="margin:0 0 16px;font-size:16px;line-height:1.7;color:#222222;">'
|| l_greeting || '</p>

<p style="margin:0 0 16px;font-size:16px;line-height:1.7;color:#222222;">
  You have been unsubscribed and will not receive any further emails.
</p>

<p style="margin:0;font-size:16px;line-height:1.7;color:#222222;">
  If you change your mind, you are always welcome to
  <a href="' || BLOG_BASE_URL || '/#subscribe"
     style="color:#8c6a43;text-decoration:none;">subscribe again</a>.
</p>';

        l_html := render_email_wrapper(
            p_content   => l_content,
            p_preheader => 'You have been unsubscribed.'
        );

        l_ok := send_email(
            p_to_address => l_email,
            p_to_name    => l_name,
            p_subject    => 'You have been unsubscribed',
            p_body_html  => l_html
        );

    EXCEPTION
        WHEN OTHERS THEN NULL;
    END send_unsubscribe_ack;

END sub_email;
/
