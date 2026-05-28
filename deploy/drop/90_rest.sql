whenever oserror exit failure rollback
whenever sqlerror exit sql.sqlcode rollback

prompt === drop ORDS modules ===
@api/modules/admin/module.drop.sql
@api/modules/subscriber/module.drop.sql
@api/modules/ui/module.drop.sql
