whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === drop views ===
begin
  for v in (
    select view_name
      from user_views
     where view_name in ('V_SUBSCRIBER_GROWTH', 'V_SEND_SUMMARY', 'V_ACTIVE_SUBSCRIBERS')
  ) loop
    execute immediate 'drop view ' || dbms_assert.simple_sql_name(v.view_name);
  end loop;
end;
/
