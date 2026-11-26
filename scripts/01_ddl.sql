/*==============================================================*/
/* FutureFit - Sistema de Assinatura para Academias             */
/* Script DDL - criacao do banco de dados                       */
/* SGBD: Microsoft SQL Server                                   */
/*==============================================================*/

IF DB_ID('futurefit') IS NULL
    CREATE DATABASE futurefit;
GO

USE futurefit;
GO

/*==============================================================*/
/* Table: pessoa  (GENERALIZACAO de aluno e funcionario)        */
/*==============================================================*/
CREATE TABLE pessoa (
    cd_pessoa       INT IDENTITY(1,1)  NOT NULL,
    nm_pessoa       VARCHAR(100)       NOT NULL,
    nr_cpf          CHAR(11)           NOT NULL,
    ds_email        VARCHAR(100)       NULL,
    nr_telefone     VARCHAR(11)        NULL,
    dt_nascimento   DATE               NOT NULL,
    dt_cadastro     DATE               NOT NULL CONSTRAINT df_pessoa_dt_cadastro DEFAULT (CAST(GETDATE() AS DATE)),
    CONSTRAINT pk_pessoa PRIMARY KEY CLUSTERED (cd_pessoa),
    CONSTRAINT uq_pessoa_cpf UNIQUE (nr_cpf),
    CONSTRAINT ck_pessoa_cpf CHECK (nr_cpf NOT LIKE '%[^0-9]%'),
    CONSTRAINT ck_pessoa_email CHECK (ds_email IS NULL OR ds_email LIKE '%_@_%._%'),
    CONSTRAINT ck_pessoa_telefone CHECK (nr_telefone IS NULL OR (LEN(nr_telefone) BETWEEN 10 AND 11 AND nr_telefone NOT LIKE '%[^0-9]%')),
    CONSTRAINT ck_pessoa_dt_nascimento CHECK (dt_nascimento >= '1900-01-01')
);
GO

/*==============================================================*/
/* Table: aluno  (ESPECIALIZACAO de pessoa)                     */
/*==============================================================*/
CREATE TABLE aluno (
    cd_aluno        INT                NOT NULL,
    dt_matricula    DATE               NOT NULL CONSTRAINT df_aluno_dt_matricula DEFAULT (CAST(GETDATE() AS DATE)),
    st_aluno        BIT                NOT NULL CONSTRAINT df_aluno_st DEFAULT (1),
    CONSTRAINT pk_aluno PRIMARY KEY CLUSTERED (cd_aluno),
    CONSTRAINT fk_aluno_pessoa FOREIGN KEY (cd_aluno) REFERENCES pessoa (cd_pessoa)
);
GO

/*==============================================================*/
/* Table: funcionario  (ESPECIALIZACAO de pessoa)               */
/*==============================================================*/
CREATE TABLE funcionario (
    cd_funcionario   INT               NOT NULL,
    ds_cargo         VARCHAR(20)       NOT NULL,
    nr_cref          VARCHAR(15)       NULL,
    ds_especialidade VARCHAR(30)       NULL,
    dt_admissao      DATE              NOT NULL CONSTRAINT df_funcionario_dt_admissao DEFAULT (CAST(GETDATE() AS DATE)),
    vl_salario       DECIMAL(8,2)      NOT NULL,
    st_funcionario   BIT               NOT NULL CONSTRAINT df_funcionario_st DEFAULT (1),
    CONSTRAINT pk_funcionario PRIMARY KEY CLUSTERED (cd_funcionario),
    CONSTRAINT fk_funcionario_pessoa FOREIGN KEY (cd_funcionario) REFERENCES pessoa (cd_pessoa),
    CONSTRAINT ck_funcionario_cargo CHECK (ds_cargo IN ('Instrutor','Recepcionista','Gerente','Tecnico')),
    CONSTRAINT ck_funcionario_cref CHECK (ds_cargo <> 'Instrutor' OR nr_cref IS NOT NULL),
    CONSTRAINT ck_funcionario_salario CHECK (vl_salario > 0)
);
GO

/*==============================================================*/
/* Table: plano                                                 */
/*==============================================================*/
CREATE TABLE plano (
    cd_plano          TINYINT IDENTITY(1,1) NOT NULL,
    nm_plano          VARCHAR(50)       NOT NULL,
    ds_plano          VARCHAR(500)      NULL,
    vl_mensal         DECIMAL(7,2)      NOT NULL,
    vl_taxa_matricula DECIMAL(7,2)      NOT NULL CONSTRAINT df_plano_taxa DEFAULT (0),
    qt_duracao_meses  TINYINT           NOT NULL,
    st_plano          BIT               NOT NULL CONSTRAINT df_plano_st DEFAULT (1),
    CONSTRAINT pk_plano PRIMARY KEY CLUSTERED (cd_plano),
    CONSTRAINT uq_plano_nome UNIQUE (nm_plano),
    CONSTRAINT ck_plano_vl_mensal CHECK (vl_mensal > 0),
    CONSTRAINT ck_plano_taxa CHECK (vl_taxa_matricula >= 0),
    CONSTRAINT ck_plano_duracao CHECK (qt_duracao_meses IN (1, 3, 6, 12))
);
GO

/*==============================================================*/
/* Table: assinatura                                            */
/*==============================================================*/
CREATE TABLE assinatura (
    cd_assinatura        INT IDENTITY(1,1) NOT NULL,
    cd_aluno             INT            NOT NULL,
    cd_plano             TINYINT        NOT NULL,
    dt_inicio            DATE           NOT NULL CONSTRAINT df_assinatura_dt_inicio DEFAULT (CAST(GETDATE() AS DATE)),
    dt_fim               DATE           NOT NULL,
    nr_dia_vencimento    TINYINT        NOT NULL CONSTRAINT df_assinatura_dia_venc DEFAULT (10),
    vl_mensal_contratado DECIMAL(7,2)   NOT NULL,
    st_assinatura        CHAR(1)        NOT NULL CONSTRAINT df_assinatura_st DEFAULT ('A'),
    dt_cancelamento      DATE           NULL,
    CONSTRAINT pk_assinatura PRIMARY KEY CLUSTERED (cd_assinatura),
    CONSTRAINT fk_assinatura_aluno FOREIGN KEY (cd_aluno) REFERENCES aluno (cd_aluno),
    CONSTRAINT fk_assinatura_plano FOREIGN KEY (cd_plano) REFERENCES plano (cd_plano),
    CONSTRAINT ck_assinatura_periodo CHECK (dt_fim > dt_inicio),
    CONSTRAINT ck_assinatura_dia_venc CHECK (nr_dia_vencimento BETWEEN 1 AND 28),
    CONSTRAINT ck_assinatura_valor CHECK (vl_mensal_contratado > 0),
    -- A = ativa | T = trancada | C = cancelada | F = finalizada (terminou sem renovar)
    CONSTRAINT ck_assinatura_st CHECK (st_assinatura IN ('A','T','C','F')),
    CONSTRAINT ck_assinatura_cancelamento CHECK (
        (st_assinatura = 'C' AND dt_cancelamento IS NOT NULL AND dt_cancelamento >= dt_inicio)
        OR (st_assinatura <> 'C' AND dt_cancelamento IS NULL))
);
GO

/*==============================================================*/
/* Table: forma_pagamento                                       */
/*==============================================================*/
CREATE TABLE forma_pagamento (
    cd_forma_pagamento TINYINT IDENTITY(1,1) NOT NULL,
    nm_forma_pagamento VARCHAR(40)     NOT NULL,
    -- C = credito | D = debito | P = pix | B = boleto | W = carteira digital | A = debito automatico | E = especie (dinheiro)
    tp_forma_pagamento CHAR(1)         NOT NULL,
    pc_taxa            DECIMAL(4,2)    NOT NULL CONSTRAINT df_forma_pagamento_taxa DEFAULT (0),
    CONSTRAINT pk_forma_pagamento PRIMARY KEY CLUSTERED (cd_forma_pagamento),
    CONSTRAINT uq_forma_pagamento_nome UNIQUE (nm_forma_pagamento),
    CONSTRAINT ck_forma_pagamento_tipo CHECK (tp_forma_pagamento IN ('C','D','P','B','W','A','E')),
    CONSTRAINT ck_forma_pagamento_taxa CHECK (pc_taxa BETWEEN 0 AND 20)
);
GO

/*==============================================================*/
/* Table: pagamento  (mensalidades de cada assinatura)          */
/*==============================================================*/
CREATE TABLE pagamento (
    cd_pagamento       INT IDENTITY(1,1) NOT NULL,
    cd_assinatura      INT            NOT NULL,
    cd_forma_pagamento TINYINT        NULL,
    nr_parcela         TINYINT        NOT NULL,
    dt_vencimento      DATE           NOT NULL,
    dt_pagamento       DATE           NULL,
    vl_cobrado         DECIMAL(7,2)   NOT NULL,
    vl_pago            DECIMAL(7,2)   NULL,
    -- P = pendente | G = pago | C = cancelado  (atraso = pendente com vencimento passado; e calculado, nao armazenado)
    st_pagamento       CHAR(1)        NOT NULL CONSTRAINT df_pagamento_st DEFAULT ('P'),
    CONSTRAINT pk_pagamento PRIMARY KEY CLUSTERED (cd_pagamento),
    CONSTRAINT fk_pagamento_assinatura FOREIGN KEY (cd_assinatura) REFERENCES assinatura (cd_assinatura),
    CONSTRAINT fk_pagamento_forma FOREIGN KEY (cd_forma_pagamento) REFERENCES forma_pagamento (cd_forma_pagamento),
    CONSTRAINT uq_pagamento_parcela UNIQUE (cd_assinatura, nr_parcela),
    CONSTRAINT ck_pagamento_parcela CHECK (nr_parcela BETWEEN 1 AND 12),
    CONSTRAINT ck_pagamento_vl_cobrado CHECK (vl_cobrado > 0),
    CONSTRAINT ck_pagamento_vl_pago CHECK (vl_pago IS NULL OR vl_pago >= 0),
    CONSTRAINT ck_pagamento_st CHECK (st_pagamento IN ('P','G','C')),
    CONSTRAINT ck_pagamento_quitado CHECK (
        st_pagamento <> 'G'
        OR (dt_pagamento IS NOT NULL AND vl_pago IS NOT NULL AND cd_forma_pagamento IS NOT NULL))
);
GO

/*==============================================================*/
/* Table: checkin  (frequencia dos alunos)                      */
/*==============================================================*/
CREATE TABLE checkin (
    cd_checkin   INT IDENTITY(1,1)  NOT NULL,
    cd_aluno     INT                NOT NULL,
    dt_entrada   DATETIME2(0)       NOT NULL CONSTRAINT df_checkin_dt_entrada DEFAULT (SYSDATETIME()),
    dt_saida     DATETIME2(0)       NULL,
    -- L = liberado | I = bloqueado por inadimplencia | V = plano vencido
    st_acesso    CHAR(1)            NOT NULL CONSTRAINT df_checkin_st DEFAULT ('L'),
    CONSTRAINT pk_checkin PRIMARY KEY CLUSTERED (cd_checkin),
    CONSTRAINT fk_checkin_aluno FOREIGN KEY (cd_aluno) REFERENCES aluno (cd_aluno),
    CONSTRAINT ck_checkin_saida CHECK (dt_saida IS NULL OR dt_saida > dt_entrada),
    CONSTRAINT ck_checkin_st CHECK (st_acesso IN ('L','I','V'))
);
GO

/*==============================================================*/
/* Table: avaliacao_fisica  (bioimpedancia)                     */
/*==============================================================*/
CREATE TABLE avaliacao_fisica (
    cd_avaliacao    INT IDENTITY(1,1)  NOT NULL,
    cd_aluno        INT                NOT NULL,
    cd_funcionario  INT                NOT NULL,
    dt_avaliacao    DATE               NOT NULL CONSTRAINT df_avaliacao_dt DEFAULT (CAST(GETDATE() AS DATE)),
    vl_peso         DECIMAL(5,2)       NOT NULL,
    vl_altura       DECIMAL(3,2)       NOT NULL,
    pc_gordura      DECIMAL(3,1)       NOT NULL,
    pc_massa_magra  DECIMAL(3,1)       NULL,
    ds_observacao   VARCHAR(500)       NULL,
    CONSTRAINT pk_avaliacao_fisica PRIMARY KEY CLUSTERED (cd_avaliacao),
    CONSTRAINT fk_avaliacao_aluno FOREIGN KEY (cd_aluno) REFERENCES aluno (cd_aluno),
    CONSTRAINT fk_avaliacao_funcionario FOREIGN KEY (cd_funcionario) REFERENCES funcionario (cd_funcionario),
    CONSTRAINT ck_avaliacao_peso CHECK (vl_peso BETWEEN 20 AND 350),
    CONSTRAINT ck_avaliacao_altura CHECK (vl_altura BETWEEN 0.50 AND 2.50),
    CONSTRAINT ck_avaliacao_gordura CHECK (pc_gordura BETWEEN 2 AND 70),
    CONSTRAINT ck_avaliacao_massa_magra CHECK (pc_massa_magra IS NULL OR pc_massa_magra BETWEEN 10 AND 90)
);
GO

/*==============================================================*/
/* Table: ficha_treino                                          */
/*==============================================================*/
CREATE TABLE ficha_treino (
    cd_ficha        INT IDENTITY(1,1)  NOT NULL,
    cd_aluno        INT                NOT NULL,
    cd_funcionario  INT                NOT NULL,
    ds_objetivo     VARCHAR(20)        NOT NULL,
    dt_inicio       DATE               NOT NULL CONSTRAINT df_ficha_dt_inicio DEFAULT (CAST(GETDATE() AS DATE)),
    dt_fim          DATE               NULL,
    st_ficha        BIT                NOT NULL CONSTRAINT df_ficha_st DEFAULT (1),
    CONSTRAINT pk_ficha_treino PRIMARY KEY CLUSTERED (cd_ficha),
    CONSTRAINT fk_ficha_aluno FOREIGN KEY (cd_aluno) REFERENCES aluno (cd_aluno),
    CONSTRAINT fk_ficha_funcionario FOREIGN KEY (cd_funcionario) REFERENCES funcionario (cd_funcionario),
    CONSTRAINT ck_ficha_objetivo CHECK (ds_objetivo IN ('Hipertrofia','Emagrecimento','Resistencia','Condicionamento','Reabilitacao')),
    CONSTRAINT ck_ficha_periodo CHECK (dt_fim IS NULL OR dt_fim > dt_inicio)
);
GO

/*==============================================================*/
/* Table: equipamento                                           */
/*==============================================================*/
CREATE TABLE equipamento (
    cd_equipamento       SMALLINT IDENTITY(1,1) NOT NULL,
    nm_equipamento       VARCHAR(100)   NOT NULL,
    cd_patrimonio        VARCHAR(20)    NOT NULL,
    dt_aquisicao         DATE           NOT NULL,
    vl_aquisicao         DECIMAL(9,2)   NOT NULL,
    -- D = disponivel | M = em manutencao | X = desativado
    st_equipamento       CHAR(1)        NOT NULL CONSTRAINT df_equipamento_st DEFAULT ('D'),
    -- Desnormalizacao controlada: mantida pela trigger tg_manutencao_atualiza_equipamento
    dt_ultima_manutencao DATE           NULL,
    CONSTRAINT pk_equipamento PRIMARY KEY CLUSTERED (cd_equipamento),
    CONSTRAINT uq_equipamento_patrimonio UNIQUE (cd_patrimonio),
    CONSTRAINT ck_equipamento_valor CHECK (vl_aquisicao >= 0),
    CONSTRAINT ck_equipamento_st CHECK (st_equipamento IN ('D','M','X'))
);
GO

/*==============================================================*/
/* Table: exercicio                                             */
/*==============================================================*/
CREATE TABLE exercicio (
    cd_exercicio       SMALLINT IDENTITY(1,1) NOT NULL,
    nm_exercicio       VARCHAR(100)   NOT NULL,
    ds_grupo_muscular  VARCHAR(15)    NOT NULL,
    cd_equipamento     SMALLINT       NULL,
    ds_url_video       VARCHAR(255)   NULL,
    CONSTRAINT pk_exercicio PRIMARY KEY CLUSTERED (cd_exercicio),
    CONSTRAINT uq_exercicio_nome UNIQUE (nm_exercicio),
    CONSTRAINT fk_exercicio_equipamento FOREIGN KEY (cd_equipamento) REFERENCES equipamento (cd_equipamento),
    CONSTRAINT ck_exercicio_grupo CHECK (ds_grupo_muscular IN ('Peito','Costas','Pernas','Ombros','Biceps','Triceps','Abdomen','Gluteos','Cardio'))
);
GO

/*==============================================================*/
/* Table: ficha_exercicio  (tabela associativa N x N)           */
/*==============================================================*/
CREATE TABLE ficha_exercicio (
    cd_ficha         INT            NOT NULL,
    cd_exercicio     SMALLINT       NOT NULL,
    nr_ordem         TINYINT        NOT NULL,
    qt_series        TINYINT        NOT NULL CONSTRAINT df_ficha_exercicio_series DEFAULT (3),
    qt_repeticoes    TINYINT        NOT NULL CONSTRAINT df_ficha_exercicio_reps DEFAULT (12),
    vl_carga_kg      DECIMAL(5,1)   NULL,
    qt_descanso_seg  SMALLINT       NOT NULL CONSTRAINT df_ficha_exercicio_descanso DEFAULT (60),
    CONSTRAINT pk_ficha_exercicio PRIMARY KEY CLUSTERED (cd_ficha, cd_exercicio),
    CONSTRAINT fk_ficha_exercicio_ficha FOREIGN KEY (cd_ficha) REFERENCES ficha_treino (cd_ficha),
    CONSTRAINT fk_ficha_exercicio_exercicio FOREIGN KEY (cd_exercicio) REFERENCES exercicio (cd_exercicio),
    CONSTRAINT ck_ficha_exercicio_series CHECK (qt_series BETWEEN 1 AND 10),
    CONSTRAINT ck_ficha_exercicio_reps CHECK (qt_repeticoes BETWEEN 1 AND 100),
    CONSTRAINT ck_ficha_exercicio_carga CHECK (vl_carga_kg IS NULL OR vl_carga_kg BETWEEN 0 AND 500),
    CONSTRAINT ck_ficha_exercicio_descanso CHECK (qt_descanso_seg BETWEEN 0 AND 600)
);
GO

/*==============================================================*/
/* Table: manutencao_equipamento                                */
/*==============================================================*/
CREATE TABLE manutencao_equipamento (
    cd_manutencao    INT IDENTITY(1,1)  NOT NULL,
    cd_equipamento   SMALLINT           NOT NULL,
    cd_funcionario   INT                NOT NULL,
    -- P = preventiva | C = corretiva
    tp_manutencao    CHAR(1)            NOT NULL CONSTRAINT df_manutencao_tp DEFAULT ('P'),
    dt_manutencao    DATE               NOT NULL CONSTRAINT df_manutencao_dt DEFAULT (CAST(GETDATE() AS DATE)),
    vl_custo         DECIMAL(8,2)       NOT NULL CONSTRAINT df_manutencao_custo DEFAULT (0),
    ds_servico       VARCHAR(500)       NOT NULL,
    -- A = em andamento | C = concluida
    st_manutencao    CHAR(1)            NOT NULL CONSTRAINT df_manutencao_st DEFAULT ('A'),
    CONSTRAINT pk_manutencao_equipamento PRIMARY KEY CLUSTERED (cd_manutencao),
    CONSTRAINT fk_manutencao_equipamento FOREIGN KEY (cd_equipamento) REFERENCES equipamento (cd_equipamento),
    CONSTRAINT fk_manutencao_funcionario FOREIGN KEY (cd_funcionario) REFERENCES funcionario (cd_funcionario),
    CONSTRAINT ck_manutencao_tp CHECK (tp_manutencao IN ('P','C')),
    CONSTRAINT ck_manutencao_custo CHECK (vl_custo >= 0),
    CONSTRAINT ck_manutencao_st CHECK (st_manutencao IN ('A','C'))
);
GO
