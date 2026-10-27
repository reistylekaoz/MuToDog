class_name Kanturu
extends Control
# Evento da Torre do Kanturu no mapa 39 (Kanturu 3, pasta World40; M39Kanturu3rd, CKanturuDirection e
# CNewUIKanturuInfoWindow do S6), na tela de 640x480 colada embaixo (largura da janela / 640):
#   janela de 99x78 em (541, 351) (newui_Figure_kantru): "Character: %d" (2180) e "Monster : %d" (2183) ou
#     "Monster : Boss" (2182, com a Maya de pe: detalhe 4, 9 e 14) em negrito (134, 134, 199); o relogio com os
#     numeros grandes (minutos em 35, segundos em 65, os dois pontos piscando a cada 0,5 s em 48). O segundo e
#     a conta do original: resto por 60 x minutos, e 0 no ultimo minuto. Aparece no C1 D1 03 das fases de luta
#     (Maya 3, 4, 8, 9, 13, 14 e Nightmare 3) e some nos outros estados ou fora do mapa.
#   resultado (C1 D1 04): Success_kantru ou Failure_kantru (372x99) no meio, alfa de 0,1 subindo 0,01 por quadro
#     do cliente, fica 5 s e some. O de vitoria so vale na luta do Nightmare.
#   a Maya (objeto 0 do mapa) nasce 20 m pra baixo (CreateKanturu3rdObject); no aviso da luta (detalhe 2) sobe
#     13 por quadro tremendo a tela ate -749,5; fica de pe do detalhe 3 ao 18; volta pra baixo no 18 (ENDCYCLE)
#     e na espera. No detalhe 16 (ENDCYCLE_MAYA3) explode: estouros pelo corpo uns 6 s e apaga.
#   ataque em area da Maya (C1 D1 06): 0 tempestade (100 pedras saltando do chao em volta do heroi, som
#     maya_storm), 1 chuva de pedras (4 levas de 10 MayaStone com fogo azul, uma por segundo, caindo em volta).
#   grade: com a torre aberta (estado 4, detalhe 1 ou 2) a grade e a do EncTerrain401.att (a barreira some) e
#     toca o kan_boss_disfield; nos outros, a do mapa.

const MAPA := 39
const PASTA := "res://dados/mundo40/"
const ALTURA_MAYA := -749.5
const BAIXO := -2000.0

var estado := 0
var detalhe := 0
var mostrando := false
var gente := 0
var monstros := 0
var mapa_atual := -1
var resultado := -1
var som: Som
var mundo: Node3D           # o do mapa 39 (o jogo passa)
var heroi: Node3D
var _tex: Texture2D
var _numeros: Texture2D
var _sucesso: Texture2D
var _falha: Texture2D
var _segundos := 0
var _sync := 0
var _alfa := 0.1
var _parado := 0.0
var _maya: Node3D
var _maya_subindo := false
var _maya_explode := 0.0
var _tremor := 0.0
var _sucesso_mapa := false


func _ready() -> void:
	_tex = load("res://dados/hud/kanturu/info.png")
	_sucesso = load("res://dados/hud/kanturu/sucesso.png")
	_falha = load("res://dados/hud/kanturu/falha.png")
	_numeros = load(Inventario.PASTA + "numeros.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


static func no_kanturu(mapa: int) -> bool:
	return mapa == MAPA


# o jogo chama ao trocar de mapa (e depois de montar o mundo, com ele)
func mapa(m: int, mundo_: Node3D = null) -> void:
	mapa_atual = m
	mundo = mundo_
	_maya = null
	if not no_kanturu(m):
		mostrando = false
		resultado = -1
		_sucesso_mapa = false
		if som:
			som.kanturu = 0
	elif mundo and mundo.numero == 40:
		for par in mundo.nos_objetos:
			if int(par[1].t) == 0:
				_maya = par[0]
		_sucesso_mapa = false
		_aplicar()
	queue_redraw()


# ReceiveKanturu3rdState / CurrentState: guarda o estado, liga ou desliga a janela, mexe na Maya e na grade
func mudar(estado_: int, detalhe_: int) -> void:
	var antes := detalhe
	estado = estado_
	detalhe = detalhe_
	if som and no_kanturu(mapa_atual):
		som.kanturu = estado
	var luta := (estado == 2 and detalhe in [3, 4, 8, 9, 13, 14]) or (estado == 3 and detalhe == 3)
	if no_kanturu(mapa_atual):
		if luta != mostrando:
			print("TESTE kanturu janela %s" % ("liga" if luta else "desliga"))
		mostrando = luta
	print("TESTE kanturu estado %d detalhe %d" % [estado, detalhe])
	if estado == 2 and detalhe == 2 and antes != 2:
		_maya_subindo = true
		if som:
			som.tocar(PASTA + "sons/maya_intro.wav")
	if estado == 2 and detalhe == 16 and antes != 16:
		_maya_explode = 6.0
		if som:
			som.tocar(PASTA + "sons/maya_death.wav")
	_aplicar()
	queue_redraw()


func _aplicar() -> void:
	if not no_kanturu(mapa_atual):
		return
	var sucesso := estado == 4 and detalhe in [1, 2]
	if sucesso != _sucesso_mapa and mundo and mundo.numero == 40:
		_sucesso_mapa = sucesso
		_trocar_grade(sucesso)
		if sucesso and som:
			som.tocar(PASTA + "sons/kan_boss_disfield.wav")
	if _maya and not _maya_subindo:
		var de_pe := estado == 2 and detalhe >= 3 and detalhe <= 17
		_maya.position.z = ALTURA_MAYA if de_pe else ALTURA_MAYA + BAIXO
		_maya.visible = true


# CheckSuccessBattle: OpenTerrainAttribute(EncTerrain401.att) com a torre aberta, a do mapa nos outros
func _trocar_grade(sucesso: bool) -> void:
	var img: Image
	var canal_a := true
	if sucesso and ResourceLoader.exists(PASTA + "atributos_sucesso.png"):
		img = (load(PASTA + "atributos_sucesso.png") as Texture2D).get_image()
		canal_a = false
	else:
		img = (load(PASTA + "mapa.png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var n := 256
	for y in n:
		for x in n:
			var c := img.get_pixel(x, y)
			mundo.atributos[y * n + x] = int(round((c.a if canal_a else c.r) * 255.0))
			mundo.grade.set_point_solid(Vector2i(x, y), not mundo.anda(x, y))
	print("TESTE kanturu grade %s" % ("da torre aberta" if sucesso else "do mapa"))


# C1 D1 05: o tempo da fase (SetTime)
func tempo(ms: int) -> void:
	_segundos = ms / 1000
	_sync = Time.get_ticks_msec()
	print("TESTE kanturu tempo %d s" % _segundos)
	queue_redraw()


# C1 D1 07
func contagem(monstros_: int, gente_: int) -> void:
	monstros = monstros_
	gente = gente_
	queue_redraw()


# C1 D1 04 (Kanturu3rdResult): 0 falhou; 1 venceu, so na luta do Nightmare
func fim(r: int) -> void:
	if r == 0:
		resultado = 0
	elif r == 1 and estado == 3:
		resultado = 1
	_alfa = 0.1
	_parado = 0.0
	print("TESTE kanturu resultado %d (mostra %d)" % [r, resultado])
	queue_redraw()


# C1 D1 06 (MayaSceneMayaAction + MayaAction)
func ataque_maya(tipo: int) -> void:
	print("TESTE kanturu ataque da maya %d" % tipo)
	if not heroi or not is_instance_valid(heroi) or not mundo:
		return
	var e := EfeitoMU.criar(mundo)
	var h := heroi.global_position
	if tipo == 0:
		if som:
			som.tocar(PASTA + "sons/maya_storm.wav")
		_tremor = 1.5
		for i in 100:
			var p := h + Vector3(randf_range(-9, 9), -randf_range(0.0, 1.0), randf_range(-9, 9))
			e.modelo("stone0%d" % (1 + randi() % 2), p, randf_range(0.6, 1.2), Color.WHITE, 2.0,
				{"vel": Vector3(randf_range(-1, 1), randf_range(6, 10), randf_range(-1, 1)), "acel": Vector3(0, -12, 0), "vgiro": randf_range(-4, 4), "solido": true})
	else:
		e.tarefa(1.0, 3.5, func(ef: EfeitoMU, _i: int):
			if not is_instance_valid(heroi):
				return
			var c := heroi.global_position
			for k in 10:
				var p := c + Vector3(randf_range(-8, 8) + 5.0, randf_range(3, 13), randf_range(-8, 8))
				var esc := 5.0 + randf_range(0, 3.3)
				var cena: PackedScene = load(PASTA + "efeitos/mayastone0%d.glb" % (1 + randi() % 3))
				var m := cena.instantiate() as Node3D
				m.rotation_degrees = Vector3(-90, 180, 0)
				m.scale = Vector3.ONE * 0.01
				var op := {"vel": Vector3(-3, -6, 0), "acel": Vector3(0, -10, 0), "vgiro": randf_range(-3, 3), "some": 0.1, "solido": true}
				ef.no_pronto(m, p, esc * 0.2, Color.WHITE, 1.4, op)
				ef.sprite("flareblue", p, esc * 0.5, Color(0.4, 0.6, 1.0), 1.4, op))


func _process(dt: float) -> void:
	if _maya and is_instance_valid(_maya):
		if _maya_subindo:
			_maya.position.z += 13.0 * 25.0 * dt
			_tremor = 0.3
			if _maya.position.z >= ALTURA_MAYA:
				_maya.position.z = ALTURA_MAYA
				_maya_subindo = false
				print("TESTE kanturu maya de pe")
		if _maya_explode > 0.0:
			_maya_explode -= dt
			if randf() < dt * 8.0 and mundo:
				var e := EfeitoMU.criar(mundo)
				var c := _maya.global_position + Vector3(randf_range(-4, 4), randf_range(2, 10), randf_range(-4, 4))
				e.sprite("explotion01", c, randf_range(3, 6), Color.WHITE, 0.8, {"quadros": 16, "colunas": 4})
			if _maya_explode <= 0.0:
				_maya.position.z = ALTURA_MAYA + BAIXO
	if _tremor > 0.0 and mundo and is_instance_valid(mundo) and mundo.camera:
		_tremor -= dt
		mundo.camera.h_offset = randf_range(-0.06, 0.06) if _tremor > 0.0 else 0.0
	if resultado >= 0:
		if _alfa <= 1.0:
			_alfa += 0.01 * 25.0 * dt
		else:
			_parado += dt
			if _parado > 5.0:
				resultado = -1
		queue_redraw()
	elif mostrando:
		queue_redraw()


func relogio() -> Vector2i:
	var passou := (Time.get_ticks_msec() - _sync) / 1000
	var resta := _segundos - passou
	var m := resta / 60
	var s := 0 if m <= 0 else resta % (60 * m)
	return Vector2i(maxi(m, 0), maxi(s, 0))


func _draw() -> void:
	if not no_kanturu(mapa_atual):
		return
	var v := get_viewport_rect().size
	var e := v.x / 640.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(e, e))
	var base := v.y / e - 480
	if mostrando:
		var p := Vector2(541, base + 351)
		draw_texture_rect(_tex, Rect2(p, Vector2(99, 78)), false)
		var f := get_theme_default_font()
		var cor := Color8(134, 134, 199)
		_texto(f, p + Vector2(10, 15), DicaItem.t(2180, [gente]), cor)
		var boss := estado == 2 and detalhe in [4, 9, 14]
		_texto(f, p + Vector2(10, 35), DicaItem.t(2182) if boss else DicaItem.t(2183, [monstros]), cor)
		var r := relogio()
		if (Time.get_ticks_msec() / 500) % 2 == 0:
			_texto(f, p + Vector2(48, 57), ":", cor)
		_numero(p.x + 35, p.y + 55, r.x)
		_numero(p.x + 65, p.y + 55, r.y)
	if resultado >= 0:
		var t := _sucesso if resultado == 1 else _falha
		# y = (480 - 372) / 2 como no original (usa a largura na conta), medido do topo
		draw_texture_rect(t, Rect2((640 - 372) / 2.0, (480 - 372) / 2.0, 372, 99), false, Color(1, 1, 1, clampf(_alfa, 0, 1)))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# RenderNumber com escala 1: digitos de 12x14 de largura 12 x 0,7, centrados em x, passo 80%
func _numero(x: float, y: float, n: int) -> void:
	var s := str(maxi(n, 0))
	var w := 12.0 * 0.7
	var h := 16.0 * 0.7
	x -= w * s.length() / 2.0
	for c in s:
		draw_texture_rect_region(_numeros, Rect2(x, y, w, h), Rect2((c.unicode_at(0) - 48) * 12, 0, 12, 14))
		x += w * 0.8


func _texto(f: Font, p: Vector2, t: String, cor: Color) -> void:
	var q := p + Vector2(0, 10)
	draw_string_outline(f, q, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0, 0, 0, 0.9))
	draw_string(f, q, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cor)
