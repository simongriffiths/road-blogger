whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === verify ROAD Blogger deployment ===
select count(*) as subscriber_count from subscribers;
select object_name, status
  from user_objects
 where object_name in ('SUB_API', 'SUB_EMAIL', 'SUB_NEWSLETTER', 'SUB_GDPR')
 order by object_name;
