class_name JanelaMU
extends Control
# Janela antiga do cliente S6 (CUIBaseWindow, UIWindows.cpp), a familia do "My Friend": amigos, cartas, sala de
# chat, pergunta e texto. Desenhada a mao como no original: fundo SetLineColor(3) a partir de y+5, a moldura do
# DrawOutLine (cores 0, 1, 2 e o ponto 4 nos cantos), a barra do titulo (win_titlebar de x+6, 15 de altura) com o
# titulo em negrito em x+9, y+8 ((230,220,200) na janela de cima, (115,110,100) nas outras) e o X de 9x9 em
# w-16, 8. A area de dentro (RPos) comeca em 5, 21. Coordenadas na tela de 640x480; a janela escala junto.

signal fechou

const PASTA := "res://dados/hud/"
const MOLDURA := 5.0
const TITULO := 21.0
const TEXTO := Color8(230, 220, 200)
# SetLineColor do UIControls.cpp
const COR := [Color8(146, 134, 121), Color8(37, 37, 37), Color8(106, 97, 88), Color(0, 0, 0, 0.7), Color8(173, 167, 150),
	Color8(53, 49, 48), Color8(26, 22, 21), Color(0, 0, 0, 1), Color8(153, 156, 166), Color8(136, 138, 147),
	Color8(83, 85, 93), Color8(102, 104, 112), Color8(0, 0, 8), Color8(0, 0, 0), Color8(185, 185, 185)]

static var tex := {}

var titulo := ""
var L := 250.0
var A := 170.0
var pos := Vector2(50, 50)          # canto na tela de 640x480
var com_titulo := true
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _apertado := ""                 # botao com o mouse em cima e apertado
var _arrasta := Vector2.ZERO
var _arrastando := false
var _botoes := {}                   # nome -> [Rect2, texto] desenhados neste quadro


static func carregar() -> void:
	if not tex.is_empty():
		return
	for n in ["win_titlebar", "win_button", "win_size", "win_check", "win_mail", "win_scrollbar", "win_question", "webzenmail"]:
		tex[n] = load(PASTA + n + ".png")


func _init(t := "", largura := 250.0, altura := 170.0) -> void:
	titulo = t
	L = largura
	A = altura
	carregar()
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(L, A)


func _ready() -> void:
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	altura_campos(self)


# o LineEdit nasce com a altura da fonte padrao (31) se o tamanho vem antes do tema: volta pra 14 dentro da arvore
static func altura_campos(no: Node) -> void:
	for c in no.get_children():
		if c is LineEdit:
			c.size.y = 14


func _ajustar() -> void:
	if not is_inside_tree():
		return
	var v := get_viewport_rect().size
	_esc = minf(v.x / 640.0, v.y / 480.0)
	pos = pos.clamp(Vector2(-L + 40, 0), Vector2(640 - 40, 480 - 20))
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = pos * _esc
	queue_redraw()


# janela no meio da tela (UIWND_DEFAULT)
func centrar() -> void:
	pos = Vector2(round((640 - L) / 2), round((480 - A) / 2) - 40)
	_ajustar()


func no_topo() -> bool:
	var p := get_parent()
	if p == null:
		return true
	for i in range(p.get_child_count() - 1, -1, -1):
		var c := p.get_child(i)
		if c is JanelaMU and c.visible:
			return c == self
	return true


func trazer() -> void:
	if get_parent():
		get_parent().move_child(self, -1)
	queue_redraw()


func fechar() -> void:
	visible = false
	fechou.emit()


func dentro(x: float, y: float) -> Vector2:
	return Vector2(MOLDURA + x, (TITULO if com_titulo else MOLDURA) + y)


func largura_dentro() -> float:
	return L - MOLDURA * 2


func altura_dentro() -> float:
	return A - ((TITULO if com_titulo else MOLDURA) + MOLDURA)


func _draw() -> void:
	_botoes.clear()
	draw_rect(Rect2(0, 5, L, A - 10), COR[3])
	_conteudo()
	var topo := no_topo()
	if com_titulo:
		draw_texture_rect(tex.win_titlebar, Rect2(6, 5, L - 12, 15), false)
		draw_rect(Rect2(5, 5, 1, 1), COR[10] if not topo else COR[8])
		draw_rect(Rect2(5, 6, 1, 13), COR[10] if not topo else COR[9])
		draw_rect(Rect2(5, 19, 1, 1), COR[10])
		draw_rect(Rect2(L - 6, 5, 1, 1), COR[11])
		draw_rect(Rect2(L - 6, 6, 1, 13), COR[12])
		draw_rect(Rect2(L - 6, 19, 1, 1), COR[13])
	_moldura(0, 0, L, A)
	if com_titulo:
		draw_rect(Rect2(5, 20, L - 10, 1), COR[2])
		texto(Vector2(9, 8), _cortar(titulo, L - 50), TEXTO if topo else Color8(115, 110, 100), true)
		draw_texture_rect_region(tex.win_size, Rect2(L - 16, 8, 9, 9), Rect2(0, 9, 9, 9))
	_por_cima()


# DrawOutLine
func _moldura(x: float, y: float, w: float, h: float) -> void:
	draw_rect(Rect2(x, y, w, 1), COR[0])
	draw_rect(Rect2(x, y + 1, w, 3), COR[1])
	draw_rect(Rect2(x, y + 4, w, 1), COR[2])
	draw_rect(Rect2(x, y + h - 5, w, 1), COR[2])
	draw_rect(Rect2(x, y + h - 4, w, 3), COR[1])
	draw_rect(Rect2(x, y + h - 1, w, 1), COR[0])
	draw_rect(Rect2(x, y, 1, h), COR[0])
	draw_rect(Rect2(x + 1, y + 5, 3, h - 10), COR[1])
	draw_rect(Rect2(x + 4, y + 1, 1, h - 2), COR[2])
	draw_rect(Rect2(x + w - 5, y + 1, 1, h - 2), COR[2])
	draw_rect(Rect2(x + w - 4, y + 5, 3, h - 10), COR[1])
	draw_rect(Rect2(x + w - 1, y, 1, h), COR[0])
	for p in [Vector2(x + 2, y + 2), Vector2(x + w - 3, y + 2), Vector2(x + 2, y + h - 3), Vector2(x + w - 3, y + h - 3)]:
		draw_rect(Rect2(p, Vector2.ONE), COR[4])


# o que cada janela desenha dentro (antes da moldura) e por cima (a foto, a lista de convite)
func _conteudo() -> void:
	pass


func _por_cima() -> void:
	pass


# texto do original: (x, y) e o topo da linha; aqui a base fica 9 abaixo
func texto(p: Vector2, t: String, cor := TEXTO, negrito := false, largura := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT, tam := 10) -> void:
	var f := get_theme_default_font()
	var b := p + Vector2(0, 9)
	draw_string(f, b, t, al, largura, tam, cor)
	if negrito:
		draw_string(f, b + Vector2(0.6, 0), t, al, largura, tam, cor)


func largura_texto(t: String) -> float:
	return get_theme_default_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x


func _cortar(t: String, w: float) -> String:
	if largura_texto(t) <= w:
		return t
	while t.length() > 1 and largura_texto(t + "..") > w:
		t = t.substr(0, t.length() - 1)
	return t + ".."


# CUIButton: win_button esticado, legenda no meio; apertado desce 1
func botao(nome: String, r: Rect2, legenda: String, ativo := true) -> void:
	_botoes[nome] = [r, ativo]
	var em_cima := r.has_point(_mouse)
	var mod := Color(1, 1, 1) if ativo else Color(0.5, 0.5, 0.5)
	draw_texture_rect(tex.win_button, r, false, mod)
	var d := 1.0 if em_cima and _apertado == nome else 0.0
	var cor := TEXTO if ativo else Color8(150, 140, 130)
	if em_cima and ativo:
		cor = Color8(255, 255, 255)
	texto(Vector2(r.position.x + d, r.position.y + (r.size.y - 12) / 2 + d), legenda, cor, false, r.size.x,
		HORIZONTAL_ALIGNMENT_CENTER)


# RenderCheckBox: quadrado de 9x9 na cor 0 e a marca de 5x5 dentro
func caixa_marcar(p: Vector2, marcado: bool) -> void:
	draw_rect(Rect2(p, Vector2(9, 9)), COR[0], false, 1.0)
	if marcado:
		draw_texture_rect(tex.win_check, Rect2(p + Vector2(2, 2), Vector2(5, 5)), false)


# barra de rolar das listas (win_scrollbar: seta em cima e embaixo, trilho e o botao)
func rolagem(r: Rect2, total: int, cabe: int, primeira: int) -> void:
	draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), COR[2])
	if total <= cabe:
		return
	var curso := r.size.y - 4
	var h := maxf(10.0, curso * cabe / total)
	var y := r.position.y + 2 + (curso - h) * primeira / maxf(1, total - cabe)
	draw_texture_rect_region(tex.win_scrollbar, Rect2(r.position.x + 2, y, r.size.x - 3, h), Rect2(0, 1, 11, 1))
	draw_rect(Rect2(r.position.x + 2, y, r.size.x - 3, 1), COR[0])
	draw_rect(Rect2(r.position.x + 2, y + h - 1, r.size.x - 3, 1), COR[1])


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		if _arrastando:
			position = get_global_mouse_position() - _arrasta
			pos = position / _esc
		queue_redraw()
	elif ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			trazer()
			if com_titulo and Rect2(L - 18, 6, 13, 13).has_point(ev.position):
				fechar()
			elif com_titulo and Rect2(0, 0, L, TITULO).has_point(ev.position):
				_arrastando = true
				_arrasta = get_global_mouse_position() - position
			else:
				_apertado = ""
				for n in _botoes:
					if _botoes[n][0].has_point(ev.position) and _botoes[n][1]:
						_apertado = n
				if _apertado == "":
					_clique(ev.position, ev.double_click)
		elif ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			_arrastando = false
			if _apertado != "" and _botoes.has(_apertado) and _botoes[_apertado][0].has_point(ev.position):
				var n := _apertado
				_apertado = ""
				_apertou(n)
			_apertado = ""
		elif ev.pressed and ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_roda(ev.position, -1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()


# cada janela responde aqui
func _apertou(_nome: String) -> void:
	pass


func _clique(_p: Vector2, _duplo: bool) -> void:
	pass


func _roda(_p: Vector2, _passo: int) -> void:
	pass


# campo de texto sem fundo (CUITextInputBox com SetBackColor(0,0,0,0)), na tela de 640x480 da janela
static func campo(limite: int, cor := Color8(230, 220, 200)) -> LineEdit:
	var e := LineEdit.new()
	e.max_length = limite
	e.add_theme_font_size_override("font_size", 10)
	e.add_theme_color_override("font_color", cor)
	var vazio := StyleBoxFlat.new()
	vazio.bg_color = Color(0, 0, 0, 0)
	vazio.content_margin_left = 1
	vazio.content_margin_top = 0
	vazio.content_margin_bottom = 0
	for s in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(s, vazio)
	e.custom_minimum_size = Vector2(0, 14)
	e.context_menu_enabled = false
	return e


# campo da caixa de mensagem (CNewUITextInputMsgBox: SetBackColor(255, 0, 0, 0) e SetTextColor(255, 255, 230, 210),
# alfa primeiro): fundo preto cheio, letra creme, sem a moldura branca do Godot
static func campo_preto(e: LineEdit) -> void:
	var preto := StyleBoxFlat.new()
	preto.bg_color = Color(0, 0, 0, 1)
	preto.content_margin_left = 3
	preto.content_margin_right = 3
	preto.content_margin_top = 1
	preto.content_margin_bottom = 1
	for s in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(s, preto)
	var cor := Color8(255, 230, 210)
	e.add_theme_color_override("font_color", cor)
	e.add_theme_color_override("caret_color", cor)
	e.add_theme_color_override("font_selected_color", Color.BLACK)
	e.add_theme_color_override("selection_color", Color8(255, 230, 210, 200))
	e.context_menu_enabled = false


# botao com a textura do cliente (newui_btn_empty: btn_pequeno 64, btn_vazio 108, btn_grande 180; tres
# quadros de 29 empilhados: normal, mouse em cima, apertado), letra branca de 10 como nas caixas
static func botao_mu(b: Button, nome := "btn_vazio") -> void:
	var tex: Texture2D = load("res://dados/hud/%s.png" % nome)
	var w := float(tex.get_width())
	for par in [["normal", 0], ["hover", 1], ["pressed", 2], ["focus", 0], ["disabled", 0]]:
		var s := StyleBoxTexture.new()
		s.texture = tex
		s.region_rect = Rect2(0, 29 * par[1], w, 29)
		s.texture_margin_left = 6
		s.texture_margin_right = 6
		s.texture_margin_top = 6
		s.texture_margin_bottom = 6
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		if par[0] == "disabled":
			s.modulate_color = Color(0.5, 0.5, 0.5)
		b.add_theme_stylebox_override(par[0], s)
	b.add_theme_font_size_override("font_size", 10)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	b.custom_minimum_size = Vector2(maxf(b.custom_minimum_size.x, w), 29)
	b.focus_mode = Control.FOCUS_NONE


# fundo das janelas que ainda sao montadas com containers: a pedra escura das caixas do cliente
# (newui_msgbox_back) com uma borda dourada fina, no lugar do painel do Godot
static func painel_mu(c: Control, margem := 12) -> void:
	var s := StyleBoxTexture.new()
	s.texture = load("res://dados/hud/msg_fundo.png")
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.set_content_margin_all(margem)
	c.add_theme_stylebox_override("panel", s)


# o tema do hud inteiro (jogo.gd): Button com o newui_btn_empty, LineEdit e TextEdit pretos com letra creme,
# PanelContainer na pedra das caixas; quem precisa de outro visual sobrescreve no proprio controle
static func tema_mu(t: Theme) -> void:
	var modelo := Button.new()
	botao_mu(modelo)
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(k, "Button", modelo.get_theme_stylebox(k))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]:
		t.set_color(c, "Button", modelo.get_theme_color(c))
	modelo.free()
	var campo := LineEdit.new()
	campo_preto(campo)
	for k in ["normal", "focus", "read_only"]:
		t.set_stylebox(k, "LineEdit", campo.get_theme_stylebox(k))
		t.set_stylebox(k, "TextEdit", campo.get_theme_stylebox(k))
	for c in ["font_color", "caret_color", "font_selected_color", "selection_color"]:
		t.set_color(c, "LineEdit", campo.get_theme_color(c))
		t.set_color(c, "TextEdit", campo.get_theme_color(c))
	campo.free()
	var painel := PanelContainer.new()
	painel_mu(painel)
	t.set_stylebox("panel", "PanelContainer", painel.get_theme_stylebox("panel"))
	painel.free()
