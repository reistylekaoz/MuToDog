class_name Selecao
extends Control
# Escolha de personagem do MU S6, no jeito do MuMain: CharacterScene.cpp (o mapa World75 com a
# camera parada e os personagens nas 5 posicoes), CharSelMainWin (a barra de baixo: Create,
# Menu, Connect e Delete), CharInfoBalloon (o balao com nome, guilda, classe e nivel),
# CharMakeWin (a janela de criar: rosto da classe, atributos iniciais, descricao e nome) e
# MsgWin (as mensagens; apagar pede confirmacao e a senha da conta).
# Clique escolhe; duplo clique, Enter ou Connect entra. Tudo desenhado em 800 x 600 e
# esticado como no cliente (escala de 1 a 2).

signal entrar(nome: String)
signal voltar   # Menu > Select Server
signal listou   # a lista chegou e os personagens estao no lugar

const PASTA := "res://dados/selecao/"
const MUNDO := 75   # WD_74NEW_CHARACTER_SCENE: o cliente le Data/World75
# posicao (unidades do MU) e giro de cada slot (WSclient.cpp, ReceiveCreateCharacter); z 163
const SLOTS := [[8008.0, 18885.0, 115.0], [7986.0, 19145.0, 90.0], [8046.0, 19400.0, 75.0],
	[8133.0, 19645.0, 60.0], [8282.0, 19845.0, 35.0]]
const ALTURA := 1.63
# camera da cena (CameraConfig.h): posicao, Angle[0] -84,5 e Angle[2] -75; FOV 40 de lado num
# 4:3 (30,5 de altura) e o fundo em 4100
const CAMERA := Vector3(9758.93, 18913.11, 675.5)
# classes na ordem do cliente (CLASS_TYPE): numero no servidor, texto do botao, atributos
# iniciais, descricao, bit que libera na conta (0 = sempre) e o rosto (Logo/NewFace0N.bmd):
# angulo x, angulo z, escala, desloca x e z (ClassRenderParameters)
const CLASSES := [
	{"numero": 0, "texto": 20, "stats": [18, 18, 15, 30], "desc": 1705, "libera": 0, "rosto": [0.0, -40.0, 5.9, 0.0, 0.0]},
	{"numero": 4, "texto": 21, "stats": [28, 20, 25, 10], "desc": 1706, "libera": 0, "rosto": [0.0, -12.0, 6.05, 0.0, 0.0]},
	{"numero": 8, "texto": 22, "stats": [22, 25, 20, 15], "desc": 1707, "libera": 0, "rosto": [8.0, 5.0, 9.1, 4.8, 0.0]},
	{"numero": 12, "texto": 23, "stats": [26, 26, 26, 26], "desc": 1708, "libera": 4, "rosto": [8.0, -13.0, 6.0, 0.0, 1.8]},
	{"numero": 16, "texto": 24, "stats": [26, 20, 20, 15, 25], "desc": 1709, "libera": 2, "rosto": [8.0, -18.0, 6.0, 0.0, 0.0]},
	{"numero": 20, "texto": 1687, "stats": [21, 21, 18, 23], "desc": 1690, "libera": 1, "rosto": [2.0, 2.0, 9.1, 4.8, 4.0]},
	{"numero": 24, "texto": 3150, "stats": [32, 27, 25, 20], "desc": 3152, "libera": 8, "rosto": [0.0, 0.0, 6.0, 9.8, -7.5]},
]
# linha (y) de cada botao de classe na janela de criar (CCharMakeWin::SetPosition)
const LINHA := [131, 157, 183, 272, 298, 209, 246]
# posicao na guilda -> texto do balao (CharInfoBalloon.cpp)
const GUILDA := {0: 1330, 32: 1302, 64: 1301, 128: 1300, 255: 488}
const BRANCO := Color.WHITE
const LARANJA := Color8(255, 180, 0)
const LARANJA_CLARO := Color8(255, 217, 39)
const CINZA_CLARO := Color8(226, 226, 226)
const CINZA := Color8(119, 119, 119)
const FONTE := 11

var cli
var palco: Node             # onde o mundo 3D entra (o jogo)
var nomes_classe := {}      # numero da classe -> nome (dados/classes.json)
var volume := 0.8
var lista: Array = []
var escolhido := -1         # slot
var _bonecos := {}          # slot -> Boneco
var _mundo: Node3D
var _auroras: Array[MeshInstance3D] = []
var _brilhos: Node3D
var _musica: AudioStreamPlayer
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _apertou := ""          # botao que levou o clique (o MU executa ao soltar em cima)
var _t := 0.0
var _depois := ""           # nome pra escolher quando a lista nova chegar
# janela de criar
var criando := false
var _classe := 1            # comeca no Dark Knight, como no cliente
var _rosto_vp: SubViewport
var _rosto_giro: Node3D
var _rosto_anim: AnimationPlayer
var _campo_nome: LineEdit
# mensagem por cima de tudo: linhas, tipo (ok, ambos, entrada, nada) e o que fazer no OK
var _msg := {}
var _campo_senha: LineEdit
var _menu := false


func _ready() -> void:
	for n in ["b_create", "b_connect", "b_delete", "server_menu_b_all", "message_ok_b_all", "loding_cancel_b_all",
			"cha_bt", "cha_id", "character_ex", "deco", "message_back", "delete_secret_number", "aurora", "brilho", "faisca"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_campo_nome = _campo(10, false)
	_campo_nome.text_submitted.connect(func(_t2): _criar())
	_campo_senha = _campo(10, true)
	_campo_senha.text_submitted.connect(func(_t2): _msg_ok())
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	if cli:
		cli.criou.connect(_criou)
		cli.apagou.connect(_apagou)


func _campo(maximo: int, secreto: bool) -> LineEdit:
	var c := LineEdit.new()
	c.max_length = maximo
	c.secret = secreto
	c.visible = false
	c.add_theme_font_size_override("font_size", 12)
	c.add_theme_color_override("font_color", BRANCO)
	c.add_theme_color_override("caret_color", BRANCO)
	var vazio := StyleBoxEmpty.new()
	for e in ["normal", "focus", "read_only"]:
		c.add_theme_stylebox_override(e, vazio)
	add_child(c)
	return c


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = clampf(minf(v.x / 800.0, v.y / 600.0), 1.0, 2.0)
	scale = Vector2(_esc, _esc)
	position = Vector2.ZERO
	size = v / _esc
	if _rosto_vp:
		_rosto_vp.size = Vector2i(Vector2(410, 335) * _esc)
	_posicionar_campos()


# --- abrir, lista e mundo -----------------------------------------------------------

func mostrar(l: Array) -> void:
	lista = l
	if _mundo == null:
		await _montar_mundo()
	_montar_personagens()
	var antes := escolhido
	escolhido = -1
	for p in lista:
		if (_depois != "" and p.nome == _depois) or (_depois == "" and p.slot == antes):
			escolhido = p.slot
	_depois = ""
	_atualizar_escolhido()
	# conta sem personagem: a janela de criar abre sozinha (UpdateDisplay)
	if lista.is_empty() and _msg.is_empty():
		abrir_criar()
	print("TESTE selecao %d personagens · escolhido %d · %s" % [lista.size(), escolhido, ", ".join(lista.map(func(p): return "%d %s" % [p.slot, p.nome]))])
	listou.emit()
	# testes do navegador: onde cada um esta na tela (pixels), pra clicar nele
	await get_tree().process_frame
	var cam := _camera()
	if cam:
		for sl in _bonecos:
			var pt := cam.unproject_position(_bonecos[sl].global_position + Vector3(0, 1.0, 0))
			print("TESTE boneco %d na tela %d %d" % [sl, pt.x, pt.y])


func fechar() -> void:
	if _mundo:
		_mundo.queue_free()
		_mundo = null
	_bonecos.clear()
	queue_free()


func _montar_mundo() -> void:
	if PacoteMapa.precisa(MUNDO):
		await PacoteMapa.carregar(self, MUNDO)
	_mundo = Node3D.new()
	_mundo.set_script(load("res://scripts/mundo.gd"))
	_mundo.modo_jogo = true
	_mundo.numero = MUNDO
	_mundo.fixa = true
	# a camera do MU olha pelo -Z dela; base Rz(75) Rx(84,5) no MU, que tem Z pra cima
	var b := Basis(Vector3.RIGHT, -PI / 2) * Basis(Vector3.BACK, deg_to_rad(75.0)) * Basis(Vector3.RIGHT, deg_to_rad(84.5))
	_mundo.camera_fixa = Transform3D(b, Vector3(CAMERA.x, CAMERA.z, -CAMERA.y) * 0.01)
	_mundo.fixa_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(20.0)) * 0.75))
	_mundo.fixa_longe = 41.0
	palco.add_child(_mundo)
	_aura()
	_musica = AudioStreamPlayer.new()
	var mp := "res://dados/mundo%d/musica.mp3" % MUNDO
	if ResourceLoader.exists(mp):
		var s := load(mp) as AudioStreamMP3
		s.loop = true
		_musica.stream = s
		_musica.volume_db = -8.0 + linear_to_db(maxf(volume, 0.001) / 0.8)
		add_child(_musica)
		_musica.play()


func _montar_personagens() -> void:
	for s in _bonecos:
		_bonecos[s].queue_free()
	_bonecos.clear()
	for p in lista:
		if p.slot < 0 or p.slot >= SLOTS.size():
			continue
		var b := Boneco.da_classe(p.classe)
		if b == null:
			continue
		var sl: Array = SLOTS[p.slot]
		_mundo.add_child(b)
		b.position = Vector3(sl[0] * 0.01, ALTURA, -sl[1] * 0.01)
		# no MU o angulo a olha pra (sen a, -cos a); o Boneco olha pro -Z
		b.rotation.y = deg_to_rad(sl[2]) + PI
		b.tocar("parado")
		if p.has("equip"):
			b.vestir(p.equip)
		_bonecos[p.slot] = b


# BITMAP_GM_AURORA no chao (1,8 e 1,2 tiles, girando ao contrario) e as particulas
# BITMAP_EFFECT 4 (raios de chasellight) e 5 (faiscas Impack03) subindo em volta
func _aura() -> void:
	for tam in [1.8, 1.2]:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(tam, tam)
		mi.mesh = pm
		mi.material_override = _somado(_tex.aurora, false)
		mi.visible = false
		_mundo.add_child(mi)
		_auroras.append(mi)
	_brilhos = Node3D.new()
	_brilhos.visible = false
	_mundo.add_child(_brilhos)
	# a luz da particula: 0,15 sobe 16% por quadro ate a metade da vida e desce igual
	var luz := Gradient.new()
	luz.set_color(0, Color(0.15, 0.15, 0.15))
	luz.set_color(1, Color(0.15, 0.15, 0.15))
	luz.add_point(0.5, Color(0.77, 0.77, 0.77))
	for i in 2:
		var p := CPUParticles3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.35, 2.8) if i == 0 else Vector2(0.21, 0.21)
		p.mesh = q
		p.material_override = _somado(_tex.brilho if i == 0 else _tex.faisca, true)
		p.amount = 21
		p.lifetime = 0.84
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(0.4 if i == 0 else 0.25, 1.0, 0.25)
		p.position = Vector3(0, 0.5 if i == 0 else 1.5, 0)
		p.gravity = Vector3.ZERO
		p.direction = Vector3.UP
		p.spread = 0.0
		p.initial_velocity_min = 0.0 if i == 0 else 0.33
		p.initial_velocity_max = 0.0 if i == 0 else 0.49
		p.scale_amount_min = 0.9
		p.scale_amount_max = 1.1
		p.color_ramp = luz
		_brilhos.add_child(p)


static func _somado(t: Texture2D, particula: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = t
	if particula:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
	return m


# C1 F3 15 (FocusCharacter, rodada 25): o personagem clicado vai pro servidor, que devolve o nome; o MuMain so tem a
# funcao de mandar e nao usa a resposta, entao aqui ela fica guardada em "focado"
var focado := ""


func _focar() -> void:
	for p in lista:
		if p.slot == escolhido and cli:
			cli.foco_personagem(p.nome)


func foco_confirmado(nome: String) -> void:
	focado = nome
	print("TESTE selecao foco %s" % nome)


func _atualizar_escolhido() -> void:
	var b: Boneco = _bonecos.get(escolhido)
	for a in _auroras:
		a.visible = b != null
	if _brilhos:
		_brilhos.visible = b != null
	if b:
		var sl: Array = SLOTS[escolhido]
		var chao: float = _mundo.altura_em(sl[0] / 100.0, sl[1] / 100.0) / 100.0 + 0.03
		for a in _auroras:
			a.position = Vector3(b.position.x, maxf(chao, ALTURA + 0.02), b.position.z)
		_brilhos.position = b.position
		for p: CPUParticles3D in _brilhos.get_children():
			p.restart()


func _process(dt: float) -> void:
	_t += dt
	if not _auroras.is_empty() and _auroras[0].visible:
		var ms := _t * 1000.0
		var lumi := sin(ms * 0.0015) * 0.3 + 0.5
		for i in 2:
			_auroras[i].rotation.y = deg_to_rad(ms * 0.01 * (1 if i == 0 else -1))
			(_auroras[i].material_override as StandardMaterial3D).albedo_color = Color(lumi, lumi, lumi)
	if _rosto_anim and not _rosto_anim.is_playing():
		_rosto_anim.play("parado", 0.1, 7.5)
	queue_redraw()


# --- geometria (tudo em 800 x 600 esticado) -----------------------------------------

func _topo_barra() -> float:
	return roundf(567.0 / 600.0 * size.y) - 30.0 - 11.0


func _botoes_barra() -> Dictionary:
	var y := _topo_barra()
	var apagar := Rect2(size.x - 22 - 54, y, 54, 30)
	return {"criar": Rect2(22, y, 54, 30), "menu": Rect2(22 + 54 + 1, y, 54, 30),
		"entrar": Rect2(apagar.position.x - 1 - 54, y, 54, 30), "apagar": apagar}


func _pode(botao: String) -> bool:
	match botao:
		"criar":
			return lista.size() < SLOTS.size()
		"entrar", "apagar":
			return escolhido >= 0 and _bonecos.has(escolhido)
	return true


func _janela_criar() -> Vector2:
	return ((size - Vector2(454, 406)) / 2.0).round()


func _janela_msg() -> Vector2:
	return ((size - Vector2(352, 113)) / 2.0).round()


func _botoes_criar() -> Dictionary:
	var o := _janela_criar()
	var r := {"ok": Rect2(o + Vector2(346, 325), Vector2(54, 30)), "cancelar": Rect2(o + Vector2(400, 325), Vector2(54, 30))}
	for c in CLASSES.size():
		r["classe%d" % c] = Rect2(o + Vector2(346, LINHA[c]), Vector2(108, 26))
	return r


func _botoes_msg() -> Dictionary:
	var o := _janela_msg()
	var y := o.y + 72
	match _msg.get("tipo", ""):
		"ok":
			return {"ok": Rect2(o.x + 149, y, 54, 30)}
		"ambos":
			return {"ok": Rect2(o.x + 98, y, 54, 30), "cancelar": Rect2(o.x + 200, y, 54, 30)}
		"entrada":
			return {"ok": Rect2(o.x + 209, y, 54, 30), "cancelar": Rect2(o.x + 264, y, 54, 30)}
	return {}


func _botoes_menu() -> Dictionary:
	var o := _janela_msg()
	return {"servidor": Rect2(o.x + 56, o.y + 44, 108, 26), "fechar": Rect2(o.x + 188, o.y + 44, 108, 26)}


func _classe_liberada(c: int) -> bool:
	var bit: int = CLASSES[c].libera
	return bit == 0 or (cli != null and int(cli.liberadas) & bit != 0)


# personagem embaixo do mouse: o retangulo do pe a cabeca na tela
func _personagem_em(p: Vector2) -> int:
	var cam := _camera()
	if cam == null:
		return -1
	for s in _bonecos:
		var b: Boneco = _bonecos[s]
		var pe := b.global_position
		if cam.is_position_behind(pe):
			continue
		var a := cam.unproject_position(pe) / _esc
		var c := cam.unproject_position(pe + Vector3(0, b.altura, 0)) / _esc
		var alto := a.y - c.y
		if Rect2(a.x - alto * 0.22, c.y, alto * 0.44, alto).has_point(p):
			return s
	return -1


func _camera() -> Camera3D:
	return _mundo.camera if _mundo and is_instance_valid(_mundo) else null


func _posicionar_campos() -> void:
	if _campo_nome == null:
		return
	var o := _janela_criar()
	_campo_nome.position = o + Vector2(78, 317 + 11)
	_campo_nome.size = Vector2(160, 20)
	_campo_nome.visible = criando and _msg.is_empty()
	var m := _janela_msg()
	_campo_senha.position = m + Vector2(36, 77)
	_campo_senha.size = Vector2(163, 20)
	_campo_senha.visible = _msg.get("tipo", "") == "entrada"


# --- desenho --------------------------------------------------------------------------

func _draw() -> void:
	var f := get_theme_default_font()
	var cam := _camera()
	# baloes (por baixo das janelas)
	if cam:
		for p in lista:
			var b: Boneco = _bonecos.get(p.slot)
			if b == null:
				continue
			var pos := b.global_position + Vector3(0, 3.5, 0)
			if cam.is_position_behind(pos):
				continue
			var o := (cam.unproject_position(pos) / _esc - Vector2(59, 54)).round()
			draw_texture_rect_region(_tex.character_ex, Rect2(o, Vector2(118, 54)), Rect2(0, 0, 118, 54))
			var cor := BRANCO
			if p.get("estado", 0) & 0x01:
				cor = Color8(0, 255, 255)
			elif p.get("estado", 0) & 0x28:
				cor = Color8(255, 0, 0)
			_texto(f, o + Vector2(0, 6), p.nome, 118, cor)
			var g: int = GUILDA.get(int(p.get("guilda", 255)), 0)
			_texto(f, o + Vector2(0, 22), "(%s)" % (DicaItem.t(g) if g else ""), 118, BRANCO)
			_texto(f, o + Vector2(0, 38), "%s %d" % [nomes_classe.get(str(p.classe), "?"), p.nivel], 118, LARANJA_CLARO)
	# barra de baixo
	var bt := _botoes_barra()
	var info_x: float = bt.menu.end.x + 2
	draw_rect(Rect2(info_x, bt.menu.position.y + 5, bt.entrar.position.x - 2 - info_x, 21), Color(0, 0, 0, 143.0 / 255.0))
	draw_texture_rect_region(_tex.deco, Rect2(size.x - 189, bt.menu.position.y - 59, 189, 103), Rect2(0, 0, 189, 103))
	var travado := criando or _menu or not _msg.is_empty()
	_botao(_tex.b_create, bt.criar, _pode("criar"), not travado, "criar")
	_botao(_tex.server_menu_b_all, bt.menu, true, not travado, "menu")
	_botao(_tex.b_connect, bt.entrar, _pode("entrar"), not travado, "entrar")
	_botao(_tex.b_delete, bt.apagar, _pode("apagar"), not travado, "apagar")
	if criando:
		_desenhar_criar(f)
	if _menu:
		var o := _janela_msg()
		draw_texture_rect_region(_tex.message_back, Rect2(o, Vector2(352, 113)), Rect2(0, 0, 352, 113))
		var bm := _botoes_menu()
		_botao_texto(bm.servidor, DicaItem.t(382), true, _msg.is_empty(), false, "servidor")
		_botao_texto(bm.fechar, DicaItem.t(388), true, _msg.is_empty(), false, "fechar")
	if not _msg.is_empty():
		_desenhar_msg(f)


func _desenhar_criar(f: Font) -> void:
	var o := _janela_criar()
	if _rosto_vp:
		draw_texture_rect(_rosto_vp.get_texture(), Rect2(o, Vector2(410, 335)), false)
	var c: Dictionary = CLASSES[_classe]
	var stats: Array = c.stats
	var caixa := Rect2(o + Vector2(346, 24), Vector2(108, 96 if stats.size() > 4 else 80))
	draw_rect(caixa, Color(0, 0, 0, 143.0 / 255.0))
	var rotulos := [1701, 1702, 1703, 1704, 1738]
	for i in stats.size():
		var y := caixa.position.y + 10 + i * 17
		_texto(f, Vector2(caixa.position.x + 22, y), DicaItem.t(rotulos[i]), 0, BRANCO)
		_texto(f, Vector2(caixa.position.x + 22 + 54, y), str(stats[i]), 0, LARANJA)
	var livre := _msg.is_empty()
	var bc := _botoes_criar()
	for i in CLASSES.size():
		_botao_texto(bc["classe%d" % i], DicaItem.t(CLASSES[i].texto), _classe_liberada(i), livre, i == _classe, "classe%d" % i)
	_botao(_tex.message_ok_b_all, bc.ok, true, livre, "ok", 3)
	_botao(_tex.loding_cancel_b_all, bc.cancelar, true, livre, "cancelar", 3)
	draw_texture_rect_region(_tex.cha_id, Rect2(o + Vector2(0, 317), Vector2(346, 38)), Rect2(0, 0, 346, 38))
	var desc := Rect2(o + Vector2(0, 355), Vector2(454, 51))
	draw_rect(desc, Color(0, 0, 0, 143.0 / 255.0))
	var linhas := _quebrar(f, DicaItem.t(c.desc), 434)
	for i in mini(linhas.size(), 2):
		_texto(f, desc.position + Vector2(10, 12 + i * 19 - 6), linhas[i], 0, BRANCO)


func _desenhar_msg(f: Font) -> void:
	var o := _janela_msg()
	draw_texture_rect_region(_tex.message_back, Rect2(o, Vector2(352, 113)), Rect2(0, 0, 352, 113))
	var linhas: Array = _msg.linhas
	var tipo: String = _msg.tipo
	if linhas.size() == 1:
		_texto(f, o + Vector2(0, 54 if tipo == "nada" else 38), linhas[0], 352, BRANCO)
	else:
		_texto(f, o + Vector2(25, 44 if tipo == "nada" else 32), linhas[0], 0, BRANCO)
		_texto(f, o + Vector2(25, 66 if tipo == "nada" else 51), linhas[1], 0, BRANCO)
	if tipo == "entrada":
		draw_texture_rect_region(_tex.delete_secret_number, Rect2(o + Vector2(32, 76), Vector2(171, 23)), Rect2(0, 0, 171, 23))
	var bm := _botoes_msg()
	if bm.has("ok"):
		_botao(_tex.message_ok_b_all, bm.ok, true, true, "msg_ok", 3)
	if bm.has("cancelar"):
		_botao(_tex.loding_cancel_b_all, bm.cancelar, true, true, "msg_cancelar", 3)


# botao de sprite: quadros de 30 um embaixo do outro (0 normal, 1 em cima, 2 apertado, 3 apagado)
func _botao(t: Texture2D, r: Rect2, ligado: bool, ativo: bool, nome: String, quadros := 4) -> void:
	var q := 0
	if not ligado and quadros > 3:
		q = 3
	elif ativo and r.has_point(_mouse):
		q = 2 if _apertou == nome and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1
	draw_texture_rect_region(t, r, Rect2(0, q * 30, 54, 30))


# botao de classe (cha_bt, quadros de 26; o 3 e o marcado) com o texto em cima
func _botao_texto(r: Rect2, texto: String, ligado: bool, ativo: bool, marcado: bool, nome: String) -> void:
	var q := 0
	if marcado:
		q = 3
	elif ligado and ativo and r.has_point(_mouse):
		q = 2 if _apertou == nome and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1
	draw_texture_rect_region(_tex.cha_bt, r, Rect2(0, q * 26, 108, 26))
	var cor := CINZA if not ligado else (BRANCO if q == 2 or marcado else CINZA_CLARO)
	_texto(get_theme_default_font(), r.position + Vector2(0, 7), texto, r.size.x, cor)


# texto com o topo em p (o MU posiciona pelo topo da letra); largura > 0 centraliza
func _texto(f: Font, p: Vector2, t: String, largura: float, cor: Color) -> void:
	var al := HORIZONTAL_ALIGNMENT_CENTER if largura > 0 else HORIZONTAL_ALIGNMENT_LEFT
	var w := largura if largura > 0 else -1.0
	var base := p + Vector2(0, f.get_ascent(FONTE))
	draw_string_outline(f, base, t, al, w, FONTE, 2, Color(0, 0, 0, 0.8))
	draw_string(f, base, t, al, w, FONTE, cor)


func _quebrar(f: Font, t: String, largura: float) -> Array:
	var linhas := []
	var atual := ""
	for p in t.split(" ", false):
		var tenta := p if atual == "" else atual + " " + p
		if f.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE).x > largura and atual != "":
			linhas.append(atual)
			atual = p
		else:
			atual = tenta
	if atual != "":
		linhas.append(atual)
	return linhas


# --- entrada --------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		if ev.pressed:
			_apertou = _botao_em(ev.position)
			if _apertou == "" and not criando and not _menu and _msg.is_empty():
				var s := _personagem_em(ev.position)
				if ev.double_click and s >= 0:
					escolhido = s
					_atualizar_escolhido()
					_entrar()
				elif s != escolhido:
					escolhido = s
					_atualizar_escolhido()
					_focar()
		else:
			var b := _botao_em(ev.position)
			if b != "" and b == _apertou:
				_clicou(b)
			_apertou = ""
		accept_event()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if ev.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		if not _msg.is_empty():
			_msg_ok()
		elif criando:
			_criar()
		elif not _menu:
			_entrar()
		get_viewport().set_input_as_handled()
	elif ev.keycode == KEY_ESCAPE:
		if not _msg.is_empty():
			_msg_cancelar()
		elif criando:
			fechar_criar()
		else:
			_menu = not _menu
		get_viewport().set_input_as_handled()


# o botao embaixo do ponto, so da camada de cima (mensagem > menu > criar > barra)
func _botao_em(p: Vector2) -> String:
	var grupos := []
	if not _msg.is_empty():
		var bm := _botoes_msg()
		grupos = [{"msg_ok": bm.get("ok", Rect2()), "msg_cancelar": bm.get("cancelar", Rect2())}]
	elif _menu:
		grupos = [_botoes_menu()]
	elif criando:
		grupos = [_botoes_criar()]
	else:
		grupos = [_botoes_barra()]
	for g in grupos:
		for k in g:
			if (g[k] as Rect2).has_point(p):
				return k
	return ""


func _clicou(b: String) -> void:
	match b:
		"criar":
			if _pode("criar"):
				abrir_criar()
		"menu":
			_menu = true
		"entrar":
			_entrar()
		"apagar":
			if _pode("apagar"):
				_apagar()
		"servidor":
			_menu = false
			voltar.emit()
		"fechar":
			_menu = false
		"ok":
			_criar()
		"cancelar":
			fechar_criar()
		"msg_ok":
			_msg_ok()
		"msg_cancelar":
			_msg_cancelar()
		_:
			if b.begins_with("classe"):
				var c := int(b.substr(6))
				if _classe_liberada(c) and c != _classe:
					_classe = c
					_mostrar_rosto()


func _entrar() -> void:
	if not _pode("entrar"):
		return
	for p in lista:
		if p.slot == escolhido:
			entrar.emit(p.nome)
			return


# --- criar ------------------------------------------------------------------------------

func abrir_criar() -> void:
	if not _pode("criar"):
		return
	criando = true
	_campo_nome.text = ""
	if _rosto_vp == null:
		_rosto_vp = SubViewport.new()
		_rosto_vp.own_world_3d = true
		_rosto_vp.transparent_bg = true
		_rosto_vp.size = Vector2i(Vector2(410, 335) * _esc)
		add_child(_rosto_vp)
		# MoveCharacterCamera: 500 na frente, 10 pro lado e 48 pra cima, FOV 10
		var cam := Camera3D.new()
		cam.position = Vector3(0.10, 0.48, 5.0)
		cam.fov = 10.0
		cam.near = 0.5
		cam.far = 20.0
		_rosto_vp.add_child(cam)
		var mu := Node3D.new()
		mu.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2) * 0.01, Vector3.ZERO)
		_rosto_vp.add_child(mu)
		_rosto_giro = Node3D.new()
		mu.add_child(_rosto_giro)
	_rosto_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if not _classe_liberada(_classe):
		_classe = 1
	_mostrar_rosto()
	_posicionar_campos()
	_campo_nome.grab_focus()


func fechar_criar() -> void:
	criando = false
	if _rosto_vp:
		_rosto_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_posicionar_campos()
	grab_focus()


# o rosto da classe (MODEL_FACE + classe): acao 1 ao escolher, depois a 0 parada, PlaySpeed 0,3
func _mostrar_rosto() -> void:
	for n in _rosto_giro.get_children():
		n.queue_free()
	_rosto_anim = null
	var cena := load("res://dados/personagens/rosto%d.glb" % (_classe + 1)) as PackedScene
	if cena == null:
		return
	var r: Array = CLASSES[_classe].rosto
	_rosto_giro.basis = (Basis(Vector3.BACK, deg_to_rad(r[1])) * Basis(Vector3.RIGHT, deg_to_rad(r[0]))).scaled(Vector3.ONE * r[2])
	_rosto_giro.position = Vector3(r[3], 0, r[4])
	var m := cena.instantiate() as Node3D
	_rosto_giro.add_child(m)
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if orig:
				var nova := orig.duplicate() as BaseMaterial3D
				nova.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mi.set_surface_override_material(s, nova)
	var achou := m.find_children("*", "AnimationPlayer", true, false)
	if not achou.is_empty():
		_rosto_anim = achou[0]
		for n in _rosto_anim.get_animation_list():
			_rosto_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR if n == "parado" else Animation.LOOP_NONE
		if _rosto_anim.has_animation("escolhido"):
			_rosto_anim.play("escolhido", 0.0, 7.5)


func _criar() -> void:
	if not criando or not _msg.is_empty():
		return
	var nome := _campo_nome.text.strip_edges()
	if nome.length() < 4:
		_mensagem([DicaItem.t(390)])
	elif not _so_letras(nome):
		_mensagem([DicaItem.t(391)])
	else:
		criando = false
		_rosto_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_mensagem([DicaItem.t(471)], "nada")
		cli.criar_personagem(nome, CLASSES[_classe].numero)
		print("TESTE criar %s classe %d" % [nome, CLASSES[_classe].numero])


static func _so_letras(t: String) -> bool:
	var r := RegEx.create_from_string("^[A-Za-z0-9]+$")
	return r.search(t) != null


func _criou(ok: bool, motivo: int, info: Dictionary) -> void:
	print("TESTE criou %s %d %s" % [ok, motivo, info])
	# o servidor nao manda a lista de novo: entra direto no slot (ReceiveCreateCharacter)
	if ok:
		_msg = {}
		_posicionar_campos()
		var l := lista.filter(func(p): return p.slot != info.slot)
		l.append(info)
		mostrar(l)
	else:
		_depois = ""
		criando = true
		_rosto_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_mensagem([DicaItem.t(396 if motivo == 2 else 1716)])


# --- apagar -----------------------------------------------------------------------------

func _apagar() -> void:
	var p := _dados(escolhido)
	if p.is_empty():
		return
	if int(p.get("guilda", 255)) != 255:
		_mensagem([DicaItem.t(1654)])
		return
	_mensagem([DicaItem.t(1712) % p.nome], "ambos", func():
		_campo_senha.text = ""
		_mensagem([DicaItem.t(1713)], "entrada", func():
			var senha := _campo_senha.text
			_mensagem([DicaItem.t(471)], "nada")
			cli.apagar_personagem(p.nome, senha)
			print("TESTE apagar %s" % p.nome)))


func _apagou(r: int) -> void:
	print("TESTE apagou %d" % r)
	match r:
		1:
			var fora := escolhido
			escolhido = -1
			mostrar(lista.filter(func(p): return p.slot != fora))
			_mensagem([DicaItem.t(1714)])
		0:
			_mensagem([DicaItem.t(1654)])
		_:
			_mensagem([DicaItem.t(401)])


func _dados(slot: int) -> Dictionary:
	for p in lista:
		if p.slot == slot:
			return p
	return {}


# --- mensagem ---------------------------------------------------------------------------

func _mensagem(linhas: Array, tipo := "ok", ok := Callable()) -> void:
	# texto comprido quebra em 2 linhas, como o SeparateTextIntoLines
	if linhas.size() == 1:
		var q := _quebrar(get_theme_default_font(), linhas[0], 300)
		if q.size() > 1:
			linhas = [q[0], " ".join(q.slice(1))]
	_msg = {"linhas": linhas, "tipo": tipo, "ok": ok}
	_posicionar_campos()
	if tipo == "entrada":
		_campo_senha.grab_focus()
	else:
		grab_focus()


func _msg_ok() -> void:
	if _msg.is_empty() or _msg.tipo == "nada":
		return
	var f: Callable = _msg.ok
	_msg = {}
	_posicionar_campos()
	if criando:
		_campo_nome.grab_focus()
	if f.is_valid():
		f.call()


func _msg_cancelar() -> void:
	if _msg.is_empty() or _msg.tipo == "nada":
		return
	_msg = {}
	_posicionar_campos()
	if criando:
		_campo_nome.grab_focus()


# --- testes (--selecao criar:Nome:4,apagar:Nome,entrar:Nome) ------------------------------
# faz pelos mesmos caminhos dos botoes; a senha de apagar e a da conta

func teste(passos: PackedStringArray) -> void:
	for passo in passos:
		var a := passo.split(":")
		await get_tree().create_timer(2.0).timeout
		print("TESTE passo %s" % passo)
		match a[0]:
			"criar":
				abrir_criar()
				_campo_nome.text = a[1]
				for c in CLASSES.size():
					if CLASSES[c].numero == int(a[2]) and _classe_liberada(c):
						_classe = c
						_mostrar_rosto()
				await get_tree().create_timer(1.5).timeout
				_criar()
				if _msg.get("tipo", "") == "nada":
					await cli.criou
					await get_tree().create_timer(0.5).timeout
				if not _msg.is_empty():
					print("TESTE mensagem %s" % str(_msg.linhas))
					_msg_ok()
				fechar_criar()
			"apagar", "entrar":
				var s := -1
				for p in lista:
					if p.nome == a[1]:
						s = p.slot
				escolhido = s
				_atualizar_escolhido()
				if a[0] == "entrar":
					_entrar()
					return
				_clicou("apagar")
				await get_tree().create_timer(1.0).timeout
				print("TESTE mensagem %s" % str(_msg.get("linhas", [])))
				_msg_ok()
				_campo_senha.text = a[2] if a.size() > 2 else cli.senha
				_msg_ok()
				var r: int = await cli.apagou
				await get_tree().create_timer(1.0).timeout
				print("TESTE mensagem %s" % str(_msg.get("linhas", [])))
				_msg_ok()
