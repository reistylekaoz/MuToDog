class_name Inventario
extends Control
# Janela do inventario do MU S6 (CNewUIMyInventory): 190 x 429 na tela de 640,
# colada na direita em cima da barra. Equipamento em cima, mochila 8 x 8 embaixo,
# zen no pe. Clique pega o item (vai junto do mouse), clique de novo larga onde
# estiver: na mochila, num slot de equipamento ou no chao (fora da janela).
# Botao direito usa (pocao, joia) ou equipa e tira. Joia em cima de outro item usa nele.

signal mover(de: int, para: int)
signal usar(slot: int, alvo: int)
signal fruta(slot: int)   # fruta (13,15): o jogo pergunta se soma ou tira antes de usar
signal largar_no_chao(slot: int)
signal aviso(texto: String)

const PASTA := "res://dados/hud/"
const L := 190.0
const A := 429.0
const GRADE := Vector2(15, 200)
const CASA := 20.0
const MOCHILA := 12
const FIM := MOCHILA + 64   # 204 a 235 sao da loja pessoal (nao aparecem na mochila)
# slot -> [x, y, largura, altura, fundo] (SetEquipmentSlotInfo)
const EQUIP := {
	8: [15, 44, 46, 46, "inv_pet"], 2: [75, 44, 46, 46, "inv_elmo"], 7: [120, 44, 61, 46, "inv_asa"],
	1: [135, 87, 46, 66, "inv_arma_esq"], 3: [75, 87, 46, 66, "inv_armadura"], 0: [15, 87, 46, 66, "inv_arma_dir"],
	5: [15, 150, 46, 46, "inv_luvas"], 4: [75, 150, 46, 46, "inv_calca"], 6: [135, 150, 46, 46, "inv_botas"],
	10: [114, 150, 28, 28, "inv_anel"], 9: [54, 87, 28, 28, "inv_colar"], 11: [54, 150, 28, 28, "inv_anel"],
}
const NOMES_SLOT := {0: "mao direita", 1: "mao esquerda", 2: "elmo", 3: "armadura", 4: "calca", 5: "luvas",
	6: "botas", 7: "asa", 8: "ajudante", 9: "colar", 10: "anel", 11: "anel"}

var itens := {}            # slot -> item (cliente.gd item_de)
var zen := 0
var na_mao := -1           # slot do item que esta no mouse
var loja_npc: Control      # com a loja do NPC aberta, a caixa do item mostra o preco de venda
var esperando := -1        # slot que mandei mover e o servidor ainda nao respondeu
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)   # em coordenadas da janela (190 x 429)
var _sair_apertado := false


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "inv_zen", "inv_casa", "inv_sair",
			"tab_ce", "tab_cd", "tab_be", "tab_bd", "tab_c", "tab_b", "tab_e", "tab_d"]:
		_tex[n] = load(PASTA + n + ".png")
	for e in EQUIP.values():
		_tex[e[4]] = load(PASTA + e[4] + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


# do tamanho da tela de 640 x 480, sem passar da barra de baixo (51 de 480 na largura)
func _ajustar() -> void:
	var v := get_viewport_rect().size
	var barra := 51.0 * v.x / 640.0
	_esc = minf(v.x / 640.0, (v.y - barra) / A)
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2(v.x - L * _esc, 0)
	queue_redraw()


func alternar() -> void:
	visible = not visible
	if not visible:
		soltar()
	queue_redraw()


func soltar() -> void:
	na_mao = -1
	queue_redraw()


func definir(lista: Dictionary) -> void:
	itens = lista
	na_mao = -1
	esperando = -1
	queue_redraw()


# --- servidor -------------------------------------------------------------------

func movido(slot: int, it: Dictionary) -> void:
	if esperando >= 0:
		itens.erase(esperando)
	esperando = -1
	itens[slot] = it
	queue_redraw()


func nao_moveu() -> void:
	esperando = -1
	queue_redraw()


func removido(slot: int) -> void:
	itens.erase(slot)
	if na_mao == slot:
		na_mao = -1
	queue_redraw()


func entrou(slot: int, it: Dictionary) -> void:
	itens[slot] = it
	queue_redraw()


func durabilidade(slot: int, v: int) -> void:
	if itens.has(slot):
		itens[slot].durabilidade = v
		queue_redraw()


# --- mochila ---------------------------------------------------------------------

static func casa(slot: int) -> Vector2i:
	return Vector2i((slot - MOCHILA) % 8, (slot - MOCHILA) / 8)


func _ocupado(ignorar: int) -> Array:
	var o := []
	o.resize(64)
	o.fill(false)
	for s in itens:
		if s < MOCHILA or s >= FIM or s == ignorar:
			continue
		var c := casa(s)
		var t := ItensMU.tamanho(itens[s])
		for y in t.y:
			for x in t.x:
				if c.x + x < 8 and c.y + y < 8:
					o[(c.y + y) * 8 + c.x + x] = true
	return o


func cabe(it: Dictionary, c: Vector2i, ignorar := -1) -> bool:
	var t := ItensMU.tamanho(it)
	if c.x < 0 or c.y < 0 or c.x + t.x > 8 or c.y + t.y > 8:
		return false
	var o := _ocupado(ignorar)
	for y in t.y:
		for x in t.x:
			if o[(c.y + y) * 8 + c.x + x]:
				return false
	return true


func lugar_livre(it: Dictionary, ignorar := -1) -> int:
	for y in 8:
		for x in 8:
			if cabe(it, Vector2i(x, y), ignorar):
				return MOCHILA + y * 8 + x
	return -1


# slot da mochila em que o item ocupa a casa c (ou -1)
func item_na_casa(c: Vector2i) -> int:
	for s in itens:
		if s < MOCHILA or s >= FIM:
			continue
		var p := casa(s)
		var t := ItensMU.tamanho(itens[s])
		if c.x >= p.x and c.y >= p.y and c.x < p.x + t.x and c.y < p.y + t.y:
			return s
	return -1


func _rect_slot(s: int) -> Rect2:
	if s < MOCHILA:
		var e: Array = EQUIP[s]
		return Rect2(e[0], e[1], e[2], e[3])
	var c := casa(s)
	var t := ItensMU.tamanho(itens[s]) if itens.has(s) else Vector2i.ONE
	return Rect2(GRADE + Vector2(c) * CASA, Vector2(t) * CASA)


func _equip_em(p: Vector2) -> int:
	for s in EQUIP:
		var e: Array = EQUIP[s]
		if Rect2(e[0], e[1], e[2], e[3]).has_point(p):
			return s
	return -1


func _casa_em(p: Vector2) -> Vector2i:
	var q := (p - GRADE) / CASA
	if q.x < 0 or q.y < 0 or q.x >= 8 or q.y >= 8:
		return Vector2i(-1, -1)
	return Vector2i(int(q.x), int(q.y))


# onde o item da mao cairia: a casa de cima a esquerda, com o item centrado no mouse
func _destino_mochila(p: Vector2) -> Vector2i:
	var t := ItensMU.tamanho(itens[na_mao])
	var q := (p - GRADE - Vector2(t - Vector2i.ONE) * CASA / 2.0) / CASA
	return Vector2i(floori(q.x), floori(q.y))


func slot_sob_mouse() -> int:
	var e := _equip_em(_mouse)
	if e >= 0 and itens.has(e):
		return e
	var c := _casa_em(_mouse)
	return item_na_casa(c) if c.x >= 0 else -1


# --- desenho ---------------------------------------------------------------------

func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 16), "Inventario", L, 11, Color(1, 0.9, 0.7))
	# equipamento
	for s in EQUIP:
		var e: Array = EQUIP[s]
		var r := Rect2(e[0], e[1], e[2], e[3])
		draw_texture_rect(_tex[e[4]], r, false)
		if itens.has(s) and s != na_mao:
			ItensMU.desenhar(self, itens[s], r.grow(-3), Color(1, 1, 1, 0.5) if s == esperando else Color.WHITE)
	# mochila: casas e moldura (CNewUIInventoryCtrl::Render)
	for y in 8:
		for x in 8:
			draw_texture_rect(_tex.inv_casa, Rect2(GRADE + Vector2(x, y) * CASA, Vector2(21, 21)), false)
	_moldura(Rect2(GRADE, Vector2(8, 8) * CASA))
	for s in itens:
		if s < MOCHILA or s >= FIM or s == na_mao:
			continue
		var r := _rect_slot(s)
		draw_rect(r.grow(-1), Color(0.25, 0.2, 0.45, 0.35))
		ItensMU.desenhar(self, itens[s], r.grow(-1), Color(1, 1, 1, 0.5) if s == esperando else Color.WHITE)
		if itens[s].grupo == 14 and itens[s].durabilidade > 1:
			_texto(f, r.position + Vector2(0, r.size.y - 2), str(itens[s].durabilidade), r.size.x - 2, 7, Color(1, 0.95, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	# onde o item da mao vai cair: verde se cabe, vermelho se nao
	if na_mao >= 0 and itens.has(na_mao):
		var it: Dictionary = itens[na_mao]
		var e := _equip_em(_mouse)
		if e >= 0:
			var ok := e in ItensMU.slots(it) and (not itens.has(e) or e == na_mao)
			var alvo_joia := ItensMU.chave(it) in ItensMU.JOIAS_ALVO and itens.has(e)
			draw_rect(_rect_slot(e), Color(0.2, 0.9, 0.3, 0.3) if ok or alvo_joia else Color(0.9, 0.1, 0.1, 0.35))
		elif _casa_em(_mouse).x >= 0:
			var c := _destino_mochila(_mouse)
			var t := ItensMU.tamanho(it)
			var ok := cabe(it, c, na_mao)
			var joia := ItensMU.chave(it) in ItensMU.JOIAS_ALVO and item_na_casa(_casa_em(_mouse)) not in [-1, na_mao]
			if joia:
				draw_rect(_rect_slot(item_na_casa(_casa_em(_mouse))), Color(0.2, 0.6, 1.0, 0.35))
			else:
				var r := Rect2(GRADE + Vector2(c) * CASA, Vector2(t) * CASA).intersection(Rect2(GRADE, Vector2(160, 160)))
				draw_rect(r, Color(0.2, 0.9, 0.3, 0.3) if ok else Color(0.9, 0.1, 0.1, 0.35))
	# zen
	draw_texture_rect(_tex.inv_zen, Rect2(11, 364, 170, 26), false)
	_texto(f, Vector2(50, 381), ItemChao._milhar(zen), 120, 10, Color(1, 0.86, 0.45), HORIZONTAL_ALIGNMENT_LEFT)
	# fechar
	var linha := 1 if Rect2(13, 391, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 391, 36, 29), Rect2(0, 29 * linha, 36, 29))
	_texto(f, Vector2(52, 410), "Fechar (I)", 120, 9, Color(0.75, 0.75, 0.8), HORIZONTAL_ALIGNMENT_LEFT)
	# item na mao segue o mouse; dica do item embaixo do mouse
	if na_mao >= 0 and itens.has(na_mao):
		var t := Vector2(ItensMU.tamanho(itens[na_mao])) * CASA
		ItensMU.desenhar(self, itens[na_mao], Rect2(_mouse - t / 2.0, t))
		DicaItem.esconder(self)
	else:
		var s := slot_sob_mouse()
		if s >= 0:
			var topo := []
			if loja_npc and loja_npc.visible and s >= MOCHILA:
				var v := DicaItem._milhar(ItensMU.preco_venda(itens[s]))
				topo.append(DicaItem._linha(DicaItem.t(63, [v]), Color8(255, 204, 26)))
			DicaItem.equipados = _equipados()
			Pets.onde = [0, s]
			DicaItem.mostrar(self, f, DicaItem.linhas(itens[s], topo), _rect_slot(s))
		else:
			DicaItem.esconder(self)


# os itens vestidos (slots 0 a 11), pra caixa contar as pecas do set ancient
func _equipados() -> Array:
	var l := []
	for i in MOCHILA:
		if itens.has(i):
			l.append(itens[i])
	return l


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



# --- mouse -----------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		_mouse = ev.position
		if ev.button_index == MOUSE_BUTTON_LEFT:
			_clique(ev.position)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			if na_mao >= 0:
				soltar()
			else:
				usar_ou_equipar(slot_sob_mouse())
		accept_event()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and na_mao < 0:
		_mouse = Vector2(-100, -100)
		queue_redraw()


# mouse fora da janela com item na mao: o jogo segue mostrando o item
func mouse_fora(p_tela: Vector2) -> void:
	_mouse = (p_tela - position) / _esc
	queue_redraw()


func _clique(p: Vector2) -> void:
	if Rect2(13, 391, 36, 29).has_point(p) or Rect2(160, 2, 26, 22).has_point(p):
		alternar()
		return
	if esperando >= 0:
		return
	if na_mao < 0:
		var s := slot_sob_mouse()
		if s >= 0:
			na_mao = s
		return
	var it: Dictionary = itens[na_mao]
	var joia := ItensMU.chave(it) in ItensMU.JOIAS_ALVO
	var e := _equip_em(p)
	if e >= 0:
		if e == na_mao:
			soltar()
		elif joia and itens.has(e):
			_usar_em(na_mao, e)
		elif itens.has(e):
			aviso.emit("Ja tem item na %s." % NOMES_SLOT[e])
		elif e not in ItensMU.slots(it):
			aviso.emit("%s nao vai na %s." % [ItensMU.nome(it), NOMES_SLOT[e]])
		else:
			_mandar(na_mao, e)
		return
	var c := _casa_em(p)
	if c.x < 0:
		return
	var embaixo := item_na_casa(c)
	if joia and embaixo not in [-1, na_mao]:
		_usar_em(na_mao, embaixo)
		return
	var d := _destino_mochila(p)
	var para := MOCHILA + d.y * 8 + d.x
	if para == na_mao:
		soltar()
	elif cabe(it, d, na_mao):
		_mandar(na_mao, para)
	else:
		aviso.emit("Nao cabe ai.")


func _mandar(de: int, para: int) -> void:
	esperando = de
	na_mao = -1
	mover.emit(de, para)


func _usar_em(joia: int, alvo: int) -> void:
	na_mao = -1
	usar.emit(joia, alvo)


# botao direito: pocao e afins usa; equipamento vai pro slot dele ou volta pra mochila
func usar_ou_equipar(s: int) -> void:
	if s < 0 or esperando >= 0:
		return
	var it: Dictionary = itens[s]
	if ItensMU.chave(it) in ItensMU.JOIAS_ALVO:
		aviso.emit("Pegue a joia e solte em cima do item.")
		return
	if ItensMU.chave(it) == "13,15" and s >= MOCHILA:
		fruta.emit(s)
		return
	if ItensMU.consome(it):
		usar.emit(s, 0)
		return
	if s < MOCHILA:
		var livre := lugar_livre(it)
		if livre < 0:
			aviso.emit("Mochila cheia.")
		else:
			_mandar(s, livre)
		return
	var opcoes: Array = ItensMU.slots(it)
	if opcoes.is_empty():
		return
	for e in opcoes:
		if not itens.has(e):
			_mandar(s, e)
			return
	aviso.emit("Tire o que esta na %s antes." % NOMES_SLOT[opcoes[0]])
