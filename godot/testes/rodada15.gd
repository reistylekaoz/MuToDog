extends SceneTree
# Confere a rodada 15 sem servidor: os 3 mapas (os 7 Kalimas na pasta World25, Santa Village na 63, Arena
# na 65, cada um em pacote a parte no navegador com a musica), o que cada um monta (Kalima sem terreno e com
# a agua, nado e cachoeira; Santa com neve e as luzes 26 a 28; Arena com luz no chao, fumaca e fogo), a dica
# do Lost Map e do Symbol of Kundun, e o duelo: pacotes C1 AA que chegam, C3 AA que saem, o placar e os
# comandos /duelstart e /duelend.
# Uso: $G --headless --path . --script res://testes/rodada15.gd   (termina com "falhas: 0")

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


func _mundo(n: int) -> Node3D:
	var m := Node3D.new()
	m.set_script(load("res://scripts/mundo.gd"))
	m.modo_jogo = true
	m.numero = n
	root.add_child(m)
	await process_frame
	await process_frame
	return m


# todas as faces do primeiro objeto do tipo t com material somado (EfeitoMU, modo 1)
func _somado(m: Node3D, t: int) -> bool:
	for par in m.nos_objetos:
		if int(par[1].t) != t:
			continue
		var tem := false
		for mi: MeshInstance3D in (par[0] as Node).find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_surface_override_material(s) as ShaderMaterial
				if mat == null or mat.shader != EfeitoMU.SHADER:
					return false
				tem = true
		return tem
	return false


func _initialize() -> void:
	# mapas e pastas
	var kal := [24, 25, 26, 27, 28, 29, 36].all(func(x): return PacoteMapa.mundo_do_mapa(x) == 25)
	confere("os 7 Kalimas (24 a 29 e 36) usam a pasta mundo25", kal)
	confere("Santa Village (62) na 63 e Arena (64) na 65", PacoteMapa.mundo_do_mapa(62) == 63 and PacoteMapa.mundo_do_mapa(64) == 65)
	confere("25, 63 e 65 em pacote a parte", [25, 63, 65].all(func(x): return x in PacoteMapa.FORA))
	for f in ["mundo25/objetos.json", "mundo25/agua1.png", "mundo25/agua2.png", "mundo25/musica.mp3", "mundo25/fundo.wav",
			"mundo63/objetos.json", "mundo63/folha1.png", "mundo63/musica.mp3", "mundo65/objetos.json", "mundo65/musica.mp3",
			"hud/duelo_fundo.png", "sons/duelo_janela.wav", "sons/duelo_comeca.wav"]:
		confere("arquivo " + f, FileAccess.file_exists("res://dados/" + f))

	# Kalima
	var m: Node3D = await _mundo(25)
	var amb: Ambiente = m.ambiente
	confere("Kalima: terreno escondido", not (m.mu.get_node("Terreno") as MeshInstance3D).visible)
	var agua := m.mu.get_node_or_null("AguaKalima") as MeshInstance3D
	confere("Kalima: agua a 350 com as duas passadas", agua != null and is_equal_approx(agua.position.z, 350.0)
		and (agua.material_override as ShaderMaterial).next_pass != null)
	confere("Kalima: fundo (30, 40, 40)", Ambiente.CEU.get(25) == Color8(30, 40, 40))
	confere("Kalima: luzes azuis 35 e 36 (%d)" % amb._brilhos.size(), amb._brilhos.size() == 18 + 6)
	confere("Kalima: cachoeiras 37 a 40 (%d emissores)" % amb.fogos, amb.fogos == 62 + 25 + 52 + 50)
	confere("Kalima: sem grama", amb.gramas == 0)
	var esc: Array = m.nos_objetos.filter(func(par): return int(par[1].t) in [35, 36, 37, 38, 39, 40] and par[0].visible)
	confere("Kalima: 35 a 40 escondidos", esc.is_empty())
	m.free()

	# Santa Village
	m = await _mundo(63)
	amb = m.ambiente
	confere("Santa: neve caindo (leaf01 e leaf02)", amb._cai != null and amb._cai2 != null)
	confere("Santa: luzes 26 a 28 (%d)" % amb._brilhos.size(), amb._brilhos.size() == 42 + 71 + 56)
	var b0: Array = amb._brilhos[0]
	confere("Santa: pulso (sin(t * 5) * 0,1 + 1) e sprite a 8 x Scale", b0[4] == [5.0, 0.1, 1.0])
	confere("Santa: ceu de estrelas (21, ChrisSky_R) somado", _somado(m, 21))
	confere("Santa: aurora (18) e luz (29) somadas, casa (25) nao inteira", _somado(m, 18) and _somado(m, 29) and not _somado(m, 25))
	m.free()

	# Arena
	m = await _mundo(65)
	amb = m.ambiente
	confere("Arena: brilho no 36 (%d)" % amb._brilhos.size(), amb._brilhos.size() == 59)
	confere("Arena: fogo no 36 e fumaca no 35 (%d)" % amb.fogos, amb.fogos == 59 + 34)
	confere("Arena: lava (24, PKMagma_R) somada", _somado(m, 24))
	m.free()

	# dicas
	DicaItem.eu = {"nivel": 100, "classe": 0}
	var linhas: Array = DicaItem.linhas({"grupo": 14, "numero": 28, "nivel": 3}).map(func(l): return l.get("t", ""))
	var txt := "\n".join(linhas)
	confere("Lost Map: cabecalho e 7 linhas", txt.contains("Kalima Level       Min. Level") and txt.contains("7             350~400"))
	confere("Lost Map +3 em amarelo", DicaItem.linhas({"grupo": 14, "numero": 28, "nivel": 3}).any(func(l):
		return l.get("t", "").begins_with("3 ") and l.get("cor") == DicaItem.AMARELO))
	confere("Lost Map: joga na tela", txt.contains("Magic stone will appear when you throw it in the screen"))
	DicaItem.eu = {"nivel": 30, "classe": 0}
	txt = "\n".join(DicaItem.linhas({"grupo": 14, "numero": 28, "nivel": 1}).map(func(l): return l.get("t", "")))
	confere("Lost Map: nivel 30 de DW nao chega no 40", txt.contains("Only above level 40 can use."))
	DicaItem.eu = {"nivel": 30, "classe": 3 << 2}
	txt = "\n".join(DicaItem.linhas({"grupo": 14, "numero": 28, "nivel": 1}).map(func(l): return l.get("t", "")))
	confere("Lost Map: MG entra a partir do 20", txt.contains("1              20~400") and not txt.contains("Only above"))
	txt = "\n".join(DicaItem.linhas({"grupo": 14, "numero": 29, "durabilidade": 3}).map(func(l): return l.get("t", "")))
	confere("Symbol of Kundun 3/5: faltam 2", txt.contains("3 / 5") and txt.contains("2 is lacking to create lost map."))

	# duelo: pacotes
	var cli := ClienteMU.new()
	for s in ["duelo_resultado", "duelo_pedido", "duelo_fim", "duelo_placar", "duelo_vida", "duelo_venceu"]:
		cli.connect(s, guarda(s))
	var nome := func(n: String) -> PackedByteArray:
		var b := n.to_utf8_buffer()
		b.resize(10)
		return b
	var p := PackedByteArray([0xC1, 17, 0xAA, 0x01, 0, 0x01, 0x23])
	p.append_array(nome.call("Rival"))
	cli._tratar(p)
	confere("C1 AA 01: aceitou, id 0x123 (big endian)", ultimo.get("duelo_resultado", []) == [0, 0x123, "Rival"])
	p = PackedByteArray([0xC1, 16, 0xAA, 0x02, 0x23, 0x01])
	p.append_array(nome.call("Rival"))
	cli._tratar(p)
	confere("C1 AA 02: pedido do 0x123 (little endian)", ultimo.get("duelo_pedido", []) == [0x123, "Rival"])
	cli._tratar(PackedByteArray([0xC1, 10, 0xAA, 0x04, 0x01, 0x23, 0x00, 0x07, 3, 5]))
	confere("C1 AA 04: placar 3 x 5", ultimo.get("duelo_placar", []) == [0x123, 7, 3, 5])
	cli._tratar(PackedByteArray([0xC1, 12, 0xAA, 0x05, 0x01, 0x23, 0x00, 0x07, 40, 90, 10, 100]))
	confere("C1 AA 05: vida e SD", ultimo.get("duelo_vida", []) == [0x123, 7, 40, 90, 10, 100])
	p = PackedByteArray([0xC1, 24, 0xAA, 0x0C])
	p.append_array(nome.call("Eu"))
	p.append_array(nome.call("Rival"))
	cli._tratar(p)
	confere("C1 AA 0C: vencedor e perdedor", ultimo.get("duelo_venceu", []) == ["Eu", "Rival"])
	p = PackedByteArray([0xC1, 17, 0xAA, 0x03, 0, 0x01, 0x23])
	p.append_array(nome.call("Rival"))
	cli._tratar(p)
	confere("C1 AA 03: fim", ultimo.get("duelo_fim", []) == [0, 0x123, "Rival"])
	var con := ConFalsa.new()
	cli.con = con
	cli.duelo_pedir(0x123, "Rival")
	cli.duelo_responder(true, 0x123, "Rival")
	cli.duelo_parar()
	confere("sai C3 AA 01 de 16 com id big endian", con.enviados[0].size() == 16 and con.enviados[0].slice(0, 6) == PackedByteArray([0xC3, 16, 0xAA, 0x01, 0x01, 0x23]))
	confere("sai C3 AA 02 de 17 com id little endian", con.enviados[1].size() == 17 and con.enviados[1].slice(0, 7) == PackedByteArray([0xC3, 17, 0xAA, 0x02, 1, 0x23, 0x01]))
	confere("sai C3 AA 03", con.enviados[2] == PackedByteArray([0xC3, 4, 0xAA, 0x03]))

	# placar
	var j := JanelaDuelo.new()
	root.add_child(j)
	await process_frame
	j.abrir("Eu", 0x123, "Rival")
	j.placar(7, 0x123, 2, 4)
	confere("placar: eu 2, ele 4 (ele vem em segundo)", j.meus == 2 and j.dele == 4 and j.visible)
	j.placar(0x123, 7, 6, 1)
	confere("placar: ele em primeiro, eu 1, ele 6", j.meus == 1 and j.dele == 6)
	j.vidas(0x123, 7, 30, 80, 0, 50)
	confere("vida: eu 80/50, ele 30/0", j.vida == {"eu": 80, "ele": 30, "sd_eu": 50, "sd_ele": 0})
	j.queue_redraw()
	await process_frame
	confere("placar a 131 da direita e 121 de baixo", j.canto().x == 509.0)
	j.fechar()
	confere("fechou", not j.visible)
	confere("textos: " + DicaItem.t(912, ["Rival"]), DicaItem.t(912, ["Rival"]) == "Rival has accepted your challenge."
		and DicaItem.t(2695, ["Eu"]) == "Eu has just won" and DicaItem.t(910) == "You are challenged to a duel.")
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
