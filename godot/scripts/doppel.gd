class_name Doppel
extends Control
# Doppelganger durante o evento (CNewUIDoppelGangerFrame e CGMDoppelGanger do S6), desenhado na tela de
# 640x480 colada embaixo (largura da janela / 640):
#   moldura de 227x87 em (413, 342): "Monsters Passed: ( n/max )" (laranja, laranja escuro, vermelho pelos
#     que ja passaram), "Time Left" e o relogio MM:SS:cc na fonte grande (os centesimos correm sozinhos);
#   a barra do caminho (59, 78, 167x7) enchendo da direita ate o monstro da frente, na cor de quantos ja
#     passaram (amarela sobre nada, laranja sobre amarela, vermelha sobre laranja);
#   o Ice Walker (13x7) e cada um do grupo (9x8, o heroi com a marca dele) no caminho.
# Os numeros andam 0,01 por quadro ate o que o servidor mandou (C1 BF 0F, 11 e 12).
# Estado (C1 BF 10): 2 mostra a moldura e liga a musica; o resultado (C1 BF 13) para o relogio e a musica.

const PASTA := "res://dados/hud/doppel/"
const SONS := "res://dados/mundo0/doppel/%s"   # sons, musica e as texturas do Ice Walker e da Larva: no pacote dos monstros dos eventos (PacoteMapa.MONSTROS)
const MAPAS := [65, 66, 67, 68]
const CAMINHO := 22.0
const PASSO := 0.01

var mostrando := false      # INTERFACE_DOPPELGANGER_FRAME
var ligado := false         # EnabledDoppelGangerEvent: so com ele a musica toca
var passaram := 0
var maximo := 0
var tempo := 600
var parado := false
var monstro := 0.0
var monstro_vai := 0.0
var gelo := false
var gelo_pos := 0.0
var gelo_vai := 0.0
var grupo := {}             # id -> [pos, pos que chegou (-1 = nao veio no ultimo)]
var meu_id := -1
var som: Som
var _tex := {}
var _quadro := 0.0


func _ready() -> void:
	for n in ["double_back", "double_bary", "double_baro", "double_barr", "double_micon01", "double_baricon01", "double_baricon04"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


static func no_doppel(mapa: int) -> bool:
	return mapa in MAPAS


# o jogo chama ao trocar de mapa: fora dos 4 mapas a moldura some
func mapa(m: int) -> void:
	if not no_doppel(m) and mostrando:
		print("TESTE doppel saiu do mapa")
		mostrando = false
		_ligar(false)
	queue_redraw()


# OpenningProcess
func abrir() -> void:
	passaram = 0
	maximo = 0
	monstro = 0.0
	monstro_vai = 0.0
	tempo = 600
	parado = false
	grupo.clear()
	gelo = false
	gelo_pos = 0.0
	gelo_vai = 0.0
	mostrando = true
	_ligar(true)
	queue_redraw()


func _ligar(sim: bool) -> void:
	ligado = sim
	if som:
		som.doppel = sim


# C1 BF 10
func estado(e: int) -> void:
	print("TESTE doppel estado %d" % e)
	if e == 2:
		abrir()


# C1 BF 0F: posicao do monstro da frente
func receber_monstro(pos: int) -> void:
	monstro_vai = pos / CAMINHO


# C1 BF 11: 0 o Ice Walker apareceu (salta pra posicao na primeira vez), 1 sumiu
func receber_gelo(e: int, pos: int) -> void:
	if e == 0:
		gelo_vai = (CAMINHO - pos) / CAMINHO
		if not gelo:
			gelo_pos = gelo_vai
		gelo = true
	elif e == 1:
		gelo = false
		gelo_vai = 0.0
	print("TESTE doppel ice walker %s" % ("aparece em %d" % pos if gelo else "some"))


# C1 BF 12: tempo e o grupo (quem nao veio fica sem marca)
func receber_info(segundos: int, lista: Array) -> void:
	tempo = segundos
	for k in grupo:
		grupo[k][1] = -1.0
	for g in lista:
		var p := (CAMINHO - int(g.pos)) / CAMINHO
		if grupo.has(int(g.id)):
			grupo[int(g.id)][1] = p
		else:
			grupo[int(g.id)] = [0.0, p]


# C1 BF 14
func receber_meta(m: int, n: int) -> void:
	maximo = m
	passaram = n
	print("TESTE doppel passaram %d/%d" % [n, m])


# C1 BF 13: som do fim, relogio parado, musica desligada
func fim(r: int) -> void:
	if som:
		som.tocar(SONS % "fim.wav")
	parado = true
	_ligar(false)
	if r == 0:
		tempo = 0


func relogio() -> String:
	var cc := 0 if parado else 99 - int(_quadro) % 100
	return "%02d:%02d:%02d" % [tempo / 60, tempo % 60, cc]


static func _chegar(v: float, alvo: float) -> float:
	if v + PASSO <= alvo:
		return v + PASSO
	if v - PASSO >= alvo:
		return v - PASSO
	return alvo


func _process(dt: float) -> void:
	if not mostrando:
		return
	# o cliente anda 0,01 por quadro a 25 quadros por segundo; o WorldTime corre em milissegundos
	var n := int(dt * 25.0 + 0.5) if dt > 0.0 else 1
	for i in maxi(n, 1):
		monstro = _chegar(monstro, monstro_vai)
		if gelo:
			gelo_pos = _chegar(gelo_pos, gelo_vai)
		for k in grupo:
			if grupo[k][1] >= 0.0:
				grupo[k][0] = _chegar(grupo[k][0], grupo[k][1])
	_quadro += dt * 1000.0
	queue_redraw()


func _draw() -> void:
	if not mostrando:
		return
	var v := get_viewport_rect().size
	var e := v.x / 640.0
	var f := get_theme_default_font()
	draw_set_transform(Vector2.ZERO, 0, Vector2(e, e))
	var p := Vector2(413, v.y / e - 480 + 342)
	draw_texture_rect_region(_tex.double_back, Rect2(p, Vector2(227, 87)), Rect2(0, 0, 227, 87))
	var cor := Color8(255, 150, 0) if passaram == 0 else (Color8(255, 70, 0) if passaram == 1 else Color8(255, 0, 0))
	_escrever(f, p + Vector2(117, 13), DicaItem.t(2772, [passaram, maximo]), 110, 10, cor)
	_escrever(f, p + Vector2(117, 38), DicaItem.t(865), 110, 10, Color8(255, 150, 0))
	_escrever(f, p + Vector2(117, 50), relogio(), 110, 16, Color8(255, 150, 0))
	# a barra: a de baixo inteira e a de cima da direita ate o monstro
	var baixo := ""
	var cima := "double_bary"
	if passaram == 1:
		baixo = "double_bary"
		cima = "double_baro"
	elif passaram >= 2:
		baixo = "double_baro"
		cima = "double_barr"
	if baixo != "":
		draw_texture_rect_region(_tex[baixo], Rect2(p + Vector2(59, 78), Vector2(167, 7)), Rect2(0, 0, 165, 6))
	if monstro > 0.0:
		draw_texture_rect_region(_tex[cima], Rect2(p + Vector2(59 + 167 * (1.0 - monstro), 78), Vector2(167 * monstro, 7)),
			Rect2(165 * (1.0 - monstro), 0, 165 * monstro, 6))
	if gelo:
		draw_texture_rect_region(_tex.double_micon01, Rect2(p + Vector2(59 - 6.5 + 167 * gelo_pos, 77), Vector2(13, 7)), Rect2(0, 0, 13, 7))
	for k in grupo:
		if grupo[k][1] < 0.0:
			continue
		var t: Texture2D = _tex.double_baricon04 if k == meu_id else _tex.double_baricon01
		draw_texture_rect_region(t, Rect2(p + Vector2(59 - 4.5 + 167 * grupo[k][0], 79), Vector2(9, 8)), Rect2(0, 0, 9, 8))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _escrever(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color) -> void:
	while tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura - 2:
		tam -= 1
	var q := p + Vector2(0, tam)
	draw_string_outline(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, cor)
