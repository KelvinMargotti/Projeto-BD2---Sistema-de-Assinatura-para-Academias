/*==============================================================*/
/* FutureFit - Sistema de Assinatura para Academias             */
/* Exemplo de uso: nova matricula + sp_gerar_mensalidades       */
/*==============================================================*/
/* Cadastra um novo aluno, cria a assinatura de um plano        */
/* semestral e gera as 6 parcelas pela procedure. Roda dentro   */
/* de uma transacao com ROLLBACK no final para nao alterar a    */
/* carga de dados; troque por COMMIT para gravar de verdade.    */
/*==============================================================*/

USE futurefit;
GO

BEGIN TRANSACTION;

DECLARE @cd_pessoa INT, @cd_assinatura INT;

INSERT INTO pessoa (nm_pessoa, nr_cpf, ds_email, nr_telefone, dt_nascimento)
VALUES ('Mariana Cechinel Rocha', '52998224725', 'mariana.rocha@gmail.com', '48991234567', '2001-03-14');
SET @cd_pessoa = SCOPE_IDENTITY();

INSERT INTO aluno (cd_aluno) VALUES (@cd_pessoa);   -- dt_matricula e st_aluno pelo DEFAULT

INSERT INTO assinatura (cd_aluno, cd_plano, dt_inicio, dt_fim, nr_dia_vencimento, vl_mensal_contratado)
SELECT @cd_pessoa, pl.cd_plano, CAST(GETDATE() AS DATE),
       DATEADD(MONTH, pl.qt_duracao_meses, CAST(GETDATE() AS DATE)), 10, pl.vl_mensal
  FROM plano pl
 WHERE pl.nm_plano = 'Semestral Completo';
SET @cd_assinatura = SCOPE_IDENTITY();

EXEC dbo.sp_gerar_mensalidades @cd_assinatura = @cd_assinatura;   -- gera 6 parcelas
EXEC dbo.sp_gerar_mensalidades @cd_assinatura = @cd_assinatura;   -- 2a execucao: 0 parcelas (nao duplica)

SELECT nr_parcela, dt_vencimento, vl_cobrado, st_pagamento
  FROM pagamento
 WHERE cd_assinatura = @cd_assinatura
 ORDER BY nr_parcela;

SELECT dbo.fn_status_acesso(@cd_pessoa, CAST(GETDATE() AS DATE), DEFAULT) AS st_acesso_hoje;

ROLLBACK TRANSACTION;   -- troque por COMMIT TRANSACTION para gravar
GO
