class_name HudMu
extends Control
# A barra de baixo do MU S6 (CNewUIMainFrameWindow do cliente), desenhada em
# coordenadas da tela de referencia 640x480 e esticada na largura da janela:
# moldura em 3 pecas, orbe de vida (x 158) e mana (x 437), SD (x 204) e AG (x 420)
# enchendo de baixo pra cima, numeros com a fonte do cliente, experiencia em 10
# partes (a barra enche a parte atual, o numero da direita diz em qual esta) e os
# botoes da direita. Passar o mouse mostra o valor, como no jogo.

signal botao(qual: String)

const PASTA := "res://dados/hud/"
const TOPO := 429.0            # onde a moldura comeca na tela de 480
const BOTOES := ["loja", "personagem", "inventario", "amigos", "menu"]
const DICAS := {"loja": "Loja (X)", "personagem": "Personagem (C)", "inventario": "Inventario (I, V)",
	"amigos": "Amigos (F)", "menu": "Menu (U)"}

var vida := 0
var vida_max := 1
var mana := 0
var mana_max := 1
var sd := 0
var sd_max := 1
var ag := 0
var ag_max := 1
var exp_atual := 0
var exp_antes := 0      # experiencia em que o nivel atual comecou
var exp_prox := 1

var _tex := {}
var _mouse := Vector2(-1, -1)
var _apertado := ""
var _esc := 1.0


func _ready() -> void:
	for n in ["menu1", "menu2", "menu3", "orbe_red", "orbe_blue", "orbe_sd", "orbe_ag", "exbar", "numeros",
			"bt1", "bt2", "bt3", "bt4", "bt5"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


# a tela de 640 vira a largura da janela; a barra fica colada embaixo
func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	size = Vector2(640, 51)
	position = Vector2(0, v.y - 51.0 * _esc)
	queue_redraw()


# ponto da tela de referencia (640x480) -> ponto local deste Control
func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x, y - TOPO, w, h)


func _draw() -> void:
	draw_texture(_tex.menu1, Vector2(0, 0))
	draw_texture(_tex.menu2, Vector2(256, 0))
	draw_texture(_tex.menu3, Vector2(384, 0))
	_orbe(_tex.orbe_red, 158, 432, 45, 39, vida, vida_max)
	_numero(158 + 25, 462, vida)
	_orbe(_tex.orbe_blue, 437, 432, 45, 39, mana, mana_max)
	_numero(437 + 30, 462, mana)
	_orbe(_tex.orbe_sd, 204, 431, 16, 39, sd, sd_max)
	_numero(204 + 15, 462, sd)
	_orbe(_tex.orbe_ag, 420, 431, 16, 39, ag, ag_max)
	_numero(420 + 10, 462, ag)
	# experiencia: 10 partes; a barra mostra quanto da parte atual ja foi
	var r := clampf(float(exp_atual - exp_antes) / maxf(exp_prox - exp_antes, 1), 0.0, 1.0)
	var parte := mini(int(r * 10.0), 9)
	var resto := 1.0 if r >= 1.0 else r * 10.0 - parte
	if resto > 0.0:
		draw_texture_rect(_tex.exbar, _r(2, 473, resto * 629.0, 4), false)
	_numero(635, 469, parte)
	for i in BOTOES.size():
		var q: Rect2 = _r(489 + 30 * i, TOPO, 30, 41)
		var linha := 0
		if _apertado == BOTOES[i] and q.has_point(_mouse):
			linha = 2
		elif q.has_point(_mouse):
			linha = 1
		var t: Texture2D = _tex["bt%d" % [5, 1, 2, 3, 4][i]]
		draw_texture_rect_region(t, q, Rect2(0, 41 * linha, 30, 41))
	# dica em cima da barra (RenderTipText, y 418)
	var d := dica()
	if d != "":
		var f := get_theme_default_font()
		var tam := f.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		var x := clampf(_mouse.x - tam.x / 2.0, 2.0, 638.0 - tam.x)
		draw_rect(Rect2(x - 3, 418 - TOPO - 10, tam.x + 6, 13), Color(0, 0, 0, 0.75))
		draw_string(f, Vector2(x, 418 - TOPO), d, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1))


# orbe que enche de baixo pra cima (RenderLifeMana): a parte vazia some por cima
func _orbe(t: Texture2D, x: float, y: float, w: float, h: float, v: int, m: int) -> void:
	var falta := clampf(float(m - v) / maxf(m, 1), 0.0, 1.0)
	if falta >= 1.0:
		return
	draw_texture_rect_region(t, _r(x, y + falta * h, w, h - falta * h), Rect2(0, falta * h, w, h - falta * h))


# RenderNumber: digitos de 12x14 na tira newui_number1, centrados em x, passo 80%
func _numero(x: float, y: float, n: int) -> void:
	var s := str(maxi(n, 0))
	var w := 12.0 * 0.7
	var h := 16.0 * 0.7
	x -= w * s.length() / 2.0
	for c in s:
		var d := c.unicode_at(0) - 48
		draw_texture_rect_region(_tex.numeros, _r(x, y, w, h), Rect2(d * 12, 0, 12, 14))
		x += w * 0.8


func dica() -> String:
	var p := _mouse
	if _r(158, 432, 45, 39).has_point(p):
		return "Vida %d / %d" % [vida, vida_max]
	if _r(437, 432, 45, 39).has_point(p):
		return "Mana %d / %d" % [mana, mana_max]
	if _r(204, 431, 16, 39).has_point(p):
		return "SD %d / %d" % [sd, sd_max]
	if _r(420, 431, 16, 39).has_point(p):
		return "AG %d / %d" % [ag, ag_max]
	if _r(2, 470, 629, 10).has_point(p):
		return "Exp %s / %s" % [ItemChao._milhar(exp_atual), ItemChao._milhar(exp_prox)]
	var b := _botao_em(p)
	return DICAS.get(b, "")


func _botao_em(p: Vector2) -> String:
	for i in BOTOES.size():
		if _r(489 + 30 * i, TOPO, 30, 41).has_point(p):
			return BOTOES[i]
	return ""


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		if ev.pressed:
			_apertado = _botao_em(ev.position)
		else:
			var b := _botao_em(ev.position)
			if b != "" and b == _apertado:
				botao.emit(b)
			_apertado = ""
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-1, -1)
		_apertado = ""
		queue_redraw()


func atualizar() -> void:
	queue_redraw()
