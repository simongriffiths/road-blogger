whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === deploy views ===
@db/views/v_active_subscribers.create.sql
@db/views/v_send_summary.create.sql
@db/views/v_subscriber_growth.create.sql
