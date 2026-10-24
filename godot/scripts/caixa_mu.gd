class_name CaixaMU
extends Control
# Caixa de mensagem do cliente S6 (CNewUICommonMessageBox): 230 de largura, topo de 67, um meio de 15 por
# linha a mais e o pe de 50, centrada a 100 do alto na tela de 640x480. OK e Cancel (54x30) no meio de cada
# metade. Com senha=true ganha um campo secreto (o CNewUIGuildPasswordMsgBox, ate 20).

signal respondeu(ok: bool, texto: String)
signal escolheu(i: int)                     # caixa com escolhas (cargo da guilda): -1 cancelou

const PASTA := "res://dados/hud/"
const L := 230.0

var linhas: Array = []
var com_cancelar := true
var senha := false
var escolhas: Array = []     # textos de botoes de 108x29, um embaixo do outro, e o Cancel no pe
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _campo: LineEdit


func _init(textos: Array = [], cancelar := true, com_senha := false) -> void:
	linhas = textos
	com_cancelar = cancelar
	senha = com_senha
	_campo = LineEdit.new()
	_campo.secret = true
	_campo.max_length = 20
	_campo.add_theme_font_size_override("font_size", 10)
	_campo.visible = senha
	_campo.text_submitted.connect(func(_t): responder(true))
	add_child(_campo)


func _ready() -> void:
	for n in ["inv_fundo", "msg_topo", "msg_meio", "msg_baixo", "msg_ok", "msg_cancelar", "btn_vazio"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	if senha:
		_campo.grab_focus()


func altura() -> float:
	return 67.0 + 15.0 * maxi(_linhas_total() - 2, 0) + 50.0


func _linhas_total() -> int:
	return linhas.size() + (2 if senha else 0) + escolhas.size() * 2


func _escolha(i: int) -> Rect2:
	return Rect2(L / 2 - 54, 35 + linhas.size() * 15 + 4 + i * 30, 108, 29)


func _ajustar() -> void:
	if not is_inside_tree():
		return
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	size = Vector2(L, altura())
	position = Vector2((v.x - L * _esc) / 2.0, 100.0 * _esc)
	_campo.position = Vector2(40, 35 + linhas.size() * 15 + 2)
	_campo.size = Vector2(L - 80, 18)
	queue_redraw()


func _botao(i: int) -> Rect2:
	var a := altura()
	if not com_cancelar or not escolhas.is_empty():
		return Rect2(L / 2 - 27, a - 50, 54, 30)
	return Rect2(L / 4 - 27 + i * L / 2, a - 50, 54, 30)


func responder(ok: bool) -> void:
	if not is_queued_for_deletion():
		respondeu.emit(ok, _campo.text)
		queue_free()


func escolher(i: int) -> void:
	if not is_queued_for_deletion():
		escolheu.emit(i)
		queue_free()


func _draw() -> void:
	var a := altura()
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, a), false)
	draw_texture_rect(_tex.msg_topo, Rect2(0, 0, L, 67), false)
	for i in maxi(_linhas_total() - 2, 0):
		draw_texture_rect(_tex.msg_meio, Rect2(0, 67 + i * 15, L, 15), false)
	draw_texture_rect(_tex.msg_baixo, Rect2(0, a - 50, L, 50), false)
	var f := get_theme_default_font()
	for i in linhas.size():
		var p := Vector2(0, 35 + i * 15 + 10)
		draw_string_outline(f, p, str(linhas[i]), HORIZONTAL_ALIGNMENT_CENTER, L, 10, 2, Color(0, 0, 0, 0.9))
		draw_string(f, p, str(linhas[i]), HORIZONTAL_ALIGNMENT_CENTER, L, 10, Color.WHITE)
	for i in escolhas.size():
		var r := _escolha(i)
		draw_texture_rect_region(_tex.btn_vazio, r, Rect2(0, 29 * (1 if r.has_point(_mouse) else 0), 108, 29))
		draw_string(f, Vector2(r.position.x, r.position.y + 18), str(escolhas[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10,
			Color.WHITE)
	if not escolhas.is_empty():
		var b := _botao(0)
		draw_texture_rect_region(_tex.msg_cancelar, b, Rect2(0, 30 * (1 if b.has_point(_mouse) else 0), 54, 30))
		return
	for i in (2 if com_cancelar else 1):
		var b := _botao(i)
		var t: Texture2D = _tex.msg_ok if i == 0 else _tex.msg_cancelar
		draw_texture_rect_region(t, b, Rect2(0, 30 * (1 if b.has_point(_mouse) else 0), 54, 30))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		if not escolhas.is_empty():
			for i in escolhas.size():
				if _escolha(i).has_point(ev.position):
					escolher(i)
			if _botao(0).has_point(ev.position):
				escolher(-1)
			accept_event()
			return
		for i in (2 if com_cancelar else 1):
			if _botao(i).has_point(ev.position):
				responder(i == 0)
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev.pressed:
		return
	if ev.keycode in [KEY_ENTER, KEY_KP_ENTER] and escolhas.is_empty():
		responder(true)
	elif ev.keycode == KEY_ESCAPE:
		if escolhas.is_empty():
			responder(false)
		else:
			escolher(-1)
	else:
		return
	get_viewport().set_input_as_handled()
