create or replace PACKAGE CTB  is

------ Funcoes copiadas da FUN ------------------------------------------------------------------------------
function randomCode( prm_tamanho number default 10) return varchar2 ;  

function c2b ( p_clob in clob ) return blob ; 

function b2c ( p_blob blob ) return clob ;

function ret_var  ( prm_variavel   varchar2 default null, 
                    prm_usuario    varchar2 default 'DWU' ) return varchar2; 

function xexec ( ws_content  varchar2 default null ) return varchar2 ; 

function vpipe ( prm_entrada varchar2,
                 prm_divisao varchar2 default '|' ) return CHARRET pipelined ; 

---------------------------------------------------------------------------------------------------------


procedure exec_schdl;

procedure exec_run (prm_run_id             varchar2,
                    prm_run_acao_id        varchar2 default null,
					prm_retorno     in out varchar2) ; 

procedure ctb_run_param_atu(prm_run_id varchar2) ;

procedure exec_param_substitui (prm_run_id          in varchar2, 
                                prm_run_acao_id     in varchar2,
                                prm_id_acao         in varchar2,
                                prm_comando     in out varchar2,
                                prm_parametros  in out varchar2,
                                prm_erro        in out varchar2 ) ;

procedure ctb_atu_status_acao ( prm_run_acao_id  number, 
	                            prm_status       varchar2 ) ; 
procedure ctb_atu_status_run ( prm_run_id      varchar2,
                               prm_status in out varchar2 ) ; 

---------------------------------------------------------------------------------------------------------

function ctb_clie_usua_get (prm_usuario varchar2) return varchar2 ;

procedure ctb_clie_usua_atu (prm_usuario varchar2 default null, prm_id_cliente varchar2) ;

function prn_a_status  (prm_status varchar2) return varchar2 ; 

procedure menu_ctb (prm_menu      varchar2, 
		            prm_tipo      varchar2 default null,
					prm_id_copia  varchar2 default null) ; 

procedure ctb_conexoes_valida (prm_acao           varchar2, 
						 	   prm_campo          varchar2, 
                               prm_conteudo       varchar2,
							   prm_retorno    out varchar2 ) ; 

procedure ctb_conexoes_list (prm_id_cliente  varchar2 default null) ;

procedure ctb_conexoes_insert ( prm_parametros    varchar2, 
							    prm_conteudos     varchar2 ) ; 

procedure ctb_conexoes_update ( prm_id_cliente    varchar2, 
                                prm_id_conexao    varchar2, 
                                prm_cd_parametro  varchar2,
							    prm_conteudo      varchar2 ) ; 

procedure ctb_conexoes_delete ( prm_id_cliente  varchar2, 
                                prm_id_conexao  varchar2 ); 

procedure ctb_acoes_list (prm_id_cliente   varchar2 default null,
                          prm_id_acao      varchar2 default null,
						  prm_order        varchar2 default '2',
						  prm_dir          varchar2 default '1') ; 

procedure ctb_acoes_insert (prm_id_cliente       varchar2,
							prm_ds_acao          varchar2, 
                            prm_id_conexao       varchar2,
						    prm_tabela_criterio  varchar2,
						    prm_tabela_transp    varchar2,
						    prm_id_copia         varchar2 default null); 

procedure ctb_acoes_update (prm_id_acao       varchar2, 
                           	prm_cd_parametro  varchar2,
						   	prm_conteudo      varchar2 ) ;

procedure ctb_acoes_delete (prm_id_acao     varchar2 ) ;


procedure ctb_acoes_comando (prm_id_acao    varchar2, 
                             prm_coluna     varchar2) ; 

procedure ctb_acoes_exec_list(prm_tp      varchar2,
                              prm_id      varchar2,
					          prm_linhas	varchar2 default '50') ; 

procedure tmp_docs_list (prm_id_cliente   varchar2,
                         prm_id_acao      varchar2,
					     prm_linhas	      varchar2 default '50') ; 

procedure ctb_run_list (prm_id_cliente  varchar2 default null, 
                        prm_order       varchar2 default '2', 
                        prm_dir         varchar2 default '1') ;
procedure ctb_run_insert (prm_id_cliente  varchar2, 
                          prm_ds_run      varchar2) ; 

procedure ctb_run_update ( prm_run_id       varchar2, 
                           prm_cd_parametro  varchar2,
						   prm_conteudo      varchar2 ) ; 
                           
procedure ctb_run_delete (prm_run_id varchar2 ); 

procedure ctb_run_schedule_list(prm_run_id     varchar2) ;
procedure ctb_run_schedule_insert (prm_run_id         varchar2,
								   prm_nr_dia_semana  varchar2,
								   prm_nr_dia_mes     varchar2,
							   	   prm_nr_mes         varchar2,
								   prm_nr_hora        varchar2, 
						   		   prm_nr_minuto      varchar2
                               	   ) ; 
procedure ctb_run_schedule_update ( prm_schedule_id   varchar2, 
                 	          	    prm_cd_parametro  varchar2,
							   	    prm_conteudo      varchar2 ); 
procedure ctb_run_schedule_delete (prm_schedule_id varchar2 ); 

procedure ctb_run_acoes_list(prm_run_id     varchar2) ; 

procedure ctb_run_acoes_insert (prm_run_id        varchar2,
                                prm_ordem         varchar2,
						        prm_id_acao       varchar2) ; 

procedure ctb_run_acoes_update ( prm_run_acao_id   varchar2, 
                           	     prm_cd_parametro  varchar2,
						   	     prm_conteudo      varchar2 ); 

procedure ctb_run_acoes_delete (prm_run_acao_id varchar2 );                                  

procedure ctb_run_param_list(prm_run_id     varchar2);

procedure ctb_run_param_update ( prm_run_id        varchar2, 
                           	     prm_cd_parametro  varchar2,
								 prm_campo         varchar2, 
						   	     prm_conteudo      varchar2 );

procedure ctb_run_exec (prm_run_id      varchar2,
                        prm_run_acao_id varchar2 default null); 

procedure ctb_run_stop (prm_run_id   varchar2);

END CTB;