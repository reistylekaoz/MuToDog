extends Node
# Tela do cliente: entra no OpenMU (servidor, conta, personagem), monta o mapa
# e mostra quem esta em volta. Clique no chao pra andar.

const ROXO := Color(0.55, 0.45, 0.95)

var cli: ClienteMU
var mundo: Node3D
var mapa_atual := -1
var eu: Entidade
var meu_nome := ""
var entidades := {}
var monstros := {}
var mapas := {}
var classes := {}
var _restante: Array[Vector2i] = []
var _fim_enviado := Vector2i(-1, -1)

var ui: CanvasLayer
var painel: PanelContainer
var campo_host: LineEdit
var campo_porta: LineEdit
var campo_conta: LineEdit
var campo_senha: LineEdit
var botao_entrar: Button
var aviso: Label
var lista: VBoxContainer
var hud: Control
var hud_texto: Label
var barra_vida: ProgressBar
var registro: RichTextLabel


func _ready() -> void:
	# o visualizador de mapa (main.tscn) segue abrindo no navegador com ?vista=1
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("vista="):
		get_tree().change_scene_to_file.call_deferred("res://main.tscn")
		return
	monstros = _json("res://dados/monstros.json")
	mapas = _json("res://dados/mapas.json")
	classes = _json("res://dados/classes.json")
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.06))
	cli = ClienteMU.new()
	add_child(cli)
	cli.estado_mudou.connect(_estado)
	cli.servidores.connect(_servidores)
	cli.personagens.connect(_personagens)
	cli.entrou.connect(_entrou)
	cli.objeto_entrou.connect(_objeto_entrou)
	cli.objeto_saiu.connect(_objeto_saiu)
	cli.objeto_andou.connect(_objeto_andou)
	cli.objeto_moveu.connect(_objeto_moveu)
	cli.objeto_morreu.connect(_objeto_morreu)
	cli.mapa_mudou.connect(_mapa_mudou)
	cli.vida.connect(func(v): barra_vida.value = v)
	cli.mensagem.connect(_msg)
	cli.golpe.connect(func(id, dano):
		if entidades.has(id):
			entidades[id].mostrar_dano(dano))
	cli.ataque.connect(func(id, alvo):
		if entidades.has(id) and entidades.has(alvo):
			entidades[id].olhar_para(entidades[alvo]))
	_montar_ui()
	_carregar_config()
	# testes: -- --auto conta,senha,personagem --andar x,y --gravacao arquivo
	# (no navegador: ?auto=...&andar=...&gravacao=1, toca dados/gravacao.txt)
	var p := _parametros()
	if p.has("gravacao"):
		Conexao.tocar(p.gravacao if FileAccess.file_exists(p.gravacao) else "res://dados/gravacao.txt")
	if p.has("andar"):
		var xy: PackedStringArray = p.andar.split(",")
		_andar_depois = Vector2i(int(xy[0]), int(xy[1]))
	if p.has("sair"):
		get_tree().create_timer(float(p.sair)).timeout.connect(func():
			print("TESTE fim: %d objetos na tela, eu em %s" % [entidades.size(), eu.tile if eu else "-"])
			cli._fechar()
			get_tree().quit())
	if p.has("auto"):
		var c: PackedStringArray = p.auto.split(",")
		campo_conta.text = c[0]
		campo_senha.text = c[1]
		meu_nome = c[2]
		_auto = true
		_entrar()


var _andar_depois := Vector2i(-1, -1)
var _auto := false


func _parametros() -> Dictionary:
	var p := {}
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search")
		for par in str(q).trim_prefix("?").split("&", false):
			var kv := par.split("=")
			if kv.size() == 2:
				p[kv[0]] = kv[1].uri_decode()
	var a := OS.get_cmdline_user_args()
	for i in range(0, a.size() - 1):
		if a[i].begins_with("--"):
			p[a[i].substr(2)] = a[i + 1]
	return p


func _json(c: String) -> Dictionary:
	if not FileAccess.file_exists(c):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(c))
	return d if d is Dictionary else {}


# --- tela de entrada -------------------------------------------------------

func _estilo(cor: Color, borda := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = cor
	s.border_color = borda
	s.set_border_width_all(1 if borda.a > 0 else 0)
	s.set_corner_radius_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _montar_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var tema := Theme.new()
	tema.default_font_size = 17
	tema.set_stylebox("panel", "PanelContainer", _estilo(Color(0.08, 0.08, 0.11, 0.96), Color(0.25, 0.22, 0.4)))
	tema.set_stylebox("normal", "LineEdit", _estilo(Color(0.13, 0.13, 0.17), Color(0.3, 0.3, 0.38)))
	tema.set_stylebox("focus", "LineEdit", _estilo(Color(0.13, 0.13, 0.17), ROXO))
	tema.set_stylebox("normal", "Button", _estilo(Color(0.2, 0.17, 0.36)))
	tema.set_stylebox("hover", "Button", _estilo(Color(0.28, 0.23, 0.5)))
	tema.set_stylebox("pressed", "Button", _estilo(Color(0.35, 0.29, 0.62)))
	tema.set_stylebox("disabled", "Button", _estilo(Color(0.14, 0.14, 0.17)))
	tema.set_color("font_color", "Label", Color(0.88, 0.88, 0.92))
	var raiz := Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.theme = tema
	ui.add_child(raiz)

	painel = PanelContainer.new()
	painel.custom_minimum_size = Vector2(440, 0)
	painel.set_anchors_preset(Control.PRESET_CENTER)
	painel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	painel.grow_vertical = Control.GROW_DIRECTION_BOTH
	raiz.add_child(painel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	painel.add_child(v)
	var titulo := Label.new()
	titulo.text = "MU Estudo"
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	v.add_child(titulo)
	var sub := Label.new()
	sub.text = "Cliente Godot pro OpenMU (Season 6)"
	sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.68))
	v.add_child(sub)
	campo_host = _campo(v, "Servidor (IP do OpenMU)", "127.127.127.127")
	campo_porta = _campo(v, "Porta do connect server", "44405")
	campo_conta = _campo(v, "Conta", "test0")
	campo_senha = _campo(v, "Senha", "")
	campo_senha.secret = true
	campo_senha.text_submitted.connect(func(_t): _entrar())
	botao_entrar = Button.new()
	botao_entrar.text = "Entrar"
	botao_entrar.pressed.connect(_entrar)
	v.add_child(botao_entrar)
	aviso = Label.new()
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82))
	aviso.text = "No Docker do OpenMU as contas de teste sao test0 a test9 (senha igual ao nome)."
	v.add_child(aviso)
	lista = VBoxContainer.new()
	lista.add_theme_constant_override("separation", 6)
	v.add_child(lista)

	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	raiz.add_child(hud)
	var caixa := PanelContainer.new()
	caixa.position = Vector2(12, 12)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(caixa)
	var hv := VBoxContainer.new()
	caixa.add_child(hv)
	hud_texto = Label.new()
	hv.add_child(hud_texto)
	barra_vida = ProgressBar.new()
	barra_vida.custom_minimum_size = Vector2(260, 16)
	barra_vida.show_percentage = false
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.2, 0.08, 0.08)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = Color(0.85, 0.2, 0.2)
	barra_vida.add_theme_stylebox_override("background", fundo)
	barra_vida.add_theme_stylebox_override("fill", cheio)
	hv.add_child(barra_vida)
	var ajuda := Label.new()
	ajuda.text = "Clique no chao pra andar · Q/E gira · roda do mouse aproxima"
	ajuda.add_theme_font_size_override("font_size", 14)
	ajuda.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))
	hv.add_child(ajuda)
	var sair := Button.new()
	sair.text = "Sair"
	sair.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sair.position = Vector2(-90, 12)
	sair.pressed.connect(_sair)
	hud.add_child(sair)
	registro = RichTextLabel.new()
	registro.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	registro.position = Vector2(12, -170)
	registro.size = Vector2(560, 158)
	registro.scroll_following = true
	registro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	registro.add_theme_stylebox_override("normal", _estilo(Color(0, 0, 0, 0.45)))
	registro.add_theme_font_size_override("normal_font_size", 15)
	hud.add_child(registro)


func _campo(pai: Control, rotulo: String, valor: String) -> LineEdit:
	var l := Label.new()
	l.text = rotulo
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))
	pai.add_child(l)
	var e := LineEdit.new()
	e.text = valor
	pai.add_child(e)
	return e


func _carregar_config() -> void:
	var c := ConfigFile.new()
	if c.load("user://conexao.cfg") == OK:
		campo_host.text = c.get_value("conexao", "host", campo_host.text)
		campo_porta.text = str(c.get_value("conexao", "porta", campo_porta.text))
		campo_conta.text = c.get_value("conexao", "conta", campo_conta.text)


func _salvar_config() -> void:
	var c := ConfigFile.new()
	c.set_value("conexao", "host", campo_host.text)
	c.set_value("conexao", "porta", int(campo_porta.text))
	c.set_value("conexao", "conta", campo_conta.text)
	c.save("user://conexao.cfg")


func _entrar() -> void:
	if campo_conta.text.strip_edges() == "" or campo_senha.text == "":
		aviso.text = "Preencha a conta e a senha."
		return
	_salvar_config()
	_limpar_lista()
	botao_entrar.disabled = true
	cli.entrar(campo_conta.text.strip_edges(), campo_senha.text)
	cli.conectar(campo_host.text.strip_edges(), int(campo_porta.text))


func _limpar_lista() -> void:
	for c in lista.get_children():
		c.queue_free()


func _estado(e: String, t: String) -> void:
	var textos := {
		"conectando": "Conectando em %s..." % t,
		"lista": "Pedindo a lista de servidores...",
		"pedindo_endereco": "Pedindo o endereco do servidor %s..." % t,
		"conectando_jogo": "Conectando no servidor do jogo...",
		"login": "Entrando com a conta %s..." % t,
		"logado": "Conta aceita. Buscando os personagens...",
		"personagens": "Escolha o personagem:",
		"entrando": "Entrando com %s..." % t,
		"jogo": "",
	}
	if e == "erro":
		_voltar("Nao deu: %s. Confira se o OpenMU esta ligado e o IP e a porta." % t)
	elif e == "erro_login":
		_voltar("Login recusado: %s." % t)
	elif textos.has(e):
		aviso.text = textos[e]


func _voltar(texto: String) -> void:
	_limpar_mundo()
	hud.visible = false
	painel.visible = true
	botao_entrar.disabled = false
	_limpar_lista()
	aviso.text = texto


func _servidores(l: Array) -> void:
	_limpar_lista()
	if l.size() == 1 or _auto:
		cli.pedir_servidor(l[0].id)
		return
	aviso.text = "Escolha o servidor:"
	for s in l:
		var b := Button.new()
		b.text = "Servidor %d  ·  %d%% ocupado" % [s.id + 1, s.carga]
		b.pressed.connect(func():
			_limpar_lista()
			cli.pedir_servidor(s.id))
		lista.add_child(b)


func _personagens(l: Array) -> void:
	_limpar_lista()
	if l.is_empty():
		aviso.text = "Essa conta nao tem personagem. Crie um no cliente original ou no painel do OpenMU."
		return
	for p in l:
		if meu_nome != "" and p.nome == meu_nome:
			_escolher(p.nome)
			return
	for p in l:
		var b := Button.new()
		b.text = "%s  ·  %s  ·  nivel %d" % [p.nome, classes.get(str(p.classe), "?"), p.nivel]
		b.pressed.connect(_escolher.bind(p.nome))
		lista.add_child(b)


func _escolher(nome: String) -> void:
	meu_nome = nome
	_limpar_lista()
	cli.escolher(nome)


# --- mundo -------------------------------------------------------------------

func _entrou(info: Dictionary) -> void:
	painel.visible = false
	hud.visible = true
	barra_vida.max_value = info.vida_max
	barra_vida.value = info.vida
	_abrir_mapa(info.mapa, info.x, info.y)
	_msg("Entrou em %s (%d, %d)." % [mapas.get(str(info.mapa), "mapa %d" % info.mapa), info.x, info.y])
	print("TESTE entrou %s" % info)
	if _andar_depois.x >= 0:
		await get_tree().create_timer(2.0).timeout
		if eu:
			andar_ate(_andar_depois)
			print("TESTE andando de %s ate %s (%d passos)" % [eu.tile, _andar_depois, eu.fila.size()])


func _limpar_mundo() -> void:
	entidades.clear()
	eu = null
	_restante.clear()
	if mundo:
		mundo.queue_free()
		mundo = null
	mapa_atual = -1


func _abrir_mapa(mapa: int, x: int, y: int) -> void:
	_limpar_mundo()
	mapa_atual = mapa
	mundo = Node3D.new()
	mundo.set_script(load("res://scripts/mundo.gd"))
	mundo.modo_jogo = true
	mundo.numero = mapa + 1
	mundo.alvo = Vector2(x + 0.5, y + 0.5)
	mundo.distancia = 20.0
	mundo.inclinacao = 50.0
	add_child(mundo)
	if not mundo.tem_dados:
		_msg("[color=#e8b04a]%s ainda nao foi convertido: chao liso, so as posicoes.[/color]" % mapas.get(str(mapa), "Esse mapa"))
	eu = Entidade.new()
	mundo.add_child(eu)
	eu.montar(mundo, cli.meu_id, "eu", meu_nome, x, y)
	entidades[cli.meu_id] = eu
	mundo.seguir = eu


func _objeto_entrou(o: Dictionary) -> void:
	if mundo == null:
		return
	if o.id == cli.meu_id:
		return
	if entidades.has(o.id):
		entidades[o.id].queue_free()
	var tipo := "jogador"
	var nome: String = o.get("nome", "")
	if o.tipo == "npc":
		var m: Array = monstros.get(str(o.numero), ["#%d" % o.numero, 0])
		nome = m[0]
		tipo = ["monstro", "npc", "guarda"][m[1]] if int(m[1]) < 3 else "outro"
	var e := Entidade.new()
	mundo.add_child(e)
	e.montar(mundo, o.id, tipo, nome, o.x, o.y)
	entidades[o.id] = e
	if Vector2i(o.ax, o.ay) != Vector2i(o.x, o.y):
		_objeto_andou(o.id, o.ax, o.ay, [])


func _objeto_saiu(id: int) -> void:
	if id != cli.meu_id and entidades.has(id):
		entidades[id].queue_free()
		entidades.erase(id)


func _objeto_andou(id: int, x: int, y: int, _passos: Array) -> void:
	if id == cli.meu_id or not entidades.has(id):
		return
	var e: Entidade = entidades[id]
	e.ir_para(Vector2i(x, y), mundo.caminho(e.tile, Vector2i(x, y)))


func _objeto_moveu(id: int, x: int, y: int) -> void:
	if entidades.has(id):
		entidades[id].teleportar(x, y)
		if id == cli.meu_id:
			_restante.clear()


func _objeto_morreu(id: int) -> void:
	if not entidades.has(id):
		return
	var e: Entidade = entidades[id]
	if id == cli.meu_id:
		_msg("[color=#e05050]Voce morreu.[/color]")
		return
	var tw := create_tween()
	tw.tween_property(e, "scale", Vector3(1, 0.05, 1), 0.6)


func _mapa_mudou(mapa: int, x: int, y: int) -> void:
	if mapa != mapa_atual:
		_abrir_mapa(mapa, x, y)
		_msg("Foi pra %s (%d, %d)." % [mapas.get(str(mapa), "mapa %d" % mapa), x, y])
	elif eu:
		eu.teleportar(x, y)
		_restante.clear()


func _msg(t: String) -> void:
	if registro:
		registro.append_text(t + "\n")


func _sair() -> void:
	cli._fechar()
	meu_nome = ""
	_voltar("Saiu. Entre de novo quando quiser.")


func _unhandled_input(ev: InputEvent) -> void:
	if eu == null or mundo == null:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var t: Vector2i = mundo.tile_na_tela(ev.position)
		if t.x < 0:
			return
		andar_ate(t)


func andar_ate(t: Vector2i) -> void:
	var de: Vector2i = eu.fila[0] if eu.andando() else eu.tile
	var c: Array[Vector2i] = mundo.caminho(de, t)
	if c.is_empty():
		return
	if eu.andando():
		c.push_front(de)
	eu.ir_para(t, c.duplicate())
	_restante = c
	_fim_enviado = Vector2i(-1, -1)
	_mandar_trecho()


# manda ate 15 passos por pacote; o resto vai quando chegar no fim do trecho
func _mandar_trecho() -> void:
	if _restante.is_empty():
		return
	var de: Vector2i = eu.tile
	var dirs := []
	var ant: Vector2i = de
	while not _restante.is_empty() and dirs.size() < 15:
		var p: Vector2i = _restante[0]
		var i := ClienteMU.PASSOS.find(p - ant)
		if i < 0:
			break
		dirs.append(i)
		ant = _restante.pop_front()
	if dirs.is_empty():
		_restante.clear()
		return
	cli.andar(de.x, de.y, dirs)
	_fim_enviado = ant


func _process(_dt: float) -> void:
	if eu == null:
		return
	if not _restante.is_empty() and eu.tile == _fim_enviado:
		_mandar_trecho()
	var seg: bool = mundo.zona_segura(eu.tile.x, eu.tile.y)
	hud_texto.text = "%s  ·  %s  (%d, %d)%s" % [meu_nome, mapas.get(str(mapa_atual), "?"), eu.tile.x, eu.tile.y, "  ·  zona segura" if seg else ""]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and cli:
		cli._fechar()
