extends Node
# Tela do cliente: entra no OpenMU (servidor, conta, personagem), monta o mapa
# e mostra quem esta em volta. Clique no chao pra andar, no monstro pra atacar
# (segue batendo ate ele morrer) e no item do chao pra pegar.

const ROXO := Color(0.55, 0.45, 0.95)

var cli: ClienteMU
var mundo: Node3D
var selecao: Selecao        # tela de escolha de personagem (mapa da cena, criar e apagar)
var mapa_atual := -1
var eu: Entidade
var meu_nome := ""
var minha_classe := 0
var _classe_de := {}
var entidades := {}
var _esperando_pacote := {}   # id -> objeto que espera o pacote dos monstros (PacoteMapa.MONSTROS)
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
var janela_personagem: JanelaPersonagem
var comandos: JanelaComandos
var seguindo := -1          # comando Seguir da janela D: id do jogador que eu sigo
var _seguir_t := 0.0
var meus_pontos := 0
var registro: RichTextLabel

# combate e itens
const ALCANCE := 1          # ataque sem skill: do lado do monstro
const RECARGA := 0.9        # segundos entre um golpe e outro
var alvo_id := -1           # monstro que estou atacando
var item_alvo := -1         # item do chao que vou pegar
var itens := {}             # id -> ItemChao
var sobre: Entidade         # debaixo do mouse
var textos: TextosMU
var item_sob: ItemChao      # item do chao debaixo do mouse (cursor de pegar)
var _marca: EfeitoMU        # marca do ultimo clique no chao
var _cursor_tipo := ""
var _cursor_lado := 0
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
# loja do NPC, amigos (F) e menu (U)
var loja: Loja
var minimapa: Minimapa     # Tab
var dialogo: DialogoNPC     # conversa do NPC (Elf Soldier): C3 F9 01
var guarda: Guarda          # bau e maquina do caos
var _janela_npc := 0        # tipo da janela que o servidor abriu (0 loja, 2 bau, 3 maquina do caos)
var amigos: Amigos
var troca: Troca            # troca com outro jogador (D > Troca)
var loja_pessoal: LojaPessoal   # a minha loja (S) e a de quem vende (clique no titulo)
var helper: MuHelper        # MU Helper (Z configura, Home liga)
var janela_helper: JanelaHelper
var botao_helper: TextureButton
var titulos_lojas := {}     # id -> titulo da loja aberta (em cima do nome)
var _preco_pendente := {}   # slot 204+ -> preco que mandei pro servidor
var _comprando := -1        # casa da loja do outro que pedi pra comprar
var menu: MenuSistema
var mover_janela: Movimento   # janela Move (M)
var _portal_pisado := -1      # portal em que ja pedi pra entrar (so pede de novo depois de sair dele)
var npc_alvo := -1          # NPC que cliquei: anda ate perto e fala
var npc_falando := -1       # NPC da janela aberta
var _zen_antes_venda := 0   # o zen novo chega (C3 22 FE) antes da resposta da venda
var minhas_skills := {}     # indice no servidor -> numero da skill
var _skill_recarga := 0.0
var skill_alvo := -1        # monstro (ou ponto) que a skill atual vai pegar quando chegar perto
var skill_ponto := Vector2i(-1, -1)
var skill_numero := -1
const RECARGA_SKILL := 0.8
const EM_VOLTA := [41, 42, 9, 14, 235, 76, 236, 237, 62]   # skills de area em volta de quem solta
# QWER: categorias de pocao do MU (vida, mana, SD, complexa); a maior primeiro
const POCOES := [["14,3", "14,2", "14,1", "14,0"], ["14,6", "14,5", "14,4"], ["14,37", "14,36", "14,35"], ["14,40", "14,39", "14,38"]]
var pocao_escolhida: Array = ["", "", "", ""]   # chave do item que a pessoa pos na tecla


func _ready() -> void:
	PacoteMapa.montar_pc()
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
	cli.ponto.connect(_ponto)
	cli.pedido_grupo.connect(func(id):
		var n: String = entidades[id].nome if entidades.has(id) else "Alguem"
		print("TESTE pedido de grupo de %s" % n)
		_perguntar("%s te chamou pro grupo." % n, func(ok): cli.responder_grupo(ok, id)))
	cli.grupo.connect(func(l):
		print("TESTE grupo %s" % [l])
		_msg("[color=#9ad0ff]Grupo: %s[/color]" % ", ".join(l.map(func(m): return m.nome))))
	cli.pedido_duelo.connect(func(id, n):
		print("TESTE pedido de duelo de %s" % n)
		_perguntar("%s te chamou pra um duelo." % n, func(ok): cli.responder_duelo(ok, id, n)))
	cli.duelo.connect(func(r, _id, n):
		print("TESTE duelo %d %s" % [r, n])
		_msg("[color=#9ad0ff]%s[/color]" % ("Duelo com %s comecou." % n if r == 0 else "O duelo nao comecou (%d)." % r)))
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
	_ligar_loja_e_amigos()
	cli.golpe.connect(func(id, dano, tipo, escudo):
		if entidades.has(id):
			entidades[id].mostrar_dano(dano, tipo, escudo))
	cli.ataque.connect(func(id, alvo):
		if alvo == cli.meu_id and helper:
			helper.me_atacou(id)
		if entidades.has(id) and entidades.has(alvo):
			entidades[id].olhar_para(entidades[alvo])
			EfeitoSkill.golpe_comum(mundo, entidades[id], entidades[alvo]))
	_montar_ui()
	_ligar_inventario_e_skills()
	_ligar_troca_loja_helper()
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
	if p.has("desmontar"):
		cli.inventario.connect(func(_l): _teste_desmontar(), CONNECT_ONE_SHOT)
	if p.has("loja"):
		cli.entrou.connect(func(_i): _teste_loja(p.loja), CONNECT_ONE_SHOT)
	if p.has("amigo"):
		cli.entrou.connect(func(_i): _teste_amigo(p.amigo), CONNECT_ONE_SHOT)
	if p.has("guarda"):
		cli.entrou.connect(func(_i): _teste_guarda(p.guarda), CONNECT_ONE_SHOT)
	if p.has("aceitar"):
		cli.pedido_amizade.connect(func(n):
			await get_tree().create_timer(1.0).timeout
			print("TESTE aceitando %s" % n)
			cli.responder_amizade(true, n))
	if p.has("apagar"):
		cli.amigos.connect(func(_l, _c):
			await get_tree().create_timer(2.0).timeout
			print("TESTE apagando %s" % p.apagar)
			cli.apagar_amigo(p.apagar), CONNECT_ONE_SHOT)
	if p.has("mover"):
		# testes: --mover 4 (Devias) ou --mover 4,3 (Devias e depois Noria), 4 s entre um e outro;
		# com --andar, anda depois de chegar no ultimo mapa
		var depois := _andar_depois
		_andar_depois = Vector2i(-1, -1)
		cli.entrou.connect(func(_i):
			for idx in str(p.mover).split(","):
				await get_tree().create_timer(4.0).timeout
				_mover_para(int(idx), "teste %s" % idx)
			if depois.x >= 0:
				await get_tree().create_timer(6.0).timeout
				if eu:
					andar_ate(depois)
					print("TESTE andando de %s ate %s (%d passos)" % [eu.tile, depois, eu.fila.size()]), CONNECT_ONE_SHOT)
	if p.has("trocar"):
		cli.entrou.connect(func(_i): _teste_trocar(), CONNECT_ONE_SHOT)
	if p.has("troca"):
		cli.entrou.connect(func(_i): _teste_troca(p.troca), CONNECT_ONE_SHOT)
	if p.has("aceitar"):
		# o outro lado da troca: aceita quando o outro aceitar
		cli.troca_botao_dele.connect(func(e):
			if e == 1 and not troca.eu_aceitei:
				await get_tree().create_timer(Troca.ESPERA + 0.5).timeout
				print("TESTE troca: aceitando tambem")
				troca.eu_aceitei = true
				cli.botao_troca(true))
	if p.has("minha_loja"):
		cli.entrou.connect(func(_i): _teste_minha_loja(int(p.minha_loja)), CONNECT_ONE_SHOT)
	if p.has("comprar_loja"):
		cli.entrou.connect(func(_i): _teste_comprar_loja(p.comprar_loja), CONNECT_ONE_SHOT)
	if p.has("helper"):
		cli.entrou.connect(func(_i): _teste_helper(float(p.helper)), CONNECT_ONE_SHOT)
	if p.has("fotos_janelas"):
		cli.entrou.connect(func(_i): _teste_fotos_janelas(), CONNECT_ONE_SHOT)
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
	# nomes, itens do chao e numeros do dano: por baixo das janelas
	var camada := CanvasLayer.new()
	add_child(camada)
	textos = TextosMU.new()
	textos.jogo = self
	camada.add_child(textos)
	ui = CanvasLayer.new()
	ui.layer = 2
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
	var linha_topo := HBoxContainer.new()
	linha_topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(linha_topo)
	linha_topo.add_child(hud_texto)
	# MU Helper: configurar (Z) e ligar ou desligar (Home), como no quadro da posicao do MuMain
	var bt_config := _botao_quadros("helper_config", "Configurar o MU Helper (Z)")
	bt_config.pressed.connect(func(): _alternar_janela_helper())
	linha_topo.add_child(bt_config)
	botao_helper = _botao_quadros("helper_play", "Ligar o MU Helper (Home)")
	botao_helper.pressed.connect(func(): helper.alternar())
	linha_topo.add_child(botao_helper)
	var ajuda := Label.new()
	ajuda.text = "Clique: anda, ataca, pega, fala com NPC · botao direito: skill · 1 a 5 troca a skill · Q W E R pocoes · I inventario · C personagem · F amigos · U menu · setas giram · roda aproxima · M mover de mapa · S loja pessoal · Z MU Helper (Home liga) · - = brilho"
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
	loja = Loja.new()
	loja.inv = inv
	loja.comprar.connect(func(slot): cli.comprar(slot))
	loja.vender.connect(func(slot):
		_zen_antes_venda = meu_zen
		cli.vender(slot))
	loja.fechar.connect(_fechar_loja)
	hud.add_child(loja)
	inv.loja_npc = loja
	dialogo = DialogoNPC.new()
	dialogo.resposta.connect(func(r):
		print("TESTE resposta %d no dialogo do npc %d" % [r, dialogo.npc])
		if r == 902:
			cli.buff_npc()
			_fechar_loja()
		else:
			_msg("[color=#9a9ab0]As quests desse NPC ainda nao foram feitas neste cliente.[/color]"))
	dialogo.fechar.connect(_fechar_loja)
	hud.add_child(dialogo)
	minimapa = Minimapa.new()
	minimapa.jogo = self
	minimapa.andar.connect(_andar_pelo_minimapa)
	hud.add_child(minimapa)   # por cima do chat e do texto do topo (o hud ainda ganha filhos depois)
	guarda = Guarda.new()
	guarda.inv = inv
	guarda.guardar.connect(func(de, para):
		if inv.itens.has(de):
			cli.mover_item(de, para, inv.itens[de].bytes, 0, 2 if guarda.modo == "bau" else 3))
	guarda.retirar.connect(func(s):
		var para := inv.lugar_livre(guarda.itens[s])
		if para < 0:
			guarda.esperando = -1
			_msg("[color=#e8b04a]Mochila cheia.[/color]")
			return
		cli.mover_item(s, para, guarda.itens[s].bytes, 2 if guarda.modo == "bau" else 3, 0))
	guarda.zen_guardar.connect(func(v):
		if v <= 0 or v > meu_zen:
			_msg("[color=#e8b04a]Escreva quanto zen guardar (voce tem %s).[/color]" % ItemChao._milhar(meu_zen))
		else:
			cli.zen_bau(0, v))
	guarda.zen_tirar.connect(func(v):
		if v <= 0 or v > guarda.zen_bau:
			_msg("[color=#e8b04a]Escreva quanto zen tirar (o bau tem %s).[/color]" % ItemChao._milhar(guarda.zen_bau))
		else:
			cli.zen_bau(1, v))
	guarda.combinar.connect(func(): cli.misturar())
	guarda.fechar.connect(_fechar_loja)
	hud.add_child(guarda)
	troca = Troca.new()
	troca.inv = inv
	hud.add_child(troca)
	loja_pessoal = LojaPessoal.new()
	loja_pessoal.inv = inv
	hud.add_child(loja_pessoal)
	helper = MuHelper.new()
	helper.jogo = self
	add_child(helper)
	janela_helper = JanelaHelper.new()
	janela_helper.helper = helper
	janela_helper.skills_de = func(): return minhas_skills.values()
	janela_helper.info_de = _info_skill
	janela_helper.fechar.connect(func(): janela_helper.visible = false)
	janela_helper.salvar.connect(func(d):
		cli.salvar_helper(d)
		print("TESTE helper salvo")
		_msg("[color=#9fe0a0]Configuracao do MU Helper salva.[/color]"))
	hud.add_child(janela_helper)
	amigos = Amigos.new()
	amigos.adicionar.connect(func(n): cli.adicionar_amigo(n))
	amigos.apagar.connect(func(n): cli.apagar_amigo(n))
	amigos.responder.connect(func(a, n): cli.responder_amizade(a, n))
	hud.add_child(amigos)
	menu = MenuSistema.new()
	menu.musica.connect(func(_v): _volumes())
	menu.efeitos.connect(func(_v): _volumes())
	menu.brilho.connect(func(v):
		if mundo:
			mundo.definir_brilho(v)
			brilho = mundo.brilho)
	menu.trocar_personagem.connect(func(): cli.sair_para(1))
	menu.sair_jogo.connect(func(): cli.sair_para(0))
	menu.mover.connect(func(): mover_janela.abrir(meu_nivel, meu_zen, minha_classe))
	hud.add_child(menu)
	mover_janela = Movimento.new()
	mover_janela.mapas = mapas
	mover_janela.ir.connect(_mover_para)
	hud.add_child(mover_janela)
	# janela do personagem (C)
	janela_personagem = JanelaPersonagem.new()
	janela_personagem.inventario = inv
	janela_personagem.adicionar.connect(func(a): cli.adicionar_ponto(a))
	hud.add_child(janela_personagem)
	inv.visibility_changed.connect(janela_personagem._ajustar)
	comandos = JanelaComandos.new()
	comandos.executar.connect(_comando)
	hud.add_child(comandos)
	var sair := Button.new()
	sair.text = "Sair"
	sair.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sair.position = Vector2(-90, 12)
	sair.pressed.connect(_sair)
	hud.add_child(sair)
	# o Sair sai da frente das janelas coladas na direita (inventario, loja, bau, C e D)
	var direita: Array[Control] = [inv, loja, dialogo, guarda, janela_personagem, comandos, troca, loja_pessoal, janela_helper]
	var mover_sair := func():
		var x := hud.size.x
		for j in direita:
			if j.visible:
				x = minf(x, j.position.x)
		sair.position.x = x - 90
	for j in direita:
		j.visibility_changed.connect(mover_sair, CONNECT_DEFERRED)
	registro = RichTextLabel.new()
	registro.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	registro.position = Vector2(12, -250)
	registro.size = Vector2(560, 158)
	registro.scroll_following = true
	registro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	registro.add_theme_stylebox_override("normal", _estilo(Color(0, 0, 0, 0.45)))
	registro.add_theme_font_size_override("normal_font_size", 15)
	hud.add_child(registro)


# botao de 18 x 13 com 3 quadros empilhados (normal, mouse em cima, apagado)
func _botao_quadros(nome: String, dica: String) -> TextureButton:
	var b := TextureButton.new()
	var tex: Texture2D = load("res://dados/hud/%s.png" % nome)
	for i in 3:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(0, 13 * i, 18, 13)
		b.set(["texture_normal", "texture_hover", "texture_disabled"][i], a)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.custom_minimum_size = Vector2(27, 20)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = dica
	return b


func _trocar_icone_helper(ligado: bool) -> void:
	var tex: Texture2D = load("res://dados/hud/%s.png" % ("helper_pause" if ligado else "helper_play"))
	for k in ["texture_normal", "texture_hover", "texture_disabled"]:
		var a: AtlasTexture = botao_helper.get(k)
		a.atlas = tex
	botao_helper.tooltip_text = "Desligar o MU Helper (Home)" if ligado else "Ligar o MU Helper (Home)"


func _alternar_janela_helper() -> void:
	if not janela_helper.visible:
		inv.visible = false
		janela_personagem.visible = false
		comandos.visible = false
		if janela_helper.helper.c.skills[0] == 0:
			janela_helper._padrao_skills()
	janela_helper.alternar()


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
	_fechar_selecao()
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
	for p in l:
		_classe_de[p.nome] = [p.classe, p.nivel]
	for p in l:
		if meu_nome != "" and p.nome == meu_nome:
			_escolher(p.nome)
			return
	# testes: --auto conta,senha,Novo --criar 0 (0 DW, 4 DK, 8 Elf, 12 MG, 16 DL, 20 Sum, 24 RF) cria e entra
	if _auto and _parametros().has("criar") and meu_nome != "":
		cli.criar_personagem(meu_nome, int(_parametros().criar))
		var r: Array = await cli.criou
		print("TESTE criou %s %s" % [meu_nome, r])
		cli.pedir_personagens()
		return
	_abrir_selecao(l)


func _abrir_selecao(l: Array) -> void:
	painel.visible = false
	hud.visible = false
	if selecao == null:
		selecao = Selecao.new()
		selecao.cli = cli
		selecao.palco = self
		selecao.nomes_classe = classes
		selecao.volume = menu.vol_musica
		ui.add_child(selecao)
		ui.move_child(selecao, 0)
		selecao.entrar.connect(_escolher)
		selecao.voltar.connect(func() -> void:
			_fechar_selecao()
			_sair())
		selecao.grab_focus()
		await selecao.mostrar(l)
		if _parametros().has("selecao"):
			selecao.teste(str(_parametros().selecao).split(",", false))
		return
	selecao.mostrar(l)


func _fechar_selecao() -> void:
	if selecao:
		selecao.fechar()
		selecao = null


func _escolher(nome: String) -> void:
	_fechar_selecao()
	meu_nome = nome
	# o helper e a janela C sao de cada personagem: o servidor so manda a config (C2 AE) de quem ja salvou
	if helper:
		helper.parar("")
		helper.c = MuHelper.padrao()
		janela_helper.visible = false
		janela_personagem.esperando = false
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
	DicaItem.eu = {"nivel": meu_nivel, "classe": minha_classe, "forca": info.forca, "agilidade": info.agilidade,
		"vitalidade": info.vitalidade, "energia": info.energia, "comando": info.comando,
		"vida_max": info.vida_max, "mana_max": info.mana_max}
	exp_prox = info.exp_prox
	meu_zen = info.zen
	inv.zen = info.zen
	_hud_nivel()
	await _abrir_mapa(info.mapa, info.x, info.y)
	_msg("Entrou em %s (%d, %d)." % [mapas.get(str(info.mapa), "mapa %d" % info.mapa), info.x, info.y])
	print("TESTE entrou %s" % info)
	if _parametros().has("chao_teste"):
		_chao_teste(info.x, info.y)
	if _parametros().has("uma_skill"):
		_teste_uma_skill(int(_parametros().uma_skill))
	if _parametros().has("segurar"):
		_teste_segurar(int(_parametros().segurar))
	if _parametros().has("comando"):
		_teste_comando(str(_parametros().comando).split(","))
	if _parametros().has("ponto"):
		_teste_ponto(int(_parametros().ponto))
	if _parametros().has("falar"):
		_teste_falar(str(_parametros().falar))
	if _parametros().has("minimapa"):
		_teste_minimapa(str(_parametros().minimapa))
	if _parametros().has("dialogo_teste"):
		dialogo.abrir(int(_parametros().dialogo_teste), "Elf Soldier")
	if _parametros().has("efeito_teste"):
		_efeito_teste(str(_parametros().efeito_teste).split(",", false))
	if _andar_depois.x >= 0:
		await get_tree().create_timer(2.0).timeout
		if eu:
			andar_ate(_andar_depois)
			print("TESTE andando de %s ate %s (%d passos)" % [eu.tile, _andar_depois, eu.fila.size()])


func _limpar_mundo() -> void:
	if loja:
		loja.visible = false
		guarda.visible = false
		troca.visible = false
		loja_pessoal.visible = false
		loja_pessoal.aberta = false
		helper.parar("")
	titulos_lojas.clear()
	npc_falando = -1
	npc_alvo = -1
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
	EfeitoMontaria.mapa = mapa
	# navegador: Lost Tower e Atlans vem num pacote a parte; a rede espera ele baixar
	if PacoteMapa.precisa(mapa + 1):
		_msg("Carregando %s..." % mapas.get(str(mapa), "o mapa"))
		cli.segurar = true
		await PacoteMapa.carregar(self, mapa + 1)
		cli.segurar = false
		if mapa_atual != mapa:
			return
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
	# chegou em cima de um portal (saida de outro): so conta depois de sair dele
	var g := mover_janela.portal_em(mapa, x, y)
	_portal_pisado = int(g[0]) if not g.is_empty() else -1


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
		if str(o.get("dono", "")) != "":
			tipo = "invocado"   # bicho de alguem (elfa, Dark Lord): nao e alvo
	# monstro de evento no navegador: entra de boneco provisorio e e refeito quando o pacote chega
	if o.tipo == "npc" and PacoteMapa.falta_monstro(o.numero):
		_esperando_pacote[o.id] = o
		if _esperando_pacote.size() == 1:
			_baixar_monstros()
	var e := Entidade.new()
	mundo.add_child(e)
	e.montar(mundo, o.id, tipo, nome, o.x, o.y,
		Boneco.do_npc(o.numero) if o.tipo == "npc" else Boneco.da_classe(o.get("classe", 0)))
	entidades[o.id] = e
	# armadilha (Meteorite Trap da Lost Tower, as da Dungeon): o cliente nao desenha
	if tipo == "outro":
		e.visible = false
	if e.boneco and o.has("equip"):
		e.boneco.vestir(o.equip)
	if Vector2i(o.ax, o.ay) != Vector2i(o.x, o.y):
		_objeto_andou(o.id, o.ax, o.ay, [])


func _baixar_monstros() -> void:
	await PacoteMapa.carregar(self, PacoteMapa.MONSTROS)
	var lista := _esperando_pacote.values()
	_esperando_pacote.clear()
	for o: Dictionary in lista:
		if entidades.has(o.id):
			var t: Vector2i = entidades[o.id].tile
			o.x = t.x
			o.y = t.y
			o.ax = t.x
			o.ay = t.y
			if entidades[o.id] == sobre:
				sobre = null
			_objeto_entrou(o)


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
	helper.morreu(id)
	if id == alvo_id:
		alvo_id = -1
	if id == cli.meu_id:
		alvo_id = -1
		item_alvo = -1
		_msg("[color=#e05050]Voce morreu.[/color]")


func _mapa_mudou(mapa: int, x: int, y: int) -> void:
	print("TESTE mapa mudou %d (%d, %d)" % [mapa, x, y])
	if mapa != mapa_atual:
		await _abrir_mapa(mapa, x, y)
		_msg("Foi pra %s (%d, %d)." % [mapas.get(str(mapa), "mapa %d" % mapa), x, y])
		# gravacao com --andar (a gravacao do --mover): anda de novo no mapa novo, como no teste
		var p := _parametros()
		if p.has("gravacao") and p.has("andar"):
			var xy: PackedStringArray = str(p.andar).split(",")
			await get_tree().create_timer(6.0).timeout
			if eu:
				andar_ate(Vector2i(int(xy[0]), int(xy[1])))
				print("TESTE andando de %s ate %s (%d passos)" % [eu.tile, p.andar, eu.fila.size()])
	elif eu:
		var longe := _distancia(eu.tile, Vector2i(x, y)) > 1
		eu.teleportar(x, y)
		_restante.clear()
		if longe:
			EfeitoSkill.teleporte(EfeitoMU.criar(mundo), eu, false)


# --- mover de mapa ----------------------------------------------------------------

# janela Move: o servidor confere nivel e zen; se der, chega o MapChanged (_mapa_mudou)
func _mover_para(indice: int, nome: String) -> void:
	if eu == null or eu.morto:
		return
	_restante.clear()
	alvo_id = -1
	item_alvo = -1
	print("TESTE mover %d %s" % [indice, nome])
	_msg("Indo pra %s..." % nome)
	cli.mover_para(indice)


# portal do mapa (EnterGate): pisou no retangulo, pede pra entrar, uma vez por pisada
func _conferir_portal() -> void:
	if eu == null or eu.morto:
		return
	var g := mover_janela.portal_em(mapa_atual, eu.tile.x, eu.tile.y)
	if g.is_empty():
		_portal_pisado = -1
		return
	if int(g[0]) == _portal_pisado:
		return
	_portal_pisado = int(g[0])
	var precisa := mover_janela.nivel_pedido(int(g[5]), minha_classe)
	var destino: String = mapas.get(str(int(g[6])), "mapa %d" % g[6])
	if meu_nivel < precisa:
		print("TESTE portal %d sem nivel (%d < %d)" % [g[0], meu_nivel, precisa])
		_msg("[color=#e8b04a]Precisa do nivel %d pra entrar em %s.[/color]" % [precisa, destino])
		return
	print("TESTE portal %d pra %s, pisado em %s" % [g[0], destino, eu.tile])
	_restante.clear()
	_msg("Entrando em %s..." % destino)
	cli.entrar_portal(int(g[0]))


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
		item_sob = _item_perto(mundo.tile_na_tela(ev.position))
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
		seguindo = -1
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
		if comandos.selecionado >= 0:
			_comando_no_mouse(ev.position)
			return
		_segura_direito = true
		_skill_no_mouse(ev.position)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_C:
		_botao_barra("personagem")
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var e := _entidade_na_tela(ev.position)
		if e and e.tipo == "monstro":
			mirar(e.id)
			return
		if e and e.tipo == "npc":
			falar_com(e.id)
			return
		if e and e.tipo == "jogador" and titulos_lojas.has(e.id):
			cli.ver_loja(e.id, e.nome)
			return
		var t: Vector2i = mundo.tile_na_tela(ev.position)
		if loja_pessoal.aberta:
			_msg("[color=#e8b04a]Com a loja aberta nao da pra andar. Feche a loja (S) pra sair daqui.[/color]")
			return
		var it := _item_perto(t)
		if it:
			pegar_item(it.id)
			return
		if t.x < 0:
			return
		alvo_id = -1
		item_alvo = -1
		npc_alvo = -1
		andar_ate(t)
		if eu.andando():
			_marcar_clique(t)


# cursor do cliente (RenderCursor do ZzzInterface): 24 de 640 de largura, ponta em (2, 2);
# mao no item, balao no NPC, espada no monstro fora da cidade, empurrando com o botao apertado
func _cursor_mu() -> void:
	var tipo := "cursor"
	if get_viewport().gui_get_hovered_control() == null:
		if is_instance_valid(item_sob):
			tipo = "cursor_pegar"
		elif is_instance_valid(sobre) and sobre.tipo == "npc":
			tipo = "cursor_falar"
		elif is_instance_valid(sobre) and sobre.tipo == "monstro" and not mundo.zona_segura(eu.tile.x, eu.tile.y):
			tipo = "cursor_ataque"
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			tipo = "cursor_push"
	var lado := mini(int(24.0 * DisplayServer.window_get_size().x / 640.0), 128)
	if lado < 8 or tipo == _cursor_tipo and lado == _cursor_lado:
		return
	_cursor_tipo = tipo
	_cursor_lado = lado
	var img: Image = (load("res://dados/hud/%s.png" % tipo) as Texture2D).get_image()
	if tipo == "cursor_falar":
		img = img.get_region(Rect2i(0, 0, 32, 32))   # 4 quadros em 2 x 2: o primeiro
	img.resize(lado, lado, Image.INTERPOLATE_BILINEAR)
	Input.set_custom_mouse_cursor(img, Input.CURSOR_ARROW, Vector2.ONE * 2.0 * lado / 24.0)


# marca do clique no chao (MODEL_MOVE_TARGETPOSITION_EFFECT): o pino girando em laranja por
# 30 quadros, faiscas na ponta e um anel no chao a cada 15 quadros que encolhe de 0,9 a 0,2 tile
func _marcar_clique(t: Vector2i) -> void:
	if is_instance_valid(_marca):
		_marca.queue_free()
	var p: Vector3 = mundo.no_tile(t.x, t.y)
	var cor := Color(1.0, 0.7, 0.3)
	var q := 1.0 / 25.0   # o cliente anda a 25 quadros por segundo
	var e := EfeitoMU.criar(mundo)
	_marca = e
	e.modelo("movetargetposeffect", p, 0.6, cor, 30 * q, {some = 10.0 / 30.0, ritmo = 0.3})
	e.tarefa(15 * q, 16 * q, func(ef: EfeitoMU, _i: int):
		ef.chao("cursorpin01", p + Vector3.UP * 0.02, 0.9, cor, 17.5 * q, {tam1 = 0.2, some = 0.3}))
	e.tarefa(q, 30 * q, func(ef: EfeitoMU, _i: int):
		var v := Vector3(randi_range(-1, 1), randi_range(-1, 1), randi_range(-1, 1)) * 2.0 * 25.0 / 100.0
		ef.sprite("spark03", p + Vector3.UP * 1.1, randf_range(0.4, 0.8) * 0.5, cor, 16 * q,
			{vel = v, tam1 = 0.1, some = 10.0 / 16.0,
			anda = func(pc: Dictionary, k: float):
				if k > 6.0 / 16.0 and not pc.has("volta"):
					pc.volta = true
					pc.vel = -pc.vel}))


func andar_ate(t: Vector2i) -> void:
	if loja_pessoal.aberta:
		return
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


# botao direito no minimapa: anda ate o tile (ou o livre mais perto dele)
func _andar_pelo_minimapa(t: Vector2i) -> void:
	var alvo := Vector2i(-1, -1)
	for r in 16:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p := t + Vector2i(dx, dy)
				if alvo.x < 0 and maxi(absi(dx), absi(dy)) == r and mundo.anda(p.x, p.y):
					alvo = p
	var c: Array[Vector2i] = []
	if alvo.x >= 0:
		c = mundo.caminho(eu.tile, alvo)
	print("TESTE minimapa: andar ate %s (livre %s, %d passos)" % [t, alvo, c.size()])
	if c.is_empty():
		_msg("[color=#e8b04a]Nao da pra chegar ate ai andando.[/color]")
		return
	alvo_id = -1
	npc_alvo = -1
	item_alvo = -1
	minimapa._destino = alvo
	andar_ate(alvo)


# manda ate 7 passos por pacote; o resto vai quando chegar no fim do trecho.
# Fora da zona segura o OpenMU (SpeedHackDetectPlugIn) da no maximo 2 s de "credito"
# e cobra ~250 ms por tile andado desde o pacote anterior: com 15 passos ele acha que e
# speedhack, corta o caminho e, no 3o aviso, derruba a conexao. Com 7 cabe sempre.
const PASSOS_POR_PACOTE := 7


func _mandar_trecho() -> void:
	if _restante.is_empty():
		return
	var de: Vector2i = eu.tile
	var dirs := []
	var ant: Vector2i = de
	while not _restante.is_empty() and dirs.size() < PASSOS_POR_PACOTE:
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
	_seguir(dt)
	_skills(dt)
	_cursor_mu()
	if not _restante.is_empty() and eu.tile == _fim_enviado:
		_mandar_trecho()
	_costas_t -= dt
	if _costas_t <= 0.0:
		# na zona segura a arma vai pras costas (como no cliente)
		_costas_t = 0.3
		for e: Entidade in entidades.values():
			if is_instance_valid(e) and e.boneco and e.tipo in ["eu", "jogador"]:
				# teste com &monta: montaria a mostra mesmo na cidade
				var segura: bool = mundo.zona_segura(e.tile.x, e.tile.y) and not _teste_monta
				e.boneco.arma_nas_costas(segura)
				e.boneco.nadando(mapa_atual == 7 and not segura)
	var seg: bool = mundo.zona_segura(eu.tile.x, eu.tile.y)
	if som == null:
		som = Som.new()
		add_child(som)
		_volumes()
	# a loja fecha se eu andar pra longe do NPC (o servidor tambem esquece)
	if npc_falando >= 0 and (not entidades.has(npc_falando) or _distancia(eu.tile, entidades[npc_falando].tile) > 5):
		_fechar_loja()
	som.atualizar(mapa_atual, seg, mundo.camada1(eu.tile.x, eu.tile.y), eu.tile.x, eu.tile.y)
	_conferir_portal()
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
			if int(_info_skill(_skill_teste)[2]) == 30 or _skill_teste == 63:
				skill_alvo = cli.meu_id
			elif _skill_teste == 6:
				skill_alvo = -1
				skill_ponto = _livre_perto(melhor.tile)
		else:
			mirar(melhor.id)


func _combate(dt: float) -> void:
	if _cacar > 0:
		_cacador(dt)
	_recarga -= dt
	_repensar -= dt
	if eu.morto:
		return
	if npc_alvo >= 0:
		_ir_ao_npc()
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
	EfeitoSkill.golpe_comum(mundo, eu, a)
	cli.atacar(a.id, 38, dir)


func _experiencia(_morto: int, ganho: int) -> void:
	exp_atual += ganho
	_mortos += 1
	print("TESTE experiencia +%d (total %d de %d)" % [ganho, exp_atual, exp_prox])
	_msg("[color=#f0d070]+%d de experiencia[/color]" % ganho)
	_hud_nivel()


func _nivel(info: Dictionary) -> void:
	meu_nivel = info.nivel
	DicaItem.eu.nivel = meu_nivel
	print("TESTE nivel %s" % info)
	barra_mu.vida_max = maxi(info.vida_max, 1)
	barra_mu.vida = info.vida_max
	barra_mu.mana_max = maxi(info.mana_max, 1)
	barra_mu.mana = info.mana_max
	meus_pontos = info.pontos
	exp_prox = exp_do_nivel(meu_nivel)
	_msg("[color=#ffd84a]Subiu pro nivel %d! (%d pontos pra distribuir)[/color]" % [meu_nivel, info.pontos])
	_hud_nivel()
	if _parametros().has("ponto_subir"):
		_teste_ponto(int(_parametros().ponto_subir))


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
	if janela_personagem == null:
		return
	var j := janela_personagem
	j.eu.merge(DicaItem.eu, true)
	j.eu.merge({"nome": meu_nome, "classe": minha_classe, "nivel": meu_nivel, "pontos": meus_pontos,
		"exp": exp_atual, "exp_prox": exp_prox, "vida": barra_mu.vida, "vida_max": barra_mu.vida_max,
		"mana": barra_mu.mana, "mana_max": barra_mu.mana_max}, true)
	j.queue_redraw()


# --- janela D (comandos) ---------------------------------------------------------

func _comando_no_mouse(tela: Vector2) -> void:
	var e := _entidade_na_tela(tela)
	if e == null or e.tipo != "jogador":
		_msg("[color=#9a9ab0]Clique com o botao direito num jogador pra usar \"%s\".[/color]" % comandos.nome(comandos.selecionado))
		return
	if _distancia(eu.tile, e.tile) > JanelaComandos.DISTANCIA:
		_msg("[color=#e8b04a]%s esta longe. Chegue mais perto.[/color]" % e.nome)
		return
	comandos.usar_em(e.id)


func _comando(c: int, alvo: int) -> void:
	var n: String = entidades[alvo].nome if entidades.has(alvo) else ""
	print("TESTE comando %d em %s" % [c, n])
	match c:
		JanelaComandos.TROCA:
			if troca.visible or loja_pessoal.aberta:
				_msg("[color=#e8b04a]Feche a troca ou a loja antes.[/color]")
			else:
				cli.pedir_troca(alvo)
				_msg("[color=#9ad0ff]Pedido de troca mandado pra %s.[/color]" % n)
		JanelaComandos.COMPRAR:
			if titulos_lojas.has(alvo):
				cli.ver_loja(alvo, n)
			else:
				_msg("[color=#e8b04a]%s nao esta com a loja aberta.[/color]" % n)
		JanelaComandos.GRUPO:
			cli.chamar_grupo(alvo)
			_msg("[color=#9ad0ff]Convite de grupo mandado pra %s.[/color]" % n)
		JanelaComandos.AMIGO:
			cli.adicionar_amigo(n)
			_msg("[color=#9ad0ff]Pedido de amizade mandado pra %s.[/color]" % n)
		JanelaComandos.SEGUIR:
			seguindo = alvo
			_msg("[color=#9ad0ff]Seguindo %s. Clique no chao pra parar.[/color]" % n)
		JanelaComandos.DUELO:
			if meu_nivel < 30:
				_msg("[color=#e8b04a]Duelo so a partir do nivel 30.[/color]")
			else:
				cli.chamar_duelo(alvo, n)
				_msg("[color=#9ad0ff]Desafio de duelo mandado pra %s.[/color]" % n)
		_:
			_msg("[color=#9a9ab0]%s ainda nao existe neste cliente.[/color]" % comandos.nome(c))


func _seguir(dt: float) -> void:
	if seguindo < 0 or eu == null:
		return
	if not entidades.has(seguindo) or entidades[seguindo].morto:
		seguindo = -1
		return
	_seguir_t -= dt
	var alvo: Entidade = entidades[seguindo]
	if _seguir_t <= 0.0 and _distancia(eu.tile, alvo.tile) > 2:
		_seguir_t = 0.5
		andar_ate(alvo.tile)


# caixa de sim ou nao no meio da tela (convite de grupo, duelo)
func _perguntar(texto: String, resposta: Callable) -> void:
	var caixa := PanelContainer.new()
	caixa.add_theme_stylebox_override("panel", _estilo(Color(0.05, 0.04, 0.03, 0.92), Color(0.6, 0.5, 0.3)))
	caixa.set_anchors_preset(Control.PRESET_CENTER)
	var v := VBoxContainer.new()
	caixa.add_child(v)
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	for ok in [true, false]:
		var b := Button.new()
		b.text = "Aceitar" if ok else "Recusar"
		b.pressed.connect(func():
			resposta.call(ok)
			caixa.queue_free())
		h.add_child(b)
	hud.add_child(caixa)
	caixa.position = (get_viewport().get_visible_rect().size - caixa.get_combined_minimum_size()) / 2.0
	if _parametros().has("aceitar"):
		resposta.call(true)
		caixa.queue_free()


# resposta do ponto distribuido (F3 06): o servidor manda o maximo novo que dependia dele
func _ponto(ok: bool, atributo: int, maximo_dep: int, sd_max: int, ag_max: int) -> void:
	print("TESTE ponto %s atributo %d maximo %d sd %d ag %d" % [ok, atributo, maximo_dep, sd_max, ag_max])
	if not ok:
		janela_personagem.resposta(false, atributo)
		_msg("[color=#e8b04a]O servidor nao aceitou o ponto.[/color]")
		return
	var k: String = ["forca", "agilidade", "vitalidade", "energia", "comando"][clampi(atributo, 0, 4)]
	DicaItem.eu[k] = int(DicaItem.eu.get(k, 0)) + 1
	meus_pontos = maxi(meus_pontos - 1, 0)
	if atributo == 2 and maximo_dep > 0:
		barra_mu.vida_max = maximo_dep
	elif atributo == 3 and maximo_dep > 0:
		barra_mu.mana_max = maximo_dep
	if sd_max > 0:
		barra_mu.sd_max = sd_max
	if ag_max > 0:
		barra_mu.ag_max = ag_max
	janela_personagem.esperando = false
	_hud_nivel()


func _botao_barra(qual: String) -> void:
	if qual == "personagem":
		janela_personagem.alternar()
		_hud_nivel()
	elif qual == "comandos":
		comandos.alternar()
		if comandos.visible:
			if inv.visible:
				inv.alternar()
			if janela_personagem.visible:
				janela_personagem.alternar()
	elif qual == "inventario":
		inv.alternar()
	elif qual == "amigos":
		amigos.alternar()
	elif qual == "menu":
		menu.alternar(brilho)
	else:
		_msg("[color=#9a9ab0]A loja de cash (X) nao existe no OpenMU. Pra comprar, clique num NPC vendedor (Hanzo, Pasi, Lumen, Amy...).[/color]")


# --- loja do NPC, amigos e menu ---------------------------------------------------

func falar_com(id: int) -> void:
	npc_alvo = id
	alvo_id = -1
	item_alvo = -1
	_repensar = 0.0


# anda ate 2 tiles do NPC e fala (C3 30); o servidor responde com a janela (C3 30)
func _ir_ao_npc() -> void:
	var n: Entidade = entidades.get(npc_alvo)
	if n == null:
		npc_alvo = -1
		return
	if _distancia(eu.tile, n.tile) <= 2:
		if eu.andando():
			return
		eu.olhar_para(n)
		if npc_falando >= 0:
			_fechar_loja()
		print("TESTE falando com %s (%d)" % [n.nome, n.id])
		cli.falar_npc(n.id)
		npc_falando = n.id
		npc_alvo = -1
	elif not eu.andando() or _repensar <= 0.0:
		_repensar = 0.8
		_ir_perto(n.tile, 2)


func _fechar_loja() -> void:
	if npc_falando >= 0 and cli:
		# o bau e a maquina do caos tem o fechar proprio (C1 82 e C1 87)
		if _janela_npc == 2:
			cli.fechar_bau()
		elif _janela_npc == 3:
			cli.fechar_mistura()
		else:
			cli.fechar_npc()
	npc_falando = -1
	_janela_npc = 0
	loja.visible = false
	guarda.visible = false
	dialogo.visible = false
	inv.soltar()


func _volumes() -> void:
	if som and menu:
		som.volumes(menu.vol_musica, menu.vol_efeitos)


func _ligar_loja_e_amigos() -> void:
	cli.dialogo_npc.connect(func(numero):
		var n: Entidade = entidades.get(npc_falando)
		print("TESTE dialogo do npc %d (%s)" % [numero, n.nome if n else "?"])
		if dialogo.tem(numero):
			dialogo.abrir(numero, n.nome if n else "")
			if _parametros().has("resposta"):
				dialogo.escolher(int(_parametros().resposta) - 1)
		else:
			_msg("[color=#9a9ab0]A conversa desse NPC ainda nao foi feita neste cliente.[/color]")
			_fechar_loja())
	cli.janela_npc.connect(func(tipo):
		print("TESTE janela do npc %d" % tipo)
		_janela_npc = tipo
		if tipo == 3:
			# a maquina vazia nao vem com lista: abre ja (a lista, se vier, preenche)
			var gob: Entidade = entidades.get(npc_falando)
			guarda.abrir_guarda("caos", gob.nome if gob else "", {})
			if not inv.visible:
				inv.alternar()
		if tipo > 3:
			var nomes := {6: "o guarda da Arena", 0x0C: "o mercador de cash"}
			_msg("[color=#9a9ab0]A janela de %s ainda nao foi feita neste cliente.[/color]" % nomes.get(tipo, "esse NPC (tipo %d)" % tipo))
			_fechar_loja())
	cli.loja.connect(func(l, tipo):
		print("TESTE loja %d itens (tipo %d, janela %d)" % [l.size(), tipo, _janela_npc])
		var n: Entidade = entidades.get(npc_falando)
		if _janela_npc in [2, 3] or tipo == 3:
			if guarda.visible and guarda.modo == "caos":
				guarda.itens = l   # o que esta na maquina (ao abrir e depois de combinar)
				guarda.esperando = -1
				guarda.queue_redraw()
			else:
				guarda.abrir_guarda("bau" if _janela_npc == 2 else "caos", n.nome if n else "", l)
		else:
			loja.abrir(n.nome if n else "", l)
		if not inv.visible:
			inv.alternar())
	cli.bau_zen.connect(func(no_bau, mochila):
		print("TESTE zen do bau %d mochila %d" % [no_bau, mochila])
		guarda.zen_bau = no_bau
		guarda.queue_redraw()
		inv.zen = mochila
		inv.queue_redraw()
		meu_zen = mochila
		_hud_nivel())
	cli.mistura.connect(func(r, it):
		var textos := {0: "Nao deu certo: os itens se perderam.", 1: "Deu certo!", 2: "Falta zen pra combinar.",
			3: "Itens demais na maquina.", 4: "Nivel baixo pra essa receita.", 6: "Falta item na receita.",
			7: "Esses itens nao formam receita.", 8: "O nivel do item nao serve pra essa receita."}
		print("TESTE mistura %d %s" % [r, ItensMU.nome(it) if not it.is_empty() else ""])
		guarda.aviso = textos.get(r, "Nao deu (codigo %d)." % r)
		if r == 1 and not it.is_empty():
			guarda.aviso = "Deu certo: %s" % ItensMU.nome(it)
		_msg(guarda.aviso)
		guarda.queue_redraw())
	cli.comprou.connect(func(slot, it):
		print("TESTE comprou %s no slot %d" % [ItensMU.nome(it), slot])
		inv.entrou(slot, it)
		_msg("Comprou %s." % ItensMU.nome(it))
		_contar_pocoes())
	cli.compra_falhou.connect(func():
		print("TESTE compra falhou")
		_msg("[color=#e8b04a]Nao deu pra comprar (zen ou lugar na mochila).[/color]"))
	cli.vendeu.connect(func(ok, z):
		var s := inv.esperando
		print("TESTE vendeu %s slot %d zen %d" % [ok, s, z])
		if ok and s >= 0:
			_msg("Vendeu %s por %s zen." % [ItensMU.nome(inv.itens[s]), ItemChao._milhar(maxi(z - _zen_antes_venda, 0))])
			inv.removido(s)
		elif not ok:
			_msg("[color=#e8b04a]O NPC nao quis esse item.[/color]")
		inv.nao_moveu()
		inv.zen = z
		meu_zen = z
		_hud_nivel()
		_vestir_eu()
		_contar_pocoes())
	cli.amigos.connect(func(l, cartas):
		print("TESTE amigos %s" % [l])
		amigos.definir(l, cartas))
	cli.amigo_novo.connect(func(n, sv):
		print("TESTE amigo novo %s" % n)
		amigos.novo(n, sv))
	cli.amigo_saiu.connect(func(n):
		print("TESTE amigo apagado %s" % n)
		amigos.saiu(n))
	cli.amigo_estado.connect(func(n, sv):
		print("TESTE amigo %s no servidor %d" % [n, sv])
		amigos.estado(n, sv))
	cli.pedido_amizade.connect(func(n):
		print("TESTE pedido de amizade de %s" % n)
		amigos.pedido(n)
		_msg("[color=#9ad0ff]%s quer ser seu amigo. Aperte F pra responder.[/color]" % n))
	cli.saiu.connect(func(tipo):
		print("TESTE saiu %d" % tipo)
		if tipo == 1:
			meu_nome = ""
			_limpar_mundo()
			hud.visible = false
			painel.visible = true
			_limpar_lista()
			cli.pedir_personagens()
		else:
			_sair())


# testes: --loja <parte do nome do NPC> anda ate ele, compra o primeiro item e vende
func _teste_loja(quem: String) -> void:
	var achou := false
	for i in 12:
		await get_tree().create_timer(1.5).timeout
		for e: Entidade in entidades.values():
			if e.tipo == "npc" and e.nome.containsn(quem):
				print("TESTE indo ao npc %s em %s" % [e.nome, e.tile])
				falar_com(e.id)
				achou = true
				break
		if achou:
			break
	var l: Dictionary = (await cli.loja)[0]   # o sinal manda [itens, tipo]
	await get_tree().create_timer(0.5).timeout
	if _parametros().has("so_abrir"):
		return
	var s: int = l.keys().min()
	print("TESTE comprando %s (zen %d)" % [ItensMU.nome(l[s]), meu_zen])
	cli.comprar(s)
	var r: Array = await cli.comprou
	await get_tree().create_timer(0.5).timeout
	print("TESTE vendendo slot %d (zen %d, a caixa diz %d)" % [r[0], meu_zen, ItensMU.preco_venda(inv.itens[r[0]]) if inv.itens.has(r[0]) else -1])
	inv.esperando = r[0]
	_zen_antes_venda = meu_zen
	cli.vender(r[0])
	await cli.vendeu
	await get_tree().create_timer(0.3).timeout
	print("TESTE loja ok, zen %d, slot %d %s" % [meu_zen, r[0], "vazio" if not inv.itens.has(r[0]) else "ainda ocupado"])
	_fechar_loja()


# testes: --guarda Baz (bau) ou --guarda Goblin (maquina do caos): abre, guarda e tira 1 zen
# (so no bau), poe o primeiro item da mochila na grade, combina (so na maquina) e traz de volta
func _teste_guarda(quem: String) -> void:
	await get_tree().create_timer(1.5).timeout
	for i in 12:
		var achou := false
		for e: Entidade in entidades.values():
			if e.tipo == "npc" and e.nome.containsn(quem):
				print("TESTE indo ao npc %s em %s" % [e.nome, e.tile])
				falar_com(e.id)
				achou = true
				break
		if achou:
			break
		await get_tree().create_timer(1.5).timeout
	await cli.janela_npc
	await get_tree().create_timer(1.5).timeout
	print("TESTE guarda aberta: %s, %d itens, zen no bau %d" % [guarda.modo, guarda.itens.size(), guarda.zen_bau])
	if _parametros().has("so_abrir"):
		return
	if guarda.modo == "bau":
		var antes := meu_zen
		guarda.zen_guardar.emit(1)
		await cli.bau_zen
		print("TESTE guardou 1 zen: bau %d, mochila %d (antes %d)" % [guarda.zen_bau, meu_zen, antes])
		guarda.zen_tirar.emit(1)
		await cli.bau_zen
		print("TESTE tirou 1 zen: bau %d, mochila %d" % [guarda.zen_bau, meu_zen])
	var s := -1
	for k in inv.itens:
		if k >= Inventario.MOCHILA:
			s = k
			break
	if s < 0:
		print("TESTE guarda: mochila vazia")
		_fechar_loja()
		return
	var it: Dictionary = inv.itens[s]
	var para := guarda.lugar_livre(it)
	print("TESTE guardando %s (mochila %d) na casa %d" % [ItensMU.nome(it), s, para])
	inv.esperando = s
	guarda.guardar.emit(s, para)
	await cli.item_movido
	await get_tree().create_timer(0.5).timeout
	print("TESTE guardou: grade %s, mochila %d %s" % [guarda.itens.keys(), s, "vazia" if not inv.itens.has(s) else "ainda ocupada"])
	if guarda.modo == "caos":
		guarda.combinar.emit()
		await cli.mistura
		await get_tree().create_timer(1.0).timeout
		print("TESTE depois de combinar: %s, grade %s" % [guarda.aviso, guarda.itens.keys()])
	if _parametros().has("deixar"):
		return
	var g := -1
	for k in guarda.itens:
		if ItensMU.chave(guarda.itens[k]) == ItensMU.chave(it):
			g = k
	if g < 0 and not guarda.itens.is_empty():
		g = guarda.itens.keys()[0]   # combinou: traz o que saiu
		it = guarda.itens[g]
	if g < 0:
		print("TESTE guarda: o item sumiu da grade")
		_fechar_loja()
		return
	guarda.esperando = g
	guarda.retirar.emit(g)
	await cli.item_movido
	await get_tree().create_timer(0.5).timeout
	print("TESTE trouxe de volta: grade %s, mochila tem %s" % [guarda.itens.keys(), ItensMU.nome(it) if inv.itens.values().any(func(x): return ItensMU.chave(x) == ItensMU.chave(it)) else "nada"])
	_fechar_loja()
	print("TESTE guarda ok")


# testes: --amigo <nome> pede amizade e mostra a resposta
func _teste_amigo(nome: String) -> void:
	await get_tree().create_timer(2.0).timeout
	print("TESTE pedindo amizade a %s; lista: %s" % [nome, amigos.lista])
	cli.adicionar_amigo(nome)


func _esperar_jogador(nome: String) -> Entidade:
	for i in 60:
		for e: Entidade in entidades.values():
			if is_instance_valid(e) and e.tipo == "jogador" and e.nome == nome:
				return e
		await get_tree().create_timer(0.5).timeout
	print("TESTE nao achei %s por perto" % nome)
	return null


func _primeiro_da_mochila() -> int:
	var k := inv.itens.keys()
	k.sort()
	for s in k:
		if s >= Inventario.MOCHILA and s < Inventario.FIM:
			return s
	return -1


# testes: --troca Nome pede troca, poe o primeiro item da mochila e 100 de zen e aceita
# (o outro roda com --aceitar 1)
func _teste_troca(nome: String) -> void:
	await get_tree().create_timer(3.0).timeout
	var e := await _esperar_jogador(nome)
	if e == null:
		return
	print("TESTE pedindo troca a %s; zen %d, %d itens" % [nome, meu_zen, inv.itens.size()])
	_comando(JanelaComandos.TROCA, e.id)
	await cli.troca_resposta
	await get_tree().create_timer(1.0).timeout
	var s := _primeiro_da_mochila()
	if s >= 0:
		var it: Dictionary = inv.itens[s]
		print("TESTE troca: pondo %s (slot %d)" % [ItensMU.nome(it), s])
		inv.esperando = s
		cli.mover_item(s, troca.lugar_livre(it), it.bytes, 0, 1)
	await get_tree().create_timer(1.0).timeout
	troca._campo.text = "100"
	troca._mandar_zen()
	await get_tree().create_timer(Troca.ESPERA + 1.0).timeout
	print("TESTE troca: aceitando")
	troca.eu_aceitei = true
	cli.botao_troca(true)


# testes: --minha_loja PRECO poe o primeiro item da mochila na loja com esse preco e abre
func _teste_minha_loja(v: int) -> void:
	await get_tree().create_timer(3.0).timeout
	_alternar_minha_loja()
	var s := _primeiro_da_mochila()
	if s < 0:
		print("TESTE mochila vazia")
		return
	print("TESTE loja: pondo %s (slot %d) por %d" % [ItensMU.nome(inv.itens[s]), s, v])
	_preco_pendente[-1] = v
	inv.esperando = s
	cli.mover_item(s, LojaPessoal.PRIMEIRO, inv.itens[s].bytes, 0, 4)
	await cli.loja_preco
	await get_tree().create_timer(1.0).timeout
	loja_pessoal._campo.text = "Loja de teste"
	loja_pessoal.titulo = "Loja de teste"
	loja_pessoal.abrir_minha.emit("Loja de teste")


# testes: --comprar_loja Nome abre a loja de Nome e compra o primeiro item
func _teste_comprar_loja(nome: String) -> void:
	await get_tree().create_timer(3.0).timeout
	var e := await _esperar_jogador(nome)
	if e == null:
		return
	for i in 40:
		if titulos_lojas.has(e.id):
			break
		await get_tree().create_timer(0.5).timeout
	print("TESTE loja de %s: %s; meu zen %d" % [nome, titulos_lojas.get(e.id, "(fechada)"), meu_zen])
	cli.ver_loja(e.id, e.nome)
	await cli.loja_itens
	await get_tree().create_timer(1.0).timeout
	if loja_pessoal.itens.is_empty():
		print("TESTE loja vazia")
		return
	var i: int = loja_pessoal.itens.keys()[0]
	loja_pessoal.comprar_item.emit(i)


# testes: --helper SEGUNDOS liga o MU Helper (golpe comum, pega zen e joias) e conta as mortes;
# salva a configuracao com alcance 5 e "Jewel" nos extras (a proxima entrada mostra se voltou)
func _teste_helper(seg: float) -> void:
	await get_tree().create_timer(3.0).timeout
	while eu.andando() or not _restante.is_empty():
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.0).timeout
	print("TESTE helper: config do servidor caca=%d extras=%s skills=%s" % [helper.c.caca, helper.c.extras, helper.c.skills])
	helper.c.caca = 5
	helper.c.extras = ["Jewel"]
	helper.c.extra = true
	if _parametros().has("helper_skill"):
		helper.c.skills[0] = int(_parametros().helper_skill)
	cli.salvar_helper(helper.serializar())
	helper.alternar()
	await get_tree().create_timer(seg).timeout
	print("TESTE helper: %d mortos, ligado=%s, zen gasto %d, eu em %s" % [helper.mortos, helper.ligado, helper.zen_gasto, eu.tile])
	if helper.ligado:
		helper.alternar()


# fotos (testes/tela_trocas.mjs): abre a troca, a minha loja, a loja de outro e o MU Helper
# com itens da propria mochila (so na tela, nada vai pro servidor); "TESTE foto X" marca a hora
func _teste_fotos_janelas() -> void:
	await get_tree().create_timer(4.0).timeout
	var meus := []
	var k := inv.itens.keys()
	k.sort()
	for s in k:
		if s >= Inventario.MOCHILA and s < Inventario.FIM:
			meus.append(inv.itens[s])
	troca.abrir_troca("Visitante", 152)
	for i in mini(meus.size(), 3):
		troca.item_dele(troca.lugar_livre(meus[i]) if i == 0 else i * 2, meus[i])
	troca.zen_dele = 250000
	troca.dele_aceitou = true
	if meus.size() > 3:
		troca.entrou(0, meus[3])
	troca.meu_zen = 1500
	troca._campo.text = "1500"
	inv.visible = true
	await get_tree().create_timer(2.0).timeout
	print("TESTE foto troca")
	await get_tree().create_timer(2.0).timeout
	troca.visible = false
	for i in mini(meus.size(), 2):
		inv.itens[LojaPessoal.PRIMEIRO + i * 2] = meus[i]
		loja_pessoal.precos[LojaPessoal.PRIMEIRO + i * 2] = 120000 * (i + 1)
	loja_pessoal.titulo = "Joias baratas"
	loja_pessoal._campo.text = ""
	meu_nivel = maxi(meu_nivel, 6)
	loja_pessoal.abrir_minha_loja()
	titulos_lojas[cli.meu_id] = "Joias baratas"
	await get_tree().create_timer(2.0).timeout
	print("TESTE foto minha_loja")
	await get_tree().create_timer(2.0).timeout
	var lista := {}
	for i in mini(meus.size(), 3):
		var it: Dictionary = meus[i].duplicate()
		it.preco = 45000 * (i + 1)
		lista[i * 2] = it
	loja_pessoal.abrir_de_outro(-1, "Visitante", "Tudo pela metade", lista)
	await get_tree().create_timer(2.0).timeout
	print("TESTE foto loja_outro")
	await get_tree().create_timer(2.0).timeout
	loja_pessoal.visible = false
	titulos_lojas.erase(cli.meu_id)
	helper.c.skills = [41, 42, 0]
	helper.c.por_condicao[1] = true
	helper.c.buffs = [48, 0, 0]
	_alternar_janela_helper()
	await get_tree().create_timer(2.0).timeout
	print("TESTE foto helper")
	await get_tree().create_timer(2.0).timeout
	janela_helper.aba = 1
	helper.c.extras = ["Jewel of Bless", "Box of Luck"]
	janela_helper.queue_redraw()
	await get_tree().create_timer(2.0).timeout
	print("TESTE foto helper_itens")


# testes: --trocar 1 volta pra escolha de personagem e entra de novo (--trocar Nome: entra com outro)
func _teste_trocar() -> void:
	await get_tree().create_timer(2.0).timeout
	print("TESTE helper antes de trocar: %s caca=%d skills=%s" % [meu_nome, helper.c.caca, helper.c.skills])
	var quem := meu_nome if str(_parametros().trocar) == "1" else str(_parametros().trocar)
	cli.sair_para(1)
	var l: Array = await cli.personagens
	print("TESTE de volta na escolha: %s" % [l.map(func(x): return x.nome)])
	await get_tree().create_timer(0.5).timeout
	_escolher(quem)
	await cli.entrou
	await get_tree().create_timer(2.0).timeout
	print("TESTE helper depois de trocar: %s caca=%d skills=%s" % [meu_nome, helper.c.caca, helper.c.skills])


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
		# niveis e opcoes variados, pra ver as cores do nome no chao
		l.append({"id": 60000 + k, "x": x - 3 + k % 4 * 2, "y": y + 2 + k / 4 * 2, "grupo": int(chaves[k].get_slice(",", 0)),
			"numero": int(chaves[k].get_slice(",", 1)), "nivel": [0, 1, 3, 5, 7, 9, 0, 0, 0, 0, 0, 2][k],
			"exc": 0x21 if k == 7 else 0, "sorte": k == 6, "skill": k == 6, "opcao": 1 if k == 6 else 0})
	l.append({"id": 60100, "x": x + 5, "y": y + 4, "zen": 5000})
	_itens_cairam(l)
	# onde ficam na tela o item excelente e o NPC mais perto (o roteiro de foto passa o mouse neles)
	await get_tree().create_timer(1.0).timeout
	var cam := get_viewport().get_camera_3d()
	var pi: Vector2 = cam.unproject_position(itens[60007].global_position + Vector3.UP * 0.2)
	print("TESTE tela item %d,%d" % [pi.x, pi.y])
	for e: Entidade in entidades.values():
		if e.tipo == "npc" and is_instance_valid(e) and not cam.is_position_behind(e.global_position):
			var pn: Vector2 = cam.unproject_position(e.global_position + Vector3.UP * e.altura() * 0.6)
			if Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).has_point(pn):
				print("TESTE tela npc %d,%d" % [pn.x, pn.y])
				break
	# numeros do dano de cada tipo, em mim e em quem estiver perto, um a cada 0,3 s
	var tipos := [[1234, 0, 0], [0, 0, 0], [5678, 2, 0], [987, 3, 0], [432, 0, 120], [77, 0x40, 0]]
	for i in 40:
		await get_tree().create_timer(0.3).timeout
		var t: Array = tipos[i % tipos.size()]
		var quem: Entidade = eu
		if i % 2 == 1:
			for e: Entidade in entidades.values():
				if e != eu and is_instance_valid(e) and _distancia(e.tile, eu.tile) < 8:
					quem = e
					break
		if quem:
			quem.mostrar_dano(t[0], t[1], t[2])


var _teste_monta := false   # &monta: a montaria fica a mostra na zona segura

# testes (?efeito_teste=4,3,41): solta o efeito de cada skill a 3 tiles na frente, uma a cada 3 s
func _efeito_teste(lista: Array) -> void:
	# ?lento=0.25: camera lenta, pra foto no navegador de teste (poucos quadros por segundo)
	Engine.time_scale = float(_parametros().get("lento", "1"))
	await get_tree().create_timer(4.0).timeout
	# &monta=red (black, blue, gold): o heroi no Fenrir dessa cor, pro golpe do Fenrir (76)
	if _parametros().has("monta") and eu != null:
		_teste_monta = true
		var d := eu.boneco.vestido()
		d[8] = "13,37"
		d["fenrir"] = str(_parametros().monta)
		eu.boneco.vestir(d)
	for x in lista:
		if eu == null:
			return
		var n := int(x)
		var p: Vector3 = mundo.no_tile(eu.tile.x + 3, eu.tile.y - 3)
		var alvo := Node3D.new()
		mundo.add_child(alvo)
		alvo.global_position = p
		eu.tocar_skill(_acao_skill(n), p)
		print("TESTE efeito %d" % n)
		EfeitoSkill.criar(mundo, n, eu, alvo, n in EM_VOLTA or int(_info_skill(n)[2]) in [3, 4, 5])
		await get_tree().create_timer(3.0).timeout
		print("TESTE depois do efeito %d: heroi visivel %s" % [n, eu.boneco.visible])
		alvo.queue_free()


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


# testes: --falar <parte do nome> anda ate o NPC e fala com ele
func _teste_falar(quem: String) -> void:
	await get_tree().create_timer(2.0).timeout
	for e: Entidade in entidades.values():
		if e.tipo == "npc" and e.nome.containsn(quem):
			print("TESTE indo falar com %s (%d) em %s" % [e.nome, e.id, e.tile])
			falar_com(e.id)
			return
	print("TESTE nenhum npc com %s: %s" % [quem, entidades.values().filter(func(x): return x.tipo == "npc").map(func(x): return x.nome)])


# --minimapa 1: abre o Tab; --minimapa x,y: abre e anda ate o tile (botao direito)
func _teste_minimapa(q: String) -> void:
	await get_tree().create_timer(2.0).timeout
	hud.move_child(minimapa, -1)
	minimapa.alternar(mapa_atual)
	print("TESTE minimapa aberto %s no mapa %d" % [minimapa.visible, mapa_atual])
	var xy := q.split(",")
	if xy.size() == 2:
		var t := Vector2i(int(xy[0]), int(xy[1]))
		# o mesmo caminho do clique: tela -> tile pela conta do minimapa
		var tela: Vector2 = minimapa._base() * (Vector2(t) + Vector2(0.5, 0.5))
		print("TESTE minimapa: %s fica em %s na tela, volta %s" % [t, tela, minimapa.tile_em(tela)])
		minimapa.ir_para(minimapa.tile_em(tela))
		for i in 120:
			await get_tree().create_timer(1.0).timeout
			if not eu.andando() and _restante.is_empty():
				break
		print("TESTE minimapa: parei em %s" % eu.tile)


# --- inventario --------------------------------------------------------------------

func _ligar_inventario_e_skills() -> void:
	cli.inventario.connect(func(l):
		inv.definir(l)
		print("TESTE inventario %d itens" % l.size())
		_vestir_eu()
		_contar_pocoes())
	cli.item_movido.connect(func(slot, it, arm):
		print("TESTE movido para %d (armazem %d)" % [slot, arm])
		if arm == 1:
			# da mochila pra minha grade da troca
			if inv.esperando >= 0:
				inv.removido(inv.esperando)
				inv.nao_moveu()
			troca.entrou(slot, it)
		elif troca.esperando >= 0 and troca.visible:
			# da troca de volta pra mochila
			troca.saiu(troca.esperando)
			inv.entrou(slot, it)
		elif loja_pessoal.esperando >= 0:
			# da loja de volta pra mochila
			inv.removido(loja_pessoal.esperando)
			loja_pessoal.precos.erase(loja_pessoal.esperando)
			_salvar_precos()
			loja_pessoal.esperando = -1
			inv.entrou(slot, it)
			loja_pessoal.queue_redraw()
		elif slot >= LojaPessoal.PRIMEIRO and slot < LojaPessoal.PRIMEIRO + 32:
			# da mochila pra loja (o servidor responde no inventario, slot 204+): agora o preco
			inv.movido(slot, it)
			if _preco_pendente.has(-1):
				_preco_pendente[slot] = _preco_pendente[-1]
				_preco_pendente.erase(-1)
				cli.preco_loja(slot, _preco_pendente[slot])
			loja_pessoal.queue_redraw()
		elif arm in [2, 3]:
			# da mochila (ou de outro lugar da grade) pro bau ou pra maquina
			if inv.esperando >= 0:
				inv.removido(inv.esperando)
				inv.nao_moveu()
			guarda.entrou(slot, it)
		elif guarda.esperando >= 0 and guarda.visible:
			# do bau ou da maquina pra mochila
			guarda.saiu(guarda.esperando)
			inv.entrou(slot, it)
		else:
			inv.movido(slot, it)
		_vestir_eu()
		_contar_pocoes())
	cli.item_nao_moveu.connect(func():
		print("TESTE nao moveu")
		inv.nao_moveu()
		_preco_pendente.erase(-1)
		troca.esperando = -1
		loja_pessoal.esperando = -1
		loja_pessoal.queue_redraw()
		troca.queue_redraw()
		guarda.esperando = -1
		guarda.queue_redraw()
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
	cli.aparencia_mudou.connect(func(quem, slot, chave, nivel):
		var e: Entidade = entidades.get(quem)
		if quem == cli.meu_id or e == null or e.boneco == null:
			return
		var d: Dictionary = e.boneco.vestido()
		if chave == "":
			d.erase(slot)
			d.niveis.erase(slot)
		else:
			d[slot] = chave
			d.niveis[slot] = nivel
		e.boneco.vestir(d))
	cli.area_animacao.connect(func(n, quem, x, y, _giro):
		if quem == cli.meu_id or not entidades.has(quem) or mundo == null:
			return
		var e: Entidade = entidades[quem]
		var p: Vector3 = mundo.no_tile(x, y)
		e.tocar_skill(_acao_skill(n), p)
		EfeitoSkill.criar(mundo, n, e, p, true))


# --- troca, loja pessoal e MU Helper ---------------------------------------------------

func _ligar_troca_loja_helper() -> void:
	# troca
	cli.pedido_troca.connect(func(n):
		print("TESTE pedido de troca de %s" % n)
		if troca.visible or loja_pessoal.aberta:
			cli.responder_troca(false)
			return
		_perguntar("%s quer trocar com voce." % n, func(ok): cli.responder_troca(ok)))
	cli.troca_resposta.connect(func(ok, n, nivel, _g):
		print("TESTE troca %s com %s (nivel %d)" % ["abriu" if ok else "recusada", n, nivel])
		if not ok:
			_msg("[color=#e8b04a]%s recusou a troca.[/color]" % n)
			return
		_fechar_loja()
		loja_pessoal.visible = false
		janela_helper.visible = false
		troca.abrir_troca(n, nivel)
		if not inv.visible:
			inv.alternar())
	cli.troca_item_dele.connect(func(sl, it):
		print("TESTE troca: o outro pos %s no %d" % [ItensMU.nome(it), sl])
		troca.item_dele(sl, it))
	cli.troca_item_dele_saiu.connect(troca.item_dele_saiu)
	cli.troca_zen_dele.connect(func(v):
		print("TESTE troca: zen dele %d" % v)
		troca.zen_dele = v
		troca.queue_redraw())
	cli.troca_zen_ok.connect(troca.zen_confirmado)
	cli.troca_botao_dele.connect(func(e):
		print("TESTE troca: botao dele %d" % e)
		troca.botao_dele(e))
	cli.troca_fim.connect(func(r):
		print("TESTE troca terminou %d" % r)
		troca.visible = false
		inv.nao_moveu()
		_msg("[color=%s]%s[/color]" % ["#9fe0a0" if r == 1 else "#e8b04a",
			["A troca foi cancelada.", "Troca feita.", "A troca nao fechou: a mochila nao tem espaco.",
			"A troca acabou o tempo.", "Esse item nao pode ser trocado."][clampi(r, 0, 4)]]))
	troca.por.connect(func(de, para):
		cli.mover_item(de, para, inv.itens[de].bytes, 0, 1))
	troca.tirar.connect(func(sl):
		var para := inv.lugar_livre(troca.itens[sl])
		if para < 0:
			troca.esperando = -1
			_msg("[color=#e8b04a]Mochila cheia.[/color]")
			return
		cli.mover_item(sl, para, troca.itens[sl].bytes, 1, 0))
	troca.zen.connect(func(v):
		if v > meu_zen + troca.meu_zen:
			_msg("[color=#e8b04a]Voce so tem %s zen.[/color]" % ItemChao._milhar(meu_zen + troca.meu_zen))
		else:
			cli.zen_troca(v))
	troca.aceitar.connect(func(a):
		print("TESTE troca: meu botao %s" % a)
		cli.botao_troca(a))
	troca.cancelar.connect(func(): cli.cancelar_troca())
	troca.fechar.connect(func(): cli.cancelar_troca())
	# loja pessoal
	loja_pessoal.por.connect(func(de, para, v):
		_preco_pendente[-1] = v
		cli.mover_item(de, para, inv.itens[de].bytes, 0, 4))
	loja_pessoal.tirar.connect(func(sl):
		var para := inv.lugar_livre(inv.itens[sl])
		if para < 0:
			loja_pessoal.esperando = -1
			_msg("[color=#e8b04a]Mochila cheia.[/color]")
			return
		cli.mover_item(sl, para, inv.itens[sl].bytes, 4, 0))
	loja_pessoal.preco.connect(func(sl, v):
		_preco_pendente[sl] = v
		cli.preco_loja(sl, v))
	loja_pessoal.abrir_minha.connect(func(t):
		if loja_pessoal.grade().is_empty():
			_msg("[color=#e8b04a]Ponha pelo menos um item na loja.[/color]")
		elif loja_pessoal.falta_preco():
			_msg("[color=#e8b04a]Todo item da loja precisa de preco (botao direito no item).[/color]")
		elif t == "":
			_msg("[color=#e8b04a]Escreva o nome da loja.[/color]")
		else:
			cli.abrir_loja(t))
	loja_pessoal.fechar_minha.connect(func(): cli.fechar_loja())
	loja_pessoal.comprar_item.connect(func(i):
		_comprando = i
		print("TESTE comprando da loja de %s a casa %d" % [loja_pessoal.dono, i])
		cli.comprar_loja(loja_pessoal.dono_id, loja_pessoal.dono, LojaPessoal.PRIMEIRO + i))
	loja_pessoal.fechar.connect(_fechar_loja_pessoal)
	cli.loja_preco.connect(func(r, sl):
		print("TESTE preco da loja %d no %d" % [r, sl])
		if r == 1 and _preco_pendente.has(sl):
			loja_pessoal.precos[sl] = _preco_pendente[sl]
			_salvar_precos()
		elif r != 1:
			_msg("[color=#e8b04a]O servidor nao aceitou esse preco.[/color]")
		_preco_pendente.erase(sl)
		loja_pessoal.queue_redraw())
	cli.loja_aberta.connect(func(ok):
		print("TESTE minha loja abriu %s" % ok)
		loja_pessoal.aberta = ok
		if loja_pessoal.visible and loja_pessoal.modo == "minha":
			loja_pessoal.abrir_minha_loja()
		if ok:
			titulos_lojas[cli.meu_id] = loja_pessoal.titulo
			_salvar_precos()
			_msg("[color=#9fe0a0]Loja aberta. Quem passar ve o titulo em cima do seu nome.[/color]")
		else:
			_msg("[color=#e8b04a]A loja nao abriu (precisa do nivel 6 e de preco em tudo).[/color]"))
	cli.lojas.connect(func(l):
		for k in l:
			titulos_lojas[k.id] = k.titulo
		print("TESTE lojas por perto %s" % [l]))
	cli.loja_fechou.connect(func(id):
		titulos_lojas.erase(id)
		if id == cli.meu_id:
			loja_pessoal.aberta = false
			if loja_pessoal.visible:
				loja_pessoal.abrir_minha_loja()
			_msg("[color=#9ad0ff]Loja fechada.[/color]")
		elif loja_pessoal.visible and loja_pessoal.modo == "outro" and loja_pessoal.dono_id == id:
			loja_pessoal.visible = false)
	cli.loja_itens.connect(func(id, n, t, l, atualizacao):
		var lista := {}
		for k in l:
			lista[int(k) - LojaPessoal.PRIMEIRO] = l[k]
		print("TESTE loja de %s: %s com %d itens" % [n, t, lista.size()])
		titulos_lojas[id] = t
		if atualizacao and not (loja_pessoal.visible and loja_pessoal.modo == "outro" and loja_pessoal.dono_id == id):
			return
		_fechar_loja()
		troca.visible = false
		janela_helper.visible = false
		loja_pessoal.abrir_de_outro(id, n, t, lista)
		if not inv.visible:
			inv.alternar())
	cli.loja_compra.connect(func(r, _v, it, sl):
		print("TESTE compra da loja %d no %d" % [r, sl])
		if r == 1:
			inv.entrou(sl, it)
			loja_pessoal.itens.erase(_comprando)
			loja_pessoal.queue_redraw()
			_msg("[color=#9fe0a0]Comprou %s.[/color]" % ItensMU.nome(it))
		else:
			_msg("[color=#e8b04a]A compra nao deu certo (%s).[/color]" % {2: "o item ja foi vendido", 3: "a loja fechou",
				4: "outra compra em andamento", 5: "o item nao esta mais la", 6: "o item ficou sem preco",
				7: "falta zen", 8: "a mochila esta cheia ou o zen passaria do limite", 9: "item bloqueado"}.get(r, "codigo %d" % r))
		_comprando = -1)
	cli.loja_vendeu.connect(func(sl, quem):
		var nome: String = ItensMU.nome(inv.itens[sl]) if inv.itens.has(sl) else "um item"
		print("TESTE vendi o %d pra %s" % [sl, quem])
		loja_pessoal.precos.erase(sl)
		_salvar_precos()
		_msg("[color=#f0c860]%s comprou %s da sua loja.[/color]" % [quem, nome]))
	cli.loja_dialogo_fechou.connect(func(id):
		if loja_pessoal.modo == "outro" and loja_pessoal.dono_id == id:
			loja_pessoal.visible = false)
	# MU Helper
	cli.helper_estado.connect(func(pausado, consumiu, z):
		print("TESTE helper estado pausado=%s consumiu=%s zen=%d" % [pausado, consumiu, z])
		helper.estado(pausado, consumiu, z))
	cli.helper_dados.connect(func(d):
		helper.desserializar(d)
		print("TESTE helper dados %d bytes: caca=%d extras=%s" % [d.size(), helper.c.caca, helper.c.extras]))
	cli.efeito.connect(func(a, quem, e): helper.efeito(a, quem, e))
	cli.efeito.connect(func(a, quem, e):
		if quem == cli.meu_id and e == 3:
			# buff da Elf Soldier (ate o nivel 180): mais dano e defesa
			print("TESTE buff da elf soldier %s" % a)
			_msg("[color=#7fe0ff]%s[/color]" % ("Buff da Elf Soldier: dano e defesa maiores." if a else "O buff da Elf Soldier acabou.")))
	helper.mudou.connect(_trocar_icone_helper)
	cli.mensagem.connect(func(t):
		if helper.pedindo and t.to_lower().contains("helper"):
			helper.pedindo = false)


func _alternar_minha_loja() -> void:
	if loja_pessoal.visible and loja_pessoal.modo == "minha":
		_fechar_loja_pessoal()
		return
	if troca.visible:
		return
	if meu_nivel < 6:
		_msg("[color=#e8b04a]A loja pessoal abre a partir do nivel 6.[/color]")
		return
	_fechar_loja()
	janela_helper.visible = false
	_carregar_precos()
	loja_pessoal.abrir_minha_loja()
	if not inv.visible:
		inv.alternar()


func _fechar_loja_pessoal() -> void:
	if loja_pessoal.modo == "outro" and loja_pessoal.dono_id >= 0:
		cli.sair_loja(loja_pessoal.dono_id, loja_pessoal.dono)
	loja_pessoal.visible = false
	inv.soltar()


func _carregar_precos() -> void:
	var c := ConfigFile.new()
	if c.load("user://loja_%s.cfg" % meu_nome.validate_filename()) == OK:
		loja_pessoal.titulo = c.get_value("loja", "titulo", loja_pessoal.titulo)
		var p: Dictionary = c.get_value("loja", "precos", {})
		for k in p:
			if not loja_pessoal.precos.has(int(k)):
				loja_pessoal.precos[int(k)] = int(p[k])


func _salvar_precos() -> void:
	var c := ConfigFile.new()
	c.set_value("loja", "titulo", loja_pessoal.titulo)
	c.set_value("loja", "precos", loja_pessoal.precos)
	c.save("user://loja_%s.cfg" % meu_nome.validate_filename())


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
				if s >= Inventario.MOCHILA and s < Inventario.FIM and ItensMU.chave(it) == k:
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
		if s >= Inventario.MOCHILA and s < Inventario.FIM and ItensMU.chave(inv.itens[s]) == ItensMU.chave(it):
			print("TESTE usando %s do slot %d" % [ItensMU.nome(it), s])
			cli.usar_item(s)
			return


# teclas do jogo; devolve true se usou a tecla
func _teclas(ev: InputEventKey) -> bool:
	var k := ev.keycode
	if k == KEY_ALT:
		textos.nomes_itens = not textos.nomes_itens   # Alt: nome de todos os itens do chao (como no cliente)
		return true
	if k in [KEY_I, KEY_V]:
		inv.alternar()
		return true
	if k == KEY_F:
		amigos.alternar()
		return true
	if k == KEY_U:
		menu.alternar(brilho)
		return true
	if k == KEY_TAB:
		hud.move_child(minimapa, -1)
		if not minimapa.alternar(mapa_atual):
			_msg("[color=#9a9ab0]Este mapa nao tem minimapa no cliente S6.[/color]")
		return true
	if k == KEY_M:
		mover_janela.alternar(meu_nivel, meu_zen, minha_classe)
		return true
	if k == KEY_D:
		_botao_barra("comandos")
		return true
	if k == KEY_S:
		_alternar_minha_loja()
		return true
	if k == KEY_Z:
		_alternar_janela_helper()
		return true
	if k == KEY_HOME:
		helper.alternar()
		return true
	if k == KEY_ESCAPE:
		if minimapa.visible:
			minimapa.visible = false
		elif menu.visible:
			menu.visible = false
		elif mover_janela.visible:
			mover_janela.visible = false
		elif troca.visible:
			cli.cancelar_troca()
		elif janela_helper.visible:
			janela_helper.visible = false
		elif loja_pessoal.visible:
			_fechar_loja_pessoal()
		elif loja.visible or guarda.visible or dialogo.visible:
			_fechar_loja()
		elif inv.visible:
			inv.alternar()
		elif comandos.visible:
			comandos.alternar()
		elif janela_personagem.visible:
			janela_personagem.alternar()
		elif amigos.visible:
			amigos.visible = false
		else:
			menu.alternar(brilho)
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
	print("TESTE barra skills %s" % [l])
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
		41: "giro", 42: "furia", 43: "estocada", 232: "destruicao", 44: "lua", 47: "estocada",
		14: "inferno", 10: "fogo_inferno", 12: "raio", 26: "cura", 27: "cura", 28: "cura", 48: "cura",
		24: "arco", 52: "arco", 46: "arco", 51: "arco", 235: "arco",
		6: "teleporte", 58: "nova_carga", 40: "nova", 233: "magia_cheia", 77: "flecha_infinita", 76: "fenrir_skill",
		30: "cura", 31: "cura", 32: "cura", 33: "cura", 34: "cura", 35: "cura", 36: "cura",
		57: "um_corte", 73: "canhao", 236: "golpe_chama", 237: "tempestade",
		60: "golpe_dl", 61: "golpe_dl", 66: "golpe_dl", 74: "golpe_dl", 78: "golpe_dl", 238: "golpe_dl",
		62: "terremoto_cavalo", 63: "teleporte_dl", 64: "magia", 65: "raio", 72: "vitalidade"}
	if a.has(n):
		return a[n]
	return "magia2" if n in [5, 9, 13, 38, 39] else "magia"


# botao direito: solta a skill atual no monstro do mouse (ou no chao, se for de area).
# de_novo: o botao segue apertado e a skill anterior ja saiu (_skills): solta outra vez onde o
# mouse estiver, sem mensagem; sem monstro no mouse, segue no ultimo; teleporte e Nova nao repetem
func _skill_no_mouse(tela: Vector2, de_novo := false) -> void:
	var n: int = barra_mu.skill_atual
	if de_novo and n in [6, 15, 40]:
		_segura_direito = false
		return
	if n < 0:
		if de_novo:
			return
		_msg("[color=#9a9ab0]Esse personagem nao tem skill. Clique no quadro verde da barra pra ver a lista.[/color]")
		return
	var info := _info_skill(n)
	var tipo := int(info[2])
	var e := _entidade_na_tela(tela)
	if de_novo and (e == null or e.tipo != "monstro") and tipo in [0, 3, 5]:
		var ant: Entidade = entidades.get(_skill_ultimo)
		if ant and not ant.morto and ant.tipo == "monstro":
			e = ant
		elif tipo == 0:
			return
	if de_novo and tipo not in [0, 3, 4, 5, 10, 11, 30] and n != 63:
		_segura_direito = false
		return
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
	elif tipo == 30 or n == 63:
		# invocacao (elfa) e Summon do Dark Lord: a skill vai em mim
		skill_alvo = cli.meu_id
	elif n == 6:
		skill_ponto = mundo.tile_na_tela(tela)
		if skill_ponto.x < 0 or not mundo.anda(skill_ponto.x, skill_ponto.y):
			_msg("[color=#e8b04a]Nao da pra teleportar pra ai.[/color]")
			skill_numero = -1
			return
	elif n == 15:
		if e == null or e.tipo != "jogador":
			_msg("[color=#9a9ab0]%s precisa de um jogador do seu grupo: aponte nele e clique com o botao direito.[/color]" % info[0])
			skill_numero = -1
			return
		skill_alvo = e.id
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


# leva a skill ate o alvo e solta; com o botao direito segurado (como no cliente) solta de novo
# a cada RECARGA_SKILL onde o mouse estiver
func _skills(dt: float) -> void:
	_skill_recarga -= dt
	if _segura_direito and not _direito_apertado():
		_segura_direito = false
	if skill_numero < 0 and _segura_direito and _skill_recarga <= 0.0 and not eu.morto and comandos.selecionado < 0:
		_skill_no_mouse(_mouse_skill(), true)
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
		_segura_direito = false
		return
	if barra_mu.mana < int(info[4]):
		_msg("[color=#e8b04a]Falta mana pra %s.[/color]" % info[0])
		skill_numero = -1
		_segura_direito = false
		return
	if barra_mu.ag < int(info[5]):
		_msg("[color=#e8b04a]Falta AG pra %s.[/color]" % info[0])
		skill_numero = -1
		_segura_direito = false
		return
	_skill_recarga = RECARGA_SKILL
	_lancadas += 1
	if alvo and alvo.tipo == "monstro":
		_skill_ultimo = alvo.id
	var p: Vector3 = alvo.position if alvo else mundo.no_tile(ponto.x, ponto.y)
	eu.tocar_skill(_acao_skill(n), p)
	if n == 6:
		cli.teleporte(ponto.x, ponto.y)
		print("TESTE teleporte pra %s" % ponto)
		EfeitoSkill.criar(mundo, n, eu, eu)
		skill_numero = -1
		return
	if n == 15:
		var livre := _livre_perto(eu.tile)
		cli.teleporte_aliado(skill_alvo, livre.x, livre.y)
		print("TESTE teleporte do aliado %d pra %s" % [skill_alvo, livre])
		skill_numero = -1
		return
	if n == 40:
		_nova(skill_alvo)
		skill_numero = -1
		return
	if tipo in [0, 10, 11, 30] or n == 63:
		cli.skill_alvo(n, skill_alvo)
		print("TESTE skill %d no alvo %d" % [n, skill_alvo])
	else:
		var d := ponto - eu.tile
		var giro := 0
		if d != Vector2i.ZERO:
			var th := rad_to_deg(atan2(-d.x, d.y))
			giro = int(round(fposmod(th - 180.0, 360.0) * 256.0 / 360.0)) & 0xFF
		var meio := eu.tile if n in EM_VOLTA else ponto
		cli.skill_area(n, meio.x, meio.y, giro, skill_alvo if (tipo == 5 or n == 76) and skill_alvo >= 0 else 0)
		print("TESTE skill %d em area (%d, %d) giro %d" % [n, meio.x, meio.y, giro])
	EfeitoSkill.criar(mundo, n, eu, alvo if alvo else p, tipo in [3, 4, 5])
	# a proxima sai do _skill_no_mouse(de_novo), com o alvo que estiver no mouse
	if not _cacar_skill:
		skill_numero = -1


# Nova: segurar manda a carga (58) em mim, o servidor sobe o estagio a cada 0,5 s; soltar manda o 40
func _nova(alvo: int) -> void:
	cli.skill_alvo(58, cli.meu_id)
	EfeitoSkill.criar(mundo, 58, eu, eu)
	var t := 0.0
	while t < 6.0 and (t < 0.6 or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or _cacar_skill and t < 2.0):
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	if eu == null or eu.morto:
		return
	var a: int = alvo if entidades.has(alvo) else cli.meu_id
	cli.skill_alvo(40, a)
	eu.tocar_skill(_acao_skill(40), entidades[a].position if entidades.has(a) else eu.position)
	EfeitoSkill.criar(mundo, 40, eu, eu)
	print("TESTE nova soltou em %d depois de %.1f s" % [a, t])


# tile andavel mais perto de t, sem ser o proprio t (Teleport Ally)
func _livre_perto(t: Vector2i) -> Vector2i:
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := t + Vector2i(dx, dy)
				if mundo.anda(q.x, q.y):
					return q
	return t


var _cacar_skill := false   # testes: --skill N usa a skill N no lugar do golpe comum
var _segura_direito := false   # o botao direito desceu no jogo (nao numa janela) e segue apertado
var _skill_ultimo := -1        # o ultimo monstro que levou a skill (segurando, sem monstro no mouse, segue nele)
var _lancadas := 0             # skills soltas (testes)
var _segurar_teste := false    # testes: --segurar N faz de conta que o botao esta apertado no monstro mais perto


func _direito_apertado() -> bool:
	return _segurar_teste or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _mouse_skill() -> Vector2:
	if not _segurar_teste:
		return get_viewport().get_mouse_position()
	# testes: o mouse em cima do monstro vivo mais perto (fora da zona segura)
	var cam := get_viewport().get_camera_3d()
	var perto: Entidade = null
	for e: Entidade in entidades.values():
		if e.tipo == "monstro" and not e.morto and (perto == null or _distancia(e.tile, eu.tile) < _distancia(perto.tile, eu.tile)):
			perto = e
	if perto == null or cam == null:
		return Vector2(-100, -100)
	return cam.unproject_position(perto.global_position + Vector3.UP * perto.altura() * 0.5)


func _skill_de_outro(n: int, quem: int, alvo: int) -> void:
	if quem == cli.meu_id or mundo == null or not entidades.has(quem):
		return
	var e: Entidade = entidades[quem]
	var a: Entidade = entidades.get(alvo, e)
	e.tocar_skill(_acao_skill(n), a.position)
	EfeitoSkill.criar(mundo, n, e, a)


var _skill_teste := -1
var _costas_t := 0.0


# o que eu visto vem do inventario (slots 0 a 8)
func _vestir_eu() -> void:
	if eu == null or eu.boneco == null:
		return
	var d := {}
	var niveis := {}
	for s in 9:
		if inv.itens.has(s) and s != inv.esperando:
			d[s] = ItensMU.chave(inv.itens[s])
			niveis[s] = inv.itens[s].nivel
	if d.get(8, "") == "13,37":
		var x: int = inv.itens[8].exc
		d["fenrir"] = "black" if x & 1 else ("blue" if x & 2 else ("gold" if x & 4 else "red"))
	print("TESTE vestido %s niveis %s" % [d, niveis])
	d["niveis"] = niveis
	eu.boneco.vestir(d)


# testes: --inventario 1 move o primeiro item da mochila pra outra casa, usa a
# pocao do Q e tira e poe de volta a arma da mao
# testes: --desmontar 1 tira a montaria do slot 8 (botao direito) e poe de volta
# uma_skill=N: usa a skill N uma vez (no monstro mais perto, ou em mim) e mostra quem esta perto depois
func _teste_uma_skill(n: int) -> void:
	await get_tree().create_timer(3.0).timeout
	while eu.andando() or not _restante.is_empty():
		await get_tree().create_timer(0.5).timeout
	var antes := entidades.keys()
	var perto: Entidade = null
	for e: Entidade in entidades.values():
		if e.tipo == "monstro" and not e.morto and (perto == null or _distancia(e.tile, eu.tile) < _distancia(perto.tile, eu.tile)):
			perto = e
	barra_mu.skill_atual = n
	skill_numero = n
	skill_alvo = perto.id if perto else cli.meu_id
	skill_ponto = Vector2i(-1, -1)
	if int(_info_skill(n)[2]) in [10, 11, 30] or n == 63:
		skill_alvo = cli.meu_id
	elif n == 6:
		skill_alvo = -1
		skill_ponto = _livre_perto(eu.tile + Vector2i(4, 0))
	elif int(_info_skill(n)[2]) in [3, 4] and perto == null:
		skill_alvo = -1
		skill_ponto = eu.tile + Vector2i(2, 0)
	print("TESTE uma_skill %d alvo %d ponto %s eu em %s" % [n, skill_alvo, skill_ponto, eu.tile])
	cli.objeto_entrou.connect(func(o): print("TESTE entrou objeto %s" % o))
	for e: Entidade in entidades.values():
		if e.tipo == "invocado" or _distancia(e.tile, eu.tile) <= 2:
			print("TESTE perto: %s %s (%d) em %s" % [e.tipo, e.nome, e.id, e.tile])
	cli.skill_animacao.connect(func(sk, q, a): print("TESTE animacao skill %d de %d em %d" % [sk, q, a]))
	cli.area_animacao.connect(func(sk, q, x, y, _g): print("TESTE animacao area %d de %d em (%d, %d)" % [sk, q, x, y]))
	cli.golpe.connect(func(id, dano, _t, _e): print("TESTE dano %d em %d" % [dano, id]))
	await get_tree().create_timer(5.0).timeout
	if _parametros().has("de_novo"):
		skill_numero = n
		print("TESTE de novo")
		await get_tree().create_timer(5.0).timeout
	for id in entidades:
		if id not in antes:
			print("TESTE apareceu %s (%s) em %s" % [entidades[id].nome, entidades[id].tipo, entidades[id].tile])
	print("TESTE depois eu em %s, visivel %s" % [eu.tile, eu.boneco.visible])


# segurar=N: "aperta" o botao direito com a skill N no monstro mais perto, segura 8 s e solta;
# conta quantas sairam (o cliente repete sozinho enquanto o botao esta apertado)
func _teste_segurar(n: int) -> void:
	await get_tree().create_timer(3.0).timeout
	while eu.andando() or not _restante.is_empty():
		await get_tree().create_timer(0.5).timeout
	barra_mu.skill_atual = n
	cli.golpe.connect(func(id, dano, _t, _e): print("TESTE dano %d em %d" % [dano, id]))
	_segurar_teste = true
	_segura_direito = true
	_skill_no_mouse(_mouse_skill())
	print("TESTE segurando skill %d alvo %d ponto %s" % [n, skill_alvo, skill_ponto])
	var antes := _lancadas
	await get_tree().create_timer(8.0).timeout
	_segurar_teste = false
	var segurando := _lancadas - antes
	await get_tree().create_timer(3.0).timeout
	print("TESTE segurar %d: %d soltas em 8 s, %d depois de soltar" % [n, segurando, _lancadas - antes - segurando])


# comando=N,Nome: abre a janela D, aperta o botao N e usa no jogador Nome quando ele aparecer
func _teste_comando(a: PackedStringArray) -> void:
	_botao_barra("comandos")
	for i in 60:
		await get_tree().create_timer(1.0).timeout
		for e: Entidade in entidades.values():
			if is_instance_valid(e) and e.nome == a[1]:
				print("TESTE achei %s em %s, eu em %s" % [e.nome, e.tile, eu.tile])
				if _distancia(eu.tile, e.tile) > JanelaComandos.DISTANCIA:
					andar_ate(e.tile)
					await get_tree().create_timer(4.0).timeout
				comandos.clique(Vector2(95, 33 + int(a[0]) * 30 + 14))
				print("TESTE botao %s apertado: %s" % [comandos.nome(int(a[0])), comandos.selecionado == int(a[0])])
				_comando_no_mouse(get_viewport().get_camera_3d().unproject_position(e.global_position + Vector3.UP))
				await get_tree().create_timer(5.0).timeout
				print("TESTE seguindo %d eu em %s ele em %s" % [seguindo, eu.tile, e.tile if is_instance_valid(e) else "outro mapa"])
				return
	print("TESTE nao achei %s" % a[1])


# ponto=N: abre a janela C e clica 3 vezes no + do atributo N, como a pessoa faria
func _teste_ponto(a: int) -> void:
	await get_tree().create_timer(2.0).timeout
	_botao_barra("personagem")
	var j := janela_personagem
	print("TESTE janela antes: pontos %d %s vida_max %d mana_max %d" % [j.eu.pontos, [j.eu.forca, j.eu.agilidade, j.eu.vitalidade, j.eu.energia, j.eu.comando], barra_mu.vida_max, barra_mu.mana_max])
	print("TESTE linhas %s" % [j._linhas(j.classe_base())])
	for n in 3:
		j._clique(Vector2(168, JanelaPersonagem.ALTURAS[a] + 9))
		await get_tree().create_timer(1.0).timeout
	print("TESTE janela depois: pontos %d %s vida_max %d mana_max %d" % [j.eu.pontos, [j.eu.forca, j.eu.agilidade, j.eu.vitalidade, j.eu.energia, j.eu.comando], barra_mu.vida_max, barra_mu.mana_max])


func _teste_desmontar() -> void:
	await get_tree().create_timer(3.0).timeout
	print("TESTE antes: slot 8 %s, montaria %s, acao %s" % [ItensMU.nome(inv.itens[8]) if inv.itens.has(8) else "-",
		eu.boneco.montaria != null, eu.boneco.acao])
	if not inv.itens.has(8):
		return
	var livre := inv.lugar_livre(inv.itens[8])
	var grade := ""
	for y in 8:
		for x in 8:
			grade += "#" if inv.item_na_casa(Vector2i(x, y)) >= 0 else "."
		grade += "/"
	print("TESTE livre %d grade %s" % [livre, grade])
	inv.usar_ou_equipar(8)
	await get_tree().create_timer(2.0).timeout
	print("TESTE tirou: slot 8 %s, montaria %s, acao %s" % [inv.itens.has(8), is_instance_valid(eu.boneco.montaria) and eu.boneco.montaria != null, eu.boneco.acao])
	for k in inv.itens:
		if k >= Inventario.MOCHILA and ItensMU.chave(inv.itens[k]) in Boneco.MONTARIAS:
			inv.usar_ou_equipar(k)
			break
	await get_tree().create_timer(2.0).timeout
	print("TESTE pos de volta: slot 8 %s, montaria %s, acao %s" % [inv.itens.has(8), eu.boneco.montaria != null, eu.boneco.acao])


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
