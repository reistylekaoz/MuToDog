class_name JanelaEvento
extends Control
# Janela de entrada dos eventos do S6: Devil Square pelo Charon (CNewUIEnterDevilSquare, NPC janela 4)
# e Blood Castle pelo Mensageiro do Arcanjo (CNewUIEnterBloodCastle, janela 6). 190 x 429 colada na
# direita, o texto do NPC em cima e um botao grande (180x29, 33 de passo) por nivel. So o botao do
# nivel do heroi fica aceso; quem tem master level so entra no ultimo. DK, DL e RF tem a tabela
# propria (entram mais cedo). O Devil Square manda o indice do botao, o Blood Castle o indice + 1.

signal entrar(nivel: int)
signal fechar

const L := 190.0
const A := 429.0
const LIMITES := {
	"ds": [[[15, 130], [131, 180], [181, 230], [231, 280], [281, 330], [331, 400]],
		[[15, 110], [111, 160], [161, 210], [211, 260], [261, 310], [311, 400]]],
	"bc": [[[15, 80], [81, 130], [131, 180], [181, 230], [231, 280], [281, 330], [331, 400]],
		[[10, 60], [61, 110], [111, 160], [161, 210], [211, 260], [261, 310], [311, 400]]],
}

var modo := "ds"
var ativo := -1
var _botoes: Array[String] = []
var _linhas: Array[String] = []
var _tam := 10
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "btn_grande"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
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


# OpenningProcess: classe base (indice do Boneco.CLASSES), nivel e se ja e master
func abrir(qual: String, classe_base: int, nivel: int, master: bool) -> void:
	modo = qual
	var tabela: Array = LIMITES[modo][1 if classe_base in [1, 4, 6] else 0]
	ativo = tabela.size() if master else 0
	if not master:
		for i in tabela.size():
			if nivel >= tabela[i][0] and nivel <= tabela[i][1]:
				ativo = i
				break
	_botoes.clear()
	for i in tabela.size():
		_botoes.append(DicaItem.t(645 if modo == "ds" else 847, [i + 1, tabela[i][0], tabela[i][1]]))
	_botoes.append(DicaItem.t(1778 if modo == "ds" else 1779, [tabela.size() + 1]))
	if modo == "ds":
		_tam = 10
		_linhas.clear()
		for n in range(670, 676):
			_linhas.append(DicaItem.t(n))
		# todas no mesmo tamanho: o maior em que a linha mais comprida cabe
		for t in _linhas:
			while _tam > 7 and get_theme_default_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, _tam).x > L - 10:
				_tam -= 1
	else:
		# SeparateTextIntoLines: a fala cabe em 3 linhas antes do primeiro botao (125)
		_tam = 10
		_linhas = _quebrar(get_theme_default_font(), DicaItem.t(832), L - 10)
		while _linhas.size() > 3 and _tam > 7:
			_tam -= 1
			_linhas = _quebrar(get_theme_default_font(), DicaItem.t(832), L - 10)
	visible = true
	queue_redraw()


func _quebrar(f: Font, t: String, largura: float) -> Array[String]:
	var linhas: Array[String] = []
	var atual := ""
	for p in t.split(" ", false):
		var tenta := p if atual == "" else atual + " " + p
		if atual != "" and f.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, _tam).x > largura:
			linhas.append(atual)
			atual = p
		else:
			atual = tenta
	if atual != "":
		linhas.append(atual)
	return linhas


func _rect_botao(i: int) -> Rect2:
	return Rect2(6, (155.0 if modo == "ds" else 125.0) + 33 * i, 180, 29)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, A - 64 - 45), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, A - 64 - 45), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(20, 22), DicaItem.t(39 if modo == "ds" else 846), 150, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var y0 := 45.0 if modo == "ds" else 55.0
	var passo := 15.0 if modo == "ds" else 20.0
	for i in _linhas.size():
		_texto(f, Vector2(3, y0 + passo * i + 10), _linhas[i], L - 6, _tam, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	for i in _botoes.size():
		var r := _rect_botao(i)
		var aceso := i == ativo
		var estado := 0
		if aceso and r.has_point(_mouse):
			estado = 2 if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1
		draw_texture_rect_region(_tex.btn_grande, r, Rect2(0, 29 * estado, 180, 29),
			Color.WHITE if aceso else Color(0.55, 0.55, 0.55))
		_texto(f, Vector2(r.position.x, r.position.y + 19), _botoes[i], r.size.x, 10,
			Color.WHITE if aceso else Color8(150, 150, 150), HORIZONTAL_ALIGNMENT_CENTER)
	var sair := 1 if Rect2(13, 392, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 392, 36, 29), Rect2(0, 29 * sair, 36, 29))
	_texto(f, Vector2(52, 411), "Fechar (Esc)", 120, 9, Color(0.75, 0.75, 0.8))


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# a fonte do cliente e mais estreita: a frase que nao cabe desce de tamanho ate caber
	while tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura - 4:
		tam -= 1
	draw_string_outline(f, p, t, al, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, largura, tam, cor)


# BtnProcess: o botao aceso manda o pedido e fecha
func clicar(i: int) -> void:
	if i != ativo or i < 0:
		return
	entrar.emit(i if modo == "ds" else i + 1)
	fechar.emit()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		queue_redraw()
		if not ev.pressed:
			for i in _botoes.size():
				if _rect_botao(i).has_point(ev.position):
					clicar(i)
			if Rect2(13, 392, 36, 29).has_point(ev.position):
				fechar.emit()
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()
