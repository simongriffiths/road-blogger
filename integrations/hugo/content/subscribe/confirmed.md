---
title: "Subscription Confirmed"
description: "Your subscription status"
layout: "subscribe-result"
---

<div id="sub-result-message"></div>

<script>
(function() {
  const params  = new URLSearchParams(window.location.search);
  const result  = params.get('result');
  const el      = document.getElementById('sub-result-message');

  const messages = {
    'ok':                '<h2>You\'re subscribed!</h2><p>Thanks for confirming. You\'ll receive the weekly newsletter every week.</p>',
    'already_confirmed': '<h2>Already confirmed</h2><p>Your subscription is already active. Look out for the weekly newsletter.</p>',
    'invalid_token':     '<h2>Invalid link</h2><p>This confirmation link is not valid or has already been used. <a href="/">Return home</a>.</p>',
    'expired':           '<h2>Link expired</h2><p>This confirmation link has expired. Please <a href="/#subscribe">subscribe again</a>.</p>',
  };

  el.innerHTML = messages[result] ||
    '<h2>Something went wrong</h2><p>Please <a href="/">return home</a> and try again.</p>';
}());
</script>
