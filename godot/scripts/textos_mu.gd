class_name TextosMU
extends Control
# Textos do mundo no jeito do cliente S6, desenhados em 2D por cima do 3D:
# - nome em cima da cabeca (Chat.cpp RenderBoolean): fonte normal (11 px em 480 de altura,
#   16 px de 1080 pra cima), caixa justa no texto, base da caixa 60 acima do topo do corpo;
# - nome do item no chao (ZzzInventory, BuildGroundItemLabelDescriptor): fundo preto, cor pelo
#   tipo do item; com o mouse em cima sai no mouse, e o Alt liga e desliga o de todos;
# - numero do dano (ZzzEffectPoint): digitos do Interface/FontTest, 15 de lado (50 no golpe
#   excelente/critico, encolhendo ate 15), sobe com "gravidade" 10 que cai 0,3 por quadro
#   (25 quadros por segundo, ~1,3 s), some no fim.

const NUMEROS := preload("res://dados/hud/fonte_numeros.png")
const AMARELO := Color(1.0, 0.8, 0.1)
# cor do nome pelo estado de heroi (SetPlayerColor): 0 novo, 1 heroi, 2 heroi menor, 3 comum, 4 aviso de PK, 5 e 6 PK
const CORES_HEROI := [Color8(150, 255, 240), Color8(100, 120, 255), Color8(140, 180, 255), Color8(200, 220, 255),
	Color8(255, 150, 60), Color8(255, 80, 30), Color8(255, 0, 0)]
const MARCA_GENS := [null, preload("res://dados/hud/gens_marca_d.png"), preload("res://dados/hud/gens_marca_v.png")]
const JOIAS := ["14,13", "14,14", "14,16", "14,22", "14,31", "14,41", "14,42", "14,43", "14,44", "12,15", "12,30", "12,31"]

static var atual: TextosMU
var jogo: Node
var nomes_itens := true      # Alt liga e desliga o nome de todos os itens do chao
var _pontos: Array[Dictionary] = []


func _ready() -> void:
	atual = self
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# CreatePoint: numero (ou Miss com dano 0) saindo de 140 acima do pe
func ponto(alvo: Node3D, dano: int, cor: Color, escala := 15.0, subir := 0.0) -> void:
	_pontos.append({alvo = alvo, pos = alvo.global_position, z = 140.0 + subir, g = 10.0, esc = escala,
		cor = cor, texto = str(dano) if dano > 0 else ""})


func _process(dt: float) -> void:
	var q := dt * 25.0
	for p in _pontos.duplicate():
		if is_instance_valid(p.alvo):
			p.pos = (p.alvo as Node3D).global_position
		p.z += p.g * q
		p.g -= 0.3 * q
		if p.texto != "":
			p.esc = maxf(15.0, p.esc - 5.0 * q)
		if p.g <= 0.0:
			_pontos.erase(p)
	queue_redraw()


# fonte normal do cliente: 11 px em 480 de altura ate 16 px em 1080, em unidades do canvas
func _fonte() -> Array:
	var janela := float(DisplayServer.window_get_size().y)
	var k := janela / get_viewport_rect().size.y          # pixels de verdade por unidade do canvas
	var px := 11.0 + 5.0 * clampf((janela / 480.0 - 1.0) / 1.25, 0.0, 1.0)
	return [maxi(int(round(px / k)), 8), k]


func _draw() -> void:
	if jogo == null or jogo.eu == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := get_theme_default_font()
	var fk := _fonte()
	var tam: int = fk[0]
	var sob = jogo.item_sob
	for it: ItemChao in jogo.itens.values():
		if is_instance_valid(it) and (nomes_itens or it == sob):
			var p := it.global_position + Vector3.UP * 0.3
			if cam.is_position_behind(p):
				continue
			var s := cam.unproject_position(p) - Vector2(0, 15.0 * get_viewport_rect().size.y / 480.0)
			if it == sob and not nomes_itens:
				s = get_local_mouse_position() - Vector2(0, 15.0 * get_viewport_rect().size.y / 480.0)
			_caixa(f, tam, it.nome, s, _cor_item(it.dados), Color.BLACK, _joia(it.dados), true)
	for e: Entidade in jogo.entidades.values():
		if is_instance_valid(e) and not e.morto and e.nome_visivel():
			_nome(cam, f, tam, e)
	for e: Entidade in jogo.entidades.values():
		if is_instance_valid(e) and not e.morto and e.has_meta("pedra_estagio") and int(e.get_meta("pedra_estagio")) < 5:
			_barra_obra(cam, e, int(e.get_meta("pedra_estagio")))
	for p in _pontos:
		_numero(cam, p)
	_foco(f, tam)


# RenderBuildTimes (GMBattleCastle): a Life Stone subindo (C1 B9 01, estagio 0 a 4) tem a barra de 50x2 em cima,
# 100 acima da caixa do modelo, cheia em estagio / 5 (RenderBar: sombra 80000000, moldura 003333, trilho 003232, verde 00C832)
func _barra_obra(cam: Camera3D, e: Entidade, estagio: int) -> void:
	var alto: float = (e.boneco.altura if e.boneco else 1.5) + 1.0
	var p := e.global_position + Vector3.UP * alto
	if cam.is_position_behind(p):
		return
	var k := get_viewport_rect().size.y / 480.0
	var s := cam.unproject_position(p)
	var x := s.x - 25 * k
	var y := s.y + 12 * k
	draw_rect(Rect2(x + k, y + k, 54 * k, 6 * k), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(x, y, 54 * k, 6 * k), Color8(0, 0x33, 0x33))
	draw_rect(Rect2(x + 2 * k, y + 2 * k, 50 * k, 2 * k), Color8(0, 0x32, 0x32))
	draw_rect(Rect2(x + 2 * k, y + 2 * k, 50 * k * estagio / 5.0, 2 * k), Color8(0, 0xC8, 0x32))


# foco: o monstro do mouse (ou o alvo) com o nome no alto da tela, como o cliente faz com o mouse em cima
# (nome em (255, 230, 200) no fundo (100, 0, 0)) e uma barra de 20 pedacos. O 1.04d nao recebe a vida do
# monstro: a barra sai da vida maxima do banco menos o dano que este cliente viu ele levar.
func _foco(f: Font, tam: int) -> void:
	var e: Entidade = jogo.sobre if is_instance_valid(jogo.sobre) else null
	if (e == null or e.tipo != "monstro") and jogo.entidades.has(jogo.alvo_id):
		e = jogo.entidades[jogo.alvo_id]
	if e == null or e.tipo != "monstro" or e.morto:
		return
	var k := get_viewport_rect().size.x / 640.0
	var info: Array = jogo.monstros_vida.get(str(e.numero), [0, 0])
	var nome := e.nome if info[0] <= 0 else "%s  Lv %d" % [e.nome, info[0]]
	var h := f.get_height(tam)
	_caixa(f, tam, nome, Vector2(320 * k, 2 * k + h), Color8(255, 230, 200), Color8(100, 0, 0, 255), false, false)
	if info[1] <= 0:
		return
	var resto := clampf(1.0 - float(e.dano_visto) / info[1], 0.0, 1.0)
	var b := Rect2(round(320 * k - 50 * k), round(4 * k + h), round(100 * k), round(4 * k))
	draw_rect(b, Color8(0, 0, 0, 200))
	for i in ceili(resto * 20):
		draw_rect(Rect2(b.position.x + (1 + 5 * i) * k, b.position.y + k, 4 * k, 2 * k), Color8(250, 10, 0))


func _nome(cam: Camera3D, f: Font, tam: int, e: Entidade) -> void:
	var p := e.global_position + Vector3.UP * (e.altura() + 0.6)
	if cam.is_position_behind(p):
		return
	var s := cam.unproject_position(p)
	# balao de fala (CHATBOX): as linhas logo acima da cabeca, fundo azul escuro, e o nome sobe em cima delas;
	# nos ultimos 0,4 s vai sumindo
	if e.falando():
		var h := f.get_height(tam)
		var a := clampf((e.fala_ate - Time.get_ticks_msec()) / 400.0, 0.5, 1.0)
		for i in range(e.fala.size() - 1, -1, -1):
			_caixa(f, tam, e.fala[i], s, Color8(230, 220, 200, int(255 * a)), Color8(10, 30, 50, int(150 * a)), false, false)
			s.y -= h
		s.y -= 2
	var cor: Color = CORES_HEROI[clampi(e.heroi, 0, 6)]
	var fundo := Color8(10, 30, 50, 150)
	match e.tipo:
		"eu":
			fundo = Color8(60, 100, 0, 150)
		"npc", "guarda":
			cor = Color8(150, 255, 240)
		"monstro":
			cor = Color8(255, 230, 200)
			fundo = Color8(100, 0, 0, 255)
	if not jogo.guerra.is_empty() and e.tipo in ["eu", "jogador"]:
		if jogo.inimigo_da_guerra(e):
			fundo = Color8(50, 0, 0, 150)
		elif e.guilda >= 0 and e.guilda == jogo.minha_guilda:
			fundo = Color8(30, 50, 0, 150)
	# Gens (Chat.cpp): a marca do titulo (40x55, 0,8 da folha) colada a esquerda do nome; em Vulcanus quem e do
	# outro Gens e ja tem contribuicao aparece so com a marca, sem o nome
	if e.tipo in ["eu", "jogador"] and (e.gens == 1 or e.gens == 2) and (jogo.eu_skin if e.tipo == "eu" else e.skin) == 0:
		var k := get_viewport_rect().size.x / 640.0
		var h := f.get_height(tam)
		if jogo.inimigo_gens(e) and e.gens_contribuicao > 0:
			_marca_gens(Rect2(s.x - 19 * k, s.y - h / 2.0 - 27.5 * k, 40 * k, 55 * k), e)
			return
		var w := f.get_string_size(e.nome, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 3.0
		_marca_gens(Rect2(round(s.x - w / 2.0) - 40 * k + 1, s.y - h / 2.0 - 27.5 * k, 40 * k, 55 * k), e)
	_caixa(f, tam, e.nome, s, cor, fundo, false, false)
	# RenderPartyHP: membro do grupo (menos eu) com a barra de 42x5 em cima do nome, 10 pedacos de 3x2
	if e.tipo == "jogador" and jogo.janela_grupo:
		var passo: int = jogo.janela_grupo.passo_de(e.nome)
		if passo >= 0:
			var k := get_viewport_rect().size.y / 480.0
			var b := Rect2(round(s.x - 21 * k), round(s.y - f.get_height(tam) - 7 * k), round(42 * k), round(5 * k))
			draw_rect(b, Color8(0, 0, 0, 255))
			draw_rect(b.grow(-k * 0.5), Color8(0x33, 0, 0, 255))
			for i in passo:
				draw_rect(Rect2(b.position.x + (2 + 4 * i) * k, b.position.y + 1.5 * k, 3 * k, 2 * k), Color8(250, 10, 0))
	var y := f.get_height(tam) + 2
	# guilda: "[Nome] Master" em cima do nome e "<Alianca> Alliance master" em cima dela (AddGuildName); verde pra mim
	# e pra minha guilda, vermelho pro rival e a alianca dele, azul claro pros outros
	if e.guilda >= 0 and e.tipo in ["eu", "jogador"] and Guildas.info.has(e.guilda):
		var g := "[%s]" % Guildas.nome(e.guilda)
		var c := Guildas.cargo(e.guilda_cargo) if e.guilda_cargo != 0 else DicaItem.t(1330)
		if e.guilda_cargo != 255:
			g += " " + c
		var cor_g := Color8(230, 230, 255)
		var fundo_g := Color8(10, 30, 50, 150)
		var r: int = e.guilda_rel | e.guilda_relacao
		if e.tipo == "eu":
			cor_g = Color8(200, 255, 0)
			fundo_g = Color8(60, 100, 0, 150)
		elif r & 10:
			cor_g = Color8(255, 30, 0)
			fundo_g = Color8(0, 0, 0, 150)
		elif e.guilda == jogo.minha_guilda or r != 0:
			cor_g = Color8(200, 255, 0)
			fundo_g = Color8(20, 50, 80, 150)
		_caixa(f, tam, g, s - Vector2(0, y), cor_g, fundo_g, false, false)
		y += f.get_height(tam) + 2
		var alianca: String = Guildas.info[e.guilda].alianca
		if alianca != "":
			# o original escreve "Alliance" pro GR_UNION e logo apaga (o if seguinte sobrescreve): fica sem sufixo
			var u := "<%s>" % alianca
			var mestre: bool = e.guilda_cargo == 128
			if r & 4:
				u += " " + DicaItem.t(1296 if mestre else 1295)
			elif r & 2:
				u += " " + DicaItem.t(1298 if mestre else 1297)
			elif r & 8:
				u += " " + DicaItem.t(1299)
			_caixa(f, tam, u, s - Vector2(0, y), cor_g, fundo_g, false, false)
			y += f.get_height(tam) + 2
	# loja pessoal aberta: o titulo em cima do nome (PersonalShopTitleImp), mais forte com o mouse
	var titulo: String = jogo.titulos_lojas.get(e.id, "")
	if titulo != "":
		var em_cima: bool = e == jogo.sobre
		_caixa(f, tam, titulo, s - Vector2(0, y), Color8(250, 150, 0) if em_cima else Color8(230, 230, 0),
			Color8(250, 150, 0, 128) if em_cima else Color8(108, 57, 41, 128), false, false)


# caixa justa no texto (3 px a mais de largura no nome), centrada em x; base em s.y
# (centro) ou base da caixa em s.y (nome de cabeca)
func _caixa(f: Font, tam: int, texto: String, s: Vector2, cor: Color, fundo: Color, negrito: bool, centro_y: bool) -> void:
	var w := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 3.0
	var h := f.get_height(tam)
	var r := Rect2(round(s.x - w / 2.0), round(s.y - (h / 2.0 if centro_y else h)), round(w), round(h))
	draw_rect(r, fundo)
	var base := Vector2(r.position.x + 1.5, r.position.y + f.get_ascent(tam))
	draw_string(f, base, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
	if negrito:
		draw_string(f, base + Vector2(0.6, 0), texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)


func _marca_gens(r: Rect2, e: Entidade) -> void:
	draw_texture_rect_region(MARCA_GENS[e.gens], r, JanelaGens.regiao_marca(e.gens_titulo))


static func _joia(d: Dictionary) -> bool:
	return not d.has("zen") and "%d,%d" % [d.grupo, d.numero] in JOIAS


# cor do nome no chao, na ordem do cliente
static func _cor_item(d: Dictionary) -> Color:
	if d.has("zen") or _joia(d):
		return AMARELO
	var g: int = d.grupo
	var n: int = d.numero
	var asa := g == 12 and (n <= 6 or n >= 36 and n <= 43 or n == 49 or n == 50 or n >= 130 and n <= 135)
	if (int(d.get("exc", 0)) & 63) and not asa:
		return Color(0.1, 1.0, 0.5)
	var nv: int = d.get("nivel", 0)
	if nv >= 7:
		return AMARELO
	if d.get("skill", false) or d.get("sorte", false) or int(d.get("opcao", 0)) > 0:
		return Color(0.4, 0.7, 1.0)
	if nv == 0:
		return Color(0.7, 0.7, 0.7)
	if nv < 3:
		return Color(0.9, 0.9, 0.9)
	if nv < 5:
		return Color(1.0, 0.5, 0.2)
	return Color(0.4, 0.7, 1.0)


# RenderNumberPoints: cada digito e um quadrado de 'esc' (unidades do MU) virado pra camera,
# um do lado do outro a 0,707 do lado; Miss e a palavra de 45 x 20
func _numero(cam: Camera3D, p: Dictionary) -> void:
	var w: Vector3 = p.pos + Vector3.UP * (p.z / 100.0)
	if cam.is_position_behind(w):
		return
	var c := cam.unproject_position(w)
	# o tamanho segue a camera padrao do cliente (~0,9 px por unidade em 480 de altura), sem o
	# zoom da nossa camera, que fica mais longe: 15 da ~20 px em 720. A subida e no 3D.
	var por_unidade := 0.9 * get_viewport_rect().size.y / 480.0
	var cor: Color = p.cor
	cor.a = minf(1.0, p.g * 0.4)
	if p.texto == "":
		var tam := Vector2(45.0, 20.0) * por_unidade
		draw_texture_rect_region(NUMEROS, Rect2(c - tam / 2.0, tam), Rect2(0, 17, 32, 15), cor)
		return
	var lado: float = p.esc * por_unidade
	var passo := lado * 0.7071
	var n: int = p.texto.length()
	var x0 := c.x - (passo * (n - 1) + lado) / 2.0
	for i in n:
		var d: int = p.texto.unicode_at(i) - 48
		draw_texture_rect_region(NUMEROS, Rect2(x0 + passo * i, c.y - lado / 2.0, lado, lado), Rect2(d * 16, 0, 16, 16), cor)
