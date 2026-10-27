class_name Crywolf
extends Control
# Evento de Crywolf (mapa 34, pasta mundo35; M34CryWolf1st e CNewUICryWolf do S6). O servidor manda C1 BD:
#   00 ocupacao (0 paz, 1 ocupado, 2 guerra) e estado (1 e 2 avisos, 3 pronto, 4 luta, 5 fim, 6 fim do ciclo)
#   02 vida da estatua (%) e os 5 altares (nibble de cima: 1 contratado; de baixo: contratos que restam)
#   03 resposta do contrato no altar   04 tempo (hora, minuto)   05 vida do Balgass (%) e Dark Elves vivos
#   07 meu rank (0 D a 4 S) e exp   08 os 5 herois   09 bonus de chaos   0C tiro da balista
# A ocupacao troca a luz do chao (TerrainLight, 1, 2) e a grade (EncTerrain35, 351, 352). No pronto e na
# luta aparece o painel do canto (in_main: altares, estatua, Dark Elves, Balgass e relogio); no pronto, os
# avisos das missoes (1957 a 1972, 4 linhas que trocam a cada 10 s). No fim (sem guerra) a faixa de vitoria
# ou derrota entra pela esquerda, fica, sai pela direita e abre a caixa com os herois; junto, a tabela do
# rank e a exp. Tudo contado em quadros de 25 por segundo, como o cliente.

signal resultado_pronto(linhas: Array)   # a caixa CCry_Wolf_Result_Set_Temple

const MAPA := 34
const PASTA := "res://dados/hud/crywolf/"
const MUNDO := "res://dados/mundo35/"
const NOTIFY2 := 2
const PRONTO := 3
const LUTA := 4
const FIM := 5
const FIM_CICLO := 6
const PAZ := 0
const OCUPADO := 1
const GUERRA := 2
const QUADRO := 1.0 / 25.0
const ALTARES := [Vector2(565, 280), Vector2(582, 282), Vector2(598, 286), Vector2(613, 294), Vector2(625, 306)]

var ocupacao := -1
var estado := 0
var estatua := 0
var altares := [0, 0, 0, 0, 0]
var balgass := 100
var ver_balgass := false
var elfos := 0
var rank := 0
var exp_ganha := 0
var herois := {}          # posicao 0 a 4 -> [nome, classe, pontos]
var bonus_caos := 0
var mapa_atual := -1
var mundo: Node3D
var som: Som
var heroi: Node3D
# faixa do fim (Suc_Or_Fail, View_Suc_Or_Fail, Add_Num, Delay, Delay_Add_inter)
var faixa := -1           # 1 entrando e parada, 0 saindo, -1 nada
var venceu := false
var _atraso := 0
var _rank_x := 390
var _deco := 0.0
# relogio (CNewUICryWolf::SetTime)
var minuto := 0
var _ms := 0
var _cnt := 0
var contando := false
var _aviso := -1
var _aviso_t := 10.0
var _acum := 0.0
var _tex := {}
var _numeros: Texture2D
var _esc := 1.0


func _ready() -> void:
	for n in ["in_main", "in_main2", "icon_bal", "icon_dl1", "icon_dl2", "num0", "num1", "num2", "num1_1", "num2_1",
			"bar2", "t_main", "sucesso", "falha", "rank_tabela", "rank_exp", "rank_rank",
			"r0", "r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8", "r9", "rd", "rc", "rb", "ra", "rs"]:
		_tex[n] = load(PASTA + n + ".png")
	_numeros = load(Inventario.PASTA + "numeros.png")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	size = Vector2(640, 480)
	queue_redraw()


func no_crywolf() -> bool:
	return mapa_atual == MAPA


func mapa(m: int, mundo_: Node3D = null) -> void:
	if m != mapa_atual and m != MAPA:
		_iniciar()
	mapa_atual = m
	mundo = mundo_
	# mapa recarregado: a luz e a grade voltam as do arquivo; o BD 00 que o jogo pede reaplica a ocupacao
	if mundo_ != null:
		ocupacao = -1
	queue_redraw()


# CryWolfMVPInit
func _iniciar() -> void:
	ocupacao = -1
	estado = 0
	estatua = 0
	elfos = 0
	balgass = 100
	ver_balgass = false
	_aviso = -1
	_deco = 0.0
	contando = false


# so o pronto e a luta mostram o painel (Get_State_Only_Elf)
func painel() -> bool:
	return no_crywolf() and estado in [PRONTO, LUTA]


# C1 BD 00: CheckCryWolf1stMVP
func info(ocup: int, est: int) -> void:
	if ocup == ocupacao and est == estado:
		return
	print("TESTE crywolf estado %d ocupacao %d" % [est, ocup])
	estado = est
	if estado == LUTA:
		_cnt = 0
	if estado != LUTA:
		ver_balgass = false
	if estado == FIM:
		herois.clear()
		if ocup != GUERRA:
			faixa = 1
			_atraso = 0
			venceu = ocup == PAZ
			_rank_x = 390
			if som:
				som.tocar(MUNDO + "sons/" + ("venceu.wav" if venceu else "perdeu.wav"))
			print("TESTE crywolf faixa %s" % ("vitoria" if venceu else "derrota"))
	if som:
		som.crywolf = estado
	if ocup != ocupacao:
		ocupacao = ocup
		_trocar_terreno()
	queue_redraw()


# a luz do chao e a grade de caminho pela ocupacao (OpenTerrainLight e OpenTerrainAttribute)
func _trocar_terreno() -> void:
	if not mundo or not is_instance_valid(mundo) or mundo.numero != 35:
		return
	var luz: String = ["luz.png", "luz1.png", "luz2.png"][clampi(ocupacao, 0, 2)]
	mundo.trocar_luz(luz)
	var img: Image
	var canal_a := ocupacao == PAZ
	img = (load(MUNDO + ("mapa.png" if canal_a else "atributos_%d.png" % ocupacao)) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	for y in 256:
		for x in 256:
			var c := img.get_pixel(x, y)
			mundo.atributos[y * 256 + x] = int(round((c.a if canal_a else c.r) * 255.0))
			mundo.grade.set_point_solid(Vector2i(x, y), not mundo.anda(x, y))
	print("TESTE crywolf terreno %s" % luz)


# C1 BD 02
func estatua_altares(vida: int, a: Array) -> void:
	if vida != estatua or a != altares:
		print("TESTE crywolf estatua %d%% altares %s" % [vida, a])
	estatua = vida
	altares = a.duplicate()
	queue_redraw()


# C1 BD 03 com o contrato aceito: Check_AltarState(chave - 316)
func altar_contratado(chave: int, est: int) -> void:
	var n := chave - 316
	if painel() and n >= 1 and n <= 5:
		altares[n - 1] = est
	queue_redraw()


# C1 BD 04: o tempo da luta. Minuto novo comeca 60 s; o 2o pacote no mesmo minuto vira 40 s, o 3o 20 s
func tempo(_hora: int, m: int) -> void:
	if m != minuto:
		_ms = 60000
		_cnt = 1
		contando = true
	elif _cnt == 1:
		_ms = 40000
		_cnt = 2
	elif _cnt == 2:
		_ms = 20000
		_cnt = 0
	minuto = m
	print("TESTE crywolf tempo minuto %d, o relogio conta %d s" % [minuto, _ms / 1000])


# C1 BD 05: Set_BossMonster
func chefe(vida: int, dark_elves: int) -> void:
	print("TESTE crywolf balgass %d%% elfos %d" % [vida, dark_elves])
	if not painel():
		return
	elfos = dark_elves
	if vida > 0 and not ver_balgass:
		ver_balgass = true
	elif vida <= 0 and ver_balgass:
		ver_balgass = false
	balgass = vida
	queue_redraw()


# C1 BD 07
func meu_rank(r: int, e: int) -> void:
	rank = clampi(r, 0, 4)
	exp_ganha = e
	print("TESTE crywolf rank %d exp %d" % [rank, e])


# C1 BD 08 (uma linha por heroi; a posicao vem de 0 a 4)
func heroi_lista(pos: int, nome: String, classe: int, pontos: int) -> void:
	print("TESTE crywolf heroi %d %s classe %d pontos %d" % [pos, nome, classe, pontos])
	if pos >= 0 and pos < 5:
		herois[pos] = [nome, classe, pontos]


# a caixa do fim com os herois e o premio ou o castigo
func linhas_resultado(nomes_classe: Callable) -> Array:
	var laranja := Color8(255, 148, 21)
	var rosa := Color8(255, 0, 255)
	var l: Array = [["%s    %s    %s    %s" % [DicaItem.t(680), DicaItem.t(681), DicaItem.t(1973), DicaItem.t(1977)], laranja]]
	for i in 5:
		if herois.has(i):
			var h: Array = herois[i]
			l.append("%d      %s      %s      %d" % [i + 1, h[0], nomes_classe.call(h[1]), h[2]])
	for i in 4:
		l.append(["    ", rosa])
	if venceu:
		l.append([DicaItem.t(2000), rosa])
		l.append([DicaItem.t(2001), rosa])
	else:
		l.append([DicaItem.t(2009), rosa])
	return l


# o clique no altar (ZzzInterface): so a elfa no pronto e na luta ganha as caixas do contrato
# devolve "falar" (manda a conversa normal), "pode" (caixa 2006/2007), "destruido" (2003) ou "contratado" (2002)
func clique_altar(numero: int, elfa: bool) -> String:
	if not painel() or numero < 205 or numero > 209:
		return "falar"
	var a: int = altares[numero - 205]
	var ativo := (a >> 4) == 1
	if elfa and not ativo:
		return "pode" if (a & 0x0F) > 0 else "destruido"
	if elfa and ativo:
		return "contratado"
	return "falar"


func contratos_restantes(numero: int) -> int:
	return altares[numero - 205] & 0x0F if numero >= 205 and numero <= 209 else 0


# C1 BD 0C: DoTankerFireFixStartPosition. A pedra sai 8 tiles ao lado (pela torre que atira) e 8 de altura
func balista(sx: int, _sy: int, px: int, py: int) -> void:
	if not mundo or not is_instance_valid(mundo):
		return
	var alvo: Vector3 = mundo.no_tile(px, py) + Vector3(0, 1.0, 0)
	var de := alvo + Vector3(-8, 7, 0)
	if sx == 183:
		de = alvo + Vector3(8, 7, 0)
	elif sx == 122 or sx == 116:
		de = alvo + Vector3(0, 7, -8)   # y do MU e -z aqui
	print("TESTE crywolf balista de %d para %d,%d" % [sx, px, py])
	var e := EfeitoMU.criar(mundo)
	var n := e.voar(de, alvo, 0.8, func(p: Vector3):
		for i in 6:
			e.sprite("fire01", p + Vector3(randf_range(-0.5, 0.5), randf_range(0, 0.5), randf_range(-0.5, 0.5)), 1.6,
				Color(1, 0.6, 0.2), 0.6, {"giro": randf_range(0, TAU), "vel": Vector3(0, 0.8, 0), "tam1": 0.4})
		e.sprite("smoke01", p, 2.5, Color(0.6, 0.5, 0.4), 1.2, {"vel": Vector3(0, 0.6, 0), "tam1": 3.5})
		e.chao("flare01", p - Vector3(0, 0.9, 0), 2.0, Color(1, 0.5, 0.2), 0.8, {})
		if mundo.camera:
			var cam: Camera3D = mundo.camera
			var tw := cam.create_tween()
			for k in 4:
				tw.tween_property(cam, "v_offset", randf_range(-0.08, 0.08), 0.04)
			tw.tween_property(cam, "v_offset", 0.0, 0.04))
	e.tarefa(0.04, 0.8, func(_e, _i):
		if EfeitoMU.voando(n):
			e.sprite("fire01", n.global_position, 1.0, Color(1, 0.6, 0.2), 0.3, {"giro": randf_range(0, TAU), "tam1": 0.2}))


func _process(dt: float) -> void:
	if not no_crywolf():
		return
	_acum += dt
	var passos := 0
	while _acum >= QUADRO:
		_acum -= QUADRO
		passos += 1
	for i in passos:
		_quadro()
	if contando and estado == LUTA:
		_ms -= int(dt * 1000.0)
		if minuto <= 0 and _ms <= 0:
			contando = false
			_ms = 0
			_cnt = 0
	if estado == PRONTO:
		_aviso_t += dt
		if _aviso_t >= 10.0:
			_aviso_t = 0.0
			_aviso = (_aviso + 1) % 4
	queue_redraw()


# o que o Render faz por quadro
func _quadro() -> void:
	if faixa == 1:
		_atraso += 1
		if _atraso >= 400:
			_atraso = 0
			faixa = 0
	elif faixa == 0:
		_atraso += 1
		if _atraso * 15 > 479:
			_atraso = 0
			faixa = -1
			_rank_x = 390
			resultado_pronto.emit([])
			print("TESTE crywolf caixa do resultado")
	if faixa >= 0:
		_rank_x = maxi(_rank_x - 15, 0)
	if ver_balgass:
		_deco = minf(_deco + 1.0, 21.0)
	else:
		_deco = maxf(_deco - 1.0, 0.0)


func _img(n: String, x: float, y: float, w: float, h: float, cor := Color.WHITE) -> void:
	var t: Texture2D = _tex.get(n)
	if t:
		draw_texture_rect(t, Rect2(x, y, w, h), false, cor)


func _draw() -> void:
	if not no_crywolf():
		return
	var f := get_theme_default_font()
	if faixa >= 0:
		_desenhar_fim()
	if not painel():
		return
	_img("in_main", 518, 278, 122, 119)
	for i in 5:
		var a: int = altares[i]
		var uso := (a & 0xF0) >> 4
		var st := a & 0x0F
		var p: Vector2 = ALTARES[i]
		var n := ""
		if uso == 1:
			n = "num1_1" if st == 1 else ("num2_1" if st == 2 else "num0")
		elif st == 1:
			n = "num1"
		elif st == 2:
			n = "num2"
		if n != "":
			_img(n, p.x, p.y, 13, 13)
	_img("icon_dl2" if elfos == 0 else "icon_dl1", 623, 358, 15, 15)
	_img("t_main", 538, 392, 104, 37)
	_texto(f, Vector2(582, 359), DicaItem.t(1948, [elfos]), Color8(255, 148, 21))
	if ver_balgass and _deco >= 21.0:
		_img("icon_bal", 623, 379, 15, 15)
		_texto(f, Vector2(600, 380), DicaItem.t(1949), Color8(255, 148, 21))
		var w := 0.68 * balgass
		var t: Texture2D = _tex.bar2
		draw_texture_rect_region(t, Rect2(548, 388, w, 8), Rect2(0, 0, 0.67 * balgass, 8))
	# relogio: minuto e segundos (vermelho com o Balgass na rua)
	var cor := Color8(255, 77, 77) if ver_balgass else Color.WHITE
	if contando and estado == LUTA:
		var s := maxi(_ms / 1000, 0)
		if minuto < 10:
			_numero(570, 402, 0, cor)
		_numero(580, 402, minuto, cor)
		if s < 10:
			_numero(597, 402, 0, cor)
		_numero(607, 402, s, cor)
	else:
		for x in [570, 580, 597, 607]:
			_numero(x, 402, 0, Color.WHITE)
	# a estatua: in_main2 cortado da esquerda pela vida que falta
	var falta := 100 - clampi(estatua, 0, 100)
	var nx := 0.89 * falta
	draw_texture_rect_region(_tex.in_main2, Rect2(548 + nx, 323, 89.0 - nx, 30), Rect2(0.88 * falta, 0, 0.88 * (100 - falta), 29))
	if estado == PRONTO and _aviso >= 0:
		_avisos(f)


# RenderNoticesCryWolf: 4 linhas em negrito com fundo preto, a 1a mais clara
func _avisos(f: Font) -> void:
	for i in 4:
		var t := DicaItem.t(1957 + i + 4 * _aviso)
		var cor := Color8(100, 200, 255) if i == 0 else Color8(100, 150, 255)
		var p := Vector2(190, 63 + i * 13)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_rect(Rect2(p.x, p.y, w + 2, 13), Color(0, 0, 0, 170 / 255.0))
		draw_string_outline(f, p + Vector2(1, 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 1, cor.darkened(0.4))
		draw_string(f, p + Vector2(1, 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, cor)


func _desenhar_fim() -> void:
	var aa := (_atraso * 2) % 140
	var alfa := 1.0 - (aa - 70) * 0.01 if aa > 70 else 0.3 + aa * 0.01
	var t := "sucesso" if venceu else "falha"
	var x := -329.0 + _atraso * 15
	if _atraso * 15 > 479:
		x = 150
	elif faixa == 0:
		x = 150 + _atraso * 15
	_img(t, x, 50, 329, 94, Color(1, 1, 1, alfa))
	_img("rank_tabela", 230, 150, 196, 141)
	_img("rank_rank", 250 + _rank_x, 188, 110, 28)
	if _rank_x == 0:
		_img(["rd", "rc", "rb", "ra", "rs"][rank], 370, 188, 29, 28)
		_img("rank_exp", 229, 235, 60, 19)
		# 9 casas, da direita: so as que o numero tem (as da esquerda ficam no 0)
		var s := str(maxi(exp_ganha, 0))
		var dig := []
		for i in 9:
			dig.append(0)
		for i in mini(s.length(), 9):
			dig[8 - i] = int(s[s.length() - 1 - i])
		for i in 9:
			_img("r%d" % dig[i], 289 + 15 * i, 235, 15, 19)


# RenderNumber2D: digitos de 14x14 centrados em x, passo 0,7
func _numero(x: float, y: float, n: int, cor: Color) -> void:
	var s := str(maxi(n, 0))
	x -= 14.0 * s.length() / 2.0
	for c in s:
		draw_texture_rect_region(_numeros, Rect2(x, y, 14, 14), Rect2((c.unicode_at(0) - 48) * 12, 0, 12, 14), cor)
		x += 14.0 * 0.7


func _texto(f: Font, p: Vector2, t: String, cor: Color) -> void:
	var q := p + Vector2(0, 10)
	var w := 200.0
	draw_string_outline(f, q - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_CENTER, w, 10, 2, Color(0, 0, 0, 0.9))
	draw_string(f, q - Vector2(w / 2, 0), t, HORIZONTAL_ALIGNMENT_CENTER, w, 10, cor)
