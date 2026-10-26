class_name JanelaTemplo
extends Control
# Entrada do Illusion Temple pela Mirage (CNewUICursedTempleEnter, NPC janela 0x14): caixa de mensagem de
# 230x252 (topo com titulo, 9 meios, pe e a linha a 77 do fim) em (640/2 - 115, 80). Titulo em azul claro,
# "The N Illusion Temple" e as 6 faixas de nivel (220-270 ... 381-400 e o master), a do heroi com fundo
# azul e "Entrance enabled"; embaixo quantos ja estao no templo (C1 BF 03) em vermelho. Quem tem menos de
# 220 so ve o aviso. Enter (54x23) manda C1 BF 00 com o templo do nivel; Close fecha.

signal entrar(templo: int)
signal fechar

const PASTA := "res://dados/hud/templo/"
const L := 230.0
const A := 252.0
const MINIMO := [220, 271, 321, 351, 381]
const MAXIMO := [270, 320, 350, 380, 400]
const AZUL := Color(0x49 / 255.0, 0xB0 / 255.0, 1.0)

var templo := -1          # 1 a 5 pelo nivel, 6 o master, -1 nao pode
var gente := 0
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "msg_meio", "msg_baixo", "msg_linha"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	for n in ["msg_titulo", "btn_mini"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


# a tela de 640x480 inteira cabe na janela (largura ou altura), centrada
func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = minf(v.x / 640.0, v.y / 480.0)
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2((v.x - 640.0 * _esc) / 2.0 + (320.0 - L / 2.0) * _esc, (v.y - 480.0 * _esc) / 2.0 + 80.0 * _esc)
	queue_redraw()


# CheckEnterLevel: master (nivel 400 com a arvore) entra no 6; senao a faixa do nivel
static func templo_do_nivel(nivel: int, master: bool) -> int:
	if master:
		return 6
	for i in MINIMO.size():
		if nivel >= MINIMO[i] and nivel <= MAXIMO[i]:
			return i + 1
	return -1


func abrir(nivel: int, master: bool) -> void:
	templo = templo_do_nivel(nivel, master)
	visible = true
	queue_redraw()


# C1 BF 03: a gente de cada templo; a janela mostra so a do templo do heroi
func contar(lista: Array) -> void:
	if templo > 0 and templo <= lista.size():
		gente = int(lista[templo - 1])
		queue_redraw()


func _botao(i: int) -> Rect2:
	return Rect2(L / 4 - 27 + i * L / 2, 203, 54, 23)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 2, L - 4, A - 6), false)
	draw_texture_rect_region(_tex.msg_titulo, Rect2(0, 0, L, 67), Rect2(0, 0, L, 67))
	for i in 9:
		draw_texture_rect(_tex.msg_meio, Rect2(0, 67 + i * 15, L, 15), false)
	draw_texture_rect(_tex.msg_baixo, Rect2(0, 67 + 135, L, 50), false)
	draw_texture_rect(_tex.msg_linha, Rect2(0, A - 77, 223, 21), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 13), DicaItem.t(2358), L, 11, AZUL, true)
	if templo > 0:
		_texto(f, Vector2(3, 42), DicaItem.t(2370, [templo]), L - 10, 10, Color.WHITE)
		for i in 6:
			var t := DicaItem.t(737) if i == 5 else DicaItem.t(2371, [MINIMO[i], MAXIMO[i]])
			t += " " + DicaItem.t(2412 if templo == i + 1 else 2413)
			if templo == i + 1:
				var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				draw_rect(Rect2(3 + (L - 10 - w) / 2 - 1, 67 + i * 15, w + 2, 13), Color(0, 0, 1))
			_texto(f, Vector2(3, 67 + i * 15), t, L - 10, 10, Color.WHITE)
		_texto(f, Vector2(3, 70 + 6 * 15), DicaItem.t(2373, [gente]), L - 10, 10, Color(1, 0, 0))
	else:
		_texto(f, Vector2(0, 52), DicaItem.t(2366), L, 10, Color(1, 0, 0))
	for i in 2:
		var r := _botao(i)
		var estado := 0
		if r.has_point(_mouse):
			estado = 2 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1
		draw_texture_rect_region(_tex.btn_mini, r, Rect2(0, 23 * estado, 54, 23))
		_texto(f, Vector2(r.position.x, r.position.y + 5), DicaItem.t(1593 if i == 0 else 388), 54, 10, Color.WHITE)


# DrawText do cliente: y e o alto da linha; a frase que nao cabe desce de tamanho
func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, negrito := false) -> void:
	while tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura - 4:
		tam -= 1
	var q := p + Vector2(0, tam)
	draw_string_outline(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, 3 if negrito else 2, Color(0, 0, 0, 0.9))
	draw_string(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, cor)


# UpdateMouseEvent: Enter com o nivel certo manda o pedido; fora da faixa so o aviso no log
func clicar(i: int) -> void:
	if i == 0:
		if templo > 0:
			entrar.emit(templo)
		else:
			entrar.emit(-1)
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
