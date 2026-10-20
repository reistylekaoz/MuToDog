class_name DialogoNPC
extends Control
# Janela de conversa do NPC (CNewUINPCDialogue do S6): 190 x 429 colada na direita.
# Abre quando o servidor manda C3 F9 01 (Elf Soldier e os NPCs de quest). Os textos
# vem do NPCDialogue.bmd + QuestWords (ferramentas/dados_dialogo.py -> npc_dialogo.json).
# Fala do NPC em cima (';' quebra a linha, 7 linhas por pagina), respostas numeradas
# embaixo da linha. Resposta ate 900 troca o estado da conversa; 902 pede o buff.

signal resposta(resultado: int)
signal fechar

const L := 190.0
const A := 429.0
const GAP := 15.0
const LARGURA := 160.0
const TAM := 10
const POR_PAGINA := 7

var npc := 0
var nome := ""
var _dados := {}
var _fala: Array[String] = []
var _respostas := []           # [[linhas, resultado]]
var _pagina := 0
var _sob := -1
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "dlg_linha", "dlg_seta_e", "dlg_seta_d"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	if FileAccess.file_exists("res://dados/npc_dialogo.json"):
		_dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/npc_dialogo.json"))
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


func tem(numero: int) -> bool:
	return _dados.get("dialogo", {}).has("%d,0" % numero)


func abrir(numero: int, nome_npc: String) -> void:
	npc = numero
	nome = nome_npc
	estado(0)
	visible = true


func estado(e: int) -> void:
	var d: Dictionary = _dados.get("dialogo", {}).get("%d,%d" % [npc, e], {})
	var f := get_theme_default_font()
	_fala.clear()
	for parte in str(d.get("fala", "")).split(";"):
		_fala.append_array(_quebrar(f, parte.strip_edges()))
	_respostas.clear()
	var i := 1
	for r in d.get("respostas", []):
		_respostas.append([_quebrar(f, "%d. %s" % [i, r[0]]), int(r[1])])
		i += 1
	_pagina = 0
	queue_redraw()


func _quebrar(f: Font, t: String) -> Array[String]:
	var linhas: Array[String] = []
	var atual := ""
	for p in t.split(" ", false):
		var tenta := p if atual == "" else atual + " " + p
		if atual != "" and f.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, TAM).x > LARGURA:
			linhas.append(atual)
			atual = p
		else:
			atual = tenta
	if atual != "" or linhas.is_empty():
		linhas.append(atual)
	return linhas


func _paginas() -> int:
	return maxi(1, ceili(_fala.size() / float(POR_PAGINA)))


func _rect_resposta(i: int) -> Rect2:
	var y := 203.0
	for j in i:
		y += _respostas[j][0].size() * GAP
	return Rect2(11, y, 168, _respostas[i][0].size() * GAP)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	draw_texture_rect(_tex.dlg_linha, Rect2(1, 181, 188, 21), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 24), nome, L, 11, Color8(150, 255, 240), HORIZONTAL_ALIGNMENT_CENTER)
	for i in POR_PAGINA:
		var k := _pagina * POR_PAGINA + i
		if k < _fala.size():
			_texto(f, Vector2(13, 70 + GAP * i), _fala[k], LARGURA, TAM, Color8(255, 230, 210))
	if _paginas() > 1:
		if _pagina > 0:
			draw_texture_rect_region(_tex.dlg_seta_e, Rect2(131, 165, 17, 18), Rect2(0, 0, 17, 18))
		if _pagina < _paginas() - 1:
			draw_texture_rect_region(_tex.dlg_seta_d, Rect2(153, 165, 17, 18), Rect2(0, 0, 17, 18))
	for i in _respostas.size():
		var r := _rect_resposta(i)
		if i == _sob:
			draw_rect(r, Color8(0x80, 0xB3, 0x4D, 0x80))
		for j in _respostas[i][0].size():
			_texto(f, Vector2(13, r.position.y + 11 + GAP * j), _respostas[i][0][j], LARGURA, TAM, Color.WHITE)
	var linha := 1 if Rect2(13, 391, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 391, 36, 29), Rect2(0, 29 * linha, 36, 29))
	_texto(f, Vector2(52, 410), "Fechar (Esc)", 120, 9, Color(0.75, 0.75, 0.8))


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(f, p, t, al, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, largura, tam, cor)


func escolher(i: int) -> void:
	if i < 0 or i >= _respostas.size():
		return
	var r: int = _respostas[i][1]
	if r <= 900:
		estado(r)
	else:
		resposta.emit(r)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		_sob = -1
		for i in _respostas.size():
			if _rect_resposta(i).has_point(_mouse):
				_sob = i
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		if Rect2(13, 391, 36, 29).has_point(ev.position) or Rect2(160, 2, 26, 22).has_point(ev.position):
			fechar.emit()
		elif _pagina > 0 and Rect2(131, 165, 17, 18).has_point(ev.position):
			_pagina -= 1
		elif _pagina < _paginas() - 1 and Rect2(153, 165, 17, 18).has_point(ev.position):
			_pagina += 1
		else:
			for i in _respostas.size():
				if _rect_resposta(i).has_point(ev.position):
					escolher(i)
					break
		accept_event()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		_sob = -1
		queue_redraw()
