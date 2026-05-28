# Subscriber Module — Hardening & Go-Live Checklist
**M7 / M8 | ROAD Kit**

Work through this list in order before switching DNS for simongriffiths.io.

---

## M7 — Hardening

### Schema & Packages

- [ ] Run `install.sql` on a clean schema — no errors
- [ ] Run `drop.sql` then `install.sql` again — confirms rerunnable
- [ ] All packages compile without errors:
  ```sql
  SELECT object_name, status FROM user_objects
  WHERE object_type = 'PACKAGE BODY'
  AND   object_name IN ('SUB_API','SUB_EMAIL','SUB_NEWSLETTER','SUB_GDPR')
  ORDER BY object_name;
  ```
  All should show `VALID`.

### Test Script

- [ ] Run `tests/test_subscriber_module.sql` — all 15 tests pass
- [ ] If any fail, resolve before proceeding

### ORDS Endpoints

- [ ] Verify ORDS modules published:
  ```sql
  SELECT name, status FROM user_ords_modules
  ORDER BY name;
  ```
  Expected: `admin`, `subscriber`, `tracker` — all `PUBLISHED`.

- [ ] Test subscribe endpoint manually (curl or browser fetch):
  ```bash
  curl -X POST https://[YOUR_ORDS_URL]/ords/[SCHEMA]/subscriber/subscribe \
    -H "Content-Type: application/json" \
    -d '{"email":"test@yourdomain.com","first_name":"Test","website":""}'
  ```
  Expected: `{"status":"ok","message":"Check your inbox..."}`

- [ ] Test honeypot (website field populated) — returns ok, no DB record created
- [ ] Test confirm endpoint with valid token from DB
- [ ] Test unsubscribe endpoint with valid token from DB
- [ ] Test tracking pixel returns 1x1 GIF (check Content-Type: image/gif)
- [ ] Test click redirect returns 302 to correct URL

### Scheduler Jobs

- [ ] Verify jobs created and enabled:
  ```sql
  SELECT job_name, enabled, state
  FROM   user_scheduler_jobs
  WHERE  job_name IN ('JOB_PROCESS_SEND_QUEUE',
                      'JOB_PURGE_PENDING_SUBS',
                      'JOB_PURGE_RATE_LIMIT_LOG');
  ```

- [ ] Manually trigger queue job to confirm it runs without error:
  ```sql
  BEGIN DBMS_SCHEDULER.RUN_JOB('JOB_PROCESS_SEND_QUEUE'); END;
  /
  ```

- [ ] Check scheduler job log for errors:
  ```sql
  SELECT job_name, status, error#, req_start_date
  FROM   user_scheduler_job_run_details
  WHERE  job_name IN ('JOB_PROCESS_SEND_QUEUE',
                      'JOB_PURGE_PENDING_SUBS',
                      'JOB_PURGE_RATE_LIMIT_LOG')
  ORDER BY req_start_date DESC
  FETCH FIRST 10 ROWS ONLY;
  ```

### Email Delivery

- [ ] OCI Email Delivery enabled in tenancy home region
- [ ] Approved sender address configured in OCI console
- [ ] SPF record added to sending domain DNS
- [ ] DKIM record added to sending domain DNS
- [ ] DMARC record added to sending domain DNS (recommended)
- [ ] ACL grant confirmed (`oci_email_prereqs.sql` run as ADMIN)
- [ ] `OCI_SMTP` credential object created
- [ ] Send a test confirmation email manually:
  ```sql
  -- Insert a test PENDING subscriber directly, then:
  BEGIN sub_email.send_confirmation([subscriber_id]); END;
  /
  ```
- [ ] Confirm email received, links work, unsubscribe link functions
- [ ] Check branded HTML renders correctly in:
  - [ ] Gmail (web)
  - [ ] Apple Mail
  - [ ] Outlook (if relevant)
  - [ ] Mobile (iOS Mail or Gmail app)

### Hugo Integration

- [ ] Subscribe form partial included in at least one Hugo layout
- [ ] `subscribe.js` present in `static/js/`
- [ ] ORDS endpoint URL in `subscribe.js` matches deployed schema path
- [ ] Form submits successfully on deployed site
- [ ] Success message displays inline (no page redirect)
- [ ] `/subscribe/confirmed` page renders correctly for all `?result=` values
- [ ] `/subscribe/unsubscribed` page renders correctly for all `?result=` values
- [ ] `/privacy` page published and accessible
- [ ] Privacy policy placeholders all replaced:
  - [ ] `[SITE_NAME]`
  - [ ] `[YOUR FULL NAME]`
  - [ ] `[CONTACT_EMAIL]`
  - [ ] `[DATE]`

### Security

- [ ] Admin endpoints return 401 when accessed without authentication
- [ ] Public endpoints (`/subscriber/*`, `/tracker/*`) accessible without auth
- [ ] Honeypot verified working (manual test above)
- [ ] Suppression list check verified — suppressed email returns ok, no record created

### GDPR

- [ ] Erasure flow tested end-to-end (manual or via test script)
- [ ] Consent record query returns expected fields
- [ ] Privacy policy live and linked from subscribe form
- [ ] Unsubscribe link present in all outbound emails

---

## M8 — Go-Live

### New Domain (Proof-of-Concept)

- [ ] Domain registered and pointed at ADB/Cloudflare
- [ ] Hugo site built and uploaded to ADB
- [ ] Site accessible via new domain
- [ ] HTTPS certificate provisioned (Cloudflare handles this)
- [ ] Subscribe form working end-to-end on new domain
- [ ] Send a real confirmation email to yourself and complete the flow
- [ ] Send first newsletter to yourself as sole subscriber

### Pre-Migration Checks (before switching simongriffiths.io)

- [ ] New site has been running without issues for at least [N] weeks
- [ ] At least one real newsletter sent successfully
- [ ] All Hugo content migrated and checked
- [ ] Existing subscribers exported from current platform (JetPack/WordPress)
- [ ] Existing subscribers imported into SUBSCRIBERS table:
  - Status: `ACTIVE` (they have previously consented)
  - consent_given: `Y`
  - signup_source_url: `migrated from WordPress/JetPack`
  - confirm_ts: migration date
  - Note: consider sending a re-permission email depending on original consent basis
- [ ] OCI Email Delivery approved sender updated to simongriffiths.io address
- [ ] SPF/DKIM/DMARC DNS records updated for simongriffiths.io
- [ ] Cloudflare DNS updated: simongriffiths.io → new ADB endpoint
- [ ] TTL lowered on simongriffiths.io DNS before cutover (allows faster rollback)
- [ ] Old WordPress site kept live for [N] days post-migration as fallback

### Post-Migration

- [ ] simongriffiths.io resolves to new site
- [ ] All existing URLs return correct content (check redirects if URL structure changed)
- [ ] Subscribe form working on simongriffiths.io
- [ ] Send first newsletter from simongriffiths.io to full subscriber list
- [ ] Monitor OCI Email Delivery console for bounces/rejections in first 48 hours
- [ ] Confirm open and click events appearing in DB
- [ ] Lower daily send cap temporarily if bounce rate is high (protects sender reputation)

---

## Known Issues

| ID | Description | Resolution |
|---|---|---|
| M1-01 | `RATE_LIMIT_LOG` table provisioned but not used. Honeypot is sole spam protection for MVP. | Implement IP or email-based rate limiting if abuse observed post-launch. |

---

## Useful Verification Queries

```sql
-- Active subscriber count
SELECT COUNT(*) FROM v_active_subscribers;

-- Pending subscribers (awaiting confirmation)
SELECT email, signup_ts FROM subscribers WHERE status = 'PENDING' ORDER BY signup_ts;

-- Suppression list
SELECT email, reason, suppressed_ts FROM suppression_list ORDER BY suppressed_ts DESC;

-- Send queue status
SELECT send_id, subject, status, total_recipients, sent_count, failed_count
FROM   newsletter_sends ORDER BY created_ts DESC;

-- Today's email send count
SELECT COUNT(*) AS sent_today
FROM   send_recipients
WHERE  status  = 'SENT'
AND    sent_ts >= TRUNC(SYSTIMESTAMP AT TIME ZONE 'UTC');

-- Recent scheduler job runs
SELECT job_name, status, error#, TO_CHAR(req_start_date,'DD-MON HH24:MI') AS run_time
FROM   user_scheduler_job_run_details
ORDER BY req_start_date DESC
FETCH FIRST 20 ROWS ONLY;

-- Packages compilation status
SELECT object_name, status, last_ddl_time
FROM   user_objects
WHERE  object_type IN ('PACKAGE','PACKAGE BODY')
ORDER BY object_name;
```
