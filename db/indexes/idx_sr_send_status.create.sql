create index idx_sr_send_status
  on send_recipients (send_id, status);
