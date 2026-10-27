class_name JanelaCastelo
extends Control
# Janelas do Castle Siege do S6, 190x429 na direita como o inventario (rodada 21):
# - Guardsman (CNewUIGuardWindow, NPC 224, janela 0x0D): o cliente pede o estado (C1 B2 00) e a inscricao da
#   guilda (B2 03). Abas Status (datas do periodo e da batalha, segundos que faltam), Announce ou Register
#   (o mestre inscreve a guilda no periodo de inscricao, B2 01; no periodo das marcas entrega o Sign of Lord,
#   B2 04) e List (C1 B4 guildas inscritas; no aviso e no preparo C1 B5 guildas da batalha). Abandon (B2 02)
#   so pro mestre inscrito, com a caixa de confirmar.
# - Senior (CNewUICastleWindow, NPC 223, janela 0x0C): abas Castle Gate e Guardian Statue (C1 B3 01 e 02: mapa
#   do castelo, botoes dos 6 portoes e das 4 estatuas, DUR/DP/RR, Buy, Repair e Improve, B2 05/06/07) e Tax
#   (B2 08: imposto da maquina do caos e das lojas, 0 a 3%, Apply manda B2 09; zen do castelo e Withdraw, B2 10).

signal pedir(sub: int, dados: PackedByteArray)     # C1 B2 sub
signal pedir_lista(cod: int, sub: int)              # C1 B3/B4/B5
signal pedir_npc(sub: int, numero: int, indice: int, tipo: int, valor: int)
signal confirmar(linhas: Array, feito: Callable)    # caixa de OK/Cancel do jogo
signal digitar(linhas: Array, feito: Callable)      # caixa com campo de numero
signal fechar
signal atirar(npc: int, area: int)                 # catapulta: C1 B7 01

const PASTA := "res://dados/hud/"
const L := 190.0
const A := 429.0
# CASTLESIEGE_STATE: 0 Idle1, 1 RegSiege, 2 Idle2, 3 RegMark, 4 Idle3, 5 Notify, 6 Ready, 7 Start, 8 End, 9 EndCycle
const REGSIEGE := 1
const REGMARK := 3
const NOTIFY := 5
const READY := 6
const START := 7
const PORTAO := 277
const ESTATUA := 283
const HP_PORTAO := [1900000, 2500000, 3500000, 5200000]
const DP_PORTAO := [100, 180, 300, 520]
const HP_ESTATUA := [1500000, 2200000, 3400000, 5000000]
const DP_ESTATUA := [80, 180, 340, 550]
# lugares dos botoes no mapa do castelo (RenderGateManagingTab e RenderStatueManagingTab, a partir de y + 73)
const LUGAR_PORTAO := [Vector2(82, 35), Vector2(64, 83), Vector2(100, 83), Vector2(48, 135), Vector2(82, 135), Vector2(116, 135)]
const LUGAR_ESTATUA := [Vector2(82, 20), Vector2(82, 65), Vector2(64, 110), Vector2(100, 110)]

var modo := "guarda"        # "guarda", "senior" ou "catapulta"
var catapulta_npc := -1     # C1 B7 00: o NPC da maquina e o tipo (1 ataque, 2 defesa)
var catapulta_tipo := 1
var area := -1              # botao escolhido na catapulta
var aba := 0
var estado := -1            # do C1 B2 00
var info := {}              # o C1 B2 00 inteiro
var inscrita := {}          # B2 03: guilda, marcas, ordem ("" sem inscricao)
var inscritas: Array = []   # C2 B4
var lados: Array = []       # C2 B5
var sou_mestre := false
var minha_guilda := ""
var minha_alianca := ""
var marcas_na_mochila := 0  # Sign of Lord (14,21 nivel 3) somado
var slot_marca := -1
var portoes: Array = []     # C2 B3 01, na ordem do indice
var estatuas: Array = []    # C2 B3 02
var escolhido := [0, 0]     # portao e estatua escolhidos
var taxa_caos := 0          # o que o senhor vai aplicar
var taxa_loja := 0
var taxa_caos_real := 0     # o que vale agora (B2 08)
var taxa_loja_real := 0
var tesouro := 0
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _desde := 0.0


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo01", "inv_esq", "inv_dir", "inv_baixo", "inv_sair"]:
		_tex[n] = load(PASTA + n + ".png")
	for n in ["aba", "botao", "mapa", "portao", "portao_sel", "estatua", "estatua_sel", "zen", "linha", "tabela_c",
			"tabela_b", "tabela_e", "tabela_d", "tabela_ce", "tabela_cd", "tabela_be", "tabela_bd", "cat_portao",
			"cat_area", "botao_grande"]:
		_tex[n] = load(PASTA + "castelo/" + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


func _ajustar() -> void:
	var v := get_viewport_rect().size
	var barra := 51.0 * v.x / 640.0
	_esc = minf(v.x / 640.0, (v.y - barra) / A)
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2(v.x - L * _esc, 0)
	queue_redraw()


# --- abrir e dados do servidor ----------------------------------------------------

# OpeningProcess do Guardsman: a janela so aparece com a resposta do B2 00 (resultado 1 ou 2)
func abrir_guarda(i: Dictionary) -> void:
	modo = "guarda"
	info = i
	estado = int(i.estado)
	aba = 0
	inscritas = []
	lados = []
	visible = true
	pedir.emit(0x03, PackedByteArray())
	print("TESTE castelo guarda estado %d guilda '%s' faltam %d s" % [estado, i.guilda, i.segundos])
	queue_redraw()


func abrir_senior() -> void:
	modo = "senior"
	aba = 0
	visible = true
	pedir_lista.emit(0xB3, 0x01)
	pedir_lista.emit(0xB3, 0x02)
	pedir.emit(0x08, PackedByteArray())
	print("TESTE castelo senior")
	queue_redraw()


func registro(d: Dictionary) -> void:
	inscrita = d if int(d.resultado) == 1 else {}
	print("TESTE castelo inscricao '%s' marcas %d ordem %d" % [inscrita.get("guilda", ""), inscrita.get("marcas", 0), inscrita.get("ordem", 0)])
	queue_redraw()


func lista_inscritas(l: Array) -> void:
	inscritas = l
	inscritas.sort_custom(func(a, b): return a.marcas > b.marcas)
	print("TESTE castelo inscritas %s" % [l.map(func(g): return "%s:%d" % [g.guilda, g.marcas])])
	queue_redraw()


func lista_lados(l: Array) -> void:
	lados = l
	print("TESTE castelo lados %s" % [l.map(func(g): return "%s:%d" % [g.guilda, g.lado])])
	queue_redraw()


func npcs(l: Array) -> void:
	if l.is_empty():
		return
	l.sort_custom(func(a, b): return a.indice < b.indice)
	if int(l[0].numero) == PORTAO:
		portoes = l
	else:
		estatuas = l
	print("TESTE castelo npcs %d: %s" % [int(l[0].numero), l.map(func(n): return "%d:%s" % [n.indice, "vivo" if n.vivo else "nao"])])
	queue_redraw()


func impostos(d: Dictionary) -> void:
	taxa_caos_real = d.caos
	taxa_loja_real = d.loja
	taxa_caos = d.caos
	taxa_loja = d.loja
	tesouro = d.tesouro
	print("TESTE castelo impostos caos %d loja %d tesouro %d" % [d.caos, d.loja, d.tesouro])
	queue_redraw()


# cada NPC da lista com a vida e o nivel novos (B2 05/06/07 bem sucedidos)
func npc_mudou(sub: int, d: Dictionary) -> void:
	for n in portoes + estatuas:
		if int(n.numero) == int(d.numero) and int(n.indice) == int(d.indice):
			if sub == 0x05:
				n.vivo = true
			elif sub == 0x06:
				n.vida = d.vida
				n.vida_max = d.vida_max
			elif sub == 0x07:
				match int(d.tipo):
					1: n.defesa = d.valor
					2: n.regen = d.valor
					3:
						n.vida_max = d.valor
						n.vida = d.valor
	queue_redraw()


# --- textos dos periodos ----------------------------------------------------------

static func nome_periodo(e: int) -> String:
	if e < 0 or e > 9:
		return DicaItem.t(1535)
	return DicaItem.t(1535 + e)


func _data(d: Array) -> Array:
	return [d[0], d[1], d[2], d[3], d[4]]


func _ha_inscricao() -> bool:
	return str(inscrita.get("guilda", "")) != ""


# a guilda do castelo e a minha (ou a da minha alianca)
func _sou_do_castelo() -> bool:
	var dono := str(info.get("guilda", ""))
	return dono != "" and (dono == minha_guilda or dono == minha_alianca)


# CNewUICatapultWindow: abre com o C1 B7 00 resultado 1, sem abas
func abrir_catapulta(npc: int, tipo: int) -> void:
	modo = "catapulta"
	catapulta_npc = npc
	catapulta_tipo = tipo
	area = -1
	visible = true
	print("TESTE castelo catapulta npc %d tipo %d" % [npc, tipo])
	queue_redraw()


# --- desenho ----------------------------------------------------------------------

func _sair() -> Rect2:
	return Rect2(13, 391, 36, 29)


func _aba_r(i: int) -> Rect2:
	if modo == "guarda":
		return Rect2(12 + i * 56, 84, 56, 22)
	return Rect2(12 + i * 55, 32, 55, 22)


func _btn_centro(y: float) -> Rect2:
	return Rect2(L / 2 - 27, y, 53, 23)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo01, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var s := _sair()
	draw_texture_rect_region(_tex.inv_sair, s, Rect2(0, 29 * (1 if s.has_point(_mouse) else 0), 36, 29))
	if modo == "guarda":
		_desenhar_guarda()
	elif modo == "catapulta":
		_desenhar_catapulta()
	else:
		_desenhar_senior()


func _abas(nomes: Array) -> void:
	for i in nomes.size():
		var r := _aba_r(i)
		draw_texture_rect_region(_tex.aba, r, Rect2(0, 22 if i == aba else 0, 56, 22))
		_texto(Vector2(r.position.x, r.position.y + 15), nomes[i], r.size.x, Color.WHITE if i == aba else Color(0.7, 0.7, 0.7))


func _desenhar_guarda() -> void:
	_texto(Vector2(15, 13 + 8), DicaItem.t(1445), 160, Color8(220, 220, 220), true)
	var nada := DicaItem.t(1361)
	var mestre := str(info.get("mestre", ""))
	var dono := str(info.get("guilda", ""))
	_texto(Vector2(0, 50 + 8), DicaItem.t(1446, [mestre if mestre != "" else nada]), L, Color.WHITE, true)
	_texto(Vector2(0, 65 + 8), DicaItem.t(1447, [dono if dono != "" else nada]), L, Color.WHITE, true)
	_abas([DicaItem.t(1448), DicaItem.t(1435 if estado == REGSIEGE else 1439), DicaItem.t(1449)])
	match aba:
		0: _aba_status()
		1: _aba_inscrever()
		2: _aba_lista()


func _linha(y: float, t: String, cor := Color.WHITE, negrito := false) -> void:
	_texto(Vector2(0, y + 8), t, L, cor, negrito)


func _aba_status() -> void:
	var y := 125.0
	_linha(y, DicaItem.t(1533, _data(info.inicio)))
	y += 14
	_linha(y, DicaItem.t(1534, _data(info.fim)))
	y += 14
	_linha(y, nome_periodo(estado))
	if estado < START:
		y += 35
		_linha(y, DicaItem.t(1545))
		y += 14
		_linha(y, DicaItem.t(1546, _data(info.batalha)))
		y += 35
		var seg := int(info.segundos)
		_linha(y, DicaItem.t(1421, [seg / 3600, (seg % 3600) / 60, (seg % 3600) % 60]))


func _aba_inscrever() -> void:
	var y := 125.0
	match estado:
		REGSIEGE:
			if not sou_mestre:
				_linha(y, DicaItem.t(1429))   # NotAGuildMaster: o S6 mostra "You have no ability"
			elif _ha_inscricao():
				_linha(y, DicaItem.t(1547))
			else:
				_botao(_btn_centro(120), DicaItem.t(1435), not _sou_do_castelo())
		REGMARK:
			if _ha_inscricao():
				_linha(y, DicaItem.t(1436))
				y += 30
				_linha(y, DicaItem.t(1437, [marcas_na_mochila]))
				y += 14
				_linha(y, DicaItem.t(1438, [int(inscrita.marcas)]))
				_botao(_btn_centro(200), DicaItem.t(1439), marcas_na_mochila > 0)
			else:
				_linha(y, DicaItem.t(1514))
		4:
			_linha(y, DicaItem.t(1440), Color.WHITE, true)
			_linha(y + 14, DicaItem.t(1441), Color.WHITE, true)
		0, 2, 5, 6, 7, 8, 9:
			_linha(y, nome_periodo(estado), Color.WHITE, estado == 8)
		_:
			_linha(y, DicaItem.t(1535))


func _caixa_tabela(x: float, y: float, w: float, h: float) -> void:
	draw_rect(Rect2(x - 1, y - 1, w + 1, h + 2), Color(0, 0, 0, 0.4))
	draw_texture_rect(_tex.tabela_c, Rect2(x - 1, y - 14, w + 2, 14), false)
	draw_texture_rect(_tex.tabela_b, Rect2(x - 1, y + h, w + 2, 14), false)
	draw_texture_rect(_tex.tabela_e, Rect2(x - 4, y - 14, 14, h + 28), false)
	draw_texture_rect(_tex.tabela_d, Rect2(x + w - 9, y - 14, 14, h + 28), false)


func _aba_lista() -> void:
	var x := 15.0
	var f := 0.0
	if estado == REGSIEGE or estado == REGMARK:
		# CUIBCDeclareGuildListBox: 160 x 235 com o fundo em 129; Name, No. Reg., Stat, Order
		var topo := 129.0
		_caixa_tabela(x, topo, 160, 235)
		_texto(Vector2(x + 5, topo - 12 + 8), DicaItem.t(182), 0, Color.WHITE)
		_texto(Vector2(x + 50, topo - 12 + 8), DicaItem.t(1528), 0, Color.WHITE)
		_texto(Vector2(x + 98, topo - 12 + 8), DicaItem.t(1529), 0, Color.WHITE)
		_texto(Vector2(x + 123, topo - 12 + 8), DicaItem.t(1530), 0, Color.WHITE)
		var i := 0
		for g in inscritas:
			var y := topo + 3 + i * 13
			if y > topo + 230:
				break
			var minha: bool = g.guilda == minha_guilda or g.guilda == minha_alianca
			var cor := Color8(230, 220, 200) if minha else Color(0.6, 0.6, 0.6)
			_texto(Vector2(x + 6, y + 9), g.guilda, 0, cor)
			_texto(Vector2(x + 74 - 30, y + 9), str(g.marcas), 30, cor, false, HORIZONTAL_ALIGNMENT_RIGHT)
			_texto(Vector2(x + 124 - 30, y + 9), DicaItem.t(1531) if g.desistiu else DicaItem.t(1532), 30, cor, false, HORIZONTAL_ALIGNMENT_RIGHT)
			_texto(Vector2(x + 144 - 20, y + 9), str(g.ordem), 20, cor, false, HORIZONTAL_ALIGNMENT_RIGHT)
			i += 1
		if _ha_inscricao() and sou_mestre:
			_botao(_btn_centro(370), DicaItem.t(1549), true)
	elif estado == NOTIFY or estado == READY:
		# CUIBCGuildListBox: 160 x 195 com o fundo em 129; Name, Camp, Maintain
		var topo := 129.0
		_caixa_tabela(x, topo, 160, 195)
		_texto(Vector2(x + 5, topo - 12 + 8), DicaItem.t(182), 0, Color.WHITE)
		_texto(Vector2(x + 80, topo - 12 + 8), DicaItem.t(1603), 0, Color.WHITE)
		_texto(Vector2(x + 120, topo - 12 + 8), DicaItem.t(1604), 0, Color.WHITE)
		var i := 0
		for g in lados:
			var y := topo + 3 + i * 13
			if y > topo + 190:
				break
			var cor := Color8(230, 220, 200)
			_texto(Vector2(x + 6, y + 9), g.guilda, 0, cor)
			_texto(Vector2(x + 104 - 60, y + 9), DicaItem.t(1606 if g.lado == 1 else 1605), 60, cor, false, HORIZONTAL_ALIGNMENT_RIGHT)
			_texto(Vector2(x + 148 - 40, y + 9), DicaItem.t(1607 if g.envolvida else 1608), 40, cor, false, HORIZONTAL_ALIGNMENT_RIGHT)
			i += 1
		if lados.is_empty():
			_texto(Vector2(x, topo + 90), DicaItem.t(1609), 160, Color(0.8, 0.8, 0.8))
	else:
		f = 125
		_linha(f, nome_periodo(estado), Color.WHITE, true)


# --- Senior -----------------------------------------------------------------------

func _desenhar_senior() -> void:
	_texto(Vector2(15, 13 + 8), DicaItem.t(1588), 160, Color8(220, 220, 220), true)
	_abas([DicaItem.t(1589), DicaItem.t(1590), DicaItem.t(1591)])
	match aba:
		0, 1: _aba_npcs(aba == 0)
		2: _aba_imposto()


func _contorno(y: float, w: float, h: float, titulo: String) -> void:
	# RenderOutlineUpper/Lower: cantos de 14 e bordas da tabela 01/02/03
	var x := 0.0
	draw_rect(Rect2(x + 15, y - 3, w - 2, 15), Color(0, 0, 0, 0.3))
	draw_texture_rect(_tex.tabela_ce, Rect2(x + 12, y - 4, 14, 14), false)
	draw_texture_rect(_tex.tabela_cd, Rect2(x + w + 4, y - 4, 14, 14), false)
	draw_texture_rect(_tex.tabela_c, Rect2(x + 25, y - 4, w - 21, 14), false)
	draw_texture_rect(_tex.tabela_e, Rect2(x + 12, y + 9, 14, h), false)
	draw_texture_rect(_tex.tabela_d, Rect2(x + w + 4, y + 9, 14, h), false)
	draw_texture_rect(_tex.tabela_b, Rect2(x + 15, y + 3, w - 2, 14), false)
	draw_texture_rect(_tex.tabela_be, Rect2(x + 12, y + h + 3, 14, 14), false)
	draw_texture_rect(_tex.tabela_bd, Rect2(x + w + 4, y + h + 3, 14, 14), false)
	draw_texture_rect(_tex.tabela_b, Rect2(x + 25, y + h + 3, w - 21, 14), false)
	_texto(Vector2(0, y + 8), titulo, L, Color.WHITE, true)


func _npc_atual(portao: bool) -> Dictionary:
	var l := portoes if portao else estatuas
	var i: int = escolhido[0 if portao else 1]
	return l[i] if i < l.size() else {}


func _lugar(portao: bool, i: int) -> Rect2:
	var p: Vector2 = (LUGAR_PORTAO if portao else LUGAR_ESTATUA)[i]
	return Rect2(p + Vector2(0, 73), Vector2(24, 24))


func _nivel_hp(n: Dictionary) -> int:
	var t: Array = HP_PORTAO if int(n.numero) == PORTAO else HP_ESTATUA
	for i in 3:
		if int(n.vida_max) <= t[i]:
			return i
	return 3


func _aba_npcs(portao: bool) -> void:
	var y := 61.0
	_contorno(y, 160, 165, DicaItem.t(1557))
	draw_texture_rect(_tex.mapa, Rect2(15, y + 12, 160, 165), false)
	var l := portoes if portao else estatuas
	for i in mini(l.size(), (LUGAR_PORTAO if portao else LUGAR_ESTATUA).size()):
		var r := _lugar(portao, i)
		var n: Dictionary = l[i]
		if n.vivo:
			# RenderCastleItem: barra da vida (branca, vermelha pelo resto) e da defesa (verde) em cima do botao
			var bloco := 24 / 4
			var hp := _nivel_hp(n)
			var frac := float(n.vida) / maxf(1.0, float(n.vida_max))
			draw_rect(Rect2(r.position.x, r.position.y - 10, bloco * (hp + 1), 3), Color.WHITE)
			draw_rect(Rect2(r.position.x, r.position.y - 5, 24, 3), Color.WHITE)
			draw_rect(Rect2(r.position.x, r.position.y - 10, bloco * (hp + 1) * frac, 3), Color.RED)
			draw_rect(Rect2(r.position.x, r.position.y - 5, bloco * (int(n.defesa) + 1), 3), Color.GREEN)
		var sel: bool = i == escolhido[0 if portao else 1]
		var nome := ("portao" if portao else "estatua") + ("_sel" if sel else "")
		draw_texture_rect(_tex[nome], r, false, Color.WHITE if n.vivo else Color(0.45, 0.45, 0.45))
	var n := _npc_atual(portao)
	if n.is_empty():
		return
	y += 173
	if not n.vivo:
		_botao(_btn_centro(250), DicaItem.t(1558), true)
		return
	var dp: Array = DP_PORTAO if portao else DP_ESTATUA
	_texto(Vector2(20, y + 8), DicaItem.t(1560, [n.vida, n.vida_max]), 0, Color.WHITE)
	y += 13
	_texto(Vector2(20, y + 8), DicaItem.t(1561, [dp[clampi(int(n.defesa), 0, 3)]]), 0, Color.WHITE)
	if not portao:
		y += 13
		_texto(Vector2(20, y + 8), DicaItem.t(1562, [int(n.regen)]), 0, Color.WHITE)
	_botao(Rect2(110, 260, 53, 23), DicaItem.t(1559), int(n.vida) < int(n.vida_max))
	y += 35 if portao else 22
	_contorno(y, 160, 78, DicaItem.t(1550))
	var hp_t: Array = HP_PORTAO if portao else HP_ESTATUA
	var nivel := _nivel_hp(n)
	var mais_hp: int = hp_t[nivel + 1] - hp_t[nivel] if nivel < 3 else 0
	var mais_dp: int = dp[int(n.defesa) + 1] - dp[int(n.defesa)] if int(n.defesa) < 3 else 0
	_texto(Vector2(30, y + 24 + 8), DicaItem.t(1563, [mais_hp]), 0, Color.WHITE)
	_botao(Rect2(110, 310, 53, 23), DicaItem.t(1550), mais_hp > 0)
	_texto(Vector2(30, y + 47 + 8), DicaItem.t(1564, [mais_dp]), 0, Color.WHITE)
	_botao(Rect2(110, 334, 53, 23), DicaItem.t(1550), mais_dp > 0)
	if not portao:
		_texto(Vector2(30, y + 70 + 8), DicaItem.t(1565, [1 if int(n.regen) < 3 else 0]), 0, Color.WHITE)
		_botao(Rect2(110, 358, 53, 23), DicaItem.t(1550), int(n.regen) < 3)


func _aba_imposto() -> void:
	var y := 61.0
	draw_rect(Rect2(15, y + 14, 150, 24), Color8(102, 102, 102, 128))
	draw_rect(Rect2(15, y + 42, 150, 24), Color8(102, 102, 102, 128))
	_contorno(y, 160, 55, DicaItem.t(1572))
	for i in 4:
		var r := _seta(i)
		draw_rect(r, Color(0.25, 0.22, 0.18))
		var c := r.get_center()
		var d := -3.0 if i % 2 == 0 else 3.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -d), c + Vector2(4, -d), c + Vector2(0, d)]),
			Color(1, 0.9, 0.6) if r.has_point(_mouse) else Color(0.85, 0.8, 0.7))
	y += 23
	_texto(Vector2(8, y + 8), DicaItem.t(1573, [taxa_caos_real, taxa_caos]), 148, Color.WHITE)
	y += 25
	_texto(Vector2(8, y + 8), DicaItem.t(1574, [taxa_loja_real, taxa_loja]), 148, Color.WHITE)
	_botao(Rect2(120, 133, 53, 23), DicaItem.t(1106), _sou_do_castelo() and sou_mestre)
	y += 53
	for t in [1575, 1576, 1577]:
		_texto(Vector2(15, y + 8), DicaItem.t(t), 160, Color.WHITE)
		y += 13
	y += 7
	for t in [1578, 1579, 1580, 1581, 1582, 1583]:
		_texto(Vector2(15, y + 8), DicaItem.t(t).replace("%%", "%"), 160, Color.WHITE)
		y += 12
	y -= 2
	draw_texture_rect(_tex.linha, Rect2(1, y, 188, 21), false)
	y += 18
	draw_texture_rect(_tex.zen, Rect2(10, y, 170, 24), false)
	_texto(Vector2(14, y + 7 + 8), DicaItem.t(224), 0, Color.WHITE)
	_texto(Vector2(90, y + 7 + 8), DicaItem._milhar(tesouro), 80, Color.WHITE, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_botao(Rect2(120, 322, 53, 23), DicaItem.t(236), _sou_do_castelo() and sou_mestre)
	y += 54
	for t in [1585, 1586, 1587]:
		_texto(Vector2(15, y + 8), DicaItem.t(t), 160, Color.WHITE)
		y += 12


# setas de subir e descer o imposto (15 x 13): caos em 73 e 86, lojas em 101 e 114
func _seta(i: int) -> Rect2:
	return Rect2(158, [73, 86, 101, 114][i], 15, 13)


func _botao(r: Rect2, txt: String, ativo: bool) -> void:
	var linha := 0
	if ativo and r.has_point(_mouse):
		linha = 1
	draw_texture_rect_region(_tex.botao, r, Rect2(0, 23 * linha, 53, 23), Color.WHITE if ativo else Color(0.4, 0.4, 0.4))
	_texto(Vector2(r.position.x, r.position.y + 15), txt, r.size.x, Color.WHITE if ativo else Color(0.4, 0.4, 0.4))


func _texto(p: Vector2, t: String, largura: float, cor: Color, negrito := false, al := -1) -> void:
	var f := get_theme_default_font()
	var alinha: int = al if al >= 0 else (HORIZONTAL_ALIGNMENT_CENTER if largura > 0 else HORIZONTAL_ALIGNMENT_LEFT)
	var w := largura if largura > 0 else -1.0
	# o que nao cabe na largura desce a letra ate 7 (a fonte do original e menor que a nossa)
	var tam := 10
	while largura > 0 and tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura:
		tam -= 1
	var larg := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	if largura > 0 and larg > largura:
		# nem com 7 coube: aperta so na horizontal, como a fonte estreita do original
		var k := largura / larg
		draw_set_transform(Vector2(p.x * (1.0 - k), 0), 0.0, Vector2(k, 1))
		draw_string_outline(f, p, t, alinha, w / k, tam, 3 if negrito else 2, Color(0, 0, 0, 0.9))
		draw_string(f, p, t, alinha, w / k, tam, cor)
		draw_set_transform(Vector2.ZERO)
		return
	draw_string_outline(f, p, t, alinha, w, tam, 3 if negrito else 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, alinha, w, tam, cor)


# --- mouse ------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicar(ev.position)
		accept_event()


func _process(d: float) -> void:
	if not visible or modo != "guarda" or info.is_empty():
		return
	# o relogio da aba Status anda sozinho (m_dwStateLeftSec)
	_desde += d
	if _desde >= 1.0:
		_desde -= 1.0
		info.segundos = maxi(0, int(info.segundos) - 1)
		if aba == 0:
			queue_redraw()


func clicar(p: Vector2) -> void:
	if _sair().has_point(p):
		fechar.emit()
		return
	if modo == "catapulta":
		_clicar_catapulta(p)
		return
	var n_abas := 3
	for i in n_abas:
		if _aba_r(i).has_point(p):
			_mudar_aba(i)
			return
	if modo == "guarda":
		_clicar_guarda(p)
	else:
		_clicar_senior(p)


func _mudar_aba(i: int) -> void:
	aba = i
	if modo == "guarda" and i == 2:
		if estado == REGSIEGE or estado == REGMARK:
			pedir_lista.emit(0xB4, -1)
		elif estado == NOTIFY or estado == READY:
			pedir_lista.emit(0xB5, -1)
	print("TESTE castelo aba %d" % i)
	queue_redraw()


func _clicar_guarda(p: Vector2) -> void:
	if aba == 1 and estado == REGSIEGE and sou_mestre and not _ha_inscricao() and not _sou_do_castelo() \
			and _btn_centro(120).has_point(p):
		print("TESTE castelo inscrever")
		pedir.emit(0x01, PackedByteArray())
	elif aba == 1 and estado == REGMARK and _ha_inscricao() and marcas_na_mochila > 0 and slot_marca >= 0 \
			and _btn_centro(200).has_point(p):
		# o servidor soma os 12 lugares do equipamento, como no cliente original
		print("TESTE castelo entregar marca slot %d" % slot_marca)
		pedir.emit(0x04, PackedByteArray([slot_marca - 12]))
	elif aba == 2 and (estado == REGSIEGE or estado == REGMARK) and _ha_inscricao() and sou_mestre \
			and _btn_centro(370).has_point(p):
		# CSiegeGiveUpMsgBoxLayout
		confirmar.emit([DicaItem.t(1549) + "?"], func():
			print("TESTE castelo desistir")
			pedir.emit(0x02, PackedByteArray([1])))


func _clicar_senior(p: Vector2) -> void:
	if aba <= 1:
		var portao := aba == 0
		var l := portoes if portao else estatuas
		for i in mini(l.size(), (LUGAR_PORTAO if portao else LUGAR_ESTATUA).size()):
			if _lugar(portao, i).has_point(p):
				escolhido[0 if portao else 1] = i
				print("TESTE castelo escolhido %s %d" % ["portao" if portao else "estatua", i])
				queue_redraw()
				return
		var n := _npc_atual(portao)
		if n.is_empty():
			return
		if not n.vivo and _btn_centro(250).has_point(p):
			var custo := 0
			confirmar.emit([DicaItem.t(1551 if portao else 1610), DicaItem.t(1617, [custo]), DicaItem.t(1612)],
				func(): pedir_npc.emit(0x05, int(n.numero), int(n.indice), -1, 0))
		elif n.vivo and Rect2(110, 260, 53, 23).has_point(p) and int(n.vida) < int(n.vida_max):
			var custo := (int(n.vida_max) - int(n.vida)) * (5 if portao else 3) + int(n.defesa) * 1000000
			confirmar.emit([DicaItem.t(1552 if portao else 1611), DicaItem.t(1617, [custo]), DicaItem.t(1554)],
				func(): pedir_npc.emit(0x06, int(n.numero), int(n.indice), -1, 0))
		elif n.vivo and Rect2(110, 310, 53, 23).has_point(p) and _nivel_hp(n) < 3:
			var hp_t: Array = HP_PORTAO if portao else HP_ESTATUA
			var joias: int = [2, 3, 4][_nivel_hp(n)] if portao else [3, 5, 7][_nivel_hp(n)]
			confirmar.emit([DicaItem.t(1555 if portao else 1613), DicaItem.t(1553, [joias, 1000000]), DicaItem.t(1554)],
				func(): pedir_npc.emit(0x07, int(n.numero), int(n.indice), 3, hp_t[_nivel_hp(n) + 1]))
		elif n.vivo and Rect2(110, 334, 53, 23).has_point(p) and int(n.defesa) < 3:
			var joias: int = [2, 3, 4][int(n.defesa)] if portao else [3, 5, 7][int(n.defesa)]
			confirmar.emit([DicaItem.t(1556 if portao else 1614), DicaItem.t(1553, [joias, 3000000]), DicaItem.t(1554)],
				func(): pedir_npc.emit(0x07, int(n.numero), int(n.indice), 1, int(n.defesa) + 1))
		elif not portao and n.vivo and Rect2(110, 358, 53, 23).has_point(p) and int(n.regen) < 3:
			var joias: int = [3, 5, 7][int(n.regen)]
			confirmar.emit([DicaItem.t(1615), DicaItem.t(1553, [joias, 5000000]), DicaItem.t(1554)],
				func(): pedir_npc.emit(0x07, int(n.numero), int(n.indice), 2, int(n.regen) + 1))
		return
	# Tax: as setas mudam o que vai ser aplicado (0 a 3), Apply manda os dois, Withdraw pede o valor
	for i in 4:
		if _seta(i).has_point(p):
			if i < 2:
				taxa_caos = clampi(taxa_caos + (1 if i == 0 else -1), 0, 3)
			else:
				taxa_loja = clampi(taxa_loja + (1 if i == 2 else -1), 0, 3)
			queue_redraw()
			return
	if Rect2(120, 133, 53, 23).has_point(p) and _sou_do_castelo() and sou_mestre:
		confirmar.emit([DicaItem.t(1566, [taxa_caos]).replace("%%", "%"), DicaItem.t(1567, [taxa_loja]).replace("%%", "%"),
				DicaItem.t(1568)], func():
			var a := PackedByteArray([1])
			a.append_array(_be4_local(taxa_caos))
			pedir.emit(0x09, a)
			var b := PackedByteArray([2])
			b.append_array(_be4_local(taxa_loja))
			pedir.emit(0x09, b))
	elif Rect2(120, 322, 53, 23).has_point(p) and _sou_do_castelo() and sou_mestre:
		digitar.emit([DicaItem.t(1571)], func(valor: int):
			pedir.emit(0x10, _be4_local(valor)))


static func _be4_local(v: int) -> PackedByteArray:
	return PackedByteArray([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF])


# --- catapulta (rodada 22) ------------------------------------------------------

# botoes do original: ataque = 3 portoes (46x36) e o patio (77x47); defesa = 2 patios e a ponte
func _areas() -> Array:
	if catapulta_tipo == 1:
		return [[Rect2(22, 135, 46, 36), 1402, "cat_portao"], [Rect2(74, 135, 46, 36), 1403, "cat_portao"],
			[Rect2(126, 135, 46, 36), 1404, "cat_portao"], [Rect2(59, 182, 77, 47), 1405, "cat_area"]]
	return [[Rect2(18, 125, 77, 47), 1406, "cat_area"], [Rect2(97, 125, 77, 47), 1407, "cat_area"],
		[Rect2(56, 179, 77, 47), 1408, "cat_area"]]


func _atirar_r() -> Rect2:
	return Rect2(41, 250, 108, 29)


func _desenhar_catapulta() -> void:
	_texto(Vector2(0, 13 + 8), DicaItem.t(1400 if catapulta_tipo == 1 else 1401), L, Color8(220, 220, 220), true)
	_linha(50, DicaItem.t(1409))
	_linha(65, DicaItem.t(1410))
	_linha(80, DicaItem.t(1411))
	_caixa_tabela(14, 120, 162, 125)
	var lista := _areas()
	for i in lista.size():
		var r: Rect2 = lista[i][0]
		var tex: Texture2D = _tex[lista[i][2]]
		var h := r.size.y
		var linha := 0
		if i == area:
			linha = 2
		elif r.has_point(_mouse):
			linha = 1
		var cor := Color(0.4, 0.4, 0.4) if i == area else Color.WHITE
		draw_texture_rect_region(tex, r, Rect2(0, h * linha, r.size.x, h), cor)
		_texto(Vector2(r.position.x, r.position.y + h / 2 + 4), DicaItem.t(lista[i][1]), r.size.x, cor)
	var a := _atirar_r()
	var pode := area >= 0
	var la := 1 if pode and a.has_point(_mouse) else 0
	draw_texture_rect_region(_tex.botao_grande, a, Rect2(0, 29 * la, 108, 29), Color.WHITE if pode else Color(0.4, 0.4, 0.4))
	_texto(Vector2(a.position.x, a.position.y + 19), DicaItem.t(1499), a.size.x, Color.WHITE if pode else Color(0.4, 0.4, 0.4), true)


func _clicar_catapulta(p: Vector2) -> void:
	var lista := _areas()
	for i in lista.size():
		if (lista[i][0] as Rect2).has_point(p):
			area = i
			print("TESTE castelo catapulta area %d" % (i + 1))
			queue_redraw()
			return
	if area >= 0 and _atirar_r().has_point(p):
		print("TESTE castelo catapulta atira npc %d area %d" % [catapulta_npc, area + 1])
		atirar.emit(catapulta_npc, area + 1)
		fechar.emit()
