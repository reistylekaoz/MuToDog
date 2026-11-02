class_name MenuSistema
extends Control
# Menu do jogo (Esc, U ou o botao da barra) como o cliente S6, desenhado com as texturas dele:
# - a caixa do Esc (CSystemMenuMsgBox): caixa de mensagem de 230 com topo, 5 meios e pe, a 100 do alto
#   na tela de 640; 5 botoes vazios de 108x29 no meio, a partir de y 23, de 30 em 30: Exit Game, Select
#   Server, Switch Character, Option e Cancel (textos 381 a 385 e 384);
# - a janela Option (CNewUIOptionWindow): moldura de 190 (topo de 64, laterais de 10 em 10, pe de 45),
#   linhas e pontos do cliente, barras de volume de 124x16 em 10 passos e o Close de 54x30 em x 68.
#   Aqui ela tem Volume (efeitos), musica, brilho, a luz nova e as texturas HD (Polido, so no PC); o resto das opcoes do cliente nao existe neste jogo.
# As opcoes ficam guardadas em user://opcoes.cfg.

signal musica(v: float)
signal efeitos(v: float)
signal brilho(v: float)
signal luz_nova(ligada: bool)
signal trocar_personagem
signal trocar_servidor
signal mover
signal sair_jogo

const ARQ := "user://opcoes.cfg"
const PASTA := "res://dados/hud/"
const L_CAIXA := 230.0
const L_OPCAO := 190.0
const LATERAIS := 19            # pedacos de 10 entre o topo e o pe da janela Option
const BRILHO_DE := 0.5
const BRILHO_ATE := 3.0

var vol_musica := 0.8
var vol_efeitos := 0.8
var _brilho := 2.0
var _luz := true
var _hd := true
var _hd_aviso := false          # mudou o HD: vale ao abrir o jogo de novo
var pagina := "menu"            # "menu" (caixa do Esc) ou "opcao"
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _apertado := ""             # botao com o mouse apertado em cima
var _arrastando := ""           # barra sendo arrastada


func _ready() -> void:
	var c := ConfigFile.new()
	if c.load(ARQ) == OK:
		vol_musica = c.get_value("som", "musica", vol_musica)
		vol_efeitos = c.get_value("som", "efeitos", vol_efeitos)
	for n in ["msg_fundo", "msg_topo", "msg_meio", "msg_baixo", "btn_vazio", "opc_topo", "opc_esq", "opc_dir", "opc_baixo",
			"opc_linha", "opc_ponto", "opc_vol_fundo", "opc_vol_cor", "opc_fechar"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	visible = false


func alternar(brilho_atual: float) -> void:
	visible = not visible
	_brilho = brilho_atual
	_luz = Polido.opcao()
	_hd = Polido.opcao_hd()
	pagina = "menu"
	_arrastando = ""
	_apertado = ""
	if visible:
		move_to_front()
		_ajustar()


func _altura_opcao() -> float:
	return 64.0 + LATERAIS * 10.0 + 45.0


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	if pagina == "menu":
		size = Vector2(L_CAIXA, 67.0 + 5 * 15.0 + 50.0)
		position = Vector2((v.x - L_CAIXA * _esc) / 2.0, 100.0 * _esc)
	else:
		size = Vector2(L_OPCAO, _altura_opcao())
		position = Vector2((v.x - L_OPCAO * _esc) / 2.0, maxf((v.y - size.y * _esc) / 2.0, 0.0))
	queue_redraw()


# --- caixa do Esc ---------------------------------------------------------------

func _botoes() -> Array:
	return [["sair", DicaItem.t(381)], ["servidor", DicaItem.t(382)], ["personagem", DicaItem.t(383)],
		["opcao", DicaItem.t(385)], ["cancelar", DicaItem.t(384)]]


func _rect_botao(i: int) -> Rect2:
	return Rect2(L_CAIXA / 2.0 - 54.0, 23.0 + i * 30.0, 108.0, 29.0)


# --- janela Option --------------------------------------------------------------

# [nome, texto, y do texto, y da barra]
func _barras() -> Array:
	return [["efeitos", DicaItem.t(389), 80.0, 92.0], ["musica", "Music", 122.0, 134.0],
		["brilho", "Brightness (- and =)", 164.0, 176.0]]


func _rect_barra(y: float) -> Rect2:
	return Rect2(33.0, y, 124.0, 16.0)


# caixa de marcar da luz nova, embaixo das barras
func _rect_luz() -> Rect2:
	return Rect2(20.0, 204.0, 150.0, 14.0)


func _rect_hd() -> Rect2:
	return Rect2(20.0, 224.0, 150.0, 14.0)


func _rect_fechar() -> Rect2:
	return Rect2(68.0, _altura_opcao() - 38.0, 54.0, 30.0)


func _valor(nome: String) -> float:
	match nome:
		"efeitos": return vol_efeitos
		"musica": return vol_musica
	return (_brilho - BRILHO_DE) / (BRILHO_ATE - BRILHO_DE)


func _mudar(nome: String, x: float) -> void:
	var f := clampf((x - 33.0) / 124.0, 0.0, 1.0)
	match nome:
		"efeitos":
			vol_efeitos = roundf(f * 10.0) / 10.0   # 10 passos, como o cliente
			_guardar()
			efeitos.emit(vol_efeitos)
		"musica":
			vol_musica = roundf(f * 10.0) / 10.0
			_guardar()
			musica.emit(vol_musica)
		"brilho":
			_brilho = BRILHO_DE + f * (BRILHO_ATE - BRILHO_DE)
			brilho.emit(_brilho)
	queue_redraw()


# --- desenho --------------------------------------------------------------------

func _draw() -> void:
	var f := get_theme_default_font()
	if pagina == "menu":
		var a := size.y
		draw_texture_rect(_tex.msg_fundo, Rect2(0, 2, L_CAIXA - 5, a - 4), false)
		draw_texture_rect(_tex.msg_topo, Rect2(0, 0, L_CAIXA, 67), false)
		for i in 5:
			draw_texture_rect(_tex.msg_meio, Rect2(0, 67 + i * 15, L_CAIXA, 15), false)
		draw_texture_rect(_tex.msg_baixo, Rect2(0, a - 50, L_CAIXA, 50), false)
		var bs := _botoes()
		for i in bs.size():
			var r := _rect_botao(i)
			var linha := 2 if _apertado == bs[i][0] else (1 if r.has_point(_mouse) else 0)
			draw_texture_rect_region(_tex.btn_vazio, r, Rect2(0, 29 * linha, 108, 29))
			draw_string(f, Vector2(r.position.x, r.position.y + 18), bs[i][1], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10, Color.WHITE)
		return
	var h := _altura_opcao()
	draw_texture_rect(_tex.msg_fundo, Rect2(0, 0, L_OPCAO, h), false)
	draw_texture_rect(_tex.opc_topo, Rect2(0, 0, L_OPCAO, 64), false)
	for i in LATERAIS:
		draw_texture_rect(_tex.opc_esq, Rect2(0, 64 + i * 10, 21, 10), false)
		draw_texture_rect(_tex.opc_dir, Rect2(L_OPCAO - 21, 64 + i * 10, 21, 10), false)
	draw_texture_rect(_tex.opc_baixo, Rect2(0, h - 45, L_OPCAO, 45), false)
	draw_string_outline(f, Vector2(0, 16), DicaItem.t(385), HORIZONTAL_ALIGNMENT_CENTER, L_OPCAO, 11, 2, Color(0, 0, 0, 0.9))
	draw_string(f, Vector2(0, 16), DicaItem.t(385), HORIZONTAL_ALIGNMENT_CENTER, L_OPCAO, 11, Color(1, 0.9, 0.7))
	for b in _barras():
		draw_texture_rect(_tex.opc_ponto, Rect2(20, b[2] - 2, 10, 10), false)
		draw_string(f, Vector2(40, b[2] + 7), b[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		var r := _rect_barra(b[3])
		draw_texture_rect(_tex.opc_vol_fundo, r, false)
		var v := _valor(b[0])
		if v > 0.0:
			draw_texture_rect_region(_tex.opc_vol_cor, Rect2(r.position, Vector2(124.0 * v, 16.0)), Rect2(0, 0, 124.0 * v, 16.0))
		draw_texture_rect(_tex.opc_linha, Rect2(18, b[3] + 22, 154, 2), false)
	_marcar(f, _rect_luz(), _luz, "New lighting (shadows)")
	var rh := _rect_hd()
	if not OS.has_feature("web"):   # no navegador nao tem pacote HD
		_marcar(f, rh, _hd, "HD textures")
	if _hd_aviso:
		draw_string(f, Vector2(rh.position.x + 32, rh.end.y + 10), "Applies when the game restarts", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.8, 0.4))
	draw_texture_rect(_tex.opc_linha, Rect2(18, rh.end.y + 16, 154, 2), false)
	var fe := _rect_fechar()
	var lf := 2 if _apertado == "fechar" else (1 if fe.has_point(_mouse) else 0)
	draw_texture_rect_region(_tex.opc_fechar, fe, Rect2(0, 30 * lf, 54, 30))


func _marcar(f: Font, r: Rect2, ligado: bool, texto: String) -> void:
	var cx := Rect2(r.position.x + 13, r.position.y + 1, 12, 12)
	draw_rect(cx, Color(0.05, 0.05, 0.05, 0.9))
	draw_rect(cx, Color(0.6, 0.5, 0.35) if r.has_point(_mouse) else Color(0.4, 0.35, 0.28), false, 1.0)
	if ligado:
		draw_rect(cx.grow(-3), Color(1, 0.85, 0.4))
	draw_string(f, Vector2(r.position.x + 32, r.position.y + 11), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


# --- mouse ----------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		if _arrastando != "":
			_mudar(_arrastando, ev.position.x)
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		if ev.pressed:
			_apertado = _sob_mouse(ev.position)
			if pagina == "opcao":
				for b in _barras():
					if _rect_barra(b[3]).grow_individual(0, 0, 4, 0).has_point(ev.position):
						_arrastando = b[0]
						_mudar(b[0], ev.position.x)
		else:
			var solto := _sob_mouse(ev.position)
			if solto != "" and solto == _apertado:
				_clicou(solto)
			_apertado = ""
			_arrastando = ""
		queue_redraw()
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()


func _sob_mouse(p: Vector2) -> String:
	if pagina == "menu":
		var bs := _botoes()
		for i in bs.size():
			if _rect_botao(i).has_point(p):
				return bs[i][0]
		return ""
	if _rect_luz().has_point(p):
		return "luz"
	if _rect_hd().has_point(p) and not OS.has_feature("web"):
		return "hd"
	return "fechar" if _rect_fechar().has_point(p) else ""


func _clicou(nome: String) -> void:
	match nome:
		"sair":
			visible = false
			sair_jogo.emit()
		"servidor":
			visible = false
			trocar_servidor.emit()
		"personagem":
			visible = false
			trocar_personagem.emit()
		"opcao":
			pagina = "opcao"
			_ajustar()
		"luz":
			_luz = not _luz
			luz_nova.emit(_luz)
		"hd":
			_hd = not _hd
			_hd_aviso = true
			Polido.guardar_opcao_hd(_hd)
		"cancelar", "fechar":
			visible = false


func _guardar() -> void:
	var c := ConfigFile.new()
	c.load(ARQ)   # a luz nova (Polido) mora no mesmo arquivo
	c.set_value("som", "musica", vol_musica)
	c.set_value("som", "efeitos", vol_efeitos)
	c.save(ARQ)
