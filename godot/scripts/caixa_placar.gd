class_name CaixaPlacar
extends CaixaMU
# Placar do fim dos eventos, na moldura da caixa de mensagem com so o OK:
# Devil Square (CDevilSquareRankMsgBox): a 60 do alto, 11 meios, a linha, mais 3 meios; parabens, as colunas
# Rank, point, EXP e Reward em verde, cada um numa linha de 16 (o meu em laranja) e "My Info" no pe.
# Blood Castle (CBloodCastleResultMsgBox): a 100 do alto, 6 meios; a frase verde de deu certo ou nao,
# exp, zen (so se deu certo) e os pontos.
# Chaos Castle (CChaosCastleResultMsgBox): igual ao Blood Castle no tamanho; a frase, exp, monstros e
# jogadores mortos. O OpenMU nao manda as duas contagens (so os pontos: 2 por monstro, 1 por jogador):
# o jogo conta as mortes que viu com o meu nome de matador (C1 17).

var modo := "ds"
var heroi := ""
var minha_pos := 0
var lista: Array = []          # ds: [{nome, pontos, exp, zen}]
var bc := {}                   # bc: {ok, pontos, exp, zen}; cc: {ok, exp, monstros, jogadores}
var _frase: Array[String] = []


func _init(qual := "ds") -> void:
	super._init([], false)
	modo = qual


func _ready() -> void:
	super._ready()
	for n in ["msg_linha", "msg_separa"]:
		_tex[n] = load(PASTA + n + ".png")
	if modo == "bc":
		var t := DicaItem.t(858) + " " + DicaItem.t(857) if bc.get("ok", false) else DicaItem.t(860) + " " + DicaItem.t(859)
		_frase = _quebrar(get_theme_default_font(), t, 210.0)
	elif modo == "cc":
		# o texto ingles do "missao cumprida" e do "falhou" do castelo vem vazio no Text_eng (1154 e 1155):
		# fica a frase do guardiao (1151) ou "Unfortunately, you have failed" (860) e "Try again next time" (1153)
		_frase.assign([DicaItem.t(1151)] if bc.get("ok", false) else [DicaItem.t(860), DicaItem.t(1153)])
	_ajustar()


func altura() -> float:
	if modo == "ds":
		return 67.0 + 11 * 15 + 21 + 3 * 15 + 50
	return 67.0 + 15.0 * (6 + ceili(maxi(_frase.size() - 2, 0) * 16 / 15.0)) + 50


# a caixa e alta (408 de 480 no Devil Square): na tela larga a escala segue a altura pra caber
func _ajustar() -> void:
	super._ajustar()
	if is_inside_tree():
		var v := get_viewport_rect().size
		_esc = minf(v.x / 640.0, v.y / 480.0)
		scale = Vector2(_esc, _esc)
		position = Vector2((v.x - L * _esc) / 2.0, (60.0 if modo == "ds" else 100.0) * _esc)


func _quebrar(f: Font, t: String, largura: float) -> Array[String]:
	var linhas: Array[String] = []
	var atual := ""
	for p in t.split(" ", false):
		var tenta := p if atual == "" else atual + " " + p
		if atual != "" and f.get_string_size(tenta, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > largura:
			linhas.append(atual)
			atual = p
		else:
			atual = tenta
	if atual != "":
		linhas.append(atual)
	return linhas


func _draw() -> void:
	var a := altura()
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 2, L, a - 2), false)
	draw_texture_rect(_tex.msg_topo, Rect2(0, 0, L, 67), false)
	var y := 67.0
	if modo == "ds":
		for i in 11:
			draw_texture_rect(_tex.msg_meio, Rect2(0, y, L, 15), false)
			y += 15
		draw_texture_rect(_tex.msg_linha, Rect2(0, y, 223, 21), false)
		y += 21
		for i in 3:
			draw_texture_rect(_tex.msg_meio, Rect2(0, y, L, 15), false)
			y += 15
	else:
		while y < a - 50:
			draw_texture_rect(_tex.msg_meio, Rect2(0, y, L, 15), false)
			y += 15
	draw_texture_rect(_tex.msg_baixo, Rect2(0, a - 50, L, 50), false)
	var b := _botao(0)
	draw_texture_rect_region(_tex.msg_ok, b, Rect2(0, 30 * (1 if b.has_point(_mouse) else 0), 54, 30))
	var f := get_theme_default_font()
	if modo == "ds":
		_desenhar_ds(f)
	elif modo == "cc":
		_desenhar_cc(f)
	else:
		_desenhar_bc(f)


func _escrever(f: Font, x: float, y: float, t: String, cor: Color, largura := -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# a fonte do cliente e mais estreita: o que nao cabe desce de tamanho (o Godot corta o resto)
	var cabe := largura if largura > 0 else L - x - 8
	var tam := 10
	while tam > 7 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > cabe:
		tam -= 1
	var p := Vector2(x, y + 10)
	draw_string_outline(f, p, t, al, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, largura, tam, cor)


# CSDevilSquareMatch::RenderMatchResult (as colunas a 0, 15, 30, 90, 140 e 178 da borda)
func _desenhar_ds(f: Font) -> void:
	for yl in [75, 93, 255, 273]:
		draw_texture_rect(_tex.msg_separa, Rect2(13, yl, 205, 2), false)
	var xs := [0.0, 15.0, 30.0, 90.0, 140.0, 178.0]
	var y := 40.0
	_escrever(f, xs[2], y, DicaItem.t(647), Color.WHITE)
	y += 16
	_escrever(f, xs[2], y, DicaItem.t(648, [heroi]), Color.WHITE)
	y += 24
	var verde := Color8(0, 255, 0)
	_escrever(f, xs[2], y, DicaItem.t(680), verde, xs[3] - xs[1], HORIZONTAL_ALIGNMENT_CENTER)
	_escrever(f, xs[3], y, DicaItem.t(682), verde, xs[4] - xs[3], HORIZONTAL_ALIGNMENT_CENTER)
	_escrever(f, xs[4], y, DicaItem.t(683), verde, xs[5] - xs[4], HORIZONTAL_ALIGNMENT_CENTER)
	_escrever(f, xs[5], y, DicaItem.t(684), verde, 210 - xs[5], HORIZONTAL_ALIGNMENT_CENTER)
	y += 20
	var inicio := y
	for i in lista.size():
		_linha_ds(f, xs, y, i + 1, lista[i], Color8(200, 120, 0) if i == minha_pos - 1 else Color8(255, 255, 0))
		y += 16
	if minha_pos > 0 and minha_pos <= lista.size():
		y = inicio + 160
		_escrever(f, 0, y, DicaItem.t(685), Color8(200, 120, 0), L, HORIZONTAL_ALIGNMENT_CENTER)
		_linha_ds(f, xs, y + 20, minha_pos, lista[minha_pos - 1], Color8(200, 120, 0))


func _linha_ds(f: Font, xs: Array, y: float, pos: int, d: Dictionary, cor: Color) -> void:
	_escrever(f, xs[1], y, "%2d" % pos, cor)
	_escrever(f, xs[2], y, str(d.nome), cor)
	_escrever(f, xs[3], y, str(d.pontos), cor, xs[4] - xs[3] - 4, HORIZONTAL_ALIGNMENT_RIGHT)
	_escrever(f, xs[4], y, str(d.exp), cor, xs[5] - xs[4] - 4, HORIZONTAL_ALIGNMENT_RIGHT)
	_escrever(f, xs[5], y, str(d.zen), cor, 214 - xs[5], HORIZONTAL_ALIGNMENT_RIGHT)


# CNewBloodCastleSystem::RenderMatchResult
func _desenhar_bc(f: Font) -> void:
	var y := 40.0
	for linha in _frase:
		_escrever(f, 0, y, linha, Color8(128, 255, 128), L, HORIZONTAL_ALIGNMENT_CENTER)
		y += 16
	y += 14
	_escrever(f, 0, y, DicaItem.t(861, [int(bc.get("exp", 0))]), Color8(210, 255, 210), L, HORIZONTAL_ALIGNMENT_CENTER)
	y += 24
	if bc.get("ok", false):
		_escrever(f, 0, y, DicaItem.t(862, [int(bc.get("zen", 0))]), Color8(255, 210, 210), L, HORIZONTAL_ALIGNMENT_CENTER)
		y += 24
	_escrever(f, 0, y, DicaItem.t(863, [int(bc.get("pontos", 0))]), Color8(210, 210, 255), L, HORIZONTAL_ALIGNMENT_CENTER)


# CNewChaosCastleSystem::RenderMatchResult
func _desenhar_cc(f: Font) -> void:
	var y := 40.0
	for linha in _frase:
		_escrever(f, 0, y, linha, Color8(128, 255, 128), L, HORIZONTAL_ALIGNMENT_CENTER)
		y += 16
	y = 40.0 + 16 + 30
	var cor := Color8(210, 255, 210)
	_escrever(f, 0, y, DicaItem.t(861, [int(bc.get("exp", 0))]), cor, L, HORIZONTAL_ALIGNMENT_CENTER)
	y += 20
	_escrever(f, 0, y, DicaItem.t(1162, [int(bc.get("monstros", 0))]), cor, L, HORIZONTAL_ALIGNMENT_CENTER)
	y += 20
	_escrever(f, 0, y, DicaItem.t(1163, [int(bc.get("jogadores", 0))]), cor, L, HORIZONTAL_ALIGNMENT_CENTER)
