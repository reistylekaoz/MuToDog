class_name JanelaDoppel
extends Control
# Entrada do Doppelganger pelo Lugard (CNewUIDoppelGangerWindow, NPC janela 0x23): 190x429 colada na direita
# como as outras de NPC (moldura do inventario), "Lugard" em cima, a fala dele em 3 partes (quebradas a 140
# e a 100 de largura), o Mirror of Dimensions (14,111) desenhado no meio com o nome em negrito, o Enter
# (54x23), a linha, "Entry Time" e quanto falta (o byte depois do tipo no C3 30: 0 = pode entrar). Enter
# manda C1 BF 0E; o C1 BF 0E de volta trava (1, 2, 3) ou destrava (4) o botao. Close ou Esc fecham.

signal entrar
signal fechar

const L := 190.0
const A := 429.0
const PASTA := "res://dados/hud/templo/"

var minutos := 0
var travado := false
var _linhas: Array[String] = []
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "quest_linha"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	_tex.btn_mini = load(PASTA + "btn_mini.png")
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


# OpeningProcess: o botao sempre abre destravado
func abrir(min_: int) -> void:
	minutos = min_
	travado = false
	var f := get_theme_default_font()
	_linhas.clear()
	_linhas.append_array(cortar(f, DicaItem.t(2757), 140))
	_linhas.append_array(cortar(f, DicaItem.t(2758), 100))
	visible = true
	queue_redraw()


# CutStr(texto, ..., largura, 2 linhas): a primeira linha leva as palavras que cabem, a segunda o resto
static func cortar(f: Font, t: String, largura: float) -> Array[String]:
	var a := ""
	var b := ""
	for p in t.split(" ", false):
		if b == "":
			var tenta := p if a == "" else a + " " + p
			if a != "" and f.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > largura:
				b = p
			else:
				a = tenta
		else:
			b += " " + p
	return [a, b]


# C1 BF 0E: 1, 2 e 3 travam o Enter (2 e 3 tambem dizem por que no log), 4 destrava
func resultado(r: int) -> void:
	if r in [1, 2, 3]:
		travado = true
	elif r == 4:
		travado = false
	queue_redraw()


func _botao(i: int) -> Rect2:
	return Rect2(68, 190 if i == 0 else 360, 54, 23)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(15, 13), DicaItem.t(2756), 160, 11, Color8(220, 220, 220), true)
	var y := 50.0
	for i in _linhas.size():
		_texto(f, Vector2(0, y + 15 * i), _linhas[i], L, 10, Color.WHITE)
	_texto(f, Vector2(0, y + 60), DicaItem.t(2759), L, 10, Color.WHITE)
	ItensMU.desenhar(self, {"grupo": 14, "numero": 111}, Rect2((L - 20) / 2, y + 75, 20, 27))
	_texto(f, Vector2(0, y + 120), DicaItem.t(2760), L, 10, Color.WHITE, true)
	draw_texture_rect(_tex.quest_linha, Rect2(1, 220, 188, 21), false)
	_texto(f, Vector2(0, y + 210), DicaItem.t(2761), L, 10, Color.WHITE)
	_texto(f, Vector2(0, y + 230), DicaItem.t(2800) if minutos == 0 else DicaItem.t(2762, [minutos]), L, 10, Color.WHITE)
	for i in 2:
		var r := _botao(i)
		var cinza := i == 0 and travado
		var estado := 0
		if not cinza and r.has_point(_mouse):
			estado = 2 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1
		var cor := Color8(100, 100, 100) if cinza else Color.WHITE
		draw_texture_rect_region(_tex.btn_mini, r, Rect2(0, 23 * estado, 54, 23), cor)
		_texto(f, Vector2(r.position.x, r.position.y + 5), DicaItem.t(1593 if i == 0 else 388), 54, 10, cor)


# RenderText com RT3_SORT_CENTER: y e o alto da linha; a frase que nao cabe desce de tamanho
func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, negrito := false) -> void:
	while tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura - 4:
		tam -= 1
	var q := p + Vector2(0, tam)
	draw_string_outline(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, 3 if negrito else 2, Color(0, 0, 0, 0.9))
	draw_string(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, cor)


# BtnProcess: Enter (se nao travado) pede a entrada; Close fecha
func clicar(i: int) -> void:
	if i == 0:
		if not travado:
			entrar.emit()
	else:
		visible = false
		fechar.emit()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		queue_redraw()
		if not ev.pressed:
			for i in 2:
				if _botao(i).has_point(ev.position):
					clicar(i)
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()


func _unhandled_key_input(ev: InputEvent) -> void:
	if visible and ev.pressed and ev.keycode == KEY_ESCAPE:
		clicar(1)
		get_viewport().set_input_as_handled()
