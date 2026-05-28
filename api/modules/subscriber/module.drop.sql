begin
  ords.delete_module(p_module_name => 'tracker');
exception
  when others then
    null;
end;
/

begin
  ords.delete_module(p_module_name => 'subscriber');
exception
  when others then
    null;
end;
/
