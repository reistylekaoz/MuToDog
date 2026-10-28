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
var painel: LoginCena
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
var master := {}       # F3 50 / 51: nivel, exp, exp_prox, pontos (vazio = nao e classe master)
var meu_zen := 0
var som: Som
var brilho := 2.0

# inventario e skills
var inv: Inventario
# loja do NPC, amigos (F) e menu (U)
var loja: Loja
var minimapa: Minimapa     # Tab
var dialogo: DialogoNPC     # conversa do NPC (Elf Soldier): C3 F9 01
var janela_quest: JanelaQuest   # quests de troca de classe (Sebina, Marlon, Devin): C1 A0 a A4
var quest_legado := QuestLegado.new()   # o estado delas (a lista chega antes do HUD)
var quest_nova := QuestNova.new()       # quests novas do S6 (F6): Elf Soldier
var janela_evento: JanelaEvento  # entrada do Devil Square (Charon) e do Blood Castle (Mensageiro): C1 90 e 9A
var eventos: Eventos           # contagem, tempo do Blood Castle e placar (C1 92, 93 e 9B)
var janela_duelo: JanelaDuelo  # placar do duelo (C1 AA)
var janela_templo: JanelaTemplo   # entrada do Illusion Temple pela Mirage (NPC janela 0x14)
var templo: Templo               # HUD do Illusion Temple (rodada 16)
var janela_doppel: JanelaDoppel   # entrada do Doppelganger pelo Lugard (NPC janela 0x23)
var doppel: Doppel               # moldura do Doppelganger (rodada 17)
var janela_imperial: JanelaImperial   # entrada do Imperial Fortress pelo Jerint (NPC janela 0x24)
var imperial: Imperial           # tempo e clima do Imperial Fortress (rodada 18)
var janela_kanturu: JanelaKanturu   # entrada da Torre do Kanturu pelo Gateway (C1 D1 00)
var janela_castelo: JanelaCastelo   # Guardsman e Senior do Castle Siege (rodada 21)
var cerco: GuerraCastelo            # minimapa, relogio e comandos da batalha do castelo (rodada 22)
var taxa_caos := 0                  # C1 B2 1A: imposto do castelo na maquina do caos e nas lojas
var taxa_loja := 0
var kanturu: Kanturu             # evento do Kanturu no mapa 39 (rodada 19)
var raklion: Raklion             # evento do Raklion, mapas 57 e 58 (rodada 20)
var crywolf: Crywolf             # evento de Crywolf no mapa 34 (rodada 20)
var _templo_fx := {}             # "id:o que" -> EfeitoMU preso em alguem (reliquia, skills 210 e 211)
var _templo_preso := false       # Restraint (211) em mim: nao anda ate o C1 BF 07
var _mirage_t := 0.0             # Mirage sem janela do servidor: o cliente abre a dele
var caos: ChaosCastle          # Chaos Castle: o castelo encolhe, buracos e armas do castelo (rodada 14)
var _caos_slot := -1           # a Armor of Guardsman do clique direito, esperando o C1 91
var _caos_mortes := {"monstros": 0, "jogadores": 0}   # o que eu matei no castelo (o OpenMU nao manda)
var janela_quest_nova: JanelaQuestNova  # o passo da quest no NPC: F6 0B e 0C
var janela_minhas_quests: JanelaMinhasQuests   # janela T
var janela_master: JanelaMaster                # janela A: arvore de skills master
var janela_buffs: JanelaBuffs                  # icones dos buffs em mim, no topo
var meu_heroi := 3
var monstros_vida := {}                        # numero -> [nivel, vida maxima] (ferramentas/monstros_vida.py)
var eu_skin := 0                               # monstro do anel de transformacao em mim (0 = eu mesmo)
var janela_grupo: JanelaGrupo                  # lista do grupo no canto da direita
var caixa_senha: CaixaSenha                     # teclado da senha do bau
var caixa_fruta: CaixaFruta                    # fruta: soma ou tira pontos
var guarda: Guarda          # bau e maquina do caos
var _janela_npc := 0        # tipo da janela que o servidor abriu (0 loja, 2 bau, 3 maquina do caos)
var amigos: JanelaAmigos                      # F: amigos, cartas e salas (rodada 10)
var correio: Correio                          # o mensageiro inteiro e a caixa de chat do Enter
var janela_guilda: JanelaGuilda               # janela G (rodada 7)
var criar_guilda: JanelaCriarGuilda           # aberta pelo Guild Master de Devias (C1 54)
var minha_guilda := -1                        # id da minha guilda (C2 65 com o meu id)
var meu_cargo_guilda := 255
var _guildas_pedidas := {}                    # ids que ja pedi no C1 66
var minha_gens := 0                           # F8 07: 1 Duprian, 2 Vanert (rodada 9)
var janela_gens: JanelaGens                   # tecla B
var pets: Pets                                # o corvo e o cavalo do Dark Lord (ordens, ficha, janela)
var borda_direita := -1.0                     # x da janela aberta mais a esquerda na direita (-1 = nenhuma)
var _gens_vistos := {}                        # id -> F8 05 de quem ainda nao entrou na tela
var guerra := {}                              # guerra ou Battle Soccer em curso: guilda, tipo, time, meu, dele (C1 62 e 64)
var placar: PlacarGuerra                      # placar de 131x70 acima da barra (rodada 8)
var _cacar_jogador := ""                      # roteiro A:Nome: ataca esse jogador sempre que der (teste da guerra)
var _chutar := false                          # roteiro F: leva a bola do Battle Soccer pro gol do meu time
var _bola_inicio := Vector2i(-1, -1)
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
const RAGE := [260, 261, 262, 265, 269]   # golpes do Rage Fighter: C3 4A (animacao pros outros) antes do C3 19
const EM_VOLTA := [264, 270, 41, 42, 9, 14, 235, 76, 236, 237, 62]   # skills de area em volta de quem solta
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
	monstros_vida = _json("res://dados/monstros_vida.json") if FileAccess.file_exists("res://dados/monstros_vida.json") else {}
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
	cli.morte.connect(_morte_caos)
	cli.mapa_mudou.connect(_mapa_mudou)
	cli.vida.connect(func(v): barra_mu.vida = v; _hud_nivel())
	cli.sd.connect(func(v): barra_mu.sd = v; _hud_nivel())
	cli.ag.connect(func(v): barra_mu.ag = v; _hud_nivel())
	cli.maximo.connect(func(q, v): barra_mu.set(q + "_max", maxi(v, 1)); _hud_nivel())
	cli.mensagem.connect(_msg)
	cli.mana.connect(func(v): barra_mu.mana = v; _hud_nivel())
	cli.experiencia.connect(_experiencia)
	cli.nivel.connect(_nivel)
	cli.master.connect(_master)
	cli.master_subiu.connect(_master_subiu)
	cli.master_skills.connect(func(l):
		print("TESTE master skills %s" % [l])
		janela_master.definir_classe(minha_classe)
		janela_master.lista(l)
		if _parametros().has("master_skills") and not _teste_master_comecou:
			_teste_master_comecou = true
			_teste_master(str(_parametros().master_skills).split(",", false)))
	cli.master_skill.connect(_master_skill)
	cli.ponto.connect(_ponto)
	cli.pedido_grupo.connect(func(id):
		var n: String = entidades[id].nome if entidades.has(id) else "Alguem"
		print("TESTE pedido de grupo de %s" % n)
		_perguntar("%s te chamou pro grupo." % n, func(ok): cli.responder_grupo(ok, id)))
	cli.grupo.connect(func(l):
		print("TESTE grupo %s" % [l.map(func(m): return "%s i%d %d/%d" % [m.nome, m.indice, m.vida, m.vida_max])])
		var antes: int = janela_grupo.membros.size()
		janela_grupo.meu_nome = meu_nome
		janela_grupo.definir(l)
		if antes == 0 and l.size() > 0:
			_msg("[color=#9ad0ff]Grupo: %s[/color]" % ", ".join(l.map(func(m): return m.nome))))
	cli.heroi.connect(func(id, estado):
		print("TESTE heroi %d = %d" % [id, estado])
		if id == cli.meu_id:
			if estado != meu_heroi:
				_msg("[color=#ff9a4a]%s[/color]" % DicaItem.t([487, 487, 487, 488, 489, 490, 491][clampi(estado, 0, 6)]))
			meu_heroi = estado
			if eu:
				eu.por_heroi(estado)
		elif entidades.has(id):
			entidades[id].por_heroi(estado))
	cli.bau_trava.connect(_bau_trava)
	# a janela da vida da invocacao (newui_Pet_Back, texto 356) fica pra quando um servidor mandar o F3 20
	cli.vida_invocacao.connect(func(v): print("TESTE vida da invocacao %d%%" % v))
	cli.rage_alvos.connect(func(sk, l):
		print("TESTE rage %d alvos %s" % [sk, l])
		for a in l:
			if entidades.has(a) and eu:
				EfeitoSkill.criar(mundo, sk, eu, entidades[a]))
	cli.grupo_saiu.connect(func():
		print("TESTE grupo: sai")
		if not janela_grupo.membros.is_empty():
			_msg("[color=#9ad0ff]%s[/color]" % DicaItem.t(502))
		janela_grupo.limpar())
	cli.grupo_vida.connect(func(l):
		print("TESTE grupo vida %s" % [l])
		janela_grupo.vidas(l))
	_ligar_guilda()
	_ligar_guilda2()
	_ligar_gens()
	_ligar_duelo()
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
	painel.mudar_volume(menu.vol_musica)
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
	else:
		# como o MU: abre ligado no connect server e mostra a escolha do servidor
		_conectar_lista()


var _andar_depois := Vector2i(-1, -1)
var _auto := false
var _cacar := 0      # testes: --cacar N mata N monstros sozinho (mira o mais perto, pega o que cair)
var _mortos := 0
var _cacar_t := 0.0
var _sem_modelo := {}  # monstro sem modelo ja avisado no log
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


# --roteiro "d:/item 14 9;p;u:14,9;e:5": passos com 2 s entre eles. d: diz no chat (comando de GM tambem),
# p: pega o item do chao mais perto, u:grupo,numero[,nivel]: usa o item da mochila, e:N: espera N s,
# f:1 ou f:2: Create ou Decrease na caixa da fruta, b: mostra os buffs (janela e boneco),
# x:12-50: larga no chao o que esta nesses slots, t: tira o que esta vestido, v: veste de volta,
# O: OK na caixa do MU aberta por cima, T:N: tira so o slot N
var _teste_tirados := []


# espera do roteiro: tocando gravacao, conta no relogio da fita (o navegador lento atrasa os timers e o roteiro
# saia do passo da gravacao); ao vivo conta no relogio de verdade (o timer anda pelo quadro, e no headless com
# muito monstro o quadro atrasa e o roteiro ficava 4 vezes mais lento)
func _esperar(s: float) -> void:
	var gravacao := Conexao.relogio() >= 0
	var agora := func() -> int: return Conexao.relogio() if gravacao else Time.get_ticks_msec()
	var fim: int = agora.call() + int(s * 1000.0)
	while agora.call() < fim:
		await get_tree().process_frame


func _teste_roteiro(passos: Array) -> void:
	for passo: String in passos:
		await _esperar(2.0)
		var a := passo.substr(2)
		match passo.substr(0, 1):
			"d":
				# o roteiro nao leva espaco: d:/war_Ursos diz "/war Ursos"
				a = a.replace("_", " ")
				print("TESTE roteiro diz %s (%d ms)" % [a, Time.get_ticks_msec()])
				if not comando_local(a):
					cli.dizer(meu_nome, a)
			"M":
				# mensageiro (rodada 10): M:diz,texto / M:carta,para,titulo,texto / M:ler,0 / M:sala,Nome ...
				await correio.roteiro(a.replace("_", " ").split(","))
			"T":
				# T:8 tira so o que esta nesse slot vestido pra mochila (o Fenrir barra a entrada nos eventos)
				var k := int(a)
				if inv.itens.has(k):
					var para := inv.lugar_livre(inv.itens[k])
					print("TESTE roteiro tira %s do %d pro %d" % [ItensMU.nome(inv.itens[k]), k, para])
					if para >= 0:
						inv._mandar(k, para)
			"O":
				# O: aperta OK na caixa do MU aberta por cima (a do Chaos Castle)
				var caixas := hud.get_children().filter(func(c): return c is CaixaMU)
				print("TESTE roteiro OK na caixa (%d abertas)" % caixas.size())
				if not caixas.is_empty():
					caixas[-1].responder(true)
			"F":
				_chutar = true
				print("TESTE roteiro chuta a bola pro gol")
			"o":
				# o:N escolhe a resposta N da conversa do NPC aberta
				print("TESTE roteiro responde %s" % a)
				dialogo.escolher(int(a) - 1)
			"B":
				_alternar_gens()
			"I":
				# I:sub,bytes em hex: pacote C1 BF do Illusion Temple montado aqui (o OpenMU nao tem o evento)
				# (EU vira o meu id em little endian; NOME o meu nome em 10 bytes). Vai pra fita como recebido;
				# tocando a fita, ela mesma entrega
				if Conexao.tocando():
					continue
				var pi := a.split(",")
				var pq := PackedByteArray([0xC1, 0, 0xBF, pi[0].hex_to_int()])
				if pi.size() > 1:
					var nb := meu_nome.to_utf8_buffer()
					nb.resize(10)
					pq.append_array(pi[1].replace("EU", "%02x%02x" % [cli.meu_id & 0xFF, cli.meu_id >> 8]).replace("NOME", nb.hex_encode()).hex_decode())
				pq[1] = pq.size()
				print("TESTE roteiro templo injeta BF %s (%d bytes)" % [pi[0], pq.size()])
				Conexao.anotar(pq)
				cli._ler_templo(pq, pq[3])
			"S":
				# S:skill,id usa a skill do templo nesse alvo como se fosse Shift + botao direito
				var ps := a.split(",")
				templo.skill = int(ps[0])
				_skill_templo(entidades.get(int(ps[1])) if ps.size() > 1 else null)
			"J":
				# J:0 Enter, J:1 Close na janela da Mirage
				janela_templo.clicar(int(a))
			"D":
				# D:0 Enter, D:1 Close na janela do Lugard
				janela_doppel.clicar(int(a))
			"Y":
				# Y:0 Enter, Y:1 Close na janela do Jerint
				janela_imperial.clicar(int(a))
			"Q":
				# Q:0 Refresh, Q:1 Enter, Q:2 Close na janela do Gateway do Kanturu
				janela_kanturu.clicar(int(a))
			"P":
				# P:C1,B214000102... monta o pacote (C1 ou C2, o tamanho e daqui) com o resto em hex e entrega como se
				# viesse do servidor: o que o OpenMU nao manda da batalha do castelo (rodada 22). EU (meu id, big endian), MEU (little endian) e NOME
				if Conexao.tocando():
					continue
				var pp := a.split(",")
				var nb2 := meu_nome.to_utf8_buffer()
				nb2.resize(10)
				var corpo := pp[1].replace("MEU", "%02x%02x" % [cli.meu_id & 0xFF, cli.meu_id >> 8]).replace("EU", "%02x%02x" % [cli.meu_id >> 8, cli.meu_id & 0xFF]).replace("NOME", nb2.hex_encode()).hex_decode()
				var pk := PackedByteArray([0xC1, 0]) if pp[0] == "C1" else PackedByteArray([0xC2, 0, 0])
				pk.append_array(corpo)
				if pp[0] == "C1":
					pk[1] = pk.size()
				else:
					pk[1] = pk.size() >> 8
					pk[2] = pk.size() & 0xFF
				print("TESTE roteiro injeta %s (%d bytes)" % [pk.slice(0, mini(pk.size(), 6)).hex_encode(), pk.size()])
				Conexao.anotar(pk)
				cli._tratar(pk)
			"G":
				# G:g2 grupo 3, G:c0 comando ataque, G:m64x40 ponto do minimapa (0 a 128), G:a transparencia, G:e escala
				var gp := a.substr(1)
				match a.substr(0, 1):
					"g": cerco.clicar(cerco._grupo_r(int(gp)).get_center())
					"c": cerco.clicar(cerco._cmd_r(int(gp)).get_center())
					"m":
						var gxy := gp.split("x")
						cerco.clicar(cerco._mapa_pos() + Vector2(float(gxy[0]), float(gxy[1])))
					"a": cerco.clicar(cerco.moldura() + Vector2(60, 8))
					"e": cerco.clicar(cerco.moldura() + Vector2(138, 10))
			"U":
				# U:0,500 clica no + da forca (0 forca ... 4 comando) e responde 500 na caixa de quantos
				var ua := a.split(",")
				if not janela_personagem.visible:
					_botao_barra("personagem")
				janela_personagem._clique(Vector2(168, JanelaPersonagem.ALTURAS[int(ua[0])] + 9))
				print("TESTE roteiro + do atributo %s, caixa %s" % [ua[0], is_instance_valid(_caixa_pontos)])
				if is_instance_valid(_caixa_pontos):
					_caixa_pontos._campo.text = ua[1] if ua.size() > 1 else "1"
					_caixa_pontos.responder(true)
			"H":
				# loja de cash: H:x e a tecla X, H:330x139 clica nesse ponto da loja (640 x 429),
				# H:n,nome,mensagem preenche os campos do presente, H:s mostra o que a loja tem agora
				if a == "x":
					print("TESTE roteiro tecla X")
					_alternar_loja_cash()
				elif a.begins_with("n,"):
					var hn := a.split(",")
					loja_cash._nome.text = hn[1]
					loja_cash._msg.text = hn[2].replace("_", " ") if hn.size() > 2 else ""
					print("TESTE roteiro presente para %s" % hn[1])
				elif a.begins_with("c,"):
					# H:c,Nome do pacote,N compra o pacote pelo N-esimo preco (0 = o primeiro), sem clicar
					var hc := a.split(",")
					for pk: Dictionary in LojaCash.carregar().pacotes:
						if pk.nome == hc[1].replace("_", " ") and pk.venda:
							var ps := int(pk.precos[int(hc[2]) if hc.size() > 2 else 0])
							print("TESTE roteiro compra %s preco %d" % [pk.nome, ps])
							loja_cash.comprar.emit(int(pk.seq), int(pk.cat), ps, int(pk.item), int(pk.moeda))
							break
				elif a.begins_with("u,"):
					# H:u,N usa o N-esimo item do deposito (0 = o primeiro), sem clicar
					var hu := int(a.split(",")[1])
					if hu >= loja_cash.deposito.size():
						print("TESTE roteiro usa do deposito: nada no %d" % hu)
					else:
						var it: Dictionary = loja_cash.deposito[hu]
						print("TESTE roteiro usa do deposito %s" % it.nome)
						loja_cash.usar.emit(int(it.indice), int(it.preco_seq), maxi(0, int(it.item)), int(it.tipo))
				elif a == "s":
					print("TESTE loja estado aberta %s caixa %s saldo %s deposito %s" % [loja_cash.visible, loja_cash.caixa.get("tipo", "-"),
						loja_cash.saldo, loja_cash.deposito.map(func(i): return "%d %s %s" % [i.indice, i.nome, i.duracao])])
					print("TESTE loja mochila %s" % [inv.itens.values().map(func(it): return "%s +%d" % [ItensMU.nome(it), it.nivel])])
				else:
					var hxy := a.split("x")
					print("TESTE roteiro clica na loja %s" % a)
					loja_cash.clicar(Vector2(float(hxy[0]), float(hxy[1])))
			"C":
				# C:95x131 clica nesse ponto da janela do castelo (coordenadas da janela de 190 x 429)
				var xy := a.split("x")
				janela_castelo.clicar(Vector2(float(xy[0]), float(xy[1])))
			"Z":
				# rodada 25: Z:gate,95x110 e Z:arqueiro,90x295 clicam nessas janelas (190 x 429), Z:gate,x fecha; Z:j abre a janela J,
				# Z:j,/help escolhe esse comando, Z:jx aperta Execute; Z:teclas guarda a configuracao (F3 30); Z:foco manda o F3 15
				var z := a.split(",")
				print("TESTE roteiro %s" % a)
				match z[0]:
					"gate", "arqueiro":
						var zj: PainelLateral = janela_gatekeeper if z[0] == "gate" else janela_arqueiro
						if z[1] == "x":
							zj.fechar()
						else:
							var zxy := z[1].split("x")
							zj._clique(Vector2(float(zxy[0]), float(zxy[1])))
							zj.queue_redraw()
					"j":
						if z.size() > 1:
							# Z:j,/help escolhe pelo nome
							for zl in chat_comandos.ordem.size():
								if chat_comandos._cmd(zl).comando == z[1]:
									chat_comandos._escolher(zl)
									chat_comandos.queue_redraw()
						else:
							chat_comandos.abrir()
					"jx":
						chat_comandos._executar()
						chat_comandos.queue_redraw()
					"teclas":
						_guardar_teclas()
					"foco":
						cli.foco_personagem(meu_nome)
			"W":
				# W:3 diz /crywolf ate o Crywolf chegar nesse estado (o servidor guarda o estado da volta anterior)
				for i in 8:
					if crywolf.estado == int(a):
						break
					print("TESTE roteiro diz /crywolf (estado %d, quer %s)" % [crywolf.estado, a])
					cli.dizer(meu_nome, "/crywolf")
					await _esperar(4.0)
			"N":
				# N:numero fala com o NPC do templo desse numero (o mais perto)
				for e: Entidade in entidades.values():
					if e.tipo == "npc" and e.numero == int(a):
						falar_com(e.id)
						break
			"A":
				_cacar_jogador = a.replace("_", " ")
				print("TESTE roteiro ataca o jogador %s sempre que der" % a)
			"p":
				var perto: ItemChao = null
				for it: ItemChao in itens.values():
					if perto == null or _distancia(eu.tile, it.tile) < _distancia(eu.tile, perto.tile):
						perto = it
				print("TESTE roteiro pega %s" % (perto.nome if perto else "nada"))
				if perto:
					item_alvo = perto.id
			"u":
				var v := a.split(",")
				var s := -1
				for k in inv.itens:
					var it: Dictionary = inv.itens[k]
					if k >= Inventario.MOCHILA and it.grupo == int(v[0]) and it.numero == int(v[1]) and (v.size() < 3 or it.nivel == int(v[2])):
						s = k
						break
				print("TESTE roteiro usa %s no slot %d" % [ItensMU.nome(inv.itens[s]) if s >= 0 else a, s])
				if s >= 0:
					inv.usar_ou_equipar(s)
			"e":
				await _esperar(float(a))
			"L":
				# L:14,28: larga no chao o primeiro item da mochila com esse grupo e numero (o Lost Map abre o portao)
				var v := a.split(",")
				for k in inv.itens:
					var it: Dictionary = inv.itens[k]
					if k >= Inventario.MOCHILA and it.grupo == int(v[0]) and it.numero == int(v[1]):
						print("TESTE roteiro larga %s do slot %d em %s" % [ItensMU.nome(it), k, eu.tile])
						cli.largar_item(eu.tile.x, eu.tile.y, k)
						break
			"x":
				# x:12-50: larga no chao o que estiver nesses slots da mochila (lixo de teste do GM)
				var f := a.split("-")
				for k in range(int(f[0]), int(f[1]) + 1):
					if inv.itens.has(k):
						cli.largar_item(eu.tile.x, eu.tile.y, k)
						await get_tree().create_timer(0.3).timeout
				print("TESTE roteiro largou %s" % a)
			"t", "v":
				# t: tira tudo que esta vestido pra mochila; v: veste de volta
				if passo == "t":
					_teste_tirados.clear()
					for k in inv.itens.keys():
						if k < Inventario.MOCHILA:
							var para := inv.lugar_livre(inv.itens[k])
							print("TESTE roteiro tira %s do %d pro %d" % [ItensMU.nome(inv.itens[k]), k, para])
							if para >= 0:
								_teste_tirados.append([k, para])
								inv._mandar(k, para)
								await get_tree().create_timer(0.5).timeout
				else:
					for x in _teste_tirados:
						if inv.itens.has(x[1]):
							inv._mandar(x[1], x[0])
							await get_tree().create_timer(0.5).timeout
				print("TESTE roteiro %s: vestidos agora %s" % [passo, inv.itens.keys().filter(func(k): return k < Inventario.MOCHILA)])
			"f":
				print("TESTE roteiro fruta: %s (%s)" % [DicaItem.t(CaixaFruta.BOTOES[int(a) - 1]), caixa_fruta.titulo()])
				caixa_fruta.escolher(int(a) - 1)
			"j":
				# j:g,n:slot_alvo (ou j:g,n:g2,n2) usa a joia (grupo,numero) da mochila no item desse slot
				var v := a.split(":")
				var g := v[0].split(",")
				var s := -1
				for k in inv.itens:
					if k >= Inventario.MOCHILA and inv.itens[k].grupo == int(g[0]) and inv.itens[k].numero == int(g[1]):
						s = k
						break
				var alvo := int(v[1])
				if "," in v[1]:   # j:14,13:0,0 = no primeiro item 0,0 da mochila
					var h := v[1].split(",")
					for k in inv.itens:
						if k >= Inventario.MOCHILA and inv.itens[k].grupo == int(h[0]) and inv.itens[k].numero == int(h[1]):
							alvo = k
							break
				print("TESTE roteiro joia slot %d em %s (slot %d)" % [s, ItensMU.nome(inv.itens[alvo]) if inv.itens.has(alvo) else "nada", alvo])
				if s >= 0:
					inv._usar_em(s, alvo)
			"g":
				# g:Nome chama pro grupo; g:-Nome tira do grupo (o lider tira os outros, cada um tira a si mesmo)
				var tira := a.begins_with("-")
				var n := a.trim_prefix("-")
				if tira:
					for m: Dictionary in janela_grupo.membros:
						if m.nome == n:
							print("TESTE roteiro tira %s (indice %d) do grupo" % [n, m.indice])
							janela_grupo.tirar.emit(m.indice)
				else:
					for e: Entidade in entidades.values():
						if e.nome == n:
							print("TESTE roteiro chama %s pro grupo" % n)
							cli.chamar_grupo(e.id)
			"m":
				# m:de-para move um item (slots do inventario)
				var f := a.split("-")
				print("TESTE roteiro move %s" % a)
				inv._mandar(int(f[0]), int(f[1]))
			"k":
				# k:pedido,senha[,senha da conta] digita no teclado do bau como quem clica
				var v := a.split(",")
				caixa_senha.abrir(int(v[0]))
				print("TESTE roteiro teclado: %s" % caixa_senha.titulo())
				for vez in (2 if v[0] == "1" else (1 if v[0] == "0" else 0)):
					for c in v[1]:
						caixa_senha.digito(int(c))
					caixa_senha._ok()
				if v.size() > 2:
					print("TESTE roteiro teclado: %s" % caixa_senha.titulo())
					caixa_senha._conta.text = v[2]
					caixa_senha._ok()
			"G":
				_teste_guilda(a.split(","))
			"n":
				for e: Entidade in entidades.values():
					if e.tipo == "npc" and (e.nome.containsn(a) or str(e.numero) == a):
						print("TESTE roteiro fala com %s" % e.nome)
						falar_com(e.id)
						break
			"w":
				var v := a.split(",")
				print("TESTE roteiro anda ate %s" % a)
				andar_ate(Vector2i(int(v[0]), int(v[1])))
			"c":
				print("TESTE roteiro fecha a janela do npc")
				_fechar_loja()
			"r":
				# r: pede o primeiro item do bau mesmo trancado (o servidor tem que recusar)
				if not guarda.itens.is_empty():
					var k: int = guarda.itens.keys()[0]
					print("TESTE roteiro tira do bau o slot %d (%s)" % [k, ItensMU.nome(guarda.itens[k])])
					guarda.esperando = k
					guarda.retirar.emit(k)
			"i":
				print("TESTE roteiro mochila: %s" % [inv.itens.keys().map(func(k): return "%d %s +%d" % [k, ItensMU.nome(inv.itens[k]), inv.itens[k].nivel])])
			"P":
				# pets (rodada 11): P:0 a P:3 manda a ordem (a 3 no monstro mais perto), P:j abre a janela do pet,
				# P:a0 ou P:a1 escolhe a aba (cavalo, corvo), P:i mostra as fichas vestidas
				if a == "j":
					_alternar_pet()
				elif a.begins_with("a"):
					pets.janela.aba = int(a.substr(1))
					print("TESTE roteiro pet aba %d" % pets.janela.aba)
				elif a == "i":
					print("TESTE roteiro pets vestidos %s comando %d" % [Pets.vestidos, pets.comando])
				else:
					var perto: Entidade = null
					for e: Entidade in entidades.values():
						if e.tipo == "monstro" and not e.morto and (perto == null or _distancia(eu.tile, e.tile) < _distancia(eu.tile, perto.tile)):
							perto = e
					print("TESTE roteiro ordem do corvo %s em %s" % [a, perto.nome if perto else "-"])
					pets.mandar(Pets.COMANDO + int(a), perto)
			"K":
				# K:N caca N monstros a partir daqui (dentro do evento)
				_cacar = int(a)
				_mortos = 0
				print("TESTE roteiro caca %d" % _cacar)
			"b":
				print("TESTE roteiro buffs na janela: %s" % [janela_buffs.lista().map(func(x): return "%d %s %s" % [x, JanelaBuffs.nome(x),
					JanelaBuffs.tempo(maxi((janela_buffs.buffs.get(x, 0) - Time.get_ticks_msec()) / 1000, 0)) if janela_buffs.buffs.get(x, 0) > 0 else "-"])])
				print("TESTE roteiro buffs no meu boneco: %s" % [eu.buffs.keys()])


# C1 83: estado da senha do bau (vem ao abrir e como resposta de cada pedido)
func _bau_trava(estado: int) -> void:
	print("TESTE bau trava %d" % estado)
	match estado:
		0:
			guarda.trancado = false
			guarda.tem_senha = false
		1:
			guarda.trancado = true
			guarda.tem_senha = true
		12:
			guarda.trancado = false
			guarda.tem_senha = true
	var t: Dictionary = {10: 440, 11: 441, 13: 401}
	if t.has(estado):
		_msg("[color=#e8b04a]%s[/color]" % DicaItem.t(t[estado]))
	elif estado == 12:
		_msg("[color=#9ad0ff]Bau destrancado.[/color]")
	guarda.queue_redraw()


# F3 14: a joia mexeu no item; o servidor nao diz se deu certo, entao compara com o que era
func _item_melhorado(slot: int, it: Dictionary) -> void:
	var antes: Dictionary = inv.itens.get(slot, {})
	inv.entrou(slot, it)
	_som("joia")
	var nome := ItensMU.nome(it)
	var t := ""
	if antes.is_empty():
		t = nome
	elif it.nivel > antes.nivel or it.opcao > antes.opcao:
		t = "[color=#7fd0ff]%s: deu certo, agora +%d%s.[/color]" % [nome, it.nivel, " com opcao +%d" % (it.opcao * 4) if it.opcao > antes.opcao else ""]
	elif it.nivel < antes.nivel or it.opcao < antes.opcao:
		t = "[color=#ff7050]%s: a joia falhou, ficou +%d.[/color]" % [nome, it.nivel]
	else:
		t = "%s: nada mudou." % nome
	print("TESTE item melhorado slot %d: +%d opt %d -> +%d opt %d" % [slot, antes.get("nivel", -1), antes.get("opcao", -1), it.nivel, it.opcao])
	_msg(t)


# --ver_monstros 3,15: lista os monstros vistos (id e tile) nesses segundos depois de entrar (spots do servidor)
func _teste_ver_monstros(segundos: Array) -> void:
	var antes := 0.0
	for t in segundos:
		await get_tree().create_timer(float(t) - antes).timeout
		antes = float(t)
		var l := []
		for e: Entidade in entidades.values():
			if e.tipo == "monstro":
				l.append("%s %d %s" % [e.nome, e.id, e.tile])
			elif e.tipo != "eu":
				l.append("(%s %d) %s %d %s" % [e.tipo, e.numero, e.nome, e.id, e.tile])
		l.sort()
		print("TESTE monstros em %ss: %d" % [t, l.size()])
		for x in l:
			print("TESTE   %s" % x)


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

	# tela de login do S6 (World74 com a camera passeando, logo e a janela da conta)
	painel = LoginCena.new()
	painel.palco = self
	raiz.add_child(painel)
	campo_host = painel.campo_host
	campo_porta = painel.campo_porta
	campo_host.text = "127.127.127.127"
	campo_porta.text = "44405"
	campo_conta = painel.campo_conta
	campo_conta.text = "test0"
	campo_senha = painel.campo_senha
	campo_conta.text_submitted.connect(func(_t): campo_senha.grab_focus())
	campo_senha.text_submitted.connect(func(_t): _entrar())
	botao_entrar = painel.botao
	painel.ok.connect(_entrar)
	painel.servidor.connect(func(id: int):
		aviso.text = ""
		cli.pedir_servidor(id))
	painel.pedir_lista.connect(func(): cli.pedir_lista_servidores())
	painel.cancelou.connect(func(): _voltar(""))
	aviso = painel.aviso
	aviso.text = "No Docker do OpenMU as contas de teste sao test0 a test9 (senha igual ao nome)."
	lista = painel.lista

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
	ajuda.text = "Clique: anda, ataca, pega, fala com NPC · botao direito: skill · 1 a 5 troca a skill · Q W E R pocoes · I inventario · C personagem · F amigos · G guilda · U menu · setas giram · roda aproxima · M mover de mapa · S loja pessoal · Z MU Helper (Home liga) · - = brilho"
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
	janela_buffs = JanelaBuffs.new()
	hud.add_child(janela_buffs)
	janela_grupo = JanelaGrupo.new()
	janela_grupo.mapas = mapas
	janela_grupo.tirar.connect(func(i):
		print("TESTE grupo tirar indice %d" % i)
		cli.tirar_do_grupo(i))
	hud.add_child(janela_grupo)
	inv = Inventario.new()
	inv.aviso.connect(func(t): _msg("[color=#e8b04a]%s[/color]" % t))
	inv.mover.connect(func(de, para):
		if inv.itens.has(de):
			cli.mover_item(de, para, inv.itens[de].bytes))
	inv.usar.connect(func(slot, alvo): cli.usar_item(slot, alvo))
	hud.add_child(inv)
	caixa_senha = CaixaSenha.new()
	caixa_senha.pronto.connect(func(sub, pin, senha):
		print("TESTE senha do bau: pedido %d" % sub)
		cli.senha_bau(sub, pin, senha))
	hud.add_child(caixa_senha)
	caixa_fruta = CaixaFruta.new()
	caixa_fruta.escolheu.connect(func(slot, uso):
		print("TESTE fruta slot %d uso %d" % [slot, uso])
		# o OpenMU recusa com qualquer item vestido e nao responde (PreventedByEquippedItems sem pacote): avisa aqui
		if inv.itens.keys().any(func(k): return k < Inventario.MOCHILA):
			print("TESTE fruta recusada: item vestido")
			_msg("[color=#e8b04a]%s[/color]" % DicaItem.t(1909 if uso == 1 else 1908))
			return
		cli.usar_item(slot, 0, uso))
	inv.fruta.connect(func(slot):
		print("TESTE caixa da fruta %s" % ItensMU.nome(inv.itens[slot]))
		caixa_fruta.abrir(slot, int(inv.itens[slot].get("nivel", 0))))
	hud.add_child(caixa_fruta)
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
		elif r == 903 or r == 904:
			cli.gens_entrar(r - 902)
		elif r == 905:
			cli.gens_sair()
		elif r == 906 or r == 907:
			cli.gens_pedir_premio(r - 905)
		elif r == 901:
			cli.quests_disponiveis()
		else:
			_msg("[color=#9a9ab0]As quests desse NPC ainda nao foram feitas neste cliente.[/color]"))
	dialogo.fechar.connect(_fechar_loja)
	hud.add_child(dialogo)
	janela_quest = JanelaQuest.new()
	janela_quest.q = quest_legado
	janela_quest.monstros = monstros
	janela_quest.pedir.connect(func(qq, e):
		print("TESTE quest pedido %d estado %d" % [qq, e])
		cli.quest_estado(qq, e))
	janela_quest.fechar.connect(_fechar_loja)
	hud.add_child(janela_quest)
	janela_evento = JanelaEvento.new()
	janela_evento.entrar.connect(func(n):
		print("TESTE evento entrar %s %d" % [janela_evento.modo, n])
		if janela_evento.modo == "ds":
			cli.entrar_devil(n)
		else:
			cli.entrar_blood(n))
	janela_evento.fechar.connect(_fechar_loja)
	hud.add_child(janela_evento)
	eventos = Eventos.new()
	hud.add_child(eventos)
	janela_duelo = JanelaDuelo.new()
	hud.add_child(janela_duelo)
	_ligar_templo()
	_ligar_doppel()
	_ligar_imperial()
	_ligar_kanturu()
	_ligar_castelo()
	_ligar_rodada25()
	_ligar_loja_cash()
	caos = ChaosCastle.new()
	add_child(caos)
	eventos.estagio.connect(func(n): caos.encolher(n))
	inv.armadura_caos.connect(_armadura_caos)
	quest_nova.monstros = monstros
	dialogo.quest_nova = quest_nova
	dialogo.quest_escolhida.connect(func(n, g, l): cli.quest_escolher(n, g, l))
	janela_quest_nova = JanelaQuestNova.new()
	janela_quest_nova.q = quest_nova
	janela_quest_nova.responder.connect(func(i, r):
		print("TESTE quest nova %x resposta %d" % [i, r])
		cli.quest_seguir(i & 0xFFFF, i >> 16, r))
	janela_quest_nova.concluir.connect(func(i):
		print("TESTE quest nova %x concluir" % i)
		cli.quest_concluir(i & 0xFFFF, i >> 16))
	janela_quest_nova.fechar.connect(_fechar_loja)
	hud.add_child(janela_quest_nova)
	janela_minhas_quests = JanelaMinhasQuests.new()
	janela_minhas_quests.q = quest_nova
	janela_minhas_quests.legado = quest_legado
	janela_minhas_quests.pedir_estado.connect(func(i): cli.quest_pedir_estado(i & 0xFFFF, i >> 16))
	janela_minhas_quests.abrir_quest.connect(func(i):
		janela_quest_nova.npc = ""
		janela_quest_nova.jogador = meu_nome
		janela_quest_nova.abrir(i))
	janela_minhas_quests.desistir.connect(func(i):
		print("TESTE quest nova %x desistir" % i)
		cli.quest_desistir(i & 0xFFFF, i >> 16))
	hud.add_child(janela_minhas_quests)
	janela_master = JanelaMaster.new()
	janela_master.minhas_skills = minhas_skills
	janela_master.exp_do_master = exp_do_master
	janela_master.aprender.connect(func(s):
		print("TESTE master aprender %d" % s)
		cli.subir_master(s))
	hud.add_child(janela_master)
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
	guarda.cadeado.connect(func():
		# trancado: destranca; sem senha: cria; destrancado com senha: tira a senha (pede a da conta)
		caixa_senha.abrir(0 if guarda.trancado else (2 if guarda.tem_senha else 1)))
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
	correio = Correio.new(self, cli, hud)
	add_child(correio)
	amigos = correio.amigos
	janela_guilda = JanelaGuilda.new()
	janela_guilda.sair.connect(_sair_da_guilda)
	janela_guilda.acao_membro.connect(_acao_membro_guilda)
	janela_guilda.pedir_alianca.connect(cli.pedir_alianca)
	janela_guilda.tirar_alianca.connect(_tirar_da_alianca)
	janela_guilda.sair_alianca.connect(_sair_da_alianca)
	hud.add_child(janela_guilda)
	placar = PlacarGuerra.new()
	hud.add_child(placar)
	janela_gens = JanelaGens.new()
	hud.add_child(janela_gens)
	pets = Pets.new(self, cli, hud)
	add_child(pets)
	criar_guilda = JanelaCriarGuilda.new()
	criar_guilda.responder_mestre.connect(func(sim):
		print("TESTE guilda: resposta ao Guild Master %s" % sim)
		cli.responder_mestre_guilda(sim))
	criar_guilda.criar.connect(func(n, m):
		print("TESTE guilda: criando %s" % n)
		cli.criar_guilda(n, m))
	criar_guilda.avisar.connect(func(t):
		print("TESTE guilda aviso: %s" % t)
		_caixa_mu([t], func(_ok, _t): pass, false, false))
	hud.add_child(criar_guilda)
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
	janela_personagem.quantos.connect(_pontos_quantos)
	janela_personagem.abrir_quests.connect(func(): if not janela_minhas_quests.visible: janela_minhas_quests.alternar())
	janela_personagem.abrir_master.connect(_alternar_master)
	janela_personagem.abrir_pet.connect(_alternar_pet)
	hud.add_child(janela_personagem)
	inv.visibility_changed.connect(janela_personagem._ajustar)
	# a janela do pet vive junto da C e no lugar da mochila
	pets.janela.inventario = inv
	janela_personagem.visibility_changed.connect(func(): if not janela_personagem.visible: pets.janela.visible = false)
	inv.visibility_changed.connect(func(): if inv.visible: pets.janela.visible = false)
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
	var direita: Array[Control] = [inv, loja, dialogo, janela_quest, janela_evento, janela_quest_nova, janela_minhas_quests, guarda, janela_personagem, comandos, troca, loja_pessoal, janela_helper, pets.janela]
	var mover_sair := func():
		var x := hud.size.x
		for j in direita:
			if j.visible:
				x = minf(x, j.position.x)
		borda_direita = x
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
	# aberto pelo launcher: o servidor e o do site (Conexao usa MU_SITE)
	if OS.get_environment("MU_SITE") != "":
		campo_host.text = OS.get_environment("MU_SITE")
		campo_host.editable = false
		campo_porta.text = "44405"


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
	if _auto:
		cli.conectar(campo_host.text.strip_edges(), int(campo_porta.text))


# CLoginWin::ConnectConnectionServer: liga (de novo) no connect server; a lista traz a escolha
func _conectar_lista() -> void:
	cli.usuario = ""
	cli.senha = ""
	painel.modo = "servidores"
	painel.grupos = []
	painel._ajustar()
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
		# o MU avisa e deixa tentar de novo na mesma conexao
		aviso.text = "Login recusado: %s." % t
		botao_entrar.disabled = false
		cli.usuario = ""
		cli.estado = "esperando_login"
	elif e == "esperando_login" and not _auto:
		painel.mostrar_login()
		aviso.text = ""
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
	if _auto:
		return
	# volta pra escolha do servidor; sem o OpenMU no ar tenta de novo a cada 5 s
	if cli.estado == "erro":
		await get_tree().create_timer(5.0).timeout
		if not painel.visible or cli.estado != "erro":
			return
	_conectar_lista()


func _servidores(l: Array) -> void:
	_limpar_lista()
	if _auto:
		var g := LoginCena.montar_grupos(l, painel._script_grupos, painel._textos)
		painel.servidor_nome = g[0].servidores[0].login if g.size() > 0 else "[OpenMU-%d Server]" % (l[0].id + 1)
		cli.pedir_servidor(l[0].id)
		return
	print("TESTE servidores %s" % [l])
	if aviso.text == "Pedindo a lista de servidores...":
		aviso.text = ""
	painel.mostrar_servidores(l)


func _personagens(l: Array) -> void:
	_limpar_lista()
	for p in l:
		_classe_de[p.nome] = [p.classe, p.nivel]
	for p in l:
		if meu_nome != "" and p.nome == meu_nome:
			# como o clique na selecao: o F3 15 antes de entrar (o servidor so responde ainda na selecao)
			cli.foco_personagem(p.nome)
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
	eu_skin = 0
	meu_nivel = _classe_de.get(nome, [0, 1])[1]
	_limpar_lista()
	cli.escolher(nome)


# --- mundo -------------------------------------------------------------------

func _entrou(info: Dictionary) -> void:
	meu_heroi = info.get("heroi", 3)
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
	cli.pedir_quests()
	if not _pediu_comandos:
		_pediu_comandos = true
		cli.pedir_comandos_chat()
	Conexao.segurar(true)   # gravacao: a fita espera o mapa carregar, pro roteiro andar junto com ela
	await _abrir_mapa(info.mapa, info.x, info.y)
	Conexao.segurar(false)
	_msg("Entrou em %s (%d, %d)." % [mapas.get(str(info.mapa), "mapa %d" % info.mapa), info.x, info.y])
	print("TESTE entrou %s" % info)
	if _parametros().has("chao_teste"):
		_chao_teste(info.x, info.y)
	if _parametros().has("uma_skill"):
		_teste_uma_skill(int(_parametros().uma_skill))
	if _parametros().has("roteiro"):
		_teste_roteiro(str(_parametros().roteiro).split(";"))
	if _parametros().has("ver_monstros"):
		_teste_ver_monstros(str(_parametros().ver_monstros).split(","))
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
	if _parametros().has("foco_tab"):
		_teste_foco_tab()
	if _parametros().has("dialogo_teste"):
		dialogo.abrir(int(_parametros().dialogo_teste), "Elf Soldier")
	if _parametros().has("efeito_teste"):
		_efeito_teste(str(_parametros().efeito_teste).split(",", false))
	if _parametros().has("buff_teste"):
		_buff_teste(str(_parametros().buff_teste).split(",", false))
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
	if templo:
		templo.mapa(mapa)
		_templo_preso = false
	if doppel:
		doppel.mapa(mapa)
		# a musica e os sons do evento vem no pacote dos monstros dos eventos
		if Doppel.no_doppel(mapa) and PacoteMapa.precisa_monstros():
			PacoteMapa.carregar(self, PacoteMapa.MONSTROS)
	if kanturu:
		kanturu.mapa(mapa)
	if raklion:
		raklion.mapa(mapa)
	if crywolf:
		crywolf.mapa(mapa)
	if imperial:
		imperial.mapa(mapa)
		# a musica, os sons do clima e a chuva vem no pacote dos eventos: o F7 02 (clima) espera ele
		if Imperial.no_imperial(mapa) and PacoteMapa.precisa_monstros():
			cli.segurar = true
			await PacoteMapa.carregar(self, PacoteMapa.MONSTROS)
			cli.segurar = false
			if mapa_atual != mapa:
				return
	# navegador: Lost Tower e Atlans vem num pacote a parte; a rede espera ele baixar
	if PacoteMapa.precisa(PacoteMapa.mundo_do_mapa(mapa)):
		_msg("Carregando %s..." % mapas.get(str(mapa), "o mapa"))
		cli.segurar = true
		await PacoteMapa.carregar(self, PacoteMapa.mundo_do_mapa(mapa))
		cli.segurar = false
		if mapa_atual != mapa:
			return
	mundo = Node3D.new()
	mundo.set_script(load("res://scripts/mundo.gd"))
	mundo.modo_jogo = true
	mundo.numero = PacoteMapa.mundo_do_mapa(mapa)
	eventos.em_castelo = mapa in [11, 12, 13, 14, 15, 16, 17, 52]
	# Chaos Castle: armas do castelo em todo mundo (o eu e quem aparecer) e o vento dele (aChaos)
	var era_caos := eventos.caos
	eventos.caos = ChaosCastle.e_caos(mapa)
	Boneco.no_caos = eventos.caos
	if eventos.caos:
		_caos_mortes = {"monstros": 0, "jogadores": 0}
		if som:
			som.laco("achaos")
	elif era_caos and som:
		som.parar_laco()
	janela_evento.visible = false   # o servidor leva pro evento sem mandar o C1 90 de volta
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
	caos.entrar(mundo, mapa)
	if imperial:
		imperial.ambiente = mundo.ambiente
	if kanturu:
		kanturu.mapa(mapa, mundo)
	if raklion:
		raklion.mapa(mapa, mundo)
	if crywolf:
		crywolf.mapa(mapa, mundo)
		# o cliente pede o estado ao entrar no mapa (ReceiveJoinMapServer e ReceiveTeleport)
		if mapa == Crywolf.MAPA and cli:
			cli.crywolf_pedir_info()
	# GMBattleCastle Init: no Valley of Loren o cliente pede a marca da guilda dona pras bandeiras (C1 B9 02)
	if mapa == MAPA_CASTELO and cli:
		cli.pedir_marca_castelo()
		if not _marca_castelo.is_empty():
			mundo.marca_castelo(_marca_castelo)
	Bichos.som = som
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
	eu.por_heroi(meu_heroi)
	eu.guilda = minha_guilda
	eu.guilda_cargo = meu_cargo_guilda
	eu.marca_guilda()
	if eu_skin:
		eu.trocar_boneco(Boneco.do_npc(eu_skin))
	if janela_buffs:
		for b: int in janela_buffs.buffs:
			eu.buff(b, true)
	# chegou em cima de um portal (saida de outro): so conta depois de sair dele
	var g := mover_janela.portal_em(mapa, x, y)
	_portal_pisado = int(g[0]) if not g.is_empty() else -1


func _objeto_entrou(o: Dictionary) -> void:
	if mundo == null:
		return
	if o.id == cli.meu_id:
		for x in o.get("efeitos", []):
			_efeito(true, o.id, x)
		meu_heroi = o.get("heroi", meu_heroi)
		if eu:
			eu.por_heroi(meu_heroi)
			# C2 45 pra mim: virei monstro (anel); C2 12 pra mim depois disso: voltei
			var skin: int = o.get("skin", 0)
			if skin != eu_skin:
				print("TESTE eu transformado em %d" % skin)
				eu_skin = skin
				eu.trocar_boneco(Boneco.do_npc(skin) if skin else Boneco.da_classe(minha_classe))
				if not skin:
					_vestir_eu()
		return
	if entidades.has(o.id):
		entidades[o.id].queue_free()
	var tipo := "jogador"
	var nome: String = o.get("nome", "")
	if o.tipo == "npc":
		var m: Array = monstros.get(str(o.numero), ["#%d" % o.numero, 0])
		nome = m[0]
		tipo = ["monstro", "npc", "guarda"][m[1]] if int(m[1]) < 3 else "outro"
		# o MuMain (DetermineMonsterObjectKind) faz de 201 a 259 KIND_NPC: o Gatekeeper (220) e os guardas de Lorencia falam
		if tipo == "guarda" and o.numero > 200 and o.numero < 260:
			tipo = "npc"
		if str(o.get("dono", "")) != "":
			tipo = "invocado"   # bicho de alguem (elfa, Dark Lord): nao e alvo
	# monstro de evento no navegador: entra de boneco provisorio e e refeito quando o pacote chega
	if o.tipo == "npc" and PacoteMapa.falta_monstro(o.numero):
		_esperando_pacote[o.id] = o
		if _esperando_pacote.size() == 1:
			_baixar_monstros()
	var e := Entidade.new()
	mundo.add_child(e)
	var skin: int = o.get("skin", 0)
	if skin:
		print("TESTE %s transformado em %d" % [nome, skin])
	e.montar(mundo, o.id, tipo, nome, o.x, o.y,
		Boneco.do_npc(o.numero) if o.tipo == "npc" else (Boneco.do_npc(skin) if skin else Boneco.da_classe(o.get("classe", 0))))
	e.por_heroi(o.get("heroi", 3))
	if o.tipo == "npc":
		e.numero = o.numero
		if e.boneco == null and not _sem_modelo.has(o.numero):
			_sem_modelo[o.numero] = true
			print("TESTE sem modelo %d %s: %s" % [o.numero, nome, PacoteMapa.porque(o.numero)])
	e.skin = skin
	if _gens_vistos.has(o.id):
		_gens_de(e, _gens_vistos[o.id])
	entidades[o.id] = e
	# armadilha (Meteorite Trap da Lost Tower, as da Dungeon): o cliente nao desenha; a bola do Battle Soccer sim
	if tipo == "outro" and not bola(e):
		e.visible = false
	# a Maya (364): o original carrega um Bull Fighter a 0,2 so de marca; o corpo dela e o objeto 0 do mapa 39
	if o.tipo == "npc" and o.numero == 364:
		e.visible = false
	if e.boneco and o.has("equip") and not skin:
		e.boneco.vestir(o.equip)
	for x in o.get("efeitos", []):
		e.buff(x, true)
	if e.boneco and Doppel.no_doppel(mapa_atual) and e.tipo != "jogador":
		_doppel_texturas(e)
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
	# os baus do Doppelganger abrem morrendo (MODEL_DOPPELGANGER_NPC_BOX e GOLDENBOX)
	if e.numero in [541, 542] and e.tipo != "jogador" and som:
		som.tocar(Doppel.SONS % "bau.wav")
	if id == alvo_id:
		alvo_id = -1
	if id == cli.meu_id:
		alvo_id = -1
		item_alvo = -1
		_msg("[color=#e05050]Voce morreu.[/color]")


# Chaos Castle: conta o que eu matei; quem morre num buraco cai (FallingStartCharacter)
func _morte_caos(id: int, matador: int) -> void:
	if not caos.ativo or not entidades.has(id):
		return
	var e: Entidade = entidades[id]
	if matador == cli.meu_id and id != cli.meu_id:
		if e.tipo == "monstro":
			_caos_mortes.monstros += 1
		elif e.tipo == "jogador":
			_caos_mortes.jogadores += 1
	if mundo and not mundo.atributos.is_empty() and mundo.atributos[e.tile.y * 256 + e.tile.x] & ChaosCastle.SEM_CHAO:
		print("TESTE caiu no buraco %s em %s" % [e.nome, e.tile])
		if som:
			som.tocar("queda_grito")
		var t := e.create_tween()
		t.tween_property(e, "position:y", e.position.y - 30.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# clique direito na Armor of Guardsman: so na zona segura; pergunta quando abre (C1 91 tipo 4)
func _armadura_caos(slot: int) -> void:
	if eu == null or mundo == null or not mundo.zona_segura(eu.tile.x, eu.tile.y):
		_caixa_mu([DicaItem.t(2330)], func(_ok, _t): pass, false, false)
		return
	_caos_slot = slot
	print("TESTE armadura do caos no slot %d nivel %d" % [slot, int(inv.itens[slot].get("nivel", 0))])
	cli.perguntar_evento(4, int(inv.itens[slot].get("nivel", 0)))


# C1 91 do Chaos Castle (ReceiveEventZoneOpenTime valor 4): minutos pra abrir; com OK manda o AF 01
func _caos_abre(minutos: int, gente: int) -> void:
	var cc := DicaItem.t(1147)
	var linhas: Array = []
	if minutos == 0:
		linhas = [DicaItem.t(850, [cc]), DicaItem.t(1156, [cc, gente, 100])]
	else:
		linhas = [DicaItem.t(1164, [minutos / 60]) + DicaItem.t(851, [minutos % 60, cc])]
	print("TESTE cc abre: %s" % " / ".join(linhas))
	_caixa_mu(linhas, func(ok, _t):
		if ok and _caos_slot >= 0 and inv.itens.has(_caos_slot):
			print("TESTE entrar no caos nivel %d slot %d" % [int(inv.itens[_caos_slot].get("nivel", 0)), _caos_slot])
			cli.entrar_caos(int(inv.itens[_caos_slot].get("nivel", 0)), _caos_slot), false, true)


func _mapa_mudou(mapa: int, x: int, y: int) -> void:
	print("TESTE mapa mudou %d (%d, %d)" % [mapa, x, y])
	# ReceiveTeleport chama o HideAll: as janelas da rodada 25 nao ficam abertas do outro lado
	for jn: Control in [janela_gatekeeper, janela_arqueiro]:
		if jn and jn.visible:
			jn.visible = false
			npc_falando = -1
	if mapa != mapa_atual:
		Conexao.segurar(true)
		await _abrir_mapa(mapa, x, y)
		Conexao.segurar(false)
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
		# --voltar x,y (teste da guerra): quem morreu e renasceu na cidade anda de volta pra la
		if _parametros().has("voltar") and longe:
			var xy: PackedStringArray = str(_parametros().voltar).split(",")
			await get_tree().create_timer(1.5).timeout
			print("TESTE voltando pra %s" % _parametros().voltar)
			andar_ate(Vector2i(int(xy[0]), int(xy[1])))


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


# no jogo, tecla nao navega entre botoes: um botao com foco (o ultimo clicado, ex. Sair)
# comia o Tab (ui_focus_next) e o Espaco/Enter. Solta o foco e a tecla segue pro jogo;
# campo de texto (chat, quantidade) fica com ela.
func _input(ev: InputEvent) -> void:
	if eu == null or not ev is InputEventKey or not ev.pressed:
		return
	var f := get_viewport().gui_get_focus_owner()
	if f and not (f is LineEdit or f is TextEdit or f is SpinBox):
		f.release_focus()


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
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT and ev.shift_pressed and templo.mostrando:
		_skill_templo(_entidade_na_tela(ev.position))
		return
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
		if e and (e.tipo == "monstro" or bola(e) or e.tipo == "jogador" and (inimigo_da_guerra(e) or inimigo_gens(e) or caos.ativo or ev.ctrl_pressed)):
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
		elif is_instance_valid(sobre) and (sobre.tipo == "monstro" or bola(sobre) or inimigo_da_guerra(sobre) or inimigo_gens(sobre)) and not mundo.zona_segura(eu.tile.x, eu.tile.y):
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
	if loja_pessoal.aberta or _templo_preso:
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
	_templo_quadro(dt)
	_guerra_quadro(dt)
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
				e.boneco.nadando((mapa_atual == 7 or PacoteMapa.mundo_do_mapa(mapa_atual) == 25) and not segura)
		_livre_buffs()
	var seg: bool = mundo.zona_segura(eu.tile.x, eu.tile.y)
	if som == null:
		som = Som.new()
		add_child(som)
		eventos.som = som
		caos.som = som
		templo.som = som
		doppel.som = som
		imperial.som = som
		kanturu.som = som
		raklion.som = som
		crywolf.som = som
		_volumes()
	if kanturu:
		kanturu.heroi = eu
	if raklion:
		raklion.heroi = eu
	if crywolf:
		crywolf.heroi = eu
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
	if _chutar and eu and not eu.morto:
		_chutar_bola()
	if _cacar_jogador != "" and alvo_id < 0 and eu and not eu.morto:
		for e: Entidade in entidades.values():
			if e.nome == _cacar_jogador and not e.morto and not mundo.zona_segura(e.tile.x, e.tile.y):
				print("TESTE mirando o jogador %s em %s" % [e.nome, e.tile])
				mirar(e.id)
				break
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
	_mortos += 1
	# classe master no 400: a experiencia vai pra exp master (ReceiveDieExp)
	if _master_ativo():
		master.exp = clampi(master.exp + ganho, exp_do_master(master.nivel), maxi(master.exp_prox, exp_do_master(master.nivel)))
		print("TESTE experiencia master +%d (total %d de %d)" % [ganho, master.exp, master.exp_prox])
		_msg("[color=#f0d070]+%d de experiencia master[/color]" % ganho)
	else:
		exp_atual += ganho
		print("TESTE experiencia +%d (total %d de %d)" % [ganho, exp_atual, exp_prox])
		_msg("[color=#f0d070]+%d de experiencia[/color]" % ganho)
	_hud_nivel()


# IsMasterExperienceActive: classe master (o servidor so manda o F3 50 pra ela) e nivel 400
func _master_ativo() -> bool:
	return not master.is_empty() and meu_nivel >= 400


# F3 50: ao entrar; os maximos da classe master valem pros orbes
func _master(info: Dictionary) -> void:
	master = info
	janela_master.master = master
	print("TESTE master %s" % info)
	_maximos_master(info)
	_hud_nivel()


func _maximos_master(info: Dictionary) -> void:
	barra_mu.vida_max = maxi(info.vida_max, 1)
	barra_mu.mana_max = maxi(info.mana_max, 1)
	barra_mu.sd_max = maxi(info.sd_max, 1)
	barra_mu.ag_max = maxi(info.ag_max, 1)
	DicaItem.eu.vida_max = info.vida_max
	DicaItem.eu.mana_max = info.mana_max


# F3 51 (Receive_Master_LevelUp): nivel e pontos novos; a exp vai pro inicio do nivel e o
# proximo sai da formula (CalulateMasterLevelNextExperience); brilho em volta do personagem
func _master_subiu(info: Dictionary) -> void:
	print("TESTE master subiu %s" % info)
	if master.is_empty():
		master = {"nivel": 0, "exp": 0, "exp_prox": 0, "pontos": 0}
	master.nivel = info.nivel
	master.pontos = info.pontos
	master.exp = maxi(master.exp_prox, exp_do_master(info.nivel))
	master.exp_prox = exp_do_master(info.nivel + 1)
	janela_master.master = master
	janela_master.queue_redraw()
	_maximos_master(info)
	barra_mu.vida = barra_mu.vida_max
	barra_mu.mana = barra_mu.mana_max
	_msg("[color=#ffd84a]Subiu pro nivel master %d! (+%d, %d pontos master)[/color]" % [info.nivel, info.ganhou, info.pontos])
	if eu:
		EfeitoMU.subiu_nivel(mundo, eu, true)
	_hud_nivel()


# F3 52 (Receive_Master_LevelGetSkill): a skill subiu; a troca da skill base pela fortalecida na
# barra vem do proprio servidor (F3 11 tira e poe)
func _master_skill(info: Dictionary) -> void:
	print("TESTE master skill %s" % info)
	master.pontos = info.pontos
	janela_master.subiu(info.indice, info.nivel, info.valor, info.prox)
	_msg("[color=#9fe0a0]%s no nivel %d (%d pontos master).[/color]" % [_info_skill(info.skill)[0], info.nivel, info.pontos])


# botao Pet da janela C: a janela do pet entra no lugar da mochila, a esquerda da C
func _alternar_pet() -> void:
	if not pets.janela.visible:
		for j in [inv, comandos, janela_minhas_quests, janela_helper, janela_master]:
			j.visible = false
		if not janela_personagem.visible:
			janela_personagem.alternar()
		janela_personagem._ajustar()
	pets.janela.alternar()


func _alternar_master() -> void:
	if not janela_master.e_master(minha_classe) or master.is_empty():
		_msg("[color=#9a9ab0]A arvore de skills master (A) e da classe master (3a classe) no nivel 400.[/color]")
		return
	janela_master.definir_classe(minha_classe)
	if not janela_master.visible:
		for j in [inv, janela_personagem, comandos, janela_minhas_quests, janela_helper]:
			j.visible = false
		hud.move_child(janela_master, -1)   # por cima do registro do chat, como no original
	janela_master.alternar()


# experiencia master em que o nivel master n comeca (formula do cliente: total = 400 + n)
static func exp_do_master(n: int) -> int:
	var t := 400 + n
	var o := t - 255
	return ((9 + t) * t * t * 10 + (9 + o) * o * o * 1000 - 3892250000) / 2


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
	if eu:
		EfeitoMU.subiu_nivel(mundo, eu, not master.is_empty())
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
	barra_mu.master = _master_ativo()
	if barra_mu.master:
		barra_mu.exp_antes = exp_do_master(master.nivel)
		barra_mu.exp_atual = master.exp
		barra_mu.exp_prox = master.exp_prox
	else:
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
		JanelaComandos.GUILDA:
			# NewUICommandWindow: eu ja tenho guilda (255), o outro nao e mestre (507), senao pede (477)
			if minha_guilda >= 0:
				_msg("[color=#e8b04a]%s[/color]" % DicaItem.t(255))
			elif not entidades.has(alvo) or entidades[alvo].guilda_cargo != 128:
				_msg("[color=#e8b04a]%s[/color]" % DicaItem.t(507))
			else:
				cli.pedir_entrar_guilda(alvo)
				_msg("[color=#9ad0ff]%s[/color]" % (DicaItem.t(477) % n))
		JanelaComandos.ALIANCA, JanelaComandos.RIVAL, JanelaComandos.FIM_RIVAL:
			# CommandGuildUnion e CommandGuildRival: so o mestre (1320), o outro tem que ter guilda (1385) e ser mestre (507);
			# sem caixa de confirmacao, o resultado vem no C1 E6
			var o: Entidade = entidades.get(alvo)
			if meu_cargo_guilda != 128:
				_msg("[color=#e8b04a]%s[/color]" % DicaItem.t(1320))
			elif c == JanelaComandos.ALIANCA and (o == null or o.guilda < 0):
				_msg("[color=#e8b04a]%s[/color]" % DicaItem.t(1385))
			elif o == null or o.guilda_cargo != 128:
				_msg("[color=#e8b04a]%s[/color]" % DicaItem.t(507))
			else:
				var tipo := 1 if c == JanelaComandos.ALIANCA else 2
				var pedido := 2 if c == JanelaComandos.FIM_RIVAL else 1
				print("TESTE guilda relacao: pedindo %d/%d a %s" % [tipo, pedido, n])
				cli.pedir_relacao(tipo, pedido, alvo)
				_msg("[color=#9ad0ff]Pedido mandado pra %s, mestre da guilda %s.[/color]" % [n, Guildas.nome(o.guilda)])
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
				_chamar_duelo(alvo, n)
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


# --- duelo (rodada 15) ------------------------------------------------------------------------
# ReceiveDuelRequest/Start/End/Score/HP/Result do WSclient.cpp: o pedido abre a caixa do 910/911 com o som
# da janela; o "aceitou" (0) escreve o 912, abre o placar e toca o iDuelStart; 15 e o 913 (recusou),
# 16 a caixa do "Colosseum is occupied", 28 o nivel 30 e 30 o zen. No fim da luta (C1 AA 0C) o 2689 e a
# caixa do vencedor; no fim do duelo (C1 AA 03) o 914 e o placar fecha.
func _ligar_duelo() -> void:
	cli.duelo_pedido.connect(func(id, n):
		print("TESTE duelo pedido de %s (%d)" % [n, id])
		_som("duelo_janela")
		_caixa_mu([DicaItem.t(910), n, DicaItem.t(911)], func(ok, _t):
			print("TESTE duelo respondi %s" % ok)
			cli.duelo_responder(ok, id, n)))
	cli.duelo_resultado.connect(_duelo_resultado)
	cli.duelo_fim.connect(func(r, _id, n):
		print("TESTE duelo fim %d %s" % [r, n])
		# o OpenMU manda o fim de novo depois de levar de volta: so o primeiro escreve
		if r == 0 and janela_duelo.visible:
			janela_duelo.fechar()
			_msg("[color=#ff9a4a]%s[/color]" % DicaItem.t(914)))
	cli.duelo_placar.connect(func(i1, i2, p1, p2):
		# o OpenMU repete o placar varias vezes por segundo: o teste so escreve o primeiro e quando muda
		if janela_duelo.placar(i1, i2, p1, p2):
			print("TESTE duelo placar %d x %d" % [janela_duelo.meus, janela_duelo.dele]))
	cli.duelo_vida.connect(func(i1, i2, v1, v2, s1, s2): janela_duelo.vidas(i1, i2, v1, v2, s1, s2))
	cli.duelo_venceu.connect(func(v, p):
		print("TESTE duelo venceu %s perdeu %s" % [v, p])
		_msg("[color=#d0d0d0]%s[/color]" % DicaItem.t(2689, [10]))
		_som("duelo_janela")
		_caixa_mu([DicaItem.t(2694), DicaItem.t(2695, [v]), DicaItem.t(2696, [p])], func(_ok, _t): pass, false, false))


func _duelo_resultado(r: int, id: int, n: String) -> void:
	print("TESTE duelo resultado %d %s" % [r, n])
	match r:
		0:
			_msg("[color=#ff9a4a]%s[/color]" % DicaItem.t(912, [n]))
			janela_duelo.abrir(meu_nome, id, n)
			_som("duelo_comeca")
		15:
			_msg("[color=#ff9a4a]%s[/color]" % DicaItem.t(913, [n]))
		16:
			_caixa_mu([DicaItem.t(2692), DicaItem.t(2693)], func(_ok, _t): pass, false, false)
		12, 28:
			_msg("[color=#ff9a4a]%s[/color]" % DicaItem.t(2704, [30]))
		30:
			_msg("[color=#ff9a4a]%s[/color]" % DicaItem.t(1811))


func _chamar_duelo(id: int, n: String) -> void:
	if mapa_atual in ChaosCastle.MAPAS:
		_msg("[color=#d0d0d0]%s[/color]" % DicaItem.t(1150))
	elif janela_duelo.visible:
		_msg("[color=#d0d0d0]%s[/color]" % DicaItem.t(915))
	elif meu_nivel < 30:
		_msg("[color=#ff9a4a]%s[/color]" % DicaItem.t(2704, [30]))
	else:
		print("TESTE duelo chamei %s (%d)" % [n, id])
		cli.duelo_pedir(id, n)
		_msg("[color=#9ad0ff]%s[/color]" % DicaItem.t(2687, [n]))


# comandos do chat que o cliente trata sozinho (ZzzInterface.cpp): /duelstart chama quem esta colado
# (o cliente pede que estejam de frente; aqui basta o mais perto a 1 tile) e /duelend para.
# /duelstart Nome chama esse pelo nome em qualquer distancia (atalho do estudo, o servidor nao confere)
func comando_local(t: String) -> bool:
	var partes := t.strip_edges().split(" ", false)
	if partes.is_empty():
		return false
	match partes[0].to_lower():
		"/duelstart":
			for e: Entidade in entidades.values():
				if is_instance_valid(e) and e.tipo == "jogador" and not e.morto and \
						((partes.size() > 1 and e.nome == partes[1]) or (partes.size() == 1 and _distancia(eu.tile, e.tile) <= 1)):
					_chamar_duelo(e.id, e.nome)
					return true
			return true
		"/duelend":
			if mapa_atual in ChaosCastle.MAPAS:
				_msg("[color=#d0d0d0]%s[/color]" % DicaItem.t(1150))
			elif janela_duelo.visible:
				cli.duelo_parar()
			return true
	return false


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


# + da janela C: caixa com quantos pontos (vem 1, selecionado). 1 vai no C1 F3 06 do original; mais de 1
# vai no /add do OpenMU (AddStatChatCommandPlugIn, ate 65535 por vez), que pro cliente S6 manda a ficha
# de novo (F3 03) e recarrega o mapa no mesmo lugar: _entrou ja poe os numeros novos na janela.
const COMANDO_ATRIBUTO := ["str", "agi", "vit", "ene", "cmd"]
var _caixa_pontos: CaixaMU


func _pontos_quantos(a: int) -> void:
	if is_instance_valid(_caixa_pontos) or janela_personagem.esperando or meus_pontos <= 0:
		return
	var nome: String = [DicaItem.t(166), DicaItem.t(167), DicaItem.t(169), DicaItem.t(168), DicaItem.t(1900)][clampi(a, 0, 4)]
	_caixa_pontos = _caixa_mu([[nome, Color8(230, 230, 0)], "Quantos pontos? (1 a %d)" % meus_pontos], func(ok, t):
		if ok:
			distribuir_pontos(a, int(t) if str(t).is_valid_int() else 0))
	if is_instance_valid(_caixa_pontos):
		_caixa_pontos.campo_numero("1")


func distribuir_pontos(a: int, n: int) -> void:
	n = mini(n, meus_pontos)
	print("TESTE pontos %d no atributo %d (tem %d)" % [n, a, meus_pontos])
	if n <= 0:
		return
	var j := janela_personagem
	j.esperando = true
	j.queue_redraw()
	if n == 1:
		cli.adicionar_ponto(a)
		j._desistir()
		return
	while n > 0:
		var vez := mini(n, 65535)
		cli.dizer(meu_nome, "/add %s %d" % [COMANDO_ATRIBUTO[clampi(a, 0, 4)], vez])
		n -= vez
		if n > 0:
			await get_tree().create_timer(1.5).timeout
	j._desistir()


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
		_alternar_loja_cash()


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
	# o Gateway do Kanturu fica na parede: o original fala de ate 550 (5,5 tiles) sem andar
	# o altar do Crywolf: a elfa contrata em cima dele (o servidor confere a posicao igual a do altar)
	var altar := mapa_atual == Crywolf.MAPA and n.numero >= 205 and n.numero <= 209 and (minha_classe >> 2) == 2
	var perto := 0 if altar else 2
	if _distancia(eu.tile, n.tile) <= perto or (n.numero == 367 and Vector2(eu.tile - n.tile).length() <= 5.5):
		if eu.andando():
			return
		eu.olhar_para(n)
		if npc_falando >= 0:
			_fechar_loja()
		npc_alvo = -1
		if Templo.no_templo(mapa_atual) and _npc_do_templo(n):
			return
		if crywolf and _npc_do_crywolf(n):
			return
		print("TESTE falando com %s (%d)" % [n.nome, n.id])
		cli.falar_npc(n.id)
		npc_falando = n.id
		if n.numero == 385:
			_mirage_t = 0.8
	elif not eu.andando() or _repensar <= 0.0:
		_repensar = 0.8
		_ir_perto(n.tile, perto)


func _fechar_loja(avisar := true) -> void:
	if avisar and npc_falando >= 0 and cli:
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
	janela_quest.visible = false
	janela_evento.visible = false
	janela_quest_nova.visible = false
	if janela_templo:
		janela_templo.visible = false
	if janela_doppel:
		janela_doppel.visible = false
	if janela_imperial:
		janela_imperial.visible = false
	if janela_kanturu:
		janela_kanturu.visible = false
	if janela_castelo:
		janela_castelo.visible = false
	if janela_gatekeeper:
		janela_gatekeeper.visible = false
	if janela_arqueiro:
		janela_arqueiro.visible = false
	inv.soltar()


# --- Illusion Temple (rodada 16) ----------------------------------------------------

func _ligar_templo() -> void:
	janela_templo = JanelaTemplo.new()
	janela_templo.entrar.connect(func(n):
		print("TESTE templo entrar %d" % n)
		if n < 0:
			_msg("[color=#ff5050]%s[/color]" % DicaItem.t(2367))
		else:
			cli.templo_entrar(n))
	janela_templo.fechar.connect(_fechar_loja)
	hud.add_child(janela_templo)
	templo = Templo.new()
	for k in barra_mu.info_skills:
		templo.nomes_skill[int(k)] = str(barra_mu.info_skills[k][0])
	templo.usar.connect(func(sk, alvo):
		var e: Entidade = entidades.get(alvo)
		var d := _distancia(eu.tile, e.tile) if e else 0
		print("TESTE templo usa skill %d em %d (distancia %d)" % [sk, alvo, d])
		cli.templo_usar(sk, alvo, d)
		eu.tocar_skill("magia", e.position if e else eu.position))
	templo.falar.connect(func(id):
		print("TESTE templo barra cheia: fala com %d" % id)
		cli.falar_npc(id)
		npc_falando = id)
	templo.aviso.connect(func(t, erro):
		_msg("[color=%s]%s[/color]" % ["#ff5050" if erro else "#e8e8e8", t]))
	hud.add_child(templo)
	cli.templo_entrada.connect(func(r):
		print("TESTE templo entrada %d" % r)
		if r == 0:
			janela_templo.visible = false
			_fechar_loja()
			return
		var textos := {3: 2367, 4: 2368, 5: 2369, 7: 2091, 8: 2090}
		_msg("[color=#ff5050]%s[/color]" % DicaItem.t(textos.get(r, 2367))))
	cli.templo_gente.connect(func(l): janela_templo.contar(l))
	cli.templo_estado.connect(func(t, e):
		print("TESTE templo %d estado do servidor %d" % [t, e])
		if e == 1:
			_fechar_loja()
		templo.mudar_estado(e))
	cli.templo_info.connect(func(d):
		var antes: int = templo.reliquia
		templo.receber(d)
		if templo.reliquia != antes:
			_reliquia_em(antes, false)
			_reliquia_em(templo.reliquia, true))
	cli.templo_reliquia.connect(func(id, nome):
		print("TESTE templo reliquia com %d (%s)" % [id, nome])
		_reliquia_em(templo.reliquia, false)
		templo.reliquia = id
		_reliquia_em(id, true))
	cli.templo_pontos.connect(func(n): templo.receber_pontos(n))
	cli.templo_skill.connect(_templo_skill)
	cli.templo_skill_fim.connect(func(sk, alvo):
		print("TESTE templo skill %d acabou em %d" % [sk, alvo])
		_fx_templo(alvo, str(sk), false)
		if sk == Templo.RESTRICAO and alvo == cli.meu_id:
			_templo_preso = false)
	cli.templo_resultado.connect(func(a, i, l):
		templo.mostrando = false
		templo.queue_redraw()
		som.tocar(Templo.SOM % "end01")
		var cx := CaixaTemplo.new()
		cx.heroi = meu_nome
		cx.aliados = a
		cx.ilusao = i
		cx.lista = l
		cx.classes = classes
		cx.minha_equipe = templo.equipe
		for e in l:
			if str(e.nome) == meu_nome:
				cx.minha_equipe = int(e.equipe)
		cx.fechou.connect(func():
			print("TESTE templo pede o premio")
			cli.templo_premio())
		hud.add_child(cx))


# --- Doppelganger (rodada 17) ---------------------------------------------------------

func _ligar_doppel() -> void:
	janela_doppel = JanelaDoppel.new()
	janela_doppel.entrar.connect(func():
		print("TESTE doppel entrar")
		cli.doppel_entrar())
	janela_doppel.fechar.connect(_fechar_loja)
	hud.add_child(janela_doppel)
	doppel = Doppel.new()
	hud.add_child(doppel)
	cli.doppel_entrada.connect(func(r):
		print("TESTE doppel entrada %d" % r)
		janela_doppel.resultado(r)
		if r == 2 or r == 3:
			_msg("[color=#ff5050]%s[/color]" % DicaItem.t(2864 if r == 2 else 2865)))
	cli.doppel_monstro.connect(func(pos): doppel.receber_monstro(pos))
	cli.doppel_estado.connect(func(e):
		doppel.estado(e)
		if e == 2:
			# ready -> play: a moldura e o aviso de como se perde
			_fechar_loja()
			_caixa_mu([DicaItem.t(2763), " ", DicaItem.t(2764), " ", DicaItem.t(2765)], func(_ok, _t): pass, false, false))
	cli.doppel_gelo.connect(func(e, pos): doppel.receber_gelo(e, pos))
	cli.doppel_info.connect(func(seg, l):
		doppel.meu_id = cli.meu_id
		doppel.receber_info(seg, l))
	cli.doppel_meta.connect(func(m, n): doppel.receber_meta(m, n))
	cli.doppel_resultado.connect(func(r, xp):
		print("TESTE doppel resultado %d (exp %d)" % [r, xp])
		doppel.fim(r)
		var textos := {0: [2769, 0, 2770], 1: [2766], 2: [2767, 0, 2768]}
		var l := []
		for n in textos.get(r, [2766]):
			l.append(DicaItem.t(n) if n > 0 else " ")
		_caixa_mu(l, func(_ok, _t): pass, false, false))


# --- Imperial Fortress (rodada 18) ----------------------------------------------------

func _ligar_imperial() -> void:
	janela_imperial = JanelaImperial.new()
	janela_imperial.entrar.connect(func():
		print("TESTE imperial entrar")
		cli.imperial_entrar())
	janela_imperial.fechar.connect(_fechar_loja)
	hud.add_child(janela_imperial)
	imperial = Imperial.new()
	hud.add_child(imperial)
	cli.imperial_entrada.connect(_imperial_entrada)
	cli.imperial_tempo.connect(func(t, ms, n): imperial.tempo(t, ms, n))
	cli.imperial_resultado.connect(func(r, xp):
		print("TESTE imperial resultado %d (exp %d)" % [r, xp])
		imperial.fim()
		# ReceiveResultEmpireGuardian: 0 falhou, 1 zona limpa, 2 venceu (com a exp)
		var l := []
		match r:
			0: l = [DicaItem.t(2803), DicaItem.t(2804)]
			1: l = [DicaItem.t(2801, [imperial.dia]), DicaItem.t(2832, [imperial.zona])]
			2: l = [DicaItem.t(2801, [imperial.dia]), DicaItem.t(2802), DicaItem.t(861, [xp])]
		if not l.is_empty():
			_caixa_mu(l, func(_ok, _t): pass, false, false))


# ReceiveEnterEmpireGuardianEvent: 0 entrou (ou zona nova: dia, zona, clima e tempo); os outros so avisam
func _imperial_entrada(r: int, dia: int, zona: int, clima: int, ms: int) -> void:
	print("TESTE imperial entrada %d" % r)
	if r == 0:
		_fechar_loja()
		imperial.entrar(dia, zona, clima, ms)
		return
	var l := []
	match r:
		1: l = [DicaItem.t(2798), " ", DicaItem.t(2799, [ms / 60000])]
		2: l = [DicaItem.t(2839)]
		3: l = [DicaItem.t(2841)]
		4: l = [DicaItem.t(2842)]
		5: l = [DicaItem.t(2843)]
	if not l.is_empty():
		_caixa_mu(l, func(_ok, _t): pass, false, false)


# --- Kanturu (rodada 19) ------------------------------------------------------------

func _ligar_castelo() -> void:
	janela_castelo = JanelaCastelo.new()
	janela_castelo.fechar.connect(_fechar_loja)
	janela_castelo.pedir.connect(func(sub, d): cli.cs_pedir(sub, d))
	janela_castelo.pedir_lista.connect(func(c, sub): cli.cs_lista(c, sub))
	janela_castelo.pedir_npc.connect(func(sub, n, i, t, v): cli.cs_npc(sub, n, i, t, v))
	janela_castelo.confirmar.connect(func(linhas, feito):
		_caixa_mu(linhas, func(ok, _t):
			if ok:
				feito.call()))
	janela_castelo.digitar.connect(func(linhas, feito):
		var c := _caixa_mu(linhas, func(ok, t):
			if ok and t.is_valid_int() and int(t) > 0:
				feito.call(int(t)), true)
		c._campo.secret = false)
	hud.add_child(janela_castelo)
	cli.cs_estado.connect(func(i):
		print("TESTE castelo estado resultado %d" % i.resultado)
		if int(i.resultado) == 1 or int(i.resultado) == 2:
			_abrir_castelo("guarda", i)
		else:
			# 0 falhou, 3 castelo sem dados, 4 a guilda do castelo sumiu
			_msg("[color=#ffcc66]%s[/color]" % DicaItem.t({0: 1500, 3: 1501, 4: 1502}.get(int(i.resultado), 1500)))
			_fechar_loja())
	cli.cs_resposta.connect(_castelo_resposta)
	cli.cs_npcs.connect(func(_r, l): janela_castelo.npcs(l))
	cli.cs_inscritas.connect(func(_r, l): janela_castelo.lista_inscritas(l))
	cli.cs_lados.connect(func(_r, l): janela_castelo.lista_lados(l))
	cli.cs_taxa.connect(func(tipo, t):
		print("TESTE castelo taxa %d = %d" % [tipo, t])
		if tipo == 1:
			taxa_caos = t
		elif tipo == 2:
			taxa_loja = t
			loja.taxa = t)
	cli.cs_portao.connect(func(aberto, i):
		print("TESTE castelo portao %d %s" % [i, "aberto" if aberto else "fechado"])
		_portao_castelo(i, aberto))
	_ligar_guerra()


# abre o Guardsman ou o Senior com o que o jogo sabe da guilda e das marcas na mochila
func _abrir_castelo(modo: String, info := {}) -> void:
	var j := janela_castelo
	j.sou_mestre = meu_cargo_guilda == 128
	j.minha_guilda = Guildas.nome(minha_guilda) if minha_guilda >= 0 else ""
	j.minha_alianca = janela_guilda.alianca if janela_guilda else ""
	_contar_marcas()
	if modo == "guarda":
		j.abrir_guarda(info)
	else:
		j.abrir_senior()
	if _parametros().has("aba_castelo"):
		j._mudar_aba(int(_parametros().aba_castelo))


# GetMyMarkCount / GetMyMarkSlotIndex: Sign of Lord (14,21 nivel 3) somado; o slot e o primeiro achado
func _contar_marcas() -> void:
	var n := 0
	var slot := -1
	for k in inv.itens:
		var it: Dictionary = inv.itens[k]
		if int(it.grupo) == 14 and int(it.numero) == 21 and int(it.nivel) == 3 and int(k) >= 12:
			n += int(it.durabilidade)
			if slot < 0:
				slot = int(k)
	janela_castelo.marcas_na_mochila = n
	janela_castelo.slot_marca = slot


# a marca entregue some da mochila (ou perde 1 da pilha) depois da resposta: a janela aberta reconta
func _recontar_marcas() -> void:
	if janela_castelo != null and janela_castelo.visible:
		_contar_marcas()
		janela_castelo.queue_redraw()


# respostas do C1 B2 (ReceiveBCReg, GiveUp, RegInfo, RegMark, NPCBuy/Repair/Upgrade, TaxInfo, ChangeTaxRate, MoneyDrawOut)
func _castelo_resposta(sub: int, d: Dictionary) -> void:
	var r := int(d.resultado)
	print("TESTE castelo resposta %02X resultado %d" % [sub, r])
	var t := -1
	match sub:
		0x01:
			t = {0: 1503, 1: 1504, 2: 1505, 3: 1506, 4: 1507, 5: 1508, 6: 1509, 7: 1510, 8: 1511}.get(r, 1503)
			if r == 1:
				cli.cs_pedir(0x03)
		0x02:
			t = {0: 1512, 1: 1513, 2: 1514, 3: 1515}.get(r, 1512)
			if r == 1:
				cli.cs_pedir(0x03)
				cli.cs_lista(0xB4)
		0x03:
			janela_castelo.registro(d)
		0x04:
			if r == 1:
				janela_castelo.inscrita["marcas"] = d.marcas
				janela_castelo.queue_redraw()
				print("TESTE castelo marcas registradas %d" % d.marcas)
			else:
				t = {0: 1516, 2: 1517, 3: 1518}.get(r, 1516)
		0x05, 0x06, 0x07:
			if r == 1:
				janela_castelo.npc_mudou(sub, d)
			else:
				t = {0: 1519, 3: 1520, 4: 1616 if sub == 0x05 else 1521, 5: 1522, 6: 1523, 7: 1524}.get(r, 1519)
		0x08:
			if r == 1:
				janela_castelo.impostos(d)
			else:
				t = 1525
		0x09:
			if r == 1:
				if int(d.tipo) == 1:
					janela_castelo.taxa_caos_real = d.valor
				elif int(d.tipo) == 2:
					janela_castelo.taxa_loja_real = d.valor
				janela_castelo.queue_redraw()
			else:
				t = 1526
		0x10:
			if r == 1:
				janela_castelo.tesouro = d.zen
				janela_castelo.queue_redraw()
			else:
				t = 1527
		0x11:
			# a alavanca (CNewUIGateSwitchWindow): abre ou fecha o portao da frente
			if r == 1:
				_alavanca(int(d.portao))
		0x12:
			if r != 1:
				_msg("[color=#ffcc66]%s[/color]" % DicaItem.t(1478))
	if t >= 0:
		_caixa_mu([DicaItem.t(t)], func(_ok, _t): pass, false, false)


# CNewUIGateSwitchWindow: textos 1475 a 1478 e o botao Open ou Close pelo estado do portao
var _portoes_abertos := {}


func _alavanca(portao: int) -> void:
	var aberto: bool = _portoes_abertos.get(portao, false)
	var linhas := [[DicaItem.t(1475), Color8(255, 200, 80)], DicaItem.t(1476), DicaItem.t(1477), [DicaItem.t(1478), Color8(255, 120, 120)],
		"(%s)" % (DicaItem.t(1002) if aberto else DicaItem.t(1479))]
	_caixa_mu(linhas, func(ok, _t):
		if ok:
			cli.cs_pedir(0x12, PackedByteArray([0 if aberto else 1, (portao >> 8) & 0xFF, portao & 0xFF])))


# C1 B2 13: o portao (NPC 277) abre ou fecha (npcGateSwitch GateOpen e GateClose): a acao 1 fica parada aberta,
# a 0 fechada, o som do portao e a linha de 4 tiles na frente (x - 1 a x + 2, y + 1) deixa de ser parede
func _portao_castelo(indice: int, aberto: bool) -> void:
	_portoes_abertos[indice] = aberto
	var e: Entidade = entidades.get(indice)
	if e == null or not is_instance_valid(e):
		return
	if e.boneco:
		var a := "parado2" if aberto else "parado"
		e.boneco.tocar(a, a)
	if mundo:
		mundo.mudar_atributo(0x04, aberto, e.tile.x - 1, e.tile.y + 1, e.tile.x + 2, e.tile.y + 1)
	_som("cs_oCDoorMove")
	print("TESTE guerra portao %d %s em %d,%d (chao %s)" % [indice, "abre" if aberto else "fecha", e.tile.x, e.tile.y,
		"livre" if mundo and mundo.anda(e.tile.x, e.tile.y + 1) else "parede"])


# --- batalha do castelo (rodada 22) ---------------------------------------------------

var _membros_guilda: Array = []   # C2 B6
var _membros_npc: Array = []      # C2 BB
var loja_cash: LojaCash
var _igs_versao := ""             # D2 0C no login: sem ele a loja nao abre (3035)
var _igs_pedindo := false         # mandou D2 02 [0] e espera a resposta
var _pontos_t := 0.0
var _caixas_guerra: Array = []


# --- loja de cash (In-Game Shop, rodada 23) ------------------------------------------

func _ligar_loja_cash() -> void:
	loja_cash = LojaCash.new()
	loja_cash.z_index = 5   # por cima do chat e das outras janelas, como a camada 10.08 do original
	hud.add_child(loja_cash)
	loja_cash.fechar.connect(_fechar_loja_cash)
	loja_cash.pedir_saldo.connect(func(): cli.igs_saldo())
	loja_cash.pedir_deposito.connect(func(pg, g): cli.igs_deposito(pg, g))
	loja_cash.comprar.connect(func(pk, c, ps, it, m):
		print("TESTE loja compra pacote %d categoria %d preco %d item %d moeda %d" % [pk, c, ps, it, m])
		cli.igs_comprar(pk, c, ps, it, m))
	loja_cash.presentear.connect(func(pk, c, ps, it, m, para, txt):
		print("TESTE loja presente pacote %d preco %d para %s" % [pk, ps, para])
		cli.igs_presentear(pk, c, ps, it, m, para, txt))
	loja_cash.usar.connect(func(i, ps, it, t):
		print("TESTE loja usa indice %d preco %d" % [i, ps])
		cli.igs_usar(i, ps, it, t)
		cli.igs_saldo())
	cli.igs.connect(_igs_pacote)


# X ou o botao da barra: pede pra abrir (D2 02 0); aberta, fecha (D2 02 1)
func _alternar_loja_cash() -> void:
	if loja_cash.visible:
		_fechar_loja_cash()
		return
	if _igs_versao.is_empty():
		_caixa_mu(DicaItem.t(3035).split("#"), func(_ok, _t): pass, false, false)
		return
	if _igs_pedindo:
		return
	_igs_pedindo = true
	cli.igs_abrir(false)


func _fechar_loja_cash() -> void:
	if not loja_cash.visible:
		return
	loja_cash.esc()
	loja_cash.visible = false
	cli.igs_abrir(true)


func _igs_pacote(sub: int, d: Dictionary) -> void:
	print("TESTE loja %02X %s" % [sub, d])
	match sub:
		0x0C:
			_igs_versao = d.versao
		0x02:
			_igs_pedindo = false
			if int(d.resultado) == 0:
				# o original nao diz nada; o OpenMU recusa fora da zona segura, morto ou fora do mundo
				_msg("[color=#ffcc66]%s[/color]" % DicaItem.t(3051))
				return
			# Show da loja faz HideAll
			_fechar_loja()
			for j in [inv, janela_personagem, comandos]:
				if j.visible:
					j.alternar()
			loja_cash.abrir(meu_nome)
			cli.igs_saldo()
			cli.igs_deposito(1, false)
		0x01:
			loja_cash.receber_saldo(d)
		0x06:
			loja_cash.receber_cabecalho(d)
		0x0D, 0x0E:
			loja_cash.receber_item(d)
		0x03, 0x04, 0x0B:
			loja_cash.resultado(sub, int(d.resultado))
			print("TESTE loja caixa %s / %s" % [loja_cash.caixa.get("titulo", ""), " ".join(loja_cash.caixa.get("linhas", []))])


func _ligar_guerra() -> void:
	cerco = GuerraCastelo.new()
	cerco.visible = false
	hud.add_child(cerco)
	hud.move_child(cerco, janela_castelo.get_index())
	cerco.comando.connect(func(t, x, y, c): cli.cs_comando(t, x, y, c))
	janela_castelo.atirar.connect(func(npc, area): cli.catapulta_atirar(npc, area))
	cli.cs_guerra.connect(_guerra_pacote)
	cli.cs_mapa_guerra.connect(func(cod, l):
		if cod == 0xB6:
			_membros_guilda = l
		else:
			_membros_npc = l
		cerco.membros = _membros_guilda + _membros_npc
		print("TESTE guerra minimapa %02X %d pontos" % [cod, l.size()]))
	cli.cs_catapulta.connect(_catapulta)


# a cada quadro: o minimapa so no mapa 30; os pontos de quem esta em volta 4 vezes por segundo
func _guerra_quadro(dt: float) -> void:
	if cerco == null:
		return
	cerco.visible = mapa_atual == GuerraCastelo.MAPA
	if not cerco.visible:
		return
	cerco.heroi = eu.tile
	cerco.sou_mestre = meu_cargo_guilda == 128
	_pontos_t -= dt
	if _pontos_t > 0.0:
		return
	_pontos_t = 0.25
	var l := []
	for e: Entidade in entidades.values():
		if not is_instance_valid(e) or e == eu or e.morto:
			continue
		if e.tipo == "jogador":
			var meu_lado := minha_guilda >= 0 and (e.guilda == minha_guilda or e.guilda_rel & 5 != 0)
			l.append([e.tile.x, e.tile.y, 0 if meu_lado else 1])
		elif e.tipo == "npc":
			l.append([e.tile.x, e.tile.y, 2])
	cerco.pontos = l


# caixa da batalha que fecha sozinha em 3 s (CProgressMsgBox)
func _caixa_guerra(linhas: Array, fechar_outras := false) -> void:
	if fechar_outras:
		for c in _caixas_guerra:
			if is_instance_valid(c):
				c.queue_free()
		_caixas_guerra.clear()
	var c := _caixa_mu(linhas, func(_ok, _t): pass, false, false)
	c.sem_botao = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.queue_redraw()
	_caixas_guerra.append(c)
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(c):
			c.queue_free())


func _guerra_pacote(sub: int, d: Dictionary) -> void:
	print("TESTE guerra %02X %s" % [sub, d])
	match sub:
		0x14:
			# ReceiveCrownSwitchState: 0 soltou, 1 apertou, 2 ja tem gente apertando
			var e := int(d.estado)
			if e == 0:
				_caixa_guerra([DicaItem.t(1484)])
				cerco.interruptores[0 if _primeiro_interruptor(int(d.interruptor)) else 1] = {}
			elif e == 1:
				_caixa_guerra([DicaItem.t(1485)])
			elif e == 2:
				var quem: Entidade = entidades.get(int(d.quem))
				var sw: Entidade = entidades.get(int(d.interruptor))
				_caixa_guerra([DicaItem.t(1486, [quem.nome]) if quem else DicaItem.t(1487),
					DicaItem.t(1488, [sw.nome if sw else DicaItem.t(1981)])])
		0x15:
			# ReceiveCrownState: o selo na coroa
			var ms := int(d.ms)
			match int(d.estado):
				0: _caixa_guerra([DicaItem.t(1980, [DicaItem.t(1489), mini(ms / 1000, 59)])], true)
				1: _caixa_guerra([DicaItem.t(1490)], true)
				2: _caixa_guerra([DicaItem.t(1980, [DicaItem.t(1491), mini(ms / 1000, 59)])], true)
				3: _caixa_guerra([DicaItem.t(1492)], true)
				4: _caixa_guerra([DicaItem.t(1982)], true)
		0x16:
			# ReceiveCrownState (escudo da coroa)
			match int(d.estado):
				0: _caixa_guerra([DicaItem.t(1493)])
				1: _caixa_guerra([DicaItem.t(1494)])
				2: _caixa_guerra([DicaItem.t(1490)])
		0x17:
			cerco.iniciada = int(d.estado) == 1
			print("TESTE guerra batalha %s" % ("comecou" if cerco.iniciada else "acabou"))
		0x18:
			var t := DicaItem.t(1496 if int(d.estado) == 0 else 1497, [d.guilda])
			_aviso(t)
		0x19:
			cerco.lado = int(d.estado)
			print("TESTE guerra lado %d (%s)" % [cerco.lado, ["observador", "soldado", "comandante"][cerco.tipo()]])
		0x1D:
			cerco.receber_comando(d)
		0x1E:
			cerco.hora = int(d.hora)
			cerco.minuto = int(d.minuto)
		0x20:
			cerco.receber_interruptor(d, _primeiro_interruptor(int(d.interruptor)))


# FIRST_CROWN_SWITCH_NUMBER: o interruptor 217 e o 1, o 218 o 2. O B2 20 chega antes de eles estarem a vista:
# sem a entidade, o de id menor e o 1 (o servidor cria os dois em ordem)
var _ids_interruptor: Array = []


func _primeiro_interruptor(id: int) -> bool:
	var e: Entidade = entidades.get(id)
	if e != null and e.numero in [217, 218]:
		return e.numero == 217
	if id not in _ids_interruptor:
		_ids_interruptor.append(id)
		_ids_interruptor.sort()
	return id == _ids_interruptor[0]


# C1 B7: 00 abriu a catapulta, 01 resultado do tiro, 02 pedra caindo perto de mim (vinda de longe)
func _catapulta(sub: int, d: Dictionary) -> void:
	print("TESTE catapulta %02X %s" % [sub, d])
	match sub:
		0x00:
			if int(d.resultado) == 1:
				janela_castelo.abrir_catapulta(int(d.npc), int(d.tipo))
			else:
				_caixa_mu([DicaItem.t(1458)], func(_ok, _t): pass, false, false)
				_fechar_loja()
		0x01:
			if int(d.resultado) == 0:
				_caixa_mu([DicaItem.t(1459)], func(_ok, _t): pass, false, false)
				return
			var e: Entidade = entidades.get(int(d.npc))
			if e and e.boneco:
				e.boneco.tocar("parado2")
			var de: Vector3 = (e.global_position if e else mundo.no_tile(int(d.x), int(d.y))) + Vector3.UP * 5.0
			_pedra_catapulta(int(d.tipo), de, int(d.x), int(d.y), int(d.npc) if int(d.resultado) == 1 else -1)
		0x02:
			# DoFireFixStartPosition: a pedra sai de um ponto fixo do mapa (ataque 92,30; defesa 94,190)
			var ini := Vector2i(92, 30) if int(d.tipo) == 1 else Vector2i(94, 190)
			_pedra_catapulta(int(d.tipo), mundo.no_tile(ini.x, ini.y) + Vector3.UP * 5.0, int(d.x), int(d.y), -1)


# a pedra (flybigstone1 do ataque, flybigstone2 da defesa) faz o arco ate o alvo; no chao: explosao, pedrinhas,
# o som do impacto e, quando o tiro foi meu, o C1 B7 04 pro servidor
func _pedra_catapulta(tipo: int, de: Vector3, x: int, y: int, npc_meu: int) -> void:
	if mundo == null:
		return
	_som("cs_oSWFire")
	var para: Vector3 = mundo.no_tile(x, y)
	var tempo := 1.5
	var acel := Vector3(0, -12, 0)
	var vel: Vector3 = (para - de - acel * 0.5 * tempo * tempo) / tempo
	var e := EfeitoMU.criar(mundo)
	var nome := "flybigstone%d" % (1 if tipo == 1 else 2)
	var cena: PackedScene = load(EfeitoMU.PASTA + nome + ".glb")
	var m := cena.instantiate() as Node3D
	m.rotation_degrees = Vector3(-90, 180, 0)
	m.scale = Vector3.ONE * 0.01
	if tipo == 1:
		# o glb do flybigstone1 aponta pra hugerock02.jpg (fora do arquivo): a textura vem do lado
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(EfeitoMU.PASTA + "hugerock02.png")
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			for k in mi.mesh.get_surface_count():
				mi.set_surface_override_material(k, mat)
	e.no_pronto(m, de, 1.0, Color.WHITE, tempo, {"vel": vel, "acel": acel, "vgiro": 3.0, "some": 0.0, "solido": true})
	print("TESTE catapulta pedra %d voa ate %d,%d" % [tipo, x, y])
	get_tree().create_timer(tempo).timeout.connect(func():
		if mundo == null:
			return
		var ef := EfeitoMU.criar(mundo)
		EfeitoSkill.explosao(ef, para + Vector3.UP * 0.5, 4.0)
		EfeitoSkill.pedras(ef, para, 12)
		EfeitoSkill.fumaca(ef, para + Vector3.UP * 0.3, Color(0.6, 0.55, 0.5), 3.0, 1.6)
		_som("cs_oSWHitG")
		print("TESTE catapulta pedra caiu em %d,%d" % [x, y])
		if npc_meu >= 0:
			cli.catapulta_caiu(npc_meu))


func _ligar_kanturu() -> void:
	janela_kanturu = JanelaKanturu.new()
	janela_kanturu.atualizar.connect(func(): cli.kanturu_pedir_info())
	janela_kanturu.fechar.connect(_fechar_loja)
	janela_kanturu.entrar.connect(func():
		var vestido := {}
		for k in [7, 8, 10, 11]:
			if inv.itens.has(k):
				vestido[k] = inv.itens[k]
		var r := JanelaKanturu.recusa(vestido, janela_kanturu.estado == JanelaKanturu.ESTADO_TORRE)
		print("TESTE kanturu entrar %s" % (r if r != "" else "ok"))
		if r != "":
			_caixa_mu([JanelaKanturu.texto_caixa(r)], func(_ok, _t): pass, false, false)
			_fechar_loja()
			return
		# sem C1 31: o servidor larga o pedido de entrada quando o NPC fecha
		cli.kanturu_entrar())
	hud.add_child(janela_kanturu)
	kanturu = Kanturu.new()
	hud.add_child(kanturu)
	cli.kanturu_info.connect(func(e, d, pode, gente, seg):
		if npc_falando >= 0 or janela_kanturu.visible:
			janela_kanturu.info(e, d, pode, gente, seg))
	cli.kanturu_entrada.connect(func(r):
		print("TESTE kanturu entrada %d" % r)
		janela_kanturu.visible = false
		# o OpenMU manda 1 quando ja levou pro mapa 39 (no original o 1 e "15 jogadores ja entraram")
		if not (r == 1 and mapa_atual == Kanturu.MAPA):
			_caixa_mu([JanelaKanturu.texto_caixa(r)], func(_ok, _t): pass, false, false)
		_fechar_loja())
	cli.kanturu_estado.connect(func(e, d): kanturu.mudar(e, d))
	cli.kanturu_resultado.connect(func(r): kanturu.fim(r))
	cli.kanturu_tempo.connect(func(ms): kanturu.tempo(ms))
	cli.kanturu_maya.connect(func(t): kanturu.ataque_maya(t))
	cli.kanturu_contagem.connect(func(m, g): kanturu.contagem(m, g))
	# Raklion: o servidor manda o estado sozinho (o cliente nunca pede o D1 10)
	raklion = Raklion.new()
	add_child(raklion)
	cli.raklion_estado.connect(func(e, d): raklion.mudar(e, d))
	_ligar_crywolf()


func _nome_classe(n: int) -> String:
	var b := clampi(n >> 2, 0, 6)
	return DicaItem.t(DicaItem.NOMES_CLASSE[b][[0, 1, 1, 2][n & 3]])


func _ligar_crywolf() -> void:
	crywolf = Crywolf.new()
	hud.add_child(crywolf)
	cli.crywolf_info.connect(func(o, e): crywolf.info(o, e))
	cli.crywolf_altares.connect(func(v, a): crywolf.estatua_altares(v, a))
	cli.crywolf_tempo.connect(func(h, m): crywolf.tempo(h, m))
	cli.crywolf_chefe.connect(func(v, n): crywolf.chefe(v, n))
	cli.crywolf_rank.connect(func(r, e): crywolf.meu_rank(r, e))
	cli.crywolf_heroi.connect(func(p, n, c, pt): crywolf.heroi_lista(p, n, c, pt))
	cli.crywolf_caos.connect(func(b): crywolf.bonus_caos = b)
	cli.crywolf_balista.connect(func(a, b, c, d): crywolf.balista(a, b, c, d))
	crywolf.resultado_pronto.connect(func(_l):
		_caixa_mu(crywolf.linhas_resultado(_nome_classe), func(_ok, _t): pass, false, false))
	# ReceiveCrywolfAltarContract: 0 recusou (nivel ou espera), 1 contratou: caixa, buff e a pose de cura
	cli.crywolf_contrato.connect(func(r, est, chave):
		print("TESTE crywolf contrato %d altar %d chave %d" % [r, est, chave])
		if r == 0:
			if meu_nivel < 260:
				_caixa_mu([DicaItem.t(2004), DicaItem.t(2005)], func(_ok, _t): pass, false, false)
			else:
				_caixa_mu([DicaItem.t(2008)], func(_ok, _t): pass, false, false)
		elif r == 1:
			_caixa_mu([DicaItem.t(1953), DicaItem.t(1954)], func(_ok, _t): pass, false, false)
			crywolf.altar_contratado(chave, est)
			if eu and eu.boneco:
				eu.boneco.tocar("cura"))


# o clique na elfa nos altares do Crywolf e nos NPCs da quest da 3a classe (ZzzInterface): true = ja tratou
func _npc_do_crywolf(n: Entidade) -> bool:
	if mapa_atual == Crywolf.MAPA and n.numero >= 205 and n.numero <= 209 and crywolf.painel():
		var r := crywolf.clique_altar(n.numero, (minha_classe >> 2) == 2)
		print("TESTE crywolf altar %d: %s" % [n.numero, r])
		match r:
			"pode":
				_caixa_mu([DicaItem.t(2006, [crywolf.contratos_restantes(n.numero)]), DicaItem.t(2007)], func(ok, _t):
					if not ok:
						return
					# CCry_Wolf_Get_Temple::OkBtnDown: montado no Uniria/Dinorant/Fenrir nao contrata
					var ajudante: Dictionary = inv.itens.get(8, {})
					if ajudante.get("grupo", -1) == 13 and ajudante.get("numero", -1) in [2, 3, 37]:
						_caixa_mu([DicaItem.t(1956)], func(_ok, _t): pass, false, false)
					else:
						cli.crywolf_contratar(n.id))
			"destruido":
				_caixa_mu([DicaItem.t(2003)], func(_ok, _t): pass, false, false)
			"contratado":
				_caixa_mu([DicaItem.t(2002)], func(_ok, _t): pass, false, false)
			_:
				return false
		return true
	if n.numero == 407 and mapa_atual == Crywolf.MAPA:
		cli.falar_npc(n.id)
		_caixa_quest3(n.numero)
		return true
	if n.numero == 408 and mapa_atual == 41:
		cli.falar_npc(n.id)
		_caixa_quest3(n.numero)
		return true
	return false


# CMapEnterWerwolfMsgBoxLayout (407, quest 5 da 3a classe, 3.000.000 de zen) e CMapEnterGateKeeperMsgBoxLayout
# (408, quest 6): OK travado fora da quest
func _caixa_quest3(npc: int) -> void:
	var l: Array
	var q := 5 if npc == 407 else 6
	var pode := quest_legado.estado(q) == QuestLegado.ATIVA or (npc == 407 and quest_legado.estado(q) == QuestLegado.FEITA)
	if npc == 407:
		l = [[DicaItem.t(1658), Color8(254, 176, 72)], " ", [DicaItem.t(1659), Color8(170, 218, 146)], " ", DicaItem.t(1660), " ",
			DicaItem.t(1676), " ", DicaItem.t(1661)]
	else:
		l = [[DicaItem.t(1662), Color8(255, 176, 73)], " ", [DicaItem.t(1663), Color8(145, 241, 97)], " ", DicaItem.t(1664), " ",
			DicaItem.t(1677)]
	print("TESTE crywolf caixa quest3 %d pode %s" % [npc, pode])
	var c := CaixaMU.new(l, true, false)
	c.topo = 50
	c.ok_travado = not pode
	c.respondeu.connect(func(ok, _t):
		if not ok:
			return
		if npc == 408:
			cli.entrar_refugio()
		elif meu_zen >= 3000000:
			cli.entrar_quartel()
		else:
			_msg(DicaItem.t(423)))
	hud.add_child(c)


# CGMDoppelGanger::RenderMonster: nos 4 mapas o Ice Walker troca o corpo (malha 0) e o brilho somado
# (malha 1), a Larva troca a pele (malha 0). As texturas vem no pacote dos monstros dos eventos.
func _doppel_tex(nome: String) -> Texture2D:
	var c := Doppel.SONS % (nome + ".png")
	return load(c) if ResourceLoader.exists(c) else null


func _doppel_texturas(e: Entidade) -> void:
	if e.numero == 531 and _doppel_tex("dgicewalker_body"):
		var corpo := _doppel_tex("dgicewalker_body")
		var brilho := _doppel_tex("dgicewalker_r")
		e.boneco.mudar_malha(0, func(mt: BaseMaterial3D) -> void: mt.albedo_texture = corpo)
		e.boneco.mudar_malha(1, func(mt: BaseMaterial3D) -> void:
			mt.albedo_texture = brilho
			mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mt.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED)
	elif e.numero == 532 and _doppel_tex("snake1"):
		var pele := _doppel_tex("snake1")
		e.boneco.mudar_malha(0, func(mt: BaseMaterial3D) -> void: mt.albedo_texture = pele)


# NPC janela 0x14 (Mirage); o OpenMU nao manda (Mirage sem janela): o cliente abre a dele
func _abrir_templo() -> void:
	_mirage_t = 0.0
	_janela_npc = 0x14
	janela_templo.abrir(meu_nivel, _master_ativo())
	print("TESTE janela templo templo %d" % janela_templo.templo)


# clique num NPC dentro do templo: comandantes so falam; estatua e bancos enchem a barra
func _npc_do_templo(n: Entidade) -> bool:
	if n.numero == 381 or n.numero == 382:
		_caixa_mu([DicaItem.t(2359 if n.numero == 381 else 2362)], func(_ok, _t): pass, false, false)
		return true
	var tenho := false
	for k in inv.itens:
		if int(inv.itens[k].grupo) == 14 and int(inv.itens[k].numero) == 64:
			tenho = true
	return templo.clicou_npc(n.numero, n.id, tenho)


func _skill_templo(e: Entidade) -> void:
	var inimigo: bool = e != null and e.tipo == "jogador" and e != eu
	templo.tentar(e.id if e else -1, inimigo, _distancia(eu.tile, e.tile) if e else 99)


# C1 BF 02: 210 escudo em quem usou, 211 prende o alvo, 212 leva quem usou ate a reliquia, 213 queima o alvo
func _templo_skill(ok: bool, sk: int, de: int, alvo: int) -> void:
	print("TESTE templo skill %d de %d em %d: %s" % [sk, de, alvo, "ok" if ok else "falhou"])
	templo.skill_voltou(de)
	if not ok:
		return
	var quem: Entidade = entidades.get(de)
	var nele: Entidade = entidades.get(alvo)
	if quem and quem != eu:
		quem.tocar_skill("magia", nele.position if nele else quem.position)
	match sk:
		Templo.PROTECAO:
			_fx_templo(alvo, str(sk), true)
		Templo.RESTRICAO:
			_fx_templo(alvo, str(sk), true)
			if alvo == cli.meu_id:
				_templo_preso = true
		Templo.QUEIMA:
			if nele:
				var ef := EfeitoMU.criar(mundo)
				ef.chao("magic_ground2", nele.global_position, 1.6, Color(1, 0.2, 0.1), 1.0, {"vgiro": 3.0, "some": 0.5})
				for j in 6:
					ef.sprite("flare01", nele.global_position + Vector3(randf_range(-0.4, 0.4), 0.3 + j * 0.25, randf_range(-0.4, 0.4)),
						1.0, Color(1, 0.3, 0.1), 0.8, {"some": 0.5})


# efeito preso em alguem enquanto dura: "reliquia" (eventsungmul em cima da cabeca), "210" (eventshild) e
# "211" (eventroofe)
func _fx_templo(id: int, qual: String, sim: bool) -> void:
	var chave := "%d:%s" % [id, qual]
	if _templo_fx.has(chave):
		if is_instance_valid(_templo_fx[chave]):
			_templo_fx[chave].queue_free()
		_templo_fx.erase(chave)
	var e: Entidade = entidades.get(id)
	if not sim or e == null:
		return
	var ef := EfeitoMU.criar(e)
	var sempre := 1e9
	match qual:
		"reliquia":
			ef.modelo("eventsungmul", e.global_position + Vector3.UP * 2.6, 1.0, Color(1, 1, 1), sempre,
				{"segue": e, "desl": Vector3.UP * 2.6, "vgiro": 1.5})
			ef.sprite("flare01", e.global_position + Vector3.UP * 2.6, 1.6, Color(1, 0.3, 0.2), sempre, {"segue": e, "desl": Vector3.UP * 2.6})
		"210":
			ef.modelo("eventshild", e.global_position + Vector3.UP * 0.9, 1.0, Color(0.5, 0.6, 1), sempre, {"segue": e, "desl": Vector3.UP * 0.9})
		"211":
			ef.modelo("eventroofe", e.global_position, 1.0, Color(0.7, 0.7, 0.7), sempre, {"segue": e})
	_templo_fx[chave] = ef
	print("TESTE templo efeito %s em %d" % [qual, id])


func _reliquia_em(id: int, sim: bool) -> void:
	if id == 0xFFFF or id < 0:
		return
	if sim:
		som.tocar(Templo.SOM % "holy01")
	_fx_templo(id, "reliquia", sim)


func _templo_quadro(dt: float) -> void:
	if _mirage_t > 0.0:
		_mirage_t -= dt
		if _mirage_t <= 0.0 and npc_falando >= 0 and _janela_npc == 0 and not janela_templo.visible:
			print("TESTE Mirage sem janela do servidor: o cliente abre a entrada")
			_abrir_templo()
	if templo == null or not templo.mostrando:
		return
	templo.meu_id = cli.meu_id
	if templo.progresso_npc >= 0 and (eu.andando() or alvo_id >= 0):
		templo.cancelar_progresso()
	templo.meu_tile = eu.tile


func _volumes() -> void:
	if som and menu:
		som.volumes(menu.vol_musica, menu.vol_efeitos)


func _ligar_loja_e_amigos() -> void:
	_ligar_quests()
	cli.dialogo_npc.connect(func(numero, contribuicao):
		var n: Entidade = entidades.get(npc_falando)
		print("TESTE dialogo do npc %d (%s) contribuicao %d" % [numero, n.nome if n else "?", contribuicao])
		dialogo.contribuicao = contribuicao
		dialogo.minha_gens = minha_gens
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
		if tipo == 4 or tipo == 6:
			# OpenningProcess: o cliente ja manda o fechar do NPC e mostra a janela de entrada
			janela_evento.abrir("ds" if tipo == 4 else "bc", minha_classe >> 2, meu_nivel, _master_ativo())
			print("TESTE janela evento %s botao %d" % [janela_evento.modo, janela_evento.ativo])
			if _parametros().has("evento"):
				janela_evento.clicar(janela_evento.ativo)
		elif tipo == 0x14:
			_abrir_templo()
		elif tipo == 0x23:
			janela_doppel.abrir(cli.janela_minutos)
			print("TESTE janela doppelganger %d min" % cli.janela_minutos)
		elif tipo == 0x24:
			janela_imperial.abrir(0)
			print("TESTE janela imperial")
		elif tipo == 0x0C:
			_abrir_castelo("senior")
		elif tipo == 0x0D:
			# CNewUIGuardWindow so abre com a resposta do estado (ReceiveBCStatus)
			cli.cs_pedir(0x00)
		elif tipo > 3:
			var nomes := {0x0C: "o mercador de cash"}
			_msg("[color=#9a9ab0]A janela de %s ainda nao foi feita neste cliente.[/color]" % nomes.get(tipo, "esse NPC (tipo %d)" % tipo))
			_fechar_loja())
	cli.evento_entrada.connect(func(qual, r):
		print("TESTE evento entrada %s %d" % [qual, r])
		janela_evento.visible = false
		if qual == "cc":
			# ReceiveMoveToEventMatchResult2
			var cc := DicaItem.t(1147)
			var tc := {1: DicaItem.t(854), 2: DicaItem.t(852, [cc]), 3: DicaItem.t(686), 4: DicaItem.t(687),
				5: DicaItem.t(853, [cc, 100]), 6: DicaItem.t(867, [6]), 7: DicaItem.t(423), 8: DicaItem.t(2043, [cc])}
			if tc.has(r):
				_caixa_mu([tc[r]], func(_ok, _t): pass, false, false)
			return
		var nome := DicaItem.t(39 if qual == "ds" else 1146)
		var textos := {1: DicaItem.t(677 if qual == "ds" else 854), 2: DicaItem.t(678) if qual == "ds" else DicaItem.t(852, [nome]),
			3: DicaItem.t(686), 4: DicaItem.t(687), 5: DicaItem.t(679) if qual == "ds" else DicaItem.t(853, [nome, 10]),
			6: DicaItem.t(2043, [nome]) if qual == "ds" else DicaItem.t(867, [1]), 7: DicaItem.t(2043, [nome])}
		if textos.has(r):
			_caixa_mu([textos[r]], func(_ok, _t): pass, false, false))
	cli.evento_abre.connect(func(tipo, minutos, gente, baixo):
		print("TESTE evento abre %d em %d min" % [tipo, minutos])
		if tipo == 4:
			_caos_abre(minutos * 256 + baixo, gente)
			return
		var t := ""
		if tipo == 1:
			t = DicaItem.t(643) if minutos == 0 else DicaItem.t(644, [minutos])
		elif tipo == 2:
			t = DicaItem.t(850, [DicaItem.t(1146)]) if minutos == 0 else DicaItem.t(851, [minutos, DicaItem.t(1146)])
		if t != "":
			_caixa_mu([t], func(_ok, _t): pass, false, false))
	cli.evento_contagem.connect(func(v):
		eventos.contagem(v)
		print("TESTE evento contagem %d: %s" % [v, eventos.texto_contagem()]))
	cli.ds_placar.connect(func(pos, l):
		print("TESTE ds placar pos %d de %d: %s" % [pos, l.size(), JSON.stringify(l)])
		var c := CaixaPlacar.new("ds")
		c.heroi = meu_nome
		c.minha_pos = pos
		c.lista = l
		hud.add_child(c))
	cli.bc_resultado.connect(func(ok, nome, pontos, exp, zen):
		print("TESTE bc resultado %s %s pontos %d exp %d zen %d" % [ok, nome, pontos, exp, zen])
		if eventos.caos:
			# o OpenMU manda o placar do Blood Castle tambem no Chaos Castle
			print("TESTE cc resultado monstros %d jogadores %d" % [_caos_mortes.monstros, _caos_mortes.jogadores])
			var k := CaixaPlacar.new("cc")
			k.bc = {"ok": ok, "exp": exp, "monstros": _caos_mortes.monstros, "jogadores": _caos_mortes.jogadores}
			hud.add_child(k)
			return
		var c := CaixaPlacar.new("bc")
		c.bc = {"ok": ok, "pontos": pontos, "exp": exp, "zen": zen}
		hud.add_child(c))
	cli.bc_estado.connect(func(estado, seg, maximo, mortos, _dono, _item):
		if estado != eventos.bc_tipo - 1 or mortos != eventos.bc_mortos or seg % 30 == 0:
			print("TESTE bc estado %d %d s monstros %d/%d" % [estado, seg, mortos, maximo])
		eventos.estado_castelo(estado, seg, maximo, mortos))
	cli.terreno.connect(func(atributo, tirar, areas):
		# ChangeTerrainAttributes: liga ou tira o atributo nos retangulos (portao e ponte do Blood Castle)
		print("TESTE terreno %d %s %s" % [atributo, "tira" if tirar else "poe", str(areas)])
		if mundo == null or mundo.atributos.is_empty():
			return
		for a in areas:
			mundo.mudar_atributo(atributo, tirar, a[0], a[1], a[2], a[3]))
	cli.texto_servidor.connect(func(n):
		print("TESTE texto do servidor %d" % n)
		_caixa_mu([DicaItem.t(n)], func(_ok, _t): pass, false, false))
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
	cli.saiu.connect(func(tipo):
		print("TESTE saiu %d" % tipo)
		if tipo == 1:
			meu_nome = ""
			correio.fechar_tudo()
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
	print("TESTE helper: monstros perto %s" % [entidades.values().filter(func(x): return is_instance_valid(x) and x.tipo == "monstro").map(func(x): return "%s%s" % [x.nome, x.tile])])
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


# testes (?buff_teste=a4,a55,fogos,fruta): icones na janela de buffs e um passo a cada 3 s. aN: so o buff N no
# meu boneco; fogos, natal, redemoinho, escudo, quebrou, subiu: o efeito em mim; fruta: abre a caixa da fruta
func _buff_teste(lista: Array) -> void:
	Engine.time_scale = float(_parametros().get("lento", "1"))
	await get_tree().create_timer(4.0).timeout
	if _parametros().has("buff_janela"):
		# ?buff_janela=29,44,...: so esses na janela, todos com 30 min
		for b: String in str(_parametros().buff_janela).split(",", false):
			janela_buffs.por(int(b), 1800)
	else:
		for b in [28, 4, 1, 55]:
			janela_buffs.por(b)
		janela_buffs.por(35, 1920)
		janela_buffs.por(78, 1800)
	print("TESTE buff_teste janela %s" % [janela_buffs.lista()])
	for x: String in lista:
		if eu == null:
			return
		for b in eu.buffs.keys():
			eu.buff(b, false)
		barra_mu.veneno = false
		print("TESTE buff_teste %s" % x)
		match x:
			"fogos", "natal":
				EfeitoMU.fogos(mundo, mundo.no_tile(eu.tile.x + 2, eu.tile.y - 2), x == "natal")
			"redemoinho":
				EfeitoMU.redemoinho(mundo, eu)
			"escudo", "quebrou":
				EfeitoMU.escudo(mundo, eu, x == "quebrou")
			"subiu":
				EfeitoMU.subiu_nivel(mundo, eu, false)
			"fruta":
				caixa_fruta.abrir(12, 3)
			"grupo":
				# rodada 6: a lista do grupo (eu lider) e a barra de vida em cima de quem estiver perto
				var outros := entidades.values().filter(func(e): return e.tipo == "jogador")
				var l := [{"nome": meu_nome, "indice": 0, "mapa": mapa_atual, "x": eu.tile.x, "y": eu.tile.y, "vida": 90, "vida_max": 100}]
				for e: Entidade in outros.slice(0, 2):
					l.append({"nome": e.nome, "indice": l.size(), "mapa": mapa_atual, "x": e.tile.x, "y": e.tile.y, "vida": 30, "vida_max": 100})
				if l.size() == 1:
					l.append({"nome": "Amigo", "indice": 1, "mapa": mapa_atual, "x": eu.tile.x, "y": eu.tile.y, "vida": 30, "vida_max": 100})
				janela_grupo.meu_nome = meu_nome
				janela_grupo.definir(l)
			"heroi":
				for e: Entidade in entidades.values():
					if e.tipo == "jogador":
						e.por_heroi(6)
						break
				eu.por_heroi(4)
			"anel":
				eu.trocar_boneco(Boneco.do_npc(7))
			"senha":
				eu.trocar_boneco(Boneco.da_classe(minha_classe))
				_vestir_eu()
				caixa_senha.abrir(1)
				caixa_senha.digito(1)
				caixa_senha.digito(3)
			"bau":
				caixa_senha.fechar()
				guarda.abrir_guarda("bau", "Baz The Vault Keeper", {})
				guarda.trancado = true
				guarda.tem_senha = true
				guarda.visible = true
			_:
				var n := int(x.substr(1))
				eu.buff(n, true)
				barra_mu.veneno = n == 55
		barra_mu.queue_redraw()
		await get_tree().create_timer(3.0).timeout
	caixa_fruta.visible = false


func _itens_sumiram(ids: Array) -> void:
	for id in ids:
		if itens.has(id):
			itens[id].queue_free()
			itens.erase(id)


func _pegou(slot: int, item: Dictionary) -> void:
	inv.entrou(slot, item)
	_contar_pocoes()
	var n: String = itens_nomes.get("%d,%d" % [item.grupo, item.numero], "item")
	_msg("[color=#9fe0a0]Pegou %s.[/color]" % ItensMU.nome(item))
	print("TESTE pegou %s" % n)


# --- quests de troca de classe (sistema antigo do S6) -------------------------------

func _ligar_quests() -> void:
	_ligar_quests_novas()
	var q := quest_legado
	cli.quest_lista.connect(func(n, b):
		q.definir_lista(n, b, minha_classe)
		print("TESTE quests %d estados %s atual %d" % [n, b.slice(0, 2).hex_encode(), q.atual]))
	cli.quest_npc.connect(func(i, b):
		_contexto_quest()
		q.definir(i, b)
		var n: Entidade = entidades.get(npc_falando)
		# sem o NPC aberto (a fita dos testes chega antes do clique), o nome vem do numero na quest
		janela_quest.abrir(n.nome if n and n.nome != "" else str(monstros.get(str(int(q.quest().get("npc", 0))), [""])[0]))
		print("TESTE quest npc %d (%s) estado %d fala %d: %s" % [i, janela_quest.nome, q.estado(i), janela_quest._fala, q.fala(janela_quest._fala).texto.left(60)])
		if _parametros().has("quest_respostas"):
			_teste_quest(str(_parametros().quest_respostas).split(",", false)))
	cli.quest_mudou.connect(func(i, r, b):
		print("TESTE quest mudou %d resultado %d byte %d" % [i, r, b])
		if r != 0:
			_msg("[color=#e8b04a]O NPC nao aceitou (codigo %d).[/color]" % r)
			return
		q.definir(i, b)
		_contexto_quest()
		janela_quest.atualizar()
		print("TESTE quest %d agora estado %d fala %d" % [i, q.estado(i), janela_quest._fala])
		if q.estado(i) == QuestLegado.ATIVA:
			_msg("[color=#9fe0a0]Quest aceita: %s.[/color]" % q.titulo())
		elif q.estado(i) == QuestLegado.FEITA:
			_msg("[color=#f0c860]Quest concluida: %s.[/color]" % q.titulo()))
	cli.quest_premio.connect(_premio_quest)
	cli.quest_mortes.connect(func(i, m):
		q.mortes = m
		janela_quest.queue_redraw()
		print("TESTE quest mortes %d %s" % [i, m]))
	cli.fala_objeto.connect(func(id, t):
		var n: Entidade = entidades.get(id)
		print("TESTE fala de %s: %s" % [n.nome if n else str(id), t])
		_msg("[color=#9ff0e0]%s:[/color] %s" % [n.nome if n else "NPC", t]))


# --- quests novas do S6 (F6, CQuestMng) ---------------------------------------------

func _ligar_quests_novas() -> void:
	var qn := quest_nova
	cli.quests_do_npc.connect(func(npc, l):
		print("TESTE F6 0A npc %d %s" % [npc, l])
		if dialogo.visible:
			dialogo.lista_quests(l)
			if _parametros().has("quest_nova"):
				if not _teste_qn_comecou:
					_teste_qn_comecou = true
					_teste_quest_nova(str(_parametros().quest_nova).split(",", false))
				else:
					_teste_quest_nova_janela())
	cli.quest_passo.connect(func(i):
		print("TESTE F6 0B %x: %s" % [i, qn.fala_npc(i).left(60)])
		_passo_quest(i))
	cli.quest_progresso.connect(func(i, info, do_npc):
		print("TESTE F6 %s %x %s" % ["0C" if do_npc else "1B", i, info])
		qn.info[i] = info
		if do_npc:
			_passo_quest(i)
		else:
			janela_minhas_quests.atualizar())
	cli.quest_concluiu.connect(_quest_concluiu)
	cli.quest_desistiu.connect(func(g):
		print("TESTE F6 0F grupo %d" % g)
		qn.tirar_grupo(g)
		janela_minhas_quests.atualizar()
		_msg("[color=#e8b04a]%s[/color]" % qn.texto(2818)))
	cli.quests_ativas.connect(func(l):
		print("TESTE F6 1A %s" % [l.map(func(x): return "%x" % x)])
		qn.ativas = l.filter(func(x): return qn.tem(x))
		qn.ativas.sort()
		janela_minhas_quests.atualizar())


# F6 0D: 1 concluiu (fecha e tira da lista), 2 limite de zen, 3 mochila cheia
func _quest_concluiu(i: int, r: int) -> void:
	print("TESTE F6 0D %x resultado %d" % [i, r])
	match r:
		1:
			janela_quest_nova.visible = false
			quest_nova.tirar_grupo(i >> 16)
			quest_nova.info.erase(i)
			janela_minhas_quests.atualizar()
			_msg("[color=#f0c860]%s[/color]" % quest_nova.texto(2814))
		2:
			_msg("[color=#e8b04a]%s[/color]" % quest_nova.texto(2816))
		3:
			_msg("[color=#e8b04a]A mochila esta cheia: abra espaco pra receber o premio.[/color]")


# SetCurQuestProgress: o passo novo entra na lista da janela T; 0xFF e a quest concluida
func _passo_quest(i: int) -> void:
	quest_nova.atualizar_ativa(i)
	janela_minhas_quests.atualizar()
	if i & 0xFFFF == 0xFF:
		janela_quest_nova.visible = false
		_msg("[color=#f0c860]%s[/color]" % quest_nova.texto(2814))
		return
	if not quest_nova.tem(i):
		return
	var n: Entidade = entidades.get(npc_falando)
	janela_quest_nova.npc = n.nome if n else ""
	janela_quest_nova.jogador = meu_nome
	dialogo.visible = false
	if janela_quest_nova.visible and janela_quest_nova.indice == i and quest_nova.respostas(i).is_empty():
		janela_quest_nova.atualizar_pedidos()
	else:
		janela_quest_nova.abrir(i)
	if _parametros().has("quest_nova"):
		_teste_quest_nova_janela()


# --quest_nova 1,a,d,1,a: 1 escolhe a 1a quest da lista do NPC; na janela da quest "a" aceita,
# "r" recusa, "c" conclui, "d" desiste pela janela T, "t" abre a janela T, "e" escolhe a 1a quest
# dela, "p" espera 3 s, "f" fecha o NPC, "n" fala com a Elf Soldier de novo. Um passo por segundo.
var _fila_quest_nova := []
var _teste_master_comecou := false
var _teste_qn_comecou := false
var _teste_qn_esperando := false

func _teste_quest_nova(lista: Array) -> void:
	_fila_quest_nova = lista
	await get_tree().create_timer(1.0).timeout
	_seguir_teste_quest_nova()


func _teste_quest_nova_janela() -> void:
	# o 0B e o 0C chegam juntos: so um passo do teste por vez
	if _teste_qn_esperando:
		return
	_teste_qn_esperando = true
	await get_tree().create_timer(1.0).timeout
	_teste_qn_esperando = false
	_seguir_teste_quest_nova()


func _seguir_teste_quest_nova() -> void:
	while not _fila_quest_nova.is_empty():
		var p: String = _fila_quest_nova.pop_front()
		print("TESTE quest nova passo do teste: %s" % p)
		match p:
			"a", "r":
				janela_quest_nova.seta_direita()
				while janela_quest_nova.modo != JanelaQuestNova.JOGADOR:
					janela_quest_nova.seta_direita()
				janela_quest_nova.escolher(0 if p == "a" else 1)
				return
			"c":
				janela_quest_nova.ok()
				return
			"t":
				if not janela_minhas_quests.visible:
					janela_minhas_quests.alternar()
				print("TESTE janela T: %s" % [quest_nova.ativas.map(func(x): return quest_nova.assunto(x))])
			"e":
				# escolhe a 1a quest da janela T (pede o estado, F6 1B)
				if not janela_minhas_quests.visible:
					janela_minhas_quests.alternar()
				janela_minhas_quests.escolher(0)
				await get_tree().create_timer(1.5).timeout
			"d":
				if not janela_minhas_quests.visible:
					janela_minhas_quests.alternar()
				janela_minhas_quests.escolher(0)
				await get_tree().create_timer(1.0).timeout
				janela_minhas_quests.pedir_desistir()
				janela_minhas_quests.confirmar(true)
				await get_tree().create_timer(1.5).timeout
			"p":
				await get_tree().create_timer(3.0).timeout
			"f":
				_fechar_loja()
			"n":
				# fala com a Elf Soldier de novo e pede as quests
				_fechar_loja()
				await get_tree().create_timer(0.5).timeout
				_teste_falar("Elf")
				return
			_:
				if dialogo.visible:
					dialogo.escolher(int(p) - 1)
				return


# o que a quest confere: nivel, zen e os itens da mochila (fora o equipado)
func _contexto_quest() -> void:
	var q := quest_legado
	q.nivel = meu_nivel
	q.zen = meu_zen
	q.itens = []
	for s in inv.itens:
		if s >= 12:
			q.itens.append(inv.itens[s])


# C1 A3: o premio vem pra quem esta perto tambem; so o meu muda o personagem
func _premio_quest(id: int, tipo: int, valor: int) -> void:
	print("TESTE quest premio id %d tipo %d valor %d" % [id, tipo, valor])
	if id != cli.meu_id:
		return
	match tipo:
		200, 202:
			meus_pontos += valor
			_msg("[color=#f0c860]+%d pontos de atributo pela quest.[/color]" % valor)
		201, 204:
			minha_classe = valor >> 3
			if _classe_de.has(meu_nome):
				_classe_de[meu_nome][0] = minha_classe
			DicaItem.eu["classe"] = minha_classe
			quest_legado.classe = minha_classe >> 2
			_msg("[color=#f0c860]Agora voce e %s![/color]" % classes.get(str(minha_classe), "outra classe"))
			print("TESTE classe nova %d %s" % [minha_classe, classes.get(str(minha_classe), "?")])
		203:
			_msg("[color=#f0c860]Voce aprendeu o combo de skills.[/color]")
	_hud_nivel()


# --quest_respostas 1,1,...: escolhe essas respostas na janela da quest, uma por vez
# ("c" aperta o botao de concluir)
func _teste_quest(lista: Array) -> void:
	for r in lista:
		await get_tree().create_timer(1.0).timeout
		if not janela_quest.visible:
			return
		print("TESTE quest escolhendo %s na fala %d" % [r, janela_quest._fala])
		if r == "c":
			janela_quest.concluir()
		else:
			janela_quest.escolher(int(r) - 1)
		print("TESTE quest agora fala %d: %s" % [janela_quest._fala, janela_quest.q.fala(janela_quest._fala).texto.left(60)])


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
# --foco_tab 1: um botao do menu com foco e o Tab apertado 2 vezes tem que abrir e fechar o minimapa
func _teste_foco_tab() -> void:
	await get_tree().create_timer(2.0).timeout
	menu.alternar(brilho)
	var b: Button = menu.find_children("*", "Button", true, false)[0]
	b.grab_focus()
	print("TESTE foco_tab: foco em '%s'" % b.text)
	for i in 2:
		var t := InputEventKey.new()
		t.keycode = KEY_TAB
		t.pressed = true
		Input.parse_input_event(t)
		await get_tree().process_frame
		var solta := t.duplicate()
		solta.pressed = false
		Input.parse_input_event(solta)
		await get_tree().process_frame
		var f := get_viewport().gui_get_focus_owner()
		print("TESTE foco_tab: Tab %d, minimapa %s, foco %s" % [i + 1, minimapa.visible, f.name if f else "nenhum"])


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
		_contar_pocoes()
		_recontar_marcas())
	cli.durabilidade.connect(func(slot, v):
		print("TESTE durabilidade %d = %d" % [slot, v])
		inv.durabilidade(slot, v)
		_contar_pocoes()
		_recontar_marcas())
	cli.largou.connect(func(ok, slot):
		print("TESTE largou %s %d" % [ok, slot])
		if ok:
			inv.removido(slot)
		inv.nao_moveu()
		_contar_pocoes())
	cli.item_melhorado.connect(_item_melhorado)
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
	cli.efeito.connect(_efeito)
	cli.magia_acabou.connect(func(skill, quem):
		if BUFF_DA_SKILL.has(skill):
			_efeito(false, quem, BUFF_DA_SKILL[skill]))
	cli.efeito_item.connect(_efeito_item)
	cli.item_efeito.connect(_bebida)
	cli.fruta.connect(_fruta)
	cli.mostrar_efeito.connect(_mostrar_efeito)
	cli.veneno.connect(func(dano, sd):
		print("TESTE veneno %d sd %d" % [dano, sd])
		barra_mu.vida = maxi(barra_mu.vida - dano, 0)
		barra_mu.sd = sd
		if eu:
			eu.mostrar_dano(dano, 5)
		_hud_nivel())
	cli.fogos.connect(func(t, x, y):
		print("TESTE fogos tipo %d em (%d, %d)" % [t, x, y])
		if t == 2:
			_som("medalha")
		elif mundo:
			EfeitoMU.fogos(mundo, mundo.no_tile(x, y), t == 59)
			_som("fogos"))
	cli.redemoinho.connect(func(quem):
		print("TESTE redemoinho em %d" % quem)
		if entidades.has(quem):
			EfeitoMU.redemoinho(mundo, entidades[quem])
			_som("cerejeira"))
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
	if k == KEY_X:
		_alternar_loja_cash()
		return true
	if k == KEY_T:
		janela_minhas_quests.alternar()
		return true
	if k == KEY_A:
		_alternar_master()
		return true
	if k == KEY_F:
		amigos.alternar()
		return true
	if k == KEY_J:
		if chat_comandos.visible:
			chat_comandos.fechar()
		else:
			hud.move_child(chat_comandos, -1)
			chat_comandos.abrir()
		return true
	if k in [KEY_ENTER, KEY_KP_ENTER]:
		correio.caixa.abrir()
		return true
	if k == KEY_U:
		menu.alternar(brilho)
		return true
	if k == KEY_B:
		_alternar_gens()
		return true
	if k == KEY_G:
		_alternar_guilda()
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
		if loja_cash.visible:
			if not loja_cash.esc():
				_fechar_loja_cash()
		elif correio.fechar_topo():
			pass
		elif criar_guilda.visible:
			criar_guilda.fechar()
		elif janela_guilda.visible:
			janela_guilda.visible = false
		elif janela_master.visible:
			if not janela_master.tecla_enter_esc(false):
				janela_master.alternar()
		elif minimapa.visible:
			minimapa.visible = false
		elif chat_comandos.visible:
			chat_comandos.esc()
		elif janela_gatekeeper.visible:
			janela_gatekeeper.fechar()
		elif janela_arqueiro.visible:
			janela_arqueiro.fechar()
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
		elif loja.visible or guarda.visible or dialogo.visible or janela_quest.visible or janela_quest_nova.visible:
			_fechar_loja()
		elif janela_minhas_quests.visible:
			janela_minhas_quests.alternar()
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
	# Shift+1 a 4: as ordens do corvo
	if n >= 0 and n < Pets.COMANDOS and ev.shift_pressed:
		_escolher_skill(Pets.COMANDO + n)
		return true
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
		elif barra_mu.usavel(barra_mu.atalhos[n]):
			_escolher_skill(barra_mu.atalhos[n])
		return true
	return false


# --- skills ------------------------------------------------------------------------

# [nome, alcance, tipo, alvo, mana, ag, anda ate o alvo]
func _info_skill(n: int) -> Array:
	if Pets.e_comando(n):
		return [Pets.nome_comando(n), 0, -1, 0, 0, 0, false]
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
	if not _teclas_servidor.is_empty():
		_aplicar_teclas(_teclas_servidor)
	if barra_mu.skill_atual not in l and not Pets.e_comando(barra_mu.skill_atual):
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
	_guardar_teclas()


func _escolher_skill(n: int) -> void:
	barra_mu.skill_atual = n
	barra_mu.queue_redraw()
	_salvar_atalhos()
	_msg("Skill: %s" % _info_skill(n)[0])


# acao do boneco pra cada skill (o cliente tem uma por skill; aqui as parecidas)
func _acao_skill(n: int) -> String:
	n = JanelaMaster.base(n)
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
	if Pets.e_comando(n):
		# SendPetCommand: uma vez por clique
		_segura_direito = false
		if not de_novo:
			pets.mandar(n, _entidade_na_tela(tela))
		return
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
	if n == 263:
		cli.skill_rage_area(n, skill_alvo)
		print("TESTE skill %d (Dark Side) no alvo %d" % [n, skill_alvo])
	elif tipo in [0, 10, 11, 30] or n == 63:
		if n in RAGE:
			cli.skill_rage(n, skill_alvo)
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
# --master_skills 300,300,326: abre a janela A e clica em cada skill (pelo numero) como o mouse faz;
# confirma quando a janela deixa e mostra a resposta do servidor
func _teste_master(lista: Array) -> void:
	await get_tree().create_timer(2.0).timeout
	_alternar_master()
	var j := janela_master
	print("TESTE master janela %s classe %d, %d skills na arvore, pontos %d" % [j.visible, minha_classe, j.entradas.size(), master.pontos])
	for t in lista:
		var e: Array = []
		for x in j.entradas:
			if x[7] == int(t):
				e = x
		if e.is_empty():
			print("TESTE master %s nao esta na arvore" % t)
			continue
		var antes := j.nivel(e[7])
		j.clique(j._rect_icone(e).get_center())
		print("TESTE master clicou %s: %s" % [t, j._caixa.get("linhas", [])])
		print("TESTE master dica %s" % [j.linhas_dica(e).map(func(x): return x.t)])
		if j._caixa.get("skill", -1) >= 0:
			j.clique(j._rect_botao(0).get_center())
			for i in 30:
				await get_tree().create_timer(0.1).timeout
				if j.nivel(e[7]) != antes:
					break
		else:
			j.confirmar(false)
		print("TESTE master %s nivel %d -> %d, pontos %d, grupo %d" % [t, antes, j.nivel(e[7]), master.pontos, j.pontos_do_grupo(e[2])])


func _teste_ponto(a: int) -> void:
	await get_tree().create_timer(2.0).timeout
	_botao_barra("personagem")
	var j := janela_personagem
	print("TESTE janela antes: pontos %d %s vida_max %d mana_max %d" % [j.eu.pontos, [j.eu.forca, j.eu.agilidade, j.eu.vitalidade, j.eu.energia, j.eu.comando], barra_mu.vida_max, barra_mu.mana_max])
	print("TESTE linhas %s" % [j._linhas(j.classe_base())])
	for n in 3:
		j._clique(Vector2(168, JanelaPersonagem.ALTURAS[a] + 9))
		if is_instance_valid(_caixa_pontos):
			_caixa_pontos.responder(true)   # a caixa de quantos ja vem com 1
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



# --- efeitos e consumo (rodada 5) ------------------------------------------------------

# C1 1B: a skill que acabou -> o buff que sai (ReceiveMagicFinish do cliente)
const BUFF_DA_SKILL := {1: 55, 384: 55, 38: 55, 387: 55, 7: 56, 389: 56, 489: 56, 39: 56, 232: 86, 337: 86,
	28: 1, 420: 1, 422: 1, 27: 2, 417: 2, 423: 2, 67: 61, 70: 18, 69: 9, 75: 19, 53: 7, 64: 5, 511: 5, 515: 5,
	517: 5, 48: 8, 356: 8, 360: 8, 51: 57, 424: 57, 55: 58, 490: 58, 16: 4, 403: 4, 404: 4, 266: 129, 267: 130,
	573: 130, 268: 131, 569: 131, 572: 131, 217: 71, 233: 82, 380: 82, 383: 82, 218: 81, 469: 81}


# C1 07 (e o fim pelo 1B): liga ou desliga o efeito em quem; os meus vao pra janela de buffs
func _efeito(ativo: bool, quem: int, e: int) -> void:
	var ent: Entidade = entidades.get(quem)
	if ent:
		ent.buff(e, ativo)
	if quem != cli.meu_id or janela_buffs == null:
		if ent:
			print("TESTE efeito %d %s em %s (%d): %s" % [e, "liga" if ativo else "desliga", ent.nome, quem, ent.buffs.keys()])
		return
	print("TESTE meu buff %d %s (%s)" % [e, "liga" if ativo else "desliga", JanelaBuffs.nome(e)])
	if ativo and not janela_buffs.buffs.has(e):
		janela_buffs.por(e)
		if e == 4:
			_som("soul_barrier")
	elif not ativo:
		janela_buffs.tirar(e)
	barra_mu.veneno = janela_buffs.buffs.has(55)
	barra_mu.queue_redraw()


# C1 2D: buff de item em mim com o tempo (Jack O'Lantern, Cherry Blossom, pocoes de buff)
func _efeito_item(i: Dictionary) -> void:
	print("TESTE buff de item %s" % [i])
	var e: int = i.efeito
	if i.acao == 0:
		_efeito(true, cli.meu_id, e)
		janela_buffs.por(e, i.segundos)
		_msg("[color=#9ad0ff]%s: %s.[/color]" % [JanelaBuffs.nome(e), JanelaBuffs.tempo(i.segundos)])
		if e == 3:
			_msg("[color=#7fe0ff]%s[/color]" % DicaItem.t(1828))
	else:
		_efeito(false, cli.meu_id, e)


# C3 29: Ale (0, mais velocidade de ataque) e Remedy of Love (1, mais dano): o corpo muda de cor pelo tempo
func _bebida(tipo: int, segundos: int) -> void:
	print("TESTE bebida tipo %d por %d s" % [tipo, segundos])
	if tipo > 1 or eu == null:
		return   # o 77 (Potion of Soul) o cliente tambem ignora aqui
	_som("beber")
	var b := -1 - tipo
	eu.buff(b, true)
	_msg("[color=#9ad0ff]%s por %d segundos.[/color]" % ["Ale: ataque mais rapido" if tipo == 0 else "Remedy of Love: mais dano", segundos])
	await get_tree().create_timer(maxf(segundos, 1)).timeout
	if is_instance_valid(eu):
		eu.buff(b, false)


# C1 2C: resposta da fruta (ReceiveUseStateItem): 0 somou, 3 e 6 tiraram, o resto e motivo de nao ter dado
func _fruta(r: int, pontos: int, atributo: int) -> void:
	print("TESTE fruta resultado %d pontos %d atributo %d" % [r, pontos, atributo])
	var nome := DicaItem.t(CaixaFruta.NOMES[clampi(atributo, 0, 4)])
	var k: String = ["energia", "vitalidade", "agilidade", "forca", "comando"][clampi(atributo, 0, 4)]
	var t := ""
	match r:
		0:
			DicaItem.eu[k] = int(DicaItem.eu.get(k, 0)) + pontos
			t = DicaItem.t(379) % [nome, pontos, DicaItem.t(1412)]
			_som("comer")
		3, 6:
			DicaItem.eu[k] = maxi(int(DicaItem.eu.get(k, 0)) - pontos, 0)
			meus_pontos += pontos
			t = DicaItem.t(379) % [nome, pontos, DicaItem.t(1903)]
			_som("comer")
		1:
			t = DicaItem.t(378)
		2, 5, 8:
			t = DicaItem.t(1904) % DicaItem.t(1412 if r == 2 else 1903)
		4, 7:
			t = DicaItem.t(1906)
		0x10:
			t = DicaItem.t(1909)
		0x21, 0x25:
			t = DicaItem.t(1911)
		0x26:
			t = DicaItem.t(1912)
		_:
			t = "A fruta nao foi usada (codigo %d)." % r
	_msg("[color=%s]%s[/color]" % ["#9fe0a0" if r in [0, 3, 6] else "#e8b04a", t])
	_hud_nivel()


# C1 48: efeito numa pessoa (3 pocao de SD, 16 subiu de nivel, 17 o SD acabou)
func _mostrar_efeito(quem: int, e: int) -> void:
	print("TESTE efeito %d em %d" % [e, quem])
	var ent: Entidade = entidades.get(quem)
	if ent == null or mundo == null:
		return
	match e:
		3:
			EfeitoMU.escudo(mundo, ent, false)
		16:
			if quem != cli.meu_id:   # o meu ja sai no C3 05 (subiu de nivel)
				EfeitoMU.subiu_nivel(mundo, ent, false)
				_som("subiu_nivel")
		17:
			EfeitoMU.escudo(mundo, ent, true)
			_som("escudo_quebrou")


func _som(nome: String) -> void:
	if som:
		som.tocar(nome)


# a fila de buffs anda pra esquerda quando abre janela na direita (inventario, personagem, loja...)
func _livre_buffs() -> void:
	if janela_buffs == null:
		return
	var v := get_viewport().get_visible_rect().size
	var x := v.x
	for c in hud.get_children():
		if c is Control and c.visible and c not in [barra_mu, janela_buffs, janela_grupo, minimapa, caixa_fruta] \
				and c.global_position.x >= v.x * 0.3 and c.size.y * c.scale.y >= v.y * 0.5:
			x = minf(x, c.global_position.x)
	janela_buffs.livre = x * 640.0 / v.x
	janela_buffs.queue_redraw()
	if janela_grupo.livre != janela_buffs.livre:
		janela_grupo.livre = janela_buffs.livre
		janela_grupo.queue_redraw()


# --- guilda (rodada 7) -------------------------------------------------------------

func _ligar_guilda() -> void:
	cli.guilda_pedido_entrar.connect(func(id):
		var n: String = entidades[id].nome if entidades.has(id) else "?"
		print("TESTE guilda: %s pediu pra entrar" % n)
		_caixa_mu([n, DicaItem.t(429)], func(ok, _t): cli.responder_guilda(ok, id)))
	cli.guilda_resposta.connect(func(r):
		print("TESTE guilda resposta %d" % r)
		var t := {0: "O mestre da guilda recusou o pedido.", 1: "Voce entrou na guilda.", 2: "A guilda esta cheia.",
			3: "O jogador saiu do jogo.", 4: DicaItem.t(507), 5: DicaItem.t(518), 6: "O mestre da guilda esta ocupado.",
			7: "So personagem do nivel 6 pra cima entra numa guilda."}
		_msg("[color=%s]%s[/color]" % ["#9fe0a0" if r == 1 else "#e8b04a", t.get(r, "Guilda: resposta %d." % r)])
		if r == 1 and janela_guilda.visible:
			cli.pedir_lista_guilda())
	cli.guilda_lista.connect(func(i):
		print("TESTE guilda lista %s pontos %d rival '%s': %s" % [i.em_guilda, i.pontos, i.rival,
			i.membros.map(func(m): return "%s %d %s" % [m.nome, m.cargo, "on" if m.online else "off"])])
		janela_guilda.guilda = minha_guilda
		janela_guilda.meu_cargo = meu_cargo_guilda
		janela_guilda.definir(i)
		_relacoes())
	cli.guilda_saiu.connect(func(r):
		print("TESTE guilda saiu %d" % r)
		var t := {0: DicaItem.t(401), 1: "Voce saiu da guilda.", 2: "So o mestre desfaz a guilda.", 3: "Nao deu pra sair da guilda.",
			4: "A guilda foi desfeita.", 5: "O membro saiu da guilda."}
		_msg("[color=%s]%s[/color]" % ["#e8b04a" if r in [0, 2, 3] else "#9fe0a0", t.get(r, "Guilda: %d." % r)])
		if r in [1, 4]:
			_sem_guilda(cli.meu_id)
		elif r == 5:
			cli.pedir_lista_guilda())
	cli.guilda_criar_janela.connect(func():
		print("TESTE guilda: janela de criar")
		_fechar_loja()
		criar_guilda.abrir())
	cli.guilda_criar_dialogo.connect(func():
		print("TESTE guilda: dialogo de criar (C1 55)")
		if not criar_guilda.visible:
			criar_guilda.abrir()
		if criar_guilda.passo == JanelaCriarGuilda.INFO:
			criar_guilda.ir(JanelaCriarGuilda.MARCA))
	cli.bau_fechou.connect(func():
		print("TESTE bau fechado pelo servidor")
		if _janela_npc == 2:
			_fechar_loja(false))
	cli.guilda_criada.connect(func(ok, erro):
		print("TESTE guilda criada %s erro %d" % [ok, erro])
		if ok:
			criar_guilda.fechar(false)
			_msg("[color=#9fe0a0]%s[/color]" % ("Guilda %s criada." % criar_guilda.nome() if criar_guilda.nome() != "" else "Guilda criada."))
		else:
			var t := {0: 516, 179: 516, 2: 517, 3: 518, 4: 940, 5: 941}
			_msg("[color=#e8b04a]%s[/color]" % (DicaItem.t(t[erro]) if t.has(erro) else "A guilda nao foi criada (%d)." % erro)))
	cli.guilda_jogador_saiu.connect(func(id, _mestre):
		print("TESTE guilda: %d saiu da guilda" % id)
		_sem_guilda(id)
		if janela_guilda.visible and minha_guilda >= 0:
			cli.pedir_lista_guilda())
	cli.guilda_jogadores.connect(func(l):
		print("TESTE guilda jogadores %s" % [l.map(func(x): return "%d g%d c%d" % [x.id, x.guilda, x.cargo])])
		for x: Dictionary in l:
			if x.id == cli.meu_id:
				minha_guilda = x.guilda
				meu_cargo_guilda = x.cargo
				janela_guilda.guilda = x.guilda
				janela_guilda.meu_cargo = x.cargo
				janela_guilda.em_guilda = true
			if entidades.has(x.id):
				var e: Entidade = entidades[x.id]
				e.guilda = x.guilda
				e.guilda_cargo = x.cargo
				e.guilda_relacao = x.relacao
				e.marca_guilda()
				_relacao_de(e)
			if not Guildas.info.has(x.guilda) and not _guildas_pedidas.has(x.guilda):
				_guildas_pedidas[x.guilda] = true
				cli.pedir_info_guilda(x.guilda))
	cli.guilda_info.connect(func(i):
		print("TESTE guilda info %d %s alianca '%s' logo %s" % [i.id, i.nome, i.alianca, i.logo.hex_encode()])
		Guildas.guardar(i)
		for e: Entidade in entidades.values():
			if is_instance_valid(e) and e.guilda == i.id:
				e.marca_guilda()
		if i.id == minha_guilda:
			var antes := janela_guilda.alianca
			janela_guilda.alianca = i.alianca
			if janela_guilda.visible and janela_guilda.aba == 2 and i.alianca != "":
				cli.pedir_alianca()
			elif i.alianca == "":
				janela_guilda.aliadas = []
			if antes != i.alianca:
				print("TESTE guilda alianca agora '%s'" % i.alianca)
		_relacoes()
		janela_guilda.queue_redraw())


func _sem_guilda(id: int) -> void:
	if id == cli.meu_id:
		minha_guilda = -1
		meu_cargo_guilda = 255
		janela_guilda.limpar()
	if entidades.has(id):
		var e: Entidade = entidades[id]
		e.guilda = -1
		e.guilda_cargo = 255
		e.marca_guilda()


func _alternar_guilda() -> void:
	janela_guilda.visible = not janela_guilda.visible
	if not janela_guilda.visible:
		return
	for j in [inv, janela_personagem, comandos]:
		if j.visible:
			j.alternar()
	amigos.visible = false
	janela_guilda.meu_nome = meu_nome
	janela_guilda.nivel = meu_nivel
	janela_guilda.comando = int(DicaItem.eu.get("comando", 0))
	janela_guilda.dark_lord = (minha_classe >> 2) == 4
	janela_guilda.guilda = minha_guilda
	janela_guilda.meu_cargo = meu_cargo_guilda
	janela_guilda.em_guilda = minha_guilda >= 0
	janela_guilda.aba = 1
	janela_guilda.queue_redraw()
	cli.pedir_lista_guilda()


# caixa de mensagem do cliente (CaixaMU); com --aceitar responde OK sozinha (senha vazia, ou --senha_guilda X)
func _caixa_mu(linhas: Array, resposta: Callable, senha := false, cancelar := true) -> CaixaMU:
	var c := CaixaMU.new(linhas, cancelar, senha)
	print("TESTE caixa %s" % [linhas.map(func(l): return l[0] if l is Array else l)])
	c.respondeu.connect(resposta)
	hud.add_child(c)
	if _parametros().has("aceitar") and cancelar:
		if senha:
			c._campo.text = str(_parametros().get("senha_guilda", ""))
		c.responder(true)
	return c


func _senha_guilda(linhas: Array, nome: String) -> void:
	_caixa_mu(linhas, func(ok, t):
		# o cliente original barra a senha vazia (401); o OpenMU guarda o SecurityCode das contas como "" e so aceita
		# vazio nelas, entao a caixa manda o que foi digitado
		if not ok:
			return
		print("TESTE guilda: tirando %s" % nome)
		cli.tirar_da_guilda(nome, t), true)


func _sair_da_guilda() -> void:
	var senha := DicaItem.t(428).replace("WEBZEN.COM ", "")
	if meu_cargo_guilda == 128:
		_caixa_mu([DicaItem.t(1363), DicaItem.t(1364), DicaItem.t(1365), DicaItem.t(1366)], func(ok, _t):
			if ok:
				_senha_guilda([senha], meu_nome))
	else:
		_senha_guilda([DicaItem.t(427), senha], meu_nome)


func _acao_membro_guilda(acao: int, nome: String, cargo: int) -> void:
	print("TESTE guilda acao %d em %s (cargo %d)" % [acao, nome, cargo])
	if nome == meu_nome:
		return
	match acao:
		0:
			if cargo == 128:
				return
			var c := _caixa_mu([DicaItem.t(1315)], func(_ok, _t): pass)
			c.escolhas = [DicaItem.t(1311), DicaItem.t(1312)]
			c._ajustar()
			c.escolheu.connect(func(i):
				if i >= 0:
					cli.cargo_guilda(1 if cargo == 0 else 2, [64, 32][i], nome)
					get_tree().create_timer(0.5).timeout.connect(cli.pedir_lista_guilda))
		1:
			if not cargo in [32, 64]:
				return
			_caixa_mu([DicaItem.t(1486) % nome, DicaItem.t(1368)], func(ok, _t):
				if ok:
					cli.cargo_guilda(3, 0, nome)
					get_tree().create_timer(0.5).timeout.connect(cli.pedir_lista_guilda))
		2:
			_caixa_mu([DicaItem.t(1486) % nome, DicaItem.t(1369)], func(ok, _t):
				if ok:
					_senha_guilda([DicaItem.t(428).replace("WEBZEN.COM ", "")], nome))


# roteiro G: G:criar,Nome (pinta uma marca de teste e cria), G:pintar,Nome (so pinta), G:abrir, G:aba,N, G:sair, G:tirar,Nome, G:cargo,Nome,0|1,
# G:tira_cargo,Nome, G:entrar,Mestre (o comando GUILDA da janela D); rodada 8: G:alianca,Mestre, G:rival,Mestre,
# G:fim_rival,Mestre (botoes da janela D), G:tirar_alianca,Guilda e G:sair_alianca (botoes da aba Alliance)
func _teste_guilda(v: Array) -> void:
	print("TESTE roteiro guilda %s" % [v])
	match v[0]:
		"criar", "pintar":
			# pintar: so pinta e fica no passo da marca (foto); criar segue ate o resumo e cria
			if not criar_guilda.visible:
				print("TESTE roteiro guilda: a janela de criar nao abriu")
				return
			criar_guilda.avancar()
			criar_guilda.definir_nome(v[1])
			# moldura amarela, cruz vermelha e o centro azul
			for i in 64:
				var x := i % 8
				var y := i / 8
				var c := 0
				if x == 0 or y == 0 or x == 7 or y == 7:
					c = 6
				elif x == y or x == 7 - y:
					c = 4
				elif x in [3, 4] or y in [3, 4]:
					c = 11
				criar_guilda.pintar(i, c)
			criar_guilda.cor = 6
			if v[0] == "pintar":
				return
			criar_guilda.avancar()
			await get_tree().create_timer(1.0).timeout
			criar_guilda.avancar()
		"abrir":
			if not janela_guilda.visible:
				_alternar_guilda()
		"fechar":
			janela_guilda.visible = false
		"aba":
			janela_guilda.aba = int(v[1])
			if janela_guilda.aba == 2 and janela_guilda.alianca != "":
				cli.pedir_alianca()
			janela_guilda.queue_redraw()
		"sair":
			_sair_da_guilda()
		"tirar":
			_acao_membro_guilda(2, v[1], 0)
		"cargo":
			for m: Dictionary in janela_guilda.membros:
				if m.nome == v[1]:
					cli.cargo_guilda(1 if int(m.cargo) == 0 else 2, [64, 32][int(v[2])], v[1])
			get_tree().create_timer(0.5).timeout.connect(cli.pedir_lista_guilda)
		"tira_cargo":
			_acao_membro_guilda(1, v[1], 64)
		"entrar", "alianca", "rival", "fim_rival":
			var cmd: int = {"entrar": JanelaComandos.GUILDA, "alianca": JanelaComandos.ALIANCA, "rival": JanelaComandos.RIVAL,
				"fim_rival": JanelaComandos.FIM_RIVAL}[v[0]]
			for e: Entidade in entidades.values():
				if e.nome == v[1]:
					_comando(cmd, e.id)
		"tirar_alianca":
			_tirar_da_alianca(v[1])
		"sair_alianca":
			_sair_da_alianca()


# --- guilda 2: alianca, rival, guerra e Battle Soccer (rodada 8) ----------------------

func _ligar_guilda2() -> void:
	cli.relacao_pedido.connect(func(tipo, pedido, id):
		# ReceiveGuildRelationShip: caixa de OK e Cancel com tres linhas; com outra caixa aberta recusa sozinha
		var n: String = entidades[id].nome if entidades.has(id) else "?"
		print("TESTE guilda relacao: %s pediu %d/%d" % [n, tipo, pedido])
		var l := [DicaItem.t(1280) % n, DicaItem.t(1281 if pedido == 1 else 1282), DicaItem.t(1283)]
		if tipo == 2:
			l = [DicaItem.t(1284) % n, DicaItem.t(1286 if pedido == 1 else 1285), DicaItem.t(1283)]
		for c in hud.get_children():
			if c is CaixaMU and not c.is_queued_for_deletion():
				cli.responder_relacao(tipo, pedido, false, id)
				return
		_caixa_mu(l, func(ok, _t): cli.responder_relacao(tipo, pedido, ok, id)))
	cli.relacao_resultado.connect(func(tipo, pedido, r, _id):
		print("TESTE guilda relacao resultado %d/%d: %d" % [tipo, pedido, r])
		var t := ""
		if r == 1:
			t = DicaItem.t((1381 if pedido == 1 else 1382) if tipo == 1 else (1383 if pedido == 1 else 1384))
		else:
			var erros := {0: 1328, 0x10: 1637, 0x11: 1386, 0x15: 1250, 0x16: 1251, 0x17: 1252, 0x18: 1253, 0x19: 1254,
				0x1A: 1255, 0x1B: 1333, 0x1C: 1329, 0x1D: 1331, 0x1E: 1287, 0x20: 1268, 0xA1: 2991, 0xA2: 2992, 0xA3: 2993}
			t = DicaItem.t(erros[r]) if erros.has(r) else "Guilda: resposta %d." % r
		_msg("[color=%s]%s[/color]" % ["#9fe0a0" if r == 1 else "#e8b04a", t])
		# o rival so chega no C2 52; a alianca chega no C1 66 que o servidor manda de novo
		if r == 1:
			cli.pedir_lista_guilda())
	cli.alianca_lista.connect(func(ok, rivais, aliadas, l):
		print("TESTE guilda alianca lista ok %s rivais %d aliadas %d: %s" % [ok, rivais, aliadas,
			l.map(func(g): return "%s %d" % [g.nome, g.membros])])
		janela_guilda.definir_alianca(l if ok else []))
	cli.alianca_tirou.connect(func(r, _pedido, _tipo):
		print("TESTE guilda alianca tirou %d" % r)
		if r == 1:
			_msg("[color=#9fe0a0]%s[/color]" % DicaItem.t(1382))
			if janela_guilda.aliadas.size() > 2:
				cli.pedir_alianca()
			else:
				janela_guilda.aliadas = []
				janela_guilda.queue_redraw()
		else:
			_msg("[color=#e8b04a]%s[/color]" % DicaItem.t(1328)))
	cli.guerra_resultado.connect(func(r):
		print("TESTE guerra resultado %d" % r)
		_msg("[color=%s]%s[/color]" % ["#9fe0a0" if r == 1 else "#e8b04a", DicaItem.t(519 + r) if r <= 6 else "Guerra: %d." % r]))
	cli.guerra_pedido.connect(func(g, tipo):
		print("TESTE guerra: %s chamou (tipo %d)" % [g, tipo])
		_caixa_mu([DicaItem.t(430) % g, DicaItem.t(432 if tipo == 1 else 431)], func(ok, _t):
			print("TESTE guerra: respondi %s" % ok)
			cli.responder_guerra(ok)))
	cli.guerra_comecou.connect(func(g, tipo, time):
		print("TESTE guerra comecou contra %s tipo %d time %d" % [g, tipo, time])
		guerra = {"guilda": g, "tipo": tipo, "time": time, "meu": 0, "dele": 0}
		_aviso(DicaItem.t(526 if tipo == 0 else 533) % g)
		_relacoes()
		_placar())
	cli.guerra_placar.connect(func(meu, dele, _tipo):
		print("TESTE guerra placar %d x %d" % [meu, dele])
		if not guerra.is_empty():
			guerra.meu = meu
			guerra.dele = dele
			_placar())
	cli.guerra_fim.connect(func(r, g):
		print("TESTE guerra fim %d contra %s" % [r, g])
		_aviso(DicaItem.t(527 + r) if r <= 5 else DicaItem.t(480))
		guerra = {}
		placar.visible = false
		if alvo_id >= 0 and entidades.has(alvo_id) and entidades[alvo_id].tipo == "jogador":
			alvo_id = -1
		_relacoes())
	cli.futebol_placar.connect(func(v, gv, a, ga):
		print("TESTE futebol placar %s %d x %d %s" % [v, gv, ga, a])
		if gv == 255:
			placar.visible = false
		else:
			placar.futebol(v, gv, a, ga))


# aviso no meio da tela (o CreateNotice do original) e no registro
func _aviso(t: String) -> void:
	_msg("[color=#ffd060]%s[/color]" % t)
	_mostrar_aviso(t)


func _placar() -> void:
	if guerra.is_empty():
		placar.visible = false
		return
	placar.guerra(Guildas.nome(minha_guilda), Guildas.tex(minha_guilda), guerra.meu, guerra.guilda,
		Guildas.tex(_guilda_por_nome(guerra.guilda)), guerra.dele, guerra.time)


func _guilda_por_nome(n: String) -> int:
	for id in Guildas.info:
		if Guildas.info[id].nome == n:
			return id
	return -1


# o jogador e da guilda com quem estou em guerra (GuildTeam 2): ataca com o clique, sem Ctrl
func inimigo_da_guerra(e: Entidade) -> bool:
	return not guerra.is_empty() and e.tipo == "jogador" and e.guilda >= 0 and Guildas.nome(e.guilda) == guerra.guilda


# GR_* de cada jogador visto: o OpenMU nao manda a relacao no C2 65, entao sai do nome da alianca (C1 66)
# e do rival da minha guilda (C2 52)
func _relacoes() -> void:
	for e: Entidade in entidades.values():
		if is_instance_valid(e) and e.tipo in ["eu", "jogador"]:
			_relacao_de(e)


func _relacao_de(e: Entidade) -> void:
	var r := e.guilda_relacao
	if e.guilda >= 0 and Guildas.info.has(e.guilda):
		var g: Dictionary = Guildas.info[e.guilda]
		var minha_alianca: String = Guildas.info[minha_guilda].alianca if Guildas.info.has(minha_guilda) else ""
		if g.alianca != "" and (g.alianca == minha_alianca or e.guilda == minha_guilda):
			r |= 1
			if g.alianca == g.nome:
				r |= 4
		var rival := janela_guilda.rival
		if rival != "" and e.guilda != minha_guilda:
			if g.nome == rival:
				r |= 2
			else:
				var gr := _guilda_por_nome(rival)
				if gr >= 0 and Guildas.info[gr].alianca != "" and Guildas.info[gr].alianca == g.alianca:
					r |= 8
	e.guilda_rel = r


func _tirar_da_alianca(nome: String) -> void:
	_caixa_mu([DicaItem.t(1423) % nome, DicaItem.t(1369)], func(ok, _t):
		if ok:
			print("TESTE guilda: tirando %s da alianca" % nome)
			cli.tirar_da_alianca(nome))


func _sair_da_alianca() -> void:
	if janela_guilda.sou_mestre_da_alianca():
		_caixa_mu([DicaItem.t(1271)], func(_ok, _t): pass, false, false)
		return
	print("TESTE guilda: saindo da alianca")
	cli.pedir_relacao(1, 2, cli.meu_id)


# aviso grande no alto da tela por 5 s (guerra comecou e acabou)
var _rotulo_aviso: Label


func _mostrar_aviso(t: String) -> void:
	if _rotulo_aviso == null:
		_rotulo_aviso = Label.new()
		_rotulo_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rotulo_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rotulo_aviso.add_theme_color_override("font_color", Color8(255, 220, 90))
		_rotulo_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_rotulo_aviso.add_theme_constant_override("outline_size", 4)
		hud.add_child(_rotulo_aviso)
	var v := get_viewport().get_visible_rect().size
	_rotulo_aviso.add_theme_font_size_override("font_size", int(13 * v.x / 640.0))
	_rotulo_aviso.text = t
	_rotulo_aviso.position = Vector2(0, 110 * v.y / 480.0)
	_rotulo_aviso.size = Vector2(v.x, 30)
	_rotulo_aviso.modulate.a = 1.0
	_rotulo_aviso.visible = true
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(_rotulo_aviso, "modulate:a", 0.0, 1.0)


# a bola do Battle Soccer (Arena): nao morre, anda 2 tiles (3 com skill) pro lado oposto de quem bate
func bola(e: Entidade) -> bool:
	return e != null and e.tipo == "outro" and e.nome == "Soccerball"


# roteiro F: fica atras da bola e bate nela ate entrar no gol; o time 1 (quem chamou) faz gol no de cima
# (y 139 e 140, Arena do OpenMU), o time 0 no de baixo (y 181 e 182)
func _chutar_bola() -> void:
	var b: Entidade = null
	for e: Entidade in entidades.values():
		if bola(e):
			b = e
	if guerra.is_empty() or eu.andando():
		return
	if b == null:
		# depois do gol a bola volta pro meio, longe da vista: anda pra onde ela estava no comeco
		if _bola_inicio.x >= 0 and _repensar <= 0.0:
			_repensar = 1.0
			andar_ate(_bola_inicio)
		return
	if _bola_inicio.x < 0:
		_bola_inicio = b.tile
	var lado := -1 if int(guerra.time) == 1 else 1
	var ponto := b.tile - Vector2i(0, lado)
	if eu.tile != ponto:
		if _repensar <= 0.0:
			_repensar = 0.5
			andar_ate(ponto)
		return
	if _recarga > 0.0:
		return
	_recarga = RECARGA
	eu.olhar_para(b)
	print("TESTE chutando a bola em %s" % b.tile)
	cli.atacar(b.id, 38, maxi(ClienteMU.PASSOS.find(Vector2i(0, lado)), 0))


# --- Gens (rodada 9) ---------------------------------------------------------------

# respostas do servidor viram o estado da conversa do NPC (ProcessGens*Receive)
const _GENS_ENTROU := {0: 5, 1: 9, 2: 11, 3: 8, 4: 10, 5: 12, 6: 18, 7: 19}
const _GENS_SAIU := {0: 16, 1: 15, 2: 14, 3: 17}
const _GENS_PREMIO := {0: 20, 1: 21, 2: 22, 3: 23, 4: 24, 5: 17, 6: 25}


func _ligar_gens() -> void:
	cli.gens_entrou.connect(func(r, g):
		print("TESTE gens entrou %d no %d" % [r, g])
		if r == 0:
			_minha_gens(g, 14, 0)
			cli.gens_pedir_info()
		_estado_gens(_GENS_ENTROU.get(r, 6)))
	cli.gens_saiu.connect(func(r):
		print("TESTE gens saiu %d" % r)
		if r == 0:
			_minha_gens(0, 0, 0)
			janela_gens.visible = false
		_estado_gens(_GENS_SAIU.get(r, 7)))
	cli.gens_premio.connect(func(r):
		print("TESTE gens premio %d" % r)
		_estado_gens(_GENS_PREMIO.get(r, 22)))
	cli.gens_info.connect(func(i):
		print("TESTE gens info %s" % i)
		_minha_gens(i.gens, i.titulo, i.contribuicao)
		janela_gens.definir(i))
	cli.gens_jogadores.connect(func(l):
		print("TESTE gens jogadores %s" % [l.map(func(x): return "%d g%d t%d c%d" % [x.id, x.gens, x.titulo, x.contribuicao])])
		for x: Dictionary in l:
			_gens_vistos[x.id] = x
			if entidades.has(x.id):
				_gens_de(entidades[x.id], x))


func _estado_gens(n: int) -> void:
	if dialogo.visible:
		dialogo.estado(n)


func _minha_gens(g: int, titulo: int, contribuicao: int) -> void:
	minha_gens = g
	dialogo.minha_gens = g
	dialogo.contribuicao = contribuicao
	dialogo.queue_redraw()
	if eu:
		eu.gens = g
		eu.gens_titulo = titulo
		eu.gens_contribuicao = contribuicao


func _gens_de(e: Entidade, x: Dictionary) -> void:
	e.gens = x.gens
	e.gens_titulo = x.titulo
	e.gens_contribuicao = x.contribuicao


# tecla B: sem Gens so avisa (3094); abrir pede a info (F8 0B)
func _alternar_gens() -> void:
	if minha_gens == 0:
		_msg("[color=#e8b04a]%s[/color]" % DicaItem.t(3094))
		janela_gens.visible = false
		return
	janela_gens.visible = not janela_gens.visible
	print("TESTE janela gens %s" % janela_gens.visible)
	if janela_gens.visible:
		for j in [inv, janela_personagem, comandos]:
			if j.visible:
				j.alternar()
		janela_guilda.visible = false
		amigos.visible = false
		cli.gens_pedir_info()


# Vulcanus (WD_63PK_FIELD, IsStrifeMap): o jogador do outro Gens e alvo com o clique; da mesma guilda ou do
# grupo so com Ctrl (o clique normal nao pega)
func inimigo_gens(e: Entidade) -> bool:
	if mapa_atual != 63 or e == null or e.tipo != "jogador" or e.gens == minha_gens:
		return false
	var amigo := (e.guilda >= 0 and e.guilda == minha_guilda) or (janela_grupo and janela_grupo.passo_de(e.nome) >= 0)
	return not amigo


# --- rodada 25: os 14 que faltavam ---------------------------------------------------

const MAPA_CASTELO := 30          # Valley of Loren
var janela_gatekeeper: JanelaGatekeeper
var janela_arqueiro: JanelaArqueiro
var chat_comandos: JanelaChatComandos
var relogio_futebol: Label
var quests_de_evento: Array = []  # C1 F6 03: [grupo, numero] (SetQuestIndexByEtcList)
var _marca_castelo := PackedByteArray()
var _teclas_servidor := PackedByteArray()
var _pediu_comandos := false
var _aplicando_teclas := false


func _ligar_rodada25() -> void:
	# Gatekeeper do Valley of Loren (NPC 220): C1 B9 03 abre, B9 05, B2 1F e B2 09 tipo 3 respondem
	janela_gatekeeper = JanelaGatekeeper.new()
	janela_gatekeeper.fechou.connect(func(): _fechar_loja())
	janela_gatekeeper.entrar.connect(func(p):
		print("TESTE gatekeeper entrar %d" % p)
		cli.cacada_entrar_pedir(p))
	janela_gatekeeper.publico.connect(func(sim):
		print("TESTE gatekeeper publico %s" % sim)
		cli.cacada_publico(sim))
	janela_gatekeeper.mudar_preco.connect(func(p):
		print("TESTE gatekeeper preco %d" % p)
		cli.cacada_preco(p))
	janela_gatekeeper.sem_zen.connect(func(): _caixa_mu([DicaItem.t(1628)], func(_o, _t): pass, false, false))
	hud.add_child(janela_gatekeeper)
	cli.cacada_info.connect(func(r, pub, preco, mx, passo):
		if r == 0:
			# CGatemanFailMsgBoxLayout
			print("TESTE gatekeeper falhou")
			_caixa_mu(["Request has failed."], func(_o, _t): pass, false, false)
			return
		janela_gatekeeper.meu_zen = meu_zen
		hud.move_child(janela_gatekeeper, -1)
		janela_gatekeeper.abrir(r, pub, preco, mx, passo))
	cli.cacada_entrar.connect(func(r):
		print("TESTE gatekeeper entrar resultado %d" % r)
		if r == 0:
			_caixa_mu(["Request has failed."], func(_o, _t): pass, false, false))
	cli.cs_resposta.connect(func(sub, info):
		# C1 B2 1F (ReceiveHuntZoneEnter): 1 = a entrada mudou, 2 = sem autorizacao
		if sub == 0x1F:
			if int(info.get("resultado", 0)) == 1:
				janela_gatekeeper.mudou_publico(bool(info.get("publico", false)))
			elif int(info.get("resultado", 0)) == 2:
				_caixa_mu([DicaItem.t(1386)], func(_o, _t): pass, false, false))
	# Golden Archer (NPC 236): C1 94 resultado 0 abre ou atualiza; outro resultado e o HideAll do cliente
	janela_arqueiro = JanelaArqueiro.new()
	janela_arqueiro.itens = inv.itens
	janela_arqueiro.nome = monstros.get("236", ["Golden Archer"])[0]
	janela_arqueiro.registrar.connect(func(casa):
		print("TESTE arqueiro registrar casa %d" % casa)
		cli.registrar_ficha(0, casa))
	janela_arqueiro.fechou.connect(func():
		cli.fechar_fichas()
		npc_falando = -1)
	hud.add_child(janela_arqueiro)
	cli.fichas.connect(func(r, reg, mochila):
		print("TESTE fichas resultado %d registradas %d mochila %d" % [r, reg, mochila])
		janela_arqueiro.itens = inv.itens
		if r == 0:
			hud.move_child(janela_arqueiro, -1)
			janela_arqueiro.abrir(reg)
		else:
			janela_arqueiro.visible = false)
	# comandos de chat (J): a lista chega um por pacote; executar manda a linha como chat publico
	chat_comandos = JanelaChatComandos.new()
	chat_comandos.executar.connect(func(linha):
		cli.dizer(meu_nome, linha))
	hud.add_child(chat_comandos)
	cli.comando_chat.connect(func(i, total, cmd):
		chat_comandos.receber(i, total, cmd)
		if i == total - 1:
			print("TESTE comandos chat %d: %s" % [total, ", ".join(chat_comandos.comandos.map(func(c): return c.comando))]))
	# relogio do Battle Soccer (C1 F3 22, RenderMatchTimes): so com 10 minutos ou menos, grande no 350 de 480,
	# vermelho e amarelo no ultimo minuto; 1390 com os segundos de um digito, 1391 com dois
	relogio_futebol = Label.new()
	relogio_futebol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relogio_futebol.set_anchors_preset(Control.PRESET_TOP_WIDE)
	relogio_futebol.add_theme_constant_override("outline_size", 4)
	relogio_futebol.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	relogio_futebol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relogio_futebol.visible = false
	hud.add_child(relogio_futebol)
	cli.futebol_tempo.connect(_tempo_futebol)
	# o resto: teclas guardadas, foco na selecao, invasao, skill de monstro, Nova, Chain Lightning, quests de evento,
	# Life Stone e a marca do castelo
	cli.teclas.connect(func(cfg):
		print("TESTE teclas do servidor %s" % cfg.hex_encode())
		_teclas_servidor = cfg
		_aplicar_teclas(cfg))
	cli.personagem_foco.connect(func(nome):
		print("TESTE foco confirmado %s" % nome)
		if selecao and is_instance_valid(selecao):
			selecao.foco_confirmado(nome))
	cli.evento_mapa.connect(func(ligado, ev):
		print("TESTE invasao %s evento %d" % [ligado, ev])
		Bichos.evento = ev if ligado and ev in [1, 3] else 0)
	cli.skill_monstro.connect(_skill_monstro)
	cli.estagio_skill.connect(func(id, skill, estagio):
		print("TESTE nova estagio %d skill %d de %d" % [estagio, skill, id])
		if entidades.has(id):
			entidades[id].set_meta("nova_estagio", estagio))
	cli.corrente.connect(_corrente)
	cli.quests_evento.connect(func(l):
		quests_de_evento = l
		print("TESTE quests de evento %s" % [l]))
	cli.pedra_vida.connect(_pedra_vida)
	cli.marca_castelo.connect(func(marca):
		_marca_castelo = marca
		var n := 0
		if mundo and mapa_atual == MAPA_CASTELO:
			n = mundo.marca_castelo(marca)
		print("TESTE marca castelo %s bandeiras %d" % [marca.hex_encode().left(16), n]))


func _tempo_futebol(seg: int) -> void:
	var m := seg / 60
	var s := seg % 60
	print("TESTE futebol tempo %d" % seg)
	if seg <= 0 or m > 10:
		relogio_futebol.visible = false
		return
	var k := hud.size.y / 480.0
	relogio_futebol.text = (DicaItem.t(1390) if s < 10 else DicaItem.t(1391)) % [m, s]
	relogio_futebol.add_theme_font_size_override("font_size", int(20 * k))
	relogio_futebol.add_theme_color_override("font_color", Color8(255, 255, 10) if seg < 60 else Color8(255, 10, 10))
	relogio_futebol.position.y = 350 * k - relogio_futebol.get_combined_minimum_size().y / 2.0
	relogio_futebol.visible = true


# C1 69 (ReceiveMonsterSkill + CheckMonsterSkill): o monstro vira pro alvo e toca o ataque da posicao da skill
# na lista dele (MonsterSkill.bmd: 0 ATTACK1 ... 4 a 9 ATTACK5); a Maya (364) passa pro MayaSceneMayaAction
var _skills_monstro := {}


func _skill_monstro(skill: int, id: int, alvo: int, ok: bool) -> void:
	print("TESTE skill monstro %d de %d em %d %s" % [skill, id, alvo, "acertou" if ok else "errou"])
	if not entidades.has(id):
		return
	var e: Entidade = entidades[id]
	if e.numero == 364 and kanturu:
		kanturu.ataque_maya(skill & 0xFF)
		return
	if _skills_monstro.is_empty():
		_skills_monstro = _json("res://dados/monstro_skills.json")
	var l: Array = _skills_monstro.get(str(e.numero), [])
	var i := l.find(skill)
	var acao: String = ["ataque", "ataque2", "ataque3", "ataque4"][i] if i >= 0 and i < 4 else ("ataque5" if i >= 4 else "ataque")
	var a: Entidade = entidades.get(alvo, e)
	e.tocar_skill(acao, a.position)


# C1 BF 0A (ReceiveChainMagic): quem lanca toca a acao da Chain Lightning e o raio pula de alvo em alvo
func _corrente(skill: int, id: int, alvos: Array) -> void:
	print("TESTE corrente skill %d de %d em %s" % [skill, id, alvos])
	if mundo == null or not entidades.has(id):
		return
	var e: Entidade = entidades[id]
	var l: Array = []
	for a in alvos:
		if entidades.has(a):
			l.append(entidades[a])
	if l.is_empty():
		return
	e.tocar_skill(_acao_skill(skill), (l[0] as Entidade).position)
	if som:
		som.tocar("chain_lightning")
	EfeitoSkill.corrente(mundo, e, l)


# C1 B9 01 (ReceiveLifeStoneState): a Life Stone do Castle Siege sobe de 0 a 5. RenderBattleCastleCharacter:
# a malha 0 a partir do 2, a 2 do 3, a 1 do 4, a 3 e a 4 (somadas, correndo) no 5; a barra de obra (TextosMU)
# ate o 4 e a luz que pulsa no 5
func _pedra_vida(npc: int, estagio: int) -> void:
	print("TESTE pedra vida %d estagio %d" % [npc, estagio])
	if not entidades.has(npc):
		return
	var e: Entidade = entidades[npc]
	e.set_meta("pedra_estagio", estagio)
	var b := e.boneco
	if b == null:
		return
	var desde := {0: 2, 2: 3, 1: 4, 3: 5, 4: 5}
	for n in desde:
		var a: Array = b._superficie(n)
		if a.is_empty():
			continue
		if estagio >= desde[n]:
			(a[0] as MeshInstance3D).set_surface_override_material(a[1], null)
			if n >= 3:
				b.somar_malha(n)
		else:
			b.apagar_malha(n)
	if estagio >= 5 and not e.has_meta("pedra_aurora"):
		e.set_meta("pedra_aurora", true)
		var ef := EfeitoMU.criar(mundo)
		ef.tarefa(0.04, 3600.0, func(f, _i):
			if not is_instance_valid(e) or e.morto:
				return
			if _i % 25 == 0:
				EfeitoSkill.luz_chao(f, e.global_position, Color(0.3, 0.2, 0.0) * 3.0, 4.5, 1.1))


# F3 30 (ReceiveOption / SaveOptions): [0..19] as 10 skills em BE (FFFF vazio), [20] opcoes, [21..23] Q W E
# (indice da pocao no grupo 14), [24] chat, [25] R, [26..29] niveis R E W Q (LE32 do QWERLevel)
func _aplicar_teclas(cfg: PackedByteArray) -> void:
	if cfg.size() < 30 or cfg.count(0) == 30:
		return
	_aplicando_teclas = true
	var l: Array = barra_mu.atalhos.duplicate()
	l.resize(10)
	for i in 10:
		var n := (cfg[i * 2] << 8) | cfg[i * 2 + 1]
		l[i] = n if n != 0xFFFF and n in barra_mu.skills else -1
	barra_mu.atalhos = l
	for i in 4:
		var idx: int = cfg[[21, 22, 23, 25][i]]
		pocao_escolhida[i] = "" if idx == 0xFF else "14,%d" % idx
	barra_mu.queue_redraw()
	_contar_pocoes()
	_aplicando_teclas = false
	print("TESTE teclas aplicadas %s pocoes %s" % [l, pocao_escolhida])


func _guardar_teclas() -> void:
	if _aplicando_teclas or cli == null or barra_mu == null:
		return
	var c := PackedByteArray()
	c.resize(30)
	for i in 10:
		var n: int = barra_mu.atalhos[i] if i < barra_mu.atalhos.size() and barra_mu.atalhos[i] != null and barra_mu.atalhos[i] >= 0 else 0xFFFF
		c[i * 2] = (n >> 8) & 0xFF
		c[i * 2 + 1] = n & 0xFF
	if _teclas_servidor.size() >= 30:
		c[20] = _teclas_servidor[20]
		c[24] = _teclas_servidor[24]
	for i in 4:
		var p: String = pocao_escolhida[i]
		c[[21, 22, 23, 25][i]] = int(p.split(",")[1]) & 0xFF if p.begins_with("14,") else 0xFF
	_teclas_servidor = c
	cli.guardar_teclas(c)
