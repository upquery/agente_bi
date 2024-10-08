create or replace package body CTB  is

    cursor c_param_conexao is 
        select 01 ordem, 'SISTEMA'   cd, 'SISTEMA'    ds from dual union all
        select 02 ordem, 'DB'        cd, 'BASE DADOS' ds from dual union all 
        select 03 ordem, 'HOST'      cd, 'HOST:PORTA' ds from dual union all         
        select 04 ordem, 'USUARIO'   cd, 'USUARIO'    ds from dual union all         
        select 05 ordem, 'SENHA'     cd, 'SENHA'      ds from dual union all         
        select 06 ordem, 'DATABASE'  cd, 'NOME BASE'  ds from dual 
       order by 1 ;

    cursor c_param_destino is 
        select 01 ordem, 'HOST'          cd, 'HOST'          ds from dual union all         
		select 02 ordem, 'PORTA'         cd, 'PORTA'         ds from dual union all         
        select 03 ordem, 'USUARIO'       cd, 'USUARIO'       ds from dual union all         
        select 04 ordem, 'SENHA'         cd, 'SENHA'         ds from dual union all         
        select 05 ordem, 'SERVICE_NAME'  cd, 'NOME SERVICO'  ds from dual 
       order by 1 ;


----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--     	cópia da FUN 
----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function randomCode( prm_tamanho number default 10) return varchar2 as 
    ws_code varchar2(200);
begin
    select xmlagg(xmlelement("r", ch)).extract('//text()').getstringval() into ws_code from
    (
        select distinct first_value(ch) over (partition by lower(ch)) as ch
        from (
            select substr('abcdefghijklmnpqrstuvwxyzABCDEFGHIJKLMNPQRSTUVWXYZ123456789',
                level, 1) as ch
            from dual 
            connect by level <= 59
            order by dbms_random.value
            )
        where rownum <= prm_tamanho
    );
    return ws_code;
end randomCode;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function c2b ( p_clob in clob ) return blob is
  temp_blob   blob;
  dest_offset number  := 1;
  src_offset  number  := 1;
  amount      integer := dbms_lob.lobmaxsize;
  blob_csid   number  := dbms_lob.default_csid;
  lang_ctx    integer := dbms_lob.default_lang_ctx;
  warning     integer;
begin
 	dbms_lob.createtemporary(lob_loc=>temp_blob, cache=>true);
	dbms_lob.converttoblob  (temp_blob, p_clob,amount,dest_offset,src_offset,blob_csid,lang_ctx,warning);
  	return temp_blob;
end c2b;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function b2c ( p_blob blob ) return clob is
      l_clob         clob;
      l_dest_offsset integer := 1;
      l_src_offsset  integer := 1;
      l_lang_context integer := dbms_lob.default_lang_ctx;
      l_warning      integer;
begin
      if p_blob is null then
         return null;
      end if;
      dbms_lob.createTemporary(lob_loc => l_clob
                              ,cache   => false);
      dbms_lob.converttoclob(dest_lob     => l_clob
                            ,src_blob     => p_blob
                            ,amount       => dbms_lob.lobmaxsize
                            ,dest_offset  => l_dest_offsset
                            ,src_offset   => l_src_offsset
                            ,blob_csid    => dbms_lob.default_csid
                            ,lang_context => l_lang_context
                            ,warning      => l_warning);
      return l_clob;
end B2C;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function ret_var  ( prm_variavel   varchar2 default null, 
                    prm_usuario    varchar2 default 'DWU' ) return varchar2 as
    ws_count      number; 
    ws_variavel   varchar2(200); 
    ws_conteudo   var_conteudo.conteudo%type; 
begin 
    ws_variavel := replace(replace(prm_variavel, '#[', ''), ']', '');
    ws_conteudo := null; 

    select count(*), max(conteudo) into ws_count, ws_conteudo 
      from VAR_CONTEUDO
	 where USUARIO  = prm_usuario 
	   and VARIAVEL = ws_variavel; 
    
    if ws_count = 0 then -- Se não encontrou para o usuário, procura no usuário padrão DWU 
        select count(*), max(conteudo) into ws_count, ws_conteudo 
          from VAR_CONTEUDO
	     where USUARIO  = 'DWU' 
	       and VARIAVEL = ws_variavel; 
    end if; 

    return ws_conteudo; 

exception when others then
    return '';
end ret_var;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function xexec ( ws_content  varchar2 default null ) return varchar2 as   -- Copia da FUN com simplificações para utilização somente pelo processo de CTB
    ws_tcont        varchar2(3000);
    ws_calculado    varchar2(2000);
    ws_cursor       integer;
    ws_linhas       integer;
    ws_sql          varchar2(2000);
begin
    ws_tcont := ws_content;
    if  UPPER(substr(ws_tcont,1,5)) = 'EXEC=' then
        WS_TCONT := REPLACE(UPPER(WS_TCONT), 'EXEC=','');
        WS_TCONT := REPLACE(WS_TCONT, '$[NOW]', trim(to_char(sysdate, 'DD/MM/YYYY HH24:MI')));
        WS_TCONT := REPLACE(WS_TCONT, '$[DOWNLOAD]', ''||nvl(ctb.ret_var('OWNER_BI'),'DWU')||'.fcl.download?arquivo=');
        
        ws_sql := 'select '||trim(ws_tcont)||' from dual';
        ws_cursor := dbms_sql.open_cursor;
        dbms_sql.parse(ws_cursor, ws_sql, DBMS_SQL.NATIVE);
        dbms_sql.define_column(ws_cursor, 1, ws_calculado, 600);

        ws_linhas := dbms_sql.execute(ws_cursor);
        ws_linhas := dbms_sql.fetch_rows(ws_cursor);

        dbms_sql.column_value(ws_cursor, 1, ws_calculado);
        dbms_sql.close_cursor(ws_cursor);
        ws_tcont := ws_calculado;
    end if;
    return(ws_tcont);
exception when others then
    return(ws_tcont);
end xexec;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
function vpipe ( prm_entrada varchar2,
                 prm_divisao varchar2 default '|' ) return CHARRET pipelined as
   ws_bindn      number;
   ws_texto      varchar2(32000);
   ws_nm_var      varchar2(32000);
   ws_flag         char(1);
begin
   ws_flag  := 'N';
   ws_bindn := 0;
   ws_texto := prm_entrada;
   loop
       if  ws_flag = 'Y' then
           exit;
       end if;
       if  nvl(instr(ws_texto,prm_divisao),0) = 0 then
			ws_flag  := 'Y';
			ws_nm_var := ws_texto;
       else
			ws_nm_var := substr(ws_texto, 1 ,instr(ws_texto,prm_divisao)-1);
			ws_texto  := substr(ws_texto, length(ws_nm_var||prm_divisao)+1, length(ws_texto));
       end if;
       ws_bindn := ws_bindn + 1;
       pipe row (ws_nm_var);
   end loop;
exception
   when others then
      pipe row(sqlerrm||'=VPIPE');
end VPIPE;

-------------------------------------------------------------------------------------------------------------------------------------------------------------
------ Procedures de criação das fila de ações ---------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------
function prn_a_status  (prm_status varchar2) return varchar2 is 
	ws_cor     varchar2(10);
	ws_classe  varchar2(20);
	ws_hint    varchar2(200);
	ws_status  varchar2(200);
begin 
	ws_classe := '';
	if    prm_status = 'AGUARDANDO' 	 then 	ws_cor := '#F6C21A';   ws_hint := 'Aguardando o inicio da execu&ccedil;&atilde;o pelo Agente.';
	elsif prm_status = 'AGUARD.INSERCAO' then 	ws_cor := '#F6C21A';   ws_hint := 'Aguardando a inser&ccedil;&atilde;o dos dados no Destino.';	
	elsif prm_status = 'EXECUTANDO'  	 then	ws_cor := '#F6C21A';   ws_hint := 'Executando processo de integra&ccedil;&atilde;o.';                       ws_classe := 'executando' ; 	
	elsif prm_status = 'EXTRAINDO'  	 then	ws_cor := '#F6C21A';   ws_hint := 'Executando a extra&ccedil;&atilde;o dos dados no cliente pelo Agente.';  ws_classe := 'executando' ; 
	elsif prm_status = 'INSERINDO' 		 then	ws_cor := '#F6C21A';   ws_hint := 'Executando a inser&ccedil;&atilde;o dos dados no destino.';              ws_classe := 'executando' ; 
	elsif prm_status = 'CONCLUIDO' 		 then 	ws_cor := '#3C8846';   ws_hint := 'Conclu&iacute;do do processo de integra&ccedil;&atilde;o.';
	elsif prm_status = 'ERRO'       	 then 	ws_cor := '#F2142B';   ws_hint := 'Erro durante o processo de integra&ccedil;&atilde;o.';
	elsif prm_status = 'CANCELADO'  	 then 	ws_cor := '#F2142B';   ws_hint := 'Processo de integra&ccedil;&atilde;o cancelado.';
	elsif prm_status = 'ALERTA'     	 then 	ws_cor := '#F6C21A';   ws_hint := 'Conclu&iacute;do com alerta para poss&iacute;vel erro na integra&ccedil;&atilde;o.';

	end if; 
	ws_status := prm_status;
	if prm_status = 'ALERTA' then 
		ws_status := 'CONCLUIDO';
	end if;
	return '<a class="'||ws_classe||'" style="background: '||ws_cor||' !important;" title="'||ws_hint||'" >'||ws_status||'</a>'; 
end;  

-----Criado procedure nessa package reduzir código referente ao agente dentro do BI --------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_fakelistoptions ( prm_ident     varchar2 default null,
								prm_campo     varchar2 default null,
								prm_visao     varchar2 default null,
								prm_ref       varchar2 default null,
								prm_adicional varchar2 default null,
								prm_search    varchar2 default null,
								prm_obj		  varchar2 default null ) as

	ws_usuario  varchar2(100); 
	ws_id_cliente     varchar2(100); 
	ws_id_sistema     varchar2(100); 
	ws_id_tipo_banco  varchar2(100); 

	procedure nested_test_list ( prm_ref     varchar2 default null,
								prm_id      varchar2 default null,
								prm_nome    varchar2 default null,
								prm_fixo    varchar2 default null,
								prm_cod     varchar2 default null,
								prm_com_cod varchar2 default 'S',
								prm_class   varchar2 default '') as
	ws_count  number;
	ws_rotulo varchar2(200);
	ws_class  varchar2(100); 
	begin
		select count(*) into ws_count from table((fun.vpipe(prm_ref))) where '|'||trim(column_value)||'|' = '|'||trim(prm_id)||'|';
		ws_rotulo := prm_nome;

		if nvl(prm_fixo, 'N/A') <> 'N/A' then
			ws_rotulo := prm_fixo;
		else
			if prm_id <> prm_nome and nvl(prm_com_cod,'S') = 'S' and prm_id not in ('TODOS','NENHUM') then
				ws_rotulo := nvl(prm_cod, prm_id)||' - '||prm_nome;
			end if;
		end if;
		ws_class := prm_class;
		if ws_count > 0 then
			ws_class := ws_class||' selected';
		end if; 
		htp.p('<li title="'||prm_id||'" class="opt '||ws_class||'">'||ws_rotulo||'</li>');
	end nested_test_list;

begin
	
	ws_usuario := gbl.getusuario(); 

	case
		when prm_campo = 'lista-ctb-tipo-banco' then
			for i in ( select id_tipo_banco, ds_tipo_banco from ctb_tipo_banco order by 1) loop
				nested_test_list(prm_ref, i.id_tipo_banco, i.ds_tipo_banco);
			end loop;

		when prm_campo = 'lista-ctb-tipo-comando' then
			for i in ( select cd_item as cod, fun.lang(nvl(ds_abrev, ds_item)) as nome from bi_lista_padrao where cd_lista = 'CTB_TIPO_COMANDO' order by nr_ordem, cd_item) loop
				nested_test_list(prm_ref, i.cod, i.nome);
			end loop;
		when prm_campo = 'lista-ctb-sistemas' then
			for i in ( select 1 ordem, id_sistema, ds_sistema from ctb_sistemas order by 1,2) loop
  				nested_test_list(prm_ref, i.id_sistema, i.id_sistema);
			end loop;

		when prm_campo = 'lista-ctb-clientes' then
			for i in ( select 1 ordem, id_cliente, nm_cliente from ctb_clientes 
			            where id_cliente in (select id_cliente from ctb_usuario_cliente where cd_usuario = ws_usuario)
						  and habilitado = 'S'
			           order by 1,2) loop
  				nested_test_list(prm_ref, i.id_cliente, i.nm_cliente);
			end loop;

		when prm_campo = 'lista-ctb-conexoes' then
			ws_id_cliente    := fun.vpipe_n(prm_adicional,1);
			ws_id_sistema    := fun.vpipe_n(prm_adicional,2);
			ws_id_tipo_banco := fun.vpipe_n(prm_adicional,3); 
			for i in ( select distinct id_conexao from ctb_conexoes 
			            where id_cliente    = nvl(ws_id_cliente,id_cliente) 
						  and id_conexao in (select id_conexao from ctb_conexoes where cd_parametro = 'DB'      and conteudo = ws_id_tipo_banco)  
						  and id_conexao in (select id_conexao from ctb_conexoes where cd_parametro = 'SISTEMA' and conteudo = ws_id_sistema)  
						  and id_cliente in (select id_cliente from ctb_usuario_cliente where cd_usuario = ws_usuario and id_selecionado = 'S') 
					   order by 1)
			loop
  				nested_test_list(prm_ref, i.id_conexao, i.id_conexao);
			end loop;
		when prm_campo = 'lista-ctb-acoes' then
			for i in ( select distinct id_acao from ctb_acoes 
						where id_cliente in (select id_cliente from ctb_usuario_cliente where cd_usuario = ws_usuario and id_selecionado = 'S') 
						order by 1)
			loop
  				nested_test_list(prm_ref, i.id_acao, i.id_acao);
			end loop;
	end case;

end ctb_fakelistoptions; 							


procedure ctb_float_menu (prm_closed varchar2) as 
begin 
	htp.p('<ul id="form-prefdrop-agente" class="form-config '||prm_closed||'" onmouseenter="this.focus();">');

		htp.p('<li><a title="'||fun.lang('Agendador de tarefas')||'" data-menu="ctb_run" data-refresh="ctb_run_list" data-refresh-pkg="ctb" data-carrega="ctb_run_list" data-package="ctb" data-attrib="">');
			htp.p('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M17 3v-2c0-.552.447-1 1-1s1 .448 1 1v2c0 .552-.447 1-1 1s-1-.448-1-1zm-12 1c.553 0 1-.448 1-1v-2c0-.552-.447-1-1-1-.553 0-1 .448-1 1v2c0 .552.447 1 1 1zm13 13v-3h-1v4h3v-1h-2zm-5 .5c0 2.481 2.019 4.5 4.5 4.5s4.5-2.019 4.5-4.5-2.019-4.5-4.5-4.5-4.5 2.019-4.5 4.5zm11 0c0 3.59-2.91 6.5-6.5 6.5s-6.5-2.91-6.5-6.5 2.91-6.5 6.5-6.5 6.5 2.91 6.5 6.5zm-14.237 3.5h-7.763v-13h19v1.763c.727.33 1.399.757 2 1.268v-9.031h-3v1c0 1.316-1.278 2.339-2.658 1.894-.831-.268-1.342-1.111-1.342-1.984v-.91h-9v1c0 1.316-1.278 2.339-2.658 1.894-.831-.268-1.342-1.111-1.342-1.984v-.91h-3v21h11.031c-.511-.601-.938-1.273-1.268-2z"/></svg>');
			htp.p('<span>'||fun.lang('Tarefas')||'</span>');
		htp.p('</a></li>');

		htp.p('<li><a title="'||fun.lang('A&ccedil;&otilde;es')||'" data-menu="ctb_acoes" data-refresh="" data-carrega="ctb_acoes_list" data-package="ctb" data-attrib="">');
			htp.p('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M12 2c5.514 0 10 4.486 10 10s-4.486 10-10 10-10-4.486-10-10 4.486-10 10-10zm0-2c-6.627 0-12 5.373-12 12s5.373 12 12 12 12-5.373 12-12-5.373-12-12-12zm-3 17v-10l9 5.146-9 4.854z"/></svg>');
			htp.p('<span>'||fun.lang('A&ccedil;&otilde;es')||'</span>');
		htp.p('</a></li>');

		htp.p('<li><a title="'||fun.lang('Conex&otilde;es Origem')||'" data-menu="ctb_conexoes" data-refresh="" data-carrega="ctb_conexoes_list" data-package="ctb" data-attrib="">');
			htp.p('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M1 3.488c0-1.926 4.656-3.488 10-3.488 5.345 0 10 1.562 10 3.488s-4.655 3.487-10 3.487c-5.344 0-10-1.561-10-3.487zm10 9.158c5.345 0 10-1.562 10-3.487v-2.44c-2.418 1.738-7.005 2.256-10 2.256-3.006 0-7.588-.523-10-2.256v2.44c0 1.926 4.656 3.487 10 3.487zm0 5.665c.34 0 .678-.007 1.011-.019.045-1.407.537-2.7 1.342-3.745-.839.067-1.643.1-2.353.1-3.006 0-7.588-.523-10-2.256v2.434c0 1.925 4.656 3.486 10 3.486zm1.254 1.97c-.438.02-.861.03-1.254.03-2.995 0-7.582-.518-10-2.256v2.458c0 1.925 4.656 3.487 10 3.487 1.284 0 2.526-.092 3.676-.256-1.155-.844-2.02-2.055-2.422-3.463zm10.746-1.781c0 2.485-2.017 4.5-4.5 4.5s-4.5-2.015-4.5-4.5 2.017-4.5 4.5-4.5 4.5 2.015 4.5 4.5zm-2.166-1.289l-2.063.557.916-1.925-1.387.392-1.466 3.034 1.739-.472-1.177 2.545 3.438-4.131z"/></svg>');
			htp.p('<span>'||fun.lang('Conex&otilde;es Origem')||'</span>');
		htp.p('</a></li>');

		htp.p('<li><a title="'||fun.lang('Conex&otilde;es Destino')||'" data-menu="ctb_destino" data-refresh="" data-carrega="ctb_destino_list" data-package="ctb" data-attrib="">');
			htp.p('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path d="M1 3.488c0-1.926 4.656-3.488 10-3.488 5.345 0 10 1.562 10 3.488s-4.655 3.487-10 3.487c-5.344 0-10-1.561-10-3.487zm10 9.158c5.345 0 10-1.562 10-3.487v-2.44c-2.418 1.738-7.005 2.256-10 2.256-3.006 0-7.588-.523-10-2.256v2.44c0 1.926 4.656 3.487 10 3.487zm0 5.665c.34 0 .678-.007 1.011-.019.045-1.407.537-2.7 1.342-3.745-.839.067-1.643.1-2.353.1-3.006 0-7.588-.523-10-2.256v2.434c0 1.925 4.656 3.486 10 3.486zm1.254 1.97c-.438.02-.861.03-1.254.03-2.995 0-7.582-.518-10-2.256v2.458c0 1.925 4.656 3.487 10 3.487 1.284 0 2.526-.092 3.676-.256-1.155-.844-2.02-2.055-2.422-3.463zm10.746-1.781c0 2.485-2.017 4.5-4.5 4.5s-4.5-2.015-4.5-4.5 2.017-4.5 4.5-4.5 4.5 2.015 4.5 4.5zm-2.166-1.289l-2.063.557.916-1.925-1.387.392-1.466 3.034 1.739-.472-1.177 2.545 3.438-4.131z"/></svg>');
			htp.p('<span>'||fun.lang('Conex&otilde;es Destino')||'</span>');
		htp.p('</a></li>');

	htp.p('</ul>');			
end ctb_float_menu; 


-------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure exec_schdl as 

    cursor c_tarefas is
    	select s.ID_RUN, nr_dia_mes, s.nr_dia_semana, nr_mes, nr_hora, nr_minuto
      	  from ctb_clientes c, ctb_run r, ctb_run_schedule s
         where c.id_cliente = r.id_cliente 
		   and r.ID_RUN     = s.ID_RUN 
		   and c.habilitado = 'S'            -- somente usuário habilitado 
	       and nvl(r.st_ativo,'N')  = 'S' ;  -- somente tarefas ativa

	ws_reg_online       varchar2(100);
    ws_noact            exception;
    ws_check            number     := 0;
    ws_check_semana     number     := 0;
	ws_check_dia_mes    number     := 0;
	ws_check_mes        number     := 0;	
	ws_check_hora       number     := 0;
	ws_check_minuto     number     := 0;

    ws_date             date;
    ws_dia_semana       integer;
    ws_dia_mes          integer;
    ws_mes              integer;
    ws_hora             integer;
    ws_minuto           integer;
	ws_erro             varchar2(4000); 

 BEGIN

    ws_date       := sysdate;
    ws_dia_semana := to_number(to_char(ws_date,'D'));
    ws_dia_mes 	  := to_number(to_char(ws_date,'DD'));
    ws_mes        := to_number(to_char(ws_date,'MM'));
    ws_hora       := to_number(to_char(ws_date,'HH24'));
    ws_minuto     := to_number(to_char(ws_date,'MI'));
	
    if upper(ctb.ret_var('CTB_ATIVO')) <> 'SIM' then
        raise ws_noact;
    end if;

    for a in c_tarefas loop
        -- precisa zerar pois pode retornar mais de uma linha...
        ws_check_semana  := 0;
        ws_check_dia_mes := 0;
        ws_check_mes     := 0;	
        ws_check_hora    := 0;
        ws_check_minuto  := 0;
		if (nvl(a.nr_dia_semana,  'N/A') <> 'N/A' or nvl(a.nr_dia_mes, 'N/A') <> 'N/A' ) and 
		    nvl(a.nr_mes,         'N/A') <> 'N/A' and 
		    nvl(a.nr_hora,        'N/A') <> 'N/A' and 
		    nvl(a.nr_minuto,      'N/A') <> 'N/A' then
		
            if a.nr_dia_mes is not null then
                select count(column_value) into ws_check_dia_mes from table(ctb.vpipe(a.nr_dia_mes)) where column_value = ws_dia_mes;
            end if;
            if a.nr_dia_semana is not null then
				select count(column_value) into ws_check_semana  from table(ctb.vpipe(a.nr_dia_semana))  where column_value = ws_dia_semana;
			end if;
            select count(column_value) into ws_check_mes    from table(ctb.vpipe(a.nr_mes))    where column_value = ws_mes;
            select count(column_value) into ws_check_hora   from table(ctb.vpipe(a.nr_hora))   where column_value = ws_hora;
            select count(column_value) into ws_check_minuto from table(ctb.vpipe(a.nr_minuto)) where column_value = ws_minuto;
			if (ws_check_dia_mes + ws_check_semana + ws_check_mes + ws_check_hora + ws_check_minuto) >= 4 then
				ctb.exec_run(a.ID_RUN, null, ws_erro);
			end if;
		end if; 
    end loop;

    -- Cria Job para cancelar ações executando a um determinando tempo (não cria o job, se já estiver executando)
    -- ctb.execute_now('ctb.canc_step_tempo_limite', 'N');   

 exception
    when ws_noact then
        insert into log_eventos values(sysdate , '[CTB]-TAREFA DESATIVADA' , 'DWU' , 'CTB' , 'OK', '0');
        commit;
    when others then
        insert into log_eventos values(sysdate , '[CTB]-ERRO:'||dbms_utility.format_error_stack||dbms_utility.format_error_backtrace, user , 'CTB' , 'ERRO', '0');
        commit;
end exec_schdl;


------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure exec_run (prm_ID_RUN             varchar2,
                    prm_id_run_acao        varchar2 default null,
					prm_retorno     in out varchar2) as

    cursor c_rs is
		select ra.id_run_acao, ra.ID_RUN, ra.ordem, ru.ds_run, 
		       ra.id_cliente, ra.id_conexao, ra.id_acao, ra.tbl_destino, ac.comando, ac.comando_limpar, ac.tipo_comando 
		  from ctb_acoes ac, ctb_run ru, ctb_run_acoes ra
	     where ac.id_cliente  = ra.id_cliente
		   and ac.id_acao     = ra.id_acao 
           and ru.ID_RUN      = ra.ID_RUN  
		   and ra.ID_RUN      = prm_ID_RUN
           and ra.id_run_acao = nvl(prm_id_run_acao, ra.id_run_acao)
		order by ra.ordem ;
	
	ws_rs c_rs%rowtype;
	
    ws_comando           ctb_acoes.comando%type; 
    ws_comando_limpar    ctb_acoes.comando_limpar%type;  
	ws_id_cliente        ctb_clientes.id_cliente%type;
	ws_parametros        varchar2(32000);
	ws_erro              varchar2(500); 
	ws_erro_limpar       varchar2(500); 
	ws_count             number;
	ws_id_agendamento    varchar2(100); 
	ws_status            varchar2(20); 
	ws_qt_acoes          integer;
	ws_qt_erros 		 integer;
	ws_raise_run         exception; 

begin

    ws_id_agendamento := to_char(sysdate,'yymmddhh24miss')||'-'||UPPER(ctb.randomCode(5)); 
	ws_erro := null;

	select min(ru.id_cliente) into ws_id_cliente 
	  from ctb_clientes cl, ctb_run ru
	 where cl.id_cliente = ru.id_cliente  
	   and ru.ID_RUN     = prm_ID_RUN
	   and cl.habilitado = 'S'; 
	if ws_id_cliente is null then 
		ws_erro := 'Cliente n&atilde;o est&aacute; habilitado, habilite o cliente para executar o processo de integra&ccedil;&atilde;o via agente';
		raise ws_raise_run;   -- cancela a execução atual 
	end if;    

	-- Cria o registro de controle de lock de inserção utilizado pelo Python (se for a primeira execução do cliente e ele ainda não tem esse registro)
	select count(*) into ws_count from ctb_lock_insercao where id_cliente = ws_id_cliente;
	if ws_count = 0 then 
		insert into ctb_lock_insercao (id_cliente, status) values (ws_id_cliente, 'N');
	end if; 

	-- Cancela se a tarefa já estiver em execução 
	ws_status := null;
	ctb.ctb_atu_status_run (prm_ID_RUN, ws_status);  

	if prm_id_run_acao is not null then 
		select count(*) into ws_count from ctb_run_acoes
		where id_run_acao  = prm_id_run_acao
		  and status in ('AGUARDANDO','EXECUTANDO'); 
		if ws_count > 0 then
			ws_erro := 'A&ccedil;&atilde;o ainda est&aacute; aguardando ou em execu&ccedil;&atilde;o';
			raise ws_raise_run;   -- cancela a execução atual 
		end if; 
	else 
		if ws_status in ('AGUARDANDO','EXECUTANDO') then 
			ws_erro := 'Tarefa anterior ainda executando';
			raise ws_raise_run;   -- cancela a execução atual 
		end if; 
	end if; 

	-- Atualiza os parametros da tarefa, caso tenha sido adicionado algum novo parametro nas ações - já tem commit na procedure 
	ctb.ctb_run_param_atu(prm_ID_RUN) ; 

	-- Se for execução de toda a tarefa 
	if prm_id_run_acao is null then 
		-- Atualiza Situação da tarefa
		ws_status := 'AGUARDANDO'; 
		update ctb_run set last_status = ws_status where ID_RUN = prm_ID_RUN;
		commit; 
		update ctb_run_acoes
			set status = ws_status, dt_inicio = null, dt_fim = null
		where ID_RUN      = prm_ID_RUN
			and id_run_acao = nvl(prm_id_run_acao, id_run_acao); 
		commit;
	end if; 

	-- Cria um ctb_acoes_exec para cada passo
	ws_qt_acoes := 0;
	ws_qt_erros := 0;
	for a in c_rs loop 
		ws_qt_acoes       := ws_qt_acoes + 1;
		ws_erro           := null;
		ws_comando        := a.comando; 
		ws_comando_limpar := a.comando_limpar; 
		ctb.exec_param_substitui (a.ID_RUN, a.id_run_acao, a.id_acao, ws_comando_limpar, ws_parametros, ws_erro_limpar);  -- Substitui o conteúdo dos parametros 
    	ctb.exec_param_substitui (a.ID_RUN, a.id_run_acao, a.id_acao, ws_comando,        ws_parametros, ws_erro);         -- Substitui o conteúdo dos parametros 

    	if ws_erro_limpar is not null or ws_erro is not null or ws_comando is null then 
			ws_qt_erros := ws_qt_erros + 1;
			if ws_comando is null then 
				ws_erro := 'Comando da acao esta em branco, informe o comando da acao.';
			else 
				ws_erro := nvl(ws_erro, ws_erro_limpar);
			end if;	
			ws_status := 'ERRO';
		else 	
			ws_status := 'AGUARDANDO';
    	end if;     

		ctb.ctb_atu_status_acao(a.id_run_acao, ws_status);
		insert into ctb_acoes_exec (id_agendamento,    id_cliente,   id_run,   id_run_acao,   id_acao,   id_conexao,   comando,    comando_limpar,    tbl_destino,   status,    dt_criacao, ds_erro) 
						    values (ws_id_agendamento, a.id_cliente, a.id_run, a.id_run_acao, a.id_acao, a.id_conexao, ws_comando, ws_comando_limpar, a.tbl_destino, ws_status, sysdate,    ws_erro );
	end loop; 	

	ctb.ctb_atu_status_run (prm_ID_RUN, ws_status);  -- Atualiza e retorna o status das ações e da tarefa 

	if ws_qt_acoes = 0 then 
		ws_erro   := 'Problema na parametriza&ccedil;&atilde;o das a&ccedil;&otilde;es da tarefa, confira o cadastro das a&ccedil;&otilde;es e da tarefa.';
		raise ws_raise_run; 
	elsif ws_qt_erros > 0 then 
		ws_erro   := 'Erro iniciando algumas a&ccedil;&otilde;es, verifique o log das a&ccedil;&otilde;es para visualizar o erro.';
		raise ws_raise_run; 
	end if; 
	prm_retorno := ws_erro; 

exception 
	when ws_raise_run then  
		ctb.ctb_atu_status_run (prm_ID_RUN, ws_status);  
		prm_retorno := ws_erro; 
		insert into bi_log_sistema (dt_log, ds_log, nm_usuario, nm_procedure) values (sysdate , 'ctb.exec_run('||prm_ID_RUN||') erro: '||ws_erro, 'DWU', 'ERRO');
        commit;
	when others then 	
		rollback; 
		ctb.ctb_atu_status_run (prm_ID_RUN, ws_status);  
		prm_retorno := 'Erro iniciando a execu&ccedil;ão, verifique o log de erros do sistema';
		insert into bi_log_sistema (dt_log, ds_log, nm_usuario, nm_procedure) values (sysdate , 'ctb.exec_run('||prm_ID_RUN||') erro: '||substr(dbms_utility.format_error_stack||dbms_utility.format_error_backtrace,1,3900), 'DWU', 'ERRO');
		commit;
end exec_run; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_param_atu(prm_ID_RUN varchar2) as 
    ws_comando   clob;
    ws_param     varchar2(500); 
    ws_params    clob; 
    ws_terminou  varchar2(1); 
    ws_pos_i     integer;
    ws_pos_f     integer; 
    ws_count integer; 
begin 

    for a in (select ac.comando, ac.comando_limpar
   				 from ctb_acoes ac, ctb_run_acoes ra
  				where ac.id_acao = ra.id_acao 
    			  and ra.ID_RUN  = prm_ID_RUN) loop
        ws_comando := a.comando||' '||a.comando_limpar; 
        --
        ws_count := 0 ;
        ws_terminou := 'N';
        while ws_terminou = 'N' loop 
            ws_count := ws_count + 1; 
            ws_pos_i := instr(ws_comando,'$[',1,1); 
            ws_pos_f := instr(ws_comando,']',ws_pos_i,1);
            if ws_pos_i > 0 and ws_pos_f > 0 then 
                ws_param   := trim(substr(ws_comando, ws_pos_i, ws_pos_f - ws_pos_i + 1 ));
                ws_param   := replace(replace(ws_param,'$['),']'); 
                if length(ws_param) > 0 then 
                    update ctb_run_param 
                       set cd_parametro = ws_param
                     where ID_RUN       = prm_ID_RUN
                       and cd_parametro = ws_param;
                    if sql%notfound then 
                        insert into ctb_run_param (ID_RUN,cd_parametro,st_ativo ) values (prm_ID_RUN, ws_param, 'S'); 
                    end if; 
                end if; 
                ws_comando := substr(ws_comando, ws_pos_f + 1, 99999);
            else     
                ws_terminou := 'S'; 
            end if;     
        end loop; 
    end loop;
    commit; 
    --

	select count(*) into ws_count from ctb_run_param where ID_RUN = prm_ID_RUN and cd_parametro = 'MINUTO_ESPERA';
	if ws_count = 0 then 
		insert into ctb_run_param (ID_RUN, cd_parametro, conteudo, st_ativo) values (prm_ID_RUN, 'MINUTO_ESPERA', 30,'S'); 
	end if; 	
	
	select count(*) into ws_count from ctb_run_param where ID_RUN = prm_ID_RUN and cd_parametro = 'MINUTO_ESPERA_PLSQL';
	if ws_count = 0 then 
		insert into ctb_run_param (ID_RUN, cd_parametro, conteudo, st_ativo) values (prm_ID_RUN, 'MINUTO_ESPERA_PLSQL', 180,'S');   -- 3 horas
	end if; 	
	--
end ctb_run_param_atu; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure exec_param_substitui (prm_ID_RUN          in varchar2, 
                                prm_id_run_acao     in varchar2,
                                prm_id_acao         in varchar2,
                                prm_comando     in out varchar2,
                                prm_parametros  in out varchar2,
                                prm_erro        in out varchar2 ) as 
    ws_parametros    varchar2(4000); 
    ws_comando       varchar2(32000); 
    ws_conteudo      varchar2(32000);
    ws_erro          varchar2(300);  
    ws_id_entreaspas varchar2(10);  
	ws_tbl_destino   ctb_run_acoes.tbl_destino%type;
    ws_raise_param   exception; 
    ws_raise_retorno exception;  

begin 
    select max(tbl_destino) into ws_tbl_destino from ctb_run_acoes where id_run_acao = prm_id_run_acao;
	ws_parametros := null;   
    ws_comando    := prm_comando; 
    ws_comando    := regexp_replace(ws_comando,'#\[ID_RUN]',      chr(39)||prm_ID_RUN||chr(39)      ,1,0,'i');
    ws_comando    := regexp_replace(ws_comando,'#\[ID_RUN_ACAO]', chr(39)||prm_id_run_acao||chr(39) ,1,0,'i');
    ws_comando    := regexp_replace(ws_comando,'#\[ID_ACAO]',     chr(39)||prm_id_acao||chr(39)     ,1,0,'i');
	ws_comando    := regexp_replace(ws_comando,'#\[TBL_DESTINO]', ws_tbl_destino  ,1,0,'i');
	prm_erro      := null;

    for a in (select '$['||cd_parametro||']' as parametro, conteudo, cd_parametro
                from ctb_run_param 
               where ID_RUN = prm_ID_RUN 
                 and instr(upper(ws_comando), '$['||cd_parametro||']') > 0
             ) loop

        ws_conteudo      := a.conteudo;
        if ws_conteudo is null then
            ws_erro := a.parametro; 
            raise ws_raise_param;     
        end if;
        
        if instr(upper(ws_conteudo),'EXEC=') > 0 then 
            ws_conteudo := replace(ws_conteudo,'exec=','EXEC='); 
            ws_conteudo := ctb.xexec (ws_conteudo); 
        end if;     
        ws_comando := replace(ws_comando,  a.parametro, ws_conteudo );
        if ws_parametros is not null then 
            ws_parametros := ws_parametros||', ';
        end if;     
        ws_parametros := ws_parametros||a.parametro||'='||ws_conteudo;
    end loop; 

    prm_comando := ws_comando; 

    if instr(ws_comando,'$[') > 0 then 
        ws_erro := substr(ws_comando, instr(ws_comando,'$[',1,1),  instr(ws_comando,']',1,1)-instr(ws_comando,'$[',1,1)+1 ); 
        ws_erro := 'Nao foi possivel substituir o parametro '||ws_erro||' do comando da acao.'; 
        raise ws_raise_retorno; 
    end if; 

exception 
    when ws_raise_param then 
        prm_erro := 'Parametro '||ws_erro||' nao informado, ou com conteudo invalido';
    when ws_raise_retorno then 
        prm_erro := ws_erro; 
    when others then 
        prm_erro := 'Erro substituindo parametros, verifique o log de erros do sistema.';        
        ws_erro := substr(dbms_utility.format_error_stack||'-'||dbms_utility.format_error_backtrace,1,3900); 
        insert into bi_log_sistema (dt_log, ds_log, nm_usuario, nm_procedure) values (sysdate , 'exec_param_substitui(ID_RUN:'||prm_ID_RUN||') erro: '||ws_erro , 'DWU', 'ERRO');
        commit; 
end exec_param_substitui;                                

------------------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_atu_status_acao ( prm_id_run_acao  number, 
	                            prm_status       varchar2 ) as 
	ws_dt_i  date;
	ws_dt_f  date;

begin 

     if prm_status in ('EXTRAINDO','AGUARDANDO') then 
          ws_dt_i :=  sysdate; 
     elsif prm_status in ('CONCLUIDO', 'ERRO','CANCELADO','ALERTA') then 
          ws_dt_f :=  sysdate; 
     end if; 

	update ctb_run_acoes
	set status     = prm_status, 
		dt_inicio  = nvl(nvl(ws_dt_i, dt_inicio),ws_dt_f),
		dt_fim     = nvl(ws_dt_f, dt_fim)
	where id_run_acao = prm_id_run_acao;
end; 								

------------------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_atu_status_run ( prm_ID_RUN      varchar2,
                               prm_status in out varchar2 ) as 
	ws_qt_er       integer;
    ws_qt_ca       integer;
	ws_qt_ag       integer;
	ws_qt_agi      integer;
	ws_qt_ext      integer;
	ws_qt_ins      integer;
	ws_dt_f        date := null; 
	ws_status      varchar2(20);
	ws_erro        varchar2(4000);
begin 
	prm_status := ''; 
	select  sum(decode(status,'ERRO',1,0)), 
			sum(decode(status,'CANCELADO',1,0)), 
			sum(decode(status,'AGUARDANDO',1,0)), 
			sum(decode(status,'AGUARD.INSERCAO',1,0)), 
			sum(decode(status,'EXTRAINDO',1,0)),
			sum(decode(status,'INSERINDO',1,0)),
			max(dt_fim)
	into ws_qt_er, ws_qt_ca, ws_qt_ag, ws_qt_agi, ws_qt_ext, ws_qt_ins, ws_dt_f
	from ctb_run_acoes
	where ID_RUN = prm_ID_RUN; 

	if    ws_qt_ext > 0 then   ws_status := 'EXTRAINDO';
	elsif ws_qt_ins > 0 then   ws_status := 'INSERINDO'; 
	elsif ws_qt_ag  > 0 then   ws_status := 'AGUARDANDO'; 
	elsif ws_qt_agi > 0 then   ws_status := 'AGUARD.INSERCAO'; 
	elsif ws_qt_er  > 0 then   ws_status := 'ERRO'; 
	elsif ws_qt_ca  > 0 then   ws_status := 'CANCELADO'; 
	else                       ws_status := 'CONCLUIDO';  
	end if; 

	if ws_status not in ('ERRO','CANCELADO','CONCLUIDO') then 
		ws_dt_f := null;
	end if; 	

	update ctb_run 
	   set last_run    = ws_dt_f, 
	       last_status = ws_status 
	 where ID_RUN = prm_ID_RUN;
	commit;  		 
	--
	prm_status := ws_status; 

exception when others then 
    ws_erro := substr(dbms_utility.format_error_stack||'-'||dbms_utility.format_error_backtrace,1,3900); 
    insert into bi_log_sistema (dt_log, ds_log, nm_usuario, nm_procedure) values (sysdate , 'ctb_atu_status_run(ID_RUN:'||prm_ID_RUN||' ) erro: '||ws_erro , 'DWU', 'ERRO');
	commit;
	Raise_Application_Error (-20101, ws_erro);	  -- Gera erro na execução 
end ctb_atu_status_run; 	




-------------------------------------------------------------------------------------------------------------------------------------------------------------
---- procedures de TELAS do BI ---------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function ctb_clie_usua_get (prm_usuario varchar2) return varchar2 as  
    ws_return varchar2(4000) := null;
begin
	select listagg(id_cliente,'|') within group (order by id_cliente) into ws_return from ctb_usuario_cliente where cd_usuario = prm_usuario and id_selecionado = 'S';
	return ws_return;   
exception when others then
    return 'TODOS'; 
end ctb_clie_usua_get;

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_usua_clie_sel (prm_usuario varchar2 default null, prm_clientes varchar2) as 
    ws_usuario varchar2(100);
begin 
    ws_usuario := nvl(prm_usuario, gbl.getusuario()); 
    update ctb_usuario_cliente set id_selecionado = 'N'  
     where cd_usuario = ws_usuario ;
	for a in (select column_value as id_cliente from table(fun.vpipe(prm_clientes))) loop 
    	update ctb_usuario_cliente set id_selecionado = 'S'
         where cd_usuario = ws_usuario 
		   and id_cliente = a.id_cliente;
	end loop;	   
    commit; 
end ctb_usua_clie_sel; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_usua_clie_lista (prm_usuario   varchar2 default null,
							   prm_proc_tela varchar2 default null,
							   prm_editavel  varchar2 default 'S') as 
	ws_clientes  varchar2(20);   
	ws_nm_clientes varchar2(32000);
begin 
    ws_clientes := ctb.ctb_clie_usua_get(prm_usuario);    
	select listagg(id_cliente||'-'||nm_cliente,',') within group (order by nm_cliente) into ws_nm_clientes from ctb_clientes 
	 where habilitado = 'S'
	   and id_cliente in (select column_value from table(fun.vpipe(ws_clientes)));
	htp.p('<div class="searchbar">');
		if prm_editavel = 'S' then 
		    htp.p('<a class="ctb-selecao-cliente">CLIENTE : </a>');
			htp.p('<a class="script" onclick="call(''ctb_usua_clie_sel'', ''prm_clientes=''+this.nextElementSibling.title, ''ctb'').then(function(resposta){ ajax(''list'', '''||prm_proc_tela||''',  '''', true, ''content'','''','''',''CTB'');});"></a>');
			fcl.fakeoption('prm_id_cliente', '', ws_clientes, 'lista-ctb-clientes', 'N', 'N', prm_encode => 'S', prm_desc => ws_nm_clientes, prm_min => 1 );
		else 
		    htp.p('<a class="ctb-selecao-cliente" style="cursor:default;">CLIENTE : </a>');
			htp.p('<span class="fakeoption" style="cursor:default;" >'||ws_nm_clientes||'</span>'); 	
		end if; 	
	htp.p('</div>');
end ctb_usua_clie_lista; 


-------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure menu_ctb (prm_menu      varchar2, 
		            prm_tipo      varchar2 default null,
					prm_id_copia  varchar2 default null) as 
	ws_acoes       ctb_acoes%rowtype; 					
	ws_onkeypress      varchar2(500); 
	ws_onkeypress_int  varchar2(500); 
	ws_onkeypress_cod  varchar2(500); 
	ws_onkeypress_num  varchar2(500); 
	ws_onkeypress_pipe varchar2(500); 
	ws_param           varchar2(4000); 
	ws_title           varchar2(300); 
	ws_tipo_comando varchar2(200);
	ws_desc            varchar2(400);
    ws_usuario         varchar2(100);

begin 

	ws_usuario         := gbl.getusuario();
    ws_onkeypress      := ' onkeypress="proxCampo(event,this);"'; 
	ws_onkeypress_int  := ' onkeypress="if(!input(event, ''integer'')) {event.preventDefault();} else {proxCampo(event,this);}"'; 
	ws_onkeypress_cod  := ' onkeypress="if(!input(event, ''ID''))      {event.preventDefault();} else {proxCampo(event,this);}"'; 		
	ws_onkeypress_pipe := ' onkeypress="if(!input(event, ''nopipe''))      {event.preventDefault();} else {proxCampo(event,this);}"'; 		

	case 
	when prm_menu = 'ctb_conexoes' then 	

		htp.p('<h4>'||fun.lang('CONEX&Otilde;ES ORIGEM')||'</h4>');

		htp.p('<span class="script" onclick="call(''menu_ctb'', ''prm_menu=ctb_conexoes&prm_tipo=''+this.nextElementSibling.title, ''ctb'').then(function(resposta){ '||' if(resposta.indexOf(''ERRO|'') == -1){ alerta(''feed-fixo'', resposta.split(''|'')[1]); } else { document.getElementById(''painel'').innerHTML = resposta; }  });"></span>');
		ws_param := 'prm_id_cliente|prm_id_conexao'; 
		htp.p('<input type="text" id="prm_id_conexao" title="Informe um c&oacute;digo indentificador para a conex&atilde;o"  data-min="1"  placeholder="ID CONEX&Atilde;O" data-encode="S" class="up" '||ws_onkeypress||'/>');
		for a in c_param_conexao loop
            if a.cd = 'SISTEMA' then     
            	fcl.fakeoption('prm_'||a.cd, a.cd, '', 'lista-ctb-sistemas', 'N', 'N', prm_min=>1);    
            elsif a.cd = 'DB' then     
            	fcl.fakeoption('prm_'||a.cd, 'BANCO DE DADOS', '', 'lista-ctb-tipo-banco', 'N', 'N', prm_min=>1);    
            else
			    htp.p('<input type="text" id="prm_'||a.cd||'" data-min="1" placeholder="'||upper(a.ds)||'" data-encode="S" '||ws_onkeypress||'/>');
			end if;
            ws_param := ws_param||'|prm_'||a.cd; 
		end loop;

		htp.p('<a class="addpurple followed" title="'||fun.lang('Adicionar conex&atilde;o')||'" data-sup="ctb_conexoes" '||  
	           'data-req="ctb_conexoes_insert" data-par-agrupa="S" data-par="'||ws_param||'" '||
			   'data-res="ctb_conexoes_list"  data-msg="'||fun.lang('Adicionado com sucesso')||'" data-pkg="ctb">'||fun.lang('ADICIONAR')||'</a>');

	when prm_menu = 'ctb_destino' then 	

		htp.p('<h4>'||fun.lang('CONEX&Otilde;ES DESTINO')||'</h4>');

		htp.p('<span class="script" onclick="call(''menu_ctb'', ''prm_menu=ctb_destino&prm_tipo=''+this.nextElementSibling.title, ''ctb'').then(function(resposta){ '||' if(resposta.indexOf(''ERRO|'') == -1){ alerta(''feed-fixo'', resposta.split(''|'')[1]); } else { document.getElementById(''painel'').innerHTML = resposta; }  });"></span>');
		ws_param := 'prm_id_cliente'; 
		for a in c_param_destino loop
		    htp.p('<input type="text" id="prm_'||a.cd||'" data-min="1" placeholder="'||upper(a.ds)||'" data-encode="S" '||ws_onkeypress||'/>');
            ws_param := ws_param||'|prm_'||a.cd; 
		end loop;

		htp.p('<a class="addpurple followed" title="'||fun.lang('Adicionar conex&atilde;o')||'" data-sup="ctb_destino" '||  
	           'data-req="ctb_destino_insert" data-par-agrupa="S" data-par="'||ws_param||'" '||
			   'data-res="ctb_destino_list"  data-msg="'||fun.lang('Adicionado com sucesso')||'" data-pkg="ctb">'||fun.lang('ADICIONAR')||'</a>');

    when prm_menu = 'ctb_acoes' then

		htp.p('<h4>'||fun.lang('A&Ccedil;&Otilde;ES / COMANDOS')||'</h4>');

		ws_acoes := null;
		if prm_id_copia is not null then 
			select * into ws_acoes from ctb_acoes where id_acao = prm_id_copia;  
		end if; 
		htp.p('<input type="hidden" id="prm_id_copia"   value="'||prm_id_copia||'">');	

		fcl.fakeoption('prm_id_sistema',    fun.lang('Sistema'),    ws_acoes.id_sistema,    'lista-ctb-sistemas',    'N', 'N', null, prm_min => 1);
		fcl.fakeoption('prm_id_tipo_banco', fun.lang('Tipo Banco'), ws_acoes.id_tipo_banco, 'lista-ctb-tipo-banco', 'N', 'N', null, prm_min => 1);
		
		htp.p('<span class="script" onclick="let vid = ''''; if (document.getElementById(''prm_tipo_comando'').title==''FULL''){vid = ''ETL_TAUX_'';}else{vid = ''ETL_V_'';}; document.getElementById(''prm_id_acao'').value=vid;"></span>');
		fcl.fakeoption('prm_tipo_comando', fun.lang('TIPO COMANDO'), ws_acoes.tipo_comando, 'lista-ctb-tipo-comando', 'N', 'N', null);				

		htp.p('<input type="text"   id="prm_id_acao"   data-min="1" data-encode="N" placeholder="'||fun.lang('ID A&Ccedil;&Atilde;O')||'" class="up" '||ws_onkeypress_pipe||' value="'||ws_acoes.id_acao||'" />');

		htp.p('<a class="addpurple followed" title="'||fun.lang('Adicionar A&ccedil;&atilde;o')||'" data-sup="ctb_acoes"'||  
				'data-req="ctb_acoes_insert" data-par="prm_id_cliente|prm_id_acao|prm_id_sistema|prm_id_tipo_banco|prm_tipo_comando|prm_id_copia" '||
				'data-res="ctb_acoes_list" data-msg="'||fun.lang('Adicionado com sucesso')||'" data-pkg="ctb">'||fun.lang('ADICIONAR')||'</a>');

	when prm_menu = 'ctb_run' then 	

		htp.p('<h4>'||fun.lang('TAREFAS')||'</h4>');
		htp.p('<input type="hidden" id="painel-atributos" data-refresh="ctb_run_list" data-refresh-ativo="S" data-pkg="ctb">');

		htp.p('<input type="text"   id="prm_ds_run"   data-min="1" data-encode="S" placeholder="'||fun.lang('NOME DA TAREFA')||'" '||ws_onkeypress_pipe||'/>');

		htp.p('<a class="addpurple followed" title="'||fun.lang('Adicionar Tarefa')||'" data-sup="ctb_run"'||  
	           'data-req="ctb_run_insert" data-par="prm_id_cliente|prm_ds_run" '||
			   'data-res="ctb_run_list" data-msg="'||fun.lang('Adicionado com sucesso')||'" data-pkg="ctb">'||fun.lang('ADICIONAR')||'</a>');

	when prm_menu = 'ctb_run_schedule' then 	
		htp.p('<h4>'||fun.lang('HOR&Aacute;RIO AGENDAMENTO')||'</h4>');
		htp.p('<input type="hidden" id="painel-atributos" data-refresh="" data-pkg="" >');

		fcl.fakeoption('prm_nr_dia_semana', fun.lang('Dias/semana'), '',       'lista-semanas', 'N', 'S');
		fcl.fakeoption('prm_nr_dia_mes',    fun.lang('Dias do m&ecirc;s'), '', 'lista-dia-mes', 'N', 'S'); 
        fcl.fakeoption('prm_nr_mes',        fun.lang('Meses'), '',  'lista-meses', 'N', 'S', prm_min => 1);
		fcl.fakeoption('prm_nr_hora',       fun.lang('Hora'), '',   'lista-horas', 'N', 'S', prm_min => 1);
		fcl.fakeoption('prm_nr_minuto',     fun.lang('Minuto'), '', 'lista-minutos', 'N', 'S', prm_min => 1);		

		htp.p('<a class="addpurple followed" title="'||fun.lang('Adicionar agendamento')||'" data-sup="ctb_run_schedule"'||  
	           'data-req="ctb_run_schedule_insert" data-par="prm_ID_RUN|prm_nr_dia_semana|prm_nr_dia_mes|prm_nr_mes|prm_nr_hora|prm_nr_minuto" '||
			   'data-res="ctb_run_schedule_list" data-res-par="prm_ID_RUN" data-msg="'||fun.lang('Adicionado com sucesso')||'" data-pkg="ctb">'||fun.lang('ADICIONAR')||'</a>');

	when prm_menu = 'ctb_run_acoes' then 	

		htp.p('<h4>'||fun.lang('TAREFAS / A&Ccedil;&Otilde;ES')||'</h4>');
		htp.p('<input type="hidden" id="painel-atributos" data-refresh="ctb_run_acoes_list" data-refresh-ativo="N" data-pkg="ctb" >');

		htp.p('<input type="text" id="prm_ordem" data-min="1" data-encode="N" placeholder="'||fun.lang('ORDEM EXECU&Ccedil;&Atilde;O') ||'" '||ws_onkeypress_int||' style="display:block;" >');
		fcl.fakeoption('prm_id_acao', fun.lang('A&ccedil;&atilde;o'), null, 'lista-ctb-acoes', 'N', 'N', null);				

		htp.p('<a class="addpurple followed" title="'||fun.lang('Adicionar a&ccedil;&atilde;o na tarefa')||'" data-sup="ctb_run_acoes"'||  
	           'data-req="ctb_run_acoes_insert" data-par="prm_ID_RUN|prm_ordem|prm_id_acao" '||
			   'data-res="ctb_run_acoes_list" data-res-par="prm_ID_RUN" data-msg="'||fun.lang('Adicionado com sucesso')||'" data-pkg="ctb">'||fun.lang('ADICIONAR')||'</a>');
	/* 
	when prm_menu = 'ctb_run_param' then 	

		htp.p('<h4>'||fun.lang('PAR&Acirc;METROS EXECU&Ccedil;&Atilde;O')||'</h4>');
		htp.p('<input type="hidden" id="painel-atributos" data-refresh="" data-pkg="ctb" >');

		htp.p('<input type="text"   id="prm_cd_parametro" data-min="1" data-encode="N" placeholder="'||fun.lang('NOME/ID')||'" class="up" '||ws_onkeypress_cod||'/>');
		htp.p('<input type="text"   id="prm_ds_parametro" data-min="1" data-encode="S" placeholder="'||fun.lang('DESCRI&Ccedil;&Atilde;O') ||'" '||ws_onkeypress||'>');
		
		htp.p('<a class="addpurple followed" title="'||fun.lang('Adicionar a&ccedil;&atilde;o na tarefa')||'" data-sup="ctb_step_param"'||  
	           'data-req="ctb_step_param_insert" data-par="prm_step_id|prm_cd_parametro|prm_ds_parametro" '||
			   'data-res="ctb_step_param_list" data-res-par="prm_step_id" data-msg="'||fun.lang('Adicionado com sucesso')||'" data-pkg="ctb">'||fun.lang('ADICIONAR')||'</a>');
    **************/ 

	end case; 

exception when others then 
   	insert into bi_log_sistema values(sysdate, 'MENU_CTB (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
	commit;
	htp.p('ERRO|Erro montando tela, verifique o log de erros do sistema'); 
end menu_ctb; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_destino_list as 
    ws_nm_cliente   varchar2(200);
	ws_conteudo     varchar2(4000); 	
    ws_eventoGravar varchar2(2000);
    ws_evento       varchar2(2000);
begin 

    ws_eventoGravar := ' "requestDefault(''ctb_destino_update'', ''prm_id_cliente=#CLIENTE#&prm_cd_parametro=#CAMPO#&prm_conteudo=''+#VALOR#,this,#VALOR#,'''',''CTB'');"'; 
    htp.p('<input type="hidden" id="content-atributos" data-refresh="ctb_destino_list" data-pkg="ctb" >');

    ctb.ctb_usua_clie_lista(gbl.getusuario(), 'ctb_destino_list');

    htp.p('<table class="linha">');
        htp.p('<thead>');
            htp.p('<tr>');
                htp.p('<th>CLIENTE</th>');
                for a in c_param_destino loop  
                    htp.p('<th>'||a.ds||'</th>');
                end loop;
			htp.p('</tr>');
		htp.p('</thead>');
			
		htp.p('<tbody id="ajax" >');
        for a in (select distinct des.id_cliente, cli.nm_cliente
                    from ctb_clientes cli, ctb_destino des 
                   where cli.id_cliente = des.id_cliente 
                     and des.id_cliente in (select id_cliente from ctb_usuario_cliente where cd_usuario = gbl.getusuario() and id_selecionado = 'S')
                   order by des.id_cliente) loop 	
            ws_evento := ws_eventoGravar;
            ws_evento := replace(ws_evento,'#CLIENTE#', a.id_cliente);

			htp.p('<tr id="'||a.id_cliente||'">');
                htp.p('<td><div>'||a.id_cliente||'-'||a.nm_cliente||'</div></td>');
                for b in c_param_destino loop 
                    select max(conteudo) into ws_conteudo from ctb_destino where id_cliente = a.id_cliente and cd_parametro = b.cd ;
                    ws_conteudo := replace(ws_conteudo,'"', '&#34;');
					htp.p('<td>');
                        htp.p('<input id="prm_'||lower(b.cd)||'_'||a.id_cliente||'" type="text" data-min="1" data-default="'||ws_conteudo||'" value="'||ws_conteudo||'" '||
                        'onblur=" if (this.value !== this.getAttribute(''data-default'')) { call(''ctb_destino_update'', ''prm_id_cliente='||a.id_cliente||'&prm_cd_parametro='||upper(b.cd)||'&prm_conteudo=''+this.value,''CTB'').then(function(resposta){alerta(''feed-fixo'',resposta.split(''|'')[1]); });}" />');
					htp.p('</td>');
                end loop;
                            
                htp.p('<td  class="ctb_atalho">');
                    fcl.button_lixo('ctb_destino_delete','prm_id_cliente', a.id_cliente, prm_tag => 'a', prm_pkg => 'CTB');
                htp.p('</td>');
            htp.p('</tr>');						
		end loop; 	
			
    htp.p('</tbody>');
    htp.p('</table>');	
exception when others then
    htp.p('Erro montando tela, entre em contato com o adminstrador do sistema!');	
    if nvl(gbl.getNivel, 'N') = 'A' then 
        htp.p('Erro:'||dbms_utility.format_error_stack||dbms_utility.format_error_backtrace);	
    end if;     
    insert into bi_log_sistema (dt_log, ds_log, nm_usuario, nm_procedure) values (sysdate, 'ctb_destino_list(others): Erro: '||dbms_utility.format_error_stack||dbms_utility.format_error_backtrace, gbl.getusuario(), 'ERRO');
    commit; 
end ctb_destino_list; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_destino_insert ( prm_parametros    varchar2, 
						       prm_conteudos     varchar2 ) as 
	type ws_tp_conteudos is table of varchar2(200) index by pls_integer;
	ws_conteudos		ws_tp_conteudos ;

	ws_idx        integer; 
	ws_conteudo   varchar2(4000); 
    ws_id_cliente varchar2(100); 
	ws_id_conexao varchar2(100); 
    ws_usuario    varchar2(200);
	ws_count      number;

	ws_erro     varchar2(300); 
	raise_erro  exception;
begin 

	ws_usuario := gbl.getusuario(); 

    -- Grava todos os conteudos em um array 
	ws_idx := 0 ;
	for a in (select column_value conteudo from table(fun.vpipe(prm_conteudos))) loop 
		ws_idx := ws_idx + 1; 
		ws_conteudos(ws_idx) := a.conteudo; 
	end loop; 
	
	-- Passa por todos os parametros, pega o conteúdo e grava na tabela 
	ws_idx        := 0; 
    ws_id_cliente := null; 
    ws_id_conexao := null;     
	for a in (select upper(column_value) cd_parametro from table(fun.vpipe(prm_parametros)) where column_value is not null ) loop 
		ws_idx      := ws_idx + 1; 
		ws_conteudo := ws_conteudos(ws_idx); 
		
		if a.cd_parametro = 'ID_CLIENTE' then 
			ws_id_cliente := ws_conteudo;
			if ws_id_cliente like '%@PIPE@%' then 
				ws_erro := 'Para adicionar, deve ser selecionado apenas um cliente na lista de CLIENTES';
				raise raise_erro;
			end if; 
            if length(ws_conteudo) = 0 or ws_conteudo is null then 
				ws_erro := 'Para adicionar, deve &eacute; necess&aacute;rio selecionar um cliente na lista de CLIENTES';
				raise raise_erro;
            end if; 
            ws_conteudo := ws_id_cliente;
		end if; 	

		ctb_conexoes_valida ('I', a.cd_parametro, ws_conteudo, ws_erro); 
		if ws_erro is not null then 
			raise raise_erro; 
		end if; 

		if a.cd_parametro <> 'ID_CLIENTE' then 

            if ws_id_cliente is null then         
                ws_erro := 'Erro obtendo cliente para cadastro da conex&atilde;o de destino';
                raise raise_erro; 
            end if; 

			select count(*) into ws_count from ctb_destino where id_cliente = ws_id_cliente and cd_parametro = a.cd_parametro;
			if ws_count > 0 then 
				ws_erro := 'O cliente pode ter somente uma conexão de destino';
				raise raise_erro; 
			end if; 

            begin 
                insert into ctb_destino (id_cliente, cd_parametro, conteudo) values (ws_id_cliente, a.cd_parametro, ws_conteudo);
            exception when others then 
                rollback; 
                insert into bi_log_sistema values(sysdate, 'ctb_destino_insert (insert) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
                commit;
                ws_erro	:= 'Erro inserindo parametro ['||a.cd_parametro||'], verique o log de erros do sistema';
                raise raise_erro; 
            end; 
        end if; 
	end loop; 
	--
	commit; 
	--
	htp.p('OK|Registro atualizado');
exception 
	when raise_erro then 
		rollback; 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		rollback; 
		ws_erro	:= 'Erro inserindo registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_destino_insert (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_destino_insert; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_destino_update ( prm_id_cliente    varchar2, 
                               prm_cd_parametro  varchar2,
							   prm_conteudo      varchar2 ) as 
	ws_erro     varchar2(300); 
	ws_vl_old   varchar2(4000);
	raise_erro  exception; 							   
begin 

	ctb_conexoes_valida ('U',prm_cd_parametro, prm_conteudo, ws_erro); if ws_erro is not null then raise raise_erro; end if; 

	select substr(max(conteudo),1,3990) into ws_vl_old from ctb_destino 
	 where id_cliente   = prm_id_cliente
	   and cd_parametro = prm_cd_parametro;

	update ctb_destino 
	   set conteudo = prm_conteudo 
	 where id_cliente   = prm_id_cliente
	   and cd_parametro = prm_cd_parametro;
	if sql%notfound then    
		insert into ctb_destino (id_cliente, cd_parametro, conteudo) values (prm_id_cliente, prm_cd_parametro, prm_conteudo); 
	end if;        
	
	fun.bi_log_alt_insere('U','CTB_DESTINO', prm_id_cliente||'|'||prm_cd_parametro, 'CONTEUDO', sysdate, gbl.getusuario(), ws_vl_old, substr(prm_conteudo,1,3990)); 
	
	commit; 
	htp.p('OK|Registro atualizado');
exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro alterando registro, verifique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_destino_update (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_destino_update; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_destino_delete ( prm_id_cliente  varchar2 ) as 
	ws_count    integer; 
	ws_erro     varchar2(300); 
	raise_erro  exception; 							   
begin 

	select count(*) into ws_count 
	  from ctb_run  
	 where id_cliente = prm_id_cliente; 
	if ws_count > 0 then 
		ws_erro := 'N&atilde;o &eacute; poss&iacute;vel excluir a conex&atilde;o de destino porque o cliente j&aacute; possui tarefas cadastradas'; 
		raise raise_erro; 
	end if; 

	delete ctb_destino where id_cliente = prm_id_cliente;  
	fun.bi_log_alt_insere('D','CTB_DESTINO', prm_id_cliente, null, sysdate, gbl.getusuario(), null, null); 
	commit;

	htp.p('OK|Registro exclu&iacute;do');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro excluindo registro, verifique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_destino_delete (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_destino_delete; 



----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_conexoes_valida (prm_acao           varchar2, 
						 	   prm_campo          varchar2, 
                               prm_conteudo       varchar2,
							   prm_retorno    out varchar2 ) as 
	ws_count integer; 							  	
begin 
	prm_retorno := null;
	if prm_campo in ('ID_CLIENTE') and prm_conteudo = 'TODOS' then  
		prm_retorno := 'Para inclus&atilde;o &eacute; necess&aacute;rio que uma empresa/cliente seja selecionada'; 
	end if; 

	if prm_campo in ('ID_CONEXAO','DB', 'HOST','DATABASE','USUARIO','SENHA','SERVICE_NAME') then  
		if instr(prm_conteudo,' ') <> 0 then 
			prm_retorno := '['||prm_campo||'] n&atilde;o pode conter espa&ccedil;os em branco'; 
		end if; 	
	end if; 

	if prm_conteudo is null and prm_campo in ('ID_CLIENTE','ID_CONEXAO','DB', 'HOST','DATABASE','USUARIO','SENHA','SERVICE_NAME') then  
		prm_retorno := '['||prm_campo||'] deve ser preenchido'; 
	end if; 

	if prm_campo = 'HOST' then  
		if instr(prm_conteudo,',') <> 0 then 
			prm_retorno := '['||prm_campo||'] n&atilde;o pode conter VIRGULA'; 
		end if; 	
	end if; 
   
end ctb_conexoes_valida;  							   


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_conexoes_list as 
    ws_nm_cliente   varchar2(200);
	ws_conteudo     varchar2(4000); 	
    ws_eventoGravar varchar2(2000);
    ws_evento       varchar2(2000);
begin 

    ws_eventoGravar := ' "requestDefault(''ctb_conexoes_update'', ''prm_id_cliente=#CLIENTE#&prm_id_conexao=#CONEXAO#&prm_cd_parametro=#CAMPO#&prm_conteudo=''+#VALOR#,this,#VALOR#,'''',''CTB'');"'; 
    htp.p('<input type="hidden" id="content-atributos" data-refresh="ctb_conexoes_list" data-pkg="ctb" >');

    ctb.ctb_usua_clie_lista(gbl.getusuario(), 'ctb_conexoes_list');

    htp.p('<table class="linha">');
        htp.p('<thead>');
            htp.p('<tr>');
                htp.p('<th>CLIENTE</th>');
                htp.p('<th>ID CONEX&Atilde;O</th>');
                for a in c_param_conexao loop  
                    htp.p('<th>'||a.ds||'</th>');
                end loop;
			htp.p('</tr>');
		htp.p('</thead>');
			
		htp.p('<tbody id="ajax" >');
        for a in (select distinct con.id_cliente, cli.nm_cliente, con.id_conexao  
                    from ctb_clientes cli, ctb_conexoes con 
                   where cli.id_cliente = con.id_cliente 
					 and con.id_cliente in (select id_cliente from ctb_usuario_cliente where cd_usuario = gbl.getusuario() and id_selecionado = 'S' ) 
                   order by con.id_cliente, con.id_conexao) loop 	
            ws_evento := ws_eventoGravar;
            ws_evento := replace(ws_evento,'#CLIENTE#', a.id_cliente);
            ws_evento := replace(ws_evento,'#CONEXAO#', a.id_conexao);

			htp.p('<tr id="'||a.id_cliente||'-'||a.id_conexao||'">');
                htp.p('<td><div>'||a.id_cliente||'-'||a.nm_cliente||'</div></td>');
                htp.p('<td><div>'||a.id_conexao||'</div></td>');
                for b in c_param_conexao loop 
                    select max(conteudo) into ws_conteudo from ctb_conexoes where id_cliente = a.id_cliente and id_conexao = a.id_conexao and cd_parametro = b.cd ;
                    ws_conteudo := replace(ws_conteudo,'"', '&#34;');
					htp.p('<td>');
                        if b.cd = 'SISTEMA' then
                            htp.p('<a class="script" data-default="'||ws_conteudo||'" onclick='||replace(replace(ws_evento,'#CAMPO#',b.cd),'#VALOR#','this.nextElementSibling.title')||'></a>');
	    					fcl.fakeoption(a.id_cliente||'-'||a.id_conexao||'-'||b.cd, '', ws_conteudo, 'lista-ctb-sistemas', 'N', 'N', prm_min => 1, prm_desc => ws_conteudo );
                        elsif b.cd = 'DB' then
                            htp.p('<a class="script" data-default="'||ws_conteudo||'" onclick='||replace(replace(ws_evento,'#CAMPO#',b.cd),'#VALOR#','this.nextElementSibling.title')||'></a>');
	    					fcl.fakeoption(a.id_cliente||'-'||a.id_conexao||'-'||b.cd, '', ws_conteudo, 'lista-ctb-tipo-banco', 'N', 'N', prm_min => 1, prm_desc => ws_conteudo );
                        else 
                            htp.p('<input id="prm_'||lower(b.cd)||'_'||a.id_conexao||'" type="text" data-min="1" data-default="'||ws_conteudo||'" value="'||ws_conteudo||'" '||
                            'onblur=" if (this.value !== this.getAttribute(''data-default'')) { call(''ctb_conexoes_update'', ''prm_id_cliente='||a.id_cliente||'&prm_id_conexao='||a.id_conexao||'&prm_cd_parametro='||upper(b.cd)||'&prm_conteudo=''+this.value,''CTB'').then(function(resposta){alerta(''feed-fixo'',resposta.split(''|'')[1]); });}" />');
                        end if;     
					htp.p('</td>');
                end loop;
                            
                htp.p('<td  class="ctb_atalho">');
                    fcl.button_lixo('ctb_conexoes_delete','prm_id_cliente|prm_id_conexao', a.id_cliente||'|'||a.id_conexao, prm_tag => 'a', prm_pkg => 'CTB');
                htp.p('</td>');
            htp.p('</tr>');						
		end loop; 	
			
    htp.p('</tbody>');
    htp.p('</table>');	
exception when others then
    htp.p('Erro montando tela, entre em contato com o adminstrador do sistema!');	
    if nvl(gbl.getNivel, 'N') = 'A' then 
        htp.p('Erro:'||dbms_utility.format_error_stack||dbms_utility.format_error_backtrace);	
    end if;     
    insert into bi_log_sistema (dt_log, ds_log, nm_usuario, nm_procedure) values (sysdate, 'ctb_conexoes_list(others): Erro: '||dbms_utility.format_error_stack||dbms_utility.format_error_backtrace, gbl.getusuario(), 'ERRO');
    commit; 
end ctb_conexoes_list; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_conexoes_insert ( prm_parametros    varchar2, 
							    prm_conteudos     varchar2 ) as 
	type ws_tp_conteudos is table of varchar2(200) index by pls_integer;
	ws_conteudos		ws_tp_conteudos ;

	ws_idx        integer; 
	ws_conteudo   varchar2(4000); 
    ws_id_cliente varchar2(100); 
	ws_id_conexao varchar2(100); 
    ws_usuario    varchar2(200);
	ws_count      number; 

	ws_erro     varchar2(300); 
	raise_erro  exception;
begin 

	ws_usuario := gbl.getusuario(); 

    -- Grava todos os conteudos em um array 
	ws_idx := 0 ;
	for a in (select column_value conteudo from table(fun.vpipe(prm_conteudos))) loop 
		ws_idx := ws_idx + 1; 
		ws_conteudos(ws_idx) := a.conteudo; 
	end loop; 
	
	-- Passa por todos os parametros, pega o conteúdo e grava na tabela 
	ws_idx        := 0; 
    ws_id_cliente := null; 
    ws_id_conexao := null;     
	for a in (select upper(column_value) cd_parametro from table(fun.vpipe(prm_parametros)) where column_value is not null ) loop 
		ws_idx      := ws_idx + 1; 
		ws_conteudo := ws_conteudos(ws_idx); 
		
		if a.cd_parametro = 'ID_CLIENTE' then 
			ws_id_cliente := ws_conteudo;
			if ws_id_cliente like '%@PIPE@%' then 
				ws_erro := 'Para adicionar, deve ser selecionado apenas um cliente na lista de CLIENTES';
				raise raise_erro;
			end if; 
            if length(ws_conteudo) = 0 or ws_conteudo is null then 
				ws_erro := 'Para adicionar, deve &eacute; necess&aacute;rio selecionar um cliente na lista de CLIENTES';
				raise raise_erro;
            end if; 
            ws_conteudo := ws_id_cliente;
		elsif a.cd_parametro = 'ID_CONEXAO' then 
			ws_id_conexao := upper(ws_conteudo);
            ws_conteudo   := ws_id_conexao;
		end if; 	

		ctb_conexoes_valida ('I', a.cd_parametro, ws_conteudo, ws_erro); 
		if ws_erro is not null then 
			raise raise_erro; 
		end if; 

		if a.cd_parametro <> 'ID_CLIENTE' and a.cd_parametro <> 'ID_CONEXAO' then 
            if ws_id_cliente is null or ws_id_conexao is null then         
                ws_erro := 'Erro obtendo o cliente ou o ID da conexão';
                raise raise_erro; 
            end if; 

			select count(*) into ws_count from ctb_conexoes 
			 where id_cliente   = ws_id_cliente 
			   and id_conexao   = ws_id_conexao
			   and cd_parametro = a.cd_parametro; 
			if ws_count > 0 then 
				ws_erro := 'J&aacute; existe uma conex&atilde;o cadastrada com esse ID para esse cliente';
				raise raise_erro;
			end if; 	

            begin 
                insert into ctb_conexoes (id_cliente, id_conexao, cd_parametro, conteudo) values (ws_id_cliente, ws_id_conexao, a.cd_parametro, ws_conteudo);
            exception when others then 
				rollback; 
				insert into bi_log_sistema values(sysdate, 'ctb_conexoes_insert (insert) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
				commit;
				ws_erro	:= 'Erro inserindo parametro ['||a.cd_parametro||'], verique o log de erros do sistema';
				raise raise_erro; 
            end; 
        end if; 
	end loop; 
	--
	commit; 
	--
	htp.p('OK|Registro atualizado');
exception 
	when raise_erro then 
		rollback; 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		rollback; 
		ws_erro	:= 'Erro inserindo registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_conexoes_insert (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_conexoes_insert; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_conexoes_update ( prm_id_cliente    varchar2, 
                                prm_id_conexao    varchar2, 
                                prm_cd_parametro  varchar2,
							    prm_conteudo      varchar2 ) as 
	ws_erro     varchar2(300); 
	ws_vl_old   varchar2(4000);
	raise_erro  exception; 							   
begin 

	ctb_conexoes_valida ('U',prm_cd_parametro, prm_conteudo, ws_erro); if ws_erro is not null then raise raise_erro; end if; 

	select substr(max(conteudo),1,3990) into ws_vl_old from ctb_conexoes 
	 where id_cliente   = prm_id_cliente
       and id_conexao   = prm_id_conexao 
	   and cd_parametro = prm_cd_parametro;

	update ctb_conexoes 
	   set conteudo = prm_conteudo 
	 where id_cliente   = prm_id_cliente
       and id_conexao   = prm_id_conexao 
	   and cd_parametro = prm_cd_parametro;
	if sql%notfound then    
		insert into ctb_conexoes (id_cliente, id_conexao, cd_parametro, conteudo) values (prm_id_cliente, prm_id_conexao, prm_cd_parametro, prm_conteudo); 
	end if; 
	fun.bi_log_alt_insere('U','CTB_CONEXOES', prm_id_cliente||'|'||prm_id_conexao||'|'||prm_cd_parametro, 'CONTEUDO', sysdate, gbl.getusuario(), ws_vl_old, substr(prm_conteudo,1,3990)); 	       
	commit; 
	htp.p('OK|Registro atualizado');
exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro alterando registro, verifique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_conexoes_update (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_conexoes_update; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_conexoes_delete ( prm_id_cliente  varchar2, 
                                prm_id_conexao  varchar2 ) as 
	ws_count    integer; 
	ws_erro     varchar2(300); 
	raise_erro  exception; 							   
begin 

	select count(*) into ws_count 
	  from ctb_run_acoes  
	 where id_cliente = prm_id_cliente
	   and id_conexao = prm_id_conexao; 
	if ws_count > 0 then 
		ws_erro := 'Existem Tarefas/A&ccedil;&otilde;es com essa conex&atilde;o, exclua essa conex&atilde;o das tarefas para liberar a exclus&atilde;o'; 
		raise raise_erro; 
	end if; 

	delete ctb_conexoes where id_cliente = prm_id_cliente and id_conexao = prm_id_conexao;  
	fun.bi_log_alt_insere('D','CTB_CONEXOES', prm_id_cliente||'|'||prm_id_conexao, null, sysdate, gbl.getusuario(), null, null); 	       	
	commit;  

	htp.p('OK|Registro exclu&iacute;do');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro excluindo registro, verifique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_conexoes_delete (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_conexoes_delete; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_acoes_list (prm_id_acao      varchar2 default null,
						  prm_order        varchar2 default '1',
						  prm_dir          varchar2 default '1') as 
	
	ws_id_cliente      varchar2(50);
	ws_usuario         varchar2(100);

	cursor c1 is 
		select ac.id_cliente, ac.id_acao, ac.id_sistema, si.ds_sistema, ac.id_tipo_banco, tb.ds_tipo_banco,  tipo_comando, comando, comando_limpar
          from ctb_sistemas si, ctb_tipo_banco tb, ctb_acoes ac 
		 where si.id_sistema    = ac.id_sistema
		   and tb.id_tipo_banco = ac.id_tipo_banco 
           and ac.id_acao       = nvl(prm_id_acao, id_acao)
		   and ac.id_cliente in (select id_cliente from ctb_usuario_cliente where cd_usuario = gbl.getusuario() and id_selecionado = 'S' ) 
		  order by case when prm_dir = '1' then decode(prm_order, '1', ac.id_acao, '2', si.ds_sistema, '3', tb.ds_tipo_banco, '4', ac.tipo_comando, id_acao) end asc,
		           case when prm_dir = '2' then decode(prm_order, '1', ac.id_acao, '2', si.ds_sistema, '3', tb.ds_tipo_banco, '4', ac.tipo_comando, id_acao) end desc; 

	ws_onkeypress      varchar2(300); 
	ws_onkeypress_int  varchar2(300); 
	ws_eventoGravar    varchar2(2000); 
	ws_evento          varchar2(2000); 
    ws_eventoOrdem     varchar2(2000); 
	ws_desc            varchar2(100); 
	ws_nm_cliente      varchar2(200); 
	ws_dir             number := 1;
	ws_erro            varchar2(200);
	ws_comando         clob;
	ws_comando_l       clob; 

begin 
	ws_usuario        := gbl.getusuario();
	ws_onkeypress     := ' onkeypress="proxCampo(event,this);"'; 
	ws_onkeypress_int := ' onkeypress="if(!input(event, ''integer'')) {event.preventDefault();} "';
	ws_eventoGravar   := ' "requestDefault(''ctb_acoes_update'', ''prm_id_acao=#ID#&prm_cd_parametro=#CAMPO#&prm_conteudo=''+#VALOR#,this,#VALOR#,'''',''CTB'');"'; 
	ws_eventoOrdem    := ' "var dir = order('''', ''ajax''); ajax(''list'', ''ctb_acoes_list'', ''prm_order=#ORDEM#&prm_dir=''+dir, false, ''content'','''','''',''CTB'');"';     

	if prm_id_acao is not null then 
		ctb.ctb_usua_clie_lista(gbl.getusuario(), 'ctb_acoes_list','N');
	else 
		ctb.ctb_usua_clie_lista(gbl.getusuario(), 'ctb_acoes_list','S');
	end if; 	

	htp.p('<input type="hidden" id="content-atributos" data-pkg="ctb" data-par-col="prm_id_acao" data-par-val="'||prm_id_acao||'" >');
	htp.p('<input type="hidden" id="prm_id_acao" value="'||prm_id_acao||'">');	

	htp.p('<table class="linha">');
		htp.p('<thead>');
			htp.p('<tr>');
				htp.p('<th title="ID da a&ccedil;&atilde;o"><a class="red" onclick='||replace(ws_eventoOrdem,'#ORDEM#',1)||'>'||fun.lang('ID A&Ccedil;&Atilde;O')||'</a></th>');
				htp.p('<th title="Sistema">                 <a class="red" onclick='||replace(ws_eventoOrdem,'#ORDEM#',2)||'>'||fun.lang('SISTEMA')||'</a></th>');
				htp.p('<th title="Tipo de banco de dados">  <a class="red" onclick='||replace(ws_eventoOrdem,'#ORDEM#',3)||'>'||fun.lang('TIPO BANCO')||'</a></th>');
				htp.p('<th title="Tipo de comando">         <a class="red" onclick='||replace(ws_eventoOrdem,'#ORDEM#',4)||'>'||fun.lang('TIPO COMANDO')||'</a></th>');				
				htp.p('<th title="Comando de extra&ccedil;&atilde;o dos dados">'||fun.lang('COMANDO')||'</th>');
				htp.p('<th title="Comando de limpeza da tabela de destino">'    ||fun.lang('COMANDO LIMPEZA')||'</th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
			htp.p('</tr>');
		htp.p('</thead>');

		if to_number(prm_dir) = 1 then
			ws_dir := 2;
		end if;

		htp.p('<tbody id="ajax" data-dir="'||ws_dir||'">');
			for a in c1 loop 
				ws_evento   := replace(ws_eventoGravar,'#ID#',a.id_acao); 

				htp.p('<tr id="'||a.id_cliente||'|'||a.id_acao||'">');
					
                    htp.p('<td>'||a.id_acao||'</td>');
					ws_comando   := replace(fun.html_trans(substr(a.comando,       1,500)),chr(10),'<br>');
					ws_comando_l := replace(fun.html_trans(substr(a.comando_limpar,1,500)),chr(10),'<br>');

					htp.p('<td class="fake-list">');
						htp.p('<a class="script" data-default="'||a.id_sistema||'" onclick='||replace(replace(ws_evento,'#CAMPO#','ID_SISTEMA'),'#VALOR#','this.nextElementSibling.title')||'></a>');
						fcl.fakeoption('prm_id_sistema_'||a.id_acao, fun.lang('Sistema'), a.id_sistema, 'lista-ctb-sistemas', 'N', 'N', null, prm_min => 1, prm_desc => fun.lang(a.ds_sistema) );
					htp.p('</td>');

					htp.p('<td>');
						htp.p('<a class="script" data-default="'||a.id_tipo_banco||'" onclick='||replace(replace(ws_evento,'#CAMPO#','id_tipo_banco'),'#VALOR#','this.nextElementSibling.title')||'></a>');
						fcl.fakeoption('prm_id_tipo_banco_'||a.id_acao, fun.lang('Tipo Banco'), a.id_tipo_banco, 'lista-ctb-tipo-banco', 'N', 'N', null, prm_min => 1, prm_desc => fun.lang(a.ds_tipo_banco) );
					htp.p('</td>');

					htp.p('<td>');
						htp.p('<a class="script" data-default="'||a.tipo_comando||'" onclick='||replace(replace(ws_evento,'#CAMPO#','TIPO_COMANDO'),'#VALOR#','this.nextElementSibling.title')||'></a>');
						fcl.fakeoption('prm_tipo_comando_'||a.id_acao, fun.lang('Tipo Comando'), a.tipo_comando, 'lista-ctb-tipo-comando', 'N', 'N', null, prm_min => 1, prm_desc => fun.lang(a.tipo_comando) );
					htp.p('</td>');

					htp.p('<td class="ctb_modal_comando" style="cursor: pointer;">');
						htp.p('<input id="prm_comando_'||a.id_acao||'" class="readonly" style="text-transform: none !important;" data-min="1" value="'||ws_comando||'" />');
					htp.p('</td>');

					htp.p('<td class="ctb_modal_comando_limpar" style="cursor: pointer;">');
						htp.p('<input id="prm_comando_limpar_'||a.id_acao||'" class="readonly" style="text-transform: none !important;" data-min="1" value="'||ws_comando_l||'" />');
					htp.p('</td>');

					if prm_id_acao is null then 
						htp.p('<td class="ctb_atalho" title="Copiar a&ccedil;&atilde;o" '||
					    	  ' onclick="call(''menu_ctb'', ''prm_menu=ctb_acoes&prm_id_copia='||a.id_acao||''', ''ctb'').then(function(resposta){ '||
		      			  	  '          if(resposta.indexOf(''ERRO|'') == 0){ alerta(''feed-fixo'', resposta.split(''|'')[1]); } else { document.getElementById(''painel'').innerHTML = resposta; }  });">');
							htp.p('<svg viewBox="0 0 28 28"><path d="M13.508 11.504l.93-2.494 2.998 6.268-6.31 2.779.894-2.478s-8.271-4.205-7.924-11.58c2.716 5.939 9.412 7.505 9.412 7.505zm7.492-9.504v-2h-21v21h2v-19h19zm-14.633 2c.441.757.958 1.422 1.521 2h14.112v16h-16v-8.548c-.713-.752-1.4-1.615-2-2.576v13.124h20v-20h-17.633z"></path></svg>');
						htp.p('</td>');
					end if; 

					htp.p('<td>');
						fcl.button_lixo('ctb_acoes_delete','prm_id_cliente|prm_id_acao', a.id_cliente||'|'||a.id_acao, prm_tag => 'a', prm_pkg => 'CTB');
					htp.p('</td>');
				htp.p('</tr>');						
			end loop; 	
			
		htp.p('</tbody>');
	htp.p('</table>');	
	
	htp.p('<div id="modal-txt" class="modal-txt"></div>');
	htp.p('<div id="modal-box" style="display: contents;"></div>');
exception when others then 
		ws_erro	:= 'Erro montando tela.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_acoes_list(others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_acoes_list; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_acoes_insert (prm_id_cliente       varchar2, 
							prm_id_acao          varchar2, 
							prm_id_sistema       varchar2,
							prm_id_tipo_banco    varchar2,
						    prm_tipo_comando     varchar2,
						    prm_id_copia         varchar2 default null) as 

	ws_ID_RUN   		 number; 
	ws_count 		     integer; 
	ws_erro     		 varchar2(300); 

	ws_id_sistema      ctb_acoes.id_sistema%type;
	ws_id_tipo_banco   ctb_acoes.id_tipo_banco%type;
	ws_tipo_comando    ctb_acoes.tipo_comando%type;
	ws_comando         ctb_acoes.comando%type;
	ws_comando_limpar  ctb_acoes.comando_limpar%type;
	ws_raise_erro  exception;
begin 
	if prm_id_acao is null then 
		ws_erro := 'C&oacute;digo identificador da a&ccedil;&atilde;o deve ser preenchido';
		raise ws_raise_erro; 
	end if; 
	if instr(prm_id_acao,'|') > 0 then 
		ws_erro := 'Caractere | (pipe) n&atilde;o pode ser utilizado no c&oacute;digo da a&ccedil;&atilde;o';
		raise ws_raise_erro; 
	end if; 

	select count(*) into ws_count from ctb_acoes 
	  where id_cliente = prm_id_cliente 
	    and id_acao    = trim(upper(prm_id_acao)) ; 
	if ws_count > 0 then 
		ws_erro := 'J&aacute; existe uma a&ccedil;&atilde;o com esse identificador para esse cliente';
		raise ws_raise_erro; 
	end if;

	if prm_id_copia is not null then
		begin 
			select id_sistema, id_tipo_banco, tipo_comando, comando, comando_limpar
			  into ws_id_sistema, ws_id_tipo_banco, ws_tipo_comando, ws_comando, ws_comando_limpar
			from ctb_acoes 
			where id_cliente = prm_id_cliente 
			  and id_acao    = prm_id_copia
			  and rownum     = 1 ;
		exception when others then
			null;
		end; 	
	else 
		ws_id_sistema      := prm_id_sistema;
		ws_id_tipo_banco   := prm_id_tipo_banco;  
		ws_tipo_comando    := prm_tipo_comando; 
		ws_comando         := null;
		ws_comando_limpar  := null;
	end if; 

	insert into ctb_acoes (id_cliente,     id_acao,                  id_sistema,    id_tipo_banco,    tipo_comando,    comando,    comando_limpar)
    	           values (prm_id_cliente, trim(upper(prm_id_acao)), ws_id_sistema, ws_id_tipo_banco, ws_tipo_comando, ws_comando, ws_comando_limpar);

	commit; 			  
	htp.p('OK|Registro inserido');

exception 
	when ws_raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro inserindo registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_acoes_insert (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_acoes_insert; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_acoes_update (prm_id_cliente       varchar2,
							prm_id_acao       varchar2, 
                           	prm_cd_parametro  varchar2,
						   	prm_conteudo      varchar2 ) as 
	ws_parametro varchar2(4000);
	ws_id_conexao varchar2(200);
	ws_tp_conexao varchar2(100);
	ws_comando   clob;     
	ws_conteudo  clob; 
	ws_alerta    varchar2(300);
	ws_erro      varchar2(300); 
	raise_erro   exception;
begin 
	ws_parametro := upper(trim(prm_cd_parametro)); 
	ws_conteudo  := prm_conteudo; 

	if ws_parametro = 'tipo_comando' then 
		select comando into ws_comando from ctb_acoes where id_cliente = prm_id_cliente and id_acao = prm_id_acao; 
		if ws_conteudo = 'FULL' and ws_comando like '%$[%]%' then 
			ws_alerta := '! Alerta, comando do tipo FULL n&atilde;o deve conter par&acirc;metros de data';
		end if;
	end if; 

	update ctb_acoes  
	   set id_sistema     = decode(ws_parametro, 'ID_SISTEMA',       ws_conteudo, id_sistema   ), 
		   id_tipo_banco  = decode(ws_parametro, 'ID_TIPO_BANCO',    ws_conteudo, id_tipo_banco), 
		   tipo_comando   = decode(ws_parametro, 'TIPO_COMANDO',     ws_conteudo, tipo_comando), 
		   comando        = decode(ws_parametro, 'COMANDO',          ws_conteudo, comando      ), 
		   comando_limpar = decode(ws_parametro, 'COMANDO_LIMPAR',   ws_conteudo, comando_limpar)
	 where id_cliente = prm_id_cliente
	   and id_acao    = prm_id_acao ; 
	if sql%notfound then 
		ws_erro := 'N&atilde;o localizado A&ccedil;&atilde;o com esse ID para esse cliente, recarrega a tela e tente novamente'; 
		raise raise_erro; 
	end if;  	    

	commit; 
	htp.p('OK|Registro alterado'||ws_alerta);

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro alterando registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_acoes_update (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_acoes_update;
----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_acoes_delete (prm_id_cliente  varchar2,
						    prm_id_acao     varchar2 ) as 
	ws_count    integer; 
	ws_erro     varchar2(300); 
	ws_ds_run   varchar2(300); 
	raise_erro  exception; 							   
begin 
	
	ws_ds_run := null;
	select max(ds_run) into ws_ds_run  
	  from ctb_run a, ctb_run_acoes b
	 where a.ID_RUN     = b.ID_RUN 
	   and b.id_cliente = prm_id_cliente 
	   and b.id_acao    = prm_id_acao; 
	
	if ws_ds_run is not null then 
		ws_erro := 'A&ccedil;&atilde;o n&atilde;o pode ser exclu&iacute;da porque est&aacute; sendo utilizada na tarefa ['||ws_ds_run||']';
		raise raise_erro; 
	end if;  

	delete ctb_acoes where id_cliente = prm_id_cliente and id_acao = prm_id_acao ;
	commit;

	htp.p('OK|Registro exclu&iacute;do');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro excluindo registro, verique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_acoes_delete (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_acoes_delete; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_acoes_comando (prm_id_cliente varchar2, 
							 prm_id_acao    varchar2,
                             prm_coluna     varchar2) as 
    ws_comando        clob;
	ws_titulo         varchar2(100);
	ws_title          varchar2(4000); 
	ws_erro           varchar2(200); 
	ws_onkeypress     varchar2(1000); 
	ws_htp_salvar     varchar2(32000); 
	ws_htp_fechar     varchar2(1000); 
	ws_raise_erro     exception; 
begin

	begin 
		select decode(prm_coluna, 'COMANDO',comando, 'COMANDO_LIMPAR', comando_limpar) into ws_comando    
	  	  from ctb_acoes  
	     where id_cliente = prm_id_cliente
		   and id_acao    = prm_id_acao;
	exception when others then 
		ws_erro := 'Erro obtendo comando, feche a tela e abra novamente.';
		raise ws_raise_erro;	 
	end; 	

	if prm_coluna = 'COMANDO_LIMPAR' then 
		ws_titulo := 'COMANDO LIMPEZA';
	else 
		ws_titulo := prm_coluna;
	end if;	
	ws_title    := 'Informe o comando a ser executado.'||chr(10)||'Informe $[PARAMETRO] para fazer refer&ecirc;ncia a par&acirc;metros da Tarefa.'
				   ||chr(10)||'Informe #[TBL_DESTINO] para substituir pelo nome da tabela de destino informada na tarefa.';	
	
	ws_onkeypress     := ' onkeypress="if(!input(event, ''nopipe'')) {event.preventDefault();} else {proxCampo(event,this);}"'; 
	ws_htp_fechar     := '<a class="addpurple" onclick="document.getElementById(''modal'||prm_id_acao||''').classList.remove(''expanded''); setTimeout(function(){ document.getElementById(''modal'||prm_id_acao||''').remove(); }, 200);">FECHAR</a>'; 

	htp.p('<div class="modal" style="overflow: auto;" id="modal'||prm_id_acao||'">');
       	htp.p('<h2 style="font-family: var(--fonte-secundaria); font-size: 20px; margin: 10px 5px 5px; padding: 10px 0px 5px 0px;">'||ws_titulo||'</h2>');

		htp.p('<div id="modal-input-text" style="overflow: auto;" class="ace_editor ace-tm" contenteditable="true" title="'||ws_title||'" onkeypress="var tamanho = this.innerHTML.toString().length; if(tamanho > 32000){ event.preventDefault(); return false;  };">'||ws_comando||'</div>');
		ws_htp_salvar := '<a class="addpurple" onclick="let conteudo = ace_editor.getValue(); call(''ctb_acoes_update'', ''prm_id_cliente='||prm_id_cliente||'&prm_id_acao='||prm_id_acao||'&prm_cd_parametro='||prm_coluna||'&prm_conteudo=''+encodeURIComponent(conteudo), ''ctb'').then(function(resposta){ '||
											' alerta('''', resposta.split(''|'')[1]); if(resposta.indexOf(''ERRO|'') != 0){ document.getElementById(''prm_'||lower(prm_coluna)||'_'||prm_id_acao||''').value = conteudo; }  });">SALVAR</a>'; 

		htp.p('<div style="display: flex; width: 70%; margin: 0 auto;">');
			htp.p(ws_htp_salvar);	
			htp.p(ws_htp_fechar);
		htp.p('</div>');			

	htp.p('</div>');
exception 
	when ws_raise_erro then 
		htp.p('ERRO|'||ws_erro);

end ctb_acoes_comando;

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_acoes_exec_list(prm_tp      varchar2,
                              prm_id      varchar2,
					          prm_linhas	varchar2 default '50') as 
	cursor c1 is  
		select * from (
			select ru.ds_run, ra.ordem, ae.id_agendamento, ae.id_acao, ae.dt_criacao, ae.dt_inicio, ae.dt_fim, ae.status, 
			ae.tempo_local, ae.tempo_upload, ae.tempo_processo, ae.ds_erro, ae.comando, ae.comando_limpar   
			from ctb_acoes ac, ctb_run ru, ctb_run_acoes ra, ctb_acoes_exec ae 
			where ac.id_acao        = ra.id_acao 
			  and ru.ID_RUN         = ra.ID_RUN 
			  and ra.id_run_acao(+) = ae.id_run_acao 
			  and (( prm_tp = 'RUN_ACAO' and ae.id_run_acao = prm_id and ae.id_run_acao is not null) or 
				   ( prm_tp = 'ACAO'     and ae.id_acao     = prm_id and ae.id_acao     is not null) or
				   ( prm_tp = 'RUN'      and ae.ID_RUN      = prm_id and ae.ID_RUN      is not null)
				  )			
			order by ae.dt_criacao desc
		)
        where rownum <= (CASE WHEN prm_linhas = 'TODAS' THEN 999999 ELSE TO_NUMBER(prm_linhas) END);

	ws_ds_log     	clob; 
	ws_dados_ret 	clob; 
	ws_comando    	clob;
	ws_comando_l 	clob; 
	ws_svg_dados    varchar2(4000); 
	ws_dhi_ins      date;
	ws_dhf_ins      date;
begin

	htp.p('<div id="searchbar" data-stop="S">');
		htp.p('<label>Filtrar linhas</label>');
		htp.p('<select id="searchbar" onchange="carregaTelasup(''ctb_acoes_exec_list'', ''prm_tp='||prm_tp||'&prm_id='||prm_id||'&prm_linhas=''+this.value, ''CTB'', ''none'','''','''','''');">');
			for a in (select '50'    id, '50 linhas'  ds from dual union all
					  select '100'   id, '100 linhas' ds from dual union all
					  select '250'   id, '250 linhas' ds from dual union all
					  select '500'   id, '500 linhas' ds from dual union all
					  select 'TODAS' id, 'TODAS'      ds from dual ) loop 
				if prm_linhas = a.id then
					htp.p('<option selected value="'||a.id||'">'||a.ds||'</option>');
				else
					htp.p('<option value="'||a.id||'">'||a.ds||'</option>');
				end if;
			end loop; 
		htp.p('</select>');
	htp.p('</div>');


	htp.p('<input type="hidden" id="content-atributos" data-refresh="ctb_acoes_exec_list" data-refresh-ativo="S" data-pkg="ctb" data-par-col="prm_tp|prm_id|prm_linhas" data-par-val="'||prm_tp||'|'||prm_id||'|'||prm_linhas||'">');

	htp.p('<h2>LOG EXECU&Ccedil;&Otilde;ES DO AGENTE</h2>');

	htp.p('<table class="linha">');
		htp.p('<thead>');
			htp.p('<tr>');
				HTP.P('<th title="Tarefa executada">' 								 ||FUN.LANG('TAREFA')||'</th>');
				HTP.P('<th title="Ordem da a&ccedil;&atilde;o na tarefa">'           ||FUN.LANG('ORD.')||'</th>');				
				HTP.P('<th title="Código da a&ccedil;&atilde;o executada">'          ||FUN.LANG('ID A&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th title="Comando de extra&ccedil;&atilde;o">'               ||FUN.LANG('COMANDO')||'</th>');
				HTP.P('<th title="Comando de limpeza da tabela">'                    ||FUN.LANG('C.LIMPEZA')||'</th>');
				HTP.P('<th title="Cria&ccedil;&atilde;o da execu&ccedil;&atilde;o da a&ccedil;&atilde;o">'   ||FUN.LANG('CRIA&Ccedil;&Atilde;O')||'</th>');				
				HTP.P('<th title="Inicio da a&ccedil;&atilde;o">'                    ||FUN.LANG('INICIO EXTRA&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th title="Fim da a&ccedil;&atilde;o">'                       ||FUN.LANG('FIM EXTRA&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th title="Inicio da inser&ccedil;&atilde;o.">'               ||FUN.LANG('INICIO INSER&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th title="Fim da inser&ccedil;&atilde;o">'            		 ||FUN.LANG('FIM INSER&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th title="Situa&ccedil;&atilde;o da a&ccedil;&atilde;o">'    ||FUN.LANG('SITUA&Ccedil;&Atilde;O')||'</th>');				
				HTP.P('<th title="Descri&ccedil;&atilde;o Erro">'                    ||FUN.LANG('RETORNO EXECU&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th></th>');
			htp.p('</tr>');
		htp.p('</thead>');

		htp.p('<tbody id="ajax" >');
			for a in c1 loop
				ws_ds_log         := replace(fun.html_trans(a.ds_erro),chr(10),'<br>');
				ws_comando   := replace(fun.html_trans(substr(a.comando,       1,500)),chr(10),'<br>');
				ws_comando_l := replace(fun.html_trans(substr(a.comando_limpar,1,500)),chr(10),'<br>');

				select min(dt_inicio), min(dt_fim) into ws_dhi_ins, ws_dhf_ins from ctb_docs where id_agendamento = a.id_agendamento;
				htp.p('<tr id="'||a.id_agendamento||'">');
					htp.p('<td class="ctb_col_ds_tarefa" style="width: 130px;">   <input disabled title="'||a.ds_run||'" value="'||a.ds_run||'"/></td>');					
					htp.p('<td class="ctb_col_ordem">                             <input disabled title="'||a.ordem  ||'" value="'||a.ordem||'"/></td>');
					htp.p('<td class="ctb_col_id_acao" style="width: 130px;">     <input disabled title="'||a.id_acao||'" value="'||a.id_acao||'"/></td>');					

					htp.p('<td class="ctb_modal_comando ctb_acoes_exec" style="cursor: pointer;width:100px">');
						htp.p('<input id="prm_comando_'||a.id_agendamento||'" class="readonly" style="text-transform: none !important;" data-min="1" value="'||ws_comando||'" />');
					htp.p('</td>');

					htp.p('<td class="ctb_modal_comando_limpar ctb_acoes_exec" style="cursor: pointer;width:100px">');
						htp.p('<input id="prm_comando_limpar_'||a.id_agendamento||'" class="readonly" style="text-transform: none !important;" data-min="1" value="'||ws_comando_l||'" />');
					htp.p('</td>');

					htp.p('<td class="ctb_col_dh">                                <input disabled title="'||to_char(a.dt_criacao,'dd/mm/yyyy hh24:mi:ss')||'" value="'||to_char(a.dt_criacao,'dd/mm/yyyy hh24:mi:ss')||'"/></td>');					
					htp.p('<td class="ctb_col_dh">                                <input disabled title="'||to_char(a.dt_inicio, 'dd/mm/yyyy hh24:mi:ss')||'" value="'||to_char(a.dt_inicio, 'dd/mm/yyyy hh24:mi:ss')||'"/></td>');
					htp.p('<td class="ctb_col_dh">                                <input disabled title="'||to_char(a.dt_fim,    'dd/mm/yyyy hh24:mi:ss')||'" value="'||to_char(a.dt_fim,    'dd/mm/yyyy hh24:mi:ss')||'"/></td>');
					htp.p('<td class="ctb_col_dh">                                <input disabled title="'||to_char(ws_dhi_ins,  'dd/mm/yyyy hh24:mi:ss')||'" value="'||to_char(ws_dhi_ins,  'dd/mm/yyyy hh24:mi:ss')||'"/></td>');
					htp.p('<td class="ctb_col_dh">                                <input disabled title="'||to_char(ws_dhf_ins,  'dd/mm/yyyy hh24:mi:ss')||'" value="'||to_char(ws_dhf_ins,  'dd/mm/yyyy hh24:mi:ss')||'"/></td>');
					htp.p('<td class="ctb_status">'||ctb.prn_a_status(a.status)||'</td>');
					htp.p('<td><input class="zoom_column" readonly value="'||ws_ds_log||'" onclick="modal_txt_sup(event,this.value);"/></td>');
				htp.p('</tr>');						
			end loop; 	
			
		htp.p('</tbody>');
	htp.p('</table>');	
	
	htp.p('<div id="modal-txt" class="modal-txt"></div>');
	htp.p('<div id="modal-box" style="display: contents;"></div>');
end ctb_acoes_exec_list;  


procedure ctb_acoes_exec_comando (prm_id_agendamento  varchar2, 
                         	      prm_coluna 	      varchar2) as 
    ws_comando        clob;
	ws_titulo         varchar2(100);
	ws_title          varchar2(4000); 
	ws_erro           varchar2(200); 
	ws_onkeypress     varchar2(1000); 
	ws_htp_salvar     varchar2(32000); 
	ws_htp_fechar     varchar2(1000); 
	ws_raise_erro     exception; 
begin

	begin 
		select decode(prm_coluna, 'COMANDO',comando, 'COMANDO_LIMPAR', comando_limpar) into ws_comando    
	  	  from ctb_acoes_exec
	     where id_agendamento  = prm_id_agendamento;
	exception when others then 
		ws_erro := 'Erro obtendo comando, feche a tela e abra novamente.';
		raise ws_raise_erro;	 
	end; 	

	if prm_coluna = 'COMANDO_LIMPAR' then 
		ws_titulo := 'COMANDO LIMPEZA';
	else 
		ws_titulo := prm_coluna;
	end if;	

	ws_htp_fechar     := '<a class="addpurple" onclick="document.getElementById(''modal'||prm_id_agendamento||''').classList.remove(''expanded''); setTimeout(function(){ document.getElementById(''modal'||prm_id_agendamento||''').remove(); }, 200);">FECHAR</a>'; 

	htp.p('<div class="modal" style="overflow: auto;" id="modal'||prm_id_agendamento||'">');
       	htp.p('<h2 style="font-family: var(--fonte-secundaria); font-size: 20px; margin: 10px 5px 5px; padding: 10px 0px 5px 0px;">'||ws_titulo||'</h2>');

		htp.p('<div id="modal-input-text" style="overflow: auto;" class="ace_editor ace-tm" contenteditable="true" onkeypress="var tamanho = this.innerHTML.toString().length; if(tamanho > 32000){ event.preventDefault(); return false;  };">'||ws_comando||'</div>');
		htp.p('<div style="display: flex; width: 70%; margin: 0 auto;">');
			htp.p(ws_htp_fechar);
		htp.p('</div>');			

	htp.p('</div>');
exception 
	when ws_raise_erro then 
		htp.p('ERRO|'||ws_erro);

end ctb_acoes_exec_comando;


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_docs_list (prm_id_run_acao  varchar2,
					     prm_linhas	      varchar2 default '50') as 
	cursor c1 is  
		select * from (
			select name, id_acao, doc_size, last_updated, status, ds_erro, blob_content, dt_inicio, dt_fim     
			from ctb_docs tm
			where id_run_acao = prm_id_run_acao
			order by last_updated desc 
		)
        where rownum <= (CASE WHEN prm_linhas = 'TODAS' THEN 999999 ELSE TO_NUMBER(prm_linhas) END);

	ws_ds_log       clob; 
	ws_dados_doc    clob; 
	ws_svg_dados    varchar2(4000); 
	ws_erro         varchar2(500);
begin
	ws_svg_dados := fun.ret_svg('data_download'); 

	htp.p('<div id="searchbar" data-stop="S">');
		htp.p('<label>Filtrar linhas</label>');
		htp.p('<select id="searchbar" onchange="carregaTelasup(''ctb_docs_list'', ''prm_id_run_acao='||prm_id_run_acao||'&prm_linhas=''+this.value, ''CTB'', ''none'','''','''','''');">');
			for a in (select '50'    id, '50 linhas'  ds from dual union all
					  select '100'   id, '100 linhas' ds from dual union all
					  select '250'   id, '250 linhas' ds from dual union all
					  select '500'   id, '500 linhas' ds from dual union all
					  select 'TODAS' id, 'TODAS'      ds from dual ) loop 
				if prm_linhas = a.id then
					htp.p('<option selected value="'||a.id||'">'||a.ds||'</option>');
				else
					htp.p('<option value="'||a.id||'">'||a.ds||'</option>');
				end if;
			end loop; 
		htp.p('</select>');
	htp.p('</div>');


	htp.p('<input type="hidden" id="content-atributos" data-refresh="ctb_docs_list" data-refresh-ativo="S" data-pkg="ctb" data-par-col="prm_id_run_acao|prm_linhas" data-par-val="'||prm_id_run_acao||'|'||prm_linhas||'">');

	htp.p('<h2>LOG DE ATUALIZA&Ccedil;&Atilde;O DAS TABELAS DE DESTINO</h2>');

	htp.p('<table class="linha">');
		htp.p('<thead>');
			htp.p('<tr>');
				HTP.P('<th title="Nome do arquivo de dados">' 						 ||FUN.LANG('NOME')||'</th>');
				HTP.P('<th title="Tamando do arquivo de dados em bytes">'            ||FUN.LANG('TAMANHO')||'</th>');
				HTP.P('<th title="Data e hora da recep&ccedil;&atilde;o dos dados">' ||FUN.LANG('RECEP&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th title="Inicio da inser&ccedil;&atilde;o.">'               ||FUN.LANG('INICIO INSER&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th title="Fim da inser&ccedil;&atilde;o">'            		 ||FUN.LANG('FIM INSER&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th title="Situa&ccedil;&atilde;o da a&ccedil;&atilde;o">'    ||FUN.LANG('SITUA&Ccedil;&Atilde;O')||'</th>');				
				HTP.P('<th title="Descri&ccedil;&atilde;o Erro">'                    ||FUN.LANG('RETORNO EXECU&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th></th>');
			htp.p('</tr>');
		htp.p('</thead>');

		htp.p('<tbody id="ajax" >');
			for a in c1 loop
				ws_ds_log    := replace(fun.html_trans(a.ds_erro),chr(10),'<br>');
				ws_dados_doc := ctb.b2c(a.blob_content);
				if ws_dados_doc is null or length(ws_dados_doc) = 0 then 
					ws_dados_doc := ' ';
				else 
					if length(ws_dados_doc) > 2000 then 
						ws_dados_doc := substr(ws_dados_doc,1,2000);
						ws_dados_doc := replace(fun.html_trans(ws_dados_doc),chr(10),'<br>')||'<br> ...';
					else
						ws_dados_doc := replace(fun.html_trans(ws_dados_doc),chr(10),'<br>');
					end if; 	
				end if; 


				htp.p('<tr>');
					htp.p('<td class="ctb_col_ds_acao" style="width: 130px;">     <input disabled title="'||a.name||'" value="'||a.name||'"/></td>');					
					htp.p('<td class="ctb_col_tamanho">   	   				      <input disabled title="'||a.doc_size||'" value="'||a.doc_size||'"/></td>');					
					htp.p('<td class="ctb_col_dh">                                <input disabled title="'||to_char(a.last_updated,'dd/mm/yyyy hh24:mi:ss')||'" value="'||to_char(a.last_updated,'dd/mm/yyyy hh24:mi:ss')||'"/></td>');
					htp.p('<td class="ctb_col_dh">                                <input disabled title="'||to_char(a.dt_inicio,'dd/mm/yyyy hh24:mi:ss')||'" value="'||to_char(a.dt_inicio,'dd/mm/yyyy hh24:mi:ss')||'"/></td>');
					htp.p('<td class="ctb_col_dh">                                <input disabled title="'||to_char(a.dt_fim,   'dd/mm/yyyy hh24:mi:ss')||'" value="'||to_char(a.dt_fim,   'dd/mm/yyyy hh24:mi:ss')||'"/></td>');										
					htp.p('<td class="ctb_status">'||ctb.prn_a_status(a.status)||'</td>');
					htp.p('<td>'); 
						htp.p('<input class="zoom_column" readonly value="'||ws_ds_log||'" onclick="modal_txt_sup(event,this.value);"/>'); 
					htp.p('</td>');
					htp.p('<td class="ctb_atalho" title="Parte inicial do conte&uacute;do do arquivo" style="width: 30px;" onclick="modal_txt_sup(event,this.children[0].value,''top-center'');">');
						htp.p('<input type="hidden" value="'||ws_dados_doc||'" />');
						htp.p(ws_svg_dados);
					htp.p('</td>');

				htp.p('</tr>');						
			end loop; 	
			
		htp.p('</tbody>');
	htp.p('</table>');	
	
	htp.p('<div id="modal-txt" class="modal-txt"></div>');
exception 
	when others then 	
		ws_erro	:= 'Erro montando tela, verique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_docs_list (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;	
end ctb_docs_list;  


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_list (prm_order       varchar2 default '2', 
                        prm_dir         varchar2 default '1') as 
    
    ws_id_cliente      varchar2(50);

	cursor c1 is  
		select ru.id_cliente||'-'||cl.nm_cliente cliente, ru.id_cliente, ru.ID_RUN, ru.ds_run, ru.dt_cadastro, ru.last_run, ru.last_status, ru.st_ativo 
          from ctb_clientes cl, ctb_run ru 
         where cl.id_cliente = ru.id_cliente 
           --and ru.id_cliente = decode(ws_id_cliente,'TODOS',ru.id_cliente, ws_id_cliente) 
		   and ru.id_cliente in (select id_cliente from ctb_usuario_cliente where cd_usuario = gbl.getusuario() and id_selecionado = 'S' ) 
	  order by case when prm_dir = '1' then decode(prm_order, '1', ru.id_cliente, '2', ID_RUN, '3', ds_run, '4', to_char(dt_cadastro,'YYMMDDHH24MI'), '5', st_ativo, '6', to_char(last_run, 'YYMMDDHH24MI'), '7', last_status, ds_run) end asc,
			   case when prm_dir = '2' then decode(prm_order, '1', ru.id_cliente, '2', ID_RUN, '3', ds_run, '4', to_char(dt_cadastro,'YYMMDDHH24MI'), '5', st_ativo, '6', to_char(last_run, 'YYMMDDHH24MI'), '7', last_status, ds_run) end desc ; 

	ws_eventoGravar    varchar2(2000); 
	ws_evento          varchar2(2000); 
    ws_eventoOrdem     varchar2(2000); 
    ws_nm_cliente      varchar2(200);
	ws_dir             number := 1;
	ws_msg_cancel      varchar2(4000);
	ws_status          varchar2(30); 
begin 
	ws_eventoGravar := ' "requestDefault(''ctb_run_update'', ''prm_ID_RUN=#ID#&prm_cd_parametro=#CAMPO#&prm_conteudo=''+#VALOR#,this,#VALOR#,'''',''CTB'');"'; 
    ws_eventoOrdem  := 'var dir = order('''', ''ajax''); ajax(''list'', ''ctb_run_list'', ''prm_order=#ORDER#&prm_dir=''+dir, false, ''content'','''','''',''CTB'');'; 
	
    htp.p('<input type="hidden" id="content-atributos" data-refresh="ctb_run_list" data-pkg="ctb">');

	ctb.ctb_usua_clie_lista(gbl.getusuario(), 'ctb_run_list');

	htp.p('<table class="linha">');
		htp.p('<thead>');
			htp.p('<tr>');
				htp.p('<th title="Cliente">                               <a class="red" onclick="'||replace(ws_eventoOrdem,'#ORDER#',1)||'">'||fun.lang('CLIENTE')||'</a></th>');
				htp.p('<th title="ID da tarefa">                          <a class="red" onclick="'||replace(ws_eventoOrdem,'#ORDER#',2)||'">'||fun.lang('ID_TAREFA')||'</a></th>');
				htp.p('<th title="Nome da tarefa">                        <a class="red" onclick="'||replace(ws_eventoOrdem,'#ORDER#',3)||'">'||fun.lang('NOME TAREFA')||'</a></th>');
				htp.p('<th title="Data da cria&ccedil;&atlde;o da tarefa"><a class="red" onclick="'||replace(ws_eventoOrdem,'#ORDER#',4)||'">'||fun.lang('CRIA&Ccedil;&Atilde;O')||'</a></th>');
				htp.p('<th title="Situa&ccedil;&atlde;o da tarefa">       <a class="red" onclick="'||replace(ws_eventoOrdem,'#ORDER#',5)||'">'||fun.lang('ATIVA')||'</a></th>');
				htp.p('<th title="&Uacute;ltima execu&ccedil;&atlde;o">   <a class="red" onclick="'||replace(ws_eventoOrdem,'#ORDER#',6)||'">'||fun.lang('&Uacute;LTIMA EXEC.')||'</a></th>');
				htp.p('<th title="Situa&ccedil;&atlde;o da &uacute;ltima execu&ccedil;&atlde;o" style="text-align: center;width: 100px;">');
					htp.p('<a class="red" onclick="'||replace(ws_eventoOrdem,'#ORDER#',7)||'">'||fun.lang('SITUA&Ccedil;&Atilde;O')||'</a>');
				htp.p('</th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
				htp.p('<th></th>');
				htp.p('<th></th>');				
			htp.p('</tr>');
		htp.p('</thead>');

		if to_number(prm_dir) = 1 then
			ws_dir := 2;
		end if;

		htp.p('<tbody id="ajax" data-dir="'||ws_dir||'">');

			for a in c1 loop 

				ws_evento := replace(ws_eventoGravar,'#ID#',a.ID_RUN); 
				htp.p('<tr id="'||a.ID_RUN||'">');
					htp.p('<td><input id="prm_id_cliente_'||a.ID_RUN||'" disabled value="'||a.cliente||'" /></td>');                
					htp.p('<td><input id="prm_ID_RUN_'||a.ID_RUN||'" disabled value="'||a.ID_RUN||'" /></td>');
					htp.p('<td><input id="prm_ds_run_'||a.ID_RUN||'" data-min="1" data-default="'||a.ds_run||'" onblur='||replace(replace(ws_evento,'#CAMPO#','DS_RUN'),'#VALOR#','this.value')||' value="'||a.ds_run||'" /></td>');
					htp.p('<td><input id="prm_dt_cadastro_'||a.ID_RUN||'" disabled value="'||to_char(a.dt_cadastro,'DD/MM/YYYY HH24:MI')||'" /></td>');

					htp.p('<td>');
						htp.p('<select  id="st_ativo'||a.ID_RUN||'" onchange='||replace(replace(ws_evento,'#CAMPO#','ST_ATIVO'),'#VALOR#','this.value')||'>');
							for b in (select 'N' opc, 'N&atilde;o' dsc, decode(a.st_ativo,'N', 'selected','') sel from dual union all 
									  select 'S' opc, 'Sim'        dsc, decode(a.st_ativo,'S', 'selected','') sel from dual) loop 
								htp.p('<option value="'||b.opc||'" '||b.sel||'>'||b.dsc||'</option>');
							end loop; 
						htp.p('</select>');
				    htp.p('</td>');

					htp.p('<td><input id="prm_last_run_'||a.ID_RUN||'" disabled value="'||to_char(a.last_run,'DD/MM/YYYY HH24:MI')||'" /></td>');				
					htp.p('<td class="ctb_status">'||ctb.prn_a_status(a.last_status)||'</td>');

					htp.p('<td><div style="width: 1px !important; min-width: 1px !important;"></div></td>');  -- Cria uma divisao 

					htp.p('<td class="ctb_atalho" title="Agenda de execu&ccedil;&otilde;es da tarefa" '||
					      ' onclick="carregaTelasup(''ctb_run_schedule_list'', ''prm_ID_RUN='||a.ID_RUN||''', ''CTB'', ''ctb_run_schedule'','''','''',''ctb_run_list||CTB|ctb_run|||'');">');
						htp.p('<svg height="512pt" width="512pt" viewBox="-34 0 512 512.04955" xmlns="http://www.w3.org/2000/svg"><path d="m.0234375 290.132812c-.02734375 121.429688 97.5703125 220.324219 218.9882815 221.898438 121.421875 1.574219 221.550781-94.753906 224.671875-216.144531 3.125-121.386719-91.917969-222.734375-213.257813-227.40625v-17.28125h17.066407c14.136718 0 25.597656-11.460938 25.597656-25.597657 0-14.140624-11.460938-25.601562-25.597656-25.601562h-51.199219c-14.140625 0-25.601563 11.460938-25.601563 25.601562 0 14.136719 11.460938 25.597657 25.601563 25.597657h17.066406v17.28125c-119.054687 4.707031-213.183594 102.507812-213.3359375 221.652343zm187.7343745-264.53125c0-4.714843 3.820313-8.535156 8.535157-8.535156h51.199219c4.710937 0 8.53125 3.820313 8.53125 8.535156 0 4.710938-3.820313 8.53125-8.53125 8.53125h-51.199219c-4.714844 0-8.535157-3.820312-8.535157-8.53125zm238.933594 264.53125c0 113.109376-91.691406 204.800782-204.800781 204.800782-113.105469 0-204.800781-91.691406-204.800781-204.800782 0-113.105468 91.695312-204.800781 204.800781-204.800781 113.054687.132813 204.667969 91.746094 204.800781 204.800781zm0 0"/><path d="m315.3125 127.402344c-57.828125-33.347656-129.046875-33.347656-186.878906 0-.136719.070312-.296875.070312-.441406.144531-.148438.078125-.214844.222656-.351563.308594-28.179687 16.4375-51.625 39.882812-68.0625 68.0625-.085937.136719-.222656.210937-.304687.347656-.085938.136719-.078126.300781-.148438.445313-33.347656 57.828124-33.347656 129.050781 0 186.878906.070312.144531.070312.300781.148438.445312.074218.144532.289062.347656.417968.535156 16.429688 28.097657 39.835938 51.472657 67.949219 67.875.136719.085938.214844.222657.351563.308594.136718.085938.433593.160156.648437.265625 57.714844 33.175781 128.71875 33.175781 186.433594 0 .214843-.105469.445312-.148437.648437-.265625.207032-.121094.214844-.222656.351563-.308594 28.117187-16.410156 51.523437-39.800781 67.949219-67.90625.128906-.1875.300781-.335937.417968-.539062.121094-.203125.078125-.296875.148438-.445312 33.347656-57.828126 33.347656-129.046876 0-186.878907-.070313-.144531-.070313-.296875-.148438-.441406-.074218-.148437-.21875-.214844-.304687-.34375-16.433594-28.183594-39.882813-51.632813-68.0625-68.070313-.136719-.085937-.214844-.222656-.351563-.308593-.136718-.082031-.261718-.039063-.410156-.109375zm49.777344 70.203125-7.050782 4.070312c-2.660156 1.515625-4.308593 4.339844-4.3125 7.402344-.007812 3.058594 1.625 5.890625 4.28125 7.417969 2.65625 1.523437 5.925782 1.507812 8.566407-.039063l7.058593-4.078125c11.027344 21.488282 17.332032 45.09375 18.488282 69.222656h-25.164063c-4.710937 0-8.53125 3.820313-8.53125 8.53125 0 4.714844 3.820313 8.535157 8.53125 8.535157h25.164063c-1.15625 24.128906-7.460938 47.730469-18.488282 69.222656l-7.058593-4.082031c-2.640625-1.546875-5.910157-1.5625-8.566407-.035156-2.65625 1.523437-4.289062 4.355468-4.28125 7.417968.003907 3.0625 1.652344 5.886719 4.3125 7.398438l7.050782 4.070312c-13.140625 20.265625-30.40625 37.53125-50.671875 50.671875l-4.070313-7.050781c-1.511718-2.660156-4.335937-4.308594-7.398437-4.3125-3.0625-.007812-5.894531 1.625-7.417969 4.28125-1.527344 2.65625-1.511719 5.925781.035156 8.566406l4.082032 7.058594c-21.492188 11.027344-45.09375 17.332031-69.222657 18.488281v-25.164062c0-4.710938-3.820312-8.53125-8.535156-8.53125-4.710937 0-8.53125 3.820312-8.53125 8.53125v25.164062c-24.128906-1.15625-47.734375-7.460937-69.222656-18.488281l4.078125-7.058594c1.546875-2.640625 1.5625-5.910156.039062-8.566406-1.527344-2.65625-4.359375-4.289062-7.417968-4.28125-3.0625.003906-5.886719 1.652344-7.402344 4.3125l-4.070313 7.050781c-20.265625-13.140625-37.53125-30.40625-50.667969-50.671875l7.046876-4.070312c2.660156-1.511719 4.308593-4.335938 4.316406-7.398438.007812-3.0625-1.628906-5.894531-4.285156-7.417968-2.652344-1.527344-5.921876-1.511719-8.566407.035156l-7.054687 4.082031c-11.03125-21.492187-17.335938-45.09375-18.492188-69.222656h25.164063c4.714843 0 8.535156-3.820313 8.535156-8.535157 0-4.710937-3.820313-8.53125-8.535156-8.53125h-25.164063c1.15625-24.128906 7.460938-47.734374 18.492188-69.222656l7.054687 4.078125c2.644531 1.546875 5.914063 1.5625 8.566407.039063 2.65625-1.527344 4.292968-4.359375 4.285156-7.417969-.007813-3.0625-1.65625-5.886719-4.316406-7.402344l-7.046876-4.070312c13.136719-20.265625 30.402344-37.53125 50.667969-50.671875l4.070313 7.050781c1.515625 2.660156 4.339844 4.308594 7.402344 4.316406 3.058593.003907 5.890624-1.628906 7.417968-4.285156 1.523438-2.65625 1.507813-5.921875-.039062-8.566406l-4.078125-7.054688c21.488281-11.03125 45.09375-17.335937 69.222656-18.492187v25.164062c0 4.714844 3.820313 8.535156 8.53125 8.535156 4.714844 0 8.535156-3.820312 8.535156-8.535156v-25.164062c24.128907 1.15625 47.730469 7.460937 69.222657 18.492187l-4.082032 7.054688c-1.546875 2.644531-1.5625 5.910156-.035156 8.566406 1.523438 2.65625 4.355469 4.289063 7.417969 4.285156 3.0625-.007812 5.886719-1.65625 7.398437-4.316406l4.070313-7.050781c20.265625 13.140625 37.53125 30.40625 50.671875 50.671875zm0 0"/><path d="m230.425781 266.101562v-86.902343c0-4.710938-3.820312-8.53125-8.535156-8.53125-4.710937 0-8.53125 3.820312-8.53125 8.53125v86.902343c-11.757813 4.15625-18.808594 16.179688-16.699219 28.46875 2.109375 12.285157 12.761719 21.269532 25.230469 21.269532s23.125-8.984375 25.230469-21.269532c2.109375-12.289062-4.941406-24.3125-16.695313-28.46875zm-8.535156 32.566407c-4.710937 0-8.53125-3.820313-8.53125-8.535157 0-4.710937 3.820313-8.53125 8.53125-8.53125 4.714844 0 8.535156 3.820313 8.535156 8.53125 0 4.714844-3.820312 8.535157-8.535156 8.535157zm0 0"/></svg>');						
					htp.p('</td>');

					htp.p('<td class="ctb_atalho" title="Lista de A&ccedil;&otilde;es" '||
							  ' onclick="carregaTelasup(''ctb_run_acoes_list'', ''prm_ID_RUN='||a.ID_RUN||''', ''CTB'', ''ctb_run_acoes'','''','''',''ctb_run_list||CTB|ctb_run|||'');">');
						htp.p('<svg style="height: 30px; width: 30px;" viewBox="0 0 24 24" clip-rule="evenodd" fill-rule="evenodd" stroke-linejoin="round" stroke-miterlimit="2" xmlns="http://www.w3.org/2000/svg"><path d="m21 4c0-.478-.379-1-1-1h-16c-.62 0-1 .519-1 1v16c0 .621.52 1 1 1h16c.478 0 1-.379 1-1zm-16.5.5h15v15h-15zm13.5 10.75c0-.414-.336-.75-.75-.75h-4.5c-.414 0-.75.336-.75.75s.336.75.75.75h4.5c.414 0 .75-.336.75-.75zm-11.772-.537 1.25 1.114c.13.116.293.173.455.173.185 0 .37-.075.504-.222l2.116-2.313c.12-.131.179-.296.179-.459 0-.375-.303-.682-.684-.682-.185 0-.368.074-.504.221l-1.66 1.815-.746-.665c-.131-.116-.293-.173-.455-.173-.379 0-.683.307-.683.682 0 .188.077.374.228.509zm11.772-2.711c0-.414-.336-.75-.75-.75h-4.5c-.414 0-.75.336-.75.75s.336.75.75.75h4.5c.414 0 .75-.336.75-.75zm-11.772-1.613 1.25 1.114c.13.116.293.173.455.173.185 0 .37-.074.504-.221l2.116-2.313c.12-.131.179-.296.179-.46 0-.374-.303-.682-.684-.682-.185 0-.368.074-.504.221l-1.66 1.815-.746-.664c-.131-.116-.293-.173-.455-.173-.379 0-.683.306-.683.682 0 .187.077.374.228.509zm11.772-1.639c0-.414-.336-.75-.75-.75h-4.5c-.414 0-.75.336-.75.75s.336.75.75.75h4.5c.414 0 .75-.336.75-.75z"/></svg>');
					htp.p('</td>');

					htp.p('<td class="ctb_atalho" title="Par&acirc;metros utilizados nas a&ccedil;&otilde;es da tarefa" '||
							  ' onclick="carregaTelasup(''ctb_run_param_list'', ''prm_ID_RUN='||a.ID_RUN||''', ''CTB'', ''none'','''','''',''ctb_run_list||CTB|ctb_run|||'');">');
						htp.p('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M6 18h-2v5h-2v-5h-2v-3h6v3zm-2-17h-2v12h2v-12zm11 7h-6v3h2v12h2v-12h2v-3zm-2-7h-2v5h2v-5zm11 14h-6v3h2v5h2v-5h2v-3zm-2-14h-2v12h2v-12z"/></svg>');
					htp.p('</td>');

					htp.p('<td class="ctb_atalho" title="Executar a tarefa manualmente uma &uacute;nica vez" '||
						  ' onclick="if(!confirm(''Confirma a execu\u00e7\u00e3o da tarefa?'')){ return false; }  call(''ctb_run_exec'', ''prm_ID_RUN='||a.ID_RUN||''', ''CTB'').then(function(resposta){ alerta('''',resposta.split(''|'')[1]); if (resposta.split(''|'')[0] == ''OK'') {ajax(''list'', ''ctb_run_list'', '''', true, ''content'','''','''',''CTB''); } });">');
						htp.p('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2c5.514 0 10 4.486 10 10s-4.486 10-10 10-10-4.486-10-10 4.486-10 10-10zm0-2c-6.627 0-12 5.373-12 12s5.373 12 12 12 12-5.373 12-12-5.373-12-12-12zm-3 17v-10l9 5.146-9 4.854z"/></svg>');
					htp.p('</td>');

					ws_msg_cancel := 'Aten\u00e7\u00e3o! Se a tarefa possui a\u00e7\u00f5es j\u00e1 enviadas para o Agente, o Agente concluir\u00e1 a extra\u00e7\u00e3o, por\u00e9m o conte\u00fado extra\u00eddo n\u00e3o ser\u00e1 atualizado na tabela de destino.'||
					                 '\nAs a\u00e7\u00f5es j\u00e1 em processo de atualiza\u00e7\u00e3o da tabela de destino, n\u00e3o ser\u00e3o canceladas.'||
									 '\n\nDeseja realmente cancelar a execu\u00e7\u00e3o da Tarefa?'; 
					htp.p('<td class="ctb_atalho" title="Cancelar a execu&ccedil;&atilde;o atual" '||
						  ' onclick="if(!confirm('''||ws_msg_cancel ||''')){ return false; } call(''ctb_run_stop'', ''prm_ID_RUN='||a.ID_RUN||''', ''CTB'').then(function(resposta){ alerta('''',resposta.split(''|'')[1]); if (resposta.split(''|'')[0] == ''OK'') {ajax(''list'', ''ctb_run_list'', '''', true, ''content'','''','''',''CTB''); } });">');
						htp.p('<svg viewBox="0 0 512 512"> <g><g><path d="M256,0C114.609,0,0,114.609,0,256c0,141.391,114.609,256,256,256c141.391,0,256-114.609,256-256C512,114.609,397.391,0,256,0z M256,472c-119.297,0-216-96.703-216-216S136.703,40,256,40s216,96.703,216,216S375.297,472,256,472z"/><rect x="176" y="176" width="160" height="160"/></g></g></svg>');
					htp.p('</td>');

					htp.p('<td class="ctb_atalho" title="Log de execu&ccedil;&atilde;o do agente." '||
					      ' onclick="carregaTelasup(''ctb_acoes_exec_list'', ''prm_tp=RUN&prm_id='||a.ID_RUN||''', ''CTB'', ''none'','''','''',''ctb_run_list||CTB|ctb_run|||'');">');
						htp.p('<svg viewBox="0 0 600 600" xml:space="preserve"><g><path d="M486.201,196.124h-13.166V132.59c0-0.396-0.062-0.795-0.115-1.196c-0.021-2.523-0.825-5-2.552-6.963L364.657,3.677 c-0.033-0.031-0.064-0.042-0.085-0.073c-0.63-0.707-1.364-1.292-2.143-1.795c-0.229-0.157-0.461-0.286-0.702-0.421 c-0.672-0.366-1.387-0.671-2.121-0.892c-0.2-0.055-0.379-0.136-0.577-0.188C358.23,0.118,357.401,0,356.562,0H96.757 C84.894,0,75.256,9.651,75.256,21.502v174.613H62.092c-16.971,0-30.732,13.756-30.732,30.733v159.812 c0,16.968,13.761,30.731,30.732,30.731h13.164V526.79c0,11.854,9.638,21.501,21.501,21.501h354.776 c11.853,0,21.501-9.647,21.501-21.501V417.392h13.166c16.966,0,30.729-13.764,30.729-30.731V226.854 C516.93,209.872,503.167,196.124,486.201,196.124z M96.757,21.502h249.054v110.009c0,5.939,4.817,10.75,10.751,10.75h94.972v53.861 H96.757V21.502z M317.816,303.427c0,47.77-28.973,76.746-71.558,76.746c-43.234,0-68.531-32.641-68.531-74.152 c0-43.679,27.887-76.319,70.906-76.319C293.389,229.702,317.816,263.213,317.816,303.427z M82.153,377.79V232.085h33.073v118.039 h57.944v27.66H82.153V377.79z M451.534,520.962H96.757v-103.57h354.776V520.962z M461.176,371.092 c-10.162,3.454-29.402,8.209-48.641,8.209c-26.589,0-45.833-6.698-59.24-19.664c-13.396-12.535-20.75-31.568-20.529-52.967 c0.214-48.436,35.448-76.108,83.229-76.108c18.814,0,33.292,3.688,40.431,7.139l-6.92,26.37 c-7.999-3.457-17.942-6.268-33.942-6.268c-27.449,0-48.209,15.567-48.209,47.134c0,30.049,18.807,47.771,45.831,47.771 c7.564,0,13.623-0.852,16.21-2.152v-30.488h-22.478v-25.723h54.258V371.092L461.176,371.092z"></path><path d="M212.533,305.37c0,28.535,13.407,48.64,35.452,48.64c22.268,0,35.021-21.186,35.021-49.5 c0-26.153-12.539-48.655-35.237-48.655C225.504,255.854,212.533,277.047,212.533,305.37z"></path></g></svg>');
					htp.p('</td>');

					htp.p('<td>');
						fcl.button_lixo('ctb_run_delete','prm_ID_RUN', a.ID_RUN, prm_tag => 'a', prm_pkg => 'CTB');
					htp.p('</td>');
				htp.p('</tr>');						
			end loop; 	
			
		htp.p('</tbody>');
	htp.p('</table>');	
end ctb_run_list; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_insert (prm_id_cliente  varchar2, 
                          prm_ds_run   varchar2) as 
	ws_ID_RUN   varchar2(50); 
	ws_count    integer; 
	ws_erro     varchar2(300); 
	raise_erro  exception;
begin 

	if prm_id_cliente = 'TODOS' then  
		ws_erro := 'Para inclus&atilde;o &eacute; necess&aacute;rio que uma empresa seja selecionada'; 
        raise raise_erro;
	end if; 

	select count(*) into ws_count from ctb_run where ds_run = trim(prm_ds_run);
	if ws_count > 0 then 
		ws_erro := 'J&aacute; existe uma tarefa com esse nome'; 
		raise raise_erro;
	end if; 	
	--
	ws_ID_RUN := 'RUN_'||to_char(sysdate,'yymmddhh24miss')||'_'||round(dbms_random.value(10,99));
	--
	insert into ctb_run       (id_cliente, ID_RUN, ds_run, dt_cadastro, st_ativo) values (prm_id_cliente, ws_ID_RUN, trim(prm_ds_run), sysdate, 'N' );  -- Cria como INATIVO
	commit; 			  
	--insert into ctb_run_param (ID_RUN, cd_parametro, conteudo, st_ativo) values (ws_ID_RUN, 'MINUTO_ESPERA', 30,'S'); 
	--insert into ctb_run_param (ID_RUN, cd_parametro, conteudo, st_ativo) values (ws_ID_RUN, 'MINUTO_ESPERA_PLSQL', 180,'S');   -- 3 horas
	ctb.ctb_run_param_atu(ws_ID_RUN);
	--
	htp.p('OK|Registro inserido');
exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro inserindo registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_insert (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_insert; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_update ( prm_ID_RUN       varchar2, 
                           prm_cd_parametro  varchar2,
						   prm_conteudo      varchar2 ) as 
	ws_parametro varchar2(4000);
	ws_conteudo  varchar2(32000); 
	ws_erro      varchar2(300); 
	ws_vl_old    varchar2(4000);
	raise_erro   exception;
begin 
	ws_parametro := upper(trim(prm_cd_parametro)); 
	ws_conteudo  := trim(prm_conteudo); 

    if ws_parametro in ('DS_RUN') and ws_conteudo is null then 
		ws_erro := 'Nome da tarefa deve ser preenchido';
		raise raise_erro; 
	end if; 	

	execute immediate 'select substr(max('||ws_parametro||'),1,3990) from ctb_run where id_run = :id_run' into ws_vl_old using in prm_id_run;

	update ctb_run  
	   set ds_run   = decode(ws_parametro, 'DS_RUN',   ws_conteudo, ds_run),
	       st_ativo = decode(ws_parametro, 'ST_ATIVO', ws_conteudo, st_ativo)
	 where ID_RUN = prm_ID_RUN; 
	if sql%notfound then 
		ws_erro := 'N&atilde;o localizada tarefa com o ID ['||prm_ID_RUN||'], recarrega a tela e tente novamente'; 
		raise raise_erro; 
	end if;  	    

	fun.bi_log_alt_insere('U','CTB_RUN', prm_id_run, ws_parametro, sysdate, gbl.getusuario(), ws_vl_old, substr(ws_conteudo,1,3990)); 
	
	commit; 
	htp.p('OK|Registro alterado');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro alterando registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_update (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_update;


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_delete (prm_ID_RUN varchar2 ) as 
	ws_count    integer; 
	ws_erro     varchar2(300); 
	raise_erro  exception; 							   
begin 

	select count(*) into ws_count from ctb_run_acoes where ID_RUN = prm_ID_RUN; 
	if ws_count > 0 then 
		ws_erro := 'Existem a&ccedil;&otilde;es para essa tarefa, primeiro exclua as ac&otilde;es da tarefa'; 
		raise raise_erro; 
	end if; 

	select count(*) into ws_count from ctb_run_schedule where ID_RUN = prm_ID_RUN; 
	if ws_count > 0 then 
		ws_erro := 'Existem agendamento para essa tarefa, primeiro exclua os agendamentos de execu&ccedil;&atilde;o dessa tarefa'; 
		raise raise_erro; 
	end if; 	

	delete ctb_run       where ID_RUN = prm_ID_RUN ;
	delete ctb_run_param where ID_RUN = prm_ID_RUN ;
	fun.bi_log_alt_insere('D','CTB_RUN', prm_id_run, null, sysdate, gbl.getusuario(), null, null); 

	commit;  
	htp.p('OK|Registro exclu&iacute;do');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro excluindo registro, verique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_delete (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_delete; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_schedule_list(prm_ID_RUN     varchar2) as 

	cursor c_lista (p_cd_lista varchar2, p_valores varchar2) is  
	select listagg(ds_abrev,', ') within group (order by nr_ordem) 
      from bi_lista_padrao 
     where cd_lista = p_cd_lista 
       and cd_item in (select column_value from table(fun.vpipe(p_valores)) ) ; 

    ws_eventoVerificar  varchar2(2000); 
	ws_eventoGravar     varchar2(2000); 
	ws_desc             varchar2(400);  

begin 
    ws_eventoVerificar  := 'if(document.getElementById(this.parentNode.parentNode.id+''#CAMPO#'').title.length > 0){if(confirm(''Deseja substituir o agendamento de Dias #DOCAMPO1# para Dias #DOCAMPO2#?'' )){document.getElementById(this.parentNode.parentNode.id+''#CAMPO#'').title = '''';document.getElementById(this.parentNode.parentNode.id+''#CAMPO#'').setAttribute(''data-default'', '''');document.getElementById(this.parentNode.parentNode.id+''#CAMPO#'').children[0].innerHTML = '''';#GRAVAR#} else {carregaTelasup(''ctb_run_schedule_list'', ''prm_ID_RUN='||prm_ID_RUN||''', ''CTB'', ''ctb_run_schedule'','''','''',''ctb_run_list||CTB|ctb_run|||'');}} else {#GRAVAR#}';
	ws_eventoGravar := 'requestDefault(''ctb_run_schedule_update'', ''prm_id_schedule=#ID#&prm_cd_parametro=#CAMPO#&prm_conteudo=''+this.nextElementSibling.title,this,this.nextElementSibling.title,'''',''CTB'', ()=>{carregaTelasup(''ctb_run_schedule_list'', ''prm_ID_RUN='||prm_ID_RUN||''', ''CTB'', ''ctb_run_schedule'','''','''',''ctb_run_list||CTB|ctb_run|||'');});'; 

	htp.p('<input type="hidden" id="content-atributos" data-pkg="ctb" >');
	htp.p('<input type="hidden" id="prm_ID_RUN" value="'||prm_ID_RUN||'">');	

	htp.p('<table class="linha">');

		htp.p('<thead>');
			htp.p('<tr>');
				HTP.P('<th>'||FUN.LANG('DIAS DA SEMANA')||'</th>');
                HTP.P('<th>'||FUN.LANG('DIAS DO M&Ecirc;S')||'</th>');
				HTP.P('<th>'||FUN.LANG('M&Ecirc;S')||'</th>');
				HTP.P('<th>'||FUN.LANG('HORA')||'</th>');
				HTP.P('<th>'||FUN.LANG('INTERVALO DE TEMPO')||'</th>');
                HTP.P('<th></th>');
			htp.p('</tr>');
		htp.p('</thead>');

		htp.p('<tbody id="ajax" >');

			for a in (select * from ctb_run_schedule where ID_RUN = prm_ID_RUN order by id_schedule desc) loop

				htp.p('<tr id="'||a.id_schedule||'">');

					ws_desc := null;
					open  c_lista ('DIA_SEMANA', a.nr_dia_semana);
					fetch c_lista into ws_desc;
					close c_lista; 
					htp.p('<td>');
						htp.p('<a class="script" data-default="'||a.nr_dia_semana||'" onclick="'||replace(replace(replace(replace(ws_eventoVerificar, '#CAMPO#', '-dia_mes'), '#DOCAMPO1#', 'do M&ecirc;s'), '#DOCAMPO2#', 'da Semana'), '#GRAVAR#', replace(replace(ws_eventoGravar,'#CAMPO#','NR_DIA_SEMANA'), '#ID#', a.id_schedule))||'"></a>');
						fcl.fakeoption(a.id_schedule||'-semanas', '', a.nr_dia_semana, 'lista-semanas', 'N', 'S', prm_desc => ws_desc );						
					htp.p('</td>');
					
                    ws_desc := null;
					open  c_lista ('DIA_MES', a.nr_dia_mes);
					fetch c_lista into ws_desc;
					close c_lista; 
					htp.p('<td class="fake-list">');
						htp.p('<a class="script" data-default="'||a.nr_dia_mes||'" onclick="'||replace(replace(replace(replace(ws_eventoVerificar, '#CAMPO#', '-semanas'), '#DOCAMPO1#', 'da Semana'), '#DOCAMPO2#', 'do M&ecirc;s'), '#GRAVAR#', replace(replace(ws_eventoGravar,'#CAMPO#','NR_DIA_MES'), '#ID#', a.id_schedule))||'"></a>');
						fcl.fakeoption(a.id_schedule||'-dia_mes', '', a.nr_dia_mes, 'lista-dia-mes', 'N', 'S', prm_desc => ws_desc);						
					htp.p('</td>');

					ws_desc := null;
					open  c_lista ('MES', a.nr_mes);
					fetch c_lista into ws_desc;
					close c_lista; 
					htp.p('<td class="fake-list" >');
						htp.p('<a class="script" data-default="'||a.nr_mes||'" onclick="'||replace(replace(ws_eventoGravar,'#CAMPO#','NR_MES'), '#ID#', a.id_schedule)||'"></a>');
						fcl.fakeoption(a.id_schedule||'-mes', '', a.nr_mes, 'lista-meses', 'N', 'S', prm_desc => ws_desc, prm_min => 1);
					htp.p('</td>');

					ws_desc := null;
					open  c_lista ('HORA', a.nr_hora);
					fetch c_lista into ws_desc;
					close c_lista;
					htp.p('<td>');
						htp.p('<a class="script" data-default="'||a.nr_hora||'" onclick="'||replace(replace(ws_eventoGravar,'#CAMPO#','NR_HORA'), '#ID#', a.id_schedule)||'"></a>');
						fcl.fakeoption(a.id_schedule||'-horas', '', a.nr_hora, 'lista-horas', 'N', 'S', prm_desc => ws_desc, prm_min => 1);
					htp.p('</td>');

					ws_desc := null;
					open  c_lista ('MINUTO', a.nr_minuto);
					fetch c_lista into ws_desc;
					close c_lista; 
					htp.p('<td>');
						htp.p('<a class="script" data-default="'||a.nr_minuto||'" onclick="'||replace(replace(ws_eventoGravar,'#CAMPO#','NR_MINUTO'), '#ID#', a.id_schedule)||'"></a>');
						fcl.fakeoption(a.id_schedule||'-minutos', '', a.nr_minuto, 'lista-minutos', 'N', 'S', prm_desc => ws_desc, prm_min => 1);
					htp.p('</td>');

					htp.p('<td>');
						fcl.button_lixo('ctb_run_schedule_delete','prm_id_schedule', a.id_schedule, prm_tag => 'a', prm_pkg => 'CTB');
					htp.p('</td>');
				htp.p('</tr>');						
			end loop; 	
			
		htp.p('</tbody>');
	htp.p('</table>');	


end ctb_run_schedule_list; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_schedule_insert (prm_ID_RUN         varchar2,
								   prm_nr_dia_semana  varchar2,
								   prm_nr_dia_mes     varchar2,
							   	   prm_nr_mes         varchar2,
								   prm_nr_hora        varchar2, 
						   		   prm_nr_minuto      varchar2
                               	   ) as 
	ws_id_schedule   number; 
	ws_count         integer; 
	ws_erro          varchar2(300); 
	raise_erro  exception;
begin 

	select count(*) into ws_count from ctb_run where ID_RUN = prm_ID_RUN ; 
	if ws_count = 0 then 
		ws_erro := 'N&atilde;o localizado Tarefa referente a esse agendamento, feche a tela e abra novamente';
		raise raise_erro;
	end if;

    if prm_nr_dia_semana is null and prm_nr_dia_mes is null then
        ws_erro := 'Deve ser informado o Dia da Semana ou o Dia do M&ecirc;s!';
        raise raise_erro;
    elsif prm_nr_dia_semana is not null and prm_nr_dia_mes is not null then
        ws_erro := 'Deve ser informado o Dia da Semana ou o Dia do M&ecirc;s!';
        raise raise_erro;
    end if;

	select nvl(max(to_number(id_schedule)),0)+1 into ws_id_schedule from ctb_run_schedule; 

	insert into ctb_run_schedule (ID_RUN,     id_schedule,    nr_dia_semana,     nr_dia_mes,     nr_mes,     nr_hora,     nr_minuto )
	                      values (prm_ID_RUN, ws_id_schedule, prm_nr_dia_semana, prm_nr_dia_mes, prm_nr_mes, prm_nr_hora, prm_nr_minuto );

	commit; 			  
	htp.p('OK|Registro inserido');

exception 
	when raise_erro then
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro inserindo registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_schedule_insert (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_schedule_insert; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_schedule_update ( prm_id_schedule   varchar2, 
                 	          	    prm_cd_parametro  varchar2,
							   	    prm_conteudo      varchar2 ) as 
	ws_parametro  varchar2(4000);
	ws_conteudo   varchar2(32000); 
    ws_dia_semana varchar2(4000) := null;
    ws_dia_mes    varchar2(4000) := null;
	ws_erro       varchar2(300); 
    ws_count      number;
	ws_vl_old     varchar2(4000);
	raise_erro    exception;

begin 
	ws_parametro := upper(trim(prm_cd_parametro)); 
	ws_conteudo  := prm_conteudo; 

    if ws_conteudo is null and ws_parametro not in ('NR_DIA_MES', 'NR_DIA_SEMANA')then 
		ws_erro := 'Campo deve ser preenchido';
		raise raise_erro; 
    elsif ws_parametro = 'NR_DIA_SEMANA' and ws_conteudo is not null then
        select count(*) into ws_count from ctb_run_schedule
        where id_schedule = prm_id_schedule
        and nr_dia_mes is not null;
        if ws_count > 0 then
            ws_dia_mes    := null;
            ws_dia_semana := ws_conteudo;
        end if;
    elsif ws_parametro = 'NR_DIA_MES' and ws_conteudo is not null then
        select count(*) into ws_count from ctb_run_schedule
        where id_schedule = prm_id_schedule
        and nr_dia_semana is not null;
        if ws_count > 0 then
            ws_dia_semana := null;
            ws_dia_mes    := ws_conteudo;
        end if;
    elsif ws_conteudo is null and ws_parametro = 'NR_DIA_MES'then
        select count(*) into ws_count from ctb_run_schedule
        where id_schedule = prm_id_schedule
        and nr_dia_semana is null;
        if ws_count > 0 then
            ws_erro := 'Deve ser informado o Dia da Semana ou o Dia do M&ecirc;s!';
            raise raise_erro;
        end if;
	elsif ws_conteudo is null and ws_parametro = 'NR_DIA_SEMANA'then
        select count(*) into ws_count from ctb_run_schedule
        where id_schedule = prm_id_schedule
        and nr_dia_mes is null;
        if ws_count > 0 then
            ws_erro := 'Deve ser informado o Dia da Semana ou o Dia do M&ecirc;s!';
            raise raise_erro;
        end if;
    else
        select nr_dia_semana, nr_dia_mes
          into ws_dia_semana, ws_dia_mes
          from ctb_run_schedule
         where id_schedule = prm_id_schedule;
    end if; 	

	execute immediate 'select substr(max('||ws_parametro||'),1,3990) from ctb_run_schedule where id_schedule = :p1' into ws_vl_old using in prm_id_schedule;

	update ctb_run_schedule
	   set nr_dia_semana   = decode(ws_parametro, 'NR_DIA_SEMANA', ws_conteudo, ws_dia_semana ), 
	   	   nr_dia_mes      = decode(ws_parametro, 'NR_DIA_MES',    ws_conteudo, ws_dia_mes ),  
	       nr_mes          = decode(ws_parametro, 'NR_MES',        ws_conteudo, nr_mes     ), 
		   nr_hora         = decode(ws_parametro, 'NR_HORA',       ws_conteudo, nr_hora    ), 
		   nr_minuto       = decode(ws_parametro, 'NR_MINUTO',     ws_conteudo, nr_minuto  )
	 where id_schedule = prm_id_schedule; 
	if sql%notfound then 
		ws_erro := 'N&atilde;o localizado agendamento com esse ID, recarrega a tela e tente novamente'; 
		raise raise_erro; 
	end if;  	    

	fun.bi_log_alt_insere('U', 'CTB_RUN_SCHEDULE', prm_id_schedule,  ws_parametro, sysdate, gbl.getusuario(), ws_vl_old, substr(ws_conteudo,1,3900) ); 

	commit; 
	htp.p('OK|Registro alterado');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro alterando registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_schedule_update (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_schedule_update;



----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_schedule_delete (prm_id_schedule varchar2 ) as 
	ws_count    integer; 
	ws_erro     varchar2(300); 
	raise_erro  exception; 							   
begin 

	delete ctb_run_schedule where id_schedule = prm_id_schedule ;
	fun.bi_log_alt_insere('D','CTB_RUN_SCHEDULE', prm_id_schedule, null, sysdate, gbl.getusuario(), null, null); 

	commit;  
	htp.p('OK|Registro exclu&iacute;do');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro excluindo registro, verifique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_schedule_delete (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_schedule_delete; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_acoes_list(prm_ID_RUN     varchar2) as 

	cursor c_acoes is 
	select ru.id_cliente, rc.ID_RUN, rc.id_run_acao, rc.ordem, rc.id_acao, ac.id_sistema, ac.id_tipo_banco, rc.id_conexao, rc.tbl_destino, dt_inicio, dt_fim, rc.status 
	  from ctb_acoes ac, ctb_run_acoes rc, ctb_run ru 
	 where ac.id_acao(+)    = rc.id_acao 
	   and ac.id_cliente(+) = rc.id_cliente
	   and rc.ID_RUN     = ru.ID_RUN
	   and ru.ID_RUN     = prm_ID_RUN order by ordem; 
	-- 						 	
	ws_onkeypress_int  varchar2(1000); 
	ws_eventoGravar    varchar2(1000); 
	ws_evento          varchar2(1000); 
	ws_id_acao         ctb_acoes.id_acao%type;
	--ws_id_cliente      ctb_run.id_cliente%type; 
	ws_status          ctb_run.last_status%type; 

begin 
	--select max(id_cliente) into ws_id_cliente from ctb_run where ID_RUN = prm_ID_RUN; 

	ws_onkeypress_int := ' onkeypress="if(!input(event, ''integer'')) {event.preventDefault();} "';
	ws_eventoGravar   := ' "requestDefault(''ctb_run_acoes_update'', ''prm_id_run_acao=#ID#&prm_cd_parametro=#CAMPO#&prm_conteudo=''+#VALOR#,this,#VALOR#,'''',''CTB'');"'; 

	htp.p('<input type="hidden" id="content-atributos" data-refresh="ctb_run_acoes_list" data-refresh-ativo="N" data-pkg="ctb" data-par-col="prm_ID_RUN" data-par-val="'||prm_ID_RUN||'">');
	htp.p('<input type="hidden" id="prm_ID_RUN" value="'||prm_ID_RUN||'">');	

	htp.p('<table class="linha">');

		htp.p('<thead>');
			htp.p('<tr>');
				HTP.P('<th title="Ordem da execu&ccedil;&atilde;o da tarefa">'    ||FUN.LANG('ORDEM')||'</th>');
				HTP.P('<th title="A&ccedil;&atilde;o/tarefa executada.">'         ||FUN.LANG('A&Ccedil;&Otilde;ES')||'</th>');
				HTP.P('<th></th>');				
				HTP.P('<th title="Sistema.">'                ||FUN.LANG('SISTEMA')||'</th>');
				HTP.P('<th title="Tipo de banco de dados.">' ||FUN.LANG('TIPO BANCO')||'</th>');
				HTP.P('<th title="Conex&atilde;o de origem.">' ||FUN.LANG('CONEX&Atilde;O')||'</th>');
				HTP.P('<th title="Tabela de destino.">' ||FUN.LANG('TABELA DESTINO')||'</th>');
				HTP.P('<th style="min-width: 112px;" title="Inicio da &uacute;ltima execu&ccedil;&atilde;o.">'     ||FUN.LANG('INIC EXECU&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th style="min-width: 112px;" title="Fim da &uacute;ltima execu&ccedil;&atilde;o.">'        ||FUN.LANG('FIM EXECU&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th style="width: 100px; text-align: center;" title="Situa&ccedil;&atilde;o da &uacute;ltima execu&ccedil;&atilde;o.">'   ||FUN.LANG('SITUA&Ccedil;&Atilde;O')||'</th>');
				HTP.P('<th></th>');
				HTP.P('<th></th>');
				HTP.P('<th></th>');
				HTP.P('<th></th>');
			htp.p('</tr>');
		htp.p('</thead>');

		htp.p('<tbody id="ajax" >');

			for a in c_acoes loop

				ws_evento  := replace(ws_eventoGravar,'#ID#',a.id_run_acao); 

				htp.p('<tr id="'||a.id_run_acao||'">');

					htp.p('<td style="width: 60px !important;"><input id="prm_ordem_'||a.id_run_acao||'" style="min-width: 60px !important; width: 60px !important;" data-min="1" data-default="'||a.ordem||'" '||ws_onkeypress_int||' onblur='||replace(replace(ws_evento,'#CAMPO#','ORDEM'),'#VALOR#','this.value')||' value="'||a.ordem||'" /></td>');

					htp.p('<td class="fake-list" style="border-right: none; max-width: 170px !important;">');
						htp.p('<a class="script" data-default="'||a.id_acao||'" '||
								' onclick="call(''ctb_run_acoes_update'', ''prm_id_run_acao='||a.id_run_acao||'&prm_cd_parametro=ID_ACAO&prm_conteudo=''+this.nextElementSibling.title, ''CTB'').then(function(resposta){ alerta('''',resposta.split(''|'')[1]); if (resposta.split(''|'')[0] == ''OK'') {ajax(''list'', ''ctb_run_acoes_list'', ''prm_ID_RUN='||prm_ID_RUN||''', true, ''content'','''','''',''CTB''); } });"></a>');
						fcl.fakeoption('prm_step_id_'||a.id_run_acao, '', a.id_acao, 'lista-ctb-acoes', prm_editable=>'S', prm_multi=>'N', prm_desc => a.id_acao, prm_min => 1, prm_class_adic => ' fakelist-border-right' );
					htp.p('</td>');
					htp.p('<td class="ctb_atalho" title="Abre a tela de cadastro de A&ccedil;&otilde;es" style="width: 30px;"'||
							  ' onclick="carregaTelasup(''ctb_acoes_list'', ''prm_id_acao='||a.id_acao||''', ''CTB'', '''','''','''',''ctb_run_acoes_list|prm_ID_RUN='||prm_ID_RUN||'|CTB|ctb_run_acoes|||'');">');
						htp.p('<svg style="height: 32px; width: 32px; float: left;" viewBox="0 0 24 24" clip-rule="evenodd" fill-rule="evenodd" stroke-linejoin="round" stroke-miterlimit="2" xmlns="http://www.w3.org/2000/svg"><path d="m21 4c0-.478-.379-1-1-1h-16c-.62 0-1 .519-1 1v16c0 .621.52 1 1 1h16c.478 0 1-.379 1-1zm-16.5.5h15v15h-15zm12.5 10.75c0-.414-.336-.75-.75-.75h-8.5c-.414 0-.75.336-.75.75s.336.75.75.75h8.5c.414 0 .75-.336.75-.75zm0-3.248c0-.414-.336-.75-.75-.75h-8.5c-.414 0-.75.336-.75.75s.336.75.75.75h8.5c.414 0 .75-.336.75-.75zm0-3.252c0-.414-.336-.75-.75-.75h-8.5c-.414 0-.75.336-.75.75s.336.75.75.75h8.5c.414 0 .75-.336.75-.75z" fill-rule="nonzero"/></svg>');
					htp.p('</td>');
					htp.p('<td><div>'||a.id_sistema||'</div></td>');
					htp.p('<td><div>'||a.id_tipo_banco||'</div></td>');

					htp.p('<td class="fake-list" style="border-right: none; max-width: 170px !important;">');
						htp.p('<a class="script" data-default="'||a.id_conexao||'" onclick='||replace(replace(ws_evento,'#CAMPO#','ID_CONEXAO'),'#VALOR#','this.nextElementSibling.title')||'></a>');
						fcl.fakeoption('prm_id_conexao_'||a.id_run_acao, '', a.id_conexao, 'lista-ctb-conexoes', prm_editable=>'S', prm_multi=>'N', prm_desc => a.id_conexao, prm_min => 1, prm_adicional => a.id_cliente||'|'||a.id_sistema||'|'||a.id_tipo_banco );
					htp.p('</td>');

					htp.p('<td>');
                        htp.p('<input id="prm_tbl_destino_'||'_'||a.id_run_acao||'" type="text" data-min="1" data-default="'||a.tbl_destino||'" value="'||a.tbl_destino||'" '||
                        'onblur='||replace(replace(ws_evento,'#CAMPO#','TBL_DESTINO'),'#VALOR#','this.value')||' />');
					htp.p('</td>');


					-- htp.p('<td class="ctb_qt_tent"><input id="prm_qt_tentativas_'||a.run_step_id||'" data-min="1" data-default="'||a.qt_tentativas||'" '||ws_onkeypress_int||' onblur='||replace(replace(ws_evento,'#CAMPO#','QT_TENTATIVAS'),'#VALOR#','this.value')||' value="'||a.qt_tentativas||'" /></td>');

					htp.p('<td><div>'||to_char(a.dt_inicio,'dd/mm/yy hh24:mi:ss')||'</div></td>');
					htp.p('<td><div>'||to_char(a.dt_fim,   'dd/mm/yy hh24:mi:ss')||'</div></td>');
					htp.p('<td class="ctb_status">'||ctb.prn_a_status(a.status)||'</td>');
					htp.p('<td><div style="width: 1px !important; min-width: 1px !important;"></div></td>');

					htp.p('<td class="ctb_atalho" title="Executar a tarefa manualmente uma &uacute;nica vez" '||
							' onclick="if(!confirm(''Confirma a execu\u00e7\u00e3o da a\u00e7\u00e3o?'')){ return false; }  call(''ctb_run_exec'', ''prm_ID_RUN='||a.ID_RUN||'&prm_id_run_acao='||a.id_run_acao||''', ''CTB'').then(function(resposta){ alerta('''',resposta.split(''|'')[1]); if (resposta.split(''|'')[0] == ''OK'') {ajax(''list'', ''ctb_run_acoes_list'', ''prm_ID_RUN='||prm_ID_RUN||''', true, ''content'','''','''',''CTB''); } });">');
						htp.p('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2c5.514 0 10 4.486 10 10s-4.486 10-10 10-10-4.486-10-10 4.486-10 10-10zm0-2c-6.627 0-12 5.373-12 12s5.373 12 12 12 12-5.373 12-12-5.373-12-12-12zm-3 17v-10l9 5.146-9 4.854z"/></svg>');
					htp.p('</td>');

					htp.p('<td class="ctb_atalho" title="Log de execu&ccedil;&atilde;o do agente." '||
					      ' onclick="carregaTelasup(''ctb_acoes_exec_list'', ''prm_tp=RUN_ACAO&prm_id='||a.id_run_acao||''', ''CTB'', ''none'','''','''',''ctb_run_acoes_list|prm_ID_RUN='||prm_ID_RUN||'|CTB|ctb_run_acoes|||'');">');
						htp.p('<svg viewBox="0 0 600 600" xml:space="preserve"><g><path d="M486.201,196.124h-13.166V132.59c0-0.396-0.062-0.795-0.115-1.196c-0.021-2.523-0.825-5-2.552-6.963L364.657,3.677 c-0.033-0.031-0.064-0.042-0.085-0.073c-0.63-0.707-1.364-1.292-2.143-1.795c-0.229-0.157-0.461-0.286-0.702-0.421 c-0.672-0.366-1.387-0.671-2.121-0.892c-0.2-0.055-0.379-0.136-0.577-0.188C358.23,0.118,357.401,0,356.562,0H96.757 C84.894,0,75.256,9.651,75.256,21.502v174.613H62.092c-16.971,0-30.732,13.756-30.732,30.733v159.812 c0,16.968,13.761,30.731,30.732,30.731h13.164V526.79c0,11.854,9.638,21.501,21.501,21.501h354.776 c11.853,0,21.501-9.647,21.501-21.501V417.392h13.166c16.966,0,30.729-13.764,30.729-30.731V226.854 C516.93,209.872,503.167,196.124,486.201,196.124z M96.757,21.502h249.054v110.009c0,5.939,4.817,10.75,10.751,10.75h94.972v53.861 H96.757V21.502z M317.816,303.427c0,47.77-28.973,76.746-71.558,76.746c-43.234,0-68.531-32.641-68.531-74.152 c0-43.679,27.887-76.319,70.906-76.319C293.389,229.702,317.816,263.213,317.816,303.427z M82.153,377.79V232.085h33.073v118.039 h57.944v27.66H82.153V377.79z M451.534,520.962H96.757v-103.57h354.776V520.962z M461.176,371.092 c-10.162,3.454-29.402,8.209-48.641,8.209c-26.589,0-45.833-6.698-59.24-19.664c-13.396-12.535-20.75-31.568-20.529-52.967 c0.214-48.436,35.448-76.108,83.229-76.108c18.814,0,33.292,3.688,40.431,7.139l-6.92,26.37 c-7.999-3.457-17.942-6.268-33.942-6.268c-27.449,0-48.209,15.567-48.209,47.134c0,30.049,18.807,47.771,45.831,47.771 c7.564,0,13.623-0.852,16.21-2.152v-30.488h-22.478v-25.723h54.258V371.092L461.176,371.092z"></path><path d="M212.533,305.37c0,28.535,13.407,48.64,35.452,48.64c22.268,0,35.021-21.186,35.021-49.5 c0-26.153-12.539-48.655-35.237-48.655C225.504,255.854,212.533,277.047,212.533,305.37z"></path></g></svg>');
					htp.p('</td>');

					htp.p('<td class="ctb_atalho" title="Log do processo de atualiza&ccedil;&atilde;o das tabelas de destino." '||
					      ' onclick="carregaTelasup(''ctb_docs_list'', ''prm_id_run_acao='||a.id_run_acao||''', ''CTB'', ''none'','''','''',''ctb_run_acoes_list|prm_ID_RUN='||prm_ID_RUN||'|CTB|ctb_run_acoes|||'');">');
						htp.p('<svg viewBox="0 0 600 600" xml:space="preserve"><g><path d="M486.201,196.124h-13.166V132.59c0-0.396-0.062-0.795-0.115-1.196c-0.021-2.523-0.825-5-2.552-6.963L364.657,3.677 c-0.033-0.031-0.064-0.042-0.085-0.073c-0.63-0.707-1.364-1.292-2.143-1.795c-0.229-0.157-0.461-0.286-0.702-0.421 c-0.672-0.366-1.387-0.671-2.121-0.892c-0.2-0.055-0.379-0.136-0.577-0.188C358.23,0.118,357.401,0,356.562,0H96.757 C84.894,0,75.256,9.651,75.256,21.502v174.613H62.092c-16.971,0-30.732,13.756-30.732,30.733v159.812 c0,16.968,13.761,30.731,30.732,30.731h13.164V526.79c0,11.854,9.638,21.501,21.501,21.501h354.776 c11.853,0,21.501-9.647,21.501-21.501V417.392h13.166c16.966,0,30.729-13.764,30.729-30.731V226.854 C516.93,209.872,503.167,196.124,486.201,196.124z M96.757,21.502h249.054v110.009c0,5.939,4.817,10.75,10.751,10.75h94.972v53.861 H96.757V21.502z M317.816,303.427c0,47.77-28.973,76.746-71.558,76.746c-43.234,0-68.531-32.641-68.531-74.152 c0-43.679,27.887-76.319,70.906-76.319C293.389,229.702,317.816,263.213,317.816,303.427z M82.153,377.79V232.085h33.073v118.039 h57.944v27.66H82.153V377.79z M451.534,520.962H96.757v-103.57h354.776V520.962z M461.176,371.092 c-10.162,3.454-29.402,8.209-48.641,8.209c-26.589,0-45.833-6.698-59.24-19.664c-13.396-12.535-20.75-31.568-20.529-52.967 c0.214-48.436,35.448-76.108,83.229-76.108c18.814,0,33.292,3.688,40.431,7.139l-6.92,26.37 c-7.999-3.457-17.942-6.268-33.942-6.268c-27.449,0-48.209,15.567-48.209,47.134c0,30.049,18.807,47.771,45.831,47.771 c7.564,0,13.623-0.852,16.21-2.152v-30.488h-22.478v-25.723h54.258V371.092L461.176,371.092z"></path><path d="M212.533,305.37c0,28.535,13.407,48.64,35.452,48.64c22.268,0,35.021-21.186,35.021-49.5 c0-26.153-12.539-48.655-35.237-48.655C225.504,255.854,212.533,277.047,212.533,305.37z"></path></g></svg>');
					htp.p('</td>');

					htp.p('<td>');
						fcl.button_lixo('ctb_run_acoes_delete','prm_id_run_acao', a.id_run_acao, prm_tag => 'a', prm_pkg => 'CTB');
					htp.p('</td>');
				htp.p('</tr>');						
			end loop; 	
			
		htp.p('</tbody>');
	htp.p('</table>');	

exception when others then
   	insert into bi_log_sistema values(sysdate, 'ctb_run_acoes_list :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
	commit;
	Raise_Application_Error (-20101, 'Erro ctb_run_acoes_list');	
end ctb_run_acoes_list; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_acoes_insert (prm_ID_RUN        varchar2,
                                prm_ordem         varchar2,
						        prm_id_acao       varchar2) as 
	ws_id_cliente    number; 
	ws_id_run_acao   number; 
	ws_count         integer; 
	ws_erro          varchar2(300); 
	raise_erro       exception;
begin 

	select count(*) into ws_count from ctb_run_acoes where ID_RUN = prm_ID_RUN and ordem = prm_ordem; 
	if ws_count > 0 then 
		ws_erro := 'J&aacute; existe uma a&ccedil;&atilde;o cadastrada com essa ordem, informe outro valor para o campo ORDEM EXECU&Ccedil;&Atilde;O'; 
		raise raise_erro;
	end if; 	

	select min(id_cliente) into ws_id_cliente from ctb_run where ID_RUN = prm_ID_RUN;
	select nvl(max(to_number(id_run_acao)),0)+1 into ws_id_run_acao from ctb_run_acoes; 

	insert into ctb_run_acoes (id_run_acao,    ordem,     ID_RUN,     id_cliente,    id_acao)
	                   values (ws_id_run_acao, prm_ordem, prm_ID_RUN, ws_id_cliente, prm_id_acao);

	commit; 			  
	htp.p('OK|Registro inserido');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro inserindo registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_acoes_insert (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_acoes_insert; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_acoes_update ( prm_id_run_acao   varchar2, 
                           	     prm_cd_parametro  varchar2,
						   	     prm_conteudo      varchar2 ) as 
	ws_parametro varchar2(4000);
	ws_conteudo  varchar2(32000); 
	ws_id_run             varchar2(30); 
	ws_id_cliente 	 	  varchar2(50);
	ws_id_conexao   	  varchar2(50);
	ws_id_conexao_new  	  varchar2(50);
	ws_id_sistema_acao    varchar2(50) := null;
	ws_id_sistema_con     varchar2(50) := null;
	ws_id_tipo_banco_acao varchar2(50) := null;
	ws_id_tipo_banco_con  varchar2(50) := null;

	ws_erro      varchar2(300); 
	ws_vl_old    varchar2(4000);
	ws_count     integer; 
	raise_erro   exception;
begin 
	ws_parametro := upper(trim(prm_cd_parametro)); 
	ws_conteudo  := prm_conteudo; 

    if ws_conteudo is null then 
		ws_erro := 'Campo deve ser preenchido';
		raise raise_erro; 
	end if; 	

	select id_cliente, id_run, id_conexao 
	  into ws_id_cliente, ws_id_run, ws_id_conexao 
	  from ctb_run_acoes 
	 where id_run_acao = prm_id_run_acao; 

	-- Não permite alterar a ordem se já estiver outra ação com essa ordem 
	if prm_cd_parametro = 'ORDEM' then 
		select ID_RUN  into ws_ID_RUN from ctb_run_acoes where id_run_acao = prm_id_run_acao; 
		select count(*) into ws_count from ctb_run_acoes where ID_RUN = ws_ID_RUN and ordem = prm_conteudo and id_run_acao <> prm_id_run_acao; 
		if ws_count > 0 then 
			ws_erro := 'J&aacute; existe uma a&ccedil;&atilde;o cadastrada com essa ordem, informe outro valor para o campo ORDEM'; 
			raise raise_erro;
		end if; 	
	end if; 

	execute immediate 'select substr(max('||ws_parametro||'),1,3990) from ctb_run_acoes where id_run_acao = :p1' into ws_vl_old using in prm_id_run_acao;

	update ctb_run_acoes
	   set ordem         = decode(ws_parametro, 'ORDEM',         ws_conteudo, ordem),
	       id_acao       = decode(ws_parametro, 'ID_ACAO',       ws_conteudo, id_acao),
		   id_conexao    = decode(ws_parametro, 'ID_CONEXAO',    ws_conteudo, id_conexao),
		   tbl_destino   = decode(ws_parametro, 'TBL_DESTINO',   ws_conteudo, tbl_destino)
	 where id_run_acao = prm_id_run_acao;
	if sql%notfound then 
		ws_erro := 'N&atilde;o localizado tarefa para atualiza&ccedil;&atilde;o, recarrega a tela e tente novamente'; 
		raise raise_erro; 
	end if;

	fun.bi_log_alt_insere('U', 'CTB_RUN_ACOES', prm_id_run_acao,  ws_parametro, sysdate, gbl.getusuario(), ws_vl_old, substr(ws_conteudo,1,3990) ); 

	if ws_parametro = 'ID_ACAO' then 
		select min(id_sistema), min(id_tipo_banco) into ws_id_sistema_acao, ws_id_tipo_banco_acao from ctb_acoes where id_cliente = ws_id_cliente and id_acao = ws_conteudo;		
		ws_id_conexao_new := ws_id_conexao;
		if ws_id_conexao is not null then  
			-- limpa a conexão se a conexão existente não for do mesmo sistema e tipo de banco 
			select min(conteudo) into ws_id_sistema_con    from ctb_conexoes where id_cliente = ws_id_cliente and id_conexao = ws_id_conexao and cd_parametro = 'SISTEMA';
			select min(conteudo) into ws_id_tipo_banco_con from ctb_conexoes where id_cliente = ws_id_cliente and id_conexao = ws_id_conexao and cd_parametro = 'DB';
			if nvl(ws_id_sistema_acao,'.') <> nvl(ws_id_sistema_con,'.') or nvl(ws_id_tipo_banco_acao,'.') <> nvl(ws_id_tipo_banco_con,'.') then 
				ws_id_conexao_new := null;
			end if;
		else 
			-- se a conexao estiver em branco procura uma que seja do mesmo sistema e tipo de banco da açao 
			select min(id_conexao ) into ws_id_conexao_new
			 from ctb_conexoes
             where (id_cliente, id_conexao) in (select b.id_cliente, b.id_conexao from ctb_conexoes b where id_cliente = ws_id_cliente and cd_parametro = 'SISTEMA' and conteudo = ws_id_sistema_acao)
               and (id_cliente, id_conexao) in (select b.id_cliente, b.id_conexao from ctb_conexoes b where id_cliente = ws_id_cliente and cd_parametro = 'DB'      and conteudo = ws_id_tipo_banco_acao);
		end if;

		update ctb_run_acoes set id_conexao = ws_id_conexao_new
		where id_run_acao = prm_id_run_acao;			

		if nvl(ws_id_conexao,'.') <> nvl(ws_id_conexao_new,'.') then 
			fun.bi_log_alt_insere('U', 'CTB_RUN_ACOES', prm_id_run_acao,  'ID_CONEXAO', sysdate, gbl.getusuario(), ws_id_conexao, ws_id_conexao_new ); 
		end if; 
	end if; 

	commit; 
	htp.p('OK|Registro alterado');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro alterando registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_acoes_update (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_acoes_update;

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_acoes_delete (prm_id_run_acao varchar2 ) as 
	ws_erro     varchar2(300); 
begin 

	delete ctb_run_acoes where id_run_acao = prm_id_run_acao ;
	fun.bi_log_alt_insere('D','CTB_RUN_ACOES', prm_id_run_acao, null, sysdate, gbl.getusuario(), null, null); 

	commit;  
	htp.p('OK|Registro exclu&iacute;do');

exception 
	when others then 	
		ws_erro	:= 'Erro excluindo registro, verifique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_acoes_delete (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_acoes_delete; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_param_list(prm_ID_RUN     varchar2) as 
	ws_ds_parametro varchar2(200); 
	ws_evento       varchar2(2000);
	ws_eventoGravar varchar2(2000);
	ws_conteudo     ctb_run_param.conteudo%type; 
begin 

	-- Atualiza os parametros da tarefa, caso tenha sido adicionado algum novo parametro nas ações - já tem commit na procedure 
	ctb.ctb_run_param_atu(prm_ID_RUN); 

	ws_eventoGravar := '"requestDefault(''ctb_run_param_update'', ''prm_ID_RUN=#ID#&prm_cd_parametro=#PAR#&prm_campo=#CAMPO#&prm_conteudo=''+#VALOR#,this,#VALOR#,'''',''CTB''); "'; 
	ws_eventoGravar := '"requestDefault(''ctb_run_param_update'', ''prm_ID_RUN=#ID#&prm_cd_parametro=#PAR#&prm_campo=#CAMPO#&prm_conteudo=''+#VALOR#,this,#VALOR#,'''',''CTB''); "'; 

	htp.p('<input type="hidden" id="content-atributos" data-pkg="ctb" data-par-col="prm_ID_RUN" data-par-val="'||prm_ID_RUN||'">');
	htp.p('<input type="hidden" id="prm_ID_RUN" value="'||prm_ID_RUN||'">');	

	htp.p('<h2>PAR&Acirc;METROS EXECU&Ccedil;&Atilde;O</h2>');

	htp.p('<table class="linha">');
		htp.p('<thead>');
			htp.p('<tr>');
				HTP.P('<th title="Nome par&acirc;metro.">'                                              ||FUN.LANG('NOME/ID PAR&Acirc;METRO')||'</th>');
				HTP.P('<th title="Conte&uacute;do/valor do par&acirc;metro.">'                          ||FUN.LANG('CONTE&Uacute;DO / VALOR')||'</th>');
			htp.p('</tr>');
		htp.p('</thead>');

		htp.p('<tbody id="ajax" >');
			for a in (select ID_RUN, cd_parametro, conteudo 
			            from ctb_run_param 
					   where ID_RUN           = prm_ID_RUN 
					     and nvl(st_ativo,'S') = 'S' 
			           order by decode(cd_parametro,'MINUTO_ESPERA',1, 'MINUTO_ESPERA_PLSQL',2,3), cd_parametro ) loop
				
				ws_evento := replace(replace(ws_eventoGravar,'#ID#', a.ID_RUN),'#PAR#', a.cd_parametro); 
				ws_conteudo := replace(a.conteudo,'"', '&#34;');
				htp.p('<tr id="'||a.ID_RUN||'">');
					htp.p('<td class="ctb_cd_parametro"><div title="'||a.cd_parametro||'">'||a.cd_parametro||'</div></td>');
					htp.p('<td><input id="prm_conteudo_'||a.ID_RUN||'" style="border: none;" data-min="1" data-default="'||ws_conteudo||'" value="'||ws_conteudo||'" '||
						  'onblur='||replace(replace(ws_evento,'#CAMPO#','CONTEUDO'),'#VALOR#','this.value')||' /></td>');
				htp.p('</tr>');						
			end loop; 	
		htp.p('</tbody>');
	htp.p('</table>');	

end ctb_run_param_list; 

----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_param_update ( prm_ID_RUN        varchar2, 
                           	     prm_cd_parametro  varchar2,
								 prm_campo         varchar2, 
						   	     prm_conteudo      varchar2 ) as 
	ws_parametro varchar2(4000);
	ws_conteudo  varchar2(32000); 
	ws_ID_RUN    varchar2(30); 
	ws_erro      varchar2(300); 
	ws_vl_old    varchar2(4000);
	ws_nr_aux    integer; 
	raise_erro   exception;
begin 
	ws_parametro := upper(trim(prm_cd_parametro)); 
	ws_conteudo  := prm_conteudo; 

    if ws_conteudo is null then 
		ws_erro := 'Campo deve ser preenchido';
		raise raise_erro; 
	end if; 	
	
	if ws_parametro in ('MINUTO_ESPERA','MINUTO_ESPERA_PLSQL') then 
		ws_erro := null;
		begin 
			ws_nr_aux := ws_conteudo;
			if ws_nr_aux <= 0 then 
				ws_erro := 'Conte&uacute;do inv&aacute;lido, conte&uacute;do deve ser um n&uacute;mero inteiro maior que zero';		
			end if; 	
		exception when others then 
			ws_erro := 'Conte&uacute;do inv&aacute;lido, conte&uacute;do deve ser um n&uacute;mero inteiro';		
		end; 	
		if ws_erro is not null then 
			raise raise_erro;
		end if; 	
	end if; 

	select substr(max(conteudo),1,3990) into ws_vl_old from ctb_run_param 
	 where cd_parametro  = ws_parametro 
	   and id_run        = prm_id_run;

	update ctb_run_param 
	   set conteudo      = decode(prm_campo,'CONTEUDO'     ,ws_conteudo,conteudo) 
	 where cd_parametro  = ws_parametro 
	   and ID_RUN        = prm_id_run;
	if sql%notfound then 
		ws_erro := 'Par&acirc;metro n&atilde;o localizado para atualiza&ccedil;&atilde;o'; 
		raise raise_erro; 
	end if;

	fun.bi_log_alt_insere('U', 'CTB_RUN_PARAM', prm_id_run||'-'||ws_parametro,  'CONTEUDO', sysdate, gbl.getusuario(), ws_vl_old, substr(ws_conteudo,1,3990) ); 

	commit; 
	htp.p('OK|Registro alterado');

exception 
	when raise_erro then 
		htp.p('ERRO|'||ws_erro);
	when others then 	
		ws_erro	:= 'Erro alterando registro, verique o log de erros do sistema';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_param_update (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_param_update;


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_exec (prm_ID_RUN      varchar2,
                        prm_id_run_acao varchar2 default null) as
	ws_count      number;
	ws_erro       varchar2(200) := null; 
begin

	select count(*) into ws_count 
	 from ctb_clientes cl, ctb_run ru
	 where cl.id_cliente = ru.id_cliente
	   and ru.id_run     = prm_id_run
	   and cl.habilitado = 'S';

	if ws_count = 0 then 
		ws_erro := 'Cliente n&atilde;o est&aacute; habilitado para integra&ccedil;&atilde;o.'; 
	else 
		ctb.exec_run(prm_ID_RUN, prm_id_run_acao, ws_erro);
	end if; 	

	if ws_erro is null then 
		htp.p('OK|'||fun.lang('Tarefa iniciada com sucesso, acompanhe a execu&ccedil;&atilde;o pelo log')); 
	else 
		htp.p('ERRO|'||fun.lang(ws_erro)); 
	end if; 	
exception 
	when others then
		ws_erro := 'Erro iniciando Tarefa, verifique o log de erros do sistema';
		htp.p('ERRO|'||fun.lang(ws_erro)); 
		insert into bi_log_sistema (dt_log, ds_log, nm_usuario, nm_procedure) values (sysdate , 'ctb_run_exec('||prm_ID_RUN||') erro: '||substr(dbms_utility.format_error_stack||'-'||dbms_utility.format_error_backtrace,1,3900) , gbl.getUsuario, 'ERRO');
        commit; 
end ctb_run_exec; 


----------------------------------------------------------------------------------------------------------------------------------------------------------------
procedure ctb_run_stop (prm_ID_RUN   varchar2) as
	ws_usuario       varchar2(100); 
	ws_qt_run_ext    number; 
	ws_qt_run_ins    number;
	ws_status_ins    varchar2(30);
	ws_status        varchar2(30);
	ws_count         number;
	ws_erro          varchar2(1000); 
begin 
	
	ws_usuario    := gbl.getUsuario; 
	ws_qt_run_ext := 0; 
	ws_qt_run_ins := 0; 
	ws_erro       := 'Execucao cancelada pelo Usuario ['||ws_usuario||']';

	for a in (select ru.id_cliente, ra.ID_RUN, ra.id_run_acao, ra.id_acao, ra.status 
	           from ctb_run ru, ctb_run_acoes ra 
			  where ru.ID_RUN = ra.ID_RUN 
			    and ra.ID_RUN = prm_ID_RUN ) loop 
		
		for b in (select id_agendamento, status from ctb_acoes_exec 
				   where id_run_acao = a.id_run_acao 
 		  		     and status     in ('AGUARDANDO','EXTRAINDO','AGUARD.INSERCAO','INSERINDO') ) loop   
			if b.status = 'EXTRAINDO' then 
				ws_qt_run_ext := ws_qt_run_ext + ws_count; 
			end if; 	

			select count(*), nvl(min(status),'N/A') into ws_count, ws_status_ins 
			from ctb_docs 
			where id_agendamento = b.id_agendamento ;
			if ws_status_ins = 'INSERINDO' then 
				ws_qt_run_ins := ws_qt_run_ins + ws_count; 	
			end if; 

			update ctb_acoes_exec 
			set status  = 'CANCELADO',
				ds_erro = ws_erro
			where id_agendamento = b.id_agendamento;  

			update ctb_docs 
			set status  = 'CANCELADO', 
				ds_erro = ws_erro
			where id_agendamento = b.id_agendamento ;

		end loop;

		ctb.ctb_atu_status_acao(a.id_run_acao,'CANCELADO'); 

	end loop; 	

	ctb.ctb_atu_status_run (prm_ID_RUN, ws_status);  

	if ws_qt_run_ins > 0 then 
		htp.p('OK|A tarefa foi parcialmente cancelada, existem a&ccedil;&otilde;es j&aacute; em processo de inser&ccedil;&atilde;o da tabela de destino');
	elsif ws_qt_run_ext > 0 then 
		htp.p('OK|Tarefa cancela, por&eacute;m existem a&ccedil;&otilde;es em execu&ccedil;&atilde;o pelo agente no cliente');
	else 
		htp.p('OK|Tarefa cancela com sucesso');
	end if; 	

exception 
	when others then 	
		ws_erro	:= 'Erro excluindo registro, verifique o log de erros do sistema.';
		htp.p('ERRO|'||ws_erro);
    	insert into bi_log_sistema values(sysdate, 'ctb_run_acoes_delete (others) :'||DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE, gbl.getusuario, 'ERRO');
		commit;
end ctb_run_stop; 



END CTB;
