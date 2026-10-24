class_name JanelaCriarGuilda
extends Control
# Criacao de guilda do cliente S6 (CNewUIGuildMakeWindow), aberta pelo Guild Master (C1 54).
# Tres passos: a pergunta (texto 181 e o botao Create guild), o nome com a marca de 8x8 pintada
# com as 16 cores, e o resumo. Fechar manda C1 54 00; Next no resumo manda o C1 55.

signal responder_mestre(criar: bool)
signal criar(nome: String, marca: PackedByteArray)
signal avisar(texto: String)

const PASTA := "res://dados/hud/"
const L := 190.0
const A := 429.0
enum { INFO, MARCA, RESUMO }

var passo := INFO
var marca := PackedByteArray()
var cor := 1
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _pintando := -1
var _nome: LineEdit
var _tex_marca: ImageTexture


func _init() -> void:
	marca.resize(64)
	_nome = LineEdit.new()
	_nome.max_length = 8
	_nome.position = Vector2(47, 61)
	_nome.size = Vector2(104, 21)
	_nome.flat = true
	for st in ["normal", "focus", "read_only"]:
		_nome.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_nome.add_theme_font_size_override("font_size", 10)
	_nome.visible = false
	add_child(_nome)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo01", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "btn_vazio", "btn_pequeno",
			"guilda_campo"]:
		_tex[n] = load(PASTA + n + ".png")
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


func abrir() -> void:
	passo = INFO
	marca.fill(0)
	cor = 1
	_nome.text = ""
	_nome.visible = false
	visible = true
	queue_redraw()


func fechar(avisar_servidor := true) -> void:
	if visible and avisar_servidor:
		responder_mestre.emit(false)
	visible = false
	_nome.visible = false


func nome() -> String:
	return _nome.text


func definir_nome(n: String) -> void:
	_nome.text = n


func ir(p: int) -> void:
	passo = p
	_nome.visible = p == MARCA
	if p == RESUMO:
		_tex_marca = Guildas.textura(marca)
	queue_redraw()


# o mesmo filtro do cliente: so letras e numeros, 4 ou mais; a marca nao pode ficar vazia
func validar() -> String:
	var n := _nome.text
	for ch in n:
		if not ((ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")):
			return DicaItem.t(391)
	if n.length() < 4:
		return DicaItem.t(390)
	if Guildas.vazia(marca):
		return DicaItem.t(426)
	return ""


func avancar() -> void:
	match passo:
		INFO:
			responder_mestre.emit(true)
			ir(MARCA)
		MARCA:
			var erro := validar()
			if erro != "":
				avisar.emit(erro)
			else:
				ir(RESUMO)
		RESUMO:
			criar.emit(_nome.text, marca)
			visible = false
			_nome.visible = false


func voltar() -> void:
	if passo == RESUMO:
		ir(MARCA)
	elif passo == MARCA:
		ir(INFO)


func pintar(i: int, c: int) -> void:
	marca[i] = c
	queue_redraw()


func _celula(i: int) -> Rect2:
	return Rect2(50 + (i % 8) * 15, 100 + (i / 8) * 15, 15, 15)


func _paleta(i: int) -> Rect2:
	return Rect2(15 + (i % 8) * 20, 260 + (i / 8) * 20, 20, 20)


func _btn_criar() -> Rect2:
	return Rect2(41, 100, 108, 29)


func _btn_voltar() -> Rect2:
	return Rect2(15, 379, 64, 29)


func _btn_seguir() -> Rect2:
	return Rect2(110, 379, 64, 29)


func _sair() -> Rect2:
	return Rect2(13, 392, 36, 29)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo01, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 21), DicaItem.t(180), L, Color8(73, 176, 255))
	match passo:
		INFO:
			_texto(f, Vector2(0, 56), DicaItem.t(181), L, Color.WHITE)
			_botao(_tex.btn_vazio, _btn_criar(), 108, DicaItem.t(1303))
			_botao_sair()
		MARCA:
			_texto(f, Vector2(10, 76), DicaItem.t(182), 0, Color.WHITE)
			draw_texture_rect(_tex.guilda_campo, Rect2(45, 60, 108, 23), false)
			draw_rect(Rect2(45, 95, 130, 130), Color8(170, 140, 60), false, 1.0)
			for i in 64:
				var r := _celula(i)
				var c: int = marca[i]
				var dentro := Rect2(r.position + Vector2(1, 1), Vector2(13, 13))
				draw_rect(dentro, Guildas.CORES[c] if c else Color8(0, 0, 0))
				if c == 0:
					draw_line(dentro.position, dentro.end, Color8(70, 70, 70))
					draw_line(Vector2(dentro.end.x, dentro.position.y), Vector2(dentro.position.x, dentro.end.y), Color8(70, 70, 70))
			for i in 16:
				var r := _paleta(i)
				var dentro := Rect2(r.position + Vector2(1, 1), Vector2(18, 18))
				draw_rect(dentro, Guildas.CORES[i] if i else Color8(0, 0, 0))
				if i == 0:
					draw_line(dentro.position, dentro.end, Color8(110, 110, 110))
					draw_line(Vector2(dentro.end.x, dentro.position.y), Vector2(dentro.position.x, dentro.end.y), Color8(110, 110, 110))
				if i == cor:
					draw_rect(r, Color.WHITE, false, 1.0)
			draw_rect(Rect2(16, 231, 23, 23), Guildas.CORES[cor] if cor else Color8(0, 0, 0))
			draw_rect(Rect2(16, 231, 23, 23), Color8(200, 200, 200), false, 1.0)
			_texto(f, Vector2(50, 240), DicaItem.t(183), 0, Color8(230, 230, 230))
			_texto(f, Vector2(50, 255), DicaItem.t(184), 0, Color8(230, 230, 230))
			_botao(_tex.btn_pequeno, _btn_voltar(), 64, DicaItem.t(1306))
			_botao(_tex.btn_pequeno, _btn_seguir(), 64, DicaItem.t(1305))
		RESUMO:
			draw_rect(Rect2(70, 70, 52, 52), Color8(170, 140, 60), false, 1.0)
			draw_texture_rect(_tex_marca, Rect2(72, 72, 48, 48), false)
			_texto(f, Vector2(0, 150), "%s : %s" % [DicaItem.t(182), _nome.text], L, Color.WHITE)
			_botao(_tex.btn_pequeno, _btn_voltar(), 64, DicaItem.t(1306))
			_botao(_tex.btn_pequeno, _btn_seguir(), 64, DicaItem.t(1305))


func _botao_sair() -> void:
	var s := _sair()
	draw_texture_rect_region(_tex.inv_sair, s, Rect2(0, 29 * (1 if s.has_point(_mouse) else 0), 36, 29))


func _botao(t: Texture2D, r: Rect2, w: int, txt: String) -> void:
	draw_texture_rect_region(t, r, Rect2(0, 29 * (1 if r.has_point(_mouse) else 0), w, 29))
	_texto(get_theme_default_font(), Vector2(r.position.x, r.position.y + 18), txt, r.size.x, Color.WHITE)


func _texto(f: Font, p: Vector2, t: String, largura: float, cor_t: Color) -> void:
	var al := HORIZONTAL_ALIGNMENT_CENTER if largura > 0 else HORIZONTAL_ALIGNMENT_LEFT
	var w := largura if largura > 0 else -1.0
	draw_string_outline(f, p, t, al, w, 10, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, w, 10, cor_t)


func clicar(p: Vector2, direito := false) -> void:
	match passo:
		INFO:
			if _btn_criar().has_point(p):
				avancar()
			elif _sair().has_point(p):
				fechar()
		MARCA:
			for i in 64:
				if _celula(i).has_point(p):
					pintar(i, 0 if direito else cor)
					_pintando = 0 if direito else cor
					return
			for i in 16:
				if _paleta(i).has_point(p):
					cor = i
					queue_redraw()
					return
			if _btn_voltar().has_point(p):
				voltar()
			elif _btn_seguir().has_point(p):
				avancar()
		RESUMO:
			if _btn_voltar().has_point(p):
				voltar()
			elif _btn_seguir().has_point(p):
				avancar()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		if _pintando >= 0 and passo == MARCA:
			for i in 64:
				if _celula(i).has_point(ev.position) and marca[i] != _pintando:
					pintar(i, _pintando)
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if ev.pressed:
			clicar(ev.position, ev.button_index == MOUSE_BUTTON_RIGHT)
		else:
			_pintando = -1
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()
