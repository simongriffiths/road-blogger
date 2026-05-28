whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === deploy ORDS modules ===
@api/modules/ui/module.create.sql
@api/modules/subscriber/module.create.sql
@api/modules/admin/module.create.sql
