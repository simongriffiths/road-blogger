whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === drop tables ===
begin
  for t in (
    select table_name
      from user_tables
     where table_name in (
       'CLICK_EVENTS',
       'OPEN_EVENTS',
       'LINK_REGISTRY',
       'SEND_RECIPIENTS',
       'NEWSLETTER_SENDS',
       'RATE_LIMIT_LOG',
       'SUPPRESSION_LIST',
       'SUBSCRIBERS',
       'UI_ASSETS'
     )
     order by case table_name
       when 'CLICK_EVENTS' then 1
       when 'OPEN_EVENTS' then 2
       when 'LINK_REGISTRY' then 3
       when 'SEND_RECIPIENTS' then 4
       when 'NEWSLETTER_SENDS' then 5
       when 'RATE_LIMIT_LOG' then 6
       when 'SUPPRESSION_LIST' then 7
       when 'SUBSCRIBERS' then 8
       when 'UI_ASSETS' then 9
     end
  ) loop
    execute immediate 'drop table ' || dbms_assert.simple_sql_name(t.table_name) || ' cascade constraints purge';
  end loop;
end;
/
