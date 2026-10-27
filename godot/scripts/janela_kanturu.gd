class_name JanelaKanturu
extends Control
# Entrada da Torre do Kanturu pelo Gateway Machine (367, Kanturu 2; CNewUIKanturu2ndEnterNpc): a caixa de
# mensagem do S6 com 10 meios (230x267), em (640/2 - 115, 20). O assunto em negrito laranja, quebrado a 52
# letras, e ate 3 frases do estado (a primeira verde, as outras amarelo claro), cada uma quebrada a 52.
# Refresh (17), Enter (87) e Close (157) em 220, 53x23. O servidor responde a fala com o C1 D1 00; com a
# janela aberta o cliente pede de novo a cada 5 s (KANTURU2ND_REFRESH_GAPTIME) e o Refresh trava por 3 s.
# Enter so com o botao aceso; fora da torre aberta o cliente confere antes o equipamento (Uniria, anel de
# transformacao, asa ou montaria que voa, Moonstone Pendant) e recusa com a caixa do original.

signal entrar
signal fechar
signal atualizar

const L := 230.0
const A := 267.0
const PASTA := "res://dados/hud/"
const ESTADO_ESPERA := 1
const ESTADO_MAYA := 2
const ESTADO_NIGHTMARE := 3
const ESTADO_TORRE := 4

var estado := 0
var pode := false
var assunto := ""
var frases: Array[String] = []
var refresh_travado := false
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _desde_pedido := 0.0
var _desde_refresh := 0.0


func _ready() -> void:
	for n in ["msg_topo", "msg_meio", "msg_baixo"]:
		_tex[n] = load(PASTA + n + ".png")
	_tex.fundo = load(PASTA + "kanturu/msg_fundo.png")
	_tex.btn_mini = load(PASTA + "templo/btn_mini.png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2((320 - L / 2) * _esc, 20 * _esc)
	queue_redraw()


# ReceiveKanturu3rdInfo: monta o assunto e as frases pelo estado e pelo detalhe, acende ou apaga o Enter
func info(estado_: int, detalhe: int, pode_: bool, gente: int, segundos: int) -> void:
	estado = estado_
	pode = pode_
	frases.clear()
	assunto = ""
	match estado:
		ESTADO_TORRE:
			if detalhe in [1, 2]:   # KANTURU_TOWER_REVITALIXATION, NOTIFY
				assunto = DicaItem.t(2149)
				frases = [DicaItem.t(2150), DicaItem.t(2151, [segundos / 3600])]
			else:
				assunto = DicaItem.t(2174)
				frases = [DicaItem.t(2160), DicaItem.t(2161)]
		ESTADO_MAYA:
			_frases_maya(detalhe, gente)
		ESTADO_NIGHTMARE:
			assunto = DicaItem.t(2152)
			frases = [DicaItem.t(2153, [gente]), DicaItem.t(2157, [gente])]
		ESTADO_ESPERA:
			assunto = DicaItem.t(2158)
			frases = [DicaItem.t(2159, [segundos / 60]) if detalhe == 1 else DicaItem.t(2162), DicaItem.t(2160), DicaItem.t(2161)]
		_:
			assunto = DicaItem.t(2170)
	print("TESTE kanturu info estado %d detalhe %d pode %s gente %d: %s" % [estado, detalhe, pode, gente, assunto])
	_desde_pedido = 0.0
	visible = true
	queue_redraw()


func _frases_maya(detalhe: int, gente: int) -> void:
	var f0 := ""
	var f1 := ""
	var n := 0
	if detalhe not in [1, 7, 12]:   # fora das 3 esperas (STANBY1 a 3)
		assunto = DicaItem.t(2152)
		f0 = DicaItem.t(2153, [gente])
	else:
		assunto = DicaItem.t(2163)
		if detalhe == 1:
			f0 = DicaItem.t(2164) if gente < 15 or (gente > 15 and pode) else DicaItem.t(2172)
			n = 1
		else:
			var esq := detalhe == 7
			if gente < 15:
				f0 = DicaItem.t(2165 if esq else 2166, [gente])
				f1 = DicaItem.t(2167, [15 - gente])
				n = 2
			elif gente == 15:
				f0 = DicaItem.t(2168)
				n = 1
	# a luta em curso troca a segunda frase: mao esquerda, direita ou as duas
	if detalhe in [2, 3, 4, 5, 6]:
		f1 = DicaItem.t(2154, [gente])
		n = 2
	elif detalhe in [8, 9, 10, 11]:
		f1 = DicaItem.t(2155, [gente])
		n = 2
	elif detalhe in [13, 14, 15, 16]:
		f1 = DicaItem.t(2156, [gente])
		n = 2
	elif detalhe in [0, 17, 18]:
		n = 1
	if detalhe not in [1, 7, 12] and n == 0:
		n = 1
	frases.clear()
	if n >= 1:
		frases.append(f0)
	if n >= 2:
		frases.append(f1)


# o Enter: na torre aberta entra direto; senao confere o equipamento como o ValidateEquipmentForEntry
# itens = slots vestidos do inventario (7 asa, 8 montaria, 10 e 11 aneis); "" = pode
static func recusa(itens: Dictionary, torre: bool) -> String:
	if torre:
		return ""
	var ajudante: Dictionary = itens.get(8, {})
	var g := func(it: Dictionary) -> String: return "%d,%d" % [it.get("grupo", -1), it.get("numero", -1)]
	if g.call(ajudante) == "13,2":
		return "uniria"
	for s in [10, 11]:
		var it: Dictionary = itens.get(s, {})
		if it.get("grupo", -1) == 13 and it.get("numero", -1) in [10, 39, 40, 41, 68, 76, 122]:
			return "anel"
	var asa: Dictionary = itens.get(7, {})
	var voa: bool = asa.get("grupo", -1) == 12 and (asa.get("numero", -1) <= 6 or asa.get("numero", -1) in range(36, 44) \
		or asa.get("numero", -1) in [49, 50] or asa.get("numero", -1) in range(130, 136)) and asa.get("durabilidade", 1) > 0
	var monta: bool = ajudante.get("grupo", -1) == 13 and ajudante.get("numero", -1) in [3, 4, 37] and ajudante.get("durabilidade", 1) > 0
	if not voa and not monta:
		return "voar"
	if not [10, 11].any(func(s): return g.call(itens.get(s, {})) == "13,38"):
		return "pingente"
	return ""


# CreateMessageBox: as frases das recusas e dos resultados do D1 01
static func texto_caixa(r: Variant) -> String:
	match r:
		"uniria": return DicaItem.t(569)
		"anel": return DicaItem.t(2175)
		"voar": return DicaItem.t(2176)
		"pingente": return DicaItem.t(2172)
	var n := int(r)
	if n == 3 or n == 4:
		return DicaItem.t(2170)
	return DicaItem.t(2170 + n)


func _botao(i: int) -> Rect2:
	return Rect2(17 + 70 * i, 220, 53, 23)


# 52 letras como o original; com fonte, tambem a largura da caixa (a nossa fonte e mais larga que a do MU)
static func quebrar(t: String, n := 52, f: Font = null) -> Array[String]:
	var r: Array[String] = []
	var atual := ""
	for p in t.split(" ", false):
		var tenta := p if atual == "" else atual + " " + p
		if atual != "" and (tenta.length() > n or (f and f.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > L - 24)):
			r.append(atual)
			atual = p
		else:
			atual = tenta
	if atual != "":
		r.append(atual)
	return r.slice(0, 3)


func _draw() -> void:
	draw_texture_rect(_tex.fundo, Rect2(0, 2, L - 8, A - 10), false)
	draw_texture_rect(_tex.msg_topo, Rect2(0, 0, L, 67), false)
	for i in 10:
		draw_texture_rect(_tex.msg_meio, Rect2(0, 67 + 15 * i, L, 15), false)
	draw_texture_rect(_tex.msg_baixo, Rect2(0, 217, L, 50), false)
	var f := get_theme_default_font()
	var y := 30.0
	for l in quebrar(assunto, 52, f):
		_texto(f, Vector2(0, y), l, Color8(255, 176, 73), true)
		y += 12
	y += 20
	for i in frases.size():
		for l in quebrar(frases[i], 52, f):
			_texto(f, Vector2(0, y), l, Color8(145, 241, 97) if i == 0 else Color8(255, 238, 193))
			y += 12
		y += 15
	var nomes := [2148, 2147, 388]
	for i in 3:
		var r := _botao(i)
		var cinza := (i == 0 and refresh_travado) or (i == 1 and not pode)
		var est := 0
		if not cinza and r.has_point(_mouse):
			est = 2 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1
		var cor := Color8(100, 100, 100) if cinza else Color.WHITE
		draw_texture_rect_region(_tex.btn_mini, r, Rect2(0, 23 * est, 54, 23), cor)
		draw_string(f, Vector2(r.position.x, r.position.y + 15), DicaItem.t(nomes[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, cor)


func _texto(f: Font, p: Vector2, t: String, cor: Color, negrito := false) -> void:
	var q := p + Vector2(0, 10)
	draw_string_outline(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, L, 10, 3 if negrito else 2, Color(0, 0, 0, 0.9))
	draw_string(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, L, 10, cor)


func clicar(i: int) -> void:
	match i:
		0:
			if not refresh_travado:
				refresh_travado = true
				_desde_refresh = 0.0
				_desde_pedido = 0.0
				atualizar.emit()
		1:
			if pode:
				visible = false
				entrar.emit()
		2:
			visible = false
			fechar.emit()
	queue_redraw()


func _process(dt: float) -> void:
	if not visible:
		return
	_desde_pedido += dt
	if _desde_pedido > 5.0:
		_desde_pedido = 0.0
		atualizar.emit()
	if refresh_travado:
		_desde_refresh += dt
		if _desde_refresh > 3.0:
			refresh_travado = false
			queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		queue_redraw()
		if not ev.pressed:
			for i in 3:
				if _botao(i).has_point(ev.position):
					clicar(i)
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()


func _unhandled_key_input(ev: InputEvent) -> void:
	if visible and ev.pressed and ev.keycode == KEY_ESCAPE:
		clicar(2)
		get_viewport().set_input_as_handled()
