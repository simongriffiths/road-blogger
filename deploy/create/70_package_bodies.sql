whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === deploy package bodies ===
@db/package_bodies/ui_assets_api.pkb
@db/package_bodies/sub_email.pkb
@db/package_bodies/sub_api.pkb
@db/package_bodies/sub_newsletter.pkb
@db/package_bodies/sub_gdpr.pkb
