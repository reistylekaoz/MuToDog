class_name CaixaFruta
extends Control
# Caixa da fruta (CUseFruitCheckMsgBox do cliente S6): "<atributo> Fruit", "Choose." e os botoes Create, Decrease
# e Cancel. Create manda o uso 0 (soma pontos), Decrease o 1 (tira); C3 26 [slot, 0, uso] (FruitUsage do OpenMU).

signal escolheu(slot: int, uso: int)

const NOMES := [168, 169, 167, 166, 1900]   # nivel da fruta -> ENG, STA, AGI, STR, Command
const BOTOES := [1412, 1903, 229]
const L := 240.0
const A := 104.0

var slot := -1
var nivel := 0
var _btn: Texture2D
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	_btn = load("res://dados/hud/btn_vazio.png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	if not is_inside_tree():
		return
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2((v.x - L * _esc) / 2.0, v.y * 0.3)


func abrir(s: int, n: int) -> void:
	slot = s
	nivel = clampi(n, 0, 4)
	visible = true
	_ajustar()
	queue_redraw()


func titulo() -> String:
	return "%s %s" % [DicaItem.t(NOMES[nivel]), DicaItem.t(1901)]


func _rect_botao(i: int) -> Rect2:
	return Rect2(L / 2 - 117 + 80 * i, 62, 74, 29)


func _draw() -> void:
	var f := get_theme_default_font()
	draw_rect(Rect2(0, 0, L, A), Color8(14, 12, 10, 245))
	draw_rect(Rect2(0, 0, L, A), Color8(150, 120, 70), false, 1.0)
	for i in 2:
		var t := titulo() if i == 0 else DicaItem.t(1902)
		var p := Vector2(0, 22 + 16 * i)
		draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_CENTER, L, 10, 2, Color(0, 0, 0, 0.9))
		draw_string(f, p, t, HORIZONTAL_ALIGNMENT_CENTER, L, 10, Color8(255, 230, 210) if i else Color8(255, 204, 26))
	for i in 3:
		var b := _rect_botao(i)
		draw_texture_rect_region(_btn, b, Rect2(0, 29 * (1 if b.has_point(_mouse) else 0), 108, 29))
		draw_string(f, Vector2(b.position.x, b.position.y + 19), DicaItem.t(BOTOES[i]), HORIZONTAL_ALIGNMENT_CENTER,
			b.size.x, 10, Color8(255, 230, 210))


func escolher(i: int) -> void:
	if not visible:
		return
	visible = false
	if i < 2:
		escolheu.emit(slot, i)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		for i in 3:
			if _rect_botao(i).has_point(ev.position):
				escolher(i)
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()
