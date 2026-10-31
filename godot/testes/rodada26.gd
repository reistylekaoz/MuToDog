extends SceneTree
# Confere a rodada 26 sem servidor: o resto do Castle Siege. A placa do lado em cima de cada um (buffs 14 a 17,
# B2 19 pro heroi, mestre com a coroa, so com a batalha rodando, some na invisibilidade e na morte), a moldura da
# skill da batalha (cargo -> skills, mortes do C1 B8 01, KillCount, setas que travam nas pontas), os efeitos e os
# sons das skills 67 a 71 e os arquivos da rodada.
# Uso: $G --headless --path . --script res://testes/rodada26.gd   (termina com "falhas: 0")

var falhas := 0
var mortes := -1


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _initialize() -> void:
	for f in ["mm_skill", "skill_cima", "skill_baixo", "marca_lado"]:
		confere("textura hud/castelo/%s" % f, ResourceLoader.exists("res://dados/hud/castelo/%s.png" % f))
	for f in ["cs_sDStun", "cs_sDSwellMana", "cs_sDTrans"]:
		confere("som %s" % f, ResourceLoader.exists("res://dados/sons/%s.wav" % f))

	# --- C1 B8 01: mortes da guilda ---
	var cli := ClienteMU.new()
	cli.cs_mortes.connect(func(n): mortes = n)
	cli._tratar(PackedByteArray([0xC1, 5, 0xB8, 0x01, 3]))
	confere("B8 01: 3 mortes", mortes == 3)
	cli._tratar(PackedByteArray([0xC1, 5, 0xB8, 0x01, 0]))
	confere("B8 01: zerou", mortes == 0)

	# --- placa do lado (quadro da FormationMark) ---
	var q := GuerraCastelo.quadro_placa
	confere("sem batalha: nada", q.call(false, false, {15: true}, 0, false) == -1)
	confere("ataque 1: espada (0)", q.call(true, false, {15: true}, 0, false) == 0)
	confere("ataque 2: arco (1)", q.call(true, false, {16: true}, 0, false) == 1)
	confere("ataque 3: cajado (2)", q.call(true, false, {17: true}, 0, false) == 2)
	confere("ataque 1 mestre: coroa (3)", q.call(true, false, {15: true}, 0, true) == 3)
	confere("ataque 3 mestre: coroa (5)", q.call(true, false, {17: true}, 0, true) == 5)
	confere("defesa: escudo (6)", q.call(true, false, {14: true}, 0, false) == 6)
	confere("defesa mestre: escudo com coroa (7)", q.call(true, false, {14: true}, 0, true) == 7)
	confere("invisivel: nada", q.call(true, false, {15: true, 18: true}, 0, false) == -1)
	confere("morto: nada", q.call(true, true, {15: true}, 0, false) == -1)
	confere("sem buff de lado: nada", q.call(true, false, {1: true}, 0, false) == -1)
	confere("heroi pelo B2 19 (2 = ataque 1)", q.call(true, false, {}, 2, false) == 0)
	confere("heroi pelo B2 19 (1 = defesa)", q.call(true, false, {}, 1, true) == 7)

	# --- moldura da skill da batalha ---
	var g := GuerraCastelo.new()
	g.lado = 2
	for caso in [[128, true, [70, 71, 72]], [128, false, [70, 71]], [64, false, [70, 71]], [32, false, [67, 68, 69]],
			[0, false, []], [255, false, []]]:
		g.cargo = caso[0]
		g.iniciar_skills(caso[1])
		confere("cargo %d%s: %s" % [caso[0], " (DL)" if caso[1] else "", caso[2]], g.skills == caso[2])
	g.lado = 0
	g.cargo = 32
	g.iniciar_skills(false)
	confere("sem lado: sem moldura", g.skills.is_empty())
	g.lado = 1
	g.iniciar_skills(false)
	confere("battle master comeca no Stun", g.skill_guilda() == 67)
	g.mortes = 3
	confere("Stun pede 4: 3 nao basta", not g.skill_pronta())
	g.mortes = 4
	confere("Stun com 4: pronta", g.skill_pronta())
	g.trocar_skill(-1)
	confere("seta de cima no comeco trava", g.skill_guilda() == 67)
	g.trocar_skill(1)
	confere("Cancel Stun (pede 2)", g.skill_guilda() == 68 and g.skill_pronta())
	g.trocar_skill(1)
	g.trocar_skill(1)
	confere("seta de baixo no fim trava no Swell Mana", g.skill_guilda() == 69)
	g.cargo = 128
	g.iniciar_skills(true)
	g.mortes = 7
	g.trocar_skill(2)
	confere("Abolish Magic pede 8: 7 nao basta", g.skill_guilda() == 72 and not g.skill_pronta())
	g.free()

	# --- placa na entidade e efeitos das skills (precisa da arvore) ---
	var raiz := Node3D.new()
	root.add_child(raiz)
	var e := Entidade.new()
	raiz.add_child(e)
	e.por_placa(4)
	confere("placa 4 guardada na entidade (TextosMU desenha)", e.placa == 4)
	e.por_placa(-1)
	confere("placa -1 some", e.placa == -1)
	confere("TextosMU tem a textura da placa", TextosMU.PLACA != null and TextosMU.PLACA.get_width() == 256)

	# ordem dos interruptores: o 2 fora da vista (o B2 20 dele chega sem entidade) e o oposto do 1 que esta a vista
	var j: Node = load("res://scripts/jogo.gd").new()
	var sw := Entidade.new()
	sw.id = 515
	sw.numero = 217
	sw.tipo = "npc"
	j.entidades = {515: sw}
	confere("interruptor a vista (217): o 1", j._primeiro_interruptor(515))
	confere("interruptor fora da vista com o 1 a vista: o 2", not j._primeiro_interruptor(516))
	j.entidades = {}
	confere("o 1 saiu da vista: segue o 1, e o outro o 2", j._primeiro_interruptor(515) and not j._primeiro_interruptor(516))
	sw.free()
	j.free()

	var a := Node3D.new()
	var b := Node3D.new()
	raiz.add_child(a)
	raiz.add_child(b)
	b.position = Vector3(3, 0, 0)
	for n in [67, 68, 69, 70, 71]:
		var antes := raiz.get_child_count()
		EfeitoSkill.criar(raiz, n, a, b)
		confere("efeito da skill %d nasce" % n, raiz.get_child_count() > antes)
	for i in 30:
		await process_frame
	print("falhas: %d" % falhas)
	quit()
