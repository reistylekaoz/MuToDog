class_name JanelaGrupo
extends Control
# Lista do grupo no canto de cima da direita (CNewUIPartyListWindow do cliente S6), na tela de referencia 640x480:
# uma linha de 77x23 por membro a partir de (561, 14) (ou da borda da janela aberta), 24 de passo. Nome em (+4, +4), o lider (o primeiro da lista)
# em laranja com a bandeirinha; barra de vida de 69x3 em (+4, +16), em decimos (C1 44). O X de 11x11 em (+63, +3):
# o lider tira qualquer um, os outros so a si mesmos (C1 43 com o indice). Mouse em cima: vida e onde esta.

signal tirar(indice: int)

const PASTA := "res://dados/hud/"
const Y0 := 34.0   # o cliente usa 14; aqui o botao Sair e a linha de ajuda ocupam o topo

var membros: Array = []     # {nome, indice, mapa, x, y, vida, vida_max, passo}
var meu_nome := ""
var livre := 640.0      # janela aberta na direita empurra a lista pra esquerda
var mapas := {}
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["grupo_fundo", "grupo_lider", "grupo_vida", "grupo_x"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_PASS
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	if not is_inside_tree():
		return
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	size = Vector2(640, 200)
	position = Vector2.ZERO
	queue_redraw()


func definir(l: Array) -> void:
	membros = []
	for m: Dictionary in l:
		var d := m.duplicate()
		d.passo = clampi(int(round(10.0 * m.vida / maxf(m.vida_max, 1.0))), 0, 10)
		membros.append(d)
	queue_redraw()


func limpar() -> void:
	membros = []
	queue_redraw()


# C1 44: [[indice, decimos]]
func vidas(l: Array) -> void:
	for par: Array in l:
		for m: Dictionary in membros:
			if m.indice == par[0]:
				m.passo = clampi(par[1], 0, 10)
	queue_redraw()


func passo_de(nome: String) -> int:
	for m: Dictionary in membros:
		if m.nome == nome:
			return m.passo
	return -1


func sou_lider() -> bool:
	return not membros.is_empty() and membros[0].nome == meu_nome


func _linha(i: int) -> Rect2:
	return Rect2(livre - 79, Y0 + 24 * i, 77, 23)


func _x(i: int) -> Rect2:
	return Rect2(livre - 16, Y0 + 24 * i + 3, 11, 11)


# o X aparece no lider (em todos) e em mim
func tem_x(i: int) -> bool:
	return sou_lider() or membros[i].nome == meu_nome


func _has_point(p: Vector2) -> bool:
	for i in membros.size():
		if _linha(i).has_point(p):
			return true
	return false


func _draw() -> void:
	var f := get_theme_default_font()
	var sob := -1
	for i in membros.size():
		var m: Dictionary = membros[i]
		var r := _linha(i)
		draw_texture_rect(_tex.grupo_fundo, r, false)
		var cor := Color8(255, 148, 22) if i == 0 else Color8(255, 255, 255)
		draw_string(f, r.position + Vector2(4, 12), m.nome, HORIZONTAL_ALIGNMENT_LEFT, 56, 9, cor)
		if i == 0:
			draw_texture_rect(_tex.grupo_lider, Rect2(r.position + Vector2(53, 3), Vector2(9, 10)), false)
		var w: float = 69.0 * m.passo / 10.0
		if w > 0:
			draw_texture_rect_region(_tex.grupo_vida, Rect2(r.position + Vector2(4, 16), Vector2(w, 3)), Rect2(0, 0, w, 3))
		if tem_x(i):
			var bx := _x(i)
			draw_texture_rect_region(_tex.grupo_x, bx, Rect2(0, 11 if bx.has_point(_mouse) else 0, 11, 11))
		if r.has_point(_mouse):
			sob = i
	if sob >= 0:
		var m: Dictionary = membros[sob]
		var l := [{"t": m.nome, "cor": DicaItem.AZUL, "negrito": true},
			{"t": "%s (%d, %d)" % [mapas.get(str(m.mapa), "Mapa %d" % m.mapa), m.x, m.y], "cor": DicaItem.BRANCO},
			{"t": "Vida %d%%" % (m.passo * 10), "cor": DicaItem.BRANCO}]
		DicaItem.mostrar(self, f, l, _linha(sob))
	else:
		DicaItem.esconder(self)


func clicar(p: Vector2) -> bool:
	for i in membros.size():
		if tem_x(i) and _x(i).grow(1).has_point(p):
			tirar.emit(membros[i].indice)
			return true
	return false


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		clicar(ev.position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()
