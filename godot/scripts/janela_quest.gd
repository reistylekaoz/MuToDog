class_name JanelaQuest
extends Control
# Janela da quest no NPC (CNewUINPCQuest do S6): 190 x 429 colada na direita, abre quando o
# servidor manda C1 A1 (Sebina, Marlon, Apostolo Devin). Nome do NPC e titulo da quest em cima,
# a fala no meio e as respostas numeradas (retorno 1 aceita, 2 fecha, 3 manda o pedido direto;
# o link troca a fala). Com a quest ativa mostra o que ela pede (vermelho o que falta) e o botao
# de concluir; antes de aceitar mostra o custo em zen. A logica e a do QuestLegado.

signal pedir(quest: int, estado: int)   # C1 A2
signal fechar

const L := 190.0
const A := 429.0
const GAP := 15.0
const LARGURA := 166.0
const TAM := 10
const LINHAS := 7

var q := QuestLegado.new()
var nome := ""
var _fala := 0
var _linhas: Array[String] = []
var _respostas := []        # [[texto, link, retorno]]
var _sob := -1
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _textos := {}
var monstros := {}       # dados/monstros.json, o jogo passa


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "quest_linha", "quest_zen", "btn_vazio"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	if FileAccess.file_exists("res://dados/textos_eng.json"):
		_textos = JSON.parse_string(FileAccess.get_file_as_string("res://dados/textos_eng.json"))
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


# ShowQuestNpcWindow: a fala que o estado da quest pede
func abrir(nome_npc: String) -> void:
	nome = nome_npc
	mostrar(q.pagina_npc())
	visible = true


func atualizar() -> void:
	if visible:
		mostrar(q.pagina_npc())


func mostrar(i: int) -> void:
	_fala = i
	var d := q.fala(i)
	var f := get_theme_default_font()
	_linhas = _quebrar(f, str(d.texto))
	_respostas = d.respostas.duplicate()
	if _respostas.is_empty():
		_respostas = [["Close", 0, 2]]
	_sob = -1
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


func _ativa() -> bool:
	return q.estado(q.atual) == QuestLegado.ATIVA


func _topo_respostas() -> float:
	if not _ativa():
		return 250.0
	return _topo_fala() + GAP * _linhas.size()


func _topo_fala() -> float:
	var total := _linhas.size() + (_respostas.size() if _ativa() else 0)
	return 66.0 + maxf(0.0, (LINHAS - total) * GAP / 2.0)


func _rect_resposta(i: int) -> Rect2:
	return Rect2(4, _topo_respostas() + GAP * i, L - 8, GAP)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	draw_texture_rect(_tex.quest_linha, Rect2(1, 220, 188, 21), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 24), nome, L, 11, Color8(150, 255, 240), HORIZONTAL_ALIGNMENT_CENTER)
	_texto(f, Vector2(0, 40), q.titulo(), L, 10, Color8(200, 220, 255), HORIZONTAL_ALIGNMENT_CENTER)
	var y := _topo_fala()
	for linha in _linhas:
		_texto(f, Vector2(0, y + 11), linha, L, TAM, Color8(255, 230, 210), HORIZONTAL_ALIGNMENT_CENTER)
		y += GAP
	for i in _respostas.size():
		var r := _rect_resposta(i)
		var cor := Color8(255, 0, 0) if i == _sob else Color8(223, 191, 103)
		_texto(f, Vector2(0, r.position.y + 11), "%d) %s" % [i + 1, _respostas[i][0]], L, TAM, cor, HORIZONTAL_ALIGNMENT_CENTER)
	if _ativa():
		draw_texture_rect(_tex.quest_linha, Rect2(1, 325, 188, 21), false)
		var pronta := _pedidos(f)
		var b := Rect2(41, 355, 108, 29)
		var linha := 0 if not pronta else (1 if b.has_point(_mouse) else 0)
		draw_texture_rect_region(_tex.btn_vazio, b, Rect2(0, 29 * linha, 108, 29), Color.WHITE if pronta else Color8(100, 100, 100))
		_texto(f, Vector2(41, 374), str(_textos.get("699", "Proceed with quest")), 108, TAM,
			Color8(255, 230, 210) if pronta else Color8(170, 170, 170), HORIZONTAL_ALIGNMENT_CENTER)
	elif q.estado(q.atual) == QuestLegado.NAO and q.zen_preciso > 0:
		draw_texture_rect(_tex.quest_zen, Rect2(11, 361, 170, 24), false)
		_texto(f, Vector2(20, 377), str(_textos.get("198", "Cost")), 80, TAM, Color8(255, 220, 150))
		_texto(f, Vector2(20, 377), _milhar(q.zen_preciso), 150, TAM, Color8(255, 220, 150) if q.zen >= q.zen_preciso else Color8(255, 60, 60), HORIZONTAL_ALIGNMENT_RIGHT)
	var sair := 1 if Rect2(13, 391, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 391, 36, 29), Rect2(0, 29 * sair, 36, 29))
	_texto(f, Vector2(52, 410), "Fechar (Esc)", 120, 9, Color(0.75, 0.75, 0.8))


# RenderItemMobText: o que a quest pede, com o icone; devolve se tudo esta cumprido
func _pedidos(f: Font) -> bool:
	var tudo := true
	var y := 244.0
	for a in q.acts():
		var ok := q.cumpriu(a)
		tudo = tudo and ok
		var cor := Color8(223, 191, 103) if ok else Color8(255, 30, 30)
		var t := ""
		if a.tipo == QuestLegado.ITEM:
			var it := {"grupo": a.grupo, "numero": a.numero, "nivel": a.nivel, "durabilidade": 1}
			ItensMU.desenhar(self, it, Rect2(16, y - 4, 32, 32))
			t = "%s x %d" % [ItensMU.nome(it), a.quantos]
		elif a.tipo == QuestLegado.MONSTRO:
			t = "%s x %d/%d" % [str(monstros.get(str(int(a.grupo)), ["Monstro %d" % a.grupo])[0]), mini(q.mortes_de(a.grupo), a.quantos), a.quantos]
		else:
			continue
		_texto(f, Vector2(52, y + 14), t, L - 56, TAM, cor)
		y += 32
	return tudo


static func _milhar(v: int) -> String:
	var s := str(v)
	var r := ""
	while s.length() > 3:
		r = "," + s.substr(s.length() - 3) + r
		s = s.substr(0, s.length() - 3)
	return s + r


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(f, p, t, al, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, largura, tam, cor)


# UpdateSelTextMouseEvent: a resposta escolhida
func escolher(i: int) -> void:
	if i < 0 or i >= _respostas.size():
		return
	var r: Array = _respostas[i]
	var mostrou_erro := false
	match int(r[2]):
		1:
			if q.pode_aceitar():
				pedir.emit(q.atual, QuestLegado.ATIVA)
			else:
				mostrou_erro = true
				mostrar(q.pagina)
		2:
			fechar.emit()
			return
		3:
			pedir.emit(q.atual, QuestLegado.ATIVA)
	if int(r[1]) > 0 and not mostrou_erro:
		mostrar(int(r[1]))


func concluir() -> void:
	if _ativa() and q.pronta():
		pedir.emit(q.atual, QuestLegado.ATIVA)


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
		elif _ativa() and Rect2(41, 355, 108, 29).has_point(ev.position):
			concluir()
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
