class_name CaixaSenha
extends Control
# Senha do bau (CNewUIPasswordKeyPad e CNewUILockMsgBox do cliente S6), no meio da tela de 640x480.
# Teclado de 4 digitos com os numeros embaralhados numa grade de 5x2 (o cliente sorteia a ordem a cada vez).
# Tres pedidos ao servidor (C1 83): 00 destrancar (senha de 4), 01 criar (senha de 4 duas vezes e a senha da conta),
# 02 tirar a senha (so a senha da conta). O servidor responde com o estado no C1 83.

signal pronto(sub: int, pin: int, senha: String)

const L := 200.0
const A := 170.0
const BOTOES := [228, 229]   # OK, Cancel

var sub := 0                 # 0 destrancar, 1 criar, 2 tirar
var passo := 0               # criar: 0 escolhe, 1 repete, 2 senha da conta
var digitos := ""
var primeira := ""
var aviso := ""
var ordem: Array = []
var _btn: Texture2D
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _conta: LineEdit


func _init() -> void:
	_conta = LineEdit.new()
	_conta.secret = true
	_conta.max_length = 20
	_conta.position = Vector2(30, 70)
	_conta.size = Vector2(L - 60, 18)
	_conta.add_theme_font_size_override("font_size", 10)
	JanelaMU.campo_preto(_conta)
	_conta.visible = false
	_conta.text_submitted.connect(func(_t): _ok())
	add_child(_conta)


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
	position = Vector2((v.x - L * _esc) / 2.0, v.y * 0.25)


func abrir(s: int) -> void:
	sub = s
	passo = 2 if s == 2 else 0
	digitos = ""
	primeira = ""
	aviso = ""
	ordem = range(10)
	ordem.shuffle()
	_conta.text = ""
	_conta.visible = passo == 2
	visible = true
	_ajustar()
	if passo == 2 and _conta.is_inside_tree():
		_conta.grab_focus()
	queue_redraw()


func fechar() -> void:
	visible = false
	_conta.visible = false
	if _conta.is_inside_tree():
		_conta.release_focus()


func titulo() -> String:
	if sub == 0:
		return DicaItem.t(692)
	return DicaItem.t(690) if passo == 2 else DicaItem.t(693 if passo == 0 else 694)


func pergunta() -> String:
	if passo == 2:
		return DicaItem.t(691).replace("WEBZEN.COM", "")
	if sub == 1 and passo == 1:
		return DicaItem.t(696)
	return DicaItem.t(695)


func _rect_digito(i: int) -> Rect2:
	return Rect2(L / 2 - 85 + 34 * (i % 5), 66 + 30 * (i / 5), 30, 26)


func _rect_botao(i: int) -> Rect2:
	return Rect2(L / 2 - 78 + 82 * i, A - 40, 74, 29)


func digito(n: int) -> void:
	if passo == 2 or digitos.length() >= 4:
		return
	digitos += str(n)
	aviso = ""
	queue_redraw()


func apagar() -> void:
	digitos = digitos.left(-1)
	queue_redraw()


func _ok() -> void:
	if passo == 2:
		if _conta.text == "":
			return
		var pin := int(primeira) if sub == 1 else 0
		fechar()
		pronto.emit(sub, pin, _conta.text)
		return
	if digitos.length() < 4:
		aviso = DicaItem.t(695)
		queue_redraw()
		return
	if sub == 0:
		fechar()
		pronto.emit(0, int(digitos), "")
		return
	if passo == 0:
		# o cliente nao aceita os 4 iguais (texto 442)
		if digitos == digitos[0].repeat(4):
			aviso = DicaItem.t(442)
			digitos = ""
		else:
			primeira = digitos
			digitos = ""
			passo = 1
		queue_redraw()
		return
	if digitos != primeira:
		aviso = DicaItem.t(440)
		digitos = ""
		passo = 0
		queue_redraw()
		return
	passo = 2
	_conta.visible = true
	if _conta.is_inside_tree():
		_conta.grab_focus()
	queue_redraw()


func clicar(i: int) -> void:
	if i == 0:
		_ok()
	else:
		fechar()


func _draw() -> void:
	var f := get_theme_default_font()
	draw_rect(Rect2(0, 0, L, A), Color8(14, 12, 10, 245))
	draw_rect(Rect2(0, 0, L, A), Color8(150, 120, 70), false, 1.0)
	_linha(f, 20, titulo(), Color8(255, 204, 26))
	_linha(f, 38, pergunta(), Color8(255, 230, 210))
	if passo < 2:
		_linha(f, 56, "* ".repeat(digitos.length()).strip_edges() if digitos != "" else "_ _ _ _", Color8(255, 255, 255))
		for i in 10:
			var r := _rect_digito(i)
			draw_rect(r, Color8(60, 45, 25) if r.has_point(_mouse) else Color8(35, 28, 18))
			draw_rect(r, Color8(150, 120, 70), false, 1.0)
			draw_string(f, Vector2(r.position.x, r.position.y + 18), str(ordem[i]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12,
				Color8(255, 230, 210))
	if aviso != "":
		_linha(f, A - 48, aviso, Color8(255, 120, 80))
	for i in 2:
		var b := _rect_botao(i)
		draw_texture_rect_region(_btn, b, Rect2(0, 29 * (1 if b.has_point(_mouse) else 0), 108, 29))
		draw_string(f, Vector2(b.position.x, b.position.y + 19), DicaItem.t(BOTOES[i]), HORIZONTAL_ALIGNMENT_CENTER,
			b.size.x, 10, Color8(255, 230, 210))


func _linha(f: Font, y: float, t: String, cor: Color) -> void:
	draw_string_outline(f, Vector2(0, y), t, HORIZONTAL_ALIGNMENT_CENTER, L, 10, 2, Color(0, 0, 0, 0.9))
	draw_string(f, Vector2(0, y), t, HORIZONTAL_ALIGNMENT_CENTER, L, 10, cor)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		if passo < 2:
			for i in 10:
				if _rect_digito(i).has_point(ev.position):
					digito(ordem[i])
		for i in 2:
			if _rect_botao(i).has_point(ev.position):
				clicar(i)
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not visible or not ev.pressed:
		return
	var k: int = ev.keycode
	if k >= KEY_0 and k <= KEY_9:
		digito(k - KEY_0)
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		digito(k - KEY_KP_0)
	elif k == KEY_BACKSPACE:
		apagar()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		_ok()
	elif k == KEY_ESCAPE:
		fechar()
	else:
		return
	get_viewport().set_input_as_handled()
