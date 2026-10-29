class_name PlacaPosicao
extends Control
# A placa do canto de cima do cliente (CNewUIHeroPositionInfo): Minimap_positionA de 22x25 em 0,0, a B esticada
# na largura WidenX (80 + 20% = 96, UV 0.1 a 22.4/32) e a C de 73x20 do MacroUI depois dela. O texto
# "Mapa (x , y)" branco em 10,5, centrado em WidenX + 20. Os botoes do MU Helper (MacroUI_Setup e Start/Stop,
# 18x13) em WidenX + 41 e WidenX + 59. Depois deles o botao de ajuda (F1) que abre os comandos do jogo.

signal ajuda

const WIDEN := 96.0
const AJUDA := Rect2(WIDEN + 22 + 73 + 2, 2, 16, 16)

var texto := "":
	set(t):
		if t != texto:
			texto = t
			queue_redraw()
var _tex := {}
var _sobre := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for n in ["pos_a", "pos_b", "pos_c"]:
		_tex[n] = load("res://dados/hud/%s.png" % n)
	JanelaMU.carregar()
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	var v := get_viewport_rect().size
	scale = Vector2.ONE * v.x / 640.0
	position = Vector2.ZERO
	size = Vector2(AJUDA.end.x + 2, 25)


# so o botao de ajuda pega o clique; o resto da placa deixa passar pro jogo
func _has_point(p: Vector2) -> bool:
	return AJUDA.has_point(p)


func botao(b: TextureButton, x: float) -> void:
	b.custom_minimum_size = Vector2(18, 13)
	b.size = Vector2(18, 13)
	b.position = Vector2(WIDEN + x, 0)
	add_child(b)


func _draw() -> void:
	draw_texture_rect(_tex.pos_a, Rect2(0, 0, 22, 25), false)
	draw_texture_rect_region(_tex.pos_b, Rect2(22, 0, WIDEN, 25), Rect2(0.1, 0, 22.3, 25))
	draw_texture_rect(_tex.pos_c, Rect2(22 + WIDEN, 0, 73, 20), false)
	var f := get_theme_default_font()
	draw_string(f, Vector2(10, 5 + 9), texto, HORIZONTAL_ALIGNMENT_CENTER, WIDEN + 20, 9, Color(1, 1, 1))
	draw_texture_rect(JanelaMU.tex.win_button, AJUDA, false, Color(1.25, 1.25, 1.25) if _sobre else Color(1, 1, 1))
	draw_string(f, Vector2(AJUDA.position.x, AJUDA.position.y + 12), "?", HORIZONTAL_ALIGNMENT_CENTER, AJUDA.size.x,
		11, Color8(255, 255, 255) if _sobre else JanelaMU.TEXTO)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var s := AJUDA.has_point(ev.position)
		if s != _sobre:
			_sobre = s
			queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		ajuda.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _sobre:
		_sobre = false
		queue_redraw()
