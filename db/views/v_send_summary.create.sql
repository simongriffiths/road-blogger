create or replace view v_send_summary as
select ns.send_id,
       ns.subject,
       ns.status,
       ns.total_recipients,
       ns.sent_count,
       ns.failed_count,
       ns.queued_ts,
       ns.completed_ts,
       count(distinct oe.recipient_id) as unique_opens,
       count(oe.open_id) as total_opens,
       count(distinct ce.recipient_id) as unique_clickers,
       count(ce.click_id) as total_clicks,
       count(
         distinct case
                    when sr.status = 'SENT'
                     and sub.status in ('UNSUBSCRIBED', 'BOUNCED')
                     and sub.unsubscribed_ts >= ns.queued_ts
                    then sr.subscriber_id
                  end
       ) as unsubscribes,
       case
         when ns.sent_count > 0 then
           round(count(distinct oe.recipient_id) * 100 / ns.sent_count, 1)
         else 0
       end as open_rate_pct,
       case
         when ns.sent_count > 0 then
           round(count(distinct ce.recipient_id) * 100 / ns.sent_count, 1)
         else 0
       end as click_rate_pct
  from newsletter_sends ns
  left join send_recipients sr
    on sr.send_id = ns.send_id
  left join subscribers sub
    on sub.subscriber_id = sr.subscriber_id
  left join open_events oe
    on oe.send_id = ns.send_id
  left join click_events ce
    on ce.send_id = ns.send_id
 group by ns.send_id,
          ns.subject,
          ns.status,
          ns.total_recipients,
          ns.sent_count,
          ns.failed_count,
          ns.queued_ts,
          ns.completed_ts;
