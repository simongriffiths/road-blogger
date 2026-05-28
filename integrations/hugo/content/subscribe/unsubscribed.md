---
title: "Unsubscribed"
description: "You have been unsubscribed"
layout: "subscribe-result"
---

<div id="unsub-result-message"></div>

<script>
(function() {
  const params  = new URLSearchParams(window.location.search);
  const result  = params.get('result');
  const el      = document.getElementById('unsub-result-message');

  const messages = {
    'ok':                  '<h2>Unsubscribed</h2><p>You\'ve been removed from the mailing list. You won\'t receive any further emails.</p>',
    'already_unsubscribed':'<h2>Already unsubscribed</h2><p>You\'re not currently subscribed.</p>',
    'invalid_token':       '<h2>Invalid link</h2><p>This unsubscribe link is not valid. <a href="/">Return home</a>.</p>',
  };

  el.innerHTML = messages[result] ||
    '<h2>Something went wrong</h2><p>Please <a href="/">return home</a>.</p>';
}());
</script>
