class_name JanelaComandos
extends Control
# Janela de comandos do MU S6 (CNewUICommandWindow, tecla D): 190 de largura, 12 botoes de
# 108 x 29 um embaixo do outro. Clicar num botao deixa ele apertado; depois o botao direito
# num jogador perto (ate 6 tiles) executa o comando nele, como no cliente.

signal executar(comando: int, alvo: int)

const PASTA := "res://dados/hud/"
const L := 190.0
const A := 429.0
enum { TROCA, COMPRAR, GRUPO, SUSSURRO, GUILDA, ALIANCA, RIVAL, FIM_RIVAL, AMIGO, SEGUIR, ESPECIAL, DUELO }
const TEXTOS := [943, 1124, 944, 945, 946, 1295, 1321, 1322, 947, 948, -1, 949]
const DISTANCIA := 6

var selecionado := -1
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo01", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "btn_vazio"]:
		_tex[n] = load(PASTA + n + ".png")
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


func alternar() -> void:
	visible = not visible
	if not visible:
		selecionado = -1
	queue_redraw()


func nome(i: int) -> String:
	return "Special Commands" if TEXTOS[i] < 0 else DicaItem.t(TEXTOS[i])


func _botao(i: int) -> Rect2:
	return Rect2(L / 2 - 54, 33 + i * 30, 108, 29)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo01, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 21), DicaItem.t(938), L, 10, Color.WHITE, true)
	for i in 12:
		var r := _botao(i)
		var fr := 2 if i == selecionado else (1 if r.has_point(_mouse) else 0)
		draw_texture_rect_region(_tex.btn_vazio, r, Rect2(0, 29 * fr, 108, 29))
		_texto(f, Vector2(r.position.x, r.position.y + 18), nome(i), r.size.x, 10,
			Color.WHITE if i == selecionado or r.has_point(_mouse) else Color(0.85, 0.85, 0.85), i == selecionado)
	var sair := Rect2(13, 392, 36, 29)
	draw_texture_rect_region(_tex.inv_sair, sair, Rect2(0, 29 * (1 if sair.has_point(_mouse) else 0), 36, 29))
	if sair.has_point(_mouse):
		_texto(f, Vector2(_mouse.x - 30, _mouse.y - 6), "Fechar (D)", 0, 9, Color.WHITE, false)


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, negrito: bool) -> void:
	var al := HORIZONTAL_ALIGNMENT_CENTER if largura > 0 else HORIZONTAL_ALIGNMENT_LEFT
	var w := largura if largura > 0 else -1.0
	draw_string_outline(f, p, t, al, w, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, w, tam, cor)
	if negrito:
		draw_string(f, p + Vector2(0.5, 0), t, al, w, tam, cor)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			clique(ev.position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()


func clique(p: Vector2) -> void:
	if Rect2(13, 392, 36, 29).has_point(p):
		alternar()
		return
	for i in 12:
		if _botao(i).has_point(p):
			selecionado = -1 if selecionado == i else i
			if i == ESPECIAL:
				selecionado = -1
				executar.emit(ESPECIAL, -1)
			queue_redraw()
			return


# botao direito no mundo com um comando apertado: devolve true se usou o clique
func usar_em(alvo: int) -> bool:
	if selecionado < 0:
		return false
	var c := selecionado
	selecionado = -1
	queue_redraw()
	executar.emit(c, alvo)
	return true
