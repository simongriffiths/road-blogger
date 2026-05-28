# ROAD Blogger Next Steps

## First Validation Pass

1. Move `road-blogger` to its own repository.
2. Review `road.config` and decide whether `API_BASE_PATH=blog` is the right final ORDS base path.
3. Run the drop/create deploy flow against a disposable `dev` schema.
4. Fix compile and ORDS publication errors before adding new features.
5. Run `test/contract/subscriber_module.sql`.
6. Deploy the `blog_admin` placeholder through `bin/deploy-react.sh`.
7. Run endpoint tests and convert failures into focused fixes.

## Known Work

- Replace hardcoded domain values in `sub_email` and `sub_newsletter` with configuration stored in tables or install-time parameters.
- Review suppression-list erasure semantics. The imported draft stores `[erased]` as the raw email after GDPR erasure, so uniqueness and future suppression checks need a deliberate hash-first design.
- Review scheduler creation. The imported scheduler jobs are enabled immediately on deploy; that may be too aggressive before SMTP and configuration are verified.
- Decide whether admin auth will use ORDS first-party auth, JWT, or a narrower dev/test scaffold.
- Design the full admin API before building the React admin UI.
- Add `newsletter_templates` and template upload flow.
- Add admin endpoints for dashboard, subscriber list, delete/erase, templates, queue send, and send history.
- Revisit SMTP transaction handling so subscription insert and email delivery failure states are observable.
- Add a real pipeline script after the first manual deploy path is stable.

## Backport Candidates To ROAD

- Generic ORDS UI module generation
- More flexible `deploy-react.sh` app directory support
- Endpoint-test runner with optional auth
- Database-backed app configuration conventions
- Admin-first app scaffold conventions
