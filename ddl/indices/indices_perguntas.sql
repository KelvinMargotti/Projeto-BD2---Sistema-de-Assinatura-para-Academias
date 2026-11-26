/*==============================================================*/
/* FutureFit - Sistema de Assinatura para Academias             */
/* Indices nonclustered das perguntas de negocio                */
/* Issue #16                                                    */
/*==============================================================*/
/* Os indices clustered sao as PKs criadas no script DDL.       */
/* Cada indice abaixo cobre (INCLUDE) as colunas lidas pela     */
/* consulta, evitando Key Lookup no indice clustered.           */
/*==============================================================*/

USE futurefit;
GO

/*==============================================================*/
/* Pergunta 1 - inadimplencia                                   */
/* Filtro: st_pagamento = 'P' e dt_vencimento < hoje            */
/* Igualdade na 1a chave e intervalo na 2a = Index Seek         */
/*==============================================================*/
DROP INDEX IF EXISTS ix_pagamento_st_dt_vencimento ON pagamento;
CREATE NONCLUSTERED INDEX ix_pagamento_st_dt_vencimento
    ON pagamento (st_pagamento, dt_vencimento)
    INCLUDE (cd_assinatura, vl_cobrado);
GO

/*==============================================================*/
/* Pergunta 1 (dentro de fn_status_acesso)                      */
/* Busca as assinaturas de um aluno pelo cd_aluno (FK sem       */
/* indice no DDL)                                               */
/*==============================================================*/
DROP INDEX IF EXISTS ix_assinatura_aluno_st ON assinatura;
CREATE NONCLUSTERED INDEX ix_assinatura_aluno_st
    ON assinatura (cd_aluno, st_assinatura)
    INCLUDE (cd_plano, dt_inicio, dt_fim, dt_cancelamento);
GO

/*==============================================================*/
/* Pergunta 2 (sp_taxa_cancelamento_plano) - cancelamentos      */
/* Filtro: intervalo de dt_inicio da assinatura                 */
/*==============================================================*/
DROP INDEX IF EXISTS ix_assinatura_dt_inicio ON assinatura;
CREATE NONCLUSTERED INDEX ix_assinatura_dt_inicio
    ON assinatura (dt_inicio)
    INCLUDE (cd_plano, st_assinatura, vl_mensal_contratado);
GO
