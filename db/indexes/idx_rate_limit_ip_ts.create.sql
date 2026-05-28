create index idx_rate_limit_ip_ts
  on rate_limit_log (ip_address, attempt_ts);
