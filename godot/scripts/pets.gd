class_name Pets
extends Node
# Rodada 11: os pets do Dark Lord (giPetManager e CSPetSystem do cliente). O Dark Raven (13,5 na mao esquerda)
# vira um Corvo voando em volta de cada Dark Lord na tela; as 4 ordens (AT_PET_COMMAND 120 a 123) ficam na lista
# de skills e no Shift+1 a 4, e o botao direito manda o C1 A7; o C1 A7 de volta diz a ordem aceita (o quadrinho
# no alto da direita, RenderCmdType) e o C1 A8 faz o corvo de alguem atacar. A ficha do pet (C1 A9: nivel, exp,
# vida) vale pro corvo e pro Dark Horse: a janela do pet (botao Pet da janela C) e a caixa do item.

const CORVO := "13,5"
const CAVALO := "13,4"
const COMANDO := 120          # AT_PET_COMMAND_DEFAULT
const COMANDOS := 4           # normal, aleatorio, com o dono, alvo
const DL := 4                 # classe >> 2 do Dark Lord
const CAOS := [18, 19, 20, 21, 22, 23, 53]   # Chaos Castle: o cliente nao cria o corvo

# ficha do pet vestido (Hero->GetEquipedPetInfo): "13,5" e "13,4" -> {tipo, nivel, exp, vida} + o calculado
static var vestidos := {}
# a ultima ficha que chegou (gs_PetInfo): a do item com o mouse em cima
static var ficha := {}
# onde esta o item que a caixa vai mostrar: [armazem, slot] (quem chama DicaItem.linhas poe; vazio = sem ficha)
static var onde := []
static var pedir: Callable     # (tipo, armazem, slot): manda o C1 A9
static var _pedido := ""       # o ultimo item pedido (RequestPetInfo pede uma vez por item)

var jogo: Node
var cli: ClienteMU
var corvos := {}              # id da entidade -> Corvo
var comando := 0              # ordem aceita pelo servidor (m_byCommand)
var alvo := 0xFFFF
var janela: JanelaPet
var marca: Control            # o quadrinho da ordem no alto da direita
var _t := 0.0


func _init(j: Node, c: ClienteMU, hud: Control) -> void:
	jogo = j
	cli = c
	name = "Pets"
	pedir = func(tipo: int, armazem: int, slot: int): cli.pedir_info_pet(tipo, armazem, slot)
	janela = JanelaPet.new()
	hud.add_child(janela)
	marca = MarcaCorvo.new()
	marca.pets = self
	hud.add_child(marca)
	cli.pet_modo.connect(_modo)
	cli.pet_ataque.connect(_ataque)
	cli.pet_info.connect(_info)
	# depois da mochila guardar o item (ela ouve os mesmos sinais)
	cli.inventario.connect(func(_l): pedir_vestidos.call_deferred())
	cli.item_movido.connect(func(slot, _it, arm):
		if arm == 0 and slot in [1, 8]:
			pedir_vestidos.call_deferred())


func _exit_tree() -> void:
	pedir = Callable()   # o lambda segura o cliente numa variavel estatica


static func e_comando(n: int) -> bool:
	return n >= COMANDO and n < COMANDO + COMANDOS


static func nome_comando(n: int) -> String:
	return DicaItem.t(1219 + n - COMANDO)


# RenderPetCmdInfo: o nome e o que a ordem faz
static func dica_comando(n: int) -> String:
	return "%s  ·  %s" % [nome_comando(n), DicaItem.t(1223 + n - COMANDO)]


static func sou_dl() -> bool:
	return int(DicaItem.eu.get("classe", 0)) >> 2 == DL


func eu() -> Entidade:
	return jogo.eu if jogo and is_instance_valid(jogo.eu) else null


# Hero->m_pPet: tenho o corvo na mao esquerda
func tenho_corvo() -> bool:
	var e := eu()
	return e != null and e.boneco != null and e.boneco.vestido().get(1, "") == CORVO and sou_dl()


func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0 or jogo == null or jogo.mundo == null:
		return
	_t = 0.3
	# um corvo pra cada Dark Lord com o corvo na mao (fora do Chaos Castle)
	var caos: bool = int(jogo.mapa_atual) in CAOS
	for id in corvos.keys():
		var c: Corvo = corvos[id]
		var e: Entidade = jogo.entidades.get(id)
		if not is_instance_valid(c) or e == null or not is_instance_valid(e) or not _com_corvo(e) or caos or c.mundo != jogo.mundo:
			if is_instance_valid(c):
				c.queue_free()
			corvos.erase(id)
	if caos:
		return
	for e: Entidade in jogo.entidades.values():
		if is_instance_valid(e) and not corvos.has(e.id) and _com_corvo(e):
			var c := Corvo.novo(e, jogo.mundo, _som)
			if c:
				corvos[e.id] = c
				var f: Dictionary = vestidos.get(CORVO, {})
				c.nivel = f.get("nivel", 1) if e == eu() else 1
				print("TESTE corvo de %s" % e.nome)
	jogo.barra_mu.comandos_pet = tenho_corvo()


func _com_corvo(e: Entidade) -> bool:
	return e.tipo in ["eu", "jogador"] and e.boneco != null and e.skin == 0 and e.boneco.vestido().get(1, "") == CORVO


func _som(n: String) -> void:
	if jogo.som:
		jogo.som.tocar(n)


# --- ordens -----------------------------------------------------------------------------

# SendPetCommand: botao direito com uma ordem escolhida; "alvo" so manda com um monstro ou jogador no mouse
func mandar(n: int, e: Entidade) -> void:
	if not tenho_corvo():
		jogo._msg("[color=#9a9ab0]%s: vista o Dark Raven na mao esquerda.[/color]" % nome_comando(n))
		return
	var modo := n - COMANDO
	if modo == 3:
		if e == null or e.tipo not in ["monstro", "jogador"] or e.morto:
			jogo._msg("[color=#9a9ab0]%s: aponte num monstro e clique com o botao direito.[/color]" % nome_comando(n))
			return
		cli.comando_pet(0, modo, e.id)
	else:
		cli.comando_pet(0, modo)
	print("TESTE pet mandou %d alvo %d" % [modo, e.id if e and modo == 3 else 0xFFFF])


# C1 A7: a ordem que o servidor aceitou (SetCommand)
func _modo(_tipo: int, modo: int, a: int) -> void:
	print("TESTE pet modo %d alvo %d" % [modo, a])
	comando = clampi(modo, 0, COMANDOS - 1)
	alvo = a
	var c: Corvo = corvos.get(cli.meu_id)
	if c:
		c.comando = comando
	marca.queue_redraw()
	janela.queue_redraw()


# C1 A8: o corvo do dono ataca o alvo
func _ataque(_tipo: int, ataque: int, dono: int, a: int) -> void:
	print("TESTE pet ataque %d de %d em %d" % [ataque, dono, a])
	var c: Corvo = corvos.get(dono)
	var e: Entidade = jogo.entidades.get(a)
	if c and e:
		c.atacar(e, ataque)


# --- ficha (C1 A9) ----------------------------------------------------------------------

# pede a ficha do corvo (slot 1) e do Dark Horse (slot 8) que estao vestidos
func pedir_vestidos() -> void:
	var inv: Inventario = jogo.inv
	if inv == null:
		return
	for s in [1, 8]:
		var k := ItensMU.chave(inv.itens[s]) if inv.itens.has(s) else ""
		var c := CORVO if s == 1 else CAVALO
		if k == c:
			print("TESTE pet pede ficha do slot %d" % s)
			cli.pedir_info_pet(0 if s == 1 else 1, 0, s)
		else:
			vestidos.erase(c)


func _info(f: Dictionary) -> void:
	print("TESTE pet info %s" % [f])
	f = calcular(f)
	# mochila (0), subiu (254) ou desceu (255) de nivel no slot da mao esquerda ou do ajudante: e o vestido
	if f.armazem in [0, 254, 255] and f.slot in [1, 8]:
		var k := CORVO if f.tipo == 0 else CAVALO
		vestidos[k] = f
		var e := eu()
		if f.armazem in [254, 255] and e:
			_efeito_nivel(e, f.tipo == 0, f.armazem == 254)
			jogo._msg("%s: nivel %d" % [DicaItem.t(1214 if f.tipo == 0 else 1187), f.nivel])
		var c: Corvo = corvos.get(cli.meu_id)
		if c and f.tipo == 0:
			c.nivel = f.nivel
		janela.queue_redraw()
	ficha = f
	# a caixa do item e desenhada no _draw de quem mostra: redesenha pra ficha aparecer
	for n in ["inv", "guarda", "loja", "troca"]:
		var w = jogo.get(n)
		if w is CanvasItem:
			w.queue_redraw()


# Eff_LevelUp (5 brilhos) e Eff_LevelDown (15) no corvo; no cavalo o brilho fica no dono (ExtState)
func _efeito_nivel(e: Entidade, corvo: bool, subiu: bool) -> void:
	var no: Node3D = corvos.get(e.id) if corvo and corvos.has(e.id) else e
	var ef := EfeitoMU.criar(jogo.mundo)
	var cor := Color(1, 0.9, 0.5) if subiu else Color(0.6, 0.6, 1.0)
	for i in (5 if subiu else 15):
		var p := no.global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.8 if corvo else 2.0), randf_range(-0.4, 0.4))
		ef.sprite("flare01", p, 0.8, cor, 0.9, {"some": 0.6, "vel": Vector3(0, 0.6, 0)})


# CalcPetInfo: as contas do cliente com o carisma (comando) e a forca do personagem
static func calcular(f: Dictionary) -> Dictionary:
	f = f.duplicate()
	var carisma := int(DicaItem.eu.get("comando", 0))
	var forca := int(DicaItem.eu.get("forca", 0))
	var n: int = f.nivel
	var l := n + 1
	f["exp_prox"] = (10 + l) * l * l * l * 100
	f["vel"] = 20 + n * 4 / 5 + carisma / 50
	f["sucesso"] = 1000 + n + n * 15
	if f.tipo == 0:
		f["dano_min"] = 180 + n * 15 + carisma / 8
		f["dano_max"] = 200 + n * 15 + carisma / 4
	else:
		f["dano_min"] = forca / 10 + carisma / 10 + n * 5
		f["dano_max"] = f.dano_min + f.dano_min / 2
	return f


# a ficha que a caixa do item mostra: o vestido (slot 1 ou 8 da mochila) ou a do item apontado (pede se mudou)
static func ficha_de(it: Dictionary) -> Dictionary:
	var k := ItensMU.chave(it)
	if onde.size() < 2:
		return {}
	if onde[0] == 0 and ((onde[1] == 1 and k == CORVO) or (onde[1] == 8 and k == CAVALO)):
		return calcular(vestidos[k]) if vestidos.has(k) else {}
	var chave := "%d:%d:%s:%d" % [onde[0], onde[1], k, it.get("nivel", 0)]
	if chave != _pedido:
		_pedido = chave
		ficha = {}
		if pedir.is_valid():
			pedir.call(0 if k == CORVO else 1, onde[0], onde[1])
	if ficha.is_empty() or ficha.armazem != onde[0] or ficha.slot != onde[1]:
		return {}
	return calcular(ficha)


# RenderPetItemInfo: a caixa inteira do corvo e do cavalo (topo = o preco da loja, se tiver)
static func linhas(it: Dictionary, topo: Array) -> Array:
	var f := ficha_de(it)
	onde = []
	if f.is_empty():
		return []
	var k := ItensMU.chave(it)
	var corvo := k == CORVO
	var eu := DicaItem.eu
	var l := [DicaItem._vazia()]
	if not topo.is_empty():
		l.append_array(topo)
		l.append(DicaItem._vazia())
	l.append(DicaItem._linha(DicaItem.t(1214 if corvo else 1187), DicaItem.AZUL, true))
	l.append(DicaItem._vazia())
	l.append(DicaItem._linha(DicaItem.t(201, [f.exp, f.exp_prox])))
	l.append(DicaItem._linha("%s : %d" % [DicaItem.t(368), f.nivel]))
	if corvo:
		l.append(DicaItem._linha(DicaItem.t(203, [f.dano_min, f.dano_max, f.sucesso])))
		l.append(DicaItem._linha(DicaItem.t(64, [f.vel])))
	l.append(DicaItem._linha(DicaItem.t(70, [f.vida])))
	if corvo:
		DicaItem._requisito(l, DicaItem.t(698, [185 + f.nivel * 15]), 185 + f.nivel * 15, int(eu.get("comando", 0)))
	else:
		DicaItem._requisito(l, DicaItem.t(76, [218 + f.nivel * 2]), 218 + f.nivel * 2, int(eu.get("nivel", 0)))
	l.append(DicaItem._vazia())
	l.append(DicaItem._linha(DicaItem.t(61, [DicaItem.t(24)]), DicaItem.BRANCO if sou_dl() else DicaItem.FUNDO_VERMELHO))
	if not corvo:
		# SetPetItemConvert: o cavalo ganha defesa pela agilidade e pelo nivel; absorve e aumenta o alcance
		l.append(DicaItem._linha(DicaItem.t(959, [5 + int(eu.get("agilidade", 0)) / 20 + f.nivel * 2]), DicaItem.AZUL))
		l.append(DicaItem._linha(DicaItem.t(744, [(30 + f.nivel) / 2]), DicaItem.AZUL))
		l.append(DicaItem._linha(DicaItem.t(1188, [2]), DicaItem.AZUL))
	return l


# o quadrinho do alto da direita (RenderCmdType): "Dark Raven", a vida do corvo (durabilidade / 255) e a ordem
class MarcaCorvo extends Control:
	var pets: Pets
	var _mouse := Vector2(-100, -100)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _caixa() -> Rect2:
		# no original encosta no canto (x 640 - 115); aqui desce pra baixo do botao Sair, ao lado da lista do grupo,
		# e anda pra esquerda junto com o Sair quando abre janela na direita
		var grupo: float = 50.0 if pets.jogo.janela_grupo and pets.jogo.janela_grupo.visible else 0.0
		var borda: float = pets.jogo.borda_direita
		var dir := 640.0 if borda < 0.0 else borda / _esc()
		if borda >= 0.0 and dir < 639.0:
			grupo = 0.0
		return Rect2(dir - 50.0 - grupo - 15.0 - 50.0, 34.0, 100.0, 24.0)

	func _process(_dt: float) -> void:
		visible = pets.tenho_corvo()
		if visible:
			queue_redraw()

	func _esc() -> float:
		return get_viewport_rect().size.x / 640.0

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseMotion:
			_mouse = ev.position / _esc()

	func _has_point(p: Vector2) -> bool:
		return _caixa().has_point(p / _esc())

	func _draw() -> void:
		var e := _esc()
		draw_set_transform(Vector2.ZERO, 0, Vector2(e, e))
		var r := _caixa()
		var f := get_theme_default_font()
		var x := r.position.x + 50.0
		var y := r.position.y
		var inv: Inventario = pets.jogo.inv
		var dur: int = inv.itens[1].get("durabilidade", 255) if inv and inv.itens.has(1) else 0
		var t := DicaItem.t(1214)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_rect(Rect2(x + 50 - w - 2, y, w + 4, 11), Color(0, 0, 0, 0.5))
		draw_string(f, Vector2(x + 50 - w, y + 9), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color8(220, 220, 220))
		# RenderBar: fundo escuro e a vida em laranja
		draw_rect(Rect2(x, y + 12, 50, 3), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(x, y + 12, 50.0 * clampi(dur, 0, 255) / 255.0, 3), Color8(250, 180, 40))
		# a ordem atual no icone de 16 x 20 (newui_command)
		var ic := Rect2(x - 50 + 16, y + 1, 16, 20)
		draw_texture_rect_region(pets.jogo.barra_mu._tex.skill3, ic, Rect2(pets.comando * 20, 0, 20, 28))
		if ic.has_point(_mouse):
			var d := DicaItem.t(1219 + pets.comando)
			var dw := f.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_rect(Rect2(ic.position.x - 2, ic.end.y + 1, dw + 4, 12), Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(ic.position.x, ic.end.y + 10), d, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
