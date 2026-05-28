create or replace view v_subscriber_growth as
select ns.send_id,
       ns.subject,
       trunc(ns.queued_ts) as send_date,
       (
         select count(*)
           from subscribers s
          where s.status = 'ACTIVE'
            and s.confirm_ts <= ns.queued_ts
       ) as active_subscribers
  from newsletter_sends ns
 where ns.status = 'COMPLETE';
