create or replace package     agentc is

     function chk_cliente (      p_id_cliente      varchar2,
	                             p_check_id        varchar2 ) return boolean;
    function chk_registro ( p_id_cliente    varchar2,
	                        p_tp_registro   varchar2 ) return boolean ;

	 procedure request_begin (   p_id_cliente      varchar2 default null,
                                 p_check_id        varchar2 default null,
                                 p_versao          varchar2 default null );

     procedure request_con (     p_id_cliente      varchar2 default null,
                                 p_check_id        varchar2 default null );

     procedure request_list (    p_id_cliente      varchar2 default null,
	                             p_check_id        varchar2 default null );

	 procedure request_end (     p_id_cliente      varchar2 default null,
	                             p_check_id        varchar2 default null );

     procedure acao_end (        p_id_cliente      varchar2 default null,
	                             p_check_id        varchar2 default null,
                                 p_id_acao         varchar2 default null,
                                 p_second          varchar2 default null,
                                 p_second_upload   varchar2 default null,
                                 p_second_processo varchar2 default null);


     procedure request_acao (    p_id_cliente      varchar2 default null,
                                 p_check_id        varchar2 default null,
                                 p_id_acao         varchar2 default null,
                                 p_conteudo_envio  varchar2 default 'N' );

     procedure put_error (       p_id_cliente      varchar2 default null,
	                             p_check_id        varchar2 default null,
                                 p_id_acao         varchar2 default null,
                                 p_erro_txt        varchar2 default null );

     procedure upload (          p_documento       IN varchar2 default null,
                                 p_id_cliente      varchar2 default null,
                                 p_check_id        varchar2 default null,
                                 p_id_acao         varchar2 default null );

     procedure uptest ;


     procedure error_domweb (
                                 p_id_cliente      varchar2 DEFAULT NULL,
                                 p_nm_arquivo      varchar2 DEFAULT NULL,
                                 p_erro_txt        varchar2 DEFAULT null
                       );
    procedure atu_status_acao ( prm_id_run_acao   number, 
                                prm_status        varchar2 ) ; 
    
    function send_id return varchar2;

end agentc;