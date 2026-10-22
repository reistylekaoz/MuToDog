class_name JanelaQuestNova
extends Control
# Janela da quest nova no NPC (CNewUIQuestProgress do S6): 190 x 429 colada na direita.
# Abre com F6 0B (fala de um passo) ou F6 0C (quest aceita: o que pede e o que da).
# "Quest" e o assunto em cima, o NPC e a fala dele (7 linhas por pagina, setas).
# Passo com respostas: a seta da direita na ultima pagina mostra a fala do jogador e as
# respostas (F6 0B com a resposta: 1 aceita, 2 recusa). Passo sem respostas: lista do que
# a quest pede (vermelho o que falta) e dos premios, e o OK (F6 0D) acende quando cumpriu.

signal responder(indice: int, resposta: int)
signal concluir(indice: int)
signal fechar

const L := 190.0
const A := 429.0
const GAP := 15.0
const LARGURA := 160.0
const TAM := 10
const POR_PAGINA := 7
const LISTA_LINHAS := 12

enum { SO_NPC, JOGADOR, PEDIDOS }

var q: QuestNova
var indice := 0
var npc := ""
var jogador := ""
var modo := SO_NPC
var _fala: Array[String] = []
var _pagina := 0
var _jogador: Array[String] = []
var _respostas := []       # [linhas]
var _lista := []           # QuestNova.linhas
var _cumpriu := false
var _rolar := 0
var _pode := true          # o original trava o clique ate a resposta do servidor
var _sob := -1
var _tex := {}
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "quest_linha", "dlg_seta_e", "dlg_seta_d", "btn_vazio"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


func _ajustar() -> void:
	var v := get_viewport_rect().size
	var barra := 51.0 * v.x / 640.0
	var esc := minf(v.x / 640.0, (v.y - barra) / A)
	scale = Vector2(esc, esc)
	size = Vector2(L, A)
	position = Vector2(v.x - L * esc, 0)
	queue_redraw()


# SetContents
func abrir(i: int) -> void:
	indice = i
	var f := get_theme_default_font()
	_fala = []
	for parte in q.fala_npc(i).split(";"):
		_fala.append_array(_quebrar(f, parte.strip_edges(), LARGURA))
	_pagina = 0
	_pode = true
	_sob = -1
	_rolar = 0
	if not q.respostas(i).is_empty():
		modo = SO_NPC
		_jogador = _quebrar(f, q.fala_jogador(i), LARGURA).slice(0, 2)
		_respostas = []
		var k := 1
		for r in q.respostas(i):
			_respostas.append(_quebrar(f, "%d.%s" % [k, r], LARGURA).slice(0, 2))
			k += 1
	else:
		modo = PEDIDOS
		atualizar_pedidos()
	visible = true
	queue_redraw()


func atualizar_pedidos() -> void:
	var r := q.linhas(indice)
	_lista = r[0] if q.info.has(indice) else []
	_cumpriu = r[1] and q.info.has(indice)
	_pode = true
	queue_redraw()


func _paginas() -> int:
	return maxi(1, ceili(_fala.size() / float(POR_PAGINA)))


func _quebrar(f: Font, t: String, largura: float) -> Array[String]:
	var linhas: Array[String] = []
	var atual := ""
	for p in t.split(" ", false):
		var tenta := p if atual == "" else atual + " " + p
		if atual != "" and f.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x > largura:
			linhas.append(atual)
			atual = p
		else:
			atual = tenta
	if atual != "" or linhas.is_empty():
		linhas.append(atual)
	return linhas


func _rect_resposta(i: int) -> Rect2:
	var y := 251.0
	for j in i:
		y += _respostas[j].size() * GAP
	return Rect2(11, y, 168, _respostas[i].size() * GAP)


func _seta_dir() -> bool:
	return _pagina < _paginas() - 1 or modo == SO_NPC


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	draw_texture_rect(_tex.quest_linha, Rect2(1, 181, 188, 21), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 23), "Quest", L, 11, Color8(230, 230, 230), HORIZONTAL_ALIGNMENT_CENTER)
	_texto(f, Vector2(0, 39), q.assunto(indice), L, TAM, Color8(36, 242, 252), HORIZONTAL_ALIGNMENT_CENTER)
	_texto(f, Vector2(13, 61), npc, 160, TAM, Color8(255, 255, 10))
	for i in POR_PAGINA:
		var k := _pagina * POR_PAGINA + i
		if k < _fala.size():
			_texto(f, Vector2(13, 77 + GAP * i), _fala[k], LARGURA, TAM, Color8(255, 230, 210))
	if _pagina > 0:
		draw_texture_rect_region(_tex.dlg_seta_e, Rect2(131, 168, 17, 18), Rect2(0, 0, 17, 18))
	if _seta_dir():
		var brilha := Rect2(153, 168, 17, 18).has_point(_mouse)
		draw_texture_rect_region(_tex.dlg_seta_d, Rect2(153, 168, 17, 18), Rect2(0, 0, 17, 18), Color(1.3, 1.3, 1.3) if brilha else Color.WHITE)
	if modo != PEDIDOS:
		_texto(f, Vector2(13, 218), jogador, 160, TAM, Color8(255, 185, 10))
	if modo == JOGADOR:
		for i in _jogador.size():
			_texto(f, Vector2(13, 233 + GAP * i), _jogador[i], LARGURA, TAM, Color8(255, 230, 210))
		for i in _respostas.size():
			var r := _rect_resposta(i)
			if i == _sob and _pode:
				draw_rect(r, Color8(0x80, 0xB3, 0x4D, 0x80))
			for j in _respostas[i].size():
				_texto(f, Vector2(13, r.position.y + 11 + GAP * j), _respostas[i][j], LARGURA, TAM, Color8(255, 230, 210))
	elif modo == PEDIDOS:
		_desenhar_lista(f)
		var b := Rect2(41, 362, 108, 29)
		var pode := _cumpriu and _pode
		var linha := 1 if pode and b.has_point(_mouse) else 0
		draw_texture_rect_region(_tex.btn_vazio, b, Rect2(0, 29 * linha, 108, 29), Color.WHITE if pode else Color8(100, 100, 100))
		_texto(f, Vector2(41, 381), q.texto(2811), 108, TAM, Color8(255, 230, 210) if pode else Color8(170, 170, 170), HORIZONTAL_ALIGNMENT_CENTER)
	var sair := 1 if Rect2(13, 392, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 392, 36, 29), Rect2(0, 29 * sair, 36, 29))


# a lista do que pede e do que da (174 x 158, acima do OK); a roda do mouse rola
func _desenhar_lista(f: Font) -> void:
	var y := 202.0
	for k in range(_rolar, mini(_lista.size(), _rolar + LISTA_LINHAS)):
		var l: Array = _lista[k]
		if not l[3].is_empty():
			ItensMU.desenhar(self, l[3], Rect2(16, y, 13, 13))
		_texto(f, Vector2(9, y + 11), l[0], 174, TAM + (1 if l[2] else 0), l[1], HORIZONTAL_ALIGNMENT_CENTER)
		y += 13


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(f, p, t, al, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, largura, tam, cor)


func seta_direita() -> void:
	if _pagina < _paginas() - 1:
		_pagina += 1
	elif modo == SO_NPC:
		modo = JOGADOR
	queue_redraw()


func escolher(i: int) -> void:
	if modo != JOGADOR or not _pode or i < 0 or i >= _respostas.size():
		return
	_pode = false
	responder.emit(indice, i + 1)


func ok() -> void:
	if modo == PEDIDOS and _cumpriu and _pode:
		_pode = false
		concluir.emit(indice)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		_sob = -1
		if modo == JOGADOR:
			for i in _respostas.size():
				if _rect_resposta(i).has_point(_mouse):
					_sob = i
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rolar = maxi(_rolar - 1, 0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rolar = clampi(_rolar + 1, 0, maxi(0, _lista.size() - LISTA_LINHAS))
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			_mouse = ev.position
			if Rect2(13, 392, 36, 29).has_point(ev.position) or Rect2(160, 2, 26, 22).has_point(ev.position):
				fechar.emit()
			elif _pagina > 0 and Rect2(131, 168, 17, 18).has_point(ev.position):
				_pagina -= 1
			elif _seta_dir() and Rect2(153, 168, 17, 18).has_point(ev.position):
				seta_direita()
			elif modo == PEDIDOS and Rect2(41, 362, 108, 29).has_point(ev.position):
				ok()
			else:
				for i in _respostas.size():
					if modo == JOGADOR and _rect_resposta(i).has_point(ev.position):
						escolher(i)
						break
		accept_event()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		_sob = -1
		queue_redraw()
