begin
  ords.delete_privilege(p_name => 'admin.privilege');
exception
  when others then
    null;
end;
/

begin
  ords.delete_module(p_module_name => 'admin');
exception
  when others then
    null;
end;
/
