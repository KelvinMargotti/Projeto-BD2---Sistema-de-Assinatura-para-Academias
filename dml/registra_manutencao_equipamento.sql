/*==============================================================*/
/* FutureFit - Sistema de Assinatura para Academias             */
/* Exemplo de uso: tg_manutencao_atualiza_equipamento           */
/*==============================================================*/
/* Abre uma manutencao corretiva (equipamento vai para 'M'),    */
/* conclui a manutencao (equipamento volta para 'D' e recebe a  */
/* data da ultima manutencao). Transacao com ROLLBACK no final. */
/*==============================================================*/

USE futurefit;
GO

BEGIN TRANSACTION;

DECLARE @cd_equipamento SMALLINT = (SELECT cd_equipamento FROM equipamento WHERE cd_patrimonio = 'FF-EQ-0008');
DECLARE @cd_manutencao INT;

SELECT 'antes' AS ds_momento, cd_equipamento, nm_equipamento, st_equipamento, dt_ultima_manutencao
  FROM equipamento WHERE cd_equipamento = @cd_equipamento;

INSERT INTO manutencao_equipamento (cd_equipamento, cd_funcionario, tp_manutencao, vl_custo, ds_servico, st_manutencao)
SELECT TOP 1 @cd_equipamento, f.cd_funcionario, 'C', 380.00, 'Troca do cabo de aco do leg press', 'A'
  FROM funcionario f WHERE f.ds_cargo = 'Tecnico' AND f.st_funcionario = 1 ORDER BY f.cd_funcionario;
SET @cd_manutencao = SCOPE_IDENTITY();

SELECT 'manutencao aberta' AS ds_momento, cd_equipamento, nm_equipamento, st_equipamento, dt_ultima_manutencao
  FROM equipamento WHERE cd_equipamento = @cd_equipamento;

UPDATE manutencao_equipamento SET st_manutencao = 'C' WHERE cd_manutencao = @cd_manutencao;

SELECT 'manutencao concluida' AS ds_momento, cd_equipamento, nm_equipamento, st_equipamento, dt_ultima_manutencao
  FROM equipamento WHERE cd_equipamento = @cd_equipamento;

ROLLBACK TRANSACTION;   -- troque por COMMIT TRANSACTION para gravar
GO
