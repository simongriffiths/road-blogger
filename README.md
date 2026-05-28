# ROAD Blogger

ROAD Blogger is a starter application repo extracted from the ROAD framework work.

It is intended to be moved out into its own Git repository. This folder contains:

- ROAD-style SQL deployment scripts and shell runners
- ORDS-hosted UI asset delivery for a React admin application
- a normalized first pass of the blog subscriber/newsletter database module
- public ORDS endpoints for subscription lifecycle and tracking
- a placeholder React admin app for the future M5 build
- Hugo integration assets for a public subscribe form

## Current State

This is a source scaffold, not a validated build.

The original subscriber module was a rough M7 handover. Known critical fixes have been applied where they affected repo shape:

- `sub_gdpr` has been split into `db/package_specs/sub_gdpr.pks` and `db/package_bodies/sub_gdpr.pkb`
- `sub_email.render_email_wrapper` has been exposed in `db/package_specs/sub_email.pks`
- grouped views and secondary indexes have been split into ROAD-style files
- the ROAD UI asset table/package/module has been added for the admin SPA

The SQL, ORDS modules, and React admin scaffold still need a real validation pass before deployment.

## Layout

```text
bin/                 ROAD shell runners
db/                  database artifacts
api/modules/         ORDS module definitions
deploy/create/       ordered deployment scripts
deploy/drop/         ordered teardown scripts
test/endpoint/       HTTP endpoint tests
test/contract/       SQL contract tests
blog_admin/          React admin SPA scaffold
integrations/hugo/   Hugo subscribe form integration
docs/                module docs and intake notes
road.config          app identity and ORDS base paths
```

## Expected First Commands

After moving this folder into a standalone repo:

```bash
bin/run-sql.sh --env dev --script deploy/drop/00_full.sql
bin/run-sql.sh --env dev --script deploy/create/00_full.sql
bin/deploy-react.sh --env dev --app blog_admin
bin/run-endpoint-tests.sh --env dev
```

Do not treat those as guaranteed to pass yet. The next stage is to run them, capture errors, and harden the module.

## Design Direction

Keep ROAD framework mechanics generic, but let ROAD Blogger own product decisions:

- public subscriber lifecycle endpoints
- newsletter send queue and tracking
- Hugo/blog integration
- protected admin API
- React admin UI
- OCI Email Delivery configuration

Reusable improvements discovered here can be backported to the ROAD framework repo later.
