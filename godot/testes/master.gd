extends SceneTree
# Confere a janela A (JanelaMaster) sem servidor: regras do original, dica e o printf dos textos do cliente.
# Uso: $G --headless --path . --script res://testes/master.gd   (termina com "falhas: 0")

var falhas := 0


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _initialize() -> void:
	confere("printf com argumento a mais", JanelaMaster.fmt("Rank %d, Skill Level: %d/20", [1, 0, 20]) == "Rank 1, Skill Level: 0/20")
	confere("printf %0.2f%%", JanelaMaster.fmt("decreases by %0.2f%%.", [12.04]) == "decreases by 12.04%.")
	confere("printf sem argumento", JanelaMaster.fmt("Requires 'Cyclone' skill.", [3]) == "Requires 'Cyclone' skill.")

	var j := JanelaMaster.new()
	root.add_child(j)
	j.master = {"nivel": 2, "exp": 0, "exp_prox": 0, "pontos": 0}
	for c in JanelaMaster.CLASSES:
		j.definir_classe(c)
		var vistos := {}
		var sobrepostos := 0
		for e in j.entradas:
			var k := str(j._rect(e).position)
			sobrepostos += 1 if vistos.has(k) else 0
			vistos[k] = true
		confere("classe %d: %d skills, nenhuma no mesmo lugar" % [c, j.entradas.size()], j.entradas.size() >= 36 and sobrepostos == 0)

	j.definir_classe(7)   # Blade Master
	var e := func(s: int) -> Array:
		for x in j.entradas:
			if x[7] == s:
				return x
		return []
	confere("300 (rank 1) disponivel", j.disponivel(e.call(300)))
	confere("302 (rank 2) bloqueada sem rank 1 no 10", not j.disponivel(e.call(302)))
	j.niveis[300] = [10, 0.0, 0.0]
	confere("302 liberada com a 300 no 10", j.disponivel(e.call(302)))
	confere("305 (pede a 300, rank 3) bloqueada sem rank 2 no 10", not j.disponivel(e.call(305)))
	j.niveis[302] = [10, 0.0, 0.0]
	confere("305 liberada com a 302 no 10", j.disponivel(e.call(305)))
	j.niveis[300] = [9, 0.0, 0.0]
	confere("305 bloqueada com a 300 no 9 (skill pedida)", not j.pai_ok(e.call(305)))
	confere("326 Cyclone Strengthener pede o Cyclone", not j.antes_ok(326))
	j.minhas_skills[0] = 22
	confere("326 liberada com o Cyclone na lista", j.antes_ok(326))
	confere("sem pontos: o aviso do cliente", j.motivo(e.call(301)) == DicaItem.t(3326))
	j.master.pontos = 5
	confere("com pontos: pode mandar", j.motivo(e.call(301)) == "")
	j.niveis[301] = [20, 0.0, 0.0]
	confere("no maximo (20): nao sobe", j.motivo(e.call(301)) == DicaItem.t(3326))
	var dica: Array = j.linhas_dica(e.call(300)).map(func(x): return x.t)
	print("  dica 300: %s" % [dica])
	confere("dica: rank e nivel", "Rank 1, Skill Level: 9/20" in dica)
	confere("dica: proximo nivel", "Next Level:" in dica)
	confere("dica: pontos", "Required Point: 1 point" in dica)
	j.escolher(e.call(300))
	confere("clique: confirmacao do cliente", j._caixa.linhas == [DicaItem.t(1771), DicaItem.t(1772, [1])])
	var mandou := []
	j.aprender.connect(func(s): mandou.append(s))
	j.confirmar(true)
	confere("OK manda a skill", mandou == [300])
	j.lista([{"indice": 1, "nivel": 3, "valor": 1.0, "prox": 2.0}, {"indice": 37, "nivel": 10, "valor": 1.0, "prox": 2.0}])
	confere("F3 53: indice 1 = 300 e 37 = 325", j.nivel(300) == 3 and j.nivel(325) == 10)
	confere("pontos por grupo", j.pontos_do_grupo(0) == 3 and j.pontos_do_grupo(1) == 10)
	j.subiu(1, 4, 1.0, 2.0)
	confere("F3 52 sobe a 300", j.nivel(300) == 4)
	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
