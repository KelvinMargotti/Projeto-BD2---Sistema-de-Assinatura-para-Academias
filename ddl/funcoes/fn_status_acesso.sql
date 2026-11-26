/*==============================================================*/
/* FutureFit - Sistema de Assinatura para Academias             */
/* Funcao: fn_status_acesso                                     */
/* Issue #12                                                    */
/*==============================================================*/
/* Retorna a situacao de acesso de um aluno em uma data:        */
/*   L = liberado                                               */
/*   I = bloqueado por inadimplencia (mensalidade pendente      */
/*       vencida ha mais de @qt_dias_tolerancia dias)           */
/*   V = plano vencido (sem assinatura vigente na data,         */
/*       assinatura trancada ou aluno inativo)                  */
/* Os codigos sao os mesmos da coluna checkin.st_acesso, entao  */
/* a recepcao pode gravar o check-in direto com o retorno.      */
/*                                                              */
/* Justificativa: a regra de liberacao e usada em varios lugares*/
/* (catraca, recepcao, relatorios, pergunta 1). Uma funcao      */
/* escalar centraliza a regra em um unico ponto e pode ser      */
/* chamada dentro de SELECT, WHERE e INSERT.                    */
/*==============================================================*/

USE futurefit;
GO

DROP FUNCTION IF EXISTS dbo.fn_status_acesso;
GO

CREATE FUNCTION dbo.fn_status_acesso (
    @cd_aluno            INT,
    @dt_referencia       DATE,
    @qt_dias_tolerancia  TINYINT = 5
)
RETURNS CHAR(1)
AS
BEGIN
    DECLARE @st_acesso CHAR(1);

    -- 1) Aluno precisa estar ativo e ter assinatura vigente na data.
    --    Assinaturas finalizadas (F) contam dentro do proprio periodo e as
    --    canceladas (C) contam ate a data do cancelamento, entao a funcao
    --    tambem responde corretamente para datas passadas.
    --    Assinatura trancada (T) e aluno inativo bloqueiam a partir de hoje;
    --    o banco nao guarda a data do trancamento/inativacao, entao para
    --    datas passadas esses dois estados nao sao considerados.
    DECLARE @dt_hoje DATE = CAST(GETDATE() AS DATE);

    IF NOT EXISTS (
        SELECT 1
          FROM assinatura a
          JOIN aluno al ON al.cd_aluno = a.cd_aluno
         WHERE a.cd_aluno = @cd_aluno
           AND (al.st_aluno = 1 OR @dt_referencia < @dt_hoje)
           AND (a.st_assinatura IN ('A','F')
                OR (a.st_assinatura = 'T' AND @dt_referencia < @dt_hoje)
                OR (a.st_assinatura = 'C' AND @dt_referencia <= a.dt_cancelamento))
           AND @dt_referencia >= a.dt_inicio
           AND @dt_referencia <  a.dt_fim
    )
        SET @st_acesso = 'V';

    -- 2) Mensalidade pendente vencida alem da tolerancia bloqueia o acesso
    ELSE IF EXISTS (
        SELECT 1
          FROM assinatura a
          JOIN pagamento p ON p.cd_assinatura = a.cd_assinatura
         WHERE a.cd_aluno = @cd_aluno
           AND p.st_pagamento = 'P'
           AND p.dt_vencimento < DATEADD(DAY, -@qt_dias_tolerancia, @dt_referencia)
    )
        SET @st_acesso = 'I';

    ELSE
        SET @st_acesso = 'L';

    RETURN @st_acesso;
END
GO
