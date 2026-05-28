create index idx_subscribers_pending_ts
  on subscribers (status, signup_ts);
