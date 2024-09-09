create or replace TRIGGER TRG_CTB_CLIENTES
BEFORE INSERT OR UPDATE OR DELETE ON CTB_CLIENTES
FOR EACH ROW
BEGIN
    
    if updating ('HABILITADO') then 
        insert into bi_log_alt (nm_tab, id_reg, nm_col,  tp_alt, dt_alt, nm_usu, vl_old, vl_new) values ('CTB_CLIENTES', :new.id_cliente, 'HABILITADO', 'U', sysdate, user, :old.habilitado, :new.habilitado);
    elsif inserting then 
        insert into bi_log_alt (nm_tab, id_reg, tp_alt, dt_alt, nm_usu, vl_new)  values ('CTB_CLIENTES', :new.id_cliente, 'I', sysdate, user, :new.nm_cliente||'|'||:new.habilitado);    
    elsif deleting then 
        insert into bi_log_alt (nm_tab, id_reg, tp_alt, dt_alt, nm_usu)  values ('CTB_CLIENTES', :old.id_cliente, 'D', sysdate, user);
    end if; 
END;