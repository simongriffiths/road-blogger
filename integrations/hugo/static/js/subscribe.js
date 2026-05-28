/**
 * subscribe.js
 * Handles the subscribe form submission.
 * Relative URL — same-origin, no CORS required.
 */
(function () {
  'use strict';

  const ORDS_ENDPOINT = '/ords/blog/subscriber/subscribe';

  const form     = document.getElementById('subscribe-form');
  const status   = document.getElementById('sub-status');
  const submit   = document.getElementById('sub-submit');

  if (!form) return;  // Guard — partial may not be on every page

  function setStatus(message, type) {
    // type: 'success' | 'error' | 'loading'
    status.textContent  = message;
    status.className    = 'sub-status sub-status--' + type;
  }

  function setLoading(loading) {
    submit.disabled    = loading;
    submit.textContent = loading ? 'Subscribing...' : 'Subscribe';
  }

  form.addEventListener('submit', async function (e) {
    e.preventDefault();

    const email    = document.getElementById('sub-email').value.trim();
    const name     = document.getElementById('sub-name').value.trim();
    const honeypot = document.getElementById('sub-website').value;
    const consent  = document.getElementById('sub-consent').checked;

    // Client-side validation
    if (!email) {
      setStatus('Please enter your email address.', 'error');
      return;
    }
    if (!consent) {
      setStatus('Please confirm you agree to receive emails.', 'error');
      return;
    }

    setLoading(true);
    setStatus('', '');

    try {
      const response = await fetch(ORDS_ENDPOINT, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify({
          email:      email,
          first_name: name,
          website:    honeypot   // honeypot — bots populate this
        })
      });

      const data = await response.json();

      if (response.ok && data.status === 'ok') {
        // Hide form, show success message
        form.style.display = 'none';
        setStatus(
          data.message || 'Check your inbox to confirm your subscription.',
          'success'
        );
      } else if (data.status === 'invalid_email') {
        setStatus('Please enter a valid email address.', 'error');
      } else {
        setStatus(
          data.message || 'Something went wrong. Please try again.',
          'error'
        );
      }

    } catch (err) {
      setStatus('Could not connect. Please try again.', 'error');
      console.error('Subscribe error:', err);
    } finally {
      setLoading(false);
    }
  });

}());
