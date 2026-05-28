whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === deploy tables ===
@db/tables/ui_assets.create.sql
@db/tables/subscribers.sql
@db/tables/suppression_list.sql
@db/tables/rate_limit_log.sql
@db/tables/newsletter_sends.sql
@db/tables/send_recipients.sql
@db/tables/link_registry.sql
@db/tables/open_events.sql
@db/tables/click_events.sql
