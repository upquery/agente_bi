Cadastros - Básicos 
    - CTB_SISTEMAS
    - CTB_TIPO_BANCO
    - CTB_CLIENTES
    - CTB_USUARIO_CLIENTE  (Cadastra as empresas que o usuário terá acesso)

Controle - Agente 
    - CTB_ERROS      - Log de Erros     - SELEÇAO EMPRESA (todas) - FLOAT PART - filtro empresas - order by dt_registro desc - Monitoramento
    - CTB_REGISTRO   - Registros Agente - SELEÇAO EMPRESA (todas) - FLOAT PART - filtro empresas - order by dt_registro desc
    - CTB_UPDATE     - Controle de atualização de versão da aplicatição agente

Controle - Inserção Python 
	- CTB_LOCK_INSERCAO  - libera ou bloqueia inserção 

Cadastros - Integração
    - CTB_CONEXOES  - Conexões Origem  - SELEÇAO EMPRESA - semelhante ao Java (NOME CLIENTE(ID_CLIENTE), ID_CONEXAO, SISTEMA, DB, HOST, USUARIO, SENHA, DATABASE) - semelhante etl_conexoes 
    - CTB_DESTINO   - Conexões Destino - SELEÇAO EMPRESA - Fixar parametros HOST, PORTA, USUARIO, SENHA, SERVICE_NAME (semelhante ao cadastro de conexões) 
    - CTB_ACOES     - Ações            - SELEÇAO EMPRESA - cadastrar o SQL no ds_execute (semelhante ao ETL_STEP)
    - CTB_RUN           - Tarefas             - SELEÇAO EMPRESA - (run_id, ds_run, dt_cadastro, st_ativo, last_run, last_status)    - tela semelhante a ETL_RUN 
    - CTB_RUN_ACOES 	 - Cadastrar ações da tarefa
    - CTB_RUN_SCHEDULE   - Agendamento 
    - CTB_RUN_PARAM      - Parametros 
Movimento - Integração 
    - CTB_ACOES_EXEC - log 
    - CTB_DOCS  -log 
			


Novas 
ctb_run
ctb_run_schedule
ctb_run_param
ctb_run_acoes

Baseadas no agente atual
ctb_acoes      - (adicionado comando e comando_limpar)  - CREATE unique INDEX ctb_acoes_IDX01 ON ctb_acoes (id_acao); 
CTB_ACOES_exec - (adicionado  run_acao_id, erro, comando_limpar)  - criado indexes 
TMP_DOCS       - CREATE INDEX tmp_docs_IDX01 ON tmp_docs (id_cliente, id_acao); 
ctb_cliente_usuario - clientes que o usuário tem acesso 

- Não alterar porque também é usado pelo agente 
CTB_UPDATE    -- Alteração de URL ??
CTB_INVALIDO  -- registra chave inválida 
CTB_ERROS_DOMWEB  -- Criar  Consulta 
CTB_CLIENTES  -- status de comunicação com o cliente
CTB_UPDATE    -- ??
