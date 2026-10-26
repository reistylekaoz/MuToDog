class_name JanelaDuelo
extends Control
# Placar do duelo (CNewUIDuelWindow): newui_Figure_ground de 131 x 70 em (509, 359) da tela de 640 x 480
# (131 da direita e 121 de baixo), em negrito: meu nome em azul (0, 150, 255) a (55, 33) com os meus pontos
# a (31, 33), o dele em vermelho (255, 25, 25) a (55, 56) com os pontos a (31, 56). Abre no "aceitou"
# (C1 AA 01 com 0) e fecha no fim (C1 AA 03). A vida e o SD em % (C1 AA 05) ficam guardados pro teste:
# o cliente so desenha as barras na janela de quem assiste.

var eu_nome := ""
var ele_nome := ""
var ele_id := -1
var meus := 0
var dele := 0
var vida := {"eu": 100, "ele": 100, "sd_eu": 100, "sd_ele": 100}
var _primeiro := true
var _tex: Texture2D
var _negrito: FontVariation


func _ready() -> void:
	name = "JanelaDuelo"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex = load("res://dados/hud/duelo_fundo.png")
	_negrito = FontVariation.new()
	_negrito.base_font = get_theme_default_font()
	_negrito.variation_embolden = 0.6
	visible = false


func abrir(meu: String, id: int, nome: String) -> void:
	eu_nome = meu
	ele_id = id
	ele_nome = nome
	meus = 0
	dele = 0
	_primeiro = true
	vida = {"eu": 100, "ele": 100, "sd_eu": 100, "sd_ele": 100}
	visible = true
	queue_redraw()


func fechar() -> void:
	visible = false
	ele_id = -1


# C1 AA 04 e 05 trazem os dois ids: o que nao e o adversario sou eu. Diz se mudou (ou se e o primeiro)
func placar(id1: int, _id2: int, p1: int, p2: int) -> bool:
	var primeiro_e_ele := id1 == ele_id
	var antes := [meus, dele]
	meus = p2 if primeiro_e_ele else p1
	dele = p1 if primeiro_e_ele else p2
	queue_redraw()
	var mudou := _primeiro or antes != [meus, dele]
	_primeiro = false
	return mudou


func vidas(id1: int, _id2: int, v1: int, v2: int, s1: int, s2: int) -> void:
	var ele := id1 == ele_id
	vida = {"eu": v2 if ele else v1, "ele": v1 if ele else v2, "sd_eu": s2 if ele else s1, "sd_ele": s1 if ele else s2}


func canto() -> Vector2:
	return Vector2(640 - 131, get_viewport_rect().size.y / (get_viewport_rect().size.x / 640.0) - 121)


func _draw() -> void:
	var esc := get_viewport_rect().size.x / 640.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(esc, esc))
	var p := canto()
	draw_texture_rect(_tex, Rect2(p, Vector2(131, 70)), false)
	var azul := Color8(0, 150, 255)
	var vermelho := Color8(255, 25, 25)
	for l in [[Vector2(55, 33), eu_nome, azul], [Vector2(31, 33), str(meus), azul],
			[Vector2(55, 56), ele_nome, vermelho], [Vector2(31, 56), str(dele), vermelho]]:
		draw_string(_negrito, p + l[0] + Vector2(0, 10), l[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, l[2])
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
