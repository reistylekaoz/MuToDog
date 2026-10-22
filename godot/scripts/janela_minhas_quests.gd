class_name JanelaMinhasQuests
extends Control
# Janela T (CNewUIMyQuestInfoWindow do S6): 190 x 429 colada na direita, com 3 abas.
# Quest: as quests novas em andamento (F6 1A e o que muda depois); escolher uma pede o estado
# (F6 1B) e mostra o assunto, o resumo, o que pede e o que da; o botao do meio abre a quest que
# nao vem de NPC e o da direita desiste (pede confirmacao, F6 0F).
# Change Class: a quest antiga de troca de classe (titulo, fala e o estado).
# Castle/Temple: as entradas do Blood Castle e do Illusion Temple. O OpenMU nao responde o
# pedido da contagem (C1 9F), entao o numero so aparece se um dia chegar.

signal pedir_estado(indice: int)
signal abrir_quest(indice: int)
signal desistir(indice: int)

const L := 190.0
const A := 429.0
const TAM := 10
const LINHA := 15.0
const TOPO_LISTA := 58.0
const LISTA_MAX := 6
const TOPO_CONTEUDO := 196.0
const CONTEUDO_MAX := 14

enum { QUEST, TROCA, CASTELO }

var q: QuestNova
var legado: QuestLegado
var aba := QUEST
var escolhida := 0           # indice da quest escolhida (0 = nenhuma)
var entradas := [-1, -1]     # Blood Castle e Illusion Temple; -1 = o servidor nao disse
var _conteudo := []          # [texto, cor, negrito, centro, item]
var _rolar := 0
var _confirmar := false
var _tex := {}
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo01", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "quest_linha", "quest_aba_fundo",
			"quest_aba", "quest_aba_grande", "quest_abrir", "quest_desistir", "btn_vazio", "cha_caixa"]:
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


func alternar() -> void:
	visible = not visible
	if visible:
		if legado:
			legado.pagina_npc()
		atualizar()
	else:
		_soltar()


func _soltar() -> void:
	escolhida = 0
	_conteudo = []
	_confirmar = false


# SetCurQuestList: a lista mudou; se a escolhida saiu, solta
func atualizar() -> void:
	if escolhida != 0 and not q.ativas.has(escolhida):
		_soltar()
	elif escolhida != 0:
		_montar_conteudo()
	queue_redraw()


func escolher(k: int) -> void:
	if k < 0 or k >= q.ativas.size():
		return
	escolhida = q.ativas[k]
	_confirmar = false
	_montar_conteudo()
	pedir_estado.emit(escolhida)


# SetSelQuestSummary + SetSelQuestRequestReward
func _montar_conteudo() -> void:
	_conteudo = []
	_rolar = 0
	if escolhida == 0:
		return
	var f := get_theme_default_font()
	_conteudo.append([q.assunto(escolhida), Color8(255, 185, 10), true, true, {}])
	for l in _quebrar(f, q.resumo(escolhida), 150):
		_conteudo.append([l, Color8(255, 230, 210), false, false, {}])
	if q.info.has(escolhida) and q.respostas(escolhida).is_empty():
		_conteudo.append(["", Color.WHITE, false, false, {}])
		for l in q.linhas(escolhida)[0]:
			_conteudo.append([l[0], l[1], l[2], true, l[3]])


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


func _pode_abrir() -> bool:
	return escolhida != 0 and q.por_outro(escolhida)


func _pode_desistir() -> bool:
	return escolhida != 0


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo01, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(0, 23), "Quest", L, 11, Color8(230, 230, 230), true, HORIZONTAL_ALIGNMENT_CENTER)
	_abas(f)
	match aba:
		QUEST:
			_aba_quest(f)
		TROCA:
			_aba_troca(f)
		CASTELO:
			_aba_castelo(f)
	var sair := 1 if Rect2(13, 392, 36, 29).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.inv_sair, Rect2(13, 392, 36, 29), Rect2(0, 29 * sair, 36, 29))
	if _confirmar:
		_caixa_confirmar(f)


func _abas(f: Font) -> void:
	draw_texture_rect(_tex.quest_aba_fundo, Rect2(10, 27, 166, 22), false)
	var nomes := [q.texto(1140), q.texto(2821), q.texto(2824)]
	var xs := [10.0, 57.0, 104.0]
	var ls := [48.0, 48.0, 72.0]
	if aba == CASTELO:
		draw_texture_rect(_tex.quest_aba_grande, Rect2(104, 27, 72, 22), false)
	else:
		draw_texture_rect(_tex.quest_aba, Rect2(xs[aba], 27, 48, 22), false)
	for i in 3:
		var ativa: bool = i == aba
		# centralizado na mao: com largura o Godot corta "Change Class"
		var tam := 9 if f.get_string_size(nomes[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x <= ls[i] else 8
		var x: float = xs[i] + (ls[i] - f.get_string_size(nomes[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x) / 2.0
		_texto(f, Vector2(x, 45 if ativa else 46), nomes[i], -1, tam, Color.WHITE if ativa else Color8(181, 181, 181))


func _rect_linha(k: int) -> Rect2:
	return Rect2(11, TOPO_LISTA + LINHA * k, 168, LINHA)


func _aba_quest(f: Font) -> void:
	draw_texture_rect(_tex.quest_linha, Rect2(1, 160, 188, 21), false)
	if q.ativas.is_empty():
		var k := 0
		for l in _quebrar(f, q.texto(2825), 140):
			_texto(f, Vector2(23, 96 + 18 * k + 11), l, 160, TAM, Color8(255, 255, 0), true)
			k += 1
	else:
		for k in mini(q.ativas.size(), LISTA_MAX):
			var r := _rect_linha(k)
			var i: int = q.ativas[k]
			if i == escolhida:
				draw_rect(r, Color8(0x80, 0xB3, 0x4D, 0x80))
			elif r.has_point(_mouse):
				draw_rect(r, Color8(0x80, 0xB3, 0x4D, 0x40))
			_texto(f, Vector2(15, r.position.y + 11), "%d.%s" % [k + 1, q.assunto(i)], 150, TAM, Color.WHITE)
	var y := TOPO_CONTEUDO
	for k in range(_rolar, mini(_conteudo.size(), _rolar + CONTEUDO_MAX)):
		var c: Array = _conteudo[k]
		if not c[4].is_empty():
			ItensMU.desenhar(self, c[4], Rect2(16, y - 1, 13, 13))
		_texto(f, Vector2(15, y + 11), c[0], 160, TAM, c[1], c[2],
			HORIZONTAL_ALIGNMENT_CENTER if c[3] else HORIZONTAL_ALIGNMENT_LEFT)
		y += 13
	_botao(_tex.quest_abrir, Vector2(50, 392), _pode_abrir())
	_botao(_tex.quest_desistir, Vector2(87, 392), _pode_desistir())


func _botao(t: Texture2D, p: Vector2, pode: bool) -> void:
	var r := Rect2(p, Vector2(36, 29))
	var linha := 1 if pode and r.has_point(_mouse) else 0
	draw_texture_rect_region(t, r, Rect2(0, 29 * linha, 36, 29), Color.WHITE if pode else Color8(100, 100, 100))


# RenderJobChangeContents + RenderJobChangeState
func _aba_troca(f: Font) -> void:
	draw_texture_rect(_tex.quest_linha, Rect2(1, 182, 188, 21), false)
	if legado == null:
		return
	_texto(f, Vector2(0, 69), legado.titulo(), L, TAM, Color8(36, 242, 252), true, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 76.0
	for l in _quebrar(f, str(legado.fala(legado.pagina).texto), 170):
		if y > 170:
			break
		_texto(f, Vector2(0, y + 11), l, L, TAM, Color.WHITE, false, HORIZONTAL_ALIGNMENT_CENTER)
		y += 16
	var e := legado.estado(legado.atual)
	var t := q.texto(931 if e == QuestLegado.ATIVA else (932 if e == QuestLegado.FEITA else 930))
	var k := 0
	for l in _quebrar(f, t, 140):
		_texto(f, Vector2(23, 283 + 18 * k + 11), l, 160, TAM, Color8(255, 255, 0), true)
		k += 1


func _aba_castelo(f: Font) -> void:
	draw_texture_rect(_tex.quest_linha, Rect2(1, 210, 188, 21), false)
	var nomes := [q.texto(1146), q.texto(2369)]
	for i in 2:
		var y: float = [105.0, 285.0][i]
		_texto(f, Vector2(0, y + 11), nomes[i], L, TAM, Color8(255, 255, 0), true, HORIZONTAL_ALIGNMENT_CENTER)
		var t := q.texto(868).replace("%d", str(entradas[i])) if entradas[i] >= 0 else "Entradas: o servidor nao informa"
		_texto(f, Vector2(0, y + 31), t, L, TAM, Color.WHITE, false, HORIZONTAL_ALIGNMENT_CENTER)
		if i == 1:
			_texto(f, Vector2(0, y + 51), q.texto(829).replace("%d", "6"), L, TAM, Color.WHITE, false, HORIZONTAL_ALIGNMENT_CENTER)


# a confirmacao de desistir (2817), por cima da janela
func _caixa_confirmar(f: Font) -> void:
	draw_rect(Rect2(0, 0, L, A), Color(0, 0, 0, 0.45))
	var caixa := Rect2(8, 140, 174, 150)
	draw_rect(caixa, Color8(14, 12, 10, 245))
	draw_rect(caixa, Color8(150, 120, 70), false, 1.0)
	var y := 156.0
	for l in _quebrar(f, q.texto(2817), 156):
		_texto(f, Vector2(caixa.position.x, y), l, caixa.size.x, TAM, Color8(255, 230, 210), false, HORIZONTAL_ALIGNMENT_CENTER)
		y += 14
	for i in 2:
		var b := _rect_confirmar(i)
		var linha := 1 if b.has_point(_mouse) else 0
		draw_texture_rect_region(_tex.btn_vazio, b, Rect2(0, 29 * linha, 108, 29))
		_texto(f, Vector2(b.position.x, b.position.y + 19), q.texto(228 if i == 0 else 229), b.size.x, TAM, Color8(255, 230, 210), false, HORIZONTAL_ALIGNMENT_CENTER)


func _rect_confirmar(i: int) -> Rect2:
	return Rect2(18 + 80 * i, 252, 74, 29)


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, negrito := false, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(f, p, t, al, largura, tam, 3 if negrito else 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, largura, tam, cor)
	if negrito:
		draw_string(f, p + Vector2(0.5, 0), t, al, largura, tam, cor)


func pedir_desistir() -> void:
	if _pode_desistir():
		_confirmar = true
		queue_redraw()


func confirmar(sim: bool) -> void:
	_confirmar = false
	if sim and escolhida != 0:
		desistir.emit(escolhida)
	queue_redraw()


func _clique(p: Vector2) -> void:
	if _confirmar:
		for i in 2:
			if _rect_confirmar(i).has_point(p):
				confirmar(i == 0)
		return
	if Rect2(13, 392, 36, 29).has_point(p) or Rect2(160, 2, 26, 22).has_point(p):
		alternar()
		return
	if Rect2(10, 27, 166, 22).has_point(p):
		aba = QUEST if p.x < 57 else (TROCA if p.x < 104 else CASTELO)
		return
	if aba != QUEST:
		return
	if _pode_abrir() and Rect2(50, 392, 36, 29).has_point(p):
		abrir_quest.emit(escolhida)
	elif _pode_desistir() and Rect2(87, 392, 36, 29).has_point(p):
		pedir_desistir()
	else:
		for k in mini(q.ativas.size(), LISTA_MAX):
			if _rect_linha(k).has_point(p):
				escolher(k)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_rolar = maxi(_rolar - 1, 0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_rolar = clampi(_rolar + 1, 0, maxi(0, _conteudo.size() - CONTEUDO_MAX))
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			_mouse = ev.position
			_clique(ev.position)
		accept_event()
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()
