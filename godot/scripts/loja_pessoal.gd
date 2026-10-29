class_name LojaPessoal
extends Loja
# Loja pessoal do S6, colada a esquerda do inventario:
# - "minha" (CNewUIMyShopInventory, tecla S): titulo, grade 8 x 4 e os botoes sair, abrir e
#   fechar. Os itens da loja moram na mochila do servidor (slots 204 a 235). Item da mochila
#   solto na grade pede o preco e entra; botao direito num item troca o preco; clique leva de
#   volta pra mochila. Com a loja aberta nao da pra mexer (o servidor recusa).
# - "outro" (CNewUIPurchaseShopInventory): titulo da loja em verde e a grade de quem vende;
#   clique num item pede confirmacao e compra.

signal por(de_inv: int, para: int, preco: int)
signal tirar(slot: int)
signal preco(slot: int, valor: int)
signal abrir_minha(titulo: String)
signal fechar_minha
signal comprar_item(slot: int)

const PRIMEIRO := 204       # InventoryConstants.FirstStoreItemSlotIndex
const GRADE_LOJA := Vector2(16, 90)
const LINHAS_LOJA := 4

var modo := "minha"         # "minha" ou "outro"
var aberta := false         # a minha loja esta aberta no servidor
var titulo := ""
var dono := ""              # modo outro: nome de quem vende
var dono_id := -1
var precos := {}            # slot da mochila (204+) -> preco, guardado por personagem
var esperando := -1
var _campo: LineEdit
var _caixa: PanelContainer  # pergunta do preco ou da compra
var _pergunta := {}


func _ready() -> void:
	super._ready()
	for n in ["bt_abrir_loja", "bt_fechar_loja", "titulo_loja"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	_campo = _novo_campo(Vector2(20, 55), Vector2(150, 16), "nome da loja")
	_campo.max_length = 26
	add_child(_campo)
	_campo.set_deferred("size", Vector2(150, 16))


func _novo_campo(p: Vector2, t: Vector2, dica: String) -> LineEdit:
	var c := LineEdit.new()
	c.placeholder_text = dica
	c.position = p
	c.add_theme_font_size_override("font_size", 9)
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	caixa.border_color = Color(0.6, 0.5, 0.3)
	caixa.set_border_width_all(1)
	caixa.set_content_margin_all(2)
	caixa.content_margin_left = 4
	for k in ["normal", "focus", "read_only"]:
		c.add_theme_stylebox_override(k, caixa)
	c.custom_minimum_size = t
	return c


func abrir_minha_loja() -> void:
	modo = "minha"
	esperando = -1
	_campo.visible = true
	_campo.editable = not aberta
	if _campo.text == "":
		_campo.text = titulo
	_fechar_pergunta()
	visible = true
	queue_redraw()


func abrir_de_outro(id: int, nome: String, t: String, lista: Dictionary) -> void:
	modo = "outro"
	dono_id = id
	dono = nome
	titulo = t
	itens = lista
	_campo.visible = false
	_fechar_pergunta()
	visible = true
	queue_redraw()


func linhas() -> int:
	return LINHAS_LOJA


# itens da grade: na minha, os da mochila em 204+; na do outro, os da lista
func grade() -> Dictionary:
	if modo == "outro":
		return itens
	var g := {}
	if inv:
		for s in inv.itens:
			if s >= PRIMEIRO and s < PRIMEIRO + COLUNAS * LINHAS_LOJA:
				g[s - PRIMEIRO] = inv.itens[s]
	return g


func preco_de(i: int) -> int:
	if modo == "outro":
		return int(itens[i].get("preco", 0)) if itens.has(i) else 0
	return int(precos.get(PRIMEIRO + i, 0))


func falta_preco() -> bool:
	for i in grade():
		if preco_de(i) <= 0:
			return true
	return false


func _rect_i(g: Dictionary, i: int) -> Rect2:
	var t := ItensMU.tamanho(g[i])
	return Rect2(GRADE_LOJA + Vector2(casa(i)) * CASA, Vector2(t) * CASA)


func _sob(g: Dictionary) -> int:
	for i in g:
		if _rect_i(g, i).has_point(_mouse):
			return i
	return -1


func cabe(it: Dictionary, c: Vector2i, ignorar := -1) -> bool:
	var t := ItensMU.tamanho(it)
	if c.x < 0 or c.y < 0 or c.x + t.x > COLUNAS or c.y + t.y > LINHAS_LOJA:
		return false
	var g := grade()
	for i in g:
		if i == ignorar:
			continue
		var p := casa(i)
		var q := ItensMU.tamanho(g[i])
		if c.x < p.x + q.x and p.x < c.x + t.x and c.y < p.y + q.y and p.y < c.y + t.y:
			return false
	return true


func _destino(it: Dictionary) -> Vector2i:
	var t := ItensMU.tamanho(it)
	var q := (_mouse - GRADE_LOJA - Vector2(t - Vector2i.ONE) * CASA / 2.0) / CASA
	return Vector2i(floori(q.x), floori(q.y))


# --- desenho --------------------------------------------------------------------

func _botao_loja(r: Rect2, nome: String, ligado: bool) -> void:
	var fr := 1 if ligado and r.has_point(_mouse) else 0
	draw_texture_rect_region(_tex[nome], r, Rect2(0, 29 * fr, 36, 29), Color.WHITE if ligado else Color(0.45, 0.45, 0.45))


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	draw_texture_rect_region(_tex.titulo_loja, Rect2(12, 49, 169, 26), Rect2(0, 0, 169, 26))
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 16), "Loja pessoal", L, 11, Color8(255, 176, 73))   # 0xFF49B0FF do cliente (ABGR)
	if modo == "outro":
		_texto(f, Vector2(0, 34), dono, L, 9, Color(0.85, 0.85, 0.9))
		_texto(f, Vector2(0, 66), titulo, L, 10, Color8(0, 255, 0))
	var g := grade()
	var sob := _sob(g)
	for y in LINHAS_LOJA:
		for x in COLUNAS:
			draw_texture_rect(_tex.inv_casa, Rect2(GRADE_LOJA + Vector2(x, y) * CASA, Vector2(21, 21)), false)
	_moldura(Rect2(GRADE_LOJA, Vector2(COLUNAS, LINHAS_LOJA) * CASA))
	for i in g:
		var r := _rect_i(g, i)
		var cor := Color(0.45, 0.35, 0.15, 0.45) if i == sob else Color(0.25, 0.2, 0.45, 0.35)
		if modo == "minha" and preco_de(i) <= 0:
			cor = Color(0.6, 0.15, 0.1, 0.45)   # sem preco ainda
		if PRIMEIRO + i == esperando:
			cor = Color(0.5, 0.5, 0.5, 0.3)
		draw_rect(r.grow(-1), cor)
		ItensMU.desenhar(self, g[i], r.grow(-1))
	var na_mao := modo == "minha" and inv != null and inv.na_mao >= 0 and inv.itens.has(inv.na_mao)
	if na_mao and Rect2(GRADE_LOJA, Vector2(COLUNAS, LINHAS_LOJA) * CASA).has_point(_mouse):
		var it: Dictionary = inv.itens[inv.na_mao]
		var d := _destino(it)
		draw_rect(Rect2(GRADE_LOJA + Vector2(d) * CASA, Vector2(ItensMU.tamanho(it)) * CASA), Color(0.2, 0.8, 0.3, 0.3) if cabe(it, d) and not aberta else Color(0.9, 0.2, 0.2, 0.3))
	if modo == "minha" and aberta:
		_texto(f, Vector2(0, 200), "A loja esta aberta", L, 10, Color8(215, 138, 0))
	_texto(f, Vector2(30, 230), "Aviso", 150, 9, Color8(255, 45, 47), HORIZONTAL_ALIGNMENT_LEFT)
	var avisos := ["Confira o preco antes de", "abrir a loja. Item vendido", "nao volta."] if modo == "minha" \
		else ["Confira o preco e o item", "antes de comprar. Compra", "feita nao volta."]
	for k in avisos.size():
		_texto(f, Vector2(30, 250 + k * 12), avisos[k], 150, 8, Color8(247, 206, 77), HORIZONTAL_ALIGNMENT_LEFT)
	_texto(f, Vector2(30, 300), "Toda a venda e em zen.", 150, 8, Color8(255, 45, 47), HORIZONTAL_ALIGNMENT_LEFT)
	var ajuda := ""
	if modo == "minha":
		ajuda = "Solte um item aqui pra vender" if not aberta else "Feche a loja pra mexer nos itens"
		if not aberta and not g.is_empty():
			ajuda = "Botao direito no item muda o preco"
	else:
		ajuda = "Clique no item pra comprar"
	_texto(f, Vector2(0, 340), ajuda, L, 8, Color(1, 0.86, 0.45))
	# botoes: sair, abrir e fechar (os dois ultimos so na minha)
	var linha := 1 if Rect2(13, 391, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 391, 36, 29), Rect2(0, 29 * linha, 36, 29))
	if modo == "minha":
		_botao_loja(Rect2(53, 391, 36, 29), "bt_abrir_loja", not aberta)
		_botao_loja(Rect2(93, 391, 36, 29), "bt_fechar_loja", aberta)
		if Rect2(53, 391, 36, 29).has_point(_mouse):
			_texto(f, Vector2(_mouse.x - 30, _mouse.y - 6), "Abrir a loja", 0, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		elif Rect2(93, 391, 36, 29).has_point(_mouse):
			_texto(f, Vector2(_mouse.x - 30, _mouse.y - 6), "Fechar a loja", 0, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	if sob >= 0 and not na_mao and _caixa == null:
		var v := preco_de(sob)
		var extra := [DicaItem._linha("Preco: %s zen" % ItemChao._milhar(v) if v > 0 else "Sem preco", Color8(255, 204, 26))]
		DicaItem.mostrar(self, f, DicaItem.linhas(g[sob], extra), _rect_i(g, sob))
	else:
		DicaItem.esconder(self)


# --- pergunta (preco ou compra) ---------------------------------------------------

func _perguntar(texto: String, com_campo: bool, valor: int, ok: Callable) -> void:
	_fechar_pergunta()
	_caixa = PanelContainer.new()
	JanelaMU.painel_mu(_caixa, 8)
	var v := VBoxContainer.new()
	_caixa.add_child(v)
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", 9)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(150, 0)
	v.add_child(l)
	var campo: LineEdit = null
	if com_campo:
		campo = _novo_campo(Vector2.ZERO, Vector2(150, 16), "preco em zen")
		campo.text = str(valor) if valor > 0 else ""
		campo.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		v.add_child(campo)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var feito := func():
		var n := 0
		if campo:
			var t := campo.text.strip_edges().replace(".", "")
			if not t.is_valid_int() or int(t) <= 0:
				return
			n = int(t)
		_fechar_pergunta()
		ok.call(n)
	for sim in [true, false]:
		var b := Button.new()
		b.text = ("Comprar" if not com_campo else "OK") if sim else "Cancelar"
		JanelaMU.botao_mu(b, "btn_pequeno")
		b.pressed.connect(feito if sim else _fechar_pergunta)
		h.add_child(b)
	if campo:
		campo.text_submitted.connect(func(_t): feito.call())
	add_child(_caixa)
	_caixa.position = Vector2(12, 150)
	if campo:
		campo.grab_focus.call_deferred()
	_pergunta = {"ok": feito}


func _fechar_pergunta() -> void:
	if _caixa:
		_caixa.queue_free()
		_caixa = null
	_pergunta = {}
	queue_redraw()


# testes: responde a pergunta aberta como se tivesse clicado OK
func responder(valor := 0) -> void:
	if _caixa == null:
		return
	for c in _caixa.get_child(0).get_children():
		if c is LineEdit:
			c.text = str(valor)
	_pergunta.ok.call()


func perguntando() -> bool:
	return _caixa != null


# --- mouse -----------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		if inv and inv.na_mao >= 0:
			inv.mouse_fora(get_global_transform() * ev.position)
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		_mouse = ev.position
		if _caixa:
			accept_event()
			return
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_clique()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			if inv and inv.na_mao >= 0:
				inv.soltar()
			elif modo == "minha" and not aberta:
				var i := _sob(grade())
				if i >= 0:
					_perguntar("Novo preco de %s:" % ItensMU.nome(grade()[i]), true, preco_de(i), func(v): preco.emit(PRIMEIRO + i, v))
		accept_event()
		queue_redraw()


func _clique() -> void:
	if Rect2(13, 391, 36, 29).has_point(_mouse) or Rect2(160, 2, 26, 22).has_point(_mouse):
		fechar.emit()
		return
	if modo == "outro":
		var i := _sob(itens)
		if i >= 0:
			var v := preco_de(i)
			_perguntar("Comprar %s de %s por %s zen?" % [ItensMU.nome(itens[i]), dono, ItemChao._milhar(v)], false, 0, func(_v): comprar_item.emit(i))
		return
	if Rect2(53, 391, 36, 29).has_point(_mouse):
		if not aberta:
			var t := _campo.text.strip_edges()
			titulo = t
			abrir_minha.emit(t)
		return
	if Rect2(93, 391, 36, 29).has_point(_mouse):
		if aberta:
			fechar_minha.emit()
		return
	if aberta or esperando >= 0 or (inv and inv.esperando >= 0):
		return
	if inv and inv.na_mao >= 0 and inv.itens.has(inv.na_mao):
		var it: Dictionary = inv.itens[inv.na_mao]
		var d := _destino(it)
		if not cabe(it, d):
			return
		var de := inv.na_mao
		inv.soltar()
		var para := PRIMEIRO + d.y * COLUNAS + d.x
		_perguntar("Preco de %s:" % ItensMU.nome(it), true, 0, func(v):
			inv.esperando = de
			por.emit(de, para, v))
		return
	var i := _sob(grade())
	if i >= 0:
		esperando = PRIMEIRO + i
		tirar.emit(PRIMEIRO + i)
