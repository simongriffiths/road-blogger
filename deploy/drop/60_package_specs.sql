whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === drop package specs ===
begin
  for p in (
    select object_name
      from user_objects
     where object_type = 'PACKAGE'
       and object_name in ('SUB_GDPR', 'SUB_NEWSLETTER', 'SUB_EMAIL', 'SUB_API', 'UI_ASSETS_API')
  ) loop
    execute immediate 'drop package ' || dbms_assert.simple_sql_name(p.object_name);
  end loop;
end;
/
