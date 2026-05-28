create unique index uq_suppression_email
  on suppression_list (lower(email));
