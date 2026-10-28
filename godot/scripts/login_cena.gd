class_name LoginCena
extends Control
# Tela de login do MU S6, no jeito do MuMain: LoginScene.cpp (o mapa World74 com a camera
# passeando pelo caminho do CWScript74.cws, a musica login_theme e o logo do MU acendendo),
# CLoginWin (login_back com Account, Password, OK e Cancel, a 2/3 da altura) e o rodape com a
# versao e o copyright. Tudo desenhado em 800 x 600 e esticado como no cliente (escala de 1 a 2).
# O servidor e a porta (o MU le do launcher) ficam no canto de baixo, pro estudo.

signal ok

const PASTA := "res://dados/login/"
const MUNDO := 74   # WD_73NEW_LOGIN_SCENE: o cliente le Data/World74
const BRANCO := Color.WHITE
const TEXTO_CAMPO := Color8(255, 255, 230)
const FONTE := 11
# CameraMove.h (LoginSceneCameraDefaults): o caminho do arquivo e corrigido por este desvio,
# a camera fica em z -300 + 950 e olha 72,5 graus abaixo do alto (-112,5 + 40), girada -5
const DESVIO := Vector3(-300.0, 650.0, 950.0)
const Z_TOUR := -300.0
const INCLINA := -72.5
const GIRO_EXTRA := -5.0
const MISTURA := 300.0      # kTourBlendDistance: a curva comeca 300 antes do ponto
const GIRO_MAX := 1.0       # kTourMaxRotateSpeed: graus por quadro
const DISTANCIA := 110.0    # TOUR_BASE_DISTANCE * 0,1 por nivel do ponto
const LONGE := 390.0        # TOUR_VIEWFAR_PER_LEVEL

var palco: Node
var volume := 0.8
var campo_host: LineEdit
var campo_porta: LineEdit
var campo_conta: LineEdit
var campo_senha: LineEdit
var botao: Button           # escondido: o jogo trava (disabled) enquanto conecta
var aviso: Label
var lista: VBoxContainer
var servidor_nome := ""     # [OpenMU-1 Server] quando a lista chega
var pontos: Array = []      # [x, y, demora, aceleracao, nivel] do CWScript
var _mundo: Node3D
var _musica: AudioStreamPlayer
var _tex := {}
var _textos := {}
var _brilho: Control
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _apertou := ""
var _alfa := 0.0            # g_fMULogoAlpha: sobe 0,02 por quadro
# CCameraMove no modo tour
var _alvo := 0
var _atual := Vector2.ZERO  # m_CurrentCameraPos (no segmento)
var _tour := Vector2.ZERO   # m_vTourCameraPos (com a curva)
var _angulo := 0.0
var _angulo_alvo := 0.0
var _nivel := 8.0
var _demora := 0.0


func _ready() -> void:
	for n in ["janela", "caixa", "ok", "cancelar", "logo", "logo_g"]:
		_tex[n] = load(PASTA + n + ".png")
	if FileAccess.file_exists("res://dados/textos_eng.json"):
		_textos = JSON.parse_string(FileAccess.get_file_as_string("res://dados/textos_eng.json"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_brilho = Control.new()
	_brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   # EnableAlphaBlend: o brilho soma
	_brilho.material = m
	_brilho.draw.connect(_desenhar_brilho)
	_brilho.show_behind_parent = true   # o brilho vai por baixo do logo, como no LoginScene
	add_child(_brilho)
	campo_conta = _campo(10, false)
	campo_senha = _campo(20, true)
	campo_host = _campo(64, false, true)
	campo_porta = _campo(5, false, true)
	botao = Button.new()
	botao.visible = false
	add_child(botao)
	aviso = Label.new()
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.add_theme_font_size_override("font_size", FONTE)
	aviso.add_theme_color_override("font_color", BRANCO)
	aviso.add_theme_constant_override("outline_size", 3)
	aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(aviso)
	lista = VBoxContainer.new()
	lista.add_theme_constant_override("separation", 4)
	add_child(lista)
	pontos = ler_caminho("res://dados/mundo%d/caminho.json" % MUNDO)
	get_viewport().size_changed.connect(_ajustar)
	visibility_changed.connect(_visivel)
	_ajustar()
	_visivel()


func _campo(maximo: int, secreto: bool, pequeno := false) -> LineEdit:
	var c := LineEdit.new()
	c.max_length = maximo
	c.secret = secreto
	c.add_theme_font_size_override("font_size", FONTE if not pequeno else 10)
	c.add_theme_color_override("font_color", TEXTO_CAMPO)
	c.add_theme_color_override("caret_color", TEXTO_CAMPO)
	var vazio := StyleBoxEmpty.new()
	for e in ["normal", "focus", "read_only"]:
		c.add_theme_stylebox_override(e, vazio)
	if pequeno:
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0, 0, 0, 0.55)
		f.content_margin_left = 4
		c.add_theme_stylebox_override("normal", f)
		c.add_theme_stylebox_override("focus", f)
		c.add_theme_stylebox_override("read_only", f)
	add_child(c)
	return c


# o CWScript74.cws vira dados/mundo74/caminho.json no exportar (ferramentas/caminho_login.py)
static func ler_caminho(arq: String) -> Array:
	if not FileAccess.file_exists(arq):
		return []
	var j = JSON.parse_string(FileAccess.get_file_as_string(arq))
	return j if j is Array else []


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = clampf(minf(v.x / 800.0, v.y / 600.0), 1.0, 2.0)
	scale = Vector2(_esc, _esc)
	position = Vector2.ZERO
	size = v / _esc
	_brilho.size = size
	var o := janela()
	campo_conta.position = o + Vector2(115, 108)
	campo_senha.position = o + Vector2(115, 133)
	for c in [campo_conta, campo_senha]:
		c.size = Vector2(140, 20)
	aviso.position = o + Vector2(0, 250)
	aviso.size = Vector2(329, 0)
	lista.position = o + Vector2(64, 290)
	lista.size = Vector2(200, 0)
	campo_host.position = Vector2(size.x - 238, size.y - 44)
	campo_host.size = Vector2(150, 18)
	campo_porta.position = Vector2(size.x - 56, size.y - 44)
	campo_porta.size = Vector2(46, 18)


# CUIMng::CreateLoginScene: no meio, a 2/3 da altura que sobra
func janela() -> Vector2:
	return Vector2(roundf((size.x - 329) / 2.0), roundf((size.y - 245) * 2.0 / 3.0))


func _botoes() -> Dictionary:
	var o := janela()
	return {"ok": Rect2(o + Vector2(150, 172), Vector2(54, 30)), "cancelar": Rect2(o + Vector2(211, 172), Vector2(54, 30))}


# --- mundo e camera -----------------------------------------------------------------

func _visivel() -> void:
	if not is_inside_tree():
		return
	if visible and _mundo == null and palco:
		_montar_mundo()
	elif not visible and _mundo:
		_mundo.queue_free()
		_mundo = null
		if _musica:
			_musica.queue_free()
			_musica = null
	if visible:
		_alfa = 0.0
		(campo_conta if campo_conta.text == "" else campo_senha).grab_focus.call_deferred()


func mudar_volume(v: float) -> void:
	volume = v
	if _musica:
		_musica.volume_db = -8.0 + linear_to_db(maxf(volume, 0.001) / 0.8)


func _montar_mundo() -> void:
	_mundo = Node3D.new()   # marca que ja esta montando
	if PacoteMapa.precisa(MUNDO):
		await PacoteMapa.carregar(self, MUNDO)
	if not visible:
		_mundo = null
		return
	if pontos.is_empty():   # no navegador o caminho vem no pacote do mapa
		pontos = ler_caminho("res://dados/mundo%d/caminho.json" % MUNDO)
	_mundo = Node3D.new()
	_mundo.set_script(load("res://scripts/mundo.gd"))
	_mundo.modo_jogo = true
	_mundo.numero = MUNDO
	_mundo.fixa = true
	iniciar_tour(0)
	_mundo.camera_fixa = camera()
	palco.add_child(_mundo)
	_musica = AudioStreamPlayer.new()
	var mp := "res://dados/mundo%d/musica.mp3" % MUNDO
	if ResourceLoader.exists(mp):
		var s := load(mp) as AudioStreamMP3
		s.loop = true
		_musica.stream = s
		_musica.volume_db = -8.0 + linear_to_db(maxf(volume, 0.001) / 0.8)
		add_child(_musica)
		_musica.play()


# CCameraMove::SetTourMode: sai do ponto anterior ao alvo, olhando pra ele
func iniciar_tour(alvo: int) -> void:
	if pontos.size() < 2:
		return
	_alvo = alvo % pontos.size()
	var de: Array = pontos[(_alvo - 1 + pontos.size()) % pontos.size()]
	var pra: Array = pontos[_alvo]
	_atual = Vector2(de[0], de[1])
	_tour = _atual
	_angulo = _criar_angulo(Vector2(pra[0], pra[1]) - _atual)
	_angulo_alvo = _angulo
	_nivel = de[4]
	_demora = 0.0


# CreateAngle(0, 0, x, -y): 0 olha pro +y do MU, 90 pro +x
static func _criar_angulo(d: Vector2) -> float:
	if d.length() < 0.0001:
		return 0.0
	return fposmod(rad_to_deg(atan2(d.x, d.y)), 360.0)


# CCameraMove::UpdateTourWayPoint num quadro de 25 por segundo (q = quantos quadros passaram)
func passo_tour(q: float) -> void:
	var n := pontos.size()
	if n < 2:
		return
	for _volta in 8:
		var alvo: Array = pontos[_alvo]
		var origem: Array = pontos[(_alvo - 1 + n) % n]
		if _demora < float(alvo[2]):
			_demora += q
			return
		var acel := clampf(float(alvo[3]), 0.1, 100.0) * q
		var p_alvo := Vector2(alvo[0], alvo[1])
		var p_origem := Vector2(origem[0], origem[1])
		var ate_alvo := _atual.distance_to(p_alvo)
		var ate_origem := _atual.distance_to(p_origem)
		var frente := (p_alvo - _atual).normalized()
		var dir := frente
		if ate_alvo <= MISTURA:
			var prox: Array = pontos[(_alvo + 1) % n]
			var seg := Vector2(prox[0], prox[1]) - p_alvo
			if seg.length() > 0.0001:
				var t := ate_alvo / MISTURA * 0.5 + 0.5
				dir = (seg.normalized() * (1.0 - t) + frente * t).normalized()
		elif ate_origem <= MISTURA:
			var ant: Array = pontos[(_alvo - 2 + n * 2) % n]
			var seg := p_origem - Vector2(ant[0], ant[1])
			if seg.length() > 0.0001:
				var t := ate_origem / MISTURA * 0.5 + 0.5
				dir = (seg.normalized() * (1.0 - t) + frente * t).normalized()
		if ate_alvo <= acel:
			_alvo = (_alvo + 1) % n
			_demora = 0.0
			continue
		if ate_alvo > 5.0 and ate_origem > 5.0:
			_angulo_alvo = _criar_angulo(dir)
		var delta := fposmod(_angulo_alvo - _angulo + 180.0, 360.0) - 180.0
		var giro := clampf(absf(delta) / 30.0, 0.0, GIRO_MAX) * q
		_angulo = _angulo_alvo if absf(delta) <= giro else fposmod(_angulo + giro * signf(delta), 360.0)
		_atual += frente * acel
		_tour += dir * acel
		var total := ate_origem + ate_alvo
		_nivel = (float(origem[4]) * ate_alvo + float(alvo[4]) * ate_origem) / total if total > 0.0001 else float(alvo[4])
		return


# a camera do quadro: o ponto do tour com o desvio, recuada pela distancia do nivel na direcao
# em que olha (Angle[0] -72,5, Angle[2] = angulo - 5), em metros do Godot (x, z, -y) / 100
func camera() -> Transform3D:
	var giro := _angulo + GIRO_EXTRA
	var b := Basis(Vector3.BACK, deg_to_rad(-giro)) * Basis(Vector3.RIGHT, deg_to_rad(-INCLINA))
	var frente := b * Vector3(0, 0, -1)
	var p := Vector3(_tour.x + DESVIO.x, _tour.y + DESVIO.y, Z_TOUR + DESVIO.z) - frente * DISTANCIA * _nivel
	var g := Basis(Vector3.RIGHT, -PI / 2) * b
	return Transform3D(g, Vector3(p.x, p.z, -p.y) * 0.01)


func _process(dt: float) -> void:
	var q := minf(dt * 25.0, 4.0)
	_alfa = minf(_alfa + 0.02 * q, 10.0)
	if _mundo and is_instance_valid(_mundo) and _mundo.get_script() != null:
		passo_tour(q)
		_mundo.camera_fixa = camera()
		var v := get_viewport_rect().size
		# hFov 90 (CameraConfig::ForLoginScene) virado em vertical pela tela
		_mundo.fixa_fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(45.0)) * v.y / maxf(v.x, 1.0)))
		_mundo.fixa_longe = LONGE * _nivel * 0.01 * 1.3
		if _mundo.is_inside_tree() and _mundo.camera:
			_mundo._mirar()
	if visible:
		queue_redraw()
		_brilho.queue_redraw()


# --- desenho ------------------------------------------------------------------------

func _logo_rect() -> Rect2:
	# 256 x 128 * 0,8 em 640 x 480, no meio, 25 do alto (LoginScene.cpp)
	return Rect2(size.x / 2.0 - 128.0, 31.0, 256.0, 128.0)


func _desenhar_brilho() -> void:
	var g := clampf(_alfa - 0.3, 0.0, 1.0)
	if g > 0.0:
		_brilho.draw_texture_rect(_tex.logo_g, _logo_rect(), false, Color(g, g, g))


func _draw() -> void:
	var f := get_theme_default_font()
	draw_texture_rect(_tex.logo, _logo_rect(), false, Color(1, 1, 1, clampf(_alfa, 0.0, 1.0)))
	var o := janela()
	draw_texture(_tex.janela, o)
	draw_texture(_tex.caixa, o + Vector2(109, 106))
	draw_texture(_tex.caixa, o + Vector2(109, 131))
	_texto(f, o + Vector2(30, 113), _t(450, "Account"), 0, BRANCO)
	_texto(f, o + Vector2(30, 139), _t(451, "Password"), 0, BRANCO)
	var nome := servidor_nome if servidor_nome != "" else "[%s]" % campo_host.text
	_texto(f, o + Vector2(111, 80), nome, 0, BRANCO)
	var b := _botoes()
	_botao(_tex.ok, b.ok, not botao.disabled, "ok")
	_botao(_tex.cancelar, b.cancelar, true, "cancelar")
	# canto do servidor (o launcher do MU passa o IP e a porta)
	_texto(f, campo_host.position + Vector2(-50, 3), "Servidor", 0, Color8(200, 200, 200))
	_texto(f, campo_porta.position + Vector2(-34, 3), "Porta", 0, Color8(200, 200, 200))
	# rodape: versao na esquerda e o copyright partido no 335 de 640
	var y := size.y - 15.0
	var meio := size.x * 335.0 / 640.0
	var c1 := _t(454, "(c) Copyright 2001 Webzen")
	var w1 := f.get_string_size(c1, HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE).x
	draw_rect(Rect2(meio - w1, y, w1, 14), Color(0, 0, 0, 0.5))
	_texto(f, Vector2(meio - w1, y), c1, 0, BRANCO)
	var c2 := _t(455, " All Rights Reserved.")
	draw_rect(Rect2(meio, y, f.get_string_size(c2, HORIZONTAL_ALIGNMENT_LEFT, -1, FONTE).x, 14), Color(0, 0, 0, 0.5))
	_texto(f, Vector2(meio, y), c2, 0, BRANCO)
	_texto(f, Vector2(2, y), "Ver: 1.04d (Godot)", 0, BRANCO)


func _t(n: int, padrao: String) -> String:
	return str(_textos.get(str(n), padrao))


# 3 quadros de 30 (CButton 3, 2, 1): normal, em cima, apertado; desligado fica no apertado
func _botao(t: Texture2D, r: Rect2, ligado: bool, nome: String) -> void:
	var q := 0
	if not ligado:
		q = 2
	elif r.has_point(_mouse):
		q = 2 if _apertou == nome and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1
	draw_texture_rect_region(t, r, Rect2(0, q * 30, 54, 30), Color(1, 1, 1, 0.55 if not ligado else 1.0))


func _texto(f: Font, p: Vector2, t: String, largura: float, cor: Color) -> void:
	var al := HORIZONTAL_ALIGNMENT_CENTER if largura > 0 else HORIZONTAL_ALIGNMENT_LEFT
	var w := largura if largura > 0 else -1.0
	var base := p + Vector2(0, f.get_ascent(FONTE))
	draw_string_outline(f, base, t, al, w, FONTE, 2, Color(0, 0, 0, 0.8))
	draw_string(f, base, t, al, w, FONTE, cor)


# --- entrada ------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		if ev.pressed:
			_apertou = _botao_em(ev.position)
		else:
			var b := _botao_em(ev.position)
			if b != "" and b == _apertou:
				clicar(b)
			_apertou = ""
		accept_event()


func _botao_em(p: Vector2) -> String:
	var b := _botoes()
	for n in b:
		if b[n].has_point(p):
			return n
	return ""


func clicar(b: String) -> void:
	if b == "ok" and not botao.disabled:
		ok.emit()
	elif b == "cancelar":
		# CLoginWin::CancelLogin: limpa os campos
		campo_conta.text = ""
		campo_senha.text = ""
		campo_conta.grab_focus()
