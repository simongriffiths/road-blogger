whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === drop standalone database objects ===
begin
  for j in (
    select job_name
      from user_scheduler_jobs
     where job_name in (
       'JOB_PROCESS_SEND_QUEUE',
       'JOB_PURGE_PENDING_SUBS',
       'JOB_PURGE_RATE_LIMIT_LOG'
     )
  ) loop
    dbms_scheduler.drop_job(j.job_name, force => true);
  end loop;
end;
/
