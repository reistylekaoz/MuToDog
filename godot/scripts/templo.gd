class_name Templo
extends Control
# Illusion Temple durante a partida (CNewUICursedTempleSystem e CursedTemple do S6), desenhado na tela de
# 640x480 colada embaixo a direita (largura da janela / 640):
#   moldura da skill (512, 179) com o icone da skill do templo (539, 200), os pontos pedidos e os que tenho,
#     e as setas (562, 201 e 214) que trocam a skill (a roda do mouse tambem);
#   minimapa do templo (512, 263) com a moldura (512, 232), as bases e os bancos das duas equipes, o grupo,
#     quem leva a reliquia e o heroi (MiniMapPos), o botao de transparencia (513, 238) e os numeros
#     (transparencia, pontos do MU Alliance e da Illusion Sorcery);
#   o tempo que falta (506, 393);
#   o placar grande no meio quando alguem pontua (entra 0,015 por quadro, fica 5 s e sai);
#   o tutorial do comeco (3 passos de 10 s em 140, 50);
#   a barra de "pegando/guardando a reliquia" (CCursedTempleProgressMsgBox, 10 s, cancela se o heroi
#     sair do lugar), que no fim fala com o NPC.
# Estados (C1 BF 09 + 1): 1 espera, 2 pronto (zera, tutorial, som, mostra), 3 partida, 4 fim.

signal usar(skill: int, alvo: int)      # Shift + botao direito com pontos bastantes: o jogo manda o C1 BF 02
signal falar(npc: int)                  # a barra encheu: fala com o NPC (pega ou guarda a reliquia)
signal aviso(texto: String, erro: bool) # mensagem no log do sistema

const PASTA := "res://dados/hud/templo/"
const SOM := "res://dados/mundo47/sons/%s.wav"   # vao no pacote do mapa (so tocam no templo)
const MAPAS := [45, 46, 47, 48, 49, 50]
const PROTECAO := 210
const RESTRICAO := 211
const PERSEGUICAO := 212
const QUEIMA := 213
const ABATES := {210: 5, 211: 5, 212: 10, 213: 5}     # KillCount do Skill.bmd
const PROGRESSO := 10.0
const AZUL := Color(0x49 / 255.0, 0xB0 / 255.0, 1.0)
# MiniMapPos: o quadro do minimapa esta a 45 graus; 170,84 e o meio do templo
const MEIO := Vector2(170, 84)

var estado := 0             # 0 nada, 1 espera, 2 pronto, 3 partida, 4 fim
var mostrando := false      # INTERFACE_CURSEDTEMPLE_GAMESYSTEM
var tempo := 0
var reliquia := 0xFFFF      # quem leva a reliquia (id)
var rel_tile := Vector2i.ZERO
var aliados := 0
var ilusao := 0
var equipe := 2             # 0 MU Alliance, 1 Illusion Sorcery, 2 nenhuma
var grupo: Array = []       # [{id, mapa, x, y}]
var pontos := 0             # pontos de abate
var skill := PROTECAO
var esperando := false      # m_CursedTempleCurSkillPacket: pedido de skill no ar
var alfa := 1.0
var meu_id := -1
var meu_tile := Vector2i.ZERO
var nomes_skill := {}       # numero -> nome (dados/skills.json)
var som: Som
var progresso_npc := -1     # NPC da barra (-1 nenhuma)
var progresso_tipo := 0     # 0 pegando, 1 guardando
var _progresso_t := 0.0
var _progresso_de := Vector2i.ZERO
var _placar := -1           # -1 parado, 0 entrando, 1 parado na tela, 2 saindo
var _placar_alfa := 0.0
var _placar_t := 0.0
var _tutorial := -1         # passo 0, 1, 2 (-1 nenhum)
var _tutorial_t := 0.0
var _tex := {}
var _mouse := Vector2(-100, -100)
var painel: Control         # pega o clique na coluna da direita (512, 179 a 640, 430)


func _ready() -> void:
	for n in ["ctskillframe", "ctminmap", "ctminmapframe", "Bt_clearness_illusion", "ctskillup", "ctskilldown",
			"skill2", "non_skill2", "ctgametimeframe", "ctminmap_TeamA_npc", "ctminmap_TeamB_npc", "ctminmap_TeamA_box",
			"ctminmap_TeamB_box", "ctminmap_TeamA_member", "ctminmap_TeamB_member", "ctminmap_Relic", "ctminmap_Hero",
			"ctscorealliedgaail", "ctscoreillsiongaail", "ctscorevs0", "ctscorevs1", "ctscoreleft", "ctscoreright",
			"barra_fundo", "barra"]:
		_tex[n] = load(PASTA + n + ".png")
	for i in 10:
		_tex["a%d" % i] = load(PASTA + "ctscorealliednum%d.png" % i)
		_tex["i%d" % i] = load(PASTA + "ctscoreillusionnum%d.png" % i)
	for n in ["numeros", "fonte_numeros", "inv_fundo", "msg_topo", "msg_baixo"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	painel = Control.new()
	painel.mouse_filter = Control.MOUSE_FILTER_STOP
	painel.gui_input.connect(_clique_painel)
	painel.mouse_exited.connect(func(): _mouse = Vector2(-100, -100))
	add_child(painel)
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _esc() -> float:
	return get_viewport_rect().size.x / 640.0


# quanto a tela de 480 de alto desce pra colar embaixo (na janela larga ela tem menos de 480)
func _desce() -> float:
	return get_viewport_rect().size.y / _esc() - 480.0


func _ajustar() -> void:
	var e := _esc()
	painel.position = Vector2(512, 179 + _desce()) * e
	painel.size = Vector2(128, 251) * e
	painel.visible = mostrando
	queue_redraw()


static func no_templo(mapa: int) -> bool:
	return mapa in MAPAS


# o jogo chama ao trocar de mapa: fora do templo nada aparece (Render: "mapa trocado no meio do evento")
func mapa(m: int) -> void:
	if not no_templo(m):
		if mostrando or estado != 0:
			print("TESTE templo saiu do mapa")
		mostrando = false
		estado = 0
		if som:
			som.templo = 0
		cancelar_progresso()
		_tutorial = -1
		_placar = -1
	_ajustar()


# ResetCursedTempleSystemInfo
func zerar() -> void:
	tempo = 0
	reliquia = 0xFFFF
	rel_tile = Vector2i.ZERO
	aliados = 0
	ilusao = 0
	equipe = 2
	grupo = []
	alfa = 1.0
	pontos = 0
	_tutorial = -1
	_placar = -1
	_placar_alfa = 0.0


# C1 BF 09 (o valor chega 0 a 3; o cliente soma 1)
func mudar_estado(e: int) -> void:
	estado = e + 1
	if som:
		som.templo = estado
	print("TESTE templo estado %d" % estado)
	if estado == 2:
		zerar()
		_tutorial = 0
		_tutorial_t = 0.0
		if som:
			som.tocar(SOM % "start01")
		mostrando = true
	_ajustar()


# C1 BF 01: devolve true quando o placar mudou (o jogo poe a reliquia em quem leva)
func receber(d: Dictionary) -> void:
	tempo = int(d.tempo)
	reliquia = int(d.reliquia)
	rel_tile = Vector2i(int(d.rx), int(d.ry))
	equipe = int(d.equipe)
	var a := int(d.aliados)
	var i := int(d.ilusao)
	var texto := -1
	if equipe == 0:
		if aliados != a:
			texto = 2360
		elif ilusao != i:
			texto = 2361
	else:
		if ilusao != i:
			texto = 2363
		elif aliados != a:
			texto = 2364
	if texto > 0:
		if som:
			som.tocar(SOM % "score01")
		_placar = 0
		_placar_alfa = 0.0
		aviso.emit(DicaItem.t(texto), true)
		print("TESTE templo placar %d x %d" % [a, i])
	aliados = a
	ilusao = i
	grupo = d.grupo
	queue_redraw()


# C1 BF 06
func receber_pontos(n: int) -> void:
	if n > pontos:
		aviso.emit(DicaItem.t(2391, [n - pontos]), false)
	pontos = n
	queue_redraw()


func trocar_skill(passo: int) -> void:
	skill = clampi(skill + passo, PROTECAO, QUEIMA)
	print("TESTE templo skill %d" % skill)
	queue_redraw()


# SetCursedTempleSkill: Shift + botao direito. alvo = id de quem esta embaixo do mouse (-1 nenhum),
# inimigo = se esse alvo pode levar a skill (nao e do meu grupo), distancia = tiles ate ele.
# Devolve o alvo mandado (-1 se nao mandou)
func tentar(alvo: int, inimigo: bool, distancia: int) -> int:
	if esperando:
		return -1
	if pontos < ABATES[skill]:
		aviso.emit(DicaItem.t(2392), true)
		return -1
	if skill == PERSEGUICAO and reliquia == 0xFFFF:
		return -1
	var quem := meu_id
	if skill in [RESTRICAO, QUEIMA]:
		if alvo < 0 or not inimigo or distancia > 3:
			return -1
		for g in grupo:
			if int(g.id) == alvo:
				return -1
		quem = alvo
	esperando = true
	usar.emit(skill, quem)
	return quem


# C1 BF 02 de volta (o jogo cuida do efeito); so destrava o pedido
func skill_voltou(de: int) -> void:
	if de == meu_id:
		esperando = false


# CheckTalkProgressNpc: 380 a estatua (pega), 383 e 384 os bancos da propria equipe (guarda, so com a
# reliquia na mochila), 381 e 382 os comandantes (so a fala). Devolve true se o templo cuidou do clique.
func clicou_npc(numero: int, id: int, tenho_reliquia: bool) -> bool:
	match numero:
		380:
			comecar_progresso(id, 0)
			return true
		383, 384:
			if not ((numero == 383 and equipe == 0) or (numero == 384 and equipe == 1)):
				return true
			if tenho_reliquia:
				comecar_progresso(id, 1)
			else:
				aviso.emit(DicaItem.t(2092), true)
			return true
	return false


func comecar_progresso(id: int, tipo: int) -> void:
	progresso_npc = id
	progresso_tipo = tipo
	_progresso_t = 0.0
	_progresso_de = meu_tile
	print("TESTE templo barra %s (npc %d)" % ["pegando" if tipo == 0 else "guardando", id])
	queue_redraw()


func cancelar_progresso() -> void:
	if progresso_npc >= 0:
		print("TESTE templo barra cancelada")
	progresso_npc = -1


func _process(dt: float) -> void:
	if not mostrando:
		return
	if progresso_npc >= 0:
		if meu_tile != _progresso_de:
			cancelar_progresso()
		else:
			_progresso_t += dt
			if _progresso_t >= PROGRESSO:
				var n := progresso_npc
				progresso_npc = -1
				print("TESTE templo barra cheia: fala com %d" % n)
				falar.emit(n)
	# UpdateScore (0,015 por quadro a 60 por segundo)
	if _placar == 0:
		_placar_alfa += 0.015 * 60.0 * dt
		if _placar_alfa >= 1.0:
			_placar_alfa = 1.0
			_placar = 1
			_placar_t = 0.0
	elif _placar == 1:
		_placar_t += dt
		if _placar_t >= 5.0:
			_placar = 2
	elif _placar == 2:
		_placar_alfa -= 0.015 * 60.0 * dt
		if _placar_alfa <= 0.0:
			_placar = -1
	if _tutorial >= 0:
		_tutorial_t += dt
		if _tutorial_t >= 10.0:
			_tutorial += 1
			_tutorial_t = 0.0
			if _tutorial >= 3:
				_tutorial = -1
	queue_redraw()


static func minimapa(x: float, y: float) -> Vector2:
	var esc := 1.56
	return Vector2((x - (MEIO.y - y)) / esc + 464.0, (125.0 - (y + (MEIO.x - x))) / esc + 299.0)


func _draw() -> void:
	if not mostrando:
		return
	var e := _esc()
	var f := get_theme_default_font()
	var d := _desce()
	draw_set_transform(Vector2(0, d) * e, 0, Vector2(e, e))
	_desenhar_tempo()
	_desenhar_minimapa()
	_desenhar_skill(f)
	draw_set_transform(Vector2(0, d / 2.0) * e, 0, Vector2(e, e))
	_desenhar_placar()
	draw_set_transform(Vector2.ZERO, 0, Vector2(e, e))
	_desenhar_tutorial(f)
	if progresso_npc >= 0:
		_desenhar_progresso(f)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# RenderNumber: digitos de newui_number1 (12x14), centrados em x, largura 12 * (escala - 0,3), passo 80%
func _numero(x: float, y: float, n: int, escala := 1.0) -> void:
	var s := str(maxi(n, 0))
	var w := 12.0 * (escala - 0.3)
	var h := 16.0 * (escala - 0.3)
	x -= w * s.length() / 2.0
	for c in s:
		draw_texture_rect_region(_tex.numeros, Rect2(x, y, w, h), Rect2((c.unicode_at(0) - 48) * 12, 0, 12, 14), Color(1, 1, 1, alfa))
		x += w * 0.8


# RenderNumber2D: FontTest (16x16 por digito), centrados, passo 70%
func _numero2d(x: float, y: float, n: int) -> void:
	var s := str(maxi(n, 0))
	x -= 8.0 * s.length() / 2.0
	for c in s:
		draw_texture_rect_region(_tex.fonte_numeros, Rect2(x, y, 8, 8), Rect2((c.unicode_at(0) - 48) * 16, 0, 16, 16))
		x += 8.0 * 0.7


func _desenhar_tempo() -> void:
	draw_texture_rect_region(_tex.ctgametimeframe, Rect2(506, 393, 134, 37), Rect2(0, 0, 134, 37))
	var x := 507.5 + 67.0
	draw_rect(Rect2(x, 407.5, 2, 2), Color.WHITE)
	draw_rect(Rect2(x, 412.5, 2, 2), Color.WHITE)
	_numero(x - 15.0, 404.5, tempo / 60, 1.1)
	_numero(x + 20.0, 404.5, tempo % 60, 1.1)


func _icone(nome: String, p: Vector2, tam: Vector2) -> void:
	draw_texture_rect_region(_tex[nome], Rect2(p, tam), Rect2(Vector2.ZERO, tam), Color(1, 1, 1, alfa))


func _desenhar_minimapa() -> void:
	var a := Color(1, 1, 1, alfa)
	draw_texture_rect_region(_tex.ctskillframe, Rect2(512, 179, 128, 53), Rect2(0, 0, 128, 53), a)
	draw_texture_rect(_tex.ctminmap, Rect2(512, 263, 128, 128), false, a)
	draw_texture_rect_region(_tex.ctminmapframe, Rect2(512, 232, 128, 165), Rect2(0, 0, 128, 165), a)
	_icone("ctminmap_TeamA_npc", minimapa(138, 44), Vector2(9, 9))
	_icone("ctminmap_TeamA_box", minimapa(138, 58), Vector2(9, 8))
	_icone("ctminmap_TeamB_box", minimapa(192, 113), Vector2(9, 8))
	_icone("ctminmap_TeamB_npc", minimapa(193, 126), Vector2(9, 9))
	for g in grupo:
		var id := int(g.id)
		if id == 0xFFFF or id == meu_id or id == reliquia:
			continue
		_icone("ctminmap_TeamA_member" if equipe == 0 else "ctminmap_TeamB_member", minimapa(g.x, g.y) - Vector2(3, 3), Vector2(7, 7))
	if reliquia != 0xFFFF and reliquia != meu_id:
		_icone("ctminmap_Relic", minimapa(rel_tile.x, rel_tile.y) - Vector2(5, 5), Vector2(14, 14))
	var b := Rect2(513, 238, 38, 24)
	var estado_b := 1 if b.has_point(_mouse_tela()) else 0
	draw_texture_rect_region(_tex.Bt_clearness_illusion, b, Rect2(0, 24 * estado_b, 38, 24), a)
	draw_texture_rect_region(_tex.ctminmap_Hero, Rect2(minimapa(meu_tile.x, meu_tile.y) - Vector2(4, 4), Vector2(11, 11)),
		Rect2(0, 0, 11, 11))
	_numero2d(532, 246, int(alfa * 100))
	_numero2d(583, 246, aliados)
	_numero2d(627, 246, ilusao)


func _desenhar_skill(f: Font) -> void:
	var tem: bool = pontos >= ABATES[skill]
	var t: Texture2D = _tex.skill2 if tem else _tex.non_skill2
	draw_texture_rect_region(t, Rect2(539, 200, 20, 28), Rect2((8 + skill - PROTECAO) * 20, 0, 20, 28), Color(1, 1, 1, alfa))
	_numero(539 + 55, 208, ABATES[skill])
	_numero(539 + 77, 208, pontos)
	var m := _mouse_tela()
	for s in [[Rect2(562, 201, 15, 13), _tex.ctskillup], [Rect2(562, 214, 15, 13), _tex.ctskilldown]]:
		var r: Rect2 = s[0]
		draw_texture_rect_region(s[1], r, Rect2(0, 13 * (1 if r.has_point(m) else 0), 15, 13), Color(1, 1, 1, alfa))
	# dicas (RenderTipTextList a 20 acima do ponto)
	if Rect2(540, 203, 18, 24).has_point(m):
		_dica(f, Vector2(540, 183), [[str(nomes_skill.get(skill, "Skill %d" % skill)), Color(0.4, 0.6, 1)], ["", Color.WHITE],
			[DicaItem.t(2379 + skill - PROTECAO), Color(0.55, 0.7, 1)]])
	elif Rect2(595, 203, 18, 24).has_point(m):
		_dica(f, Vector2(595, 183), [[DicaItem.t(2378), Color.WHITE]])
	elif Rect2(617, 203, 18, 24).has_point(m):
		_dica(f, Vector2(617, 183), [[DicaItem.t(2377), Color.WHITE]])


func _dica(f: Font, p: Vector2, linhas: Array) -> void:
	var w := 0.0
	for l in linhas:
		w = maxf(w, f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
	var r := Rect2(minf(p.x - w / 2 - 4, 636 - w - 8), p.y - linhas.size() * 13 - 4, w + 8, linhas.size() * 13 + 6)
	draw_rect(r, Color(0, 0, 0, 0.8))
	for i in linhas.size():
		draw_string(f, Vector2(r.position.x + 4, r.position.y + 13 + i * 13), linhas[i][0], HORIZONTAL_ALIGNMENT_CENTER, w, 10, linhas[i][1])


func _desenhar_placar() -> void:
	if _placar < 0:
		return
	var c := Color(1, 1, 1, _placar_alfa)
	var dig := func(lado: String, n: int, x: float) -> void:
		draw_texture_rect_region(_tex[lado + str(n)], Rect2(x, 160, 56, 66), Rect2(0, 0, 56, 66), c)
	if aliados >= 10:
		dig.call("a", aliados / 10 % 10, 196)
		dig.call("a", aliados % 10, 253)
	else:
		dig.call("a", aliados, 224)
	draw_texture_rect_region(_tex.ctscorevs1, Rect2(310, 168, 20, 45), Rect2(0, 0, 20, 45), c)
	if ilusao >= 10:
		dig.call("i", ilusao / 10 % 10, 331)
		dig.call("i", ilusao % 10, 388)
	else:
		dig.call("i", ilusao, 358)
	draw_texture_rect_region(_tex.ctscorealliedgaail, Rect2(232, 115, 40, 36), Rect2(0, 0, 40, 36), c)
	draw_texture_rect_region(_tex.ctscorevs0, Rect2(292, 123, 49, 27), Rect2(0, 0, 49, 27), c)
	draw_texture_rect_region(_tex.ctscoreillsiongaail, Rect2(367, 115, 40, 36), Rect2(0, 0, 40, 36), c)
	draw_texture_rect_region(_tex.ctscoreleft, Rect2(133, 115, 67, 125), Rect2(0, 0, 67, 125), c)
	draw_texture_rect_region(_tex.ctscoreright, Rect2(445, 115, 67, 125), Rect2(0, 0, 67, 125), c)


# RenderTutorialStep: titulo em azul claro, uma linha vazia e 3 linhas brancas, a 14 de passo
func _desenhar_tutorial(f: Font) -> void:
	if _tutorial < 0:
		return
	var base := 2400 + _tutorial * 4
	var linhas := [[DicaItem.t(base), AZUL], ["", Color.WHITE]]
	for i in 3:
		# o "?" do texto era uma seta no cliente coreano
		linhas.append([DicaItem.t(base + 1 + i).replace(" ? ", ": "), Color.WHITE])
	for j in linhas.size():
		var p := Vector2(140, 50 + j * 14 + 10)
		draw_string_outline(f, p, linhas[j][0], HORIZONTAL_ALIGNMENT_LEFT, 360, 10, 2, Color(0, 0, 0, 0.9))
		draw_string(f, p, linhas[j][0], HORIZONTAL_ALIGNMENT_LEFT, 360, 10, linhas[j][1])


# CCursedTempleProgressMsgBox: caixa de mensagem (topo e pe) em (640/2 - 115, 100), texto e a barra de
# 160x18 a 50 do fim com o enchimento de 150x8
func _desenhar_progresso(f: Font) -> void:
	var p := Vector2(320 - 115, 100)
	draw_texture_rect(_tex.inv_fundo, Rect2(p + Vector2(0, 2), Vector2(226, 111)), false)
	draw_texture_rect(_tex.msg_topo, Rect2(p, Vector2(230, 67)), false)
	draw_texture_rect(_tex.msg_baixo, Rect2(p + Vector2(0, 67), Vector2(230, 50)), false)
	var t := DicaItem.t(2417 if progresso_tipo == 0 else 2418)
	draw_string_outline(f, p + Vector2(0, 35 + 10), t, HORIZONTAL_ALIGNMENT_CENTER, 230, 10, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p + Vector2(0, 35 + 10), t, HORIZONTAL_ALIGNMENT_CENTER, 230, 10, Color.WHITE)
	var b := p + Vector2(115 - 80, 117 - 50)
	draw_texture_rect(_tex.barra_fundo, Rect2(b, Vector2(160, 18)), false)
	draw_texture_rect_region(_tex.barra, Rect2(b + Vector2(5, 5), Vector2(150 * clampf(_progresso_t / PROGRESSO, 0, 1), 8)),
		Rect2(0, 0, 150 * clampf(_progresso_t / PROGRESSO, 0, 1), 8))


# o mouse na tela de 640x480 colada embaixo
func _mouse_tela() -> Vector2:
	if _mouse.x < 0:
		return _mouse
	return _mouse + Vector2(512, 179)


func _clique_painel(ev: InputEvent) -> void:
	var e := _esc()
	if ev is InputEventMouseMotion:
		_mouse = ev.position / e
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		var m: Vector2 = ev.position / e + Vector2(512, 179)
		if ev.button_index == MOUSE_BUTTON_LEFT:
			if Rect2(513, 238, 38, 24).has_point(m):
				alfa = 0.51 if alfa == 1.0 else 1.0
				print("TESTE templo transparencia %d" % int(alfa * 100))
			elif Rect2(562, 201, 15, 13).has_point(m):
				trocar_skill(1)
			elif Rect2(562, 214, 15, 13).has_point(m):
				trocar_skill(-1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			trocar_skill(1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			trocar_skill(-1)
		painel.accept_event()
		queue_redraw()
