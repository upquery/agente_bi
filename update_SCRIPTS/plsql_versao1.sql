--------------------------------------------------------------------------------------------
-- Alterações de tabelas, indexes (update,insert,etc)
--------------------------------------------------------------------------------------------
declare 
    ws_passo         varchar2(20); 
    ws_count         number; 
    ws_msg_erro      varchar2(300) := null; 
    ws_raise_execute exception;
    --
    -- Faz o execute immediate tratando alguns exceptions 
    ----------------------------------------------------------------------
    procedure p_execute_immediate (p_sql varchar2) is 
    begin
        execute immediate p_sql; 
    exception when others then 
        if DBMS_UTILITY.FORMAT_ERROR_STACK like '%ORA-01430%' or       -- coluna já existe 
           DBMS_UTILITY.FORMAT_ERROR_STACK like '%ORA-00955%' or       -- nome já está sendo usado por um objeto existente
           DBMS_UTILITY.FORMAT_ERROR_STACK like '%ORA-02260%' or       -- a tabela só pode ter uma chave primária
           DBMS_UTILITY.FORMAT_ERROR_STACK like '%ORA-01408%' or       -- coluna já indexada (criação de index)
           DBMS_UTILITY.FORMAT_ERROR_STACK like '%ORA-02443%' or       -- Constraint não existe 
           DBMS_UTILITY.FORMAT_ERROR_STACK like '%ORA-01452%' or       -- há chaves duplicadas na criação de index
           DBMS_UTILITY.FORMAT_ERROR_STACK like '%ORA-02264%' or       -- nome já usado por uma restrição existente
           DBMS_UTILITY.FORMAT_ERROR_STACK like '%ORA-02441%' or       -- Não é possível eliminar chave primária que não existe
           DBMS_UTILITY.FORMAT_ERROR_STACK like '%restri%exclusiva%violada%' then          
            null;
        else 
            if ws_msg_erro is null then 
                ws_msg_erro := substr('PLSQL_VERSAO1('||ws_Passo||'):'||DBMS_UTILITY.FORMAT_ERROR_STACK||' - '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,1,299); 
            end if;
        end if;      
    end;
    -----------------------------------------------------------------------
begin 
    --
    ws_passo := '1';  
    p_execute_immediate ('');
    p_execute_immediate ('alter table CTB_RUN_PARAM add id_entreaspas varchar2(1) default ''N'' ');
    p_execute_immediate ('alter table CTB_RUN_PARAM add id_schedule   varchar2(20) default ''0'' ');
    p_execute_immediate ('alter table ctb_run_param drop primary key') ;    
    p_execute_immediate ('alter table ctb_run_param add constraint ctb_run_param_pk primary key (id_run, id_schedule, cd_parametro)') ;    
    p_execute_immediate ('alter table ctb_acoes_exec add id_schedule varchar2(20)') ;    
    --
    commit; 
    --
    if ws_msg_erro is null then 
        raise ws_raise_execute;
    end if; 
exception 
    when ws_raise_execute then 
        insert into bi_log_sistema (dt_log, ds_log, nm_usuario, nm_procedure) values(sysdate, ws_msg_erro, 'DWU', 'ERRO'); 
        commit; 
    when others then 
        insert into bi_log_sistema (dt_log, ds_log, nm_usuario, nm_procedure) values(sysdate, 'PLSQL_VERSAO1('||ws_Passo||'):'||DBMS_UTILITY.FORMAT_ERROR_STACK||' - '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 'DWU', 'ERRO'); 
        commit; 
end; 