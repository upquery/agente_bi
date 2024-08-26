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
