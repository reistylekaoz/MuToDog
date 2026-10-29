class_name Movimento
extends Control
# Janela Move (M) como o CNewUIMoveCommandWindow do S6 (NewUIMoveCommandWindow.cpp): quadro preto (CC) de 230
# no canto de cima a esquerda (1,1 na tela de 640), titulo "Warp Command Window" em negrito 255,204,26, colunas
# Map, Min. Level e Cost em 127,178,255 centradas em x 62, 119 e 159, uma linha por destino de 14, barra de
# rolagem do chat (newui_scrollbar e newui_scroll_on) e a faixa vermelha (FF990000) do Close embaixo.
# Pode ir: branco, e a linha embaixo do mouse acende (99CCCC1A). Nao pode: 164,39,17, com o nivel ou o zen que
# faltam em 255,51,26. Cada destino vem da lista do servidor (WarpInfo do OpenMU, em dados/movimento.json).
# Clique leva (o servidor confere de novo e cobra). Os portais do mapa (EnterGate) ficam em portal_em().

signal ir(indice: int, nome: String)

const L := 230.0
const LINHA := 14.0
const PASTA := "res://dados/hud/"

var lista: Array = []       # [indice, nome, zen, nivel, mapa]
var portais := {}           # mapa -> [[numero, x1, y1, x2, y2, nivel, destino]]
var reducao := {}           # classe -> % a menos no nivel
var mapas := {}             # numero -> nome
var _linhas: Array = []     # [indice, nome, nivel pedido, zen, pode, falta_nivel, falta_zen]
var _rolagem := 0
var _visiveis := 26
var _mouse := Vector2(-100, -100)
var _arrastando := false
var _pega := 0.0
var _tex := {}


func _ready() -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://dados/movimento.json")) if FileAccess.file_exists("res://dados/movimento.json") else null
	if d is Dictionary:
		lista = d.lista
		portais = d.portais
		reducao = d.reducao
	for n in ["rolagem_cima", "rolagem_meio", "rolagem_baixo", "rolagem_on", "rolagem_off"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	visible = false


# CalculateLayout: linhas que cabem ate o alto da barra de baixo (480 - 51), 60 de moldura
func _ajustar() -> void:
	var v := get_viewport_rect().size
	var e := v.x / 640.0
	scale = Vector2(e, e)
	position = Vector2(e, e)
	var fundo := (v.y - 51.0 * e) / e
	_visiveis = maxi(1, int((fundo - 1.0 - 60.0) / LINHA))
	size = Vector2(L, 60.0 + _visiveis * LINHA)
	_rolagem = clampi(_rolagem, 0, _max_rolagem())
	queue_redraw()


func _max_rolagem() -> int:
	return maxi(0, _linhas.size() - _visiveis)


# nivel que o servidor pede pra essa classe (MG, DL e RF pedem 2/3; 400 vale pra todos)
func nivel_pedido(nivel: int, classe: int) -> int:
	var r := int(reducao.get(str(classe), 0))
	if nivel == 400 or r <= 0:
		return nivel
	return nivel * (100 - r) / 100


static func nome_bonito(n: String) -> String:
	# "Devias2" -> "Devias 2", "LostTower3" -> "Lost Tower 3", "KanturuRuins1" -> "Kanturu Ruins 1"
	var r := ""
	for i in n.length():
		var c := n[i]
		if i > 0 and ((c >= "A" and c <= "Z" and n[i - 1] >= "a") or (c >= "0" and c <= "9" and not (n[i - 1] >= "0" and n[i - 1] <= "9"))):
			r += " "
		r += c
	return r


func abrir(nivel: int, zen: int, classe: int) -> void:
	_linhas.clear()
	for w in lista:
		var precisa := nivel_pedido(int(w[3]), classe)
		var falta_nivel := nivel < precisa
		var falta_zen := zen < int(w[2])
		_linhas.append([int(w[0]), nome_bonito(str(w[1])), precisa, int(w[2]), not falta_nivel and not falta_zen,
			falta_nivel, falta_zen])
	_rolagem = 0
	_arrastando = false
	visible = true
	move_to_front()
	_ajustar()


# --- desenho --------------------------------------------------------------------

func _topo_lista() -> float:
	return 38.0


func _rect_fechar() -> Rect2:
	return Rect2(2, size.y - LINHA - 6, L - 5, LINHA)


func _y_polegar() -> float:
	var m := _max_rolagem()
	var curso := maxf(0.0, _visiveis * LINHA - 30.0)
	if m == 0:
		return _topo_lista() - 3
	return _topo_lista() - 3 + roundf(_rolagem * curso / m)


func _draw() -> void:
	var f := get_theme_default_font()
	draw_rect(Rect2(0, 0, L, size.y), Color(0, 0, 0, 0.8))
	draw_rect(_rect_fechar(), Color8(0x99, 0, 0))
	# barra de rolagem
	var xb := L - 14
	var topo := _topo_lista() - 3
	var alto := _visiveis * LINHA
	draw_texture_rect(_tex.rolagem_cima, Rect2(xb, topo, 7, 3), false)
	var y := topo + 3
	while y < topo + alto - 3:
		var h := minf(15.0, topo + alto - 3 - y)
		draw_texture_rect_region(_tex.rolagem_meio, Rect2(xb, y, 7, h), Rect2(0, 0, 7, h))
		y += 15
	draw_texture_rect(_tex.rolagem_baixo, Rect2(xb, topo + alto - 3, 7, 3), false)
	var pol := Rect2(xb - 4, _y_polegar(), 15, 30)
	if _max_rolagem() > 0:
		draw_texture_rect(_tex.rolagem_on, pol, false, Color(0.7, 0.7, 0.7) if _arrastando else Color.WHITE)
	else:
		draw_texture_rect(_tex.rolagem_off, pol, false)
	# titulo e cabecalho
	_centro(f, L / 2, 4, DicaItem.t(933), Color8(255, 204, 26), true)
	for c in [[62, 934], [119, 935], [159, 936]]:
		_centro(f, c[0], 24, DicaItem.t(c[1]), Color8(127, 178, 255))
	# destinos
	for k in _visiveis:
		var i := _rolagem + k
		if i >= _linhas.size():
			break
		var l: Array = _linhas[i]
		var yl := _topo_lista() + k * LINHA
		var base := Color.WHITE if l[4] else Color8(164, 39, 17)
		var vermelho := Color8(255, 51, 26)
		if l[4] and Rect2(2, yl, L - 22, LINHA).has_point(_mouse) and not _arrastando:
			draw_rect(Rect2(2, yl - 1, L - 22, LINHA), Color8(0xCC, 0xCC, 0x1A, 0x99))
		_centro(f, 62, yl, l[1], base)
		_centro(f, 119, yl, str(l[2]), vermelho if l[5] else base)
		_centro(f, 159, yl, str(l[3]), vermelho if l[6] else base)
	_centro(f, L / 2, _rect_fechar().position.y + 1, DicaItem.t(388), Color.WHITE)


# RT3_WRITE_CENTER: texto centrado em x, alto da letra em y (g_hFont, 12 na tela de 640)
func _centro(f: Font, x: float, y: float, t: String, cor: Color, negrito := false) -> void:
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var p := Vector2(x - w / 2.0, y + 10)
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, cor)
	if negrito:
		draw_string(f, p + Vector2(0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, cor)


# --- mouse ----------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		if _arrastando:
			var curso := maxf(1.0, _visiveis * LINHA - 30.0)
			var t := clampf(ev.position.y - _pega - (_topo_lista() - 3), 0.0, curso)
			_rolagem = int(roundf(t * _max_rolagem() / curso))
		queue_redraw()
	elif ev is InputEventMouseButton:
		accept_event()
		if not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and _arrastando:
			_arrastando = false
			queue_redraw()
			return
		if not ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				_soltou(ev.position)
			return
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_rolagem = clampi(_rolagem - 1, 0, _max_rolagem())
			MOUSE_BUTTON_WHEEL_DOWN:
				_rolagem = clampi(_rolagem + 1, 0, _max_rolagem())
			MOUSE_BUTTON_LEFT:
				var pol := Rect2(L - 18, _y_polegar(), 15, 30)
				if _max_rolagem() > 0 and pol.has_point(ev.position):
					_arrastando = true
					_pega = ev.position.y - _y_polegar()
		queue_redraw()


func _soltou(p: Vector2) -> void:
	if _rect_fechar().has_point(p):
		visible = false
		return
	for k in _visiveis:
		var i := _rolagem + k
		if i >= _linhas.size():
			break
		if _linhas[i][4] and Rect2(2, _topo_lista() + k * LINHA, L - 22, LINHA).has_point(p):
			visible = false
			ir.emit(_linhas[i][0], _linhas[i][1])
			return


func alternar(nivel: int, zen: int, classe: int) -> void:
	if visible:
		visible = false
	else:
		abrir(nivel, zen, classe)


# portal do mapa embaixo de (x, y): [numero, x1, y1, x2, y2, nivel, destino] ou []
func portal_em(mapa: int, x: int, y: int) -> Array:
	for g in portais.get(str(mapa), []):
		if x >= int(g[1]) and x <= int(g[3]) and y >= int(g[2]) and y <= int(g[4]):
			return g
	return []
