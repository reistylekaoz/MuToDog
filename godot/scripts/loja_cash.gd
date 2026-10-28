class_name LojaCash
extends Control
# Loja de cash do S6 (CNewUIInGameShop, rodada 23): 640x429 no canto de cima, como o original.
# Esquerda: zonas (W Coin (C), W Coin (P), Goblin Point), categorias e a grade 3x3 dos pacotes do script
# 512.2012.084 (dados/loja.json, ferramentas/dados_loja.py), 9 por pagina. Direita: nome, saldos (D2 01), botoes
# Gift / Cash (restritos no original) e Refresh, banner, abas Storage e Gift Inventory com a lista do deposito
# (D2 06 + 0D/0E, 9 por pagina) e Use. As caixas do original sao desenhadas aqui dentro: escolher o preco
# (BuySelectItem), o pacote (BuyPackageItem), confirmar a compra, presentear (nome e mensagem), ver e usar o item
# do deposito e a caixa simples de resultado.

signal comprar(pacote: int, categoria: int, preco_seq: int, item: int, moeda: int)                   # D2 03
signal presentear(pacote: int, categoria: int, preco_seq: int, item: int, moeda: int, para: String, texto: String)  # D2 04
signal pedir_saldo                                   # D2 01
signal pedir_deposito(pagina: int, presentes: bool)  # D2 05
signal usar(indice: int, preco_seq: int, item: int, tipo: int)  # D2 0B
signal fechar

const PASTA := "res://dados/hud/loja/"
const L := 640.0
const A := 429.0
const POR_PAGINA := 9
const PERIODO := [2, 28, 12, 58, 10]       # PropertySeq de periodo de uso (GetProductInfo)
const QUANTIDADE := [30, 11, 7, 8, 9, 31]  # PropertySeq de quantidade
const AMARELO := Color8(247, 186, 0)
const PRECO := Color8(255, 238, 161)
const LISTA := Color8(255, 230, 210)

static var _dados := {}
static var _por_preco := {}
static var _por_produto := {}

var zonas: Array = []          # [{seq, nome, cats: [{seq, nome, pacotes: [...]}]}]
var zona := 0
var categoria := 0
var pagina := 0
var meu_nome := ""
var saldo := {"c": 0.0, "p": 0.0, "goblin": 0.0}
var presentes := false         # aba do deposito: false Storage, true Gift Inventory
var deposito: Array = []       # itens da pagina (D2 0D ou 0E)
var dep_pagina := 1
var dep_paginas := 1
var dep_total := 0
var dep_sel := 0
var caixa := {}                # caixa aberta por cima da loja ({} nenhuma)
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _nome: LineEdit
var _msg: TextEdit


static func carregar() -> Dictionary:
	if _dados.is_empty():
		_dados = ItensMU._json("res://dados/loja.json")
		for r in _dados.get("produtos", []):
			var k := int(r.preco_seq)
			if not _por_preco.has(k):
				_por_preco[k] = []
			_por_preco[k].append(r)
			var s := int(r.seq)
			if not _por_produto.has(s):
				_por_produto[s] = []
			_por_produto[s].append(r)
	return _dados


# zonas (Root = 1) na DisplayOrder; categorias filhas na DisplayOrder; pacotes a venda na ViewOrder
static func montar_zonas() -> Array:
	var d := carregar()
	var cats: Array = d.get("categorias", [])
	var raizes := cats.filter(func(c): return c.raiz)
	raizes.sort_custom(func(a, b): return int(a.ordem) < int(b.ordem))
	var r := []
	for z in raizes:
		var filhas := cats.filter(func(c): return not c.raiz and int(c.pai) == int(z.seq))
		filhas.sort_custom(func(a, b): return int(a.ordem) < int(b.ordem))
		var lc := []
		for c in filhas:
			var ps: Array = d.pacotes.filter(func(p): return int(p.cat) == int(c.seq) and p.venda and not p.apagado)
			ps.sort_custom(func(a, b): return [int(a.ordem), int(a.seq)] < [int(b.ordem), int(b.seq)])
			lc.append({"seq": int(c.seq), "nome": c.nome, "pacotes": ps})
		r.append({"seq": int(z.seq), "nome": z.nome, "cats": lc})
	return r


static func item_de(codigo: int) -> Dictionary:
	return {"grupo": codigo / 512, "numero": codigo % 512, "nivel": 0}


static func duracao(segundos: int) -> String:
	if segundos <= 0:
		return "-"
	if segundos % 86400 == 0:
		return "%d %s" % [segundos / 86400, DicaItem.t(2298)]
	if segundos % 3600 == 0:
		return "%d %s" % [segundos / 3600, DicaItem.t(2299)]
	if segundos % 60 == 0:
		return "%d %s" % [segundos / 60, DicaItem.t(2300)]
	return "%d %s" % [segundos, DicaItem.t(2301)]


# GetProductInfo: nome, quantidade e periodo de uso pelo PriceSeq (ou pelo ProductSeq quando o preco e 0)
static func info_produto(preco_seq: int, produto := -1) -> Dictionary:
	carregar()
	var linhas: Array = _por_preco.get(preco_seq, []) if preco_seq > 0 else _por_produto.get(produto, [])
	if produto >= 0 and preco_seq > 0:
		linhas = linhas.filter(func(r): return int(r.seq) == produto)
	if linhas.is_empty():
		return {}
	var i := {"nome": str(linhas[0].nome).strip_edges(), "qtd": 0, "duracao": "-", "item": int(linhas[0].item),
		"preco": int(linhas[0].preco)}
	for r in linhas:
		var ps := int(r.prop_seq)
		if ps in QUANTIDADE:
			i.qtd = int(r.valor)
		elif ps in PERIODO:
			var k: int = {386: 1, 174: 60, 172: 3600}.get(int(r.tipo_unidade), 86400)
			i.duracao = duracao(int(r.valor) * k)
	return i


func _ready() -> void:
	for n in ["fundo", "bt_categoria", "deco_centro", "deco_pe", "aba_deposito", "aba_presente", "aba_zona", "bt_presente",
			"bt_cash", "bt_atualizar", "bt", "logo", "pag_esq", "pag_dir", "dep_pag", "dep_esq", "dep_dir", "caixa_pacote",
			"caixa_variante", "caixa_presente", "presente_icone", "presente_nome", "caixa_info", "caixa_info_presente",
			"caixa_texto", "radio", "msg_fundo", "msg_topo", "msg_baixo", "msg_esq", "msg_dir", "sair", "banner"]:
		_tex[n] = load(PASTA + n + ".png")
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _init() -> void:
	zonas = montar_zonas()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_nome = LineEdit.new()
	_nome.max_length = 10
	_msg = TextEdit.new()
	_msg.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	# sem moldura do Godot: a caixinha e o papel sao do fundo da caixa (ingame_gift_namebox e ingame_gift_back01)
	var vazio := StyleBoxEmpty.new()
	for c: Control in [_nome, _msg]:
		c.add_theme_font_size_override("font_size", 9)
		c.add_theme_color_override("font_color", Color.WHITE)
		c.add_theme_color_override("caret_color", Color.WHITE)
		for e in ["normal", "focus", "read_only"]:
			c.add_theme_stylebox_override(e, vazio)
	_msg.text_changed.connect(func(): if _msg.text.length() > 200: _msg.text = _msg.text.left(200))
	_nome.flat = true
	# a caixinha do nome (ingame_gift_namebox) e clara: letra escura
	_nome.add_theme_color_override("font_color", Color.BLACK)
	_nome.add_theme_color_override("caret_color", Color.BLACK)
	for c in [_nome, _msg]:
		c.visible = false
		add_child(c)
	visible = false


func _ajustar() -> void:
	var v := get_viewport_rect().size
	var barra := 51.0 * v.x / 640.0
	_esc = minf(v.x / 640.0, (v.y - barra) / A)
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2((v.x - L * _esc) / 2.0, 0)
	queue_redraw()


# --- abrir e dados do servidor ----------------------------------------------------

# D2 02 com IsAllowed: OpeningProcess (zona 0, categoria 0) e a aba Storage
func abrir(nome: String) -> void:
	meu_nome = nome
	zona = 0
	categoria = 0
	pagina = 0
	presentes = false
	deposito.clear()
	dep_sel = 0
	_fechar_caixa()
	visible = true
	queue_redraw()


func receber_saldo(d: Dictionary) -> void:
	saldo = d
	queue_redraw()


func receber_cabecalho(d: Dictionary) -> void:
	deposito.clear()
	dep_total = int(d.total)
	dep_pagina = maxi(1, int(d.pagina))
	dep_paginas = maxi(1, int(d.paginas))
	dep_sel = 0
	queue_redraw()


func receber_item(d: Dictionary) -> void:
	if bool(d.presente) != presentes:
		return
	var i := d.duplicate()
	if int(d.tipo) == 67:
		i.nome = DicaItem.t(3050, [DicaItem._milhar(int(d.cash))])
		i.qtd_txt = DicaItem.t(3043, [DicaItem._milhar(int(d.cash))])
		i.duracao = "-"
		i.item = -1
	else:
		var p := info_produto(int(d.preco_seq), int(d.produto))
		i.nome = p.get("nome", "?%d" % int(d.produto))
		i.qtd = int(p.get("qtd", 0))
		i.qtd_txt = str(maxi(1, i.qtd))
		i.duracao = p.get("duracao", "-")
		i.item = int(p.get("item", -1))
	deposito.append(i)
	queue_redraw()


func pacotes_da_categoria() -> Array:
	if zona >= zonas.size() or categoria >= zonas[zona].cats.size():
		return []
	return zonas[zona].cats[categoria].pacotes


# o original da uma pagina a mais quando o total e multiplo de 9 (size / 9 + 1); aqui e a conta certa
func paginas() -> int:
	return maxi(1, ceili(pacotes_da_categoria().size() / float(POR_PAGINA)))


# resultado do D2 03 (compra), 04 (presente) e 0B (uso): caixa simples com o texto do original
func resultado(sub: int, r: int) -> void:
	var ok := r == 0
	var titulo := 0
	var texto := 0
	match sub:
		0x03:
			titulo = 2900 if ok else 2902
			texto = {0: 2901, 1: 2903, 2: 2904, 3: 2956, 4: 2957, 5: 2958, 6: 3052, 7: 3053, 8: 3054, 9: 3264,
				254: 2953, 255: 2954}.get(r, 890)
		0x04:
			titulo = 2910 if ok else 2912
			texto = {0: 2911, 1: 2913, 2: 2914, 3: 2915, 4: 2956, 5: 2958, 6: 2958, 7: 2959, 8: 2960, 9: 2961,
				10: 3264, 20: 3263, 254: 2953, 255: 2954}.get(r, 890)
		0x0B:
			titulo = 2924 if ok else 2928
			texto = {0: 2925, 1: 2962, 2: 2963, 3: 2964, 4: 2965, 21: 2284, 22: 3036, 24: 2610, 254: 2967,
				255: 2966}.get(r, 890)
	if texto == 890:
		titulo = 2945
	aviso(DicaItem.t(titulo), DicaItem.t(texto))
	if ok:
		pedir_saldo.emit()
		if sub != 0x04:
			pedir_deposito.emit(1 if sub == 0x03 else dep_pagina, presentes)


func aviso(titulo: String, texto: String) -> void:
	_fechar_caixa()
	var linhas := _quebrar(texto, 170, 9)
	caixa = {"tipo": "aviso", "titulo": titulo, "linhas": linhas, "tam": Vector2(190, 109 + maxi(0, linhas.size() - 3) * 12)}
	queue_redraw()


# --- desenho ----------------------------------------------------------------------

func _zona_r(i: int) -> Rect2:
	return Rect2(95 + i * 76, 0, 76, 23)


func _cat_r(i: int) -> Rect2:
	return Rect2(13, 31 + i * 33, 73, 27)


func _celula(i: int) -> Vector2:
	return Vector2(i % 3 * 122, i / 3 * 121)


func _comprar_r(i: int) -> Rect2:
	var c := _celula(i)
	return Rect2(162 + c.x, 126 + c.y, 52, 26)


func _sair_r() -> Rect2:
	return Rect2(484, 392, 36, 29)


func _usar_r() -> Rect2:
	return Rect2(572, 396, 52, 26)


func _btn_topo(i: int) -> Rect2:
	return Rect2(519 + i * 27, 94, 25, 25)


func _aba_dep(i: int) -> Rect2:
	return Rect2(486 + i * 47, 208, 49, 20)


func _linha_dep(i: int) -> Rect2:
	return Rect2(490, 245 + i * 13, 146, 13)


func _draw() -> void:
	draw_texture_rect(_tex.fundo, Rect2(0, 0, L, A), false)
	_desenhar_esquerda()
	_desenhar_direita()
	if not caixa.is_empty():
		draw_rect(Rect2(0, 0, L, A), Color(0, 0, 0, 0.35))
		_desenhar_caixa()


func _desenhar_esquerda() -> void:
	for i in zonas.size():
		var r := _zona_r(i)
		draw_texture_rect_region(_tex.aba_zona, r, Rect2(0, 23 * (1 if i == zona else 0), 76, 23))
		_texto(Vector2(r.position.x, 16), zonas[i].nome, 76, AMARELO if i == zona else Color.WHITE, true)
	var cats: Array = zonas[zona].cats if zona < zonas.size() else []
	if not cats.is_empty():
		draw_texture_rect(_tex.deco_pe, Rect2(0, _cat_r(cats.size() - 1).position.y - 10, 47, 100), false)
	for i in cats.size():
		var r := _cat_r(i)
		if i > 0:
			draw_texture_rect(_tex.deco_centro, Rect2(r.position.x + 34, r.position.y - 7, 4, 8), false)
		var e := 2 if i == categoria else (1 if r.has_point(_mouse) else 0)
		draw_texture_rect_region(_tex.bt_categoria, r, Rect2(0, 27 * e, 73, 27))
		_texto(Vector2(r.position.x, r.position.y + 17), cats[i].nome, 73, AMARELO if i == categoria else Color.WHITE)
	var ps := pacotes_da_categoria()
	for i in POR_PAGINA:
		var c := _celula(i)
		var k := pagina * POR_PAGINA + i
		if k >= ps.size():
			draw_texture_rect(_tex.logo, Rect2(128 + c.x, 52 + c.y, 57, 57), false)
			continue
		var p: Dictionary = ps[k]
		_texto(Vector2(105 + c.x, 48 + c.y), str(p.nome).strip_edges(), 104, Color.WHITE)
		ItensMU.desenhar(self, item_de(int(p.item)), Rect2(102 + c.x, 51 + c.y, 108, 58))
		_texto(Vector2(105 + c.x, 121 + c.y), "%s %s" % [DicaItem._milhar(int(p.preco)), p.unidade], 104, PRECO)
		_bt(_comprar_r(i), DicaItem.t(1124))
	_seta(_tex.pag_esq, Rect2(231, 397, 20, 23), pagina > 0)
	_seta(_tex.pag_dir, Rect2(307, 397, 20, 23), pagina < paginas() - 1)
	_texto(Vector2(256, 412), str(pagina + 1), 15, Color.WHITE, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_texto(Vector2(274, 412), "/", -1, Color.WHITE)
	_texto(Vector2(287, 412), str(paginas()), 15, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT)


func _desenhar_direita() -> void:
	_texto(Vector2(498, 31), meu_nome, 122, Color.WHITE, true)
	var rot := [DicaItem.t(2883, [""]), DicaItem.t(3145, [""]), DicaItem.t(2884, [""])]
	var val := [saldo.get("c", 0.0), saldo.get("p", 0.0), saldo.get("goblin", 0.0)]
	for i in 3:
		_texto(Vector2(498, 58 + i * 15), rot[i], -1, Color.WHITE)
		_texto(Vector2(548, 58 + i * 15), DicaItem._milhar(int(val[i])), 74, PRECO, false, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in 3:
		var r := _btn_topo(i)
		draw_texture_rect_region([_tex.bt_presente, _tex.bt_cash, _tex.bt_atualizar][i], r,
			Rect2(0, 25 * (1 if r.has_point(_mouse) else 0), 25, 25))
	draw_texture_rect(_tex.banner, Rect2(482, 133, 153, 63), false)
	for i in 2:
		var r := _aba_dep(i)
		var sel := int(presentes) == i
		draw_texture_rect(_tex.aba_deposito if sel else _tex.aba_presente, r, false, Color.WHITE if sel else Color(0.65, 0.65, 0.65))
		_texto(Vector2(r.position.x, 222), DicaItem.t(2888 + i), 49, AMARELO if sel else Color(0.8, 0.8, 0.8))
	_texto(Vector2(492, 241), DicaItem.t(2951), 96, Color.WHITE)
	_texto(Vector2(592, 241), DicaItem.t(2952), 34, Color.WHITE)
	for i in mini(deposito.size(), POR_PAGINA):
		var it: Dictionary = deposito[i]
		var r := _linha_dep(i)
		if i == dep_sel:
			draw_rect(r, Color(0.45, 0.35, 0.15, 0.6))
		var n: String = it.nome if int(it.get("qtd", 0)) <= 1 else "%s(%d)" % [it.nome, it.qtd]
		_texto(Vector2(492, r.position.y + 10), n, 98, LISTA, false, HORIZONTAL_ALIGNMENT_LEFT)
		_texto(Vector2(594, r.position.y + 10), it.duracao, 33, LISTA, false, HORIZONTAL_ALIGNMENT_RIGHT)
	draw_texture_rect(_tex.dep_pag, Rect2(520, 365, 80, 30), false)
	_seta(_tex.dep_esq, Rect2(500, 369, 20, 22), dep_pagina > 1, 22)
	_seta(_tex.dep_dir, Rect2(596, 369, 20, 22), dep_pagina < dep_paginas, 22)
	_texto(Vector2(530, 384), str(dep_pagina), 20, Color.WHITE, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_texto(Vector2(553, 384), "/", -1, Color.WHITE)
	_texto(Vector2(566, 384), str(dep_paginas), 20, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT)
	var s := _sair_r()
	draw_texture_rect_region(_tex.sair, s, Rect2(0, 29 * (1 if s.has_point(_mouse) else 0), 36, 29))
	_bt(_usar_r(), DicaItem.t(2887))


func _seta(t: Texture2D, r: Rect2, ativa: bool, h := 23) -> void:
	var e := 2 if not ativa else (1 if r.has_point(_mouse) else 0)
	draw_texture_rect_region(t, r, Rect2(0, h * e, 20, h))


func _bt(r: Rect2, txt: String, ativo := true) -> void:
	var e := 2 if not ativo else (1 if r.has_point(_mouse) else 0)
	draw_texture_rect_region(_tex.bt, r, Rect2(0, 26 * e, 52, 26))
	_texto(Vector2(r.position.x, r.position.y + 17), txt, 52, Color.WHITE if ativo else Color(0.5, 0.5, 0.5))


func _texto(p: Vector2, t: String, largura: float, cor: Color, negrito := false, al := -1, tam_max := 10) -> void:
	var f := get_theme_default_font()
	var alinha: int = al if al >= 0 else (HORIZONTAL_ALIGNMENT_CENTER if largura > 0 else HORIZONTAL_ALIGNMENT_LEFT)
	var w := largura if largura > 0 else -1.0
	var tam := tam_max
	while largura > 0 and tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura:
		tam -= 1
	var larg := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	if largura > 0 and larg > largura:
		var k := largura / larg
		draw_set_transform(Vector2(p.x * (1.0 - k), 0), 0.0, Vector2(k, 1))
		draw_string_outline(f, p, t, alinha, w / k, tam, 3 if negrito else 2, Color(0, 0, 0, 0.9))
		draw_string(f, p, t, alinha, w / k, tam, cor)
		draw_set_transform(Vector2.ZERO)
		return
	draw_string_outline(f, p, t, alinha, w, tam, 3 if negrito else 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, alinha, w, tam, cor)


# quebra em '#' e na largura (as descricoes do script e os textos do cliente usam '#' como linha)
func _quebrar(t: String, largura: float, tam: int) -> Array:
	var f := get_theme_default_font()
	var r := []
	for par in t.split("#"):
		var linha := ""
		for p in par.split(" ", false):
			var tenta := p if linha.is_empty() else linha + " " + p
			if f.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura and not linha.is_empty():
				r.append(linha)
				linha = p
			else:
				linha = tenta
		r.append(linha)
	return r


# --- caixas -----------------------------------------------------------------------

func _origem() -> Vector2:
	var t: Vector2 = caixa.tam
	return ((Vector2(L, A) - t) / 2.0).floor()


func _cr(x: float, y: float, w := 52.0, h := 26.0) -> Rect2:
	return Rect2(_origem() + Vector2(x, y), Vector2(w, h))


# moldura das caixas de mensagem do jogo (newui_msgbox_back, option_top, back06 L/R, item_back03)
func _moldura(o: Vector2, t: Vector2) -> void:
	draw_texture_rect_region(_tex.msg_fundo, Rect2(o, t), Rect2(0, 0, minf(t.x, 225), minf(t.y, 512)))
	draw_texture_rect(_tex.msg_topo, Rect2(o, Vector2(190, 64)), false)
	var y := 64.0
	while y < t.y - 45:
		var h := minf(10, t.y - 45 - y)
		draw_texture_rect_region(_tex.msg_esq, Rect2(o + Vector2(0, y), Vector2(21, h)), Rect2(0, 0, 21, h))
		draw_texture_rect_region(_tex.msg_dir, Rect2(o + Vector2(t.x - 21, y), Vector2(21, h)), Rect2(0, 0, 21, h))
		y += 10
	draw_texture_rect(_tex.msg_baixo, Rect2(o + Vector2(0, t.y - 45), Vector2(190, 45)), false)


func _desenhar_caixa() -> void:
	var o := _origem()
	var t: Vector2 = caixa.tam
	match caixa.tipo:
		"aviso":
			_moldura(o, t)
			_texto(o + Vector2(0, 22), caixa.titulo, t.x, AMARELO, true)
			for i in caixa.linhas.size():
				_texto(o + Vector2(10, 50 + i * 12), caixa.linhas[i], 170, Color.WHITE, false, -1, 9)
			_bt(_cr((t.x - 52) / 2, t.y - 40), DicaItem.t(228))
		"variante", "pacote":
			var var_: bool = caixa.tipo == "variante"
			draw_texture_rect(_tex.caixa_variante if var_ else _tex.caixa_pacote, Rect2(o, t), false)
			var p: Dictionary = caixa.pacote
			_texto(o + Vector2(0, 20), DicaItem.t(2890), t.x, Color.WHITE, true)
			ItensMU.desenhar(self, item_de(int(p.item)), _cr(60 if var_ else 50, 33 if var_ else 34, 96, 60))
			_texto(o + Vector2(0, 108), str(p.nome).strip_edges(), t.x, AMARELO, true)
			# o efeito do buff (selos e scrolls) vem antes da descricao do script, em azul como na dica do item
			var efeito := DicaItem.efeito_buff("%d,%d" % [int(p.item) / 512, int(p.item) % 512]) \
				if "%d,%d" % [int(p.item) / 512, int(p.item) % 512] in DicaItem.ITENS_CASH else []
			var desc := _quebrar(str(p.descricao), 185 if var_ else 158, 8)
			var y0 := 126.0 if var_ else 131.0
			var maxl := 5 if var_ else 9
			for i in mini(efeito.size() + desc.size(), maxl):
				var azul := i < efeito.size()
				_texto(o + Vector2(15 if var_ else 14, y0 + i * 10), efeito[i] if azul else desc[i - efeito.size()], -1,
					DicaItem.AZUL if azul else Color(0.85, 0.85, 0.85), false, -1, 8)
			if var_:
				var vs: Array = caixa.variantes
				var h := 100.0 / maxi(3, vs.size())
				for i in vs.size():
					var r := _cr(17, 177 + i * h, 180, h)
					draw_texture_rect_region(_tex.radio, Rect2(r.position + Vector2(0, (h - 15) / 2), Vector2(15, 15)),
						Rect2(0, 15 if i == caixa.escolha else 0, 15, 15))
					var v: Dictionary = vs[i]
					var linha2: String = DicaItem.t(3045, [v.qtd, v.duracao]) if v.qtd > 0 else DicaItem.t(3039, [v.duracao])
					_texto(r.position + Vector2(19, h / 2 - 2), v.nome, 160, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT, 8)
					_texto(r.position + Vector2(19, h / 2 + 8), linha2, 160, Color(0.8, 0.8, 0.8), false, HORIZONTAL_ALIGNMENT_LEFT, 8)
				var pv: Dictionary = vs[caixa.escolha]
				_texto(o + Vector2(129, 296), "%s %s" % [DicaItem._milhar(int(pv.preco)), p.unidade], 66, PRECO, false, HORIZONTAL_ALIGNMENT_RIGHT)
			else:
				_texto(o + Vector2(118, 237), "%s %s" % [DicaItem._milhar(int(p.preco)), p.unidade], 66, PRECO, false, HORIZONTAL_ALIGNMENT_RIGHT)
			var by := 309.0 if var_ else 253.0
			var bx: Array = [26, 82, 138] if var_ else [18, 74, 130]
			_bt(_cr(bx[0], by), DicaItem.t(2891))
			_bt(_cr(bx[1], by), DicaItem.t(2892), p.presente)
			_bt(_cr(bx[2], by), DicaItem.t(229))
		"confirmar", "confirmar_presente":
			_moldura(o, t)
			var c: bool = caixa.tipo == "confirmar"
			_texto(o + Vector2(0, 22), DicaItem.t(2896 if c else 2907), t.x, AMARELO, true)
			_texto(o + Vector2(10, 50), DicaItem.t(2897 if c else 2908), 170, Color.WHITE, false, -1, 9)
			draw_texture_rect(_tex.caixa_texto, Rect2(o + Vector2(15, 58), Vector2(160, 41)), false)
			var info: Array = [DicaItem.t(3037, [caixa.nome]), DicaItem.t(3038, [caixa.preco_txt]), DicaItem.t(3039, [caixa.duracao])]
			for i in 3:
				_texto(o + Vector2(25, 71 + i * 11), info[i], 145, AMARELO, false, HORIZONTAL_ALIGNMENT_LEFT, 8)
			var av := _quebrar(DicaItem.t(2898 if c else 2909), 150, 8)
			for i in av.size():
				_texto(o + Vector2(20, 113 + i * 10), av[i], 150, Color(1, 0.55, 0.45), false, -1, 8)
			_bt(_cr(35, 140), DicaItem.t(228))
			_bt(_cr(105, 140), DicaItem.t(229))
		"presente":
			draw_texture_rect(_tex.caixa_presente, Rect2(o, t), false)
			_texto(o + Vector2(0, 20), DicaItem.t(2916), t.x, Color.WHITE, true)
			var l3: Array = [DicaItem.t(2917, [caixa.nome]), DicaItem.t(3038, [caixa.preco_txt]), DicaItem.t(3039, [caixa.duracao])]
			for i in 3:
				_texto(o + Vector2(30, 46 + i * 12), l3[i], 160, AMARELO, false, HORIZONTAL_ALIGNMENT_LEFT, 9)
			draw_texture_rect(_tex.presente_icone, Rect2(o + Vector2(10, 82), Vector2(17, 19)), false)
			draw_texture_rect(_tex.presente_nome, Rect2(o + Vector2(118, 82), Vector2(76, 17)), false)
			_texto(o + Vector2(28, 95), DicaItem.t(2918), 88, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT, 9)
			_texto(o + Vector2(0, 118), DicaItem.t(2919), t.x, Color.WHITE, false, -1, 9)
			var av := _quebrar(DicaItem.t(2920), 180, 8)
			for i in av.size():
				_texto(o + Vector2(15, 213 + i * 10), av[i], 180, Color(1, 0.55, 0.45), false, -1, 8)
			_bt(_cr(35, 230), DicaItem.t(228))
			_bt(_cr(122, 230), DicaItem.t(229))
		"info":
			var g: bool = bool(caixa.item.presente)
			draw_texture_rect(_tex.caixa_info_presente if g else _tex.caixa_info, Rect2(o, t), false)
			var it: Dictionary = caixa.item
			_texto(o + Vector2(0, 20), DicaItem.t(3048 if g else 3049), t.x, Color.WHITE, true)
			if int(it.item) >= 0:
				ItensMU.desenhar(self, item_de(int(it.item)), _cr(56, 34, 97, 60))
			_texto(o + Vector2(0, 108), it.nome, t.x, AMARELO, true)
			_texto(o + Vector2(30, 132), DicaItem.t(3040, [it.qtd_txt]), 150, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT, 9)
			_texto(o + Vector2(30, 148), DicaItem.t(3039, [it.duracao]), 150, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT, 9)
			if g:
				_texto(o + Vector2(0, 185), DicaItem.t(3041, [it.get("de", "")]), t.x, AMARELO, false, -1, 9)
				var ml := _quebrar(str(it.get("mensagem", "")), 170, 8)
				for i in mini(ml.size(), 6):
					_texto(o + Vector2(20, 203 + i * 10), ml[i], 170, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT, 8)
			var by := 270.0 if g else 168.0
			_bt(_cr(43, by), DicaItem.t(228))
			_bt(_cr(115, by), DicaItem.t(229))
		"usar":
			_moldura(o, t)
			_texto(o + Vector2(0, 22), DicaItem.t(2922), t.x, AMARELO, true)
			var ul := _quebrar(DicaItem.t(2923, [caixa.item.nome]), 150, 8)
			for i in ul.size():
				_texto(o + Vector2(20, 50 + i * 12), ul[i], 150, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT, 8)
			_bt(_cr(33, 140), DicaItem.t(228))
			_bt(_cr(105, 140), DicaItem.t(229))


# --- mouse ------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		clicar(ev.position)
		accept_event()


func clicar(p: Vector2) -> void:
	if not caixa.is_empty():
		_clicar_caixa(p)
		queue_redraw()
		return
	queue_redraw()
	if _sair_r().has_point(p):
		fechar.emit()
		return
	for i in zonas.size():
		if _zona_r(i).has_point(p):
			zona = i
			categoria = 0
			pagina = 0
			return
	for i in (zonas[zona].cats.size() if zona < zonas.size() else 0):
		if _cat_r(i).has_point(p):
			categoria = i
			pagina = 0
			return
	var ps := pacotes_da_categoria()
	for i in POR_PAGINA:
		if _comprar_r(i).has_point(p) and pagina * POR_PAGINA + i < ps.size():
			abrir_pacote(ps[pagina * POR_PAGINA + i])
			return
	if Rect2(231, 397, 20, 23).has_point(p) and pagina > 0:
		pagina -= 1
	elif Rect2(307, 397, 20, 23).has_point(p) and pagina < paginas() - 1:
		pagina += 1
	elif _btn_topo(0).has_point(p) or _btn_topo(1).has_point(p):
		aviso(DicaItem.t(2937), DicaItem.t(2938))
	elif _btn_topo(2).has_point(p):
		pedir_saldo.emit()
	elif _aba_dep(0).has_point(p) or _aba_dep(1).has_point(p):
		var g := _aba_dep(1).has_point(p)
		if g != presentes:
			presentes = g
			deposito.clear()
			pedir_deposito.emit(1, presentes)
	elif Rect2(500, 369, 20, 22).has_point(p) and dep_pagina > 1:
		pedir_deposito.emit(dep_pagina - 1, presentes)
	elif Rect2(596, 369, 20, 22).has_point(p) and dep_pagina < dep_paginas:
		pedir_deposito.emit(dep_pagina + 1, presentes)
	elif _usar_r().has_point(p):
		if deposito.is_empty():
			aviso(DicaItem.t(3028), DicaItem.t(3033))
		else:
			caixa = {"tipo": "info", "item": deposito[clampi(dep_sel, 0, deposito.size() - 1)],
				"tam": Vector2(210, 306 if presentes else 202)}
			print("TESTE loja caixa info %s" % caixa.item.nome)
	else:
		for i in mini(deposito.size(), POR_PAGINA):
			if _linha_dep(i).has_point(p):
				dep_sel = i


# Buy na celula: PriceCount > 1 abre a escolha do preco, senao o pacote
func abrir_pacote(p: Dictionary) -> void:
	var vs := []
	for ps in p.precos:
		var i := info_produto(int(ps))
		if not i.is_empty():
			i.preco_seq = int(ps)
			vs.append(i)
	print("TESTE loja caixa do pacote %d (%d precos)" % [int(p.seq), vs.size()])
	if vs.size() > 1:
		caixa = {"tipo": "variante", "pacote": p, "variantes": vs, "escolha": 0, "tam": Vector2(215, 346)}
	else:
		caixa = {"tipo": "pacote", "pacote": p, "variantes": vs, "escolha": 0, "tam": Vector2(198, 291)}
	queue_redraw()


# o que vai pra confirmacao: o BuyPackage manda priceSeq 0, o BuySelect o escolhido
func _escolhido() -> Dictionary:
	var p: Dictionary = caixa.pacote
	var vs: Array = caixa.variantes
	var c := {"pacote": p, "categoria": zonas[zona].cats[categoria].seq if zona < zonas.size() else int(p.cat)}
	if caixa.tipo == "variante":
		var v: Dictionary = vs[caixa.escolha]
		c.merge({"preco_seq": int(v.preco_seq), "nome": v.nome, "preco_txt": "%s %s" % [DicaItem._milhar(int(v.preco)), p.unidade], "duracao": v.duracao})
	else:
		var v: Dictionary = vs[0] if not vs.is_empty() else {}
		c.merge({"preco_seq": 0, "nome": str(p.nome).strip_edges(), "preco_txt": "%s %s" % [DicaItem._milhar(int(p.preco)), p.unidade],
			"duracao": v.get("duracao", "-")})
	return c


func _clicar_caixa(p: Vector2) -> void:
	var t: Vector2 = caixa.tam
	match caixa.tipo:
		"aviso":
			if _cr((t.x - 52) / 2, t.y - 40).has_point(p):
				_fechar_caixa()
		"variante", "pacote":
			var var_: bool = caixa.tipo == "variante"
			var by := 309.0 if var_ else 253.0
			var bx: Array = [26, 82, 138] if var_ else [18, 74, 130]
			if var_:
				var h := 100.0 / maxi(3, caixa.variantes.size())
				for i in caixa.variantes.size():
					if _cr(17, 177 + i * h, 180, h).has_point(p):
						caixa.escolha = i
						return
			if _cr(bx[0], by).has_point(p):
				var c := _escolhido()
				c.tipo = "confirmar"
				c.tam = Vector2(190, 179)
				caixa = c
			elif _cr(bx[1], by).has_point(p) and caixa.pacote.presente:
				var c := _escolhido()
				c.tipo = "presente"
				c.tam = Vector2(210, 267)
				caixa = c
				_mostrar_campos()
			elif _cr(bx[2], by).has_point(p):
				_fechar_caixa()
		"confirmar":
			if _cr(35, 140).has_point(p):
				var pk: Dictionary = caixa.pacote
				comprar.emit(int(pk.seq), int(caixa.categoria), int(caixa.preco_seq), int(pk.item), int(pk.moeda))
				_fechar_caixa()
			elif _cr(105, 140).has_point(p):
				_fechar_caixa()
		"presente":
			if _cr(35, 230).has_point(p):
				var para := _nome.text.strip_edges()
				if para.is_empty():
					aviso(DicaItem.t(3028), DicaItem.t(3031))
				elif para == meu_nome:
					aviso(DicaItem.t(3028), DicaItem.t(3032))
				else:
					var c := caixa.duplicate()
					c.tipo = "confirmar_presente"
					c.tam = Vector2(190, 179)
					c.para = para
					c.texto = _msg.text
					_fechar_caixa()
					caixa = c
			elif _cr(122, 230).has_point(p):
				_fechar_caixa()
		"confirmar_presente":
			if _cr(35, 140).has_point(p):
				var pk: Dictionary = caixa.pacote
				presentear.emit(int(pk.seq), int(caixa.categoria), int(caixa.preco_seq), int(pk.item), int(pk.moeda),
					caixa.para, caixa.texto)
				_fechar_caixa()
			elif _cr(105, 140).has_point(p):
				_fechar_caixa()
		"info":
			var by := 270.0 if bool(caixa.item.presente) else 168.0
			if _cr(43, by).has_point(p):
				caixa = {"tipo": "usar", "item": caixa.item, "tam": Vector2(190, 179)}
				print("TESTE loja caixa usar %s" % caixa.item.nome)
			elif _cr(115, by).has_point(p):
				_fechar_caixa()
		"usar":
			if _cr(33, 140).has_point(p):
				var it: Dictionary = caixa.item
				usar.emit(int(it.indice), int(it.preco_seq), maxi(0, int(it.item)), int(it.tipo))
				_fechar_caixa()
			elif _cr(105, 140).has_point(p):
				_fechar_caixa()


func _mostrar_campos() -> void:
	var o := _origem()
	_nome.position = o + Vector2(121, 82)
	_nome.custom_minimum_size = Vector2(72, 17)
	_nome.size = Vector2(72, 17)
	_msg.position = o + Vector2(22, 126)
	_msg.size = Vector2(170, 65)
	_nome.text = ""
	_msg.text = ""
	_nome.visible = true
	_msg.visible = true
	if is_inside_tree():
		_nome.grab_focus()


func _fechar_caixa() -> void:
	caixa = {}
	if _nome:
		_nome.visible = false
		_msg.visible = false
		if is_inside_tree():
			_nome.release_focus()
			_msg.release_focus()
	queue_redraw()


# ESC: fecha a caixa aberta; sem caixa devolve false e o jogo fecha a loja
func esc() -> bool:
	if caixa.is_empty():
		return false
	_fechar_caixa()
	return true
