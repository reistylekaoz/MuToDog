class_name JanelaSala
extends JanelaMU
# Sala de chat do "My Friend" (CUIChatWindow, 250x170, "Talking: " e os nomes): a conversa ocupa a janela, a
# lista de quem esta na sala aparece na direita (80) com mais de 2 pessoas ou no convite, e o convite abre a lista
# dos amigos online (mais 80 a esquerda dela). Embaixo, a faixa preta de 15 com o campo de 180x14 e o Invite
# (53x13 a 54 da direita); no convite vira o Close Invitation (73x13). Fala de alguem: "nome: texto" (tipo 3);
# aviso da sala (entrou, saiu, convidou) no tipo 1, azul. Cada sala tem a propria conexao (SalaChat).

signal convidar(sala: JanelaSala, amigo: String)

var sala: SalaChat
var amigo := ""                 # com quem abriu (pra nao abrir duas com o mesmo)
var meu_nome := ""
var amigos_online: Array = []   # nomes pra lista de convite (preenchida ao abrir o convite)
var amigos_de: Callable         # devolve os amigos online (o Correio liga)
var convidando := false
var pedidos := {}               # pedido -> nome convidado
var linhas: Array = []          # [nome, texto, tipo]
var _campo: LineEdit
var _sel_convite := -1


func _init(com: String, eu: String) -> void:
	super._init(DicaItem.t(994) + com, 250, 170)
	amigo = com
	meu_nome = eu
	sala = SalaChat.new()
	sala.amigo = com
	add_child(sala)
	sala.entrou.connect(func(_i, n):
		if n != meu_nome:
			aviso(n + " " + DicaItem.t(1059))
		_titulo())
	sala.saiu_da_sala.connect(func(_i, n):
		aviso(n + " " + DicaItem.t(1060))
		_titulo())
	sala.membros.connect(func(_l): _titulo())
	sala.falou.connect(func(_i, n, t): falar(n, t))
	sala.caiu.connect(func(m): aviso(DicaItem.t(1066) if m == "" else m))
	_campo = JanelaMU.campo(59)
	_campo.text_submitted.connect(_mandar)
	add_child(_campo)
	_posicionar()


func _posicionar() -> void:
	_campo.position = dentro(2, altura_dentro() - 14)
	_campo.size = Vector2(180, 14)


func conectar(host: String, sala_id: int, token: int) -> void:
	sala.conectar(host, sala_id, token)


func membros() -> Array:
	var l := sala.nomes.values()
	l.sort()
	return l


func _titulo() -> void:
	var outros := membros().filter(func(n): return n != meu_nome)
	titulo = DicaItem.t(994) + (", ".join(outros) if not outros.is_empty() else amigo)
	queue_redraw()


func falar(nome: String, texto: String) -> void:
	linhas.append([nome, texto, 3])
	if linhas.size() > 100:
		linhas.pop_front()
	queue_redraw()


func aviso(texto: String) -> void:
	linhas.append(["", texto, 1])
	queue_redraw()


func _mandar(t: String) -> void:
	t = t.strip_edges()
	_campo.text = ""
	if t != "":
		sala.dizer(t)


func sair() -> void:
	sala.sair()


func fechar() -> void:
	sair()
	visible = false
	fechou.emit()
	queue_free()


func resultado_convite(ok: int, pedido: int) -> void:
	var n: String = pedidos.get(pedido, "")
	pedidos.erase(pedido)
	if ok == 1:
		aviso(n + " " + DicaItem.t(1057))
	elif ok == 3:
		aviso(DicaItem.t(1074))
	else:
		aviso(DicaItem.t(1056))


func _lista_direita() -> bool:
	return membros().size() > 2 or convidando


func _conteudo() -> void:
	var w := largura_dentro()
	var h := altura_dentro()
	var largura_conversa := w - (160.0 if convidando else (80.0 if _lista_direita() else 0.0))
	# conversa: da ultima linha pra cima, 13 por linha
	var visiveis: Array = []
	for l in linhas:
		var pre: String = (l[0] + ": ") if l[0] != "" else ""
		var partes := _quebrar(pre + l[1], largura_conversa - 12)
		for i in partes.size():
			visiveis.append([l, i, partes[i], pre])
	var y := h - 16 - 15.0
	for k in range(visiveis.size() - 1, -1, -1):
		if y < 0:
			break
		var v: Array = visiveis[k]
		var l: Array = v[0]
		if l[2] == 1:
			texto(dentro(8, y), v[2], Color8(70, 165, 210))
		elif v[1] == 0 and v[3] != "":
			texto(dentro(8, y), v[3], Color8(239, 220, 205))
			texto(dentro(8 + largura_texto(v[3]), y), v[2].substr(v[3].length()), Color8(230, 220, 200))
		else:
			texto(dentro(8, y), v[2], Color8(230, 220, 200))
		y -= 13
	if _lista_direita():
		draw_rect(Rect2(dentro(w - 80, 0), Vector2(1, h - 16)), COR[2])
		var ms := membros()
		for i in ms.size():
			texto(dentro(w - 77, 3 + i * 13), ms[i])
	if convidando:
		draw_rect(Rect2(dentro(w - 160, 0), Vector2(1, h - 16)), COR[2])
		for i in amigos_online.size():
			var cor := TEXTO
			if i == _sel_convite:
				draw_rect(Rect2(dentro(w - 159, i * 13), Vector2(79, 13)), Color.WHITE)
				cor = Color.BLACK
			texto(dentro(w - 157, 3 + i * 13), amigos_online[i], cor)
	draw_rect(Rect2(dentro(0, h - 16), Vector2(w, 1)), COR[2])
	draw_rect(Rect2(dentro(0, h - 15), Vector2(w, 15)), COR[7])
	if convidando:
		botao("fechar_convite", Rect2(dentro(w - 74, h - 14), Vector2(73, 13)), DicaItem.t(996))
	else:
		botao("convidar", Rect2(dentro(w - 54, h - 14), Vector2(53, 13)), DicaItem.t(993))


func _quebrar(t: String, w: float) -> PackedStringArray:
	var r: PackedStringArray = []
	var atual := ""
	for p in t.split(" "):
		var tenta := p if atual == "" else atual + " " + p
		if atual != "" and largura_texto(tenta) > w:
			r.append(atual)
			atual = p
		else:
			atual = tenta
	r.append(atual)
	return r


func _apertou(n: String) -> void:
	if n == "convidar":
		convidando = true
		_sel_convite = -1
		var dentro_sala := membros()
		amigos_online = (amigos_de.call() if amigos_de.is_valid() else []).filter(func(n): return n not in dentro_sala)
	elif n == "fechar_convite":
		convidando = false


func _clique(p: Vector2, duplo: bool) -> void:
	if not convidando:
		_campo.grab_focus()
		return
	var w := largura_dentro()
	var r := Rect2(dentro(w - 160, 0), Vector2(80, altura_dentro() - 16))
	if r.has_point(p):
		var i := int((p.y - r.position.y) / 13)
		if i < amigos_online.size():
			_sel_convite = i
			if duplo:
				convidar.emit(self, amigos_online[i])
	else:
		_campo.grab_focus()
