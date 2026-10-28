extends SceneTree
# Confere a rodada 25 sem servidor: os 14 pacotes que faltavam (F3 30, F5 01, F3 15, F3 22, 0B, 69, 94, BA, BF 0A,
# F6 03, B9 01, B9 02, B9 03, B9 05), o que o cliente manda de volta (F5 00, F3 30, F3 15, B9 02/05, B2 1F, B2 09 tipo 3,
# 95, 97), a linha do comando de chat (BuildCommandLine), a marca do castelo (CreateCastleMark), o Gatekeeper, o
# Golden Archer, as animacoes de skill de monstro (MonsterSkill.bmd) e a Chain Lightning.
# Uso: $G --headless --path . --script res://testes/rodada25.gd   (termina com "falhas: 0")

var falhas := 0


class ConFalsa extends Conexao:
	var enviados: Array = []

	func enviar(pacote: PackedByteArray) -> void:
		Cripto.gravar_tamanho(pacote)
		enviados.append(pacote)


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _initialize() -> void:
	var cli := ClienteMU.new()
	var visto := {}
	cli.teclas.connect(func(c): visto.teclas = c)
	cli.comando_chat.connect(func(i, t, c): visto.cmd = [i, t, c])
	cli.personagem_foco.connect(func(n): visto.foco = n)
	cli.futebol_tempo.connect(func(s): visto.futebol = s)
	cli.evento_mapa.connect(func(l, e): visto.evento = [l, e])
	cli.skill_monstro.connect(func(s, i, a, ok): visto.skill = [s, i, a, ok])
	cli.fichas.connect(func(r, reg, m): visto.fichas = [r, reg, m])
	cli.estagio_skill.connect(func(i, s, e): visto.nova = [i, s, e])
	cli.corrente.connect(func(s, i, l): visto.corrente = [s, i, l])
	cli.quests_evento.connect(func(l): visto.quests = l)
	cli.pedra_vida.connect(func(n, e): visto.pedra = [n, e])
	cli.marca_castelo.connect(func(m): visto.marca = m)
	cli.cacada_info.connect(func(r, p, preco, mx, passo): visto.cacada = [r, p, preco, mx, passo])
	cli.cacada_entrar.connect(func(r): visto.entrar = r)

	# F3 30: 30 bytes do ReceiveOption
	var cfg := PackedByteArray()
	cfg.resize(30)
	cfg.fill(0xFF)
	cfg[0] = 0
	cfg[1] = 9
	cfg[21] = 3
	var p := PackedByteArray([0xC1, 34, 0xF3, 0x30])
	p.append_array(cfg)
	cli._tratar(p)
	confere("F3 30 entrega os 30 bytes das teclas", visto.has("teclas") and visto.teclas == cfg)

	# C2 F5 01: um comando com um parametro de nome curto e valores com |
	var c := PackedByteArray()
	c.resize(345 + 102)
	c[0] = 0xC2
	c[1] = c.size() >> 8
	c[2] = c.size() & 0xFF
	c[3] = 0xF5
	c[4] = 0x01
	c[5] = 2
	c[6] = 5
	c[7] = 0
	c[8] = 1
	_por(c, 9, "/pkclear")
	_por(c, 41, "PK Clear")
	_por(c, 89, "Clears the player killer state of a character.")
	c[345] = 1
	c[346] = 0
	_por(c, 347, "character")
	_por(c, 379, "c")
	_por(c, 399, "sim|nao")
	cli._tratar(c)
	var cmd: Dictionary = visto.get("cmd", [0, 0, {}])[2]
	confere("F5 01 indice 2 de 5", visto.has("cmd") and visto.cmd[0] == 2 and visto.cmd[1] == 5)
	confere("F5 01 comando, nome e descricao", cmd.get("comando") == "/pkclear" and cmd.get("nome") == "PK Clear" and str(cmd.get("descricao")).begins_with("Clears"))
	confere("F5 01 parametro obrigatorio com nome curto e 2 valores", cmd.get("parametros", []).size() == 1 and cmd.parametros[0].obrigatorio and cmd.parametros[0].curto == "c" and cmd.parametros[0].valores == PackedStringArray(["sim", "nao"]))
	confere("linha com nome curto: /pkclear c=Fulano", JanelaChatComandos.linha_comando(cmd, ["Fulano"]) == "/pkclear c=Fulano")
	confere("linha sem valor deixa o parametro de fora", JanelaChatComandos.linha_comando(cmd, [""]) == "/pkclear")
	var sem_curto := {"comando": "/move", "parametros": [{"curto": "", "obrigatorio": true}, {"curto": "", "obrigatorio": false}]}
	confere("linha sem nome curto: /move lorencia 130", JanelaChatComandos.linha_comando(sem_curto, ["lorencia", "130"]) == "/move lorencia 130")

	cli._tratar(_c1sub(0xF3, 0x15, "Fulano".to_utf8_buffer() + PackedByteArray([0, 0, 0, 0])))
	confere("F3 15 devolve o nome focado", visto.get("foco") == "Fulano")
	cli._tratar(PackedByteArray([0xC1, 6, 0xF3, 0x22, 0x58, 0x02]))
	confere("F3 22 segundos em LE (600)", visto.get("futebol") == 600)
	cli._tratar(PackedByteArray([0xC1, 5, 0x0B, 1, 3]))
	confere("0B liga a invasao do dragao dourado", visto.get("evento") == [true, 3])
	cli._tratar(PackedByteArray([0xC1, 10, 0x69, 0, 37, 0, 0x34, 0x12, 0x10, 0x80]))
	confere("69 skill 37, monstro 0x1234, alvo 0x10, acertou", visto.get("skill") == [37, 0x1234, 0x10, true])
	cli._tratar(PackedByteArray([0xC1, 14, 0x94, 0, 7, 0, 0, 0, 2, 0, 0xFF, 0xFF, 0xFF, 0xFF]))
	confere("94 resultado 0, 7 registradas, 2 na mochila", visto.get("fichas") == [0, 7, 2])
	cli._tratar(PackedByteArray([0xC1, 7, 0xBA, 0x22, 0x00, 40, 5]))
	confere("BA Nova de 0x22 no estagio 5", visto.get("nova") == [0x22, 40, 5])
	cli._tratar(PackedByteArray([0xC1, 16, 0xBF, 0x0A, 0, 215, 0x05, 0, 3, 0, 0x10, 0, 0x11, 0, 0x12, 0x80]))
	confere("BF 0A Chain Lightning 215 de 5 em 3 alvos (bit de cima fora)", visto.get("corrente") == [215, 5, [0x10, 0x11, 0x12]])
	cli._tratar(PackedByteArray([0xC1, 12, 0xF6, 0x03, 5, 0, 1, 0, 0, 0, 0, 0]))
	confere("F6 03 uma quest de evento (grupo 5, numero 1)", visto.get("quests") == [[5, 1]])
	cli._tratar(PackedByteArray([0xC1, 7, 0xB9, 0x01, 0x00, 0x42, 3]))
	confere("B9 01 Life Stone 0x42 no estagio 3", visto.get("pedra") == [0x42, 3])
	var logo := PackedByteArray()
	for i in 32:
		logo.append(((i % 16) << 4) | 4)
	cli._tratar(_c1sub(0xB9, 0x02, logo))
	confere("B9 02 entrega os 32 bytes da marca", visto.get("marca") == logo)
	var info := PackedByteArray([3, 1])
	info.append_array(ClienteMU._le4(30000))
	info.append_array(ClienteMU._le4(300000))
	info.append_array(ClienteMU._le4(10000))
	cli._tratar(_c1sub(0xB9, 0x03, info))
	confere("B9 03 mestre, aberto, 30000, maximo 300000, passo 10000", visto.get("cacada") == [3, true, 30000, 300000, 10000])
	cli._tratar(PackedByteArray([0xC1, 5, 0xB9, 0x05, 1]))
	confere("B9 05 resultado 1", visto.get("entrar") == 1)

	# o que o cliente manda
	var con := ConFalsa.new()
	cli.con = con
	cli.pedir_comandos_chat()
	cli.guardar_teclas(cfg)
	cli.foco_personagem("Fulano")
	cli.pedir_marca_castelo()
	cli.cacada_publico(true)
	cli.cacada_entrar_pedir(30000)
	cli.cacada_preco(20000)
	cli.registrar_ficha(0, 14)
	cli.fechar_fichas()
	var e: Array = con.enviados
	confere("C1 F5 00 de 4 bytes", e[0] == PackedByteArray([0xC1, 4, 0xF5, 0x00]))
	confere("C1 F3 30 de 34 bytes com a configuracao", e[1].size() == 34 and e[1].slice(4) == cfg)
	confere("C1 F3 15 de 14 bytes com o nome", e[2].size() == 14 and ClienteMU._ler_texto(e[2], 4, 10) == "Fulano")
	confere("C1 B9 02 de 4 bytes", e[3] == PackedByteArray([0xC1, 4, 0xB9, 0x02]))
	confere("C1 B2 1F abre (1)", e[4] == PackedByteArray([0xC1, 5, 0xB2, 0x1F, 1]))
	confere("C1 B9 05 com 30000 em LE32", e[5] == PackedByteArray([0xC1, 8, 0xB9, 0x05, 0x30, 0x75, 0, 0]))
	confere("C1 B2 09 tipo 3 com 20000 em BE32", e[6] == PackedByteArray([0xC1, 9, 0xB2, 0x09, 3, 0, 0, 0x4E, 0x20]))
	confere("C1 95 tipo 0 casa 14", e[7] == PackedByteArray([0xC1, 5, 0x95, 0, 14]))
	confere("C1 97 fecha o Golden Archer", e[8] == PackedByteArray([0xC1, 3, 0x97]))
	cli.free()

	# CreateCastleMark: 64x64, marca 32x32 no meio (cada cor 4x4), borda azul degrade, resto cinza pela linha
	var nibbles := PackedByteArray()
	for i in 64:
		nibbles.append((logo[i / 2] >> 4) & 15 if i % 2 == 0 else logo[i / 2] & 15)
	var img: Image = ScriptMundo().imagem_marca_castelo(nibbles)
	confere("bandeira 64x64", img.get_width() == 64 and img.get_height() == 64)
	confere("marca: cor 0 transparente no canto da marca", img.get_pixel(16, 16).a == 0.0)
	confere("marca: cor 4 vermelha na casa 1", img.get_pixel(20, 16).is_equal_approx(Color8(255, 0, 0)))
	confere("borda de cima azul degrade (linha 0: 50, 50, 0 em BGR)", img.get_pixel(30, 0).is_equal_approx(Color8(50, 50, 0)))
	confere("meio cinza da linha (linha 12)", img.get_pixel(5, 12).is_equal_approx(Color8(12, 12, 12)))

	# Gatekeeper: mestre sobe e desce o preco no passo, Enter manda o escolhido; visitante sem zen pede a caixa
	var g := JanelaGatekeeper.new()
	get_root().add_child(g)
	await process_frame
	var gv := {}
	g.entrar.connect(func(v): gv.entrar = v)
	g.mudar_preco.connect(func(v): gv.preco = v)
	g.publico.connect(func(v): gv.publico = v)
	g.sem_zen.connect(func(): gv.sem_zen = true)
	g.abrir(3, false, 30000, 50000, 10000)
	g.queue_redraw()
	await process_frame
	g._clique(Vector2(120, 185))
	g._clique(Vector2(120, 185))
	g._clique(Vector2(120, 185))
	confere("mestre: a seta para no maximo (50000)", g.visto == 50000)
	g._clique(Vector2(120, 200))
	g._clique(Vector2(95, 230))
	confere("mestre: Confirm manda 40000", gv.get("preco") == 40000)
	g._clique(Vector2(60, 115))
	confere("mestre: a caixa abre pra quem nao e da guilda", gv.get("publico") == true)
	g.abrir(1, true, 30000, 0, 0)
	g.meu_zen = 100
	g.queue_redraw()
	await process_frame
	g._clique(Vector2(95, 110))
	confere("visitante sem zen: caixa 1628 e nao entra", gv.get("sem_zen") == true and not gv.has("entrar"))
	g.meu_zen = 50000
	g._clique(Vector2(95, 110))
	confere("visitante com zen entra pagando 30000", gv.get("entrar") == 30000 and not g.visible)
	g.free()

	# Golden Archer: conta as Renas da mochila e registra a primeira
	var a := JanelaArqueiro.new()
	get_root().add_child(a)
	await process_frame
	a.itens = {0: {"grupo": 0, "numero": 1}, 30: {"grupo": 14, "numero": 21}, 20: {"grupo": 14, "numero": 21}, 40: {"grupo": 14, "numero": 13}}
	var av := {}
	a.registrar.connect(func(cs): av.casa = cs)
	a.abrir(7)
	a.queue_redraw()
	await process_frame
	confere("arqueiro: 2 Renas na mochila", a.quantas() == 2)
	a._clique(Vector2(90, 295))
	confere("arqueiro: registra a Rena da casa 20", av.get("casa") == 20)
	a.free()
	confere("textos 243, 245 e 700 a 704", DicaItem.t(243) == "Registering Rena" and DicaItem.t(704) == "The event.")

	# janela J: lista com favorito em cima, comando sem parametro executa na hora
	var j := JanelaChatComandos.new()
	get_root().add_child(j)
	await process_frame
	j.favoritos = ["/online"]
	j.receber(0, 2, {"comando": "/pkclear", "parametros": [{"obrigatorio": true, "curto": "c", "nome": "character", "valores": PackedStringArray()}]})
	j.receber(1, 2, {"comando": "/online", "parametros": []})
	confere("favorito vai pro topo", j._cmd(0).comando == "/online")
	var jv := {}
	j.executar.connect(func(l): jv.linha = l)
	j.abrir()
	j._escolher(0)
	confere("sem parametro: manda /online e fecha", jv.get("linha") == "/online" and not j.visible)
	j.abrir()
	j._escolher(1)
	confere("com parametro: vai pra pagina de parametros", j.pagina == 1)
	j._executar()
	confere("obrigatorio vazio nao manda", jv.get("linha") == "/online")
	j.valores[0] = "Fulano"
	j._executar()
	confere("preenchido manda /pkclear c=Fulano", jv.get("linha") == "/pkclear c=Fulano")
	j.favoritos = []
	j.free()

	# skills de monstro: a posicao na lista do MonsterSkill.bmd escolhe o ataque
	var ms: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/monstro_skills.json"))
	confere("Selupan (459) com 9 skills, a 37 primeiro", ms.get("459", [])[0] == 37 and ms["459"].count(-1.0) == 1)
	var anim := {}
	var sel: Node = load("res://dados/personagens/monster151.glb").instantiate()
	for ap: AnimationPlayer in sel.find_children("*", "AnimationPlayer", true, false):
		for n in ap.get_animation_list():
			anim[n] = true
	sel.free()
	confere("Selupan convertido com ataque3 e ataque4 (o BMD nao tem o ATTACK5)", anim.has("ataque3") and anim.has("ataque4"))
	confere("som da Chain Lightning e do meteoro", ResourceLoader.exists("res://dados/sons/chain_lightning.wav") and ResourceLoader.exists("res://dados/sons/meteoro.wav"))

	# Chain Lightning roda com alvos que nao sao Entidade (so posicao) sem quebrar
	var raiz := Node3D.new()
	get_root().add_child(raiz)
	var q := Node3D.new()
	var alvos: Array = []
	raiz.add_child(q)
	for i in 3:
		var n := Node3D.new()
		raiz.add_child(n)
		n.position = Vector3(i + 1, 0, 0)
		alvos.append(n)
	EfeitoSkill.corrente(raiz, q, alvos)
	for k in 30:
		await process_frame
	confere("Chain Lightning criou o efeito", raiz.get_child_count() > 4)
	raiz.queue_free()
	print("falhas: %d" % falhas)
	quit()


func ScriptMundo() -> GDScript:
	return load("res://scripts/mundo.gd")


func _por(p: PackedByteArray, o: int, t: String) -> void:
	var b := t.to_utf8_buffer()
	for i in b.size():
		p[o + i] = b[i]


func _c1sub(cod: int, sub: int, dados: PackedByteArray) -> PackedByteArray:
	var p := PackedByteArray([0xC1, 4 + dados.size(), cod, sub])
	p.append_array(dados)
	return p
