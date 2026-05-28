# Subscriber Module — Data Model Reference
**ROAD Kit | M1 Deliverable**

---

## Entity Relationship Summary

```
SUBSCRIBERS ──────────────────────────────────────────┐
     │                                                 │
     │ (on unsubscribe/bounce/erasure)                 │
     ▼                                                 │
SUPPRESSION_LIST                                       │
                                                       │
RATE_LIMIT_LOG  (no FK — IP only)                     │
                                                       │
NEWSLETTER_SENDS ──────────────────────────────────┐  │
     │                                             │  │
     ▼                                             │  │
SEND_RECIPIENTS ◄──────────────────────────────────┘  │
     │           (send_id + subscriber_id)             │
     │◄─────────────────────────────────────────────── ┘
     │
     ├──► OPEN_EVENTS
     │
     └──► CLICK_EVENTS ◄── LINK_REGISTRY
                           (send_id + link_token)
```

---

## Tables

### SUBSCRIBERS
Core subscriber records. One row per email address in the active pipeline.

| Column | Type | Notes |
|---|---|---|
| subscriber_id | NUMBER | PK, sequence |
| email | VARCHAR2(320) | Unique (case-insensitive) |
| first_name | VARCHAR2(100) | Optional |
| status | VARCHAR2(20) | PENDING / ACTIVE / UNSUBSCRIBED / BOUNCED |
| confirm_token | VARCHAR2(64) | UUID, single-use double opt-in token |
| unsubscribe_token | VARCHAR2(64) | UUID, stable per subscriber |
| signup_ts | TIMESTAMP | GDPR consent record |
| signup_ip | VARCHAR2(45) | GDPR consent record (IPv4/IPv6) |
| signup_source_url | VARCHAR2(2000) | Page where form was submitted |
| consent_given | CHAR(1) | Constrained to 'Y' — no record without consent |
| confirm_ts | TIMESTAMP | Set when opt-in link clicked |
| confirm_ip | VARCHAR2(45) | IP at confirmation |
| unsubscribed_ts | TIMESTAMP | Set on unsubscribe |
| bounce_ts | TIMESTAMP | Set on bounce |
| bounce_type | VARCHAR2(10) | HARD / SOFT |

**Key design decisions:**
- Email uniqueness is enforced case-insensitively via a function-based unique index
- `consent_given` is constrained to 'Y' only — the CHECK constraint makes it impossible to insert a record without consent being recorded
- `confirm_token` is single-use; cleared after use to prevent replay
- `unsubscribe_token` is stable — same token works across all emails for a given subscriber, simplifying the unsubscribe link

---

### SUPPRESSION_LIST
Permanent record of addresses that must never be mailed.

| Column | Type | Notes |
|---|---|---|
| suppression_id | NUMBER | PK |
| email | VARCHAR2(320) | Normalised lowercase |
| email_hash | VARCHAR2(64) | SHA-256 hex — retained after erasure |
| reason | VARCHAR2(20) | UNSUBSCRIBED / HARD_BOUNCE / ERASURE_REQUEST / ADMIN |
| subscriber_id | NUMBER | FK → SUBSCRIBERS, nullable, cleared on erasure |
| suppressed_ts | TIMESTAMP | |
| notes | VARCHAR2(500) | Admin note |

**Key design decisions:**
- `email_hash` enables suppression checking after a GDPR erasure request removes the raw email — the hash is retained, raw email is deleted
- `subscriber_id` FK is SET NULL on delete, preserving the suppression record when the subscriber row is erased
- Separate from SUBSCRIBERS status — an address can be on the suppression list while no SUBSCRIBERS row exists (e.g. after erasure)

---

### RATE_LIMIT_LOG
Subscribe attempt log. No FK to SUBSCRIBERS — exists before a subscriber record is created.

| Column | Type | Notes |
|---|---|---|
| log_id | NUMBER | PK |
| ip_address | VARCHAR2(45) | IPv4 or IPv6 |
| attempt_ts | TIMESTAMP | |

Purged nightly by DBMS_SCHEDULER. The rate check query is:
```sql
SELECT COUNT(*) FROM rate_limit_log
WHERE ip_address = :ip
AND   attempt_ts > SYSTIMESTAMP - INTERVAL '1' HOUR
```
Max 3 attempts per IP per hour before silent discard.

---

### NEWSLETTER_SENDS
One row per newsletter send job.

| Column | Type | Notes |
|---|---|---|
| send_id | NUMBER | PK |
| subject | VARCHAR2(500) | |
| body_text | CLOB | Plain text — immutable once QUEUED |
| body_html | CLOB | Optional HTML (post-MVP) |
| status | VARCHAR2(20) | DRAFT / QUEUED / IN_PROGRESS / COMPLETE / FAILED / CANCELLED |
| total_recipients | NUMBER | Snapshot at queue time |
| sent_count | NUMBER | Incremented by scheduler |
| failed_count | NUMBER | Incremented by scheduler |
| created_ts | TIMESTAMP | |
| queued_ts | TIMESTAMP | Set when admin approves send |
| started_ts | TIMESTAMP | Set when scheduler begins |
| completed_ts | TIMESTAMP | Set when all recipients processed |

**Status lifecycle:**
```
DRAFT → QUEUED → IN_PROGRESS → COMPLETE
                             → FAILED
         ↓
      CANCELLED
```

---

### SEND_RECIPIENTS
Per-subscriber per-send dispatch record. Populated when send moves to QUEUED.

| Column | Type | Notes |
|---|---|---|
| recipient_id | NUMBER | PK |
| send_id | NUMBER | FK → NEWSLETTER_SENDS |
| subscriber_id | NUMBER | FK → SUBSCRIBERS |
| status | VARCHAR2(20) | PENDING / SENT / FAILED / SUPPRESSED |
| open_token | VARCHAR2(64) | Unique per recipient per send — in pixel URL |
| unsub_token | VARCHAR2(64) | Unique per recipient per send — in unsubscribe link |
| sent_ts | TIMESTAMP | |
| failed_ts | TIMESTAMP | |
| failure_reason | VARCHAR2(500) | |

**Note on tokens:** `open_token` and `unsub_token` here are per-send tokens, distinct from `subscribers.unsubscribe_token`. This enables:
- Per-send unsubscribe attribution (which send triggered the unsubscribe)
- Open tracking per send per recipient
- Unsubscribes from old emails continue to work even after a new send

---

### LINK_REGISTRY
Registry of original URLs rewritten for click tracking. One row per unique URL per send.

| Column | Type | Notes |
|---|---|---|
| link_id | NUMBER | PK |
| send_id | NUMBER | FK → NEWSLETTER_SENDS |
| link_token | VARCHAR2(32) | Short random token in rewritten URL |
| original_url | VARCHAR2(4000) | Destination after redirect |
| link_label | VARCHAR2(200) | Human-readable label for analytics |

---

### OPEN_EVENTS
Pixel load events. Directional metric only.

| Column | Type | Notes |
|---|---|---|
| open_id | NUMBER | PK |
| recipient_id | NUMBER | FK → SEND_RECIPIENTS |
| send_id | NUMBER | Denormalised |
| subscriber_id | NUMBER | Denormalised |
| opened_ts | TIMESTAMP | |
| user_agent | VARCHAR2(1000) | |
| ip_address | VARCHAR2(45) | |

---

### CLICK_EVENTS
Link click events. Primary engagement metric.

| Column | Type | Notes |
|---|---|---|
| click_id | NUMBER | PK |
| recipient_id | NUMBER | FK → SEND_RECIPIENTS |
| link_id | NUMBER | FK → LINK_REGISTRY |
| send_id | NUMBER | Denormalised |
| subscriber_id | NUMBER | Denormalised |
| clicked_ts | TIMESTAMP | |
| user_agent | VARCHAR2(1000) | |
| ip_address | VARCHAR2(45) | |

---

## Views

| View | Purpose |
|---|---|
| V_ACTIVE_SUBSCRIBERS | Active subscribers eligible for sends |
| V_SEND_SUMMARY | Per-send analytics rollup (opens, clicks, unsubscribes, rates) |
| V_SUBSCRIBER_GROWTH | Active subscriber count at each send date — growth chart data |

---

## Scheduled Jobs (DBMS_SCHEDULER)

| Job | Frequency | Purpose |
|---|---|---|
| JOB_PURGE_PENDING_SUBSCRIBERS | Nightly | Delete PENDING records older than 30 days |
| JOB_PURGE_RATE_LIMIT_LOG | Nightly | Delete rate_limit_log records older than 24 hours |
| JOB_PROCESS_SEND_QUEUE | Every 15 min | Dispatch up to N emails from QUEUED sends (daily cap: 90) |

---

## GDPR Notes

The schema satisfies the following GDPR obligations:

| Obligation | Implementation |
|---|---|
| Proof of consent | signup_ts, signup_ip, signup_source_url, consent_given on SUBSCRIBERS |
| Double opt-in audit | confirm_ts, confirm_ip on SUBSCRIBERS |
| Right to unsubscribe | unsubscribed_ts; SUPPRESSION_LIST entry created |
| Right to erasure | SUBSCRIBERS row deleted; email_hash retained on SUPPRESSION_LIST |
| Data minimisation | PENDING records auto-purged after 30 days |
| Portability | V_ACTIVE_SUBSCRIBERS exportable as CSV from admin UI |
