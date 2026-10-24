class_name JanelaGuilda
extends Control
# Janela da guilda do cliente S6 (CNewUIGuildInfoWindow, tecla G), 190x429 na direita.
# Sem guilda: so o texto de como entrar (185 a 187). Com guilda: tres abas, Guild (marca, pontos,
# membros e o botao de sair ou desfazer), Members (lista com cargo e servidor; o mestre ganha
# Position, Dissolve e Release) e Alliance (o texto de como fazer a alianca, que fica pra rodada 8).

signal sair()                              # Leave ou Disband
signal acao_membro(acao: int, nome: String, cargo: int)   # 0 Position, 1 Dissolve (tira o cargo), 2 Release

const PASTA := "res://dados/hud/"
const L := 190.0
const A := 429.0
const LINHA := 13
const VISIVEIS := 17

var aba := 1
var em_guilda := false
var guilda := -1
var meu_cargo := 255
var meu_nome := ""
var nivel := 0
var comando := 0
var dark_lord := false
var pontos := 0
var rival := ""
var membros: Array = []
var escolhido := -1
var rolagem := 0
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo01", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "btn_vazio", "btn_pequeno",
			"guilda_abas", "guilda_aba", "guilda_aba_titulo", "tab_ce", "tab_cd", "tab_be", "tab_bd", "tab_c", "tab_b",
			"tab_e", "tab_d"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


func _ajustar() -> void:
	var v := get_viewport_rect().size
	var barra := 51.0 * v.x / 640.0
	_esc = minf(v.x / 640.0, (v.y - barra) / A)
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2(v.x - L * _esc, 0)
	queue_redraw()


func definir(info: Dictionary) -> void:
	em_guilda = info.em_guilda
	pontos = info.pontos
	rival = info.rival
	membros = info.membros
	escolhido = mini(escolhido, membros.size() - 1)
	rolagem = clampi(rolagem, 0, maxi(membros.size() - VISIVEIS, 0))
	queue_redraw()


func limpar() -> void:
	em_guilda = false
	guilda = -1
	meu_cargo = 255
	membros = []
	escolhido = -1
	queue_redraw()


func sou_mestre() -> bool:
	return meu_cargo == 128


# o limite de membros do cliente: nivel / 10, o Dark Lord soma o comando / 10, no maximo 80
func limite() -> int:
	var n := nivel / 10 + (comando / 10 if dark_lord else 0)
	return mini(n, 80)


func nome_escolhido() -> String:
	return str(membros[escolhido].nome) if escolhido >= 0 and escolhido < membros.size() else ""


# --- desenho ---------------------------------------------------------------------

func _aba(i: int) -> Rect2:
	return Rect2(12 + i * 56, 68, 56, 22)


func _btn_sair_guilda() -> Rect2:
	return Rect2(L / 2 - 54 + 9, 350, 108, 29)


func _btn_membro(i: int) -> Rect2:
	return Rect2(3 + i * 61, 360, 64, 29)


func _linha(i: int) -> Rect2:
	return Rect2(13, 126 + i * LINHA, 148, LINHA)


func _sair() -> Rect2:
	return Rect2(13, 392, 36, 29)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo01, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	var s := _sair()
	draw_texture_rect_region(_tex.inv_sair, s, Rect2(0, 29 * (1 if s.has_point(_mouse) else 0), 36, 29))
	if not em_guilda:
		_texto(f, Vector2(0, 21), DicaItem.t(180), L, Color.WHITE)
		for i in 3:
			_texto(f, Vector2(25, 56 + i * 15), DicaItem.t(185 + i), 0, Color.WHITE)
		return
	_texto(f, Vector2(0, 21), DicaItem.t(180), L, Color.WHITE)
	_texto(f, Vector2(35, 57), "%s ( Score:%d )" % [Guildas.nome(guilda), pontos], 120, Color8(200, 255, 100))
	draw_texture_rect(_tex.guilda_abas, Rect2(12, 68, 166, 22), false)
	draw_texture_rect(_tex.guilda_aba, _aba(aba), false)
	for i in 3:
		var r := _aba(i)
		_texto(f, Vector2(r.position.x, 83), DicaItem.t([180, 1330, 1295][i]), 56,
			Color.WHITE if i == aba else Color(0.7, 0.7, 0.7))
	match aba:
		0: _aba_guilda(f)
		1: _aba_membros(f)
		2: _aba_alianca(f)


func _aba_guilda(f: Font) -> void:
	_moldura(Rect2(70, 104, 47, 47))
	var t := Guildas.tex(guilda)
	if t:
		draw_texture_rect(t, Rect2(74, 106, 39, 39), false)
	draw_rect(Rect2(10, 159, 171, 70), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(10, 159, 171, 70), Color8(110, 90, 50), false, 1.0)
	var linhas := ["%s :" % DicaItem.t(1332), DicaItem.t(1256) % pontos,
		DicaItem.t(1362) % [membros.size(), limite()] if sou_mestre() else DicaItem.t(1310) % membros.size(),
		"%s : %s" % [DicaItem.t(1321), rival if rival != "" else DicaItem.t(1361)]]
	for i in linhas.size():
		_texto(f, Vector2(22, 179 + i * 13), linhas[i], 0, Color8(230, 220, 200))
	draw_texture_rect(_tex.guilda_aba_titulo, Rect2(11, 237, 63, 25), false)
	_texto(f, Vector2(18, 254), DicaItem.t(1323), 0, Color8(255, 185, 1))
	draw_rect(Rect2(11, 260, 165, 84), Color(0, 0, 0, 0.8))
	_botao(_tex.btn_vazio, _btn_sair_guilda(), 108, DicaItem.t(188 if sou_mestre() else 189))


func _aba_membros(f: Font) -> void:
	draw_rect(Rect2(12, 105, 165, 20), Color8(59, 59, 59, 150))
	draw_rect(Rect2(12, 125, 165, 232), Color8(21, 21, 21, 150))
	_moldura(Rect2(8, 105, 174, 256))
	for c in [[24, 1389], [86, 1307], [128, 1022]]:
		draw_string(f, Vector2(c[0], 119), DicaItem.t(c[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	for j in mini(VISIVEIS, membros.size() - rolagem):
		var i := j + rolagem
		var m: Dictionary = membros[i]
		var r := _linha(j)
		var cor := Color8(230, 220, 200) if m.online else Color8(140, 130, 120)
		if i == escolhido:
			draw_rect(r, Color8(220, 210, 180, 230))
			cor = Color.BLACK
		elif r.has_point(_mouse):
			draw_rect(r, Color(1, 1, 1, 0.08))
		draw_string(f, Vector2(21, r.position.y + 10), str(m.nome), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cor)
		draw_string(f, Vector2(66, r.position.y + 10), Guildas.cargo(m.cargo), HORIZONTAL_ALIGNMENT_CENTER, 70, 10, cor)
		if m.online:
			draw_string(f, Vector2(143, r.position.y + 10), str(int(m.servidor) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color.BLACK if i == escolhido else Color8(255, 196, 0))
	if membros.size() > VISIVEIS:
		var trilho := Rect2(170, 128, 4, 226)
		draw_rect(trilho, Color(0, 0, 0, 0.6))
		var h := trilho.size.y * VISIVEIS / membros.size()
		var y := trilho.position.y + (trilho.size.y - h) * rolagem / maxf(membros.size() - VISIVEIS, 1)
		draw_rect(Rect2(169, y, 6, h), Color8(170, 140, 60))
	if sou_mestre():
		for i in 3:
			_botao(_tex.btn_pequeno, _btn_membro(i), 64, DicaItem.t(1307 + i))


func _aba_alianca(f: Font) -> void:
	var y := 116
	for grupo in [[1257, 1261], [1262, 1264], [1265, 1267]]:
		for n in range(grupo[0], grupo[1] + 1):
			_texto(f, Vector2(25, y), DicaItem.t(n), 0, Color.WHITE)
			y += 15
		y += 10 if grupo[0] == 1257 else 5


func _moldura(r: Rect2) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x - 14
	var y1 := r.end.y - 14
	draw_texture_rect(_tex.tab_c, Rect2(x0 + 14, y0, x1 - x0 - 14, 14), false)
	draw_texture_rect(_tex.tab_b, Rect2(x0 + 14, y1, x1 - x0 - 14, 14), false)
	draw_texture_rect(_tex.tab_e, Rect2(x0, y0 + 14, 14, y1 - y0 - 14), false)
	draw_texture_rect(_tex.tab_d, Rect2(x1, y0 + 14, 14, y1 - y0 - 14), false)
	draw_texture_rect(_tex.tab_ce, Rect2(x0, y0, 14, 14), false)
	draw_texture_rect(_tex.tab_cd, Rect2(x1, y0, 14, 14), false)
	draw_texture_rect(_tex.tab_be, Rect2(x0, y1, 14, 14), false)
	draw_texture_rect(_tex.tab_bd, Rect2(x1, y1, 14, 14), false)


func _botao(t: Texture2D, r: Rect2, w: int, txt: String) -> void:
	draw_texture_rect_region(t, r, Rect2(0, 29 * (1 if r.has_point(_mouse) else 0), w, 29))
	_texto(get_theme_default_font(), Vector2(r.position.x, r.position.y + 18), txt, r.size.x, Color.WHITE)


func _texto(f: Font, p: Vector2, t: String, largura: float, cor: Color) -> void:
	var al := HORIZONTAL_ALIGNMENT_CENTER if largura > 0 else HORIZONTAL_ALIGNMENT_LEFT
	var w := largura if largura > 0 else -1.0
	draw_string_outline(f, p, t, al, w, 10, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, w, 10, cor)


# --- mouse -----------------------------------------------------------------------

func clicar(p: Vector2) -> void:
	if _sair().has_point(p):
		visible = false
		return
	if not em_guilda:
		return
	for i in 3:
		if _aba(i).has_point(p):
			aba = i
			queue_redraw()
			return
	if aba == 0 and _btn_sair_guilda().has_point(p):
		sair.emit()
	elif aba == 1:
		for j in mini(VISIVEIS, membros.size() - rolagem):
			if _linha(j).has_point(p):
				escolhido = j + rolagem
				queue_redraw()
				return
		if sou_mestre():
			for i in 3:
				if _btn_membro(i).has_point(p) and nome_escolhido() != "":
					acao_membro.emit(i, nome_escolhido(), int(membros[escolhido].cargo))


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			clicar(ev.position)
		elif ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and aba == 1:
			rolagem = clampi(rolagem + (1 if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0,
				maxi(membros.size() - VISIVEIS, 0))
			queue_redraw()
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()
