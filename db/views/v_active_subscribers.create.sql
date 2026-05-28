create or replace view v_active_subscribers as
select s.subscriber_id,
       s.email,
       s.first_name,
       s.confirm_ts,
       s.signup_source_url,
       s.unsubscribe_token
  from subscribers s
 where s.status = 'ACTIVE';
