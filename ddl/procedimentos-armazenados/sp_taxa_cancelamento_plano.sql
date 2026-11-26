/*==============================================================*/
/* FutureFit - Sistema de Assinatura para Academias             */
/* Stored procedure: sp_taxa_cancelamento_plano                 */
/* Issue #14 (usada na pergunta de negocio 2)                   */
/*==============================================================*/
/* Para cada plano, considera as assinaturas iniciadas entre    */
/* @dt_inicio e @dt_fim e retorna:                              */
/*   - total de assinaturas, canceladas, finalizadas e vigentes */
/*   - taxa de cancelamento (%) e participacao do plano no      */
/*     total de cancelamentos do periodo                        */
/*   - receita mensal perdida com os cancelamentos              */
/*   - ranking dos planos pela taxa de cancelamento             */
/*                                                              */
/* Justificativa: relatorio gerencial parametrizado por periodo,*/
/* executado com frequencia pela gerencia. Na procedure o plano */
/* de execucao fica em cache, a regra de calculo fica unica e o */
/* periodo e validado antes da consulta.                        */
/*==============================================================*/

USE futurefit;
GO

DROP PROCEDURE IF EXISTS dbo.sp_taxa_cancelamento_plano;
GO

CREATE PROCEDURE dbo.sp_taxa_cancelamento_plano
    @dt_inicio DATE,
    @dt_fim    DATE
AS
BEGIN
    SET NOCOUNT ON;

    IF @dt_inicio IS NULL OR @dt_fim IS NULL OR @dt_fim < @dt_inicio
    BEGIN
        RAISERROR('Periodo invalido: informe @dt_inicio <= @dt_fim.', 16, 1);
        RETURN;
    END;

    -- 1) Assinaturas do periodo (busca pelo indice ix_assinatura_dt_inicio)
    WITH assinaturas_periodo AS (
        SELECT a.cd_plano,
               a.st_assinatura,
               a.vl_mensal_contratado
          FROM assinatura a
         WHERE a.dt_inicio BETWEEN @dt_inicio AND @dt_fim
    ),
    -- 2) Totais por plano
    resumo AS (
        SELECT pl.cd_plano,
               pl.nm_plano,
               pl.qt_duracao_meses,
               COUNT(*)                                                      AS qt_assinaturas,
               SUM(CASE WHEN ap.st_assinatura = 'C' THEN 1 ELSE 0 END)       AS qt_canceladas,
               SUM(CASE WHEN ap.st_assinatura = 'F' THEN 1 ELSE 0 END)       AS qt_finalizadas,
               SUM(CASE WHEN ap.st_assinatura IN ('A','T') THEN 1 ELSE 0 END) AS qt_vigentes,
               SUM(CASE WHEN ap.st_assinatura = 'C' THEN ap.vl_mensal_contratado ELSE 0 END) AS vl_mensal_perdido
          FROM assinaturas_periodo ap
          JOIN plano pl ON pl.cd_plano = ap.cd_plano
         GROUP BY pl.cd_plano, pl.nm_plano, pl.qt_duracao_meses
    )
    -- 3) Taxas e ranking (funcoes de janela)
    SELECT cd_plano,
           nm_plano,
           qt_duracao_meses,
           qt_assinaturas,
           qt_canceladas,
           qt_finalizadas,
           qt_vigentes,
           CAST(100.0 * qt_canceladas / qt_assinaturas AS DECIMAL(5,2))  AS pc_cancelamento,
           CAST(100.0 * qt_canceladas
                / NULLIF(SUM(qt_canceladas) OVER (), 0) AS DECIMAL(5,2)) AS pc_dos_cancelamentos,
           vl_mensal_perdido,
           DENSE_RANK() OVER (ORDER BY 1.0 * qt_canceladas / qt_assinaturas DESC) AS nr_ranking
      FROM resumo
     ORDER BY nr_ranking, qt_assinaturas DESC;
END
GO
