create or replace TRIGGER TRG_CTB_USUARIO_CLIENTE
BEFORE INSERT OR UPDATE OR DELETE ON CTB_USUARIO_CLIENTE
FOR EACH ROW
BEGIN
    if inserting then 
        insert into bi_log_alt (nm_tab, id_reg, tp_alt, dt_alt, nm_usu ) values ('CTB_USUARIO_CLIENTE', :new.cd_usuario||'|'||:new.id_cliente, 'I', sysdate, user);
    elsif deleting then 
        insert into bi_log_alt (nm_tab, id_reg, tp_alt, dt_alt, nm_usu)  values ('CTB_USUARIO_CLIENTE', :old.cd_usuario||'|'||:old.id_cliente, 'D', sysdate, user);
    end if; 
END;