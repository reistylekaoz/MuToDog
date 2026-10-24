class_name Correio
extends Node
# Rodada 10: o "My Friend" inteiro ligado ao jogo. Janela de amigos (F) com cartas e salas, as janelinhas de
# pergunta, escrever e ler carta, as salas de chat (cada uma com a conexao do servidor de chat), a caixa de chat
# do Enter (normal, grupo, guilda, Gens e cochicho), as linhas coloridas do registro e o balao de fala.

const CUSTO_CARTA := 1000
# registro do chat (CNewUIChatLogWindow): fundo e letra de cada tipo
const CORES := {"cochicho": ["ffc83296", "000000"], "sistema": ["00000096", "6496ff"], "erro": ["00000096", "ff1e00"],
	"normal": ["00000096", "cddcef"], "grupo": ["00c8ff96", "000000"], "guilda": ["00ff96c8", "000000"],
	"alianca": ["c8c800c8", "000000"], "gens": ["96c864c8", "000000"], "gm": ["1e1e1ec8", "fac832"]}

var jogo: Node
var cli: ClienteMU
var janelas: Control           # as janelas antigas, uma em cima da outra
var amigos: JanelaAmigos
var caixa: CaixaChat
var escrever: JanelaCarta
var lendo: JanelaCarta
var salas: Array = []          # JanelaSala
var _pedi_sala := {}           # amigo -> true (eu pedi a sala: ela abre na frente)
var mostrar_sistema := true


func _init(j: Node, c: ClienteMU, hud: Control) -> void:
	jogo = j
	cli = c
	janelas = Control.new()
	janelas.name = "JanelasMU"
	janelas.set_anchors_preset(Control.PRESET_FULL_RECT)
	janelas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(janelas)
	amigos = JanelaAmigos.new()
	janelas.add_child(amigos)
	caixa = CaixaChat.new()
	hud.add_child(caixa)
	amigos.adicionar.connect(func(n): cli.adicionar_amigo(n))
	amigos.apagar.connect(func(n): cli.apagar_amigo(n))
	amigos.conversar.connect(conversar)
	amigos.escrever.connect(escrever_carta)
	amigos.ler.connect(func(i): cli.ler_carta(i))
	amigos.apagar_cartas.connect(func(l):
		for i in l:
			cli.apagar_carta(i))
	amigos.recusar.connect(func(sim):
		cli.estado_chat(0 if sim else 1)
		if sim:
			for s in salas.duplicate():
				if is_instance_valid(s):
					s.fechar())
	amigos.mostrar_sala.connect(func(s):
		s.visible = true
		s.trazer())
	amigos.pergunta.connect(pergunta)
	caixa.falar.connect(_falar)
	# caixa aberta: vem pra frente e o registro sobe a altura dela (no original o registro fica logo acima)
	caixa.visibility_changed.connect(func():
		if caixa.visible:
			caixa.get_parent().move_child(caixa, -1)
		var r: Control = jogo.registro
		if r:
			if not r.has_meta("y0"):
				r.set_meta("y0", r.position.y)
			r.position.y = r.get_meta("y0") - (caixa.A * caixa.scale.y + 4 if caixa.visible else 0.0))
	caixa.botao_registro.connect(func(l): jogo.registro.visible = l)
	caixa.botao_sistema.connect(func(l): mostrar_sistema = l)
	_ligar_cli()


func _ligar_cli() -> void:
	cli.amigos.connect(func(l, _c):
		print("TESTE amigos %s" % [l])
		amigos.definir(l)
		cli.estado_chat(0 if amigos.recusa else 1))
	cli.caixa_cartas.connect(func(n, mx):
		amigos.maximo_cartas = mx
		if n > 0:
			linha("sistema", "", DicaItem.t(1072) % [n, mx])
		if mx > 0 and n >= mx:
			linha("erro", "", DicaItem.t(1073)))
	cli.amigo_novo.connect(func(n, sv):
		print("TESTE amigo novo %s" % n)
		amigos.novo(n, sv)
		if sv in [0xFF, 0xFE, 0xFC]:
			aviso(DicaItem.t(1075)))
	cli.amigo_resultado.connect(func(r, n):
		print("TESTE amigo resultado %d %s" % [r, n])
		var t := {0: n + " " + DicaItem.t(1047), 3: DicaItem.t(1048), 4: n + " " + DicaItem.t(1049), 5: DicaItem.t(1050),
			6: DicaItem.t(1068)}
		if t.has(r):
			aviso(t[r]))
	cli.amigo_saiu.connect(func(n):
		print("TESTE amigo apagado %s" % n)
		amigos.saiu(n))
	cli.amigo_nao_apagou.connect(func(_n): aviso(DicaItem.t(1052)))
	cli.amigo_estado.connect(func(n, sv):
		print("TESTE amigo %s no servidor %d" % [n, sv])
		amigos.estado(n, sv))
	cli.pedido_amizade.connect(func(n):
		print("TESTE pedido de amizade de %s" % n)
		jogo._som("amigo")
		pergunta("%s %s" % [n, DicaItem.t(1051)], 0, n, func(sim, _t): cli.responder_amizade(sim, n)))
	cli.carta.connect(func(c):
		print("TESTE carta %s" % [c])
		amigos.carta(c)
		if c.estado == 2:
			jogo._som("carta")
			linha("sistema", "", DicaItem.t(1062)))
	cli.carta_enviada.connect(_carta_enviada)
	cli.carta_aberta.connect(_carta_aberta)
	cli.carta_apagada.connect(func(ok, i):
		print("TESTE carta apagada %s %d" % [ok, i])
		if not ok:
			aviso(DicaItem.t(1055))
			return
		if is_instance_valid(lendo) and int(lendo.carta.get("indice", -1)) == i:
			lendo._sair()
		amigos.carta_apagada(i)
		if is_instance_valid(lendo) and int(lendo.carta.get("indice", -1)) > i:
			lendo.carta.indice -= 1)
	cli.sala_chat.connect(_sala_chat)
	cli.convite_sala.connect(func(ok, pedido):
		print("TESTE convite resultado %d %d" % [ok, pedido])
		for s in salas:
			if is_instance_valid(s) and s.pedidos.has(pedido):
				s.resultado_convite(ok, pedido))
	cli.fala.connect(_ouvir)
	cli.chat_guilda.connect(func(n, t):
		print("TESTE chat guilda %s: %s" % [n, t])
		linha("guilda", n, t))
	cli.cochicho.connect(func(n, t):
		print("TESTE cochicho de %s: %s" % [n, t])
		if not caixa.bloquear_cochicho:
			linha("cochicho", n, t))
	cli.cochicho_falhou.connect(func():
		print("TESTE cochicho sem ninguem")
		linha("erro", "", DicaItem.t(482)))


# --- janelinhas ------------------------------------------------------------------------

func pergunta(texto: String, tipo: int, guardado: String, retorno: Callable) -> JanelaPergunta:
	var p := JanelaPergunta.new(texto, tipo)
	p.guardado = guardado
	p.respondeu.connect(func(sim, t): retorno.call(sim, t))
	janelas.add_child(p)
	p.centrar()
	return p


func aviso(texto: String) -> void:
	print("TESTE aviso %s" % texto)
	pergunta(texto, 1, "", func(_s, _t): pass)


# --- registro e balao ---------------------------------------------------------------------

func linha(tipo: String, nome: String, texto: String) -> void:
	if tipo == "sistema" and not mostrar_sistema:
		return
	var c: Array = CORES.get(tipo, CORES.normal)
	var t := (nome + " : " + texto) if nome != "" else texto
	t = t.replace("[", "[lb]")
	if tipo == "gm":
		t = "[b]" + t + "[/b]"
	jogo._msg("[bgcolor=#%s][color=#%s]%s[/color][/bgcolor]" % [c[0], c[1], t])


# C1 00 que chegou: o prefixo diz o canal (ReceiveChat)
func _ouvir(nome: String, t: String) -> void:
	print("TESTE fala %s: %s" % [nome, t])
	if t.begins_with("~"):
		linha("grupo", nome, t.substr(1))
	elif t.begins_with("@@"):
		linha("alianca", nome, t.substr(2))
	elif t.begins_with("$"):
		linha("gens", nome, t.substr(1).trim_prefix(" "))
	elif t.begins_with("#"):
		balao(nome, t.substr(1))
	else:
		balao(nome, t)
		linha("normal", nome, t)


# AssignChat: o texto em cima da cabeca, em 2 linhas a partir de 20 letras; dura (letras*2 + 160) quadros de 25/s
func balao(nome: String, t: String) -> void:
	var e: Entidade = jogo.eu if nome == jogo.meu_nome else null
	if e == null:
		for x in jogo.entidades.values():
			if is_instance_valid(x) and x.tipo == "jogador" and x.nome == nome:
				e = x
	if e == null:
		return
	e.fala = partir(t)
	e.fala_ate = Time.get_ticks_msec() + int((t.length() * 2 + 160) / 25.0 * 1000.0)


# CutText: corta no espaco mais perto do meio
static func partir(t: String) -> PackedStringArray:
	if t.length() < 20:
		return PackedStringArray([t])
	var meio := t.length() / 2
	var melhor := -1
	for i in t.length():
		if t[i] == " " and (melhor < 0 or absi(i - meio) < absi(melhor - meio)):
			melhor = i
	if melhor < 0:
		melhor = meio
	return PackedStringArray([t.substr(0, melhor).strip_edges(), t.substr(melhor).strip_edges()])


# Enter na caixa
func _falar(t: String, para: String) -> void:
	if para != "":
		print("TESTE cochicho pra %s: %s" % [para, t])
		cli.cochichar(para, t)
		linha("cochicho", para, t)
	else:
		print("TESTE digitou %s" % t)
		cli.dizer(jogo.meu_nome, t)


# --- cartas ----------------------------------------------------------------------------------

func escrever_carta(para: String, assunto: String) -> void:
	if is_instance_valid(escrever):
		escrever.queue_free()
	escrever = JanelaCarta.new(false)
	escrever.pergunta.connect(pergunta)
	escrever.enviar.connect(func(p, t, txt, giro, anim):
		escrever.id_envio = randi() & 0x7FFFFFFF
		print("TESTE mandando carta pra %s: %s (giro %d, pose %d)" % [p, t, giro, anim])
		cli.enviar_carta(escrever.id_envio, p, t, txt, giro, anim))
	janelas.add_child(escrever)
	escrever.pos = Vector2(266, 40)
	escrever._ajustar()
	escrever.preparar(para, assunto, jogo.minha_classe, _meu_equip())


func _meu_equip() -> Dictionary:
	var d := {}
	var niveis := {}
	for s in 9:
		if jogo.inv.itens.has(s):
			d[s] = ItensMU.chave(jogo.inv.itens[s])
			niveis[s] = jogo.inv.itens[s].nivel
	d["niveis"] = niveis
	return d


func _carta_enviada(r: int, id: int) -> void:
	print("TESTE carta enviada %d" % r)
	var j := escrever if is_instance_valid(escrever) else null
	if r == 1:
		if j:
			j._sair()
		linha("sistema", "", DicaItem.t(1046) % CUSTO_CARTA)
		return
	if j:
		j.falhou_envio()
	var t := {0: 1053, 2: 1061, 3: 1064, 4: 1065, 6: 1068, 7: 423}
	if t.has(r):
		aviso(DicaItem.t(t[r]))


func _carta_aberta(info: Dictionary) -> void:
	var c := amigos.carta_de(info.indice)
	print("TESTE carta aberta %d de %s: %s" % [info.indice, c.get("de", "?"), info.texto])
	amigos.carta_lida(info.indice)
	amigos.selecionar_carta(info.indice)
	if not is_instance_valid(lendo):
		lendo = JanelaCarta.new(true)
		lendo.pergunta.connect(pergunta)
		lendo.responder.connect(escrever_carta)
		lendo.apagar.connect(func(i): cli.apagar_carta(i))
		lendo.andar.connect(func(i, passo):
			var l: Array = amigos.cartas
			for k in l.size():
				if l[k].indice == i and k + passo >= 0 and k + passo < l.size():
					cli.ler_carta(l[k + passo].indice)
					return)
		janelas.add_child(lendo)
		lendo.pos = Vector2(266, 40)
		lendo._ajustar()
	lendo.visible = true
	lendo.trazer()
	lendo.abrir(c if not c.is_empty() else {"indice": info.indice}, info)


# --- salas de chat -----------------------------------------------------------------------------

func conversar(amigo: String) -> void:
	for s in salas:
		if is_instance_valid(s) and s.amigo == amigo and s.sala.con != null:
			s.visible = true
			s.trazer()
			return
	_pedi_sala[amigo] = true
	print("TESTE pedindo sala com %s" % amigo)
	cli.abrir_sala(amigo)


func _sala_chat(info: Dictionary) -> void:
	print("TESTE sala %s" % [info])
	if info.ok == 0:
		aviso(DicaItem.t(1069))
		return
	if info.ok == 2:
		aviso(DicaItem.t(1070))
		return
	salas = salas.filter(func(s): return is_instance_valid(s))
	var pedi: bool = _pedi_sala.has(info.amigo)
	_pedi_sala.erase(info.amigo)
	var j: JanelaSala = null
	for s in salas:
		if s.amigo == info.amigo:
			j = s
			s.sair()
			pedi = pedi or s.visible
	if j == null:
		j = JanelaSala.new(info.amigo, jogo.meu_nome)
		j.convidar.connect(func(s, n):
			var pedido := randi() & 0x7FFFFFFF
			s.pedidos[pedido] = n
			print("TESTE convidando %s pra sala %d" % [n, s.sala.sala])
			cli.convidar_sala(n, s.sala.sala, pedido))
		j.amigos_de = func(): return amigos.lista.filter(func(a): return a.servidor < 0xFC).map(func(a): return a.nome)
		j.fechou.connect(func(): amigos.queue_redraw())
		j.sala.falou.connect(func(_i, n, t):
			print("TESTE sala %s: %s" % [n, t])
			if not j.visible:
				j.visible = true
				j.trazer()
				linha("sistema", "", DicaItem.t(1063)), CONNECT_DEFERRED)
		janelas.add_child(j)
		j.pos = Vector2(380 - 20 * salas.size(), 236 - 20 * salas.size())
		j._ajustar()
		salas.append(j)
		amigos.salas = salas
	j.visible = pedi
	if pedi:
		j.trazer()
	j.conectar(cli.host, info.sala, info.token)


func fechar_tudo() -> void:
	for s in salas:
		if is_instance_valid(s):
			s.fechar()
	salas.clear()
	for j in [escrever, lendo]:
		if is_instance_valid(j):
			j.queue_free()
	amigos.visible = false
	caixa.fechar()


func alguma_aberta() -> bool:
	for c in janelas.get_children():
		if c.visible:
			return true
	return false


# Esc: fecha a janela antiga de cima
func fechar_topo() -> bool:
	for i in range(janelas.get_child_count() - 1, -1, -1):
		var c := janelas.get_child(i)
		if c is JanelaMU and c.visible:
			c.fechar()
			return true
	return false


# roteiro dos testes (passo "M:" do jogo): faz o que o mouse e o teclado fariam
func roteiro(a: PackedStringArray) -> void:
	print("TESTE roteiro correio %s" % [a])
	match a[0]:
		"diz", "cochicho":
			caixa.abrir(a[1] if a[0] == "cochicho" else "")
			if a[0] == "diz":
				caixa.para.text = ""
			caixa.texto.text = a[-1]
			await jogo.get_tree().create_timer(1.5).timeout
			caixa.enviar()
		"aba":
			amigos.visible = true
			amigos.aba = int(a[1])
			amigos.trazer()
			amigos.queue_redraw()
		"carta":
			escrever_carta(a[1], a[2])
			escrever._texto.text = a[3]
			for i in (int(a[4]) if a.size() > 4 else 0):
				escrever.foto.proxima(1)
			await jogo.get_tree().create_timer(1.5).timeout
			escrever._apertou("enviar")
		"ler":
			var k := int(a[1]) if a.size() > 1 else 0
			if k < amigos.cartas.size():
				amigos.ler.emit(amigos.cartas[k].indice)
		"apagar":
			if is_instance_valid(lendo) and lendo.visible:
				lendo._apertou("apagar")
		"sim", "nao":
			for i in range(janelas.get_child_count() - 1, -1, -1):
				var c := janelas.get_child(i)
				if c is JanelaPergunta:
					c.responder(a[0] == "sim")
					break
		"sala":
			conversar(a[1])
		"fala":
			var s := _sala_da_frente()
			if s:
				s._mandar(a[1])
		"convida":
			var s := _sala_da_frente()
			if s:
				s._apertou("convidar")
				s.queue_redraw()
				await jogo.get_tree().create_timer(1.0).timeout
				s.convidar.emit(s, a[1])
		"sai":
			var s := _sala_da_frente()
			if s:
				s.fechar()
		"fecha":
			# fecha / fecha,carta / fecha,amigos
			if a.size() < 2:
				fechar_topo()
			elif a[1] == "carta" and is_instance_valid(lendo):
				lendo.fechar()
			elif a[1] == "amigos":
				amigos.fechar()
		"espera":
			await jogo.get_tree().create_timer(float(a[1])).timeout


func _sala_da_frente() -> JanelaSala:
	for i in range(janelas.get_child_count() - 1, -1, -1):
		var c := janelas.get_child(i)
		if c is JanelaSala and c.visible:
			return c
	return null
