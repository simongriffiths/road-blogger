whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === ROAD Blogger full teardown ===
@deploy/drop/90_rest.sql
@deploy/drop/80_standalone.sql
@deploy/drop/70_package_bodies.sql
@deploy/drop/60_package_specs.sql
@deploy/drop/40_views.sql
@deploy/drop/20_indexes.sql
@deploy/drop/10_tables.sql
@deploy/drop/08_sequences.sql
@deploy/drop/05_types.sql
