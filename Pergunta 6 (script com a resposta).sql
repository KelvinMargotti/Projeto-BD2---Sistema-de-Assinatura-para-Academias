use futurefit;
go

declare @hoje date = cast(getdate() as date),
		@dias int = 14;

select pe.nm_pessoa,
	   pe.nr_telefone,
	   pl.nm_plano,
	   u.dt_ultimo_treino,
	   datediff(day, u.dt_ultimo_treino, @hoje) as qt_dias_sem_treinar,
	   a.dt_fim as dt_fim_plano,
	   a.vl_mensal_contratado,
	   sum(a.vl_mensal_contratado) over () as vl_mensal_total_em_risco
 from dbo.assinatura a
inner join dbo.pessoa pe on pe.cd_pessoa = a.cd_aluno
inner join dbo.plano pl on pl.cd_plano = a.cd_plano
outer apply (
		select max (c.dt_entrada) as dt_ultimo_treino
			from dbo.checkin c
		 where c.cd_aluno = a.cd_aluno
			and c.st_acesso = 'L'
) u

where a.st_assinatura = 'A'
	and @hoje between a.dt_inicio and a.dt_fim
	and dbo.fn_status_acesso(a.cd_aluno, @hoje) = 'L'
	and (u.dt_ultimo_treino is null
		or u.dt_ultimo_treino < dateadd(day, -@dias, @hoje))
 order by u.dt_ultimo_treino;
go