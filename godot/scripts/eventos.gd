class_name Eventos
extends Control
# O que os eventos desenham por cima do jogo (CSBaseMatch e CNewUIBloodCastle do S6):
# a contagem de 30 s no meio de baixo (C1 92, azul claro em fundo preto meio transparente) e a janela
# do tempo do Blood Castle (124x81 no canto de baixo a direita: monstros mortos, "Time Left" e o
# relogio, vermelho nos ultimos 5 minutos). O C1 9B diz o estado do castelo: 0 comecou (som e a
# corrida de todos), 1 e 4 seguem contando (4 = portao caiu), 2 acabou. No Chaos Castle (CNewChaosCastleSystem,
# CNewUIChaosCastleTime, mesma janela e mesmo lugar) 5 comecou, 6 segue contando (quantos ainda vivos de 100),
# 7 acabou, e 8, 9 e 10 encolhem o castelo (estagio 1, 2 e 3).

const CONTAGEM := 30.0

var tipo := 0                # MATCH_TYPE do cliente (valor do C1 92 + 1); 0 nenhuma
var _desde := 0.0
var em_castelo := false      # o jogo liga quando o mapa e um Blood Castle
var caos := false            # e quando e um Chaos Castle
signal estagio(n: int)       # C1 9B 8, 9 e 10: o castelo encolhe
var bc_tipo := 0             # estado do C1 9B + 1; a janela aparece em 1, 2 e 5
var bc_segundos := 0.0
var bc_maximo := 65535
var bc_mortos := 0
var som: Som                 # o jogo passa
var _tex: Texture2D
var _fonte_grande: Font


func _ready() -> void:
	_tex = load(Inventario.PASTA + "bc_tempo.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func contagem(valor: int) -> void:
	tipo = valor + 1
	_desde = Time.get_ticks_msec() / 1000.0
	queue_redraw()


# texto da contagem, ou "" se nao tem (o jogo usa no teste)
func texto_contagem() -> String:
	var falta := int(CONTAGEM - (Time.get_ticks_msec() / 1000.0 - _desde))
	if tipo <= 0 or falta <= 0:
		return ""
	if tipo >= 4 and tipo <= 7:
		return DicaItem.t(824 + tipo - 4, [DicaItem.t(1146), falta])
	if tipo >= 11 and tipo <= 14:
		# Chaos Castle: o segundo texto e o 828 (Penetration) no lugar do 825
		var n := 824 + tipo - 11
		return DicaItem.t(828 if n == 825 else n, [DicaItem.t(1147), falta])
	if tipo >= 1 and tipo <= 3:
		return DicaItem.t(640 + tipo - 1, [falta])
	return ""


func estado_castelo(estado: int, segundos: int, maximo: int, mortos: int) -> void:
	match estado:
		0:
			if som:
				som.laco("ibloodcastle")
			bc_tipo = 1
		2:
			bc_tipo = 0
			bc_segundos = 0
			if som:
				som.parar_laco()
			queue_redraw()
			return
		1, 4:
			bc_tipo = estado + 1
		5:
			# todos correm (SetAllAction PLAYER_RUSH1): o som do castelo no lugar do vento
			if som:
				som.laco("ichaoscastle")
			bc_tipo = 6
		6:
			bc_tipo = 7
		7:
			bc_tipo = 0
			bc_segundos = 0
			if som:
				som.parar_laco()
				if caos:
					som.laco("achaos")
					som.tocar("achaosend")
			queue_redraw()
			return
		8, 9, 10:
			estagio.emit(estado - 7)
			return
		_:
			return
	bc_segundos = segundos
	bc_maximo = maximo
	bc_mortos = mortos
	queue_redraw()


func mostra_tempo() -> bool:
	return ((em_castelo and bc_tipo in [1, 2, 5]) or (caos and bc_tipo == 7)) and bc_segundos > 0


func relogio() -> String:
	var s := int(bc_segundos)
	return " %02d:%02d:%02d" % [s / 60, s % 60, int(Time.get_ticks_msec() / 1000.0) % 60]


func _process(dt: float) -> void:
	if bc_segundos > 0:
		bc_segundos = maxf(bc_segundos - dt, 0)
	if tipo > 0 or mostra_tempo():
		queue_redraw()
	if tipo > 0 and texto_contagem() == "":
		tipo = 0


func _draw() -> void:
	var v := get_viewport_rect().size
	var esc := v.x / 640.0
	var f := get_theme_default_font()
	draw_set_transform(Vector2.ZERO, 0, Vector2(esc, esc))
	var t := texto_contagem()
	if t != "":
		var largura := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var alto := v.y / esc
		draw_rect(Rect2(320 - largura / 2 - 3, alto - 70 - 1, largura + 6, 15), Color(0, 0, 0, 0.5))
		draw_string(f, Vector2(320 - largura / 2, alto - 70 + 11), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color8(128, 128, 255))
	if mostra_tempo():
		# CNewUIBloodCastle: a 127 da direita e 132 de baixo na tela de 640x480
		var p := Vector2(640 - 127, v.y / esc - 132)
		draw_texture_rect(_tex, Rect2(p, Vector2(124, 81)), false)
		var laranja := Color8(255, 150, 0)
		if bc_maximo != 65535:
			# Chaos Castle: "Character: ( vivos/100 )"
			var m := DicaItem.t(1161 if caos else (866 if bc_tipo == 5 else 864), [bc_mortos, bc_maximo])
			_escrever(f, p + Vector2(0, 13), m, 124, 10, laranja)
		_escrever(f, p + Vector2(0, 38), DicaItem.t(865), 124, 10, laranja)
		var cor := Color8(255, 32, 32) if bc_segundos < 300 else laranja
		_escrever(f, p + Vector2(0, 50), relogio(), 124, 16, cor)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _escrever(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color) -> void:
	var q := p + Vector2(0, tam)
	draw_string_outline(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, q, t, HORIZONTAL_ALIGNMENT_CENTER, largura, tam, cor)
