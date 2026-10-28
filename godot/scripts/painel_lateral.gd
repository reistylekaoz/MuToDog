class_name PainelLateral
extends Control
# Janela de 190x429 na direita da tela, a moldura do inventario do S6 (newui_msgbox_back, newui_item_back01 ou 04,
# 02-L, 02-R e 03, o X de sair em 13,391). Base das janelas da rodada 25: comandos de chat (J), Gatekeeper da
# Land of Trials e Golden Archer. Cada uma desenha em _conteudo() e responde em _clique().

signal fechou

const PASTA := "res://dados/hud/"
const L := 190.0
const A := 429.0

static var tex := {}

var topo := "inv_topo01"
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _botoes := {}            # nome -> [Rect2, ativo] desenhados neste quadro


static func carregar() -> void:
	if not tex.is_empty():
		return
	for n in ["inv_fundo", "inv_topo01", "inv_topo04", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "btn_vazio",
			"btn_pequeno", "win_check"]:
		tex[n] = load(PASTA + n + ".png")
	for n in ["botao", "seta_cima", "seta_baixo"]:
		tex[n] = load(PASTA + "castelo/" + n + ".png")


func _ready() -> void:
	carregar()
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


func fechar() -> void:
	if visible:
		visible = false
		fechou.emit()


func _sair() -> Rect2:
	return Rect2(13, 391, 36, 29)


func _draw() -> void:
	_botoes.clear()
	draw_texture_rect(tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(tex[topo], Rect2(0, 0, 190, 64), false)
	draw_texture_rect(tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var s := _sair()
	draw_texture_rect_region(tex.inv_sair, s, Rect2(0, 29 * (1 if s.has_point(_mouse) else 0), 36, 29))
	_conteudo()


func _conteudo() -> void:
	pass


func _clique(_p: Vector2) -> void:
	pass


func _roda(_passo: int) -> void:
	pass


# texto com a borda escura do RenderText; largura > 0 centraliza (RT3_SORT_CENTER) e aperta o que nao cabe
func texto(p: Vector2, t: String, largura: float, cor := Color.WHITE, negrito := false, al := -1) -> void:
	var f := get_theme_default_font()
	var alinha: int = al if al >= 0 else (HORIZONTAL_ALIGNMENT_CENTER if largura > 0 else HORIZONTAL_ALIGNMENT_LEFT)
	var w := largura if largura > 0 else -1.0
	var tam := 10
	while largura > 0 and tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura:
		tam -= 1
	draw_string_outline(f, p, t, alinha, w, tam, 3 if negrito else 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, alinha, w, tam, cor)
	if negrito:
		draw_string(f, p + Vector2(0.6, 0), t, alinha, w, tam, cor)


func largura_texto(t: String) -> float:
	return get_theme_default_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x


# CNewUIButton com a textura de 3 estados (em pe, mouse em cima, apertado); a altura de cada estado e a textura / 3
func botao(nome: String, r: Rect2, legenda: String, ativo := true, img := "botao") -> void:
	_botoes[nome] = [r, ativo]
	var t: Texture2D = tex[img]
	var h := t.get_height() / 3.0
	var linha := 1 if ativo and r.has_point(_mouse) else 0
	draw_texture_rect_region(t, r, Rect2(0, h * linha, t.get_width(), h), Color.WHITE if ativo else Color(0.4, 0.4, 0.4))
	texto(Vector2(r.position.x, r.position.y + r.size.y / 2 + 4), legenda, r.size.x, Color.WHITE if ativo else Color(0.4, 0.4, 0.4))


# RenderCheckBox do S6: quadrado de 9x9 e a marca dentro
func caixa_marcar(p: Vector2, marcado: bool) -> void:
	draw_rect(Rect2(p, Vector2(10, 10)), Color8(146, 134, 121), false, 1.0)
	if marcado:
		draw_texture_rect(tex.win_check, Rect2(p + Vector2(2.5, 2.5), Vector2(5, 5)), false)


static func zen(v: int) -> String:
	var s := str(absi(v))
	var r := ""
	while s.length() > 3:
		r = "," + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + r


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if _sair().has_point(ev.position):
				fechar()
			else:
				_clique(ev.position)
			queue_redraw()
		elif ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_roda(-1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()


# o botao em que o clique caiu (so os ativos)
func botao_em(p: Vector2) -> String:
	for n in _botoes:
		if _botoes[n][1] and _botoes[n][0].has_point(p):
			return n
	return ""
