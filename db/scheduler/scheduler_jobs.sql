-- ============================================================
-- Scheduler Jobs — Subscriber Module
-- Run as schema owner.
--
-- Jobs defined:
--   JOB_PROCESS_SEND_QUEUE       every 15 minutes
--   JOB_PURGE_PENDING_SUBS       nightly 02:00 UTC
--   JOB_PURGE_RATE_LIMIT_LOG     nightly 02:15 UTC
-- ============================================================

-- ============================================================
-- Drop existing jobs if reinstalling
-- ============================================================
BEGIN
    FOR j IN (
        SELECT job_name FROM user_scheduler_jobs
        WHERE  job_name IN (
            'JOB_PROCESS_SEND_QUEUE',
            'JOB_PURGE_PENDING_SUBS',
            'JOB_PURGE_RATE_LIMIT_LOG'
        )
    ) LOOP
        DBMS_SCHEDULER.DROP_JOB(j.job_name, force => TRUE);
    END LOOP;
END;
/

-- ============================================================
-- JOB_PROCESS_SEND_QUEUE
-- Calls sub_newsletter.process_queue every 15 minutes.
-- Respects daily cap internally — safe to run frequently.
-- ============================================================
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_PROCESS_SEND_QUEUE',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN sub_newsletter.process_queue; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY;INTERVAL=15',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Processes newsletter send queue. Respects OCI 90/day email cap.'
    );
END;
/

-- ============================================================
-- JOB_PURGE_PENDING_SUBS
-- Deletes PENDING subscriber records older than 30 days.
-- GDPR data minimisation — unconfirmed addresses must not
-- be retained indefinitely.
-- Runs nightly at 02:00 UTC.
-- ============================================================
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_PURGE_PENDING_SUBS',
        job_type        => 'PLSQL_BLOCK',
        job_action      =>
'BEGIN
    DELETE FROM subscribers
    WHERE  status    = ''PENDING''
    AND    signup_ts < SYSTIMESTAMP - INTERVAL ''30'' DAY;
    COMMIT;
END;',
        start_date      => TRUNC(SYSTIMESTAMP AT TIME ZONE 'UTC') + 2/24,  -- 02:00 UTC tonight
        repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0;BYSECOND=0',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'GDPR: purge unconfirmed (PENDING) subscribers older than 30 days.'
    );
END;
/

-- ============================================================
-- JOB_PURGE_RATE_LIMIT_LOG
-- Deletes rate_limit_log records older than 24 hours.
-- Table is only used for MVP rate limiting (Issue M1-01).
-- Job kept in place for when rate limiting is implemented.
-- Runs nightly at 02:15 UTC.
-- ============================================================
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'JOB_PURGE_RATE_LIMIT_LOG',
        job_type        => 'PLSQL_BLOCK',
        job_action      =>
'BEGIN
    DELETE FROM rate_limit_log
    WHERE  attempt_ts < SYSTIMESTAMP - INTERVAL ''1'' DAY;
    COMMIT;
END;',
        start_date      => TRUNC(SYSTIMESTAMP AT TIME ZONE 'UTC') + 2/24 + 15/1440,  -- 02:15 UTC
        repeat_interval => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=15;BYSECOND=0',
        enabled         => TRUE,
        auto_drop       => FALSE,
        comments        => 'Purge rate_limit_log records older than 24 hours. See Issue M1-01.'
    );
END;
/

COMMIT;

-- ============================================================
-- Verify
-- ============================================================
SELECT job_name, enabled, state, repeat_interval
FROM   user_scheduler_jobs
WHERE  job_name IN (
    'JOB_PROCESS_SEND_QUEUE',
    'JOB_PURGE_PENDING_SUBS',
    'JOB_PURGE_RATE_LIMIT_LOG'
)
ORDER BY job_name;

PROMPT Scheduler jobs created.
