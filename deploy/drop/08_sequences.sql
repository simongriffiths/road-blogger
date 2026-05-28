whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === drop sequences ===
begin
  for s in (
    select sequence_name
      from user_sequences
     where sequence_name in (
       'SEQ_CLICK_EVENTS',
       'SEQ_OPEN_EVENTS',
       'SEQ_LINK_REGISTRY',
       'SEQ_SEND_RECIPIENTS',
       'SEQ_NEWSLETTER_SENDS',
       'SEQ_RATE_LIMIT_LOG',
       'SEQ_SUBSCRIBERS'
     )
  ) loop
    execute immediate 'drop sequence ' || dbms_assert.simple_sql_name(s.sequence_name);
  end loop;
end;
/
