class_name GuerraCastelo
extends Control
# Batalha do Castle Siege no mapa 30 (rodada 22), em coordenadas de 640 de largura como o cliente:
# - minimapa da guerra (CNewUISiegeWarBase): moldura no canto de baixo a direita, o World31/map1 de 256 tiles
#   mostrado 128 por vez em volta do heroi (o + da moldura troca pra o mapa inteiro), ponto amarelo do heroi,
#   pontos dos outros, botao da transparencia (100, 90 ... 50 e volta) e o relogio (C1 B2 1E) so com a batalha
#   rodando (B2 17), com os dois pontos piscando a cada meio segundo.
# - quem: sem lado (B2 19 = 0) e observador; com lado e mestre da guilda (ou da alianca) e comandante, o resto
#   soldado (CreateMiniMapUI). O comandante ve a gente da guilda (C2 B6) e os portoes e estatuas (C2 BB) e tem os
#   7 botoes de grupo na coluna da moldura; grupo e comando (ataque, defesa, espera) e depois o clique no minimapa
#   manda o C1 B2 1D. Os comandos que chegam (B2 1D) piscam no minimapa por 100 quadros.
# - interruptores da coroa (B2 20, RenderSwichState): "Crown switch N / guilda / nome" embaixo, no centro, so
#   com o heroi perto da coroa (150 a 200 x 180 a 230).
# As cores dos pontos sairam do porte do cliente (os ramos estao vazios): aqui o meu lado e azul, o outro vermelho
# e NPC verde.

signal comando(time: int, x: int, y: int, cmd: int)

const MAPA := 30
const PASTA := "res://dados/hud/castelo/"
const MOLDURA := Vector2(154, 162)
const TEMPO := Vector2(134, 37)
const GRUPO := Vector2(26, 22)
const BOTAO_CMD := Vector2(30, 22)
const ALFA := Vector2(38, 23)
const CMD_TAM := [Vector2(13, 13), Vector2(18, 15), Vector2(11, 12)]
const QUADRO := 1.0 / 25.0
const OBSERVADOR := 0
const SOLDADO := 1
const COMANDANTE := 2

var lado := 0                   # B2 19: 0 nenhum, 1 defesa, 2 a 4 ataque
var iniciada := false           # B2 17
var hora := 0
var minuto := 0
var sou_mestre := false         # mestre da guilda e (sem alianca ou mestre da alianca)
var heroi := Vector2i(0, 0)     # tile do heroi
var pontos: Array = []          # [x, y, tipo] tipo 0 meu lado, 1 outro, 2 NPC
var membros: Array = []         # C2 B6 e BB: [tipo, x, y] (0 gente, 1 portao, 2 estatua)
var comandos := {}              # time -> {x, y, cmd, vida}
var interruptores := [{}, {}]   # B2 20 dos dois interruptores da coroa
var alfa := 1.0
var escala := 1
var grupo := -1
var cmd := -1
var _tex := {}
var _esc := 1.0
var _alto := 360.0
var _mouse := Vector2(-100, -100)
var _pisca := 0.0
var _dois_pontos := true
var _quadro := 0.0


func _ready() -> void:
	for n in ["mm_moldura", "mm_tempo", "mm_mapa", "mm_grupo", "mm_comando", "mm_alfa", "cmd_ataque", "cmd_defesa", "cmd_espera"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	_alto = v.y / _esc
	scale = Vector2(_esc, _esc)
	size = Vector2(640, _alto)
	queue_redraw()


func tipo() -> int:
	if lado == 0:
		return OBSERVADOR
	return COMANDANTE if sou_mestre else SOLDADO


# canto de cima da moldura: a direita, em cima do relogio, que encosta na barra do jogo (51 de 480)
func moldura() -> Vector2:
	return Vector2(640 - MOLDURA.x, _alto - 51 - (MOLDURA.y - 4 + TEMPO.y))


func _mapa_pos() -> Vector2:
	return moldura() + Vector2(25, 28)


# UpdateHeroPos: o pedaco do mapa que aparece segue o heroi; y do mapa conta de baixo pra cima
func _deslocamento() -> Vector2:
	var hx := heroi.x / escala
	var hy := (256 - heroi.y) / escala
	return Vector2(maxi(hx - 64 * escala, 0), mini(maxi(hy - 64 * escala, 0), 128))


func no_minimapa(x: int, y: int) -> Vector2:
	return Vector2(x / escala, (256 - y) / escala) - _deslocamento() + _mapa_pos()


func _dentro(p: Vector2) -> bool:
	var m := _mapa_pos()
	return p.x >= m.x and p.x <= m.x + 128 and p.y >= m.y and p.y <= m.y + 128


func _process(dt: float) -> void:
	if not visible:
		return
	_pisca += dt
	if _pisca >= 0.5:
		_pisca = 0.0
		_dois_pontos = not _dois_pontos
	_quadro += dt
	while _quadro >= QUADRO:
		_quadro -= QUADRO
		for t in comandos.keys():
			if comandos[t].vida > 0:
				comandos[t].vida -= 1
	queue_redraw()


# --- dados do servidor -------------------------------------------------------------

func receber_comando(d: Dictionary) -> void:
	if int(d.time) > 6 or int(d.cmd) > 2:
		comandos.erase(int(d.time))
		return
	comandos[int(d.time)] = {"x": int(d.x), "y": int(d.y), "cmd": int(d.cmd), "vida": 100}
	print("TESTE guerra comando time %d em %d,%d (%d)" % [d.time, d.x, d.y, d.cmd])


func receber_interruptor(d: Dictionary, primeiro: bool) -> void:
	interruptores[0 if primeiro else 1] = d if d.ocupado else {}
	print("TESTE guerra interruptor %d %s" % [1 if primeiro else 2, ("%s / %s" % [d.guilda, d.nome]) if d.ocupado else "livre"])


func texto_interruptores() -> Array:
	var l := []
	if not (heroi.x >= 150 and heroi.x <= 200 and heroi.y >= 180 and heroi.y <= 230):
		return l
	for i in 2:
		if not interruptores[i].is_empty():
			l.append("%s %d / %s / %s" % [DicaItem.t(1981), i + 1, interruptores[i].guilda, interruptores[i].nome])
	return l


# --- desenho -----------------------------------------------------------------------

func _draw() -> void:
	var cor := Color(1, 1, 1, alfa)
	var mm := _mapa_pos()
	var off := _deslocamento()
	# o mapa: 128 px na tela pegam 128 * escala px da textura de 256
	draw_texture_rect_region(_tex.mm_mapa, Rect2(mm, Vector2(128, 128)), Rect2(off * escala, Vector2(128, 128) * escala), cor)
	var m := moldura()
	draw_texture(_tex.mm_moldura, m, cor)
	var tp := m + Vector2(20, MOLDURA.y - 4)
	draw_texture(_tex.mm_tempo, tp, cor)
	var f := get_theme_default_font()
	if iniciada:
		var sep := ":" if _dois_pontos else " "
		var t := "%d%s%02d" % [hora, sep, minuto]
		draw_string_outline(f, tp + Vector2(0, 24), t, HORIZONTAL_ALIGNMENT_CENTER, TEMPO.x, 14, 2, Color(0, 0, 0, alfa))
		draw_string(f, tp + Vector2(0, 24), t, HORIZONTAL_ALIGNMENT_CENTER, TEMPO.x, 14, Color(1, 1, 1, alfa))
	# os outros (RenderCharPosInMiniMap)
	for p in pontos:
		var q := no_minimapa(p[0], p[1])
		if _dentro(q):
			var c: Color = [Color(0.3, 0.6, 1), Color(1, 0.25, 0.2), Color(0.3, 1, 0.3)][p[2]]
			c.a = alfa
			draw_rect(Rect2(q, Vector2(3, 3)), c)
	if tipo() == COMANDANTE:
		for p in membros:
			var q := no_minimapa(p[1], p[2])
			if _dentro(q):
				var c: Color = [Color(0.4, 1, 1), Color(1, 0.8, 0.3), Color(1, 0.5, 1)][clampi(p[0], 0, 2)]
				c.a = alfa
				draw_rect(Rect2(q, Vector2(3, 3)), c)
	_desenhar_comandos()
	var h := no_minimapa(heroi.x, heroi.y)
	draw_rect(Rect2(h, Vector2(3, 3)), Color(1, 1, 0, alfa))
	if tipo() == COMANDANTE:
		_desenhar_grupos()
		if grupo >= 0 and cmd >= 0 and _dentro(_mouse):
			draw_string(f, _mouse + Vector2(-13, 4), str(grupo + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
			draw_texture_rect(_tex[["cmd_ataque", "cmd_defesa", "cmd_espera"][cmd]], Rect2(_mouse - Vector2(8, 8), CMD_TAM[cmd]), false)
	# botao da transparencia
	var ra := Rect2(m + Vector2(58, 4), ALFA)
	draw_texture_rect_region(_tex.mm_alfa, ra, Rect2(0, 23 if ra.has_point(_mouse) else 0, 38, 23), cor)
	draw_string(f, ra.position + Vector2(0, 16), str(int(alfa * 100.5)), HORIZONTAL_ALIGNMENT_CENTER, ALFA.x, 10, Color(1, 1, 1, alfa))
	# interruptores da coroa
	var linhas := texto_interruptores()
	for i in linhas.size():
		var y := _alto - 85 + i * 15
		draw_string_outline(f, Vector2(0, y), linhas[i], HORIZONTAL_ALIGNMENT_CENTER, 640, 10, 2, Color.BLACK)
		draw_string(f, Vector2(0, y), linhas[i], HORIZONTAL_ALIGNMENT_CENTER, 640, 10, Color.WHITE)


func _desenhar_comandos() -> void:
	for t in comandos:
		var c: Dictionary = comandos[t]
		var q := no_minimapa(c.x, c.y)
		if not _dentro(q):
			continue
		var tam: Vector2 = CMD_TAM[c.cmd]
		# pulsa enquanto tem vida (RenderCmdIconInMiniMap)
		var pulso := 1.0 + (sin(c.vida * 0.2) if c.vida > 0 else 0.0) * 0.25
		var r := Rect2(q - tam * pulso / 2.0, tam * pulso)
		draw_texture_rect(_tex[["cmd_ataque", "cmd_defesa", "cmd_espera"][c.cmd]], r, false, Color(1, 1, 1, alfa))
		draw_string(get_theme_default_font(), q + Vector2(-13, 4), str(int(t) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, alfa))


func _grupo_r(i: int) -> Rect2:
	return Rect2(moldura() + Vector2(0, 5 + i * GRUPO.y), GRUPO)


# os 3 comandos saem ao lado do grupo (do 6 e 7 pra cima, pra caber)
func _cmd_r(j: int) -> Rect2:
	var base := mini(grupo, 4)
	return Rect2(moldura() + Vector2(GRUPO.x, 5 + (base + j) * GRUPO.y), BOTAO_CMD)


func _desenhar_grupos() -> void:
	var f := get_theme_default_font()
	for i in 7:
		var r := _grupo_r(i)
		var e := 2 if i == grupo else (1 if r.has_point(_mouse) else 0)
		draw_texture_rect_region(_tex.mm_grupo, r, Rect2(0, e * 22, 26, 22), Color(1, 1, 1, alfa))
		draw_string(f, r.position + Vector2(0, 15), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, GRUPO.x, 10, Color(1, 1, 1, alfa))
	if grupo >= 0 and cmd < 0:
		for j in 3:
			var r := _cmd_r(j)
			draw_texture_rect_region(_tex.mm_comando, r, Rect2(0, (1 if r.has_point(_mouse) else 0) * 22, 30, 22), Color(1, 1, 1, alfa))
			var tam: Vector2 = CMD_TAM[j]
			var dx := 10.0 if j == 2 else 8.0
			var dy := 3.0 if j == 1 else 5.0
			draw_texture_rect(_tex[["cmd_ataque", "cmd_defesa", "cmd_espera"][j]], Rect2(r.position + Vector2(dx, dy), tam), false)


# --- mouse ---------------------------------------------------------------------------

# o jogo chama com o ponto em coordenadas de 640; true quando o clique foi do minimapa
func clicar(p: Vector2) -> bool:
	if not visible:
		return false
	var m := moldura()
	if Rect2(m + Vector2(58, 4), ALFA).has_point(p):
		alfa = 1.0 if alfa <= 0.55 else snappedf(alfa - 0.1, 0.1)
		print("TESTE guerra transparencia %d" % int(alfa * 100.5))
		return true
	if Rect2(m + Vector2(134, 7), Vector2(13, 12)).has_point(p):
		escala = 2 if escala == 1 else 1
		print("TESTE guerra escala %d" % escala)
		return true
	if tipo() == COMANDANTE:
		for i in 7:
			if _grupo_r(i).has_point(p):
				grupo = -1 if grupo == i else i
				cmd = -1
				print("TESTE guerra grupo %d" % grupo)
				return true
		if grupo >= 0 and cmd < 0:
			for j in 3:
				if _cmd_r(j).has_point(p):
					cmd = j
					print("TESTE guerra comando escolhido %d" % j)
					return true
		if _dentro(p) and grupo >= 0 and cmd >= 0:
			var off := _deslocamento()
			var mm := _mapa_pos()
			var x := int((p.x + off.x - mm.x) * escala)
			var y := 256 - int((p.y + off.y - mm.y) * escala)
			print("TESTE guerra manda comando time %d em %d,%d (%d)" % [grupo, x, y, cmd])
			comando.emit(grupo, x, y, cmd)
			cmd = -1
			return true
	return Rect2(m, MOLDURA).has_point(p) or Rect2(m + Vector2(20, MOLDURA.y - 4), TEMPO).has_point(p)


func mover_mouse(p: Vector2) -> void:
	_mouse = p


# a tela inteira e o Control, mas so a moldura, o relogio e os botoes do comandante pegam o mouse
func _has_point(p: Vector2) -> bool:
	if not visible:
		return false
	var m := moldura()
	if Rect2(m, MOLDURA).has_point(p) or Rect2(m + Vector2(20, MOLDURA.y - 4), TEMPO).has_point(p):
		return true
	return tipo() == COMANDANTE and Rect2(m, Vector2(GRUPO.x + BOTAO_CMD.x, 7 * GRUPO.y + 5)).has_point(p)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mover_mouse(ev.position)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if clicar(ev.position):
			accept_event()
