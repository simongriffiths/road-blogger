whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === deploy sequences ===
@db/sequences/seq_subscribers.sql
@db/sequences/seq_newsletter_sends.sql
@db/sequences/seq_send_recipients.sql
@db/sequences/seq_link_registry.sql
@db/sequences/seq_open_events.sql
@db/sequences/seq_click_events.sql
@db/sequences/seq_rate_limit_log.sql
