class_name Troca
extends Loja
# Janela de troca do S6 (CNewUITrade): 190 x 429 colada a esquerda do inventario. Em cima
# o que o outro pos (nome, nivel, grade 8 x 4 e zen) e o botao dele aceso quando ele aceita;
# embaixo a minha grade, o meu zen, o botao do zen e o meu botao de aceitar. Item da mochila
# na mao solto na minha grade entra na troca; clique num item meu volta pra mochila. Item
# mudou do lado dele: o servidor solta os dois botoes e o meu fica vermelho uns segundos
# (MyTradeWaitAfterChange), como no cliente.

signal por(de_inv: int, para: int)
signal tirar(slot: int)
signal zen(valor: int)
signal aceitar(apertado: bool)
signal cancelar

const DELE := Vector2(16, 68)
const MEU := Vector2(16, 274)
const LINHAS_TROCA := 4
const ESPERA := 3.0   # segundos com o botao vermelho depois que o outro mexeu

var outro := ""
var nivel_outro := 0
var dele := {}            # slot -> item
var zen_dele := 0
var meu_zen := 0
var zen_pedido := 0       # o que mandei no C1 3A e o servidor ainda nao confirmou
var dele_aceitou := false
var eu_aceitei := false
var esperando := -1       # slot da minha grade que mandei de volta pra mochila
var _espera := 0.0
var _campo: LineEdit


func _ready() -> void:
	super._ready()
	for n in ["bt_aceitar", "bt_zen", "nome_fundo", "linha", "inv_zen"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	_campo = LineEdit.new()
	_campo.placeholder_text = "zen"
	_campo.position = Vector2(54, 394)
	_campo.add_theme_font_size_override("font_size", 9)
	_campo.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	caixa.border_color = Color(0.6, 0.5, 0.3)
	caixa.set_border_width_all(1)
	caixa.set_content_margin_all(2)
	caixa.content_margin_left = 4
	for k in ["normal", "focus", "read_only"]:
		_campo.add_theme_stylebox_override(k, caixa)
	_campo.custom_minimum_size = Vector2(48, 16)
	_campo.text_submitted.connect(func(_t): _mandar_zen())
	add_child(_campo)
	_campo.set_deferred("size", Vector2(48, 16))


func abrir_troca(nome: String, nivel: int) -> void:
	outro = nome
	nivel_outro = nivel
	dele = {}
	itens = {}
	zen_dele = 0
	meu_zen = 0
	zen_pedido = 0
	dele_aceitou = false
	eu_aceitei = false
	esperando = -1
	_espera = 0.0
	_campo.text = ""
	visible = true
	queue_redraw()


func _process(dt: float) -> void:
	if _espera > 0.0:
		_espera -= dt
		if _espera <= 0.0:
			queue_redraw()


# --- servidor -------------------------------------------------------------------

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


func item_dele(slot: int, it: Dictionary) -> void:
	dele[slot] = it
	queue_redraw()


func item_dele_saiu(slot: int) -> void:
	dele.erase(slot)
	queue_redraw()


func botao_dele(estado: int) -> void:
	match estado:
		0: dele_aceitou = false
		1: dele_aceitou = true
		2:
			# o outro mudou o que oferece: os dois botoes soltam e o meu espera
			dele_aceitou = false
			eu_aceitei = false
			_espera = ESPERA
	queue_redraw()


func zen_confirmado() -> void:
	meu_zen = zen_pedido
	queue_redraw()


# --- grade ----------------------------------------------------------------------

func linhas() -> int:
	return LINHAS_TROCA


func _ocupado(ignorar: int) -> Array:
	var o := []
	o.resize(COLUNAS * LINHAS_TROCA)
	o.fill(false)
	for s in itens:
		if s == ignorar:
			continue
		var c := casa(s)
		var t := ItensMU.tamanho(itens[s])
		for y in t.y:
			for x in t.x:
				if c.x + x < COLUNAS and c.y + y < LINHAS_TROCA:
					o[(c.y + y) * COLUNAS + c.x + x] = true
	return o


func cabe(it: Dictionary, c: Vector2i, ignorar := -1) -> bool:
	var t := ItensMU.tamanho(it)
	if c.x < 0 or c.y < 0 or c.x + t.x > COLUNAS or c.y + t.y > LINHAS_TROCA:
		return false
	var o := _ocupado(ignorar)
	for y in t.y:
		for x in t.x:
			if o[(c.y + y) * COLUNAS + c.x + x]:
				return false
	return true


func lugar_livre(it: Dictionary) -> int:
	for y in LINHAS_TROCA:
		for x in COLUNAS:
			if cabe(it, Vector2i(x, y)):
				return y * COLUNAS + x
	return -1


func _rect_em(base: Vector2, lista: Dictionary, s: int) -> Rect2:
	var t := ItensMU.tamanho(lista[s])
	return Rect2(base + Vector2(casa(s)) * CASA, Vector2(t) * CASA)


func _sob(base: Vector2, lista: Dictionary) -> int:
	for s in lista:
		if _rect_em(base, lista, s).has_point(_mouse):
			return s
	return -1


func _destino(it: Dictionary) -> Vector2i:
	var t := ItensMU.tamanho(it)
	var q := (_mouse - MEU - Vector2(t - Vector2i.ONE) * CASA / 2.0) / CASA
	return Vector2i(floori(q.x), floori(q.y))


# --- desenho --------------------------------------------------------------------

func _grade(base: Vector2, lista: Dictionary, sob: int, cinza: int) -> void:
	var f := get_theme_default_font()
	for y in LINHAS_TROCA:
		for x in COLUNAS:
			draw_texture_rect(_tex.inv_casa, Rect2(base + Vector2(x, y) * CASA, Vector2(21, 21)), false)
	_moldura(Rect2(base, Vector2(COLUNAS, LINHAS_TROCA) * CASA))
	for s in lista:
		var r := _rect_em(base, lista, s)
		var cor := Color(0.45, 0.35, 0.15, 0.45) if s == sob else Color(0.25, 0.2, 0.45, 0.35)
		if s == cinza:
			cor = Color(0.5, 0.5, 0.5, 0.3)
		draw_rect(r.grow(-1), cor)
		ItensMU.desenhar(self, lista[s], r.grow(-1))
		if lista[s].grupo == 14 and lista[s].durabilidade > 1:
			_texto(f, r.position + Vector2(0, r.size.y - 2), str(lista[s].durabilidade), r.size.x - 2, 7, Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)


func _cor_zen(v: int) -> Color:
	# getGoldColor: cor pelo tamanho do valor
	if v >= 10000000:
		return Color8(255, 0, 0)
	if v >= 1000000:
		return Color8(255, 120, 0)
	if v >= 100000:
		return Color8(255, 200, 0)
	return Color8(255, 255, 200)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	draw_texture_rect_region(_tex.linha, Rect2(1, 220, 188, 21), Rect2(0, 0, 188, 21))
	draw_texture_rect_region(_tex.nome_fundo, Rect2(11, 37, 171, 26), Rect2(0, 0, 171, 26))
	draw_texture_rect(_tex.inv_zen, Rect2(11, 150, 170, 26), false)
	draw_texture_rect_region(_tex.nome_fundo, Rect2(11, 243, 171, 26), Rect2(0, 0, 171, 26))
	draw_texture_rect(_tex.inv_zen, Rect2(11, 356, 170, 26), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 16), "Troca", L, 11, Color(1, 0.9, 0.7))
	# o outro: nome, nivel (cor pela faixa, como no cliente), grade, zen e o botao dele
	_texto(f, Vector2(22, 54), outro, 110, 11, Color8(210, 230, 255), HORIZONTAL_ALIGNMENT_LEFT)
	var cor_nivel := Color8(255, 255, 255)
	if nivel_outro >= 300:
		cor_nivel = Color8(255, 120, 120)
	elif nivel_outro >= 200:
		cor_nivel = Color8(255, 200, 100)
	elif nivel_outro >= 100:
		cor_nivel = Color8(200, 255, 120)
	_texto(f, Vector2(130, 54), "Lv. %d" % nivel_outro, 50, 9, cor_nivel, HORIZONTAL_ALIGNMENT_LEFT)
	var sob_dele := _sob(DELE, dele)
	var sob_meu := _sob(MEU, itens)
	_grade(DELE, dele, sob_dele, -1)
	_texto(f, Vector2(20, 167), ItemChao._milhar(zen_dele), 150, 10, _cor_zen(zen_dele), HORIZONTAL_ALIGNMENT_RIGHT)
	draw_texture_rect_region(_tex.bt_aceitar, Rect2(146, 186, 36, 29), Rect2(0, 29 if dele_aceitou else 0, 36, 29))
	_texto(f, Vector2(20, 191), "Aviso:", 40, 8, Color8(210, 0, 0), HORIZONTAL_ALIGNMENT_LEFT)
	_texto(f, Vector2(48, 191), "confira o nivel e", 96, 8, Color8(255, 220, 150), HORIZONTAL_ALIGNMENT_LEFT)
	_texto(f, Vector2(20, 203), "os itens antes de", 124, 8, Color8(255, 220, 150), HORIZONTAL_ALIGNMENT_LEFT)
	_texto(f, Vector2(20, 215), "aceitar a troca.", 124, 8, Color8(255, 220, 150), HORIZONTAL_ALIGNMENT_LEFT)
	# eu
	_texto(f, Vector2(22, 260), "Eu", 150, 11, Color8(210, 230, 255), HORIZONTAL_ALIGNMENT_LEFT)
	_grade(MEU, itens, sob_meu, esperando)
	var na_mao := inv != null and inv.na_mao >= 0 and inv.itens.has(inv.na_mao)
	if na_mao and Rect2(MEU, Vector2(COLUNAS, LINHAS_TROCA) * CASA).has_point(_mouse):
		var it: Dictionary = inv.itens[inv.na_mao]
		var d := _destino(it)
		draw_rect(Rect2(MEU + Vector2(d) * CASA, Vector2(ItensMU.tamanho(it)) * CASA), Color(0.2, 0.8, 0.3, 0.3) if cabe(it, d) else Color(0.9, 0.2, 0.2, 0.3))
	_texto(f, Vector2(20, 373), ItemChao._milhar(meu_zen), 150, 10, _cor_zen(meu_zen), HORIZONTAL_ALIGNMENT_RIGHT)
	# fechar, zen e aceitar (vermelho enquanto espera depois que o outro mexeu)
	var linha := 1 if Rect2(13, 390, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 390, 36, 29), Rect2(0, 29 * linha, 36, 29))
	var bz := Rect2(104, 390, 36, 29)
	draw_texture_rect_region(_tex.bt_zen, bz, Rect2(0, 29 if bz.has_point(_mouse) else 0, 36, 29))
	var ba := Rect2(144, 390, 36, 29)
	draw_texture_rect_region(_tex.bt_aceitar, ba, Rect2(0, 29 if eu_aceitei else 0, 36, 29), Color(1, 0.2, 0.2) if _espera > 0.0 else Color.WHITE)
	if ba.has_point(_mouse):
		_texto(f, Vector2(_mouse.x - 60, _mouse.y - 6), "Aceitar a troca" if not eu_aceitei else "Desfazer o aceite", 0, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	elif bz.has_point(_mouse):
		_texto(f, Vector2(_mouse.x - 60, _mouse.y - 6), "Pôr o zen escrito", 0, 9, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	if sob_dele >= 0:
		Pets.onde = [3, sob_dele]
		DicaItem.mostrar(self, f, DicaItem.linhas(dele[sob_dele]), _rect_em(DELE, dele, sob_dele))
	elif sob_meu >= 0 and not na_mao:
		Pets.onde = [2, sob_meu]
		DicaItem.mostrar(self, f, DicaItem.linhas(itens[sob_meu]), _rect_em(MEU, itens, sob_meu))
	else:
		DicaItem.esconder(self)


# --- mouse -----------------------------------------------------------------------

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
	return int(t) if t.is_valid_int() else -1


func _mandar_zen() -> void:
	var v := _valor()
	if v < 0:
		return
	zen_pedido = v
	eu_aceitei = false
	zen.emit(v)


func _clique() -> void:
	if Rect2(13, 390, 36, 29).has_point(_mouse) or Rect2(160, 2, 26, 22).has_point(_mouse):
		cancelar.emit()
		return
	if Rect2(104, 390, 36, 29).has_point(_mouse):
		_mandar_zen()
		return
	if Rect2(144, 390, 36, 29).has_point(_mouse):
		if _espera <= 0.0 and (inv == null or inv.na_mao < 0):
			eu_aceitei = not eu_aceitei
			aceitar.emit(eu_aceitei)
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
		eu_aceitei = false
		por.emit(de, d.y * COLUNAS + d.x)
		return
	var s := _sob(MEU, itens)
	if s >= 0:
		esperando = s
		eu_aceitei = false
		tirar.emit(s)
