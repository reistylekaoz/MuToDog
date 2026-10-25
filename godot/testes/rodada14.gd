extends SceneTree
# Confere a rodada 14 sem servidor: os pacotes do Chaos Castle que chegam (C1 AF 01 resposta da entrada,
# 91 tipo 4 quanto falta pra abrir, 9B estados 5 a 10, 92 contagem 10 a 13, 17 com quem matou) e o que sai
# (C1 91 4 e AF 01 com o nivel e a casa da armadura), a janela do tempo com "Character", a caixa do
# resultado, os buracos dos 3 estagios na grade, os aneis que caem e aparecem, as armas do castelo e o
# mapa (os 7 castelos usam a pasta World19).
# Uso: $G --headless --path . --script res://testes/rodada14.gd   (termina com "falhas: 0")

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
	for s in ["evento_entrada", "evento_abre", "bc_estado", "evento_contagem", "morte", "objeto_morreu"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 5, 0xAF, 0x01, 7]))
	confere("C1 AF 01: sem zen (7)", ultimo.get("evento_entrada", []) == ["cc", 7])
	cli._tratar(PackedByteArray([0xC1, 7, 0x91, 4, 0, 12, 3]))
	confere("C1 91 4: 3 minutos (alto 0, baixo 3), 12 dentro", ultimo.get("evento_abre", []) == [4, 0, 12, 3])
	cli._tratar(PackedByteArray([0xC1, 13, 0x9B, 6, 0x58, 2, 100, 0, 57, 0, 0xFF, 0xFF, 0xFF]))
	confere("C1 9B: estado 6, 600 s, 57 de 100", ultimo.get("bc_estado", []) == [6, 600, 100, 57, 0xFFFF, 0xFF])
	cli._tratar(PackedByteArray([0xC1, 9, 0x17, 0x12, 0x34, 0, 0, 0x00, 0x07]))
	confere("C1 17: 0x1234 morto pelo 7", ultimo.get("morte", []) == [0x1234, 7] and ultimo.get("objeto_morreu", []) == [0x1234])
	var con := ConFalsa.new()
	cli.con = con
	cli.perguntar_evento(4, 3)
	cli.entrar_caos(3, 14)
	confere("sai C1 91 4 3", con.enviados[0] == PackedByteArray([0xC1, 5, 0x91, 4, 3]))
	confere("sai C1 AF 01 nivel 3 casa 14", con.enviados[1] == PackedByteArray([0xC1, 6, 0xAF, 0x01, 3, 14]))

	# contagem e janela do tempo
	var ev := Eventos.new()
	root.add_child(ev)
	await process_frame
	var estagios := []
	ev.estagio.connect(func(n): estagios.append(n))
	ev.contagem(10)
	var c10 := ev.texto_contagem()
	confere("contagem 10: " + c10, c10.begins_with("Chaos Castle Closing (in "))
	ev.contagem(11)
	var c11 := ev.texto_contagem()
	confere("contagem 11 vira o 828: " + c11, c11.begins_with("Chaos Castle Penetration (in "))
	ev.contagem(13)
	var c13 := ev.texto_contagem()
	confere("contagem 13: " + c13, c13.begins_with("Chaos Castle Event shuts down (in "))
	ev.caos = true
	ev.estado_castelo(5, 600, 100, 100)
	confere("estado 5: comecou, a janela espera o 6", not ev.mostra_tempo() and ev.bc_tipo == 6)
	ev.estado_castelo(6, 599, 100, 57)
	confere("estado 6: janela com 57/100", ev.mostra_tempo() and ev.bc_mortos == 57)
	confere("texto Character: " + DicaItem.t(1161, [57, 100]), DicaItem.t(1161, [57, 100]) == "Character: ( 57/100 )")
	ev.estado_castelo(8, 590, 100, 40)
	ev.estado_castelo(6, 590, 100, 40)
	confere("estado 8 encolhe (estagio 1) sem mexer na janela", estagios == [1] and ev.mostra_tempo())
	ev.queue_redraw()
	await process_frame
	ev.estado_castelo(7, 0, 100, 1)
	confere("estado 7: acabou", not ev.mostra_tempo() and ev.bc_tipo == 0)
	ev.caos = false
	ev.em_castelo = true
	ev.estado_castelo(6, 300, 100, 57)
	confere("estado 6 fora do Chaos Castle nao mostra", not ev.mostra_tempo())

	# resultado
	for ok in [true, false]:
		var c := CaixaPlacar.new("cc")
		c.bc = {"ok": ok, "exp": 150000, "monstros": 12, "jogadores": 1}
		root.add_child(c)
		await process_frame
		confere("resultado %s: 230 x 207 a 100 do alto, %d linhas de frase" % [ok, c._frase.size()],
			c.size == Vector2(230, 207) and is_equal_approx(c.position.y, 100.0 * c._esc) and c._frase.size() == (1 if ok else 2))
		c.queue_free()
	confere("textos: " + DicaItem.t(1162, [12]) + " / " + DicaItem.t(1163, [1]),
		DicaItem.t(1162, [12]) == "Monster Kill count: 12" and DicaItem.t(1163, [1]) == "Players Kill count: 1")

	# armas do castelo
	var dk := ChaosCastle.vestido_no_caos("classe_dk", {0: "0,5", 1: "6,2", 3: "8,1", 7: "12,5", 8: "13,4", "niveis": {0: 9, 3: 7}})
	confere("DK: Sword of Destruction nas duas maos, sem asa e sem pet, armadura fica",
		dk.get(0) == "0,16" and dk.get(1) == "0,16" and not dk.has(7) and not dk.has(8) and dk.get(3) == "8,1" and dk.niveis == {3: 7})
	var elf := ChaosCastle.vestido_no_caos("classe_elf", {0: "4,7", 1: "4,15"})
	confere("Elfa: Great Reign Crossbow na direita, esquerda vazia", elf.get(0) == "4,19" and not elf.has(1))
	var dw := ChaosCastle.vestido_no_caos("classe_dw", {})
	confere("DW: Legendary Staff", dw.get(0) == "5,5" and not dw.has(1))

	# mapa, buracos e aneis
	confere("castelos 18 a 23 e 53 usam a pasta mundo19", PacoteMapa.mundo_do_mapa(18) == 19 and PacoteMapa.mundo_do_mapa(23) == 19
		and PacoteMapa.mundo_do_mapa(53) == 19 and PacoteMapa.mundo_do_mapa(24) == 25)
	confere("mundo19 convertido", FileAccess.file_exists("res://dados/mundo19/objetos.json"))
	confere("mundo19 vai em pacote a parte no navegador", 19 in PacoteMapa.FORA)
	for n in ["ichaoscastle", "achaos", "achaosend", "parede_cai", "queda_grito"]:
		confere("som " + n, FileAccess.file_exists("res://dados/sons/%s.wav" % n))
	var m: Node3D = load("res://scripts/mundo.gd").new()
	m.atributos.resize(256 * 256)
	m.grade.region = Rect2i(0, 0, 256, 256)
	m.grade.update()
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string("res://dados/mundo19/objetos.json"))
	for o in lista:
		var n := Node3D.new()
		n.position = Vector3(o.p[0], o.p[1], o.p[2])
		m.add_child(n)
		m.nos_objetos.append([n, o])
	var cc := ChaosCastle.new()
	root.add_child(cc)
	cc.entrar(m, 21)
	var vis := func(tipos: Array) -> int:
		return m.nos_objetos.filter(func(par): return int(par[1].t) in tipos and par[0].visible).size()
	confere("ao entrar: anel de fora a mostra (%d), 18-21 e 24-35 escondidos" % vis.call(ChaosCastle.CAEM[1]),
		vis.call(ChaosCastle.CAEM[1]) > 0 and vis.call(ChaosCastle.ESCONDIDOS) == 0)
	confere("anda na borda (23,75) antes", m.anda(23, 75) and m.anda(44, 100))
	cc.encolher(1)
	confere("estagio 1: buraco em (23,75), (44,100) e (24,106); (25,77) segue chao",
		not m.anda(23, 75) and not m.anda(44, 100) and not m.anda(24, 106) and m.anda(25, 77) and m.grade.is_point_solid(Vector2i(23, 75)))
	confere("estagio 1: anel 30-35 apareceu (%d), o de fora caindo" % vis.call(ChaosCastle.APARECEM[1]),
		vis.call(ChaosCastle.APARECEM[1]) > 0 and cc.caindo())
	cc.encolher(1)
	confere("estado 8 repetido nao refaz", cc.estagio == 1)
	for i in 50:
		cc._process(0.04)
	confere("depois de 40 quadros o anel de fora sumiu", vis.call(ChaosCastle.CAEM[1]) == 0 and not cc.caindo())
	cc.encolher(3)
	confere("pulou pro 3: buracos do 2 e do 3 entram (25,77) e (27,79)", not m.anda(25, 77) and not m.anda(27, 79) and m.anda(29, 81))
	confere("estagio 3: 18-21 a mostra, anel 30-35 escondido", vis.call(ChaosCastle.APARECEM[3]) > 0 and vis.call(ChaosCastle.CAEM[2]) == 0)
	cc.queue_free()
	m.free()
	var mm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/monstros_mapa.json"))
	confere("guardas do castelo no pacote dos eventos", "monster71_sword17_sword17" in mm["0"] and "monster72_crossbow20" in mm["0"])
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
