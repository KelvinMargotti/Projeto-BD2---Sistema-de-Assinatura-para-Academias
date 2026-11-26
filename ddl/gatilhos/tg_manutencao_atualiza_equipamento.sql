/*==============================================================*/
/* FutureFit - Sistema de Assinatura para Academias             */
/* Trigger: tg_manutencao_atualiza_equipamento                  */
/* Issue #13                                                    */
/*==============================================================*/
/* Mantem a desnormalizacao controlada da tabela equipamento:   */
/*   - dt_ultima_manutencao = data da ultima manutencao         */
/*     concluida (st_manutencao = 'C')                          */
/*   - st_equipamento = 'M' enquanto houver manutencao em       */
/*     andamento (st_manutencao = 'A'); volta para 'D' quando   */
/*     todas forem concluidas. Equipamento desativado ('X')     */
/*     nunca e alterado pela trigger.                           */
/*                                                              */
/* Justificativa: sem a trigger, cada tela que registra ou      */
/* conclui uma manutencao teria que lembrar de atualizar o      */
/* equipamento. A trigger garante a consistencia no proprio     */
/* banco, para INSERT, UPDATE e DELETE, inclusive em lote.      */
/*==============================================================*/

USE futurefit;
GO

DROP TRIGGER IF EXISTS dbo.tg_manutencao_atualiza_equipamento;
GO

CREATE TRIGGER dbo.tg_manutencao_atualiza_equipamento
ON dbo.manutencao_equipamento
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    /* Equipamentos afetados pela operacao (linhas novas e antigas) */
    WITH afetados AS (
        SELECT cd_equipamento FROM inserted
        UNION
        SELECT cd_equipamento FROM deleted
    )
    UPDATE e
       SET e.dt_ultima_manutencao = (
               SELECT MAX(m.dt_manutencao)
                 FROM manutencao_equipamento m
                WHERE m.cd_equipamento = e.cd_equipamento
                  AND m.st_manutencao = 'C'),
           e.st_equipamento = CASE
               WHEN e.st_equipamento = 'X' THEN 'X'
               WHEN EXISTS (SELECT 1
                              FROM manutencao_equipamento m
                             WHERE m.cd_equipamento = e.cd_equipamento
                               AND m.st_manutencao = 'A') THEN 'M'
               ELSE 'D'
           END
      FROM equipamento e
      JOIN afetados af ON af.cd_equipamento = e.cd_equipamento;
END
GO
