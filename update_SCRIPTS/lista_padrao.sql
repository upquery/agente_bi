DECLARE 
 ws_passo varchar2(20); 
BEGIN
    --
    ws_passo := '1'; 
    delete bi_lista_padrao where cd_lista = 'CTB_TIPO_COMANDO'; 
    merge into bi_lista_padrao t1 using 
        (select 'CTB_TIPO_COMANDO' cd_lista, 'FULL'      cd_item, 'FULL'       ds_item, null ds_abrev, 1  nr_ordem from dual union all
         select 'CTB_TIPO_COMANDO' cd_lista, 'SCHEDULER' cd_item, 'SCHEDULER'  ds_item, null ds_abrev, 2  nr_ordem from dual         
        ) t2 
    on (t1.cd_lista = t2.cd_lista and t1.cd_item = t2.cd_item )  
    when matched then update set t1.ds_item = t2.ds_item, t1.ds_abrev = t2.ds_abrev, t1.nr_ordem = t2.nr_ordem  
    when not matched then insert (cd_lista, cd_item, ds_item, ds_abrev, nr_ordem) values (t2.cd_lista, t2.cd_item, t2.ds_item, t2.ds_abrev, t2.nr_ordem);    
    commit; 
exception when others then
    ROLLBACK;  
    INSERT INTO BI_LOG_SISTEMA VALUES (sysdate, 'Erro PASSO ('||ws_passo||'): '||DBMS_UTILITY.FORMAT_ERROR_STACK||' - '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, 'DWU', 'ERRO');
    COMMIT;
END;
