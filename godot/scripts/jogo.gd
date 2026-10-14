extends Node
# Tela do cliente: entra no OpenMU (servidor, conta, personagem), monta o mapa
# e mostra quem esta em volta. Clique no chao pra andar, no monstro pra atacar
# (segue batendo ate ele morrer) e no item do chao pra pegar.

const ROXO := Color(0.55, 0.45, 0.95)

var cli: ClienteMU
var mundo: Node3D
var mapa_atual := -1
var eu: Entidade
var meu_nome := ""
var minha_classe := 0
var _classe_de := {}
var entidades := {}
var monstros := {}
var mapas := {}
var classes := {}
var itens_nomes := {}
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
var barra_mu: HudMu
var janela_personagem: PanelContainer
var texto_personagem: Label
var meus_pontos := 0
var registro: RichTextLabel

# combate e itens
const ALCANCE := 1          # ataque sem skill: do lado do monstro
const RECARGA := 0.9        # segundos entre um golpe e outro
var alvo_id := -1           # monstro que estou atacando
var item_alvo := -1         # item do chao que vou pegar
var itens := {}             # id -> ItemChao
var sobre: Entidade         # debaixo do mouse
var _recarga := 0.0
var _repensar := 0.0
var _aviso_seguro := false
var meu_nivel := 1
var exp_atual := 0
var exp_prox := 0
var meu_zen := 0
var som: Som
var brilho := 2.0

# inventario e skills
var inv: Inventario
var minhas_skills := {}     # indice no servidor -> numero da skill
var _skill_recarga := 0.0
var skill_alvo := -1        # monstro (ou ponto) que a skill atual vai pegar quando chegar perto
var skill_ponto := Vector2i(-1, -1)
var skill_numero := -1
const RECARGA_SKILL := 0.8
const EM_VOLTA := [41, 42, 232, 9, 14]   # skills de area em volta de quem solta
# QWER: categorias de pocao do MU (vida, mana, SD, complexa); a maior primeiro
const POCOES := [["14,3", "14,2", "14,1", "14,0"], ["14,6", "14,5", "14,4"], ["14,37", "14,36", "14,35"], ["14,40", "14,39", "14,38"]]
var pocao_escolhida: Array = ["", "", "", ""]   # chave do item que a pessoa pos na tecla


func _ready() -> void:
	# o visualizador de mapa (main.tscn) segue abrindo no navegador com ?vista=1
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search")).contains("vista="):
		get_tree().change_scene_to_file.call_deferred("res://main.tscn")
		return
	# vitrine dos personagens convertidos: ?vitrine=1 (ou -- --vitrine 1)
	if _parametros().has("vitrine"):
		get_tree().change_scene_to_file.call_deferred("res://vitrine.tscn")
		return
	# atlas dos icones dos itens: so no export "Icones" (testes/icones.mjs)
	if _parametros().has("icones"):
		var n := Node.new()
		n.set_script(load("res://scripts/icones.gd"))
		add_child(n)
		return
	monstros = _json("res://dados/monstros.json")
	mapas = _json("res://dados/mapas.json")
	classes = _json("res://dados/classes.json")
	itens_nomes = _json("res://dados/itens.json")
	RenderingServer.set_default_clear_color(Color(0.04, 0.04, 0.06))
	add_child(ModelosMU.new())
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
	cli.vida.connect(func(v): barra_mu.vida = v; _hud_nivel())
	cli.sd.connect(func(v): barra_mu.sd = v; _hud_nivel())
	cli.ag.connect(func(v): barra_mu.ag = v; _hud_nivel())
	cli.maximo.connect(func(q, v): barra_mu.set(q + "_max", maxi(v, 1)); _hud_nivel())
	cli.mensagem.connect(_msg)
	cli.mana.connect(func(v): barra_mu.mana = v; _hud_nivel())
	cli.experiencia.connect(_experiencia)
	cli.nivel.connect(_nivel)
	cli.itens_cairam.connect(_itens_cairam)
	cli.itens_sumiram.connect(_itens_sumiram)
	cli.pegou.connect(_pegou)
	cli.nao_pegou.connect(func(m): _msg("[color=#e8b04a]Nao deu pra pegar (%s).[/color]" % {253: "juntou com o que ja tinha", 254: "limite de zen"}.get(m, "inventario cheio ou longe")))
	cli.zen.connect(func(v):
		if inv:
			inv.zen = v
			inv.queue_redraw()
		if v > meu_zen:
			_msg("[color=#f0c860]+%s Zen[/color]" % ItemChao._milhar(v - meu_zen))
			print("TESTE zen +%d (total %d)" % [v - meu_zen, v])
		meu_zen = v
		_hud_nivel())
	cli.golpe.connect(func(id, dano):
		if entidades.has(id):
			entidades[id].mostrar_dano(dano))
	cli.ataque.connect(func(id, alvo):
		if entidades.has(id) and entidades.has(alvo):
			entidades[id].olhar_para(entidades[alvo]))
	_montar_ui()
	_ligar_inventario_e_skills()
	_carregar_config()
	# testes: -- --auto conta,senha,personagem --andar x,y --gravacao arquivo
	# (no navegador: ?auto=...&andar=...&gravacao=1, toca dados/gravacao.txt)
	var p := _parametros()
	if p.has("gravacao"):
		var fita := "res://dados/gravacao_%s.txt" % p.gravacao
		if FileAccess.file_exists(p.gravacao):
			fita = p.gravacao
		elif not FileAccess.file_exists(fita):
			fita = "res://dados/gravacao.txt"
		Conexao.tocar(fita)
	if p.has("andar"):
		var xy: PackedStringArray = p.andar.split(",")
		_andar_depois = Vector2i(int(xy[0]), int(xy[1]))
	if p.has("sair"):
		get_tree().create_timer(float(p.sair)).timeout.connect(func():
			print("TESTE fim: %d objetos na tela, eu em %s" % [entidades.size(), eu.tile if eu else "-"])
			cli._fechar()
			get_tree().quit())
	if p.has("cacar"):
		_cacar = int(p.cacar)
	if p.has("skill"):
		_cacar_skill = true
		_skill_teste = int(p.skill)
	if p.has("inventario"):
		cli.inventario.connect(_teste_inventario, CONNECT_ONE_SHOT)
	if p.has("auto"):
		var c: PackedStringArray = p.auto.split(",")
		campo_conta.text = c[0]
		campo_senha.text = c[1]
		meu_nome = c[2]
		_auto = true
		_entrar()


var _andar_depois := Vector2i(-1, -1)
var _auto := false
var _cacar := 0      # testes: --cacar N mata N monstros sozinho (mira o mais perto, pega o que cair)
var _mortos := 0
var _cacar_t := 0.0
var _tentados := []  # itens do chao que o cacador ja foi pegar


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
	titulo.text = "openmu"
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
	# canto de cima: onde estou (o MU mostra o mapa e a posicao) e a ajuda
	var hv := VBoxContainer.new()
	hv.position = Vector2(12, 8)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hv)
	hud_texto = Label.new()
	hud_texto.add_theme_font_size_override("font_size", 15)
	hud_texto.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	hud_texto.add_theme_constant_override("outline_size", 4)
	hud_texto.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hv.add_child(hud_texto)
	var ajuda := Label.new()
	ajuda.text = "Clique: anda, ataca, pega · botao direito: skill · 1 a 5 troca a skill · Q W E R pocoes · I inventario · C personagem · setas giram · roda aproxima · M som · - = brilho"
	ajuda.add_theme_font_size_override("font_size", 12)
	ajuda.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	ajuda.add_theme_constant_override("outline_size", 3)
	ajuda.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hv.add_child(ajuda)
	# a barra do MU embaixo
	barra_mu = HudMu.new()
	barra_mu.botao.connect(_botao_barra)
	barra_mu.escolheu_skill.connect(_escolher_skill)
	barra_mu.usar_atalho.connect(_usar_pocao)
	hud.add_child(barra_mu)
	inv = Inventario.new()
	inv.aviso.connect(func(t): _msg("[color=#e8b04a]%s[/color]" % t))
	inv.mover.connect(func(de, para):
		if inv.itens.has(de):
			cli.mover_item(de, para, inv.itens[de].bytes))
	inv.usar.connect(func(slot, alvo): cli.usar_item(slot, alvo))
	hud.add_child(inv)
	# janela do personagem (C)
	janela_personagem = PanelContainer.new()
	janela_personagem.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	janela_personagem.position = Vector2(-300, 60)
	janela_personagem.custom_minimum_size = Vector2(280, 0)
	janela_personagem.add_theme_stylebox_override("panel", _estilo(Color(0.05, 0.04, 0.03, 0.88)))
	janela_personagem.visible = false
	hud.add_child(janela_personagem)
	texto_personagem = Label.new()
	texto_personagem.add_theme_font_size_override("font_size", 15)
	texto_personagem.add_theme_color_override("font_color", Color(0.95, 0.88, 0.7))
	janela_personagem.add_child(texto_personagem)
	var sair := Button.new()
	sair.text = "Sair"
	sair.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sair.position = Vector2(-90, 12)
	sair.pressed.connect(_sair)
	hud.add_child(sair)
	# o Sair sai da frente do X do inventario
	inv.visibility_changed.connect(func(): sair.position.x = hud.size.x - 90 - (inv.size.x * inv.scale.x if inv.visible else 0.0))
	registro = RichTextLabel.new()
	registro.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	registro.position = Vector2(12, -250)
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
		_classe_de[p.nome] = [p.classe, p.nivel]
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
	minha_classe = _classe_de.get(nome, [0, 1])[0]
	meu_nivel = _classe_de.get(nome, [0, 1])[1]
	_limpar_lista()
	cli.escolher(nome)


# --- mundo -------------------------------------------------------------------

func _entrou(info: Dictionary) -> void:
	painel.visible = false
	hud.visible = true
	barra_mu.vida = info.vida
	barra_mu.vida_max = maxi(info.vida_max, 1)
	barra_mu.mana = info.mana
	barra_mu.mana_max = maxi(info.mana_max, 1)
	barra_mu.sd = info.sd
	barra_mu.sd_max = maxi(info.sd_max, 1)
	barra_mu.ag = info.ag
	barra_mu.ag_max = maxi(info.ag_max, 1)
	meus_pontos = info.pontos
	exp_atual = info.exp
	exp_prox = info.exp_prox
	meu_zen = info.zen
	inv.zen = info.zen
	_hud_nivel()
	_abrir_mapa(info.mapa, info.x, info.y)
	_msg("Entrou em %s (%d, %d)." % [mapas.get(str(info.mapa), "mapa %d" % info.mapa), info.x, info.y])
	print("TESTE entrou %s" % info)
	if _parametros().has("chao_teste"):
		_chao_teste(info.x, info.y)
	if _andar_depois.x >= 0:
		await get_tree().create_timer(2.0).timeout
		if eu:
			andar_ate(_andar_depois)
			print("TESTE andando de %s ate %s (%d passos)" % [eu.tile, _andar_depois, eu.fila.size()])


func _limpar_mundo() -> void:
	entidades.clear()
	itens.clear()
	alvo_id = -1
	item_alvo = -1
	skill_numero = -1
	sobre = null
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
	var cam_t: String = _parametros().get("camera", "")  # testes: camera=dist,inclinacao,giro
	if cam_t != "":
		var c := cam_t.split(",")
		mundo.distancia = float(c[0])
		mundo.inclinacao = float(c[1])
		if c.size() > 2:
			mundo.giro = float(c[2])
	mundo.brilho = brilho
	add_child(mundo)
	mundo.brilho_mudou.connect(func(v: float) -> void:
		brilho = v
		_msg("Brilho %s (o padrao e 2,0)" % str(snappedf(v, 0.1)).replace(".", ",")))
	if not mundo.tem_dados:
		_msg("[color=#e8b04a]%s ainda nao foi convertido: chao liso, so as posicoes.[/color]" % mapas.get(str(mapa), "Esse mapa"))
	eu = Entidade.new()
	mundo.add_child(eu)
	eu.montar(mundo, cli.meu_id, "eu", meu_nome, x, y, Boneco.da_classe(minha_classe))
	entidades[cli.meu_id] = eu
	mundo.seguir = eu
	_vestir_eu()


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
	e.montar(mundo, o.id, tipo, nome, o.x, o.y,
		Boneco.do_npc(o.numero) if o.tipo == "npc" else Boneco.da_classe(o.get("classe", 0)))
	entidades[o.id] = e
	if e.boneco and o.has("equip"):
		e.boneco.vestir(o.equip)
	if Vector2i(o.ax, o.ay) != Vector2i(o.x, o.y):
		_objeto_andou(o.id, o.ax, o.ay, [])


func _objeto_saiu(id: int) -> void:
	if entidades.get(id) == sobre:
		sobre = null
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
	e.morrer()
	if id == alvo_id:
		alvo_id = -1
	if id == cli.meu_id:
		alvo_id = -1
		item_alvo = -1
		_msg("[color=#e05050]Voce morreu.[/color]")


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
	if ev is InputEventMouseMotion:
		_sobre(_entidade_na_tela(ev.position))
		if inv.visible and inv.na_mao >= 0:
			inv.mouse_fora(ev.position)
	if ev is InputEventKey and ev.pressed and not ev.echo and _teclas(ev):
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and inv.visible and inv.na_mao >= 0:
		# item na mao e clique fora da janela: larga no chao, no tile do mouse
		var tc: Vector2i = mundo.tile_na_tela(ev.position)
		if tc.x >= 0:
			cli.largar_item(tc.x, tc.y, inv.na_mao)
			inv.esperando = inv.na_mao
			inv.soltar()
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		barra_mu.fechar_lista()
		skill_numero = -1
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		_skill_no_mouse(ev.position)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_C:
		_botao_barra("personagem")
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_M and som:
		_msg("Som desligado." if som.alternar() else "Som ligado.")
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var e := _entidade_na_tela(ev.position)
		if e and e.tipo == "monstro":
			mirar(e.id)
			return
		var t: Vector2i = mundo.tile_na_tela(ev.position)
		var it := _item_perto(t)
		if it:
			pegar_item(it.id)
			return
		if t.x < 0:
			return
		alvo_id = -1
		item_alvo = -1
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


func _process(dt: float) -> void:
	if eu == null:
		return
	_combate(dt)
	_skills(dt)
	if not _restante.is_empty() and eu.tile == _fim_enviado:
		_mandar_trecho()
	_costas_t -= dt
	if _costas_t <= 0.0:
		# na zona segura a arma vai pras costas (como no cliente)
		_costas_t = 0.3
		for e: Entidade in entidades.values():
			if is_instance_valid(e) and e.boneco and e.tipo in ["eu", "jogador"]:
				e.boneco.arma_nas_costas(mundo.zona_segura(e.tile.x, e.tile.y))
	var seg: bool = mundo.zona_segura(eu.tile.x, eu.tile.y)
	if som == null:
		som = Som.new()
		add_child(som)
	som.atualizar(mapa_atual, seg, mundo.camada1(eu.tile.x, eu.tile.y))
	hud_texto.text = "%s  ·  %s  (%d, %d)%s" % [meu_nome, mapas.get(str(mapa_atual), "?"), eu.tile.x, eu.tile.y, "  ·  zona segura" if seg else ""]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and cli:
		cli._fechar()


# --- combate e itens -----------------------------------------------------------

# quem esta debaixo do mouse: o retangulo do boneco na tela (do pe a cabeca)
func _entidade_na_tela(tela: Vector2) -> Entidade:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var melhor: Entidade = null
	var perto := INF
	for e: Entidade in entidades.values():
		if e == eu or e.morto or not is_instance_valid(e):
			continue
		var pe := e.global_position
		var cabeca := pe + Vector3.UP * e.altura()
		if cam.is_position_behind(pe):
			continue
		var a := cam.unproject_position(pe)
		var b := cam.unproject_position(cabeca)
		var alto := maxf(a.y - b.y, 24.0)
		var largo := maxf(alto * 0.45, 22.0)
		if absf(tela.x - (a.x + b.x) / 2.0) <= largo / 2.0 and tela.y <= a.y + 6 and tela.y >= b.y - 6:
			var d := cam.global_position.distance_to(pe)
			if d < perto:
				perto = d
				melhor = e
	return melhor


func _sobre(e: Entidade) -> void:
	if e == sobre:
		return
	if is_instance_valid(sobre) and sobre.id != alvo_id:
		sobre.destacar(false)
	sobre = e
	if e:
		e.destacar(true)


func _item_perto(t: Vector2i) -> ItemChao:
	if t.x < 0:
		return null
	for it: ItemChao in itens.values():
		if (it.tile - t).abs().x <= 0 and (it.tile - t).abs().y <= 0:
			return it
	return null


static func _distancia(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func mirar(id: int) -> void:
	if entidades.has(alvo_id) and alvo_id != id:
		entidades[alvo_id].destacar(false)
	alvo_id = id
	item_alvo = -1
	_repensar = 0.0
	_aviso_seguro = false
	entidades[id].destacar(true)


func pegar_item(id: int) -> void:
	item_alvo = id
	alvo_id = -1
	_repensar = 0.0


# anda ate ficar a "dist" tiles do alvo (o caminho para no primeiro tile que ja serve)
func _ir_perto(t: Vector2i, dist: int) -> void:
	var c: Array[Vector2i] = mundo.caminho(eu.tile, t)
	var corte: Array[Vector2i] = []
	for p in c:
		corte.append(p)
		if _distancia(p, t) <= dist:
			break
	if corte.is_empty():
		return
	andar_ate(corte[-1])


func _cacador(dt: float) -> void:
	_cacar_t -= dt
	if _cacar_t > 0.0 or eu.morto or alvo_id >= 0 or item_alvo >= 0 or skill_numero >= 0 or eu.andando():
		return
	_cacar_t = 0.5
	var melhor_item: ItemChao = null
	for it: ItemChao in itens.values():
		if _distancia(it.tile, eu.tile) <= 6 and it.id not in _tentados:
			melhor_item = it
	if melhor_item:
		print("TESTE indo pegar %s em %s" % [melhor_item.nome, melhor_item.tile])
		_tentados.append(melhor_item.id)
		pegar_item(melhor_item.id)
		return
	if _mortos >= _cacar:
		return
	var melhor: Entidade = null
	for e: Entidade in entidades.values():
		if e.tipo == "monstro" and not e.morto and not mundo.zona_segura(e.tile.x, e.tile.y):
			if melhor == null or _distancia(e.tile, eu.tile) < _distancia(melhor.tile, eu.tile):
				melhor = e
	if melhor:
		print("TESTE mirando %s (%d) em %s" % [melhor.nome, melhor.id, melhor.tile])
		if _cacar_skill:
			skill_numero = _skill_teste
			skill_alvo = melhor.id
		else:
			mirar(melhor.id)


func _combate(dt: float) -> void:
	if _cacar > 0:
		_cacador(dt)
	_recarga -= dt
	_repensar -= dt
	if eu.morto:
		return
	if item_alvo >= 0:
		var it: ItemChao = itens.get(item_alvo)
		if it == null:
			item_alvo = -1
		elif _distancia(eu.tile, it.tile) <= 1 and not eu.andando():
			cli.pegar(it.id)
			item_alvo = -1
		elif not eu.andando() and _repensar <= 0.0:
			_repensar = 1.0
			_ir_perto(it.tile, 0)
		return
	if alvo_id < 0:
		return
	var a: Entidade = entidades.get(alvo_id)
	if a == null or a.morto:
		alvo_id = -1
		return
	if _distancia(eu.tile, a.tile) > ALCANCE:
		# o monstro anda: refaz o caminho de tempos em tempos
		if not eu.andando() or _repensar <= 0.0:
			_repensar = 0.6
			_ir_perto(a.tile, ALCANCE)
		return
	if eu.andando():
		return
	if mundo.zona_segura(eu.tile.x, eu.tile.y):
		if not _aviso_seguro:
			_msg("[color=#e8b04a]Na zona segura nao da pra atacar.[/color]")
			_aviso_seguro = true
		return
	if _recarga > 0.0:
		return
	_recarga = RECARGA
	var passo := Vector2i(signi(a.tile.x - eu.tile.x), signi(a.tile.y - eu.tile.y))
	var dir := maxi(ClienteMU.PASSOS.find(passo), 0)
	eu.olhar_para(a)
	cli.atacar(a.id, 38, dir)


func _experiencia(_morto: int, ganho: int) -> void:
	exp_atual += ganho
	_mortos += 1
	print("TESTE experiencia +%d (total %d de %d)" % [ganho, exp_atual, exp_prox])
	_msg("[color=#f0d070]+%d de experiencia[/color]" % ganho)
	_hud_nivel()


func _nivel(info: Dictionary) -> void:
	meu_nivel = info.nivel
	print("TESTE nivel %s" % info)
	barra_mu.vida_max = maxi(info.vida_max, 1)
	barra_mu.vida = info.vida_max
	barra_mu.mana_max = maxi(info.mana_max, 1)
	barra_mu.mana = info.mana_max
	meus_pontos = info.pontos
	exp_prox = exp_do_nivel(meu_nivel)
	_msg("[color=#ffd84a]Subiu pro nivel %d! (%d pontos pra distribuir)[/color]" % [meu_nivel, info.pontos])
	_hud_nivel()


# experiencia total pra passar do nivel n pro n+1 (formula do OpenMU, ate o 255)
static func exp_do_nivel(n: int) -> int:
	var e := (n + 9) * n * n * 10
	if n > 255:
		var m := n - 255
		e += (m + 9) * m * m * 1000
	return e


func _hud_nivel() -> void:
	if barra_mu == null:
		return
	barra_mu.exp_antes = exp_do_nivel(meu_nivel - 1) if meu_nivel > 1 else 0
	barra_mu.exp_atual = exp_atual
	barra_mu.exp_prox = exp_prox
	barra_mu.atualizar()
	var nomes_classe := ["Dark Wizard", "Dark Knight", "Fairy Elf", "Magic Gladiator", "Dark Lord", "Summoner", "Rage Fighter"]
	texto_personagem.text = "%s\n%s\n\nNivel %d\nExp %s / %s\nPontos pra distribuir %d\nZen %s\n\nVida %d / %d\nMana %d / %d\nSD %d / %d\nAG %d / %d" % [
		meu_nome, nomes_classe[clampi(minha_classe >> 2, 0, 6)], meu_nivel,
		ItemChao._milhar(exp_atual), ItemChao._milhar(exp_prox), meus_pontos, ItemChao._milhar(meu_zen),
		barra_mu.vida, barra_mu.vida_max, barra_mu.mana, barra_mu.mana_max,
		barra_mu.sd, barra_mu.sd_max, barra_mu.ag, barra_mu.ag_max]


func _botao_barra(qual: String) -> void:
	if qual == "personagem":
		janela_personagem.visible = not janela_personagem.visible
		_hud_nivel()
	elif qual == "inventario":
		inv.alternar()
	else:
		_msg("[color=#9a9ab0]%s ainda nao foi feito neste cliente.[/color]" % HudMu.DICAS[qual].get_slice(" (", 0))


func _itens_cairam(lista_itens: Array) -> void:
	if mundo == null:
		return
	for d in lista_itens:
		print("TESTE item no chao %s" % d)
		if itens.has(d.id):
			itens[d.id].queue_free()
		var it := ItemChao.new()
		mundo.add_child(it)
		it.montar(mundo, d, itens_nomes)
		itens[d.id] = it


# testes (?chao_teste=1): uma fileira de itens de mentira no chao em volta de mim, pra foto
func _chao_teste(x: int, y: int) -> void:
	var l := []
	var chaves := ["0,1", "4,0", "6,2", "7,5", "8,5", "9,5", "10,5", "11,5", "14,13", "14,1", "12,36", "5,0"]
	for k in chaves.size():
		l.append({"id": 60000 + k, "x": x - 3 + k % 4 * 2, "y": y + 2 + k / 4 * 2, "grupo": int(chaves[k].get_slice(",", 0)),
			"numero": int(chaves[k].get_slice(",", 1)), "nivel": 0, "exc": 0, "sorte": false})
	l.append({"id": 60100, "x": x + 5, "y": y + 4, "zen": 5000})
	_itens_cairam(l)


func _itens_sumiram(ids: Array) -> void:
	for id in ids:
		if itens.has(id):
			itens[id].queue_free()
			itens.erase(id)


func _pegou(slot: int, item: Dictionary) -> void:
	inv.entrou(slot, item)
	_contar_pocoes()
	var n: String = itens_nomes.get("%d,%d" % [item.grupo, item.numero], "item")
	_msg("[color=#9fe0a0]Pegou %s%s.[/color]" % [n, " +%d" % item.nivel if item.nivel > 0 else ""])
	print("TESTE pegou %s" % n)


# --- inventario --------------------------------------------------------------------

func _ligar_inventario_e_skills() -> void:
	cli.inventario.connect(func(l):
		inv.definir(l)
		print("TESTE inventario %d itens" % l.size())
		_vestir_eu()
		_contar_pocoes())
	cli.item_movido.connect(func(slot, it):
		print("TESTE movido para %d" % slot)
		inv.movido(slot, it)
		_vestir_eu()
		_contar_pocoes())
	cli.item_nao_moveu.connect(func():
		print("TESTE nao moveu")
		inv.nao_moveu()
		_msg("[color=#e8b04a]O servidor nao deixou mover esse item.[/color]"))
	cli.item_removido.connect(func(slot):
		print("TESTE removido %d" % slot)
		inv.removido(slot)
		_vestir_eu()
		_contar_pocoes())
	cli.durabilidade.connect(func(slot, v):
		print("TESTE durabilidade %d = %d" % [slot, v])
		inv.durabilidade(slot, v)
		_contar_pocoes())
	cli.largou.connect(func(ok, slot):
		print("TESTE largou %s %d" % [ok, slot])
		if ok:
			inv.removido(slot)
		inv.nao_moveu()
		_contar_pocoes())
	cli.nao_consumiu.connect(func(): _msg("[color=#e8b04a]Nao deu pra usar esse item agora.[/color]"))
	cli.skills.connect(func(l):
		minhas_skills.clear()
		for k in l:
			minhas_skills[k.indice] = k.numero
		print("TESTE skills %s" % [minhas_skills.values()])
		_atualizar_skills())
	cli.skill_nova.connect(func(i, n):
		minhas_skills[i] = n
		_msg("[color=#9fe0a0]Aprendeu %s.[/color]" % _info_skill(n)[0])
		_atualizar_skills())
	cli.skill_saiu.connect(func(i, _n):
		minhas_skills.erase(i)
		_atualizar_skills())
	cli.skill_animacao.connect(_skill_de_outro)
	cli.aparencia_mudou.connect(func(quem, slot, chave):
		var e: Entidade = entidades.get(quem)
		if quem == cli.meu_id or e == null or e.boneco == null:
			return
		var d: Dictionary = e.boneco.vestido()
		if chave == "":
			d.erase(slot)
		else:
			d[slot] = chave
		e.boneco.vestir(d))
	cli.area_animacao.connect(func(n, quem, x, y, _giro):
		if quem == cli.meu_id or not entidades.has(quem) or mundo == null:
			return
		var e: Entidade = entidades[quem]
		var p: Vector3 = mundo.no_tile(x, y)
		e.tocar_skill(_acao_skill(n), p)
		EfeitoSkill.criar(mundo, n, e.position, p, true))


# QWER: a pocao escolhida pra tecla, ou a maior da categoria; conta quantas tem
func _contar_pocoes() -> void:
	for i in 4:
		var opcoes: Array = POCOES[i].duplicate()
		if pocao_escolhida[i] != "":
			opcoes.push_front(pocao_escolhida[i])
		var achou := {}
		var total := 0
		for k in opcoes:
			for s in inv.itens:
				var it: Dictionary = inv.itens[s]
				if s >= Inventario.MOCHILA and ItensMU.chave(it) == k:
					if achou.is_empty():
						achou = it
					if ItensMU.chave(achou) == k:
						total += maxi(it.durabilidade, 1)
			if not achou.is_empty():
				break
		barra_mu.pocoes[i] = [achou, total]
	barra_mu.queue_redraw()


func _usar_pocao(i: int) -> void:
	var it: Dictionary = barra_mu.pocoes[i][0]
	if it.is_empty():
		_msg("[color=#9a9ab0]Sem pocao na tecla %s.[/color]" % "QWER"[i])
		return
	for s in inv.itens:
		if s >= Inventario.MOCHILA and ItensMU.chave(inv.itens[s]) == ItensMU.chave(it):
			print("TESTE usando %s do slot %d" % [ItensMU.nome(it), s])
			cli.usar_item(s)
			return


# teclas do jogo; devolve true se usou a tecla
func _teclas(ev: InputEventKey) -> bool:
	var k := ev.keycode
	if k in [KEY_I, KEY_V]:
		inv.alternar()
		return true
	if k == KEY_ESCAPE and inv.visible:
		inv.alternar()
		return true
	var q := [KEY_Q, KEY_W, KEY_E, KEY_R].find(k)
	if q >= 0:
		# mouse em cima de uma pocao no inventario: ela vai pra tecla
		var s := inv.slot_sob_mouse() if inv.visible else -1
		if s >= Inventario.MOCHILA and ItensMU.consome(inv.itens[s]):
			pocao_escolhida[q] = ItensMU.chave(inv.itens[s])
			_msg("%s na tecla %s." % [ItensMU.nome(inv.itens[s]), "QWER"[q]])
			_contar_pocoes()
		else:
			_usar_pocao(q)
		return true
	var n := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0].find(k)
	if n >= 0:
		var sob := barra_mu.skill_sob_mouse() if barra_mu.lista_aberta else -1
		if sob >= 0:
			var velho := barra_mu.atalhos.find(sob)
			if velho >= 0:
				barra_mu.atalhos[velho] = -1
			barra_mu.atalhos[n] = sob
			_salvar_atalhos()
			_msg("%s no %d." % [_info_skill(sob)[0], (n + 1) % 10])
			barra_mu.queue_redraw()
		elif barra_mu.atalhos[n] in barra_mu.skills:
			_escolher_skill(barra_mu.atalhos[n])
		return true
	return false


# --- skills ------------------------------------------------------------------------

# [nome, alcance, tipo, alvo, mana, ag, anda ate o alvo]
func _info_skill(n: int) -> Array:
	return barra_mu.info_skills.get(str(n), ["Skill %d" % n, 1, 0, 0, 0, 0, false])


func _atualizar_skills() -> void:
	var l := []
	var idx := minhas_skills.keys()
	idx.sort()
	for i in idx:
		var n: int = minhas_skills[i]
		if int(_info_skill(n)[2]) != 20 and n not in l:   # passiva nao vai na barra
			l.append(n)
	barra_mu.skills = l
	_carregar_atalhos()
	if barra_mu.skill_atual not in l:
		barra_mu.skill_atual = l[0] if not l.is_empty() else -1
	barra_mu.queue_redraw()


func _arquivo_atalhos() -> String:
	return "user://atalhos_%s.cfg" % meu_nome.validate_filename()


func _carregar_atalhos() -> void:
	var c := ConfigFile.new()
	var a: Array = []
	if c.load(_arquivo_atalhos()) == OK:
		a = c.get_value("skills", "atalhos", [])
		barra_mu.skill_atual = c.get_value("skills", "atual", -1)
		for i in 4:
			pocao_escolhida[i] = c.get_value("pocoes", "q%d" % i, "")
	a.resize(10)
	for i in 10:
		if a[i] == null:
			a[i] = -1
	# sem nada salvo: as primeiras skills vao no 1..5
	if a.count(-1) == 10:
		for i in mini(5, barra_mu.skills.size()):
			a[i] = barra_mu.skills[i]
	barra_mu.atalhos = a


func _salvar_atalhos() -> void:
	var c := ConfigFile.new()
	c.set_value("skills", "atalhos", barra_mu.atalhos)
	c.set_value("skills", "atual", barra_mu.skill_atual)
	for i in 4:
		c.set_value("pocoes", "q%d" % i, pocao_escolhida[i])
	c.save(_arquivo_atalhos())


func _escolher_skill(n: int) -> void:
	barra_mu.skill_atual = n
	barra_mu.queue_redraw()
	_salvar_atalhos()
	_msg("Skill: %s" % _info_skill(n)[0])


# acao do boneco pra cada skill (o cliente tem uma por skill; aqui as parecidas)
func _acao_skill(n: int) -> String:
	var a := {19: "espada_s1", 20: "espada_s2", 21: "espada_s3", 22: "espada_s4", 23: "espada_s5",
		41: "giro", 42: "furia", 43: "estocada", 232: "furia", 44: "estocada", 47: "estocada",
		14: "inferno", 10: "fogo_inferno", 12: "raio", 26: "cura", 27: "cura", 28: "cura", 48: "cura",
		24: "arco", 52: "arco", 46: "arco", 51: "arco", 235: "arco"}
	if a.has(n):
		return a[n]
	return "magia2" if n in [5, 9, 13, 38, 39] else "magia"


# botao direito: solta a skill atual no monstro do mouse (ou no chao, se for de area)
func _skill_no_mouse(tela: Vector2) -> void:
	var n: int = barra_mu.skill_atual
	if n < 0:
		_msg("[color=#9a9ab0]Esse personagem nao tem skill. Clique no quadro verde da barra pra ver a lista.[/color]")
		return
	var info := _info_skill(n)
	var tipo := int(info[2])
	var e := _entidade_na_tela(tela)
	skill_numero = n
	skill_alvo = -1
	skill_ponto = Vector2i(-1, -1)
	if tipo in [10, 11]:
		# buff e cura: no aliado do mouse, ou em mim
		skill_alvo = e.id if e and e.tipo == "jogador" else cli.meu_id
	elif tipo == 0:
		if e == null or e.tipo != "monstro":
			_msg("[color=#9a9ab0]%s precisa de um monstro: aponte nele e clique com o botao direito.[/color]" % info[0])
			skill_numero = -1
			return
		skill_alvo = e.id
	elif tipo in [3, 4, 5]:
		if e and e.tipo == "monstro":
			skill_alvo = e.id
		else:
			skill_ponto = mundo.tile_na_tela(tela)
			if skill_ponto.x < 0:
				skill_numero = -1
				return
	elif tipo == 20:
		_msg("%s e passiva: ja vale sozinha." % info[0])
		skill_numero = -1
		return
	else:
		_msg("[color=#9a9ab0]%s ainda nao foi feita neste cliente.[/color]" % info[0])
		skill_numero = -1
		return
	alvo_id = -1
	item_alvo = -1
	_repensar = 0.0


# segura o botao direito: repete a skill no mesmo alvo
func _skills(dt: float) -> void:
	_skill_recarga -= dt
	if skill_numero < 0 or eu.morto:
		return
	var n := skill_numero
	var info := _info_skill(n)
	var tipo := int(info[2])
	var alcance := maxi(int(info[1]), 1)
	var alvo: Entidade = entidades.get(skill_alvo)
	var ponto := skill_ponto
	if skill_alvo >= 0:
		if alvo == null or alvo.morto:
			skill_numero = -1
			return
		ponto = alvo.tile
	if _distancia(eu.tile, ponto) > alcance:
		if not eu.andando() or _repensar <= 0.0:
			_repensar = 0.6
			_ir_perto(ponto, alcance)
		return
	if eu.andando() or _skill_recarga > 0.0:
		return
	if tipo not in [10, 11] and mundo.zona_segura(eu.tile.x, eu.tile.y):
		_msg("[color=#e8b04a]Na zona segura nao da pra atacar.[/color]")
		skill_numero = -1
		return
	if barra_mu.mana < int(info[4]):
		_msg("[color=#e8b04a]Falta mana pra %s.[/color]" % info[0])
		skill_numero = -1
		return
	if barra_mu.ag < int(info[5]):
		_msg("[color=#e8b04a]Falta AG pra %s.[/color]" % info[0])
		skill_numero = -1
		return
	_skill_recarga = RECARGA_SKILL
	var p: Vector3 = alvo.position if alvo else mundo.no_tile(ponto.x, ponto.y)
	eu.tocar_skill(_acao_skill(n), p)
	if tipo in [0, 10, 11]:
		cli.skill_alvo(n, skill_alvo)
		print("TESTE skill %d no alvo %d" % [n, skill_alvo])
	else:
		var d := ponto - eu.tile
		var giro := 0
		if d != Vector2i.ZERO:
			var th := rad_to_deg(atan2(-d.x, d.y))
			giro = int(round(fposmod(th - 180.0, 360.0) * 256.0 / 360.0)) & 0xFF
		var meio := eu.tile if n in EM_VOLTA else ponto
		cli.skill_area(n, meio.x, meio.y, giro, skill_alvo if tipo == 5 and skill_alvo >= 0 else 0)
		print("TESTE skill %d em area (%d, %d) giro %d" % [n, meio.x, meio.y, giro])
	EfeitoSkill.criar(mundo, n, eu.position, eu.position if n in EM_VOLTA else p, tipo in [3, 4, 5])
	# skill que nao e em monstro (buff, area no chao) solta uma vez; no monstro segue com o botao apertado
	if not (skill_alvo >= 0 and tipo in [0, 3, 5] and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		if not _cacar_skill:
			skill_numero = -1


var _cacar_skill := false   # testes: --skill N usa a skill N no lugar do golpe comum


func _skill_de_outro(n: int, quem: int, alvo: int) -> void:
	if quem == cli.meu_id or mundo == null or not entidades.has(quem):
		return
	var e: Entidade = entidades[quem]
	var a: Entidade = entidades.get(alvo, e)
	e.tocar_skill(_acao_skill(n), a.position)
	EfeitoSkill.criar(mundo, n, e.position, a.position)


var _skill_teste := -1
var _costas_t := 0.0


# o que eu visto vem do inventario (slots 0 a 8)
func _vestir_eu() -> void:
	if eu == null or eu.boneco == null:
		return
	var d := {}
	for s in 9:
		if inv.itens.has(s) and s != inv.esperando:
			d[s] = ItensMU.chave(inv.itens[s])
	eu.boneco.vestir(d)
	print("TESTE vestido %s" % [d])


# testes: --inventario 1 move o primeiro item da mochila pra outra casa, usa a
# pocao do Q e tira e poe de volta a arma da mao
func _teste_inventario(_l: Dictionary) -> void:
	await get_tree().create_timer(2.0).timeout
	var s := -1
	for k in inv.itens:
		if k >= Inventario.MOCHILA and not ItensMU.consome(inv.itens[k]):
			s = k
			break
	if s >= 0:
		var para := inv.lugar_livre(inv.itens[s])
		print("TESTE movendo %s de %d pra %d" % [ItensMU.nome(inv.itens[s]), s, para])
		inv.esperando = s
		cli.mover_item(s, para, inv.itens[s].bytes)
		await get_tree().create_timer(1.5).timeout
	print("TESTE pocoes %s" % [barra_mu.pocoes.map(func(x): return [ItensMU.nome(x[0]) if not x[0].is_empty() else "-", x[1]])])
	_usar_pocao(0)
	await get_tree().create_timer(1.5).timeout
	# tira a arma da mao (se tiver) e poe de volta
	if inv.itens.has(0):
		var livre := inv.lugar_livre(inv.itens[0])
		print("TESTE tirando a arma pra %d" % livre)
		inv.usar_ou_equipar(0)
		await get_tree().create_timer(1.5).timeout
		if inv.itens.has(livre):
			print("TESTE pondo a arma de volta")
			inv.usar_ou_equipar(livre)
			await get_tree().create_timer(1.5).timeout
	print("TESTE equipado %s" % [inv.itens.keys().filter(func(k): return k < Inventario.MOCHILA)])
