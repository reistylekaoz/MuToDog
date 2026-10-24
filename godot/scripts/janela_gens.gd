class_name JanelaGens
extends Control
# Janela do Gens do cliente S6 (CNewUIGensRanking, tecla B), 190x429 na direita. Sem Gens a tecla
# nao abre (3094 no registro). A marca do titulo no quadro de cima (newui_gens_rankback), o nome do
# Gens, o titulo (3104, 14 nomes separados por #), a posicao no ranking, a contribuicao, quanto falta
# pro proximo titulo (3097) e a descricao dos premios (3101, 3102). Abrir pede o F8 0B (info).

const PASTA := "res://dados/hud/"
const L := 190.0
const A := 429.0
const MARCA := Vector2(50, 69)   # GENSMARK_WIDTH x HEIGHT: 5 por linha na folha de 256

var gens := 0           # 1 Duprian, 2 Vanert
var titulo := 0         # 1 Grand Duke ... 14 Private
var posicao := 0
var contribuicao := 0
var falta := 0
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "gens_fundo_rank", "cha_caixa",
			"gens_marca_d", "gens_marca_v", "tab_ce", "tab_cd", "tab_be", "tab_bd", "tab_c", "tab_b", "tab_e", "tab_d"]:
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


func definir(info: Dictionary) -> void:
	gens = info.gens
	titulo = info.titulo
	posicao = info.posicao
	contribuicao = maxi(info.contribuicao, 0)
	falta = info.falta
	queue_redraw()


static func nome_gens(g: int) -> String:
	return DicaItem.t(3092) if g == 1 else (DicaItem.t(3093) if g == 2 else "")


# GetTitleName: fora de 1 a 14 vale o ultimo (Private)
static func nome_titulo(t: int) -> String:
	var l := DicaItem.t(3104).split("#")
	return l[clampi(t, 1, l.size()) - 1] if not l.is_empty() else ""


# RanderMark: a folha tem os 14 titulos do Private (0) ao Grand Duke (13), 5 por linha
static func regiao_marca(t: int) -> Rect2:
	var i := 14 - clampi(t if t >= 1 and t <= 14 else 14, 1, 14)
	return Rect2((i % 5) * MARCA.x, (i / 5) * MARCA.y, MARCA.x, MARCA.y)


func _sair() -> Rect2:
	return Rect2(13, 392, 36, 29)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	draw_texture_rect(_tex.gens_fundo_rank, Rect2(13, 60, 170, 88), false)
	if gens == 1 or gens == 2:
		var folha: Texture2D = _tex.gens_marca_d if gens == 1 else _tex.gens_marca_v
		draw_texture_rect_region(folha, Rect2(Vector2(13 + (85 - 50) * 0.5, 60 + (88 - 69) * 0.5), MARCA), regiao_marca(titulo))
	_quadro(Rect2(13, 250, 168, 140), 60, 20)
	draw_texture_rect(_tex.cha_caixa, Rect2(13, 151, 170, 21), false)
	draw_texture_rect(_tex.cha_caixa, Rect2(13, 175, 170, 21), false)
	var f := get_theme_default_font()
	var amarelo := Color8(230, 230, 0)
	_texto(f, Vector2(0, 15), DicaItem.t(3090), L, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_texto(f, Vector2(102, 90), DicaItem.t(3091), 0, Color8(246, 209, 73), HORIZONTAL_ALIGNMENT_LEFT, true)
	_texto(f, Vector2(102, 110), nome_gens(gens), 0, Color.WHITE)
	_texto(f, Vector2(100, 134), DicaItem.t(3095), 0, Color.WHITE)
	_texto(f, Vector2(100, 134), nome_titulo(titulo), 80, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_texto(f, Vector2(13, 157), DicaItem.t(3098), 74, amarelo, HORIZONTAL_ALIGNMENT_CENTER, true)
	_texto(f, Vector2(0, 157), str(posicao) if posicao > 0 else "-", L - 20, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_texto(f, Vector2(13, 180), DicaItem.t(3096), 74, amarelo, HORIZONTAL_ALIGNMENT_CENTER, true)
	_texto(f, Vector2(0, 180), str(contribuicao), L - 20, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	if falta > 0:
		var y := 200.0
		for l in _quebrar(f, DicaItem.t(3097) % falta, 140):
			_texto(f, Vector2(20, y), l, 180, Color.WHITE)
			y += 15
	_texto(f, Vector2(13, 258), DicaItem.t(3100), 58, amarelo, HORIZONTAL_ALIGNMENT_CENTER, true)
	var y2 := 284.0
	for n in [3101, 3102]:
		for parte in DicaItem.t(n).split("##"):
			for l in _quebrar(f, parte.strip_edges(), 150):
				_texto(f, Vector2(20, y2), l, 150, Color.WHITE)
				y2 += 13
			y2 += 4
	var s := _sair()
	draw_texture_rect_region(_tex.inv_sair, s, Rect2(0, 29 * (1 if s.has_point(_mouse) else 0), 36, 29))


# RenderInfoFrame: fundo escuro com a aba do titulo e a moldura de cantos da mochila
func _quadro(r: Rect2, tw: float, th: float) -> void:
	var fundo := Color(0, 0, 0, 0.6)
	draw_rect(Rect2(r.position.x + 3, r.position.y + 2, tw - 8, th), fundo)
	draw_rect(Rect2(r.position.x + 3, r.position.y + 2 + th, r.size.x - 7, r.size.y - th - 7), fundo)
	var x := r.position.x
	var y := r.position.y
	draw_texture_rect(_tex.tab_ce, Rect2(x, y, 14, 14), false)
	draw_texture_rect(_tex.tab_cd, Rect2(x + tw - 14, y, 14, 14), false)
	draw_texture_rect(_tex.tab_cd, Rect2(x + r.size.x - 14, y + th, 14, 14), false)
	draw_texture_rect(_tex.tab_be, Rect2(x, y + r.size.y - 14, 14, 14), false)
	draw_texture_rect(_tex.tab_bd, Rect2(x + r.size.x - 14, y + r.size.y - 14, 14, 14), false)
	draw_texture_rect(_tex.tab_c, Rect2(x + 6, y, tw - 12, 14), false)
	draw_texture_rect(_tex.tab_d, Rect2(x + tw - 14, y + 6, 14, th - 6), false)
	draw_texture_rect(_tex.tab_c, Rect2(x + tw - 5, y + th, r.size.x - tw - 6, 14), false)
	draw_texture_rect(_tex.tab_d, Rect2(x + r.size.x - 14, y + th + 6, 14, r.size.y - th - 14), false)
	draw_texture_rect(_tex.tab_b, Rect2(x + 6, y + r.size.y - 14, r.size.x - 12, 14), false)
	draw_texture_rect(_tex.tab_e, Rect2(x, y + 6, 14, r.size.y - 14), false)


func _quebrar(f: Font, t: String, largura: float) -> Array[String]:
	var linhas: Array[String] = []
	var atual := ""
	for p in t.split(" ", false):
		var tenta := p if atual == "" else atual + " " + p
		if atual != "" and f.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > largura:
			linhas.append(atual)
			atual = p
		else:
			atual = tenta
	if atual != "":
		linhas.append(atual)
	return linhas


# y do original e o topo da linha; aqui vira a base (+10)
func _texto(f: Font, p: Vector2, t: String, largura: float, cor: Color, al := HORIZONTAL_ALIGNMENT_LEFT, negrito := false) -> void:
	var b := p + Vector2(0, 10)
	draw_string_outline(f, b, t, al, largura if largura > 0 else -1, 10, 2, Color(0, 0, 0, 0.9))
	draw_string(f, b, t, al, largura if largura > 0 else -1, 10, cor)
	if negrito:
		draw_string(f, b + Vector2(0.6, 0), t, al, largura if largura > 0 else -1, 10, cor)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT and (_sair().has_point(ev.position) or Rect2(160, 2, 26, 22).has_point(ev.position)):
			visible = false
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()
