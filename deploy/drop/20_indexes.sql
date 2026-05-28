whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === drop indexes ===
begin
  for i in (
    select index_name
      from user_indexes
     where index_name in (
       'UQ_SUBSCRIBERS_EMAIL',
       'UQ_SUPPRESSION_EMAIL',
       'IDX_SUBSCRIBERS_STATUS',
       'IDX_SUBSCRIBERS_CONFIRM_TOKEN',
       'IDX_SUBSCRIBERS_UNSUB_TOKEN',
       'IDX_SUBSCRIBERS_PENDING_TS',
       'IDX_RATE_LIMIT_IP_TS',
       'IDX_SR_SEND_STATUS',
       'IDX_SR_OPEN_TOKEN',
       'IDX_SR_UNSUB_TOKEN',
       'IDX_LR_TOKEN',
       'IDX_OE_SEND_ID',
       'IDX_OE_SUBSCRIBER_ID',
       'IDX_CE_SEND_ID',
       'IDX_CE_SUBSCRIBER_ID',
       'IDX_CE_LINK_ID'
     )
  ) loop
    execute immediate 'drop index ' || dbms_assert.simple_sql_name(i.index_name);
  end loop;
end;
/
