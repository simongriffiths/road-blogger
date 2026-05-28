whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === deploy indexes ===
@db/indexes/uq_subscribers_email.create.sql
@db/indexes/uq_suppression_email.create.sql
@db/indexes/idx_subscribers_status.create.sql
@db/indexes/idx_subscribers_confirm_token.create.sql
@db/indexes/idx_subscribers_unsub_token.create.sql
@db/indexes/idx_subscribers_pending_ts.create.sql
@db/indexes/idx_rate_limit_ip_ts.create.sql
@db/indexes/idx_sr_send_status.create.sql
@db/indexes/idx_sr_open_token.create.sql
@db/indexes/idx_sr_unsub_token.create.sql
@db/indexes/idx_lr_token.create.sql
@db/indexes/idx_oe_send_id.create.sql
@db/indexes/idx_oe_subscriber_id.create.sql
@db/indexes/idx_ce_send_id.create.sql
@db/indexes/idx_ce_subscriber_id.create.sql
@db/indexes/idx_ce_link_id.create.sql
