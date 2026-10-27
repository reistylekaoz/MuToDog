extends SceneTree
# Confere a rodada 22 sem servidor: a batalha do Castle Siege. Os C1 B2 14 a 20 (interruptor, coroa, inicio e fim,
# lado, comando, relogio, quem segura o interruptor), os C2 B6 e BB do minimapa e os C1 B7 da catapulta; os pedidos
# que saem (B2 1D, B7 01, B7 04); o minimapa da guerra (observador, soldado, comandante, transparencia, escala,
# grupo e comando, ida e volta do tile), a janela da catapulta (ataque e defesa, Shoot travado sem area) e os
# arquivos da rodada (texturas, sons, pedras).
# Uso: $G --headless --path . --script res://testes/rodada22.gd   (termina com "falhas: 0")

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


static func nome(t: String, n: int) -> Array:
	var b := t.to_utf8_buffer()
	b.resize(n)
	return Array(b)


func _initialize() -> void:
	for f in ["mm_moldura", "mm_tempo", "mm_mapa", "mm_grupo", "mm_comando", "mm_alfa", "cmd_ataque", "cmd_defesa",
			"cmd_espera", "cat_portao", "cat_area", "botao_grande"]:
		confere("textura hud/castelo/%s" % f, ResourceLoader.exists("res://dados/hud/castelo/%s.png" % f))
	for f in ["cs_oCDoorMove", "cs_oSWFire", "cs_oSWHitG"]:
		confere("som %s" % f, ResourceLoader.exists("res://dados/sons/%s.wav" % f))
	for f in ["flybigstone1.glb", "flybigstone2.glb", "hugerock02.png"]:
		confere("pedra %s" % f, ResourceLoader.exists("res://dados/efeitos/" + f))

	# --- pacotes que chegam ---
	var cli := ClienteMU.new()
	for s in ["cs_guerra", "cs_mapa_guerra", "cs_catapulta"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 9, 0xB2, 0x14, 0x01, 0x2C, 0x00, 0x05, 2]))
	confere("B2 14: interruptor 300, quem 5, ja apertado", ultimo.cs_guerra == [0x14, {"interruptor": 300, "quem": 5, "estado": 2}])
	cli._tratar(PackedByteArray([0xC1, 9, 0xB2, 0x15, 0, 0x88, 0x13, 0, 0]))
	confere("B2 15: selo comecou, 5000 ms (little endian)", ultimo.cs_guerra == [0x15, {"estado": 0, "ms": 5000}])
	cli._tratar(PackedByteArray([0xC1, 5, 0xB2, 0x16, 1]))
	confere("B2 16: escudo da coroa", ultimo.cs_guerra == [0x16, {"estado": 1}])
	cli._tratar(PackedByteArray([0xC1, 5, 0xB2, 0x17, 1]))
	confere("B2 17: batalha comecou", ultimo.cs_guerra == [0x17, {"estado": 1}])
	cli._tratar(PackedByteArray([0xC1, 13, 0xB2, 0x18, 1] + nome("Ursos", 8)))
	confere("B2 18: Ursos registrou o selo", ultimo.cs_guerra == [0x18, {"estado": 1, "guilda": "Ursos"}])
	cli._tratar(PackedByteArray([0xC1, 5, 0xB2, 0x19, 2]))
	confere("B2 19: lado 2", ultimo.cs_guerra == [0x19, {"estado": 2}])
	cli._tratar(PackedByteArray([0xC1, 8, 0xB2, 0x1D, 3, 150, 200, 1]))
	confere("B2 1D: time 3 defende 150,200", ultimo.cs_guerra == [0x1D, {"time": 3, "x": 150, "y": 200, "cmd": 1}])
	cli._tratar(PackedByteArray([0xC1, 6, 0xB2, 0x1E, 1, 45]))
	confere("B2 1E: 1:45", ultimo.cs_guerra == [0x1E, {"hora": 1, "minuto": 45}])
	cli._tratar(PackedByteArray([0xC1, 27, 0xB2, 0x20, 0x01, 0x2D, 1, 2] + nome("Ursos", 8) + nome("quest1Dk", 11)))
	confere("B2 20: interruptor 301 com Ursos / quest1Dk", ultimo.cs_guerra[0] == 0x20 and ultimo.cs_guerra[1].interruptor == 301
		and ultimo.cs_guerra[1].ocupado and ultimo.cs_guerra[1].guilda == "Ursos" and ultimo.cs_guerra[1].nome == "quest1Dk")
	cli._tratar(PackedByteArray([0xC2, 0, 12, 0xB6, 2, 0, 0, 0, 10, 20, 30, 40]))
	confere("C2 B6: 2 da guilda", ultimo.cs_mapa_guerra == [0xB6, [[0, 10, 20], [0, 30, 40]]])
	cli._tratar(PackedByteArray([0xC2, 0, 11, 0xBB, 2, 0, 93, 114, 1, 80, 60]))
	confere("C2 BB: portao e estatua (tipo + 1)", ultimo.cs_mapa_guerra == [0xBB, [[1, 93, 114], [2, 80, 60]]])
	cli._tratar(PackedByteArray([0xC1, 8, 0xB7, 0x00, 1, 2, 0x02, 0x10]))
	confere("B7 00: catapulta de defesa 528", ultimo.cs_catapulta == [0, {"resultado": 1, "tipo": 2, "npc": 528}])
	cli._tratar(PackedByteArray([0xC1, 10, 0xB7, 0x01, 1, 0x02, 0x10, 1, 93, 110]))
	confere("B7 01: tiro em 93,110", ultimo.cs_catapulta == [1, {"resultado": 1, "npc": 528, "tipo": 1, "x": 93, "y": 110}])
	cli._tratar(PackedByteArray([0xC1, 7, 0xB7, 0x02, 2, 90, 120]))
	confere("B7 02: pedra caindo em 90,120", ultimo.cs_catapulta == [2, {"tipo": 2, "x": 90, "y": 120}])

	# --- pedidos que saem ---
	var con := ConFalsa.new()
	cli.con = con
	cli.cs_comando(3, 150, 200, 0)
	cli.catapulta_atirar(528, 2)
	cli.catapulta_caiu(528)
	confere("sai C1 B2 1D", con.enviados[0] == PackedByteArray([0xC1, 8, 0xB2, 0x1D, 3, 150, 200, 0]))
	confere("sai C1 B7 01 (npc big endian, area)", con.enviados[1] == PackedByteArray([0xC1, 7, 0xB7, 0x01, 0x02, 0x10, 2]))
	confere("sai C1 B7 04", con.enviados[2] == PackedByteArray([0xC1, 6, 0xB7, 0x04, 0x02, 0x10]))

	# --- minimapa da guerra ---
	var g := GuerraCastelo.new()
	root.add_child(g)
	var cmds: Array = []
	g.comando.connect(func(t, x, y, c): cmds.append([t, x, y, c]))
	confere("sem lado e observador", g.tipo() == GuerraCastelo.OBSERVADOR)
	g.lado = 2
	confere("com lado e soldado", g.tipo() == GuerraCastelo.SOLDADO)
	g.sou_mestre = true
	confere("mestre com lado e comandante", g.tipo() == GuerraCastelo.COMANDANTE)
	g.heroi = Vector2i(100, 100)
	var mm := g._mapa_pos()
	confere("heroi no meio do minimapa", g.no_minimapa(100, 100) == mm + Vector2(64, 64))
	g.heroi = Vector2i(10, 250)
	confere("no canto o mapa para na borda", g._deslocamento() == Vector2(0, 0))
	g.heroi = Vector2i(100, 100)
	var m := g.moldura()
	g.clicar(m + Vector2(60, 8))
	confere("transparencia 90", is_equal_approx(g.alfa, 0.9))
	for i in 4:
		g.clicar(m + Vector2(60, 8))
	confere("transparencia 50", is_equal_approx(g.alfa, 0.5))
	g.clicar(m + Vector2(60, 8))
	confere("depois de 50 volta pra 100", is_equal_approx(g.alfa, 1.0))
	g.clicar(m + Vector2(138, 10))
	confere("escala 2 (mapa inteiro)", g.escala == 2)
	g.clicar(m + Vector2(138, 10))
	confere("escala 1", g.escala == 1)
	g.clicar(g._grupo_r(2).get_center())
	confere("grupo 3", g.grupo == 2)
	g.clicar(g._cmd_r(1).get_center())
	confere("comando defesa", g.cmd == 1)
	g.clicar(mm + Vector2(64, 64))
	confere("clique no meio manda o comando no tile do heroi", cmds == [[2, 100, 100, 1]] and g.cmd == -1)
	g.clicar(g._grupo_r(6).get_center())
	confere("grupo 7: comandos sobem pra caber", g._cmd_r(2).position.y + 22 <= m.y + 5 + 7 * 22)
	g.receber_comando({"time": 3, "x": 150, "y": 200, "cmd": 0})
	confere("comando recebido fica 100 quadros", g.comandos[3].vida == 100)
	g.receber_comando({"time": 3, "x": 0, "y": 0, "cmd": 9})
	confere("comando invalido apaga", not g.comandos.has(3))
	g.receber_interruptor({"interruptor": 300, "ocupado": true, "lado": 2, "guilda": "Ursos", "nome": "quest1Dk"}, true)
	confere("longe da coroa nao mostra o interruptor", g.texto_interruptores().is_empty())
	g.heroi = Vector2i(170, 195)
	confere("perto da coroa: Crown switch 1 / Ursos / quest1Dk", g.texto_interruptores() == ["Crown switch 1 / Ursos / quest1Dk"])
	confere("o mouse so e do minimapa na moldura", g._has_point(m + Vector2(80, 80)) and not g._has_point(Vector2(100, 100)))
	g.sou_mestre = false
	confere("soldado nao tem botao de grupo fora da moldura", not g._has_point(m + Vector2(10, 200)) or g._has_point(m + Vector2(10, 200)) == Rect2(m, GuerraCastelo.MOLDURA).has_point(m + Vector2(10, 200)))

	# --- catapulta ---
	var j := JanelaCastelo.new()
	root.add_child(j)
	var tiros: Array = []
	var fechou := [0]
	j.atirar.connect(func(n, a): tiros.append([n, a]))
	j.fechar.connect(func(): fechou[0] += 1)
	j.abrir_catapulta(528, 1)
	confere("catapulta de ataque: 4 areas", j.visible and j.modo == "catapulta" and j._areas().size() == 4)
	j.clicar(j._atirar_r().get_center())
	confere("Shoot travado sem area", tiros.is_empty() and fechou[0] == 0)
	j.clicar(Vector2(95, 40))
	confere("sem abas na catapulta", j.aba == 0 and j.area == -1)
	j.clicar(Vector2(97, 150))
	confere("Castle Gate 2 escolhido", j.area == 1)
	j.clicar(j._atirar_r().get_center())
	confere("Shoot manda atirar(528, 2) e fecha", tiros == [[528, 2]] and fechou[0] == 1)
	j.abrir_catapulta(529, 2)
	confere("catapulta de defesa: 3 areas", j._areas().size() == 3 and j.area == -1)
	j.clicar(Vector2(90, 200))
	j.clicar(j._atirar_r().get_center())
	confere("Bridge: atirar(529, 3)", tiros.back() == [529, 3])

	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
