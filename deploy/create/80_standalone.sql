whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === deploy standalone database objects ===
@db/scheduler/scheduler_jobs.sql
