extends SceneTree
# Confere a rodada 11 sem servidor: os pacotes dos pets do Dark Lord que chegam (C1 A7 ordem aceita, A8 ataque do
# corvo, A9 ficha) e os que saem (A7 ordem, A9 pedido da ficha), as contas do CalcPetInfo, a caixa do item do corvo
# e do cavalo, as ordens na barra de skills (120 a 123), a janela do pet e o corvo voando em volta do dono.
# Uso: $G --headless --path . --script res://testes/rodada11.gd   (termina com "falhas: 0")

var falhas := 0
var ultimo := {}


class ConFalsa extends Conexao:
	var enviados: Array = []

	func enviar(pacote: PackedByteArray) -> void:
		Cripto.gravar_tamanho(pacote)
		enviados.append(pacote)


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func guarda(sinal: String) -> Callable:
	return func(...a): ultimo[sinal] = a


func _initialize() -> void:
	var cli := ClienteMU.new()
	for s in ["pet_modo", "pet_ataque", "pet_info"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 7, 0xA7, 0, 3, 0x12, 0x34]))
	confere("C1 A7: corvo, ordem 3, alvo 0x1234", ultimo.get("pet_modo", []) == [0, 3, 0x1234])
	cli._tratar(PackedByteArray([0xC1, 9, 0xA8, 0, 1, 0x80, 0x05, 0x23, 0x45]))
	confere("C1 A8: em area, dono 5 (sem o bit 0x8000), alvo 0x2345", ultimo.get("pet_ataque", []) == [0, 1, 5, 0x2345])
	cli._tratar(PackedByteArray([0xC1, 13, 0xA9, 1, 254, 8, 3, 0, 0x10, 0x27, 0, 0, 200]))
	confere("C1 A9: cavalo subiu pro 3 no slot 8, exp 10000, vida 200", ultimo.get("pet_info", [{}])[0] == {"tipo": 1,
		"armazem": 254, "slot": 8, "nivel": 3, "exp": 10000, "vida": 200})
	cli._tratar(PackedByteArray([0xC1, 6, 0xA7, 0, 3, 0]))
	confere("C1 A7 curto e ignorado", ultimo.get("pet_modo", []) == [0, 3, 0x1234])

	var con := ConFalsa.new()
	cli.con = con
	cli.comando_pet(0, 1)
	cli.comando_pet(0, 3, 0x0102)
	cli.pedir_info_pet(1, 254, 8)
	var e: Array = con.enviados
	confere("sai C1 A7 aleatorio sem alvo (FFFF)", e[0] == PackedByteArray([0xC1, 7, 0xA7, 0, 1, 0xFF, 0xFF]))
	confere("sai C1 A7 alvo big endian", e[1] == PackedByteArray([0xC1, 7, 0xA7, 0, 3, 1, 2]))
	confere("sai C1 A9 cavalo, armazem, slot", e[2] == PackedByteArray([0xC1, 6, 0xA9, 1, 254, 8]))

	# CalcPetInfo
	DicaItem.eu = {"nivel": 250, "forca": 500, "agilidade": 300, "comando": 400, "classe": 16}
	var c := Pets.calcular({"tipo": 0, "nivel": 2, "exp": 0, "vida": 255})
	confere("corvo nv 2: exp prox (10+3)*27*100 = 35100", c.exp_prox == 35100)
	confere("corvo nv 2: dano 180+30+50 a 200+30+100", c.dano_min == 260 and c.dano_max == 330)
	confere("corvo nv 2: velocidade 20+1+8, sucesso 1032", c.vel == 29 and c.sucesso == 1032)
	var h := Pets.calcular({"tipo": 1, "nivel": 2, "exp": 0, "vida": 255})
	confere("cavalo nv 2: dano 50+40+10 = 100 a 150", h.dano_min == 100 and h.dano_max == 150)
	confere("Dark Lord pela classe 16", Pets.sou_dl())

	# a caixa do item: a ficha do vestido no slot 1 da mochila; sem ficha pede uma vez e cai na caixa normal
	var corvo := {"grupo": 13, "numero": 5, "nivel": 0, "durabilidade": 255}
	Pets.vestidos = {"13,5": {"tipo": 0, "armazem": 0, "slot": 1, "nivel": 2, "exp": 100, "vida": 255}}
	Pets.onde = [0, 1]
	var l := DicaItem.linhas(corvo)
	var textos := l.map(func(x): return x.get("t", ""))
	confere("caixa do corvo vestido: nome, nivel e carisma 215", DicaItem.t(1214) in textos
		and "%s : 2" % DicaItem.t(368) in textos and DicaItem.t(698, [215]) in textos)
	var pedidos := []
	Pets.pedir = func(t, a, s): pedidos.append([t, a, s])
	Pets.onde = [1, 30]
	var l2 := DicaItem.linhas(corvo)
	Pets.onde = [1, 30]
	DicaItem.linhas(corvo)
	confere("corvo no bau sem ficha: pede A9 uma vez e mostra a caixa normal", pedidos == [[0, 1, 30]] and l2.size() > 1)
	Pets.ficha = Pets.calcular({"tipo": 0, "armazem": 1, "slot": 30, "nivel": 5, "exp": 9, "vida": 100})
	Pets.onde = [1, 30]
	var l3 := DicaItem.linhas(corvo).map(func(x): return x.get("t", ""))
	confere("ficha chegou: caixa do nivel 5", "%s : 5" % DicaItem.t(368) in l3)
	var cav := {"grupo": 13, "numero": 4, "nivel": 0}
	Pets.ficha = {"tipo": 1, "armazem": 0, "slot": 40, "nivel": 1, "exp": 0, "vida": 255}
	Pets._pedido = "0:40:13,4:0"
	Pets.onde = [0, 40]
	var l4 := DicaItem.linhas(cav).map(func(x): return x.get("t", ""))
	confere("cavalo: nivel 220 pedido, defesa, absorve e alcance", DicaItem.t(76, [220]) in l4
		and DicaItem.t(1188, [2]) in l4 and DicaItem.t(744, [15]) in l4)

	# barra de skills: as ordens so com o corvo
	var hud := HudMu.new()
	root.add_child(hud)
	await process_frame
	hud.skills = [60, 61]
	confere("sem corvo: 120 nao e usavel", not hud.usavel(120) and hud.usavel(60))
	hud.comandos_pet = true
	hud.lista_aberta = true
	hud._ajustar()
	confere("com corvo: 120 a 123 usaveis, 124 nao", hud.usavel(120) and hud.usavel(123) and not hud.usavel(124))
	confere("lista aberta sobe 77 pra fileira das ordens", hud._extra == 77.0)
	confere("fileira em 353,352: a 3a caixa e a ordem 122", hud._skill_em(Vector2(353 + 64 + 10, 352 - HudMu.TOPO + 10)) == 122)
	confere("nome da ordem 120 = Basic action", hud.nome_skill(120).begins_with(DicaItem.t(1219)))

	# janela do pet
	var jp := JanelaPet.new()
	root.add_child(jp)
	await process_frame
	jp.alternar()
	confere("janela do pet abre 190x429", jp.visible and jp.size == Vector2(190, 429))
	jp.aba = JanelaPet.CORVO
	confere("dano do corvo sem cetro = ficha", jp.dano(c) == Vector2i(260, 330))
	confere("dano do cavalo soma o Earthshake", jp.dano(h) == Vector2i(250, 375))
	confere("% do cetro (2,10) +0 = 35 / 2 = 17", DicaItem.magia({"grupo": 2, "numero": 10, "nivel": 0}) == 17)
	jp.queue_redraw()
	await process_frame

	# o corvo voando em volta de um dono parado
	var mundo := Node3D.new()
	root.add_child(mundo)
	var dono := Entidade.new()
	mundo.add_child(dono)
	var corvo3d := Corvo.novo(dono, mundo, func(_n): pass)
	confere("o corvo nasce (modelo corvo.glb)", corvo3d != null)
	if corvo3d:
		for i in 120:
			corvo3d._process(1.0 / 30.0)
		var d := corvo3d.global_position.distance_to(dono.global_position)
		confere("4 s depois segue perto do dono (%.1f m)" % d, d < 6.0)
		var alvo := Entidade.new()
		mundo.add_child(alvo)
		alvo.position = Vector3(3, 0, -3)
		corvo3d.atacar(alvo, 0)
		confere("ataque de um alvo: estado ATAQUE", corvo3d.estado == Corvo.ATAQUE)
		for i in 60:
			corvo3d._process(1.0 / 30.0)
		corvo3d.atacar(alvo, 1)
		confere("ataque em area: estado MAGIA", corvo3d.estado == Corvo.MAGIA)
		for i in 60:
			corvo3d._process(1.0 / 30.0)

	# as cenas que usam tudo isso carregam
	for s in ["res://scripts/jogo.gd", "res://scripts/pets.gd", "res://scripts/janela_pet.gd", "res://scripts/corvo.gd",
			"res://scripts/janela_personagem.gd", "res://scripts/boneco.gd"]:
		confere("carrega " + s.get_file(), load(s) != null)
	Pets.pedir = Callable()   # o lambda deste roteiro numa variavel estatica derruba o Godot na saida
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
