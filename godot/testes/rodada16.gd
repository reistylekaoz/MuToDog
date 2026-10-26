extends SceneTree
# Confere a rodada 16 sem servidor: o Illusion Temple. Os 6 templos (45 a 50) na pasta mundo47 em pacote a
# parte, com as duas musicas e o que o mapa monta (objetos 70 a 79 escondidos, nuvens e tochas, as malhas
# 64/65/80 somadas e pulsando); os pacotes C1 BF que chegam (00 a 09) e os que saem (BF 00, 02 e 05); a
# janela de entrada da Mirage (faixas de nivel); o HUD (estados, placar, skills e pontos, barra da estatua,
# minimapa); a caixa do resultado (vitoria com 2 pontos ou mais) e os bonecos do templo.
# Uso: $G --headless --path . --script res://testes/rodada16.gd   (termina com "falhas: 0")

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


func _nome(n: String) -> PackedByteArray:
	var b := n.to_utf8_buffer()
	b.resize(10)
	return b


func _initialize() -> void:
	# mapas, pacote e arquivos
	confere("templos 45 a 50 usam a pasta mundo47", range(45, 51).all(func(x): return PacoteMapa.mundo_do_mapa(x) == 47))
	confere("47 em pacote a parte", 47 in PacoteMapa.FORA)
	for f in ["mundo47/objetos.json", "mundo47/musica.mp3", "mundo47/musica_jogo.mp3", "hud/templo/sucesso.png",
			"hud/templo/falha.png", "hud/templo/msg_titulo.png", "hud/templo/btn_mini.png", "hud/templo/barra.png",
			"efeitos/eventsungmul.glb", "efeitos/eventshild.glb", "efeitos/eventroofe.glb", "mundo47/sons/start01.wav",
			"mundo47/sons/score01.wav", "mundo47/sons/end01.wav", "mundo47/sons/holy01.wav", "personagens/templo_aliado", "personagens/templo_ilusao",
			"personagens/monster124", "personagens/monster125", "personagens/monster126"]:
		confere("arquivo " + f, FileAccess.file_exists("res://dados/" + f) or FileAccess.file_exists("res://dados/" + f + ".glb"))
	var mm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/monstros_mapa.json"))
	confere("pacote 47 leva os bonecos do templo", mm.get("47", []) == ["templo_aliado", "templo_ilusao"])
	confere("espiritos 386 a 403 e skins 404/405", Boneco.NPCS.has(386) and Boneco.NPCS.has(403)
		and Boneco.NPCS[404][0] == "templo_aliado" and Boneco.NPCS[405][0] == "templo_ilusao")

	# o mapa
	var m := Node3D.new()
	m.set_script(load("res://scripts/mundo.gd"))
	m.modo_jogo = true
	m.numero = 47
	root.add_child(m)
	await process_frame
	await process_frame
	var vis := 0
	for par in m.nos_objetos:
		if int(par[1].t) >= 70 and int(par[1].t) <= 79:
			vis += 1
	confere("70 a 79 nem viram objeto (HiddenMesh -2): %d" % vis, vis == 0 and m.nos_objetos.size() > 1000)
	confere("64, 65, 66 e 80 somados", _somado(m, 64) and _somado(m, 65) and _somado(m, 66) and _somado(m, 80))
	var amb: Node = m.find_child("Ambiente", true, false)
	if amb == null:
		for c in m.get_children():
			if c.get_script() == load("res://scripts/ambiente.gd"):
				amb = c
	confere("64/65/80 pulsando (%d)" % (amb._pulsam.size() if amb else -1), amb != null and amb._pulsam.size() >= 3)
	confere("tochas e nuvens no mapa (%d)" % (amb.fogos if amb else -1), amb != null and amb.fogos >= 32 + 150)
	m.free()

	# pacotes que chegam
	var cli := ClienteMU.new()
	for s in ["templo_entrada", "templo_info", "templo_gente", "templo_skill", "templo_skill_fim", "templo_pontos",
			"templo_reliquia", "templo_resultado", "templo_estado"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 5, 0xBF, 0x00, 4]))
	confere("BF 00: resultado 4", ultimo.get("templo_entrada", []) == [4])
	var p := PackedByteArray([0xC1, 0, 0xBF, 0x01, 0x2C, 0x01, 0x12, 0x80, 170, 84, 1, 2, 0, 2,
		0x07, 0x80, 45, 140, 40, 0x09, 0x00, 45, 150, 50])
	p[1] = p.size()
	cli._tratar(p)
	var d: Dictionary = ultimo.get("templo_info", [{}])[0]
	confere("BF 01: 300 s, reliquia com 0x12, 1 x 2, equipe 0", d.get("tempo") == 300 and d.get("reliquia") == 0x12
		and d.get("rx") == 170 and d.get("aliados") == 1 and d.get("ilusao") == 2 and d.get("equipe") == 0)
	confere("BF 01: grupo de 2 (ids sem o bit de cima)", d.get("grupo", []).size() == 2 and d.grupo[0].id == 7 and d.grupo[1].y == 50)
	cli._tratar(PackedByteArray([0xC1, 11, 0xBF, 0x02, 1, 0x00, 0xD5, 0x07, 0x00, 0x09, 0x80]))
	confere("BF 02: 213 de 7 em 9", ultimo.get("templo_skill", []) == [true, 213, 7, 9])
	cli._tratar(PackedByteArray([0xC1, 10, 0xBF, 0x03, 1, 2, 3, 4, 5, 6]))
	confere("BF 03: gente dos 6 templos", ultimo.get("templo_gente", [[]])[0] == [1, 2, 3, 4, 5, 6])
	p = PackedByteArray([0xC1, 0, 0xBF, 0x04, 3, 1, 2])
	for e in [["Eu", 0, 0, 5000], ["Rival", 1, 4, 1200]]:
		p.append_array(_nome(e[0]))
		p.append_array(PackedByteArray([45, e[1], e[2], e[3] & 0xFF, (e[3] >> 8) & 0xFF, 0, 0]))
	p[1] = p.size()
	cli._tratar(p)
	var r: Array = ultimo.get("templo_resultado", [0, 0, []])
	confere("BF 04: 3 x 1, 2 linhas", r[0] == 3 and r[1] == 1 and r[2].size() == 2 and r[2][1].nome == "Rival" and r[2][0].exp == 5000)
	cli._tratar(PackedByteArray([0xC1, 5, 0xBF, 0x06, 12]))
	confere("BF 06: 12 pontos", ultimo.get("templo_pontos", []) == [12])
	cli._tratar(PackedByteArray([0xC1, 8, 0xBF, 0x07, 0x00, 0xD3, 0x09, 0x00]))
	confere("BF 07: 211 acabou em 9", ultimo.get("templo_skill_fim", []) == [211, 9])
	p = PackedByteArray([0xC1, 16, 0xBF, 0x08, 0x12, 0x00])
	p.append_array(_nome("Rival"))
	cli._tratar(p)
	confere("BF 08: reliquia com 0x12 (Rival)", ultimo.get("templo_reliquia", []) == [0x12, "Rival"])
	cli._tratar(PackedByteArray([0xC1, 6, 0xBF, 0x09, 1, 2]))
	confere("BF 09: templo 1 estado 2", ultimo.get("templo_estado", []) == [1, 2])

	# pacotes que saem
	var con := ConFalsa.new()
	cli.con = con
	cli.templo_entrar(3)
	cli.templo_usar(211, 9, 2)
	cli.templo_premio()
	confere("sai C1 BF 00 [3, FF]", con.enviados[0] == PackedByteArray([0xC1, 6, 0xBF, 0x00, 3, 0xFF]))
	confere("sai C1 BF 02 com 211 big endian, alvo e distancia", con.enviados[1] == PackedByteArray([0xC1, 8, 0xBF, 0x02, 0, 0xD3, 9, 2]))
	confere("sai C1 BF 05", con.enviados[2] == PackedByteArray([0xC1, 4, 0xBF, 0x05]))

	# janela da Mirage
	confere("nivel 219 nao entra, 220 no 1, 300 no 2, 400 no 5, master no 6", JanelaTemplo.templo_do_nivel(219, false) == -1
		and JanelaTemplo.templo_do_nivel(220, false) == 1 and JanelaTemplo.templo_do_nivel(300, false) == 2
		and JanelaTemplo.templo_do_nivel(400, false) == 5 and JanelaTemplo.templo_do_nivel(400, true) == 6)
	var jt := JanelaTemplo.new()
	root.add_child(jt)
	await process_frame
	var entrou := []
	jt.entrar.connect(func(n): entrou.append(n))
	jt.abrir(330, false)
	jt.contar([1, 2, 7, 4, 5, 6])
	confere("janela aberta no templo 3 com 7 la dentro", jt.visible and jt.templo == 3 and jt.gente == 7)
	jt.clicar(0)
	jt.abrir(100, false)
	jt.clicar(0)
	confere("Enter manda 3; nivel 100 manda -1 (so o aviso)", entrou == [3, -1])
	jt.clicar(1)
	confere("Close fecha", not jt.visible)
	confere("textos: " + DicaItem.t(2358) + " / " + DicaItem.t(2371, [220, 270]), DicaItem.t(2358) != "" and DicaItem.t(2371, [220, 270]).contains("220"))

	# HUD
	var t := Templo.new()
	root.add_child(t)
	await process_frame
	var avisos := []
	var usos := []
	var falas := []
	t.aviso.connect(func(x, e): avisos.append([x, e]))
	t.usar.connect(func(s, a): usos.append([s, a]))
	t.falar.connect(func(n): falas.append(n))
	t.mapa(45)
	t.meu_id = 7
	t.mudar_estado(1)
	confere("estado 2 mostra o HUD e zera", t.estado == 2 and t.mostrando and t.pontos == 0)
	t.receber({"tempo": 600, "reliquia": 0xFFFF, "rx": 0, "ry": 0, "aliados": 0, "ilusao": 0, "equipe": 0, "grupo": [{"id": 7, "mapa": 45, "x": 140, "y": 40}]})
	t.receber({"tempo": 590, "reliquia": 0xFFFF, "rx": 0, "ry": 0, "aliados": 1, "ilusao": 0, "equipe": 0, "grupo": []})
	confere("placar 1 x 0 avisa \"%s\"" % avisos[-1][0], t.aliados == 1 and avisos[-1][0] == DicaItem.t(2360))
	t.skill = Templo.PROTECAO
	confere("sem pontos: nao usa (2392)", t.tentar(-1, false, 0) == -1 and avisos[-1][0] == DicaItem.t(2392))
	t.receber_pontos(6)
	confere("6 pontos avisa +6", t.pontos == 6 and avisos[-1][0] == DicaItem.t(2391, [6]))
	confere("210 com 6 pontos vai em mim", t.tentar(-1, false, 0) == 7 and usos[-1] == [210, 7])
	confere("pedido no ar segura o proximo", t.tentar(-1, false, 0) == -1)
	t.skill_voltou(7)
	t.trocar_skill(1)
	confere("211 sem alvo nao vai; alvo a 4 nao vai; a 2 vai", t.skill == 211 and t.tentar(-1, false, 0) == -1
		and t.tentar(9, true, 4) == -1 and t.tentar(9, true, 2) == 9)
	t.skill_voltou(7)
	t.trocar_skill(1)
	confere("212 sem reliquia em jogo nao vai", t.skill == 212 and t.tentar(-1, false, 0) == -1)
	t.trocar_skill(5)
	confere("trocar para no 213", t.skill == 213)
	confere("estatua (380) comeca a barra", t.clicou_npc(380, 50, false) and t.progresso_npc == 50 and t.progresso_tipo == 0)
	t._process(10.5)
	confere("barra cheia fala com a estatua", falas == [50] and t.progresso_npc == -1)
	confere("banco da outra equipe (384) nao faz nada", t.clicou_npc(384, 51, true) and t.progresso_npc == -1)
	confere("banco da minha (383) sem reliquia: 2092", t.clicou_npc(383, 52, false) and avisos[-1][0] == DicaItem.t(2092))
	confere("banco com reliquia: guardando", t.clicou_npc(383, 52, true) and t.progresso_tipo == 1)
	t.meu_tile = Vector2i(1, 1)
	t._process(0.1)
	confere("andou: barra cancelada", t.progresso_npc == -1)
	confere("comandante (381) nao e com o HUD", not t.clicou_npc(381, 53, false))
	confere("minimapa: estatua (170, 84) em (573, 325) como o MiniMapPos", Templo.minimapa(170, 84).distance_to(Vector2(170 / 1.56 + 464, 41 / 1.56 + 299)) < 0.01)
	var s := Som.new()
	root.add_child(s)
	t.som = s
	t.mudar_estado(0)
	confere("estado 1: som.templo 1", s.templo == 1)
	t.mapa(0)
	confere("fora do templo: some e zera o estado", not t.mostrando and t.estado == 0 and s.templo == 0)

	# resultado
	var cx := CaixaTemplo.new()
	cx.heroi = "Eu"
	cx.minha_equipe = 0
	cx.aliados = 3
	cx.ilusao = 1
	cx.lista = r[2]
	root.add_child(cx)
	await process_frame
	confere("3 x 1 na MU Alliance: vitoria", cx.venceu == 1)
	var fechou := []
	cx.fechou.connect(func(): fechou.append(1))
	cx.fechar()
	confere("Close emite fechou (pede o premio)", fechou == [1])
	var cx2 := CaixaTemplo.new()
	cx2.minha_equipe = 0
	cx2.aliados = 1
	cx2.ilusao = 0
	root.add_child(cx2)
	await process_frame
	confere("1 x 0: derrota (precisa de 2)", cx2.venceu == 2)
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
