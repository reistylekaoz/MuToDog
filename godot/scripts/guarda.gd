class_name Guarda
extends Loja
# Bau (CNewUIStorageInventory) e Maquina do Caos (CNewUIMixInventory) do S6, no lugar da
# loja, colados a esquerda do inventario. Bau: grade 8 x 15 e o zen guardado, com campo e
# botoes pra guardar e tirar. Maquina do Caos: grade 8 x 4 e o botao Combinar (o OpenMU
# acha a receita pelos itens). Item da mochila na mao solto na grade guarda; clique num
# item da grade manda ele de volta pra mochila.

signal guardar(de_inv: int, para: int)
signal retirar(slot: int)
signal zen_guardar(valor: int)
signal zen_tirar(valor: int)
signal combinar

var modo := "bau"          # "bau" ou "caos"
var zen_bau := 0
var aviso := ""            # resultado da ultima mistura
var esperando := -1        # slot da grade que mandei mover
var _campo: LineEdit


func _ready() -> void:
	super._ready()
	_campo = LineEdit.new()
	_campo.placeholder_text = "quanto"
	_campo.position = Vector2(22, 352)
	_campo.size = Vector2(70, 16)
	_campo.add_theme_font_size_override("font_size", 9)
	_campo.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	# caixa baixinha (o tema padrao deixa o campo com o dobro da altura e cobre a ajuda)
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	caixa.border_color = Color(0.6, 0.5, 0.3)
	caixa.set_border_width_all(1)
	caixa.set_content_margin_all(2)
	caixa.content_margin_left = 4
	for k in ["normal", "focus", "read_only"]:
		_campo.add_theme_stylebox_override(k, caixa)
	_campo.custom_minimum_size = Vector2(70, 16)
	add_child(_campo)
	_campo.set_deferred("size", Vector2(70, 16))


func linhas() -> int:
	return 15 if modo == "bau" else 4


func abrir_guarda(m: String, nome_npc: String, lista: Dictionary) -> void:
	modo = m
	aviso = ""
	esperando = -1
	_campo.visible = modo == "bau"
	_campo.text = ""
	abrir(nome_npc, lista)


func entrou(slot: int, it: Dictionary) -> void:
	if esperando >= 0 and esperando != slot:
		itens.erase(esperando)
	esperando = -1
	itens[slot] = it
	queue_redraw()


func saiu(slot: int) -> void:
	itens.erase(slot)
	esperando = -1
	queue_redraw()


# --- grade ----------------------------------------------------------------------

func _ocupado(ignorar: int) -> Array:
	var o := []
	o.resize(COLUNAS * linhas())
	o.fill(false)
	for s in itens:
		if s == ignorar:
			continue
		var c := casa(s)
		var t := ItensMU.tamanho(itens[s])
		for y in t.y:
			for x in t.x:
				if c.x + x < COLUNAS and c.y + y < linhas():
					o[(c.y + y) * COLUNAS + c.x + x] = true
	return o


func cabe(it: Dictionary, c: Vector2i, ignorar := -1) -> bool:
	var t := ItensMU.tamanho(it)
	if c.x < 0 or c.y < 0 or c.x + t.x > COLUNAS or c.y + t.y > linhas():
		return false
	var o := _ocupado(ignorar)
	for y in t.y:
		for x in t.x:
			if o[(c.y + y) * COLUNAS + c.x + x]:
				return false
	return true


func lugar_livre(it: Dictionary) -> int:
	for y in linhas():
		for x in COLUNAS:
			if cabe(it, Vector2i(x, y)):
				return y * COLUNAS + x
	return -1


func _destino(it: Dictionary) -> Vector2i:
	var t := ItensMU.tamanho(it)
	var q := (_mouse - GRADE - Vector2(t - Vector2i.ONE) * CASA / 2.0) / CASA
	return Vector2i(floori(q.x), floori(q.y))


# --- botoes (na barra de baixo da janela) -----------------------------------------

func _botoes() -> Dictionary:
	if modo == "bau":
		return {"guardar": Rect2(96, 350, 44, 20), "tirar": Rect2(142, 350, 30, 20)}
	return {"combinar": Rect2(55, 340, 80, 24)}


func _botao(r: Rect2, t: String, f: Font) -> void:
	var sob := r.has_point(_mouse)
	draw_rect(r, Color(0.35, 0.25, 0.1, 0.95) if sob else Color(0.2, 0.15, 0.08, 0.95))
	draw_rect(r, Color(0.8, 0.65, 0.3), false, 1.0)
	_texto(f, r.position + Vector2(0, r.size.y / 2 + 3), t, r.size.x, 9, Color(1, 0.9, 0.6))


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 16), "Bau" if modo == "bau" else "Maquina do Caos", L, 11, Color(1, 0.9, 0.7))
	_texto(f, Vector2(0, 34), npc, L, 9, Color(0.85, 0.85, 0.9))
	var n := linhas()
	for y in n:
		for x in COLUNAS:
			draw_texture_rect(_tex.inv_casa, Rect2(GRADE + Vector2(x, y) * CASA, Vector2(21, 21)), false)
	_moldura(Rect2(GRADE, Vector2(COLUNAS, n) * CASA))
	var sob := slot_sob_mouse()
	for s in itens:
		var r := _rect(s)
		var cor := Color(0.45, 0.35, 0.15, 0.45) if s == sob else Color(0.25, 0.2, 0.45, 0.35)
		if s == esperando:
			cor = Color(0.5, 0.5, 0.5, 0.3)
		draw_rect(r.grow(-1), cor)
		ItensMU.desenhar(self, itens[s], r.grow(-1))
		if itens[s].grupo == 14 and itens[s].durabilidade > 1:
			_texto(f, r.position + Vector2(0, r.size.y - 2), str(itens[s].durabilidade), r.size.x - 2, 7, Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	var na_mao := inv != null and inv.na_mao >= 0 and inv.itens.has(inv.na_mao)
	if na_mao and Rect2(GRADE, Vector2(COLUNAS, n) * CASA).has_point(_mouse):
		var it: Dictionary = inv.itens[inv.na_mao]
		var d := _destino(it)
		var ok := cabe(it, d)
		draw_rect(Rect2(GRADE + Vector2(d) * CASA, Vector2(ItensMU.tamanho(it)) * CASA), Color(0.2, 0.8, 0.3, 0.3) if ok else Color(0.9, 0.2, 0.2, 0.3))
	var y0 := 375.0
	if modo == "bau":
		_texto(f, Vector2(22, 345), "Zen no bau: %s" % ItemChao._milhar(zen_bau), 150, 9, Color(1, 0.86, 0.45), HORIZONTAL_ALIGNMENT_LEFT)
	else:
		_texto(f, Vector2(0, GRADE.y + n * CASA + 22), "Ponha os itens da receita e clique Combinar.", L, 8, Color(0.85, 0.85, 0.9))
		_texto(f, Vector2(0, GRADE.y + n * CASA + 36), "Ex.: item +9 com Bless, Soul e Chaos vira +10.", L, 8, Color(0.7, 0.7, 0.75))
		if aviso != "":
			_texto(f, Vector2(0, 325), aviso, L, 9, Color(0.6, 1, 0.6) if aviso.begins_with("Deu certo") else Color(1, 0.6, 0.4))
	for k in _botoes():
		_botao(_botoes()[k], {"guardar": "Guardar", "tirar": "Tirar", "combinar": "Combinar"}[k], f)
	var ajuda := "Solte aqui pra guardar" if na_mao else "Clique no item pra levar pra mochila"
	_texto(f, Vector2(0, y0), ajuda, L, 9, Color(1, 0.86, 0.45))
	var linha := 1 if Rect2(13, 391, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 391, 36, 29), Rect2(0, 29 * linha, 36, 29))
	_texto(f, Vector2(52, 410), "Fechar (Esc)", 120, 9, Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	if sob >= 0 and not na_mao:
		DicaItem.mostrar(self, f, DicaItem.linhas(itens[sob]), _rect(sob))
	else:
		DicaItem.esconder(self)



func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		if inv and inv.na_mao >= 0:
			inv.mouse_fora(get_global_transform() * ev.position)
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		_mouse = ev.position
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_clique()
		elif ev.button_index == MOUSE_BUTTON_RIGHT and inv:
			inv.soltar()
		accept_event()
		queue_redraw()


func _valor() -> int:
	var t := _campo.text.strip_edges().replace(".", "")
	return int(t) if t.is_valid_int() else 0


func _clique() -> void:
	if Rect2(13, 391, 36, 29).has_point(_mouse) or Rect2(160, 2, 26, 22).has_point(_mouse):
		fechar.emit()
		return
	var b := _botoes()
	for k in b:
		if b[k].has_point(_mouse):
			match k:
				"guardar": zen_guardar.emit(_valor())
				"tirar": zen_tirar.emit(_valor())
				"combinar":
					aviso = "Combinando..."
					combinar.emit()
			return
	if esperando >= 0 or (inv and inv.esperando >= 0):
		return
	if inv and inv.na_mao >= 0 and inv.itens.has(inv.na_mao):
		var it: Dictionary = inv.itens[inv.na_mao]
		var d := _destino(it)
		if not cabe(it, d):
			return
		var de := inv.na_mao
		inv.esperando = de
		inv.soltar()
		guardar.emit(de, d.y * COLUNAS + d.x)
		return
	var s := slot_sob_mouse()
	if s >= 0:
		esperando = s
		retirar.emit(s)
