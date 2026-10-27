extends SceneTree
# Confere a rodada 20 sem servidor: Raklion (estados do D1 10 a 12, som, musica do ninho, gelo caindo),
# Balgass (mapas 42 e 43 em pacote a parte, objetos escondidos, caixas do Werewolf e do Gatekeeper com o OK
# travado) e o evento de Crywolf: os C1 BD que chegam (00, 02, 03, 04, 05, 07, 08, 09, 0C) e os que saem
# (BD 00, BD 03 com a chave do altar, D0 07 e D0 08), o painel por estado, o relogio de 60/40/20 s, o Balgass,
# os cliques no altar, a faixa do fim e a caixa dos herois, a luz e a grade trocando pela ocupacao, a musica.
# Uso: $G --headless --path . --script res://testes/rodada20.gd   (termina com "falhas: 0")

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
	# mapas e arquivos
	for m in [42, 43, 59]:
		confere("mundo%d em pacote a parte" % m, m in PacoteMapa.FORA)
	for f in ["mundo42/objetos.json", "mundo42/musica.mp3", "mundo43/musica.mp3", "mundo59/objetos.json",
			"mundo59/musica_chefe.mp3", "mundo59/sons/selupan_rage.wav", "mundo59/sons/selupan_word1.wav",
			"mundo58/sons/vento.wav", "mundo58/efeitos/ice_stone00.glb", "mundo35/musica_antes.ogg",
			"mundo35/musica_pronto.ogg", "mundo35/musica_luta.ogg", "mundo35/sons/venceu.wav", "mundo35/sons/perdeu.wav",
			"mundo35/luz1.png", "mundo35/luz2.png", "mundo35/atributos_1.png", "mundo35/atributos_2.png",
			"hud/crywolf/in_main.png", "hud/crywolf/sucesso.png", "hud/crywolf/falha.png", "hud/crywolf/rank_tabela.png"]:
		confere("arquivo " + f, FileAccess.file_exists("res://dados/" + f))
	confere("Balgass esconde a lista do CGM3rdChangeUp", Ambiente.ESCONDER.get(42) == [2, 3, 5, 6, 58, 59, 60, 85, 86, 87, 88, 89, 90, 91, 92, 93]
		and Ambiente.ESCONDER.get(43) == Ambiente.ESCONDER.get(42) and 3 in Ambiente.FOGO_TIPO[42])
	var mm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/monstros_mapa.json"))
	confere("monstros do quartel e do ninho nos pacotes", "monster94" in mm["42"] and "monster127" in mm["43"] and "monster151" in mm["59"])

	# pacotes que chegam
	var cli := ClienteMU.new()
	for s in ["raklion_estado", "crywolf_info", "crywolf_altares", "crywolf_contrato", "crywolf_tempo", "crywolf_chefe",
			"crywolf_rank", "crywolf_heroi", "crywolf_caos", "crywolf_balista"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 0x06, 0xD1, 0x12, 4, 0]))
	confere("D1 12: Raklion pronto", ultimo.get("raklion_estado", []) == [4, 0])
	cli._tratar(PackedByteArray([0xC1, 0x06, 0xBD, 0x00, 2, 3]))
	confere("BD 00: guerra, pronto", ultimo.get("crywolf_info", []) == [2, 3])
	cli._tratar(PackedByteArray([0xC1, 0x10, 0xBD, 0x02, 75, 0, 0, 0, 0x12, 0x02, 0x00, 0x11, 0x01, 0, 0, 0]))
	confere("BD 02: estatua 75%, altares", ultimo.get("crywolf_altares", []) == [75, [0x12, 0x02, 0x00, 0x11, 0x01]])
	cli._tratar(PackedByteArray([0xC1, 0x08, 0xBD, 0x03, 1, 0x11, 0x01, 0x3D]))
	confere("BD 03: contrato aceito, chave 317 (big endian)", ultimo.get("crywolf_contrato", []) == [1, 0x11, 317])
	cli._tratar(PackedByteArray([0xC1, 0x06, 0xBD, 0x04, 0, 14]))
	confere("BD 04: 0 h 14 min", ultimo.get("crywolf_tempo", []) == [0, 14])
	cli._tratar(PackedByteArray([0xC1, 0x0C, 0xBD, 0x05, 60, 0, 0, 0, 7, 0, 0, 0]))
	confere("BD 05: Balgass 60%, 7 Dark Elves", ultimo.get("crywolf_chefe", []) == [60, 7])
	cli._tratar(PackedByteArray([0xC1, 0x0C, 0xBD, 0x05, 0xFF, 0xFF, 0xFF, 0xFF, 12, 0, 0, 0]))
	confere("BD 05: vida -1 (Balgass ainda nao veio) com sinal", ultimo.get("crywolf_chefe", []) == [-1, 12])
	cli._tratar(PackedByteArray([0xC1, 0x0C, 0xBD, 0x07, 3, 0, 0, 0, 0x40, 0xE2, 0x01, 0]))
	confere("BD 07: rank A, 123456 de exp", ultimo.get("crywolf_rank", []) == [3, 123456])
	var h := PackedByteArray([0xC1, 0, 0xBD, 0x08, 1, 0])
	h.append_array("testgmElf".to_utf8_buffer())
	h.resize(6 + 10 + 1)
	h.append_array(PackedByteArray([0xE8, 0x03, 0, 0, 9, 0, 0, 0]))
	h[1] = h.size()
	cli._tratar(h)
	confere("BD 08: heroi 0 testgmElf, classe 9, 1000 pontos", ultimo.get("crywolf_heroi", []) == [0, "testgmElf", 9, 1000])
	cli._tratar(PackedByteArray([0xC1, 0x05, 0xBD, 0x09, 5]))
	confere("BD 09: bonus de chaos 5", ultimo.get("crywolf_caos", []) == [5])
	cli._tratar(PackedByteArray([0xC1, 0x0A, 0xBD, 0x0C, 0x01, 0x5C, 62, 30, 110, 40]))
	confere("BD 0C: balista de 62,30 em 110,40", ultimo.get("crywolf_balista", []) == [62, 30, 110, 40])

	# o que sai
	var con := ConFalsa.new()
	cli.con = con
	cli.crywolf_pedir_info()
	cli.crywolf_contratar(317)
	cli.entrar_quartel()
	cli.entrar_refugio()
	confere("sai BD 00, BD 03 01 3D, D0 07 e D0 08", con.enviados[0] == PackedByteArray([0xC1, 4, 0xBD, 0x00])
		and con.enviados[1] == PackedByteArray([0xC1, 6, 0xBD, 0x03, 0x01, 0x3D])
		and con.enviados[2] == PackedByteArray([0xC1, 4, 0xD0, 0x07]) and con.enviados[3] == PackedByteArray([0xC1, 4, 0xD0, 0x08]))

	# Raklion
	var s := Som.new()
	root.add_child(s)
	var rk := Raklion.new()
	root.add_child(rk)
	rk.som = s
	rk.mapa(58)
	rk.mudar(4, 0)
	confere("Raklion pronto: musica do ninho ligada", s.raklion_chefe and rk.pode_ir_ao_ninho())
	s.atualizar(58, false, 0)
	confere("som: Raklion_Hatchery no 58", s._faixa.ends_with("mundo59/musica_chefe.mp3"))
	rk.mudar(7, 0)
	confere("porta fechada: o ninho nao abre", not rk.pode_ir_ao_ninho())
	rk.mudar(10, 0)
	s.atualizar(58, false, 0)
	confere("fim: musica do ninho desliga", not s.raklion_chefe and s._faixa == "")

	# CaixaMU com OK travado e linhas coloridas
	var c := CaixaMU.new([[DicaItem.t(1658), Color8(254, 176, 72)], " ", DicaItem.t(1660)], true, false)
	c.ok_travado = true
	var resp := []
	c.respondeu.connect(func(ok, _t): resp.append(ok))
	root.add_child(c)
	await process_frame
	c.responder(true)
	confere("OK travado nao responde", resp.is_empty() and not c.is_queued_for_deletion())
	confere("cor da 1a linha", c.cores[0] == Color8(254, 176, 72) and c.cores[c.cores.size() - 1] == Color.WHITE)
	c.responder(false)
	confere("Cancel responde", resp == [false])

	# Crywolf com o mapa de verdade
	var m := Node3D.new()
	m.set_script(load("res://scripts/mundo.gd"))
	m.modo_jogo = true
	m.numero = 35
	root.add_child(m)
	await process_frame
	await process_frame
	var cw := Crywolf.new()
	root.add_child(cw)
	await process_frame
	cw.som = s
	cw.mapa(34, m)
	# um tile que anda na paz e nao na guerra (EncTerrain35 x 352)
	var a0 := (load("res://dados/mundo35/mapa.png") as Texture2D).get_image()
	var a2 := (load("res://dados/mundo35/atributos_2.png") as Texture2D).get_image()
	var tile := Vector2i(-1, -1)
	for y in 256:
		for x in 256:
			var v0 := int(round(a0.get_pixel(x, y).a * 255))
			var v2 := int(round(a2.get_pixel(x, y).r * 255))
			if v0 & 12 == 0 and v2 & 4 != 0:
				tile = Vector2i(x, y)
				break
		if tile.x >= 0:
			break
	confere("achou tile que a guerra fecha (%d,%d)" % [tile.x, tile.y], tile.x >= 0 and m.anda(tile.x, tile.y))
	cw.info(2, 1)
	confere("guerra: luz2 e grade 352 (tile fechado)", m.arquivo_luz == "luz2.png" and not m.anda(tile.x, tile.y))
	confere("aviso: sem painel", not cw.painel())
	s.atualizar(34, false, 0)
	confere("som: musica do mapa no 1o aviso", s._faixa.ends_with("mundo35/musica.mp3"))
	cw.info(2, 2)
	s.atualizar(34, false, 0)
	confere("som: crywolf_before no 2o aviso", s._faixa.ends_with("musica_antes.ogg"))
	cw.info(2, 3)
	s.atualizar(34, false, 0)
	confere("pronto: painel e crywolf_ready", cw.painel() and s._faixa.ends_with("musica_pronto.ogg"))
	cw.estatua_altares(80, [0x12, 0x02, 0x00, 0x10, 0x01])
	confere("altar 1 contratado: elfa recebe 'contratado'", cw.clique_altar(205, true) == "contratado")
	confere("altar 2 livre com 2 contratos: 'pode' (2006 com 2)", cw.clique_altar(206, true) == "pode" and cw.contratos_restantes(206) == 2)
	confere("altar 3 sem contratos: 'destruido'", cw.clique_altar(207, true) == "destruido")
	confere("outra classe fala com o altar", cw.clique_altar(206, false) == "falar" and cw.clique_altar(204, true) == "falar")
	cw.altar_contratado(318, 0x11)
	confere("BD 03 aceito na chave 318 marca o altar 2", cw.altares[1] == 0x11)
	cw.chefe(50, 3)
	confere("Balgass so aparece com vida", cw.ver_balgass and cw.elfos == 3)
	cw.info(2, 4)
	s.atualizar(34, false, 0)
	confere("luta: crywolf_back e o Balgass segue no painel (View_Bal so cai fora do START)", s._faixa.ends_with("musica_luta.ogg") and cw.ver_balgass)
	cw.tempo(0, 14)
	confere("relogio: minuto novo = 60 s", cw.contando and cw.minuto == 14 and cw._ms == 60000)
	cw.tempo(0, 14)
	confere("2o pacote no minuto = 40 s", cw._ms == 40000)
	cw.tempo(0, 14)
	confere("3o pacote = 20 s", cw._ms == 20000)
	cw.meu_rank(4, 98765)
	cw.heroi_lista(0, "testgmElf", 9, 1000)
	cw.heroi_lista(1, "test1Dk", 4, 500)
	var caixa := []
	cw.resultado_pronto.connect(func(_l): caixa.append(1))
	cw.info(0, 5)
	confere("fim em paz: vitoria, luz e grade de volta", cw.faixa == 1 and cw.venceu and m.arquivo_luz == "luz.png" and m.anda(tile.x, tile.y))
	s.atualizar(34, false, 0)
	confere("som: fim sem musica", s._faixa == "")
	cw.heroi_lista(0, "testgmElf", 9, 1000)
	for i in 440:
		cw._quadro()
	confere("faixa entra, fica 400 quadros, sai e abre a caixa", cw.faixa == -1 and caixa == [1])
	var l := cw.linhas_resultado(func(n): return "classe%d" % n)
	confere("caixa: titulo, 1 heroi, premio da vitoria", l[0][0].begins_with(DicaItem.t(680)) and l[1] == "1      testgmElf      classe9      1000"
		and l[l.size() - 1][0] == DicaItem.t(2001))
	cw.info(1, 5)
	confere("ocupado: derrota", not cw.venceu and m.arquivo_luz == "luz1.png")
	cw.mapa(0)
	confere("fora do 34: nada", not cw.no_crywolf() and not cw.painel())
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
