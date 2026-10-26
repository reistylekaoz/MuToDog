class_name CaixaTemplo
extends Control
# Resultado do Illusion Temple (CNewUICursedTempleResult, C1 BF 04): caixa de 230x282 (topo com titulo,
# 11 meios, pe e as linhas a 45 e a 77 do fim) em (205, 120). "Hero List" em azul claro, o cabecalho
# Camp / Character / Class / EXP / Point, os do MU Alliance a partir de 65 (laranja) e os da Illusion
# Sorcery a partir de 140 (azul claro), a linha do heroi com fundo azul. Em cima a faixa de vitoria ou
# derrota (351x115) aparecendo (0,015 por quadro): vence quem tem mais pontos e pelo menos 2.
# Close (ou Esc) fecha e pede o premio (C1 BF 05).

signal fechou

const PASTA := "res://dados/hud/templo/"
const L := 230.0
const A := 282.0
const AZUL := Color(0x49 / 255.0, 0xB0 / 255.0, 1.0)
const COR_ALIADOS := Color(0xFB / 255.0, 0xB2 / 255.0, 0x64 / 255.0)
const COR_ILUSAO := Color(0x37 / 255.0, 0xD6 / 255.0, 0xFE / 255.0)

var heroi := ""
var minha_equipe := 2          # 0 MU Alliance, 1 Illusion Sorcery, 2 nenhuma
var aliados := 0
var ilusao := 0
var lista: Array = []          # [{nome, equipe, classe (do servidor), exp}]
var classes := {}              # dados/classes.json (o jogo passa)
var venceu := 0                # 0 nada, 1 vitoria, 2 derrota
var _alfa := 0.0
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "msg_meio", "msg_baixo", "msg_linha"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	for n in ["msg_titulo", "btn_mini", "sucesso", "falha"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	# ReceiveCursedTempleGameResult: quem venceu e pelo menos 2 pontos
	var meus := aliados if minha_equipe == 0 else ilusao
	var deles := ilusao if minha_equipe == 0 else aliados
	venceu = 1 if meus > deles and meus >= 2 else 2
	print("TESTE templo resultado %d x %d: %s" % [aliados, ilusao, "vitoria" if venceu == 1 else "derrota"])


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = minf(v.x / 640.0, v.y / 480.0)
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2((v.x - 640.0 * _esc) / 2.0 + 205.0 * _esc, (v.y - 480.0 * _esc) / 2.0 + 120.0 * _esc)
	queue_redraw()


func _process(_dt: float) -> void:
	if _alfa < 1.0:
		_alfa = minf(_alfa + 0.015 * 60.0 * get_process_delta_time(), 1.0)
		queue_redraw()


func _botao() -> Rect2:
	return Rect2(L / 2 - 27, A - 37, 54, 23)


func _draw() -> void:
	# a faixa fica a (640 - 360) / 2 da tela, 110 acima da caixa
	draw_texture_rect_region(_tex.sucesso if venceu == 1 else _tex.falha, Rect2(140 - 205, -110, 351, 115),
		Rect2(0, 0, 351, 115), Color(1, 1, 1, _alfa))
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 2, L - 4, A - 6), false)
	draw_texture_rect_region(_tex.msg_titulo, Rect2(0, 0, L, 67), Rect2(0, 0, L, 67))
	for i in 11:
		draw_texture_rect(_tex.msg_meio, Rect2(0, 67 + i * 15, L, 15), false)
	draw_texture_rect(_tex.msg_baixo, Rect2(0, 67 + 165, L, 50), false)
	draw_texture_rect(_tex.msg_linha, Rect2(0, A - 77, 223, 21), false)
	draw_texture_rect(_tex.msg_linha, Rect2(0, 45, 223, 21), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 13), DicaItem.t(2414), L, 11, AZUL, HORIZONTAL_ALIGNMENT_CENTER)
	for c in [[5, 2415], [56, 681], [106, 1973], [150, 683], [190, 2326]]:
		_texto(f, Vector2(c[0], 38), DicaItem.t(c[1]), 60, 10, AZUL)
	var ia := 0
	var ii := 0
	for e in lista:
		var aliado := int(e.equipe) == 0
		var y := (65.0 + ia * 15) if aliado else (140.0 + ii * 15)
		if aliado:
			ia += 1
		else:
			ii += 1
		var cor := COR_ALIADOS if aliado else COR_ILUSAO
		if str(e.nome) == heroi:
			draw_rect(Rect2(2, y, 220, 13), Color(0, 0, 1))
		_texto(f, Vector2(5, y), DicaItem.t(2387 if aliado else 2388), 52, 9, cor)
		_texto(f, Vector2(56, y), str(e.nome), 52, 9, cor)
		_texto(f, Vector2(106, y), str(classes.get(str(e.classe), "?")), 46, 9, cor)
		_texto(f, Vector2(150, y), str(e.exp), 42, 9, cor)
		_texto(f, Vector2(190, y), str(aliados if aliado else ilusao), 36, 9, cor)
	_texto(f, Vector2(0, A - 55), DicaItem.t(2416), L, 10, Color(1, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	var r := _botao()
	var estado := 0
	if r.has_point(_mouse):
		estado = 2 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1
	draw_texture_rect_region(_tex.btn_mini, r, Rect2(0, 23 * estado, 54, 23))
	_texto(f, Vector2(r.position.x, r.position.y + 5), DicaItem.t(388), 54, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	while tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura - 2:
		tam -= 1
	var q := p + Vector2(0, tam)
	draw_string_outline(f, q, t, al, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, q, t, al, largura, tam, cor)


func fechar() -> void:
	if not is_queued_for_deletion():
		fechou.emit()
		queue_free()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		queue_redraw()
		if not ev.pressed and _botao().has_point(ev.position):
			fechar()
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev.pressed and ev.keycode == KEY_ESCAPE:
		fechar()
		get_viewport().set_input_as_handled()
