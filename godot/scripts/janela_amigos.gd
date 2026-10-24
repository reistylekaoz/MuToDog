class_name JanelaAmigos
extends JanelaMU
# "My Friend" (CUIFriendWindow, tecla F): 250x170 em 50,50 com 3 abas de 53x19 (RenderTabLine) e o "Refuse Chat"
# na direita. Aba 0 Friends List: nome e servidor (0xFF/0xFE/0xFC Offline, 0xFD Cannot Use, senao " %2d Server")
# e Add Friend, Delete Friend, Chat, Write. Aba 1 Letter Box: marca, envelope (fechado = nao lida), quem mandou,
# data e titulo, com Write, Read, Reply, Delete. Aba 2 Window List: as salas de chat abertas e Hide All.
# Duplo clique: Chat na aba 0, Read na aba 1, mostra a sala na aba 2. Linhas de 13, a selecionada em branco.

signal adicionar(nome: String)
signal apagar(nome: String)
signal conversar(nome: String)
signal escrever(para: String, assunto: String)
signal ler(indice: int)
signal apagar_cartas(indices: Array)
signal recusar(sim: bool)
signal mostrar_sala(janela: Control)
signal pergunta(texto: String, tipo: int, guardado: String, retorno: Callable)

const LINHAS := 6
const ALTURA_LISTA := 86.0

var aba := 0
var lista: Array = []          # [{nome, servidor}]
var cartas: Array = []         # [{indice, de, data, titulo, estado, marcada}]
var salas: Array = []          # janelas de sala (JanelaSala)
var maximo_cartas := 0
var recusa := false
var _sel := [-1, -1, -1]
var _primeira := [0, 0, 0]
var _aba_mouse := -1


func _init() -> void:
	super._init(DicaItem.t(990), 250, 170)
	visible = false


func alternar() -> void:
	visible = not visible
	if visible:
		trazer()
	queue_redraw()


# --- dados que chegam do servidor ---------------------------------------------------

func definir(l: Array, _n_cartas := 0) -> void:
	lista = l.duplicate(true)
	queue_redraw()


func novo(nome: String, servidor: int) -> void:
	for a in lista:
		if a.nome == nome:
			a.servidor = servidor
			queue_redraw()
			return
	lista.append({"nome": nome, "servidor": servidor})
	queue_redraw()


func saiu(nome: String) -> void:
	for i in lista.size():
		if lista[i].nome == nome:
			lista.remove_at(i)
			_sel[0] = mini(_sel[0], lista.size() - 1)
			break
	queue_redraw()


func estado(nome: String, servidor: int) -> void:
	for a in lista:
		if a.nome == nome:
			a.servidor = servidor
	queue_redraw()


# o pedido de amizade chega numa pergunta (o jogo abre); aqui so guarda a compatibilidade
func pedido(_nome: String) -> void:
	pass


func carta(c: Dictionary) -> void:
	for x in cartas:
		if x.indice == c.indice:
			x.merge(c, true)
			queue_redraw()
			return
	var n := c.duplicate()
	n.marcada = false
	cartas.append(n)
	cartas.sort_custom(func(a, b): return a.indice < b.indice)
	queue_redraw()


func carta_lida(indice: int) -> void:
	for x in cartas:
		if x.indice == indice:
			x.estado = 0
	queue_redraw()


# C1 C8: a carta sai e as de indice maior descem 1 (o servidor guarda por posicao na lista)
func carta_apagada(indice: int) -> void:
	for i in range(cartas.size() - 1, -1, -1):
		if cartas[i].indice == indice:
			cartas.remove_at(i)
		elif cartas[i].indice > indice:
			cartas[i].indice -= 1
	_sel[1] = mini(_sel[1], cartas.size() - 1)
	queue_redraw()


func carta_de(indice: int) -> Dictionary:
	for x in cartas:
		if x.indice == indice:
			return x
	return {}


func amigo_selecionado() -> String:
	return lista[_sel[0]].nome if _sel[0] >= 0 and _sel[0] < lista.size() else ""


func carta_selecionada() -> Dictionary:
	return cartas[_sel[1]] if _sel[1] >= 0 and _sel[1] < cartas.size() else {}


func selecionar_carta(indice: int) -> void:
	for i in cartas.size():
		if cartas[i].indice == indice:
			_sel[1] = i
	queue_redraw()


static func texto_servidor(s: int) -> String:
	if s in [0xFF, 0xFE, 0xFC]:
		return DicaItem.t(1039)
	if s == 0xFD:
		return DicaItem.t(1041)
	return DicaItem.t(1042) % (s + 1)


# --- desenho -------------------------------------------------------------------------

func _c(x: float, y: float) -> Vector2:
	# a aba e uma janela filha em (0, 21) com a propria area de dentro em 5, 21
	return Vector2(MOLDURA + x, TITULO * 2 + y)


func _conteudo() -> void:
	var w := largura_dentro()
	var h := 125.0          # RHeight da aba: (170 - 19) - 26
	# a aba de baixo: cabecalho na cor 5, a lista, a faixa preta dos botoes
	draw_rect(Rect2(_c(0, 18 + ALTURA_LISTA), Vector2(w, h - ALTURA_LISTA - 18)), COR[7])
	draw_rect(Rect2(_c(0, 0), Vector2(w, 16)), COR[5])
	draw_rect(Rect2(_c(0, 16), Vector2(w, 1)), COR[2])
	draw_rect(Rect2(_c(0, 17 + ALTURA_LISTA), Vector2(w, 1)), COR[2])
	match aba:
		0:
			_aba_amigos(w)
		1:
			_aba_cartas(w)
		2:
			_aba_salas(w)
	# as abas em cima (RenderTabLine) na faixa preta de 20
	draw_rect(Rect2(dentro(0, 0), Vector2(w, 20)), COR[7])
	for i in 3:
		var x := dentro(0, 2).x + i * 53
		var y := dentro(0, 2).y
		if i == aba:
			draw_rect(Rect2(x, y, 53, 1), COR[2])
			draw_rect(Rect2(x - 1, y, 1, 19), COR[2])
			draw_rect(Rect2(x + 52, y, 1, 19), COR[2])
			draw_rect(Rect2(x, y + 1, 52, 18), COR[5])
		else:
			draw_rect(Rect2(x, y + 1, 53, 1), COR[2])
			draw_rect(Rect2(x + 52, y + 1, 1, 18), COR[2])
			draw_rect(Rect2(x, y + 18, 53, 1), COR[2])
			draw_rect(Rect2(x, y + 2, 52, 16), COR[6])
	draw_rect(Rect2(dentro(159, 20), Vector2(w - 159, 1)), COR[2])
	var nomes := [DicaItem.t(1032), DicaItem.t(1034), DicaItem.t(1033)]
	var xs := [0, 54, 107]
	for i in 3:
		var cor := Color.WHITE if i == aba or i == _aba_mouse else TEXTO
		# a aba tem 52: o nome encolhe ate caber (o original usa a fonte pequena)
		var tam := 10
		while tam > 7 and get_theme_default_font().get_string_size(nomes[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > 50:
			tam -= 1
		texto(dentro(xs[i], 6), nomes[i], cor, false, 52, HORIZONTAL_ALIGNMENT_CENTER, tam)
	var rc := DicaItem.t(1035)
	var tw := largura_texto(rc)
	texto(dentro(w - tw - 2, 6), rc)
	caixa_marcar(dentro(w - tw - 2 - 14 - 1, 5), recusa)


func _linha_sel(y: float, w: float) -> void:
	draw_rect(Rect2(_c(0, y), Vector2(w - 12, 13)), Color.WHITE)


func _rolagem(w: float, total: int, i: int) -> void:
	rolagem(Rect2(_c(w - 13, 17), Vector2(13, ALTURA_LISTA)), total, LINHAS, _primeira[i])


func _aba_amigos(w: float) -> void:
	var c1 := largura_texto("ZZZZZZZZZZZZZ") + 8
	draw_rect(Rect2(_c(c1, 17), Vector2(1, ALTURA_LISTA)), COR[2])
	draw_rect(Rect2(_c(c1, 3), Vector2(1, 10)), COR[14])
	texto(_c(4, 3), DicaItem.t(1021))
	texto(_c(4 + c1, 3), DicaItem.t(1022))
	for k in LINHAS:
		var i: int = _primeira[0] + k
		if i >= lista.size():
			break
		var y := 17.0 + k * 13
		var cor := TEXTO
		if i == _sel[0]:
			_linha_sel(y, w)
			cor = Color.BLACK
		texto(_c(3, y + 3), lista[i].nome, cor)
		texto(_c(3 + 4 + c1, y + 3), texto_servidor(lista[i].servidor), cor)
	_rolagem(w, lista.size(), 0)
	var tem: bool = _sel[0] >= 0
	botao("adicionar", Rect2(_c(2, 108), Vector2(50, 14)), DicaItem.t(1018))
	botao("apagar", Rect2(_c(53, 108), Vector2(50, 14)), DicaItem.t(1019), tem)
	botao("conversar", Rect2(_c(104, 108), Vector2(50, 14)), DicaItem.t(1020), tem)
	botao("escrever", Rect2(_c(155, 108), Vector2(50, 14)), DicaItem.t(1015))


func _colunas_cartas() -> Array:
	var c1 := 25.0
	var c2 := c1 + largura_texto(DicaItem.t(1028)) + 8
	var c3 := c2 + largura_texto(DicaItem.t(1029)) + 8
	return [c1, c2, c3]


func _aba_cartas(w: float) -> void:
	var c: Array = _colunas_cartas()
	for x in c:
		draw_rect(Rect2(_c(x, 17), Vector2(1, ALTURA_LISTA)), COR[2])
		draw_rect(Rect2(_c(x, 3), Vector2(1, 10)), COR[14])
	caixa_marcar(_c(1, 3), not cartas.is_empty() and cartas.all(func(x): return x.marcada))
	texto(_c(4 + c[0], 3), DicaItem.t(1028))
	texto(_c(c[1], 3), DicaItem.t(1029), TEXTO, false, c[2] - c[1], HORIZONTAL_ALIGNMENT_CENTER)
	texto(_c(4 + c[2], 3), DicaItem.t(1030))
	for k in LINHAS:
		var i: int = _primeira[1] + k
		if i >= cartas.size():
			break
		var y := 17.0 + k * 13
		var l: Dictionary = cartas[i]
		var cor := TEXTO
		if i == _sel[1]:
			_linha_sel(y, w)
			cor = Color.BLACK
		caixa_marcar(_c(1, y + 2), l.marcada)
		if l.estado == 0:
			draw_texture_rect_region(tex.win_mail, Rect2(_c(11, y + 1), Vector2(13, 10)), Rect2(0, 9, 13, 10))
		else:
			draw_texture_rect_region(tex.win_mail, Rect2(_c(11, y + 2), Vector2(13, 9)), Rect2(0, 0, 13, 9))
		texto(_c(4 + c[0], y + 3), _cortar(l.de, c[1] - c[0] - 4), cor)
		texto(_c(c[1], y + 3), _data(l.data), cor, false, c[2] - c[1], HORIZONTAL_ALIGNMENT_CENTER)
		texto(_c(4 + c[2], y + 3), _cortar(l.titulo, w - 13 - c[2] - 4), cor)
	_rolagem(w, cartas.size(), 1)
	var tem: bool = _sel[1] >= 0
	botao("escrever", Rect2(_c(2, 108), Vector2(50, 14)), DicaItem.t(1015))
	botao("ler", Rect2(_c(53, 108), Vector2(50, 14)), DicaItem.t(1027), tem)
	botao("responder", Rect2(_c(104, 108), Vector2(50, 14)), DicaItem.t(1010), tem)
	botao("apagar_carta", Rect2(_c(155, 108), Vector2(50, 14)), DicaItem.t(1011))


# a data do servidor e "yyyy-MM-dd HH:mm:ss": a coluna mostra o dia
static func _data(d: String) -> String:
	return d.split(" ")[0] if d != "" else ""


func _aba_salas(w: float) -> void:
	texto(_c(8, 3), DicaItem.t(1026))
	salas = salas.filter(func(s): return is_instance_valid(s))
	for k in LINHAS:
		var i: int = _primeira[2] + k
		if i >= salas.size():
			break
		var y := 17.0 + k * 13
		var cor := TEXTO
		if i == _sel[2]:
			_linha_sel(y, w)
			cor = Color.BLACK
		texto(_c(3, y + 3), salas[i].titulo, cor)
	_rolagem(w, salas.size(), 2)
	botao("esconder", Rect2(_c(2, 108), Vector2(50, 14)), DicaItem.t(1025))


# --- mouse -----------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var a := -1
		for i in 3:
			if Rect2(dentro(i * 53, 2), Vector2(53, 19)).has_point(ev.position):
				a = i
		if a != _aba_mouse:
			_aba_mouse = a
	super._gui_input(ev)


func _clique(p: Vector2, duplo: bool) -> void:
	for i in 3:
		if Rect2(dentro(i * 53, 2), Vector2(53, 19)).has_point(p):
			aba = i
			return
	var w := largura_dentro()
	var tw := largura_texto(DicaItem.t(1035))
	if Rect2(dentro(w - tw - 2 - 16, 3), Vector2(tw + 18, 14)).has_point(p):
		if recusa:
			recusa = false
			recusar.emit(false)
		else:
			pergunta.emit(DicaItem.t(1036), 0, "", func(sim, _t):
				if sim:
					recusa = true
					recusar.emit(true)
					queue_redraw())
		return
	var r := Rect2(_c(0, 17), Vector2(w - 13, ALTURA_LISTA))
	if aba == 1 and Rect2(_c(0, 0), Vector2(14, 16)).has_point(p):
		var todas := not cartas.all(func(x): return x.marcada)
		for x in cartas:
			x.marcada = todas
		return
	if not r.has_point(p):
		return
	var i: int = _primeira[aba] + int((p.y - r.position.y) / 13)
	var total: int = [lista.size(), cartas.size(), salas.size()][aba]
	if i >= total:
		return
	_sel[aba] = i
	if aba == 1 and p.x - r.position.x < 12:
		cartas[i].marcada = not cartas[i].marcada
	elif duplo:
		_apertou(["conversar", "ler", "mostrar"][aba])


func _roda(_p: Vector2, passo: int) -> void:
	var total: int = [lista.size(), cartas.size(), salas.size()][aba]
	_primeira[aba] = clampi(_primeira[aba] + passo, 0, maxi(total - LINHAS, 0))


func _apertou(n: String) -> void:
	match n:
		"adicionar":
			pergunta.emit(DicaItem.t(1023), 2, "", func(sim, t):
				if sim and t != "":
					adicionar.emit(t))
		"apagar":
			var a := amigo_selecionado()
			if a != "":
				pergunta.emit("%s %s" % [DicaItem.t(1024), a], 0, a, func(sim, _t):
					if sim:
						apagar.emit(a))
		"conversar":
			var a := amigo_selecionado()
			if a != "":
				conversar.emit(a)
		"escrever":
			escrever.emit(amigo_selecionado() if aba == 0 else "", "")
		"ler":
			var c := carta_selecionada()
			if not c.is_empty():
				ler.emit(c.indice)
		"responder":
			var c := carta_selecionada()
			if not c.is_empty():
				escrever.emit(c.de, (DicaItem.t(1016) % c.titulo).substr(0, 32))
		"apagar_carta":
			# da maior pra menor: apagar uma carta desce o indice das de cima no servidor
			var marcadas := cartas.filter(func(x): return x.marcada).map(func(x): return x.indice)
			marcadas.sort()
			marcadas.reverse()
			if marcadas.is_empty():
				pergunta.emit(DicaItem.t(1031), 1, "", func(_s, _t): pass)
			else:
				pergunta.emit(DicaItem.t(1017), 0, "", func(sim, _t):
					if sim:
						apagar_cartas.emit(marcadas))
		"mostrar":
			if _sel[2] >= 0 and _sel[2] < salas.size():
				mostrar_sala.emit(salas[_sel[2]])
		"esconder":
			for s in salas:
				if is_instance_valid(s):
					s.visible = false
