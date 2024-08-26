create or replace package body     agentc is

procedure request_begin (  p_id_cliente     varchar2 default null,
                           p_check_id       varchar2 default null,
                           p_versao         varchar2 default null ) as

     ws_chave_final      varchar2(100);
     ws_ant_chave        varchar2(100);
     ws_chave            varchar2(100);
     ws_tempo            varchar2(100);
     ws_erro             varchar2(4000);
     ws_url              varchar2(4000);
     ws_check            number;

     ws_nocheck          exception;
     ws_gera_check       exception;
     ws_update           exception;
     ws_curl             exception;

	BEGIN

          if  substr(p_versao,1,1) <> '0' then
               begin
                    select URL into ws_url
                    from (
                                        SELECT ROWNUM SEQ, ID_VERSAO, URL
                                        FROM CTB_UPDATE
                                        WHERE ST_ATIVO = 'SIM' AND ID_CLIENTE = p_id_cliente and id_versao <> p_versao
                                        ORDER BY ID_CLIENTE NULLS LAST
                                   );
                    if  ws_url = '' then
                         select URL into ws_url
                         from (
                                             SELECT ROWNUM SEQ, ID_VERSAO, URL
                                             FROM CTB_UPDATE
                                             WHERE ST_ATIVO = 'SIM' AND ID_CLIENTE = null and id_versao <> p_versao
                                             ORDER BY ID_CLIENTE NULLS LAST
                                        );
                    end if;

               exception
                    when others then ws_url := null;
               end;

               if  ws_url is not null  then
                    raise ws_update;
               end if;

               if  substr(p_id_cliente,1,2) = '88' then
                    raise ws_curl;
               end if;
          end if;


          begin
               ws_chave_final := '';
               ws_ant_chave   := agentc.send_id;
               ws_chave       := ws_ant_chave||dwu.check_id(ws_ant_chave);
               ws_tempo       := to_char(sysdate,'DDMMYYYYHH24MISS');

               ws_chave_final := ws_chave_final||substr(ws_chave,1, 1)||substr(ws_tempo,14 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,2, 1)||substr(ws_tempo,13 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,3, 1)||substr(ws_tempo,12 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,4, 1)||substr(ws_tempo,11 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,5, 1)||substr(ws_tempo,10 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,6, 1)||substr(ws_tempo,9 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,7, 1)||substr(ws_tempo,8 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,8, 1)||substr(ws_tempo,7 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,9, 1)||substr(ws_tempo,6 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,10,1)||substr(ws_tempo,5 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,11,1)||substr(ws_tempo,4 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,12,1)||substr(ws_tempo,3 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,13,1)||substr(ws_tempo,2 ,1);
               ws_chave_final := ws_chave_final||substr(ws_chave,14,1)||substr(ws_tempo,1 ,1);

               ws_chave_final := substr(ws_chave_final,28,1)||substr(ws_chave_final,1,1)||substr(p_id_cliente,8,1)||substr(ws_chave_final,9,1)||
                                   substr(ws_chave_final,25,1)||substr(ws_chave_final,2,1)||substr(p_id_cliente,7,1)||substr(ws_chave_final,10,1)||
                                   substr(ws_chave_final,23,1)||substr(ws_chave_final,3,1)||substr(p_id_cliente,6,1)||substr(ws_chave_final,11,1)||
                                   substr(ws_chave_final,26,1)||substr(ws_chave_final,4,1)||substr(p_id_cliente,5,1)||substr(ws_chave_final,12,1)||
                                   substr(ws_chave_final,21,1)||substr(ws_chave_final,5,1)||substr(p_id_cliente,4,1)||substr(ws_chave_final,13,1)||
                                   substr(ws_chave_final,24,1)||substr(ws_chave_final,6,1)||substr(p_id_cliente,3,1)||substr(ws_chave_final,14,1)||
                                   substr(ws_chave_final,22,1)||substr(ws_chave_final,7,1)||substr(p_id_cliente,2,1)||substr(ws_chave_final,15,1)||
                                   substr(ws_chave_final,27,1)||substr(ws_chave_final,8,1)||substr(p_id_cliente,1,1)||substr(ws_chave_final,16,1)||
                                   substr(ws_chave_final,21,1)||substr(ws_chave_final,20,1)||substr(ws_chave_final,19,1)||substr(ws_chave_final,18,1)||
                                   substr(ws_chave_final,17,1);

          exception
               when others then 
                    raise ws_gera_check;
        end;

        begin
             update CTB_CLIENTES set CTB_CLIENTES.check_id      = ws_chave_final,
                                     CTB_CLIENTES.dt_ultima_com = sysdate
             where  CTB_CLIENTES.id_cliente = p_id_cliente;
             insert into CTB_REGISTRO values (p_id_cliente,sysdate,'BEGIN',null,ws_chave_final,p_versao);
             commit;
        exception
             when others
                then
                     rollback;
                     raise ws_nocheck;        
        end;

        htp.p(ws_chave_final);

    exception
         when ws_update then
              insert into err_txt values (TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS')||' - AGENTC Body[1] - REQUEST_BEGIN - UPDATE >>'||' = '||p_versao||ws_url||' - '||DBMS_UTILITY.FORMAT_ERROR_STACK||' - '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
              commit;
              htp.p('UPDATE|'||ws_url);
         when ws_curl then
              htp.p('CHKID|http://bi-aethos.upquery.com:7777/agent');
         when ws_gera_check then
              insert into CTB_INVALIDO values (p_id_cliente, p_check_id, '', sysdate);
              commit;    
         when others then
              insert into CTB_INVALIDO values (p_id_cliente, p_check_id, '', sysdate);
              commit;
              ws_check := 1/0;

end request_begin;

procedure request_end (  p_id_cliente     varchar2 default null,
	                     p_check_id       varchar2 default null ) as

	    ws_chave_final      varchar2(100);
        ws_ant_chave        varchar2(100);
        ws_chave            varchar2(100);
        ws_tempo            varchar2(100);
        ws_check            number;

        ws_nocheck          exception;

	begin		

        if  not chk_cliente(p_id_cliente,p_check_id) then
            raise ws_nocheck;
        end if;


        begin
             select count(*) into ws_check
             from   CTB_REGISTRO
             where  CTB_REGISTRO.id_cliente = p_id_cliente and
                    CTB_REGISTRO.tp_registro = 'BEGIN';
             if  ws_check = 0 then
                 raise ws_nocheck;
             end if;
        exception
             when others then
                  raise ws_nocheck;
        end;

        begin

             update CTB_CLIENTES set CTB_CLIENTES.dt_ultima_com = sysdate
             where  CTB_CLIENTES.id_cliente = p_id_cliente;

             update CTB_REGISTRO set tp_registro = 'END',
                                     dt_final    = sysdate
             where  CTB_REGISTRO.id_cliente = p_id_cliente and
                    CTB_REGISTRO.check_id   = p_check_id and
                    CTB_REGISTRO.tp_registro = 'BEGIN';
            commit;

        exception
             when others
                then
                     rollback;
                     raise ws_nocheck;        
        end;

        htp.p('FINALIZADO');

    exception
         when others
              then ws_check := 1/0;
end request_end;

procedure acao_end (      p_id_cliente      varchar2 default null,
	                      p_check_id        varchar2 default null,
                          p_id_acao         varchar2 default null,
                          p_second          varchar2 default null,
                          p_second_upload   varchar2 default null,
                          p_second_processo varchar2 default null) as

	    ws_chave_final      varchar2(100);
        ws_ant_chave        varchar2(100);
        ws_chave            varchar2(100);
        ws_tempo            varchar2(100);
        ws_check            number;
        ws_query            varchar2(4000);

        ws_nocheck          exception;
        ws_fase             varchar2(3000);

	begin

        if  not chk_cliente(p_id_cliente,p_check_id) then
            ws_fase := 'CHECK_ID:';
            raise ws_nocheck;
        end if;

        begin
             select count(*) into ws_check
             from   CTB_REGISTRO
             where  CTB_REGISTRO.id_cliente = p_id_cliente and
                    CTB_REGISTRO.tp_registro = 'BEGIN';
             if  ws_check = 0 then
                 ws_fase := 'CTB_REGISTRO:';
                 raise ws_nocheck;
             end if;
        exception
             when others then
                  raise ws_nocheck;
        end;

        begin
             update CTB_ACOES_EXEC set STATUS='END', 
                                       DT_FINAL=sysdate, 
                                       TEMPO_LOCAL=p_second,
                                       TEMPO_UPLOAD=p_second_upload,
                                       TEMPO_PROCESSO=p_second_processo
             WHERE ID_CLIENTE=p_id_cliente AND
                   ID_ACAO=p_id_acao AND
                   STATUS='RUNNING';
             COMMIT;
        exception
             when others then
                  ws_fase := 'CTB_ACOES_EXEC:';
                  raise ws_nocheck;
        end;

        htp.p('OK');

    exception
         when others
              then
                   ws_query := SQLERRM;
                   insert into CTB_ERROS values ( p_id_cliente, p_check_id, p_id_acao, ws_fase||trim(ws_query), sysdate );
                   commit;
                   htp.p('OK');

end acao_end;

procedure request_con (  p_id_cliente     varchar2 default null,
	                     p_check_id       varchar2 default null ) as

	    ws_chave_final      varchar2(100);
        ws_ant_chave        varchar2(100);
        ws_chave            varchar2(100);
        ws_tempo            varchar2(100);
        ws_check            number;

        ws_nocheck          exception;

	begin

        if  not chk_cliente(p_id_cliente,p_check_id) then
            raise ws_nocheck;
        end if;
        begin
             select count(*) into ws_check
             from   CTB_REGISTRO
             where  CTB_REGISTRO.id_cliente = p_id_cliente and
                    CTB_REGISTRO.tp_registro = 'BEGIN';
             if  ws_check = 0 then
                 raise ws_nocheck;
             end if;
        exception
             when others then
                  raise ws_nocheck;
        end;

		for i in (select ID_CONEXAO, CD_PARAMETRO, CONTEUDO from CTB_CONEXOES where ID_CLIENTE = p_id_cliente) loop
              htp.p(i.ID_CONEXAO||'|'||i.CD_PARAMETRO||'|'||i.CONTEUDO||'|');
		end loop;

    exception
         when others
              then ws_check := 1/0;
end request_con;


procedure request_list (  p_id_cliente     varchar2 default null,
	                      p_check_id       varchar2 default null ) as


	    ws_chave_final      varchar2(100);
        ws_ant_chave        varchar2(100);
        ws_chave            varchar2(100);
        ws_tempo            varchar2(100);
        ws_check            number;

        ws_nocheck          exception;

	begin
        if  not chk_cliente(p_id_cliente,p_check_id) then
            raise ws_nocheck;
        end if;

        begin
             select count(*) into ws_check
             from   CTB_REGISTRO
             where  CTB_REGISTRO.id_cliente = p_id_cliente and
                    CTB_REGISTRO.tp_registro = 'BEGIN';
             if  ws_check = 0 then
                 raise ws_nocheck;
             end if;
        exception
             when others then
                  raise ws_nocheck;
        end;

		for i in (select ID_CONEXAO, ID_ACAO, DS_ACAO, NULL ST_BYPASS, NULL CONTEUDO_ENVIO from CTB_ACOES_EXEC where ID_CLIENTE = p_id_cliente and STATUS in ('STANDBY','RUNNING')
        ) loop
              htp.p(i.ID_ACAO||'|'||i.ID_CONEXAO||'|'||i.DS_ACAO||'|'||i.ST_BYPASS||'|'||I.CONTEUDO_ENVIO);
		end loop;

    exception
         when others
              then ws_check := 1/0;
end request_list;

procedure request_acao (  p_id_cliente     varchar2 default null,
	                      p_check_id       varchar2 default null,
                          p_id_acao        varchar2 default null,
                          p_conteudo_envio varchar2 default 'N' ) as

     ws_chave_final      varchar2(100);
     ws_ant_chave        varchar2(100);
     ws_chave            varchar2(100);
     ws_tempo            varchar2(100);
     ws_check            number;
     ws_query            clob;
     ws_conteudo_envio   varchar2(4000);
     ws_run_acao_id      number; 

     ws_nocheck          exception;
     ws_erro_in          exception;

begin

     begin
          select agentc.b2c(comando) as comando, conteudo_envio, run_acao_id 
            into ws_query, ws_conteudo_envio, ws_run_acao_id
          from   CTB_ACOES_EXEC CTB_ACOES
          where  CTB_ACOES.id_cliente = p_id_cliente and
               CTB_ACOES.id_acao    = p_id_acao and
               STATUS               = 'STANDBY'
          order by dt_inicio asc
          fetch first 1 rows only;   
     exception
          when others then
               raise ws_nocheck;
     end;

     if ws_conteudo_envio is not null then
          ws_query := ws_conteudo_envio||'|GET';
     end if;

     htp.p(ws_query);

     update CTB_ACOES_EXEC set STATUS='RUNNING', CHECK_ID = p_check_id, dt_inicio=sysdate
     WHERE ID_CLIENTE = p_id_cliente 
       AND ID_ACAO    = p_id_acao 
       AND STATUS     = 'STANDBY';

     atu_status_acao ( ws_run_acao_id, 'EXECUTANDO');  -- atualiza status da tarefa no BI 

     COMMIT;

exception
      when others then
           ws_conteudo_envio := sqlerrm;
           raise ws_erro_in;
end request_acao;

procedure put_error (p_id_cliente     varchar2 default null,
	                p_check_id       varchar2 default null,
                     p_id_acao        varchar2 default null,
                     p_erro_txt       varchar2 default null ) as

     ws_chave_final      varchar2(100);
     ws_ant_chave        varchar2(100);
     ws_chave            varchar2(100);
     ws_tempo            varchar2(100);
     ws_check            number;
     ws_query            varchar2(4000);
     ws_run_acao_id      number;

     ws_nocheck          exception;

begin

     if  not chk_cliente(p_id_cliente,p_check_id) then
          raise ws_nocheck;
     end if;

     begin
          select count(*) into ws_check
          from   CTB_REGISTRO
          where  CTB_REGISTRO.id_cliente = p_id_cliente and
               CTB_REGISTRO.tp_registro = 'BEGIN';
          if  ws_check = 0 then
               raise ws_nocheck;
          end if;
     exception
          when others then
               raise ws_nocheck;
     end;

     begin
          insert into CTB_ERROS values ( p_id_cliente, p_check_id, p_id_acao, p_erro_txt, sysdate );
          commit;
     exception
          when others then
               raise ws_nocheck;
     end;

     begin
          select run_acao_id into ws_run_acao_id
          from ctb_acoes_exec 
          where id_cliente = p_id_cliente 
            and id_acao    = p_id_acao 
            and status     = 'RUNNING';

          update CTB_ACOES_EXEC set STATUS='ERRO', 
                                   ERRO = substr(p_erro_txt,1,490), 
                                   DT_FINAL=sysdate, 
                                   TEMPO_LOCAL=0,
                                   TEMPO_UPLOAD=0,
                                   TEMPO_PROCESSO=0
          WHERE ID_CLIENTE = p_id_cliente 
            AND ID_ACAO    = p_id_acao 
            AND STATUS     = 'RUNNING';

          if ws_run_acao_id is not null then 
               atu_status_acao ( ws_run_acao_id, 'ERRO' );  -- atualiza status da tarefa no BI 
          end if; 
          
          commit;   

     exception
          when others then
               raise ws_nocheck;
     end;

     htp.p('OK');

exception
     when others then
          ws_query := SQLERRM;
          insert into CTB_ERROS values ( p_id_cliente, p_check_id, p_id_acao, trim(ws_query), sysdate );
          commit;
          htp.p('OK');

end put_error;


function chk_cliente ( p_id_cliente     varchar2,
	                   p_check_id       varchar2 ) return boolean as

        ws_check            number;
        ws_retorno          boolean;
        ws_nocheck          exception;

begin

        ws_retorno := true;

        begin
             select count(*) into ws_check
             from   CTB_CLIENTES
             where  CTB_CLIENTES.id_cliente = p_id_cliente and
                    CTB_clientes.check_id   = p_check_id;
             if  ws_check <> 1 then
                 ws_retorno := false;
                 raise ws_nocheck;
             end if;
        exception
             when others then
--                  ws_retorno := false;
                    ws_retorno := true;
        end;
        ws_retorno := true;
        return(ws_retorno);

end chk_cliente;

procedure upload ( p_documento      IN  varchar2 default null,
                   p_id_cliente     varchar2 default null,
	               p_check_id       varchar2 default null,
                   p_id_acao        varchar2 default null
                   ) as

     l_nome_real         varchar2(1000);
     ws_check            number;
     ws_nocheck          exception;
     ws_count            number;
     ws_sysdate          date;
     ws_status           varchar2(20);
     ws_status_acao      varchar2(20);
     ws_erro             varchar2(100); 
     ws_dt_aux           date;   

begin

     ws_sysdate := sysdate; 
     ws_status  := 'WAITING'; 
     ws_erro    := null; 

     select count(*), max(last_updated) into ws_count, ws_dt_aux  
     from tmp_docs
     where id_cliente   = p_id_cliente
          and check_id     = p_check_id
          and id_acao      = p_id_acao
          and name        <> p_documento; 
     if ws_count > 0 then 
          ws_status := 'ERRO';
          ws_erro   := 'Arquivo enviado em duplicidade pelo Agente'; 
     end if; 

     select nvl(max(status),'N/A') into ws_status_acao
     from ctb_acoes_exec 
     where id_cliente = p_id_cliente
       and check_id   = p_check_id 
       and id_acao    = p_id_acao ;

     if nvl(ws_status_acao,'NA') = 'CANCELED' then 
          ws_status := 'CANCELED';
     end if;    

     update tmp_docs set id_cliente   = p_id_cliente,
                         check_id     = p_check_id,
                         id_acao      = p_id_acao,
                         last_updated = ws_sysdate,
                         status       = ws_status,
                         erro         = ws_erro 
     where name = p_documento;

     htp.p('OK=['||p_id_acao||']');

exception
     when others then
          insert into err_txt values (TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS')||' - AGENTC Body[3] - UPLOAD - '||DBMS_UTILITY.FORMAT_ERROR_STACK||' - '||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
          commit;

end upload;

procedure uptest ( p_documento      IN  varchar2 default null ) as

     l_nome_real         varchar2(1000);
     ws_check            number;
     ws_nocheck          exception;
begin
        htp.p('OK=['||']');
end uptest;



procedure error_domweb (
                        p_id_cliente      varchar2 DEFAULT NULL,
                        p_nm_arquivo      varchar2 DEFAULT NULL,
                        p_erro_txt        varchar2 DEFAULT null
                       ) as

  ws_notoken      exception;
  ws_nlines       exception;
  ws_token        varchar2(3000);
  ws_separador    varchar2(400);
  ws_ctoken       number;
  ws_count        number;
  ws_screens      number;
  ws_action       varchar2(3000);
  ws_erro         varchar2(3000);
  ws_command      varchar2(30);

begin

   ws_command := 'OK';

   ws_token := 'NO_TOKEN';
   for i in 1..owa.num_cgi_vars
   loop
      if owa.cgi_var_name(i) = 'HTTP_AUTHORIZATION' then
         ws_token := owa.cgi_var_val(i);
      end if;
   end loop;
   IF  ws_token <> '15edf23a8821edff322ffaa3245fe00e5' THEN
       raise ws_notoken;
   END IF;

   begin
      INSERT INTO CTB_ERROS_DOMWEB VALUES (p_id_cliente, p_nm_arquivo, p_erro_txt, sysdate);
      COMMIT;
   EXCEPTION
        WHEN OTHERS THEN
             ws_token := 'NO_TOKEN';
   end;

   if  ws_token = 'NO_TOKEN' THEN
       htp.p('{"success": false}');
   else
       htp.p('{"success": true}');
   end if;

exception
      when others THEN
           ws_ctoken := 1/0;
end;

procedure atu_status_acao ( prm_run_acao_id   number, 
                            prm_status        varchar2 ) as 
     ws_dh_i   date := null;
     ws_dh_f   date := null; 
begin

     if prm_status in ('EXECUTANDO','AGUARDANDO') then 
          ws_dh_i :=  sysdate; 
     elsif prm_status in ('CONCLUIDO', 'ERRO','CANCELADO','ALERTA') then 
          ws_dh_f :=  sysdate; 
     end if; 

     update ctb_run_acoes
	   set last_status = prm_status, 
            dh_inicio   = nvl(nvl(ws_dh_i, dh_inicio),ws_dh_f),
            dh_fim      = nvl(ws_dh_f, dh_fim)
	 where run_acao_id = prm_run_acao_id;

exception when others then   
  	insert into bi_log_sistema values(sysdate, 'agentc.atu_status_acao :'||substr(DBMS_UTILITY.FORMAT_ERROR_STACK||DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,1,3900), 'AGENTC', 'ERRO');
     commit;

end atu_status_acao;


FUNCTION send_id RETURN VARCHAR2 AS
     
       TYPE           TP_ARRAY IS TABLE OF VARCHAR2(2000) INDEX BY BINARY_INTEGER;
       WS_ARRAY       TP_ARRAY;
       WS_COUNTER     INTEGER;

       WS_INDICE      VARCHAR2(1);
       WS_SESSION     VARCHAR2(2);
       WS_INDICE_FAKE VARCHAR2(1);
      WS_IMEI        VARCHAR2(30) := '012756003461913877';
      WS_ORIGEM      VARCHAR2(30);

    BEGIN

      WS_ARRAY(0)     := 'QPWOLASJIE';
      WS_ARRAY(1)     := 'ESLWPQMZNB';
      WS_ARRAY(2)     := 'YTRUIELQCB';
      WS_ARRAY(3)     := 'RADIOSULTE';
      WS_ARRAY(4)     := 'RITALQWCVM';
      WS_ARRAY(5)     := 'ZMAKQOCJDE';
      WS_ARRAY(6)     := 'YTHEDJKSPQ';
      WS_ARRAY(7)     := 'PIRALEZOUT';
      WS_ARRAY(8)     := 'HJWPAXOQTI';
      WS_ARRAY(9)     := 'DFRTEOAPQX';

      WS_INDICE       := SUBSTR(TO_CHAR(SYSDATE,'SS'),2,1);

      SELECT  SUBSTR(WS_ARRAY(WS_INDICE),(TO_NUMBER(SUBSTR(SID,1,1))+1),1)||SUBSTR(WS_ARRAY(WS_INDICE),(TO_NUMBER(SUBSTR(SERIAL#,1,1))+1),1)
              INTO WS_SESSION
      FROM    V$SESSION
      WHERE   AUDSID  = USERENV('SESSIONID');

      WS_INDICE_FAKE := ABS((TO_NUMBER(WS_INDICE)-TO_NUMBER(SUBSTR(TO_CHAR(SYSDATE,'SS'),1,1))));

      WS_IMEI := SUBSTR(WS_ARRAY(WS_INDICE_FAKE),(TO_NUMBER(SUBSTR(WS_IMEI,9, 1))+1),1)||
                 SUBSTR(WS_ARRAY(WS_INDICE_FAKE),(TO_NUMBER(SUBSTR(WS_IMEI,10,1))+1),1)||
                 SUBSTR(WS_ARRAY(WS_INDICE_FAKE),(TO_NUMBER(SUBSTR(WS_IMEI,11,1))+1),1);

      WS_INDICE_FAKE := SUBSTR(WS_ARRAY(2),(TO_NUMBER(SUBSTR(WS_INDICE_FAKE, 1,1)+1)),1);
      WS_INDICE      := SUBSTR(WS_ARRAY(1),(TO_NUMBER(SUBSTR(WS_INDICE,      1,1)+1)),1);

      RETURN(WS_IMEI||WS_SESSION||WS_INDICE||WS_INDICE_FAKE);

END SEND_ID;

FUNCTION B2C(P_BLOB BLOB) RETURN CLOB IS
      L_CLOB         CLOB;
      L_DEST_OFFSSET INTEGER := 1;
      L_SRC_OFFSSET  INTEGER := 1;
      L_LANG_CONTEXT INTEGER := DBMS_LOB.DEFAULT_LANG_CTX;
      L_WARNING      INTEGER;

BEGIN

      IF P_BLOB IS NULL THEN
         RETURN NULL;
      END IF;

      DBMS_LOB.CREATETEMPORARY(LOB_LOC => L_CLOB
                              ,CACHE   => FALSE);

      DBMS_LOB.CONVERTTOCLOB(DEST_LOB     => L_CLOB
                            ,SRC_BLOB     => P_BLOB
                            ,AMOUNT       => DBMS_LOB.LOBMAXSIZE
                            ,DEST_OFFSET  => L_DEST_OFFSSET
                            ,SRC_OFFSET   => L_SRC_OFFSSET
                            ,BLOB_CSID    => DBMS_LOB.DEFAULT_CSID
                            ,LANG_CONTEXT => L_LANG_CONTEXT
                            ,WARNING      => L_WARNING);

      RETURN L_CLOB;

END B2C;				 


end agentc;