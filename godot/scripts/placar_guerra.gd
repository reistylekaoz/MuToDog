class_name PlacarGuerra
extends Control
# Placar da guerra de guilda e do Battle Soccer (CNewUIBattleSoccerScore): 131x70 em (509, 359) da tela
# de 640x480, logo acima da barra na direita. Duas linhas a 22 uma da outra a partir de (30, 33): os
# pontos, a marca de 8x8 e o nome da guilda. Na guerra a primeira linha e a minha guilda; o time 0
# pinta a minha de laranja (255, 60, 0) e a outra de azul (0, 150, 255), o time 1 ao contrario. Quem
# so assiste o futebol (F3 23) ve o vermelho em cima e o azul embaixo.

const VERMELHO := Color8(255, 60, 0)
const AZUL := Color8(0, 150, 255)

var linhas: Array = []     # [{nome, pontos, cor, tex}]
var _fundo: Texture2D
var _esc := 1.0


func _ready() -> void:
	_fundo = load("res://dados/hud/placar_fundo.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	size = Vector2(131, 70)
	position = Vector2(v.x - 131 * _esc, v.y - (51 + 70) * _esc)
	queue_redraw()


# guerra: eu e o inimigo com os pontos de cada um (C1 62 e C1 64)
func guerra(minha: String, tex_minha: Texture2D, meu: int, outra: String, tex_outra: Texture2D, dele: int, time: int) -> void:
	linhas = [
		{"nome": minha, "pontos": meu, "cor": VERMELHO if time == 0 else AZUL, "tex": tex_minha},
		{"nome": outra, "pontos": dele, "cor": AZUL if time == 0 else VERMELHO, "tex": tex_outra}]
	visible = true
	queue_redraw()


# futebol visto de fora (F3 23): vermelho em cima, azul embaixo
func futebol(vermelho: String, gols_v: int, azul: String, gols_a: int) -> void:
	linhas = [
		{"nome": vermelho, "pontos": gols_v, "cor": VERMELHO, "tex": null},
		{"nome": azul, "pontos": gols_a, "cor": AZUL, "tex": null}]
	visible = true
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(_fundo, Rect2(0, 0, 131, 70), false)
	var f := get_theme_default_font()
	for i in linhas.size():
		var l: Dictionary = linhas[i]
		var y := 33.0 + i * 22
		_negrito(f, Vector2(30, y), str(l.pontos), l.cor)
		if l.tex:
			draw_texture_rect(l.tex, Rect2(51, y - 8, 8, 8), false)
		_negrito(f, Vector2(63, y), str(l.nome), l.cor)


func _negrito(f: Font, p: Vector2, t: String, cor: Color) -> void:
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_rect(Rect2(p.x - 1, p.y - 10, w + 3, 13), Color(0, 0, 0, 0.5))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cor)
	draw_string(f, p + Vector2(0.6, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cor)
