whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === deploy package specs ===
@db/package_specs/ui_assets_api.pks
@db/package_specs/sub_api.pks
@db/package_specs/sub_email.pks
@db/package_specs/sub_newsletter.pks
@db/package_specs/sub_gdpr.pks
