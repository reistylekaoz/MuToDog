class_name Loja
extends Control
# Janela da loja do NPC (CNewUINPCShop do S6): 190 x 429 na tela de 640, colada a
# esquerda do inventario. Grade 8 x 15 com o que o NPC vende. Clique num item compra
# (vai pro primeiro lugar livre da mochila, o servidor escolhe); item do inventario
# na mao solto em cima da loja vende. Fecha no botao, no Esc ou andando pra longe.

signal comprar(slot: int)
signal vender(slot: int)
signal fechar

const L := 190.0
const A := 429.0
const GRADE := Vector2(15, 50)
const CASA := 20.0
const COLUNAS := 8
const LINHAS := 15

var itens := {}            # slot da loja -> item (cliente.gd item_de)
var npc := ""
var inv: Inventario
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "inv_casa", "inv_sair",
			"tab_ce", "tab_cd", "tab_be", "tab_bd", "tab_c", "tab_b", "tab_e", "tab_d"]:
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
	position = Vector2(v.x - 2 * L * _esc, 0)
	queue_redraw()


func abrir(nome_npc: String, lista: Dictionary) -> void:
	npc = nome_npc
	itens = lista
	visible = true
	queue_redraw()


func casa(slot: int) -> Vector2i:
	return Vector2i(slot % COLUNAS, slot / COLUNAS)


func _rect(slot: int) -> Rect2:
	var t := ItensMU.tamanho(itens[slot])
	return Rect2(GRADE + Vector2(casa(slot)) * CASA, Vector2(t) * CASA)


func slot_sob_mouse() -> int:
	for s in itens:
		if _rect(s).has_point(_mouse):
			return s
	return -1


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 16), "Loja", L, 11, Color(1, 0.9, 0.7))
	_texto(f, Vector2(0, 34), npc, L, 9, Color(0.85, 0.85, 0.9))
	for y in LINHAS:
		for x in COLUNAS:
			draw_texture_rect(_tex.inv_casa, Rect2(GRADE + Vector2(x, y) * CASA, Vector2(21, 21)), false)
	_moldura(Rect2(GRADE, Vector2(COLUNAS, LINHAS) * CASA))
	var sob := slot_sob_mouse()
	for s in itens:
		var r := _rect(s)
		draw_rect(r.grow(-1), Color(0.45, 0.35, 0.15, 0.45) if s == sob else Color(0.25, 0.2, 0.45, 0.35))
		ItensMU.desenhar(self, itens[s], r.grow(-1))
		if itens[s].grupo == 14 and itens[s].durabilidade > 1:
			_texto(f, r.position + Vector2(0, r.size.y - 2), str(itens[s].durabilidade), r.size.x - 2, 7, Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	var vendendo := inv != null and inv.na_mao >= 0 and inv.itens.has(inv.na_mao)
	if vendendo and Rect2(Vector2.ZERO, size).has_point(_mouse):
		draw_rect(Rect2(GRADE, Vector2(COLUNAS, LINHAS) * CASA), Color(0.9, 0.75, 0.2, 0.18))
	var ajuda := "Solte aqui pra vender" if vendendo else "Clique no item pra comprar"
	_texto(f, Vector2(0, 375), ajuda, L, 9, Color(1, 0.86, 0.45))
	var linha := 1 if Rect2(13, 391, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 391, 36, 29), Rect2(0, 29 * linha, 36, 29))
	_texto(f, Vector2(52, 410), "Fechar (Esc)", 120, 9, Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	if sob >= 0 and not vendendo:
		var preco := DicaItem._linha(DicaItem.t(62, [DicaItem._milhar(ItensMU.preco(itens[sob]))]), Color8(255, 204, 26))
		DicaItem.mostrar(self, f, DicaItem.linhas(itens[sob], [preco]), _rect(sob))
	else:
		DicaItem.esconder(self)


func _moldura(r: Rect2) -> void:
	var x0 := r.position.x - 4
	var y0 := r.position.y - 3
	var x1 := r.end.x - 9
	var y1 := r.end.y - 8
	draw_texture_rect(_tex.tab_c, Rect2(x0 + 14, y0, x1 - x0 - 14, 14), false)
	draw_texture_rect(_tex.tab_b, Rect2(x0 + 14, y1, x1 - x0 - 14, 14), false)
	draw_texture_rect(_tex.tab_e, Rect2(x0, y0 + 14, 14, y1 - y0 - 14), false)
	draw_texture_rect(_tex.tab_d, Rect2(x1, y0 + 14, 14, y1 - y0 - 14), false)
	draw_texture_rect(_tex.tab_ce, Rect2(x0, y0, 14, 14), false)
	draw_texture_rect(_tex.tab_cd, Rect2(x1, y0, 14, 14), false)
	draw_texture_rect(_tex.tab_be, Rect2(x0, y1, 14, 14), false)
	draw_texture_rect(_tex.tab_bd, Rect2(x1, y1, 14, 14), false)


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, al := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string_outline(f, p, t, al, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, largura, tam, cor)



func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		if inv and inv.na_mao >= 0:
			inv.mouse_fora(get_global_transform() * ev.position)
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		_mouse = ev.position
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if Rect2(13, 391, 36, 29).has_point(ev.position) or Rect2(160, 2, 26, 22).has_point(ev.position):
				fechar.emit()
			elif inv and inv.na_mao >= 0:
				var s := inv.na_mao
				inv.esperando = s
				inv.soltar()
				vender.emit(s)
			else:
				var s := slot_sob_mouse()
				if s >= 0:
					comprar.emit(s)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and inv:
			inv.soltar()
		accept_event()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()
