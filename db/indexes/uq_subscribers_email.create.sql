create unique index uq_subscribers_email
  on subscribers (lower(email));
