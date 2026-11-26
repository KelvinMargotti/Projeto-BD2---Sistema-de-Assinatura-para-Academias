/*==============================================================*/
/* FutureFit - Sistema de Assinatura para Academias             */
/* Stored procedure: sp_gerar_mensalidades                      */
/* Issue #14                                                    */
/*==============================================================*/
/* Gera as parcelas (tabela pagamento) que ainda nao existem    */
/* para as assinaturas ativas. Regras:                          */
/*   - quantidade de parcelas = plano.qt_duracao_meses          */
/*   - parcela 1 vence em assinatura.dt_inicio                  */
/*   - parcela N vence no nr_dia_vencimento do mes N-1 apos o   */
/*     inicio                                                   */
/*   - parcela 1 inclui a taxa de matricula do plano somente    */
/*     se for a primeira assinatura do aluno                    */
/*   - parcelas ja existentes nao sao duplicadas (pode rodar    */
/*     varias vezes)                                            */
/* Parametro @cd_assinatura NULL = todas as assinaturas ativas. */
/*                                                              */
/* Justificativa: a geracao das mensalidades e um processo de   */
/* negocio com varias etapas e regras; a procedure executa tudo */
/* em uma transacao, no servidor, e e reaproveitada pelo CRUD   */
/* e por rotinas agendadas.                                     */
/*==============================================================*/

USE futurefit;
GO

DROP PROCEDURE IF EXISTS dbo.sp_gerar_mensalidades;
GO

CREATE PROCEDURE dbo.sp_gerar_mensalidades
    @cd_assinatura INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;

    WITH numeros AS (
        SELECT CAST(n AS TINYINT) AS nr_parcela
          FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)) AS t(n)
    ),
    parcelas AS (
        SELECT a.cd_assinatura,
               n.nr_parcela,
               CASE WHEN n.nr_parcela = 1 THEN a.dt_inicio
                    ELSE DATEFROMPARTS(YEAR(DATEADD(MONTH, n.nr_parcela - 1, a.dt_inicio)),
                                       MONTH(DATEADD(MONTH, n.nr_parcela - 1, a.dt_inicio)),
                                       a.nr_dia_vencimento)
               END AS dt_vencimento,
               a.vl_mensal_contratado
               + CASE WHEN n.nr_parcela = 1
                       AND NOT EXISTS (SELECT 1
                                         FROM assinatura ant
                                        WHERE ant.cd_aluno = a.cd_aluno
                                          AND ant.dt_inicio < a.dt_inicio)
                      THEN pl.vl_taxa_matricula ELSE 0 END AS vl_cobrado
          FROM assinatura a
          JOIN plano pl  ON pl.cd_plano = a.cd_plano
          JOIN numeros n ON n.nr_parcela <= pl.qt_duracao_meses
         WHERE a.st_assinatura = 'A'
           AND (@cd_assinatura IS NULL OR a.cd_assinatura = @cd_assinatura)
    )
    INSERT INTO pagamento (cd_assinatura, nr_parcela, dt_vencimento, vl_cobrado, st_pagamento)
    SELECT pc.cd_assinatura, pc.nr_parcela, pc.dt_vencimento, pc.vl_cobrado, 'P'
      FROM parcelas pc
     WHERE NOT EXISTS (SELECT 1
                         FROM pagamento p
                        WHERE p.cd_assinatura = pc.cd_assinatura
                          AND p.nr_parcela    = pc.nr_parcela);

    SELECT @@ROWCOUNT AS qt_parcelas_geradas;

    COMMIT TRANSACTION;
END
GO
