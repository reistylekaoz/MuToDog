class_name JanelaMaster
extends Control
# Janela A (CNewUIMasterLevel do S6): a arvore de skills master, 640 x 428 no topo da tela. Tres grupos
# (colunas), 4 skills por linha e uma linha por rank. Dados do proprio cliente: MasterSkillTreeData,
# skill_eng e MasterSkillTooltip_eng (ferramentas/dados_master.py -> dados/master.json).
# O servidor manda os niveis ao entrar (F3 53) e responde o ponto gasto com o nivel novo (F3 52). Se ele
# recusa, nao responde nada: por isso a janela confere as regras do original antes de mandar.

signal aprender(skill: int)

const L := 640.0
const A := 428.0
const TAM := 10
const PASTA := "res://dados/hud/"
const COLUNAS := [Vector2(11, 55), Vector2(221, 55), Vector2(431, 55)]
const CENTRO_GRUPO := [92.0, 302.0, 513.0]
const NIVEL_PRO_PROXIMO := 10   # MASTER_SKILL_LEVEL_REQ_FOR_NEXT_RANK
const SKILL_MASTER := 300       # AT_SKILL_MASTER_BEGIN
# classe master (numero do servidor) -> bit da classe na arvore, texto dos grupos, nome da classe
const CLASSES := {3: [2, 1751, 1669], 7: [1, 1755, 1668], 11: [4, 1759, 1670], 13: [16, 1763, 1671],
	17: [32, 1767, 1672], 23: [8, 3136, 1689], 25: [64, 3330, 3151]}
# seta da arvore (1 a 8): onde fica em relacao a caixa da skill e o tamanho (RenderIcon)
const SETAS := {1: [Vector2(30, 14), Vector2(28, 7)], 2: [Vector2(30, 14), Vector2(28, 7)],
	3: [Vector2(14.5, 35), Vector2(7, 12)], 4: [Vector2(14.5, 35), Vector2(7, 52)],
	5: [Vector2.ZERO, Vector2(42, 31)], 6: [Vector2.ZERO, Vector2(42, 31)],
	7: [Vector2(16.5, 36), Vector2(40, 28)], 8: [Vector2.ZERO, Vector2(40, 28)]}

var classe := -1
var master := {}            # o do jogo: nivel, exp, exp_prox, pontos
var minhas_skills := {}     # o do jogo: indice -> skill (F3 11)
var exp_do_master: Callable # exp em que o nivel master n comeca
var entradas := []          # [indice, classes, grupo, pontos, maximo, seta, [pedidas], skill, valor]
var niveis := {}            # skill -> [nivel, valor, proximo valor]
var _skills := {}           # "<n>" -> [nome, rank, icone, marca, uso]
var _arvore_toda := []
var _todas_dicas := []
var _dicas := {}            # skill -> 7 textos da dica
var _caixa := {}            # aviso ou confirmacao por cima: {"linhas": [], "skill": -1 so aviso}
var _tex := {}
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["master_fundo1", "master_fundo2", "master_icones", "master_icones_apagados", "master_caixa",
			"master_fechar", "btn_vazio"]:
		_tex[n] = load(PASTA + n + ".png")
	for i in range(1, 9):
		_tex["seta%d" % i] = load(PASTA + "master_seta%d.png" % i)
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


# a lista do servidor pode chegar antes do _ready: os dados carregam no primeiro uso
func _carregar() -> void:
	if not _arvore_toda.is_empty():
		return
	var d := ItensMU._json("res://dados/master.json")
	# o JSON chega com float: chave de dicionario e conta inteira pedem int
	for k in d.get("skills", {}):
		var i: Array = d.skills[k]
		_skills[k] = [i[0], int(i[1]), int(i[2]), int(i[3]), int(i[4])]
	_todas_dicas = d.get("dicas", [])
	_arvore_toda = d.get("arvore", [])


static var _marcas := {}   # skill master ativa (uso 4) -> skill que ela fortalece


# a skill base de uma master ativa (326 Cyclone Strengthener -> 22 Cyclone; 332 -> 330 -> 41):
# animacao e efeito sao os da base, como o SKILL_REPLACEMENTS do original
static func base(n: int) -> int:
	if n < SKILL_MASTER:
		return n
	if _marcas.is_empty():
		var d := ItensMU._json("res://dados/master.json")
		for k in d.get("skills", {}):
			var i: Array = d.skills[k]
			if int(i[4]) == 4 and int(i[3]) > 0:
				_marcas[int(k)] = int(i[3])
		_marcas[-1] = -1   # carregado
	while _marcas.has(n):
		n = _marcas[n]
	return n


func _ajustar() -> void:
	var v := get_viewport_rect().size
	var barra := 51.0 * v.x / 640.0
	var esc := minf(v.x / L, (v.y - barra) / A)
	scale = Vector2(esc, esc)
	size = Vector2(L, A)
	position = Vector2((v.x - L * esc) / 2.0, 0)
	queue_redraw()


func e_master(c: int) -> bool:
	return CLASSES.has(c)


# SetMasterType: so as skills da classe
func definir_classe(c: int) -> void:
	if c == classe:
		return
	classe = c
	_carregar()
	var bit: int = CLASSES.get(c, [0])[0]
	entradas = []
	for e in _arvore_toda:
		if int(e[1]) & bit:
			entradas.append([int(e[0]), int(e[1]), int(e[2]), int(e[3]), int(e[4]), int(e[5]),
				[int(e[6][0]), int(e[6][1])], int(e[7]), float(e[8])])
	_dicas = {}
	for x in _todas_dicas:
		if int(x[1]) & bit and not _dicas.has(int(x[0])):
			_dicas[int(x[0])] = x[2]
	niveis = {}


func alternar() -> void:
	visible = not visible
	_caixa = {}
	if not visible:
		DicaItem.esconder(self)
	queue_redraw()


func _entrada(indice: int) -> Array:
	for e in entradas:
		if e[0] == indice:
			return e
	return []


# F3 53 (SetMasterSkillTreeInfo)
func lista(l: Array) -> void:
	niveis = {}
	for k in l:
		var e := _entrada(k.indice)
		if not e.is_empty():
			niveis[e[7]] = [k.nivel, k.valor, k.prox]
	queue_redraw()


# F3 52 (SkillUpgrade)
func subiu(indice: int, nivel: int, valor: float, prox: float) -> void:
	var e := _entrada(indice)
	if not e.is_empty():
		niveis[e[7]] = [nivel, valor, prox]
	queue_redraw()


func nivel(skill: int) -> int:
	return niveis.get(skill, [0])[0]


func pontos_do_grupo(g: int) -> int:
	var t := 0
	for e in entradas:
		if e[2] == g:
			t += nivel(e[7])
	return t


func _info(skill: int) -> Array:
	return _skills.get(str(skill), ["Skill %d" % skill, 1, 0, 0, 0])


func _rect(e: Array) -> Rect2:
	var col: int = (e[0] - 1) % 4
	var rank: int = _info(e[7])[1]
	return Rect2(COLUNAS[e[2]] + Vector2(col * 49, (rank - 1) * 41), Vector2(50, 38))


func _rect_icone(e: Array) -> Rect2:
	return Rect2(_rect(e).position + Vector2(8, 5), Vector2(20, 28))


# --- as regras do original (CheckParentSkill, CheckRankPoint, CheckBeforeSkill) ---------------

# as skills master pedidas no nivel 10
func pai_ok(e: Array) -> bool:
	for r in e[6]:
		if r >= SKILL_MASTER and nivel(r) < NIVEL_PRO_PROXIMO:
			return false
	return true


# do rank 2 pra cima: alguma skill do rank de baixo, no mesmo grupo, no nivel 10
func rank_ok(e: Array) -> bool:
	var rank: int = _info(e[7])[1]
	if rank <= 1:
		return true
	for o in entradas:
		if o[2] == e[2] and _info(o[7])[1] == rank - 1 and nivel(o[7]) >= NIVEL_PRO_PROXIMO:
			return true
	return false


# a primeira vez: a skill base (marca) precisa estar na lista, a nao ser que ela seja outra master ativa
func antes_ok(skill: int) -> bool:
	if nivel(skill) != 0:
		return true
	var marca: int = _info(skill)[3]
	if marca == 0 or _info(marca)[4] == 4:
		return true
	return marca in minhas_skills.values()


# o OpenMU cobra os pontos da tabela no primeiro nivel e 1 nos outros (AddMasterPointAction)
func pontos_pedidos(e: Array) -> int:
	return e[3] if nivel(e[7]) == 0 else 1


func disponivel(e: Array) -> bool:
	return pai_ok(e) and rank_ok(e) and antes_ok(e[7])


# "" = pode mandar; senao o aviso do original
# shortcut: nao confere a arma que a skill pede (IsNonWeaponSkillOrIsSkillEquipped), o OpenMU tambem nao.
func motivo(e: Array) -> String:
	if nivel(e[7]) >= e[4] or int(master.get("pontos", 0)) < pontos_pedidos(e):
		return DicaItem.t(3326)
	if not disponivel(e):
		return DicaItem.t(3327)
	return ""


# CheckAttributeArea: clicou na skill
func escolher(e: Array) -> void:
	var m := motivo(e)
	if m != "":
		_caixa = {"linhas": [m], "skill": -1}
	else:
		_caixa = {"linhas": [DicaItem.t(1771), DicaItem.t(1772, [pontos_pedidos(e)])], "skill": e[7]}
	queue_redraw()


func confirmar(sim: bool) -> void:
	var s: int = _caixa.get("skill", -1)
	_caixa = {}
	if sim and s >= 0:
		aprender.emit(s)
	queue_redraw()


# --- desenho -------------------------------------------------------------------------

func _draw() -> void:
	draw_texture_rect(_tex.master_fundo1, Rect2(0, 0, 512, A), false)
	draw_texture_rect(_tex.master_fundo2, Rect2(512, 0, 128, A), false)
	var f := get_theme_default_font()
	var sob: Array = []
	for e in entradas:
		_skill(f, e)
		if _caixa.is_empty() and _rect_icone(e).has_point(_mouse):
			sob = e
	var fr := 1 if Rect2(611, 9, 13, 14).has_point(_mouse) else 0
	draw_texture_rect_region(_tex.master_fechar, Rect2(611, 9, 13, 14), Rect2(0, 14 * fr, 13, 14))
	_cabecalho(f)
	if not _caixa.is_empty():
		_desenhar_caixa(f)
	if not sob.is_empty():
		DicaItem.mostrar(self, f, linhas_dica(sob), _rect_icone(sob))
	elif _caixa.is_empty() and Rect2(458, 11, 81, 10).has_point(_mouse) and int(master.get("exp_prox", 0)) > 0:
		var t := DicaItem.t(1748).replace("%I64d", "%s") % [ItemChao._milhar(master.exp), ItemChao._milhar(master.exp_prox)]
		DicaItem.mostrar(self, f, [{"t": t, "cor": DicaItem.BRANCO}], Rect2(458, 11, 81, 10))
	else:
		DicaItem.esconder(self)


func _skill(f: Font, e: Array) -> void:
	var r := _rect(e)
	var info := _info(e[7])
	draw_texture_rect(_tex.master_caixa, r, false)
	var ok := disponivel(e)
	var ic: int = info[2]
	draw_texture_rect_region(_tex.master_icones if ok else _tex.master_icones_apagados, _rect_icone(e),
		Rect2((ic % 25) * 20, (ic / 25) * 28, 20, 28))
	if SETAS.has(e[5]):
		draw_texture_rect(_tex["seta%d" % e[5]], Rect2(r.position + SETAS[e[5]][0], SETAS[e[5]][1]), false)
	_texto(f, r.position + Vector2(38, 32), str(nivel(e[7])), -1, TAM, Color.WHITE if ok else Color8(120, 120, 120))


func _cabecalho(f: Font) -> void:
	var c: Array = CLASSES.get(classe, [0, 0, 0])
	if c[2] == 0:
		return
	_texto(f, Vector2(154, 20), DicaItem.t(c[2]), -1, TAM, Color.WHITE)
	_texto(f, Vector2(275, 20), DicaItem.t(1746, [int(master.get("nivel", 0))]), -1, TAM, Color.WHITE)
	_texto(f, Vector2(372, 20), DicaItem.t(1747, [int(master.get("pontos", 0))]), -1, TAM, Color.WHITE)
	if int(master.get("exp_prox", 0)) > 0 and exp_do_master.is_valid():
		var base: int = exp_do_master.call(int(master.nivel))
		var p := float(master.exp - base) / float(maxi(master.exp_prox - base, 1)) * 100.0
		_texto(f, Vector2(466, 20), DicaItem.t(3335, [p]), -1, TAM, Color.WHITE)
	for g in 3:
		var t := DicaItem.t(c[1] + g, [pontos_do_grupo(g)])
		_texto(f, Vector2(CENTRO_GRUPO[g] - 80, 49), t, 160, TAM, Color8(255, 155, 0), false, HORIZONTAL_ALIGNMENT_CENTER)


# RenderToolTip: nome, rank e nivel, o efeito agora e no proximo nivel, o que pede (vermelho = falta)
func linhas_dica(e: Array) -> Array:
	var s: int = e[7]
	var info := _info(s)
	var d: Array = _dicas.get(s, ["", "", "", "", "", "", ""])
	var nv := nivel(s)
	var v: Array = niveis.get(s, [0, 0.0, 0.0])
	var l := [{"t": info[0], "cor": DicaItem.AMARELO, "negrito": true}]
	_mais(l, fmt(d[0], [info[1], nv, e[4]]), DicaItem.BRANCO)
	_mais(l, d[1] if e[8] == -1.0 else fmt(d[1], [v[1] if nv != 0 else e[8]]), DicaItem.BRANCO)
	if nv != 0 and nv < e[4]:
		_mais(l, DicaItem.t(3328), DicaItem.VERDE)
		_mais(l, fmt(d[1], [v[2]]), DicaItem.BRANCO)
	if nv < e[4]:
		_mais(l, DicaItem.t(3329), DicaItem.AZUL)
		var p := pontos_pedidos(e)
		_mais(l, fmt(d[2], [p]), DicaItem.BRANCO if int(master.get("pontos", 0)) >= p else DicaItem.VERMELHO)
	_mais(l, d[3], DicaItem.BRANCO if antes_ok(s) else DicaItem.VERMELHO)
	if nv < e[4] and info[1] != 1:
		_mais(l, d[4], DicaItem.BRANCO if rank_ok(e) else DicaItem.VERMELHO)
		for i in 2:
			var r: int = e[6][i]
			if r >= SKILL_MASTER:
				_mais(l, d[5 + i], DicaItem.VERMELHO if nivel(r) < NIVEL_PRO_PROXIMO else DicaItem.BRANCO)
	return l


# o "#" do texto do cliente quebra a linha; "# #" deixa uma linha em branco
func _mais(l: Array, t: String, cor: Color) -> void:
	for parte in t.split("#"):
		if parte == " ":
			l.append({"t": "", "cor": cor})
		elif parte.strip_edges() != "":
			l.append({"t": parte.strip_edges(), "cor": cor})


# printf do cliente: usa so os argumentos que o texto pede (o C ignora os que sobram, o GDScript nao)
static func fmt(t: String, args: Array) -> String:
	var n := RegEx.create_from_string("%[-+ 0#]*[0-9]*(\\.[0-9]+)?[dfis]").search_all(t.replace("%%", "")).size()
	return t.replace("%%", "%") if n == 0 else t % args.slice(0, n)


func _desenhar_caixa(f: Font) -> void:
	draw_rect(Rect2(0, 0, L, A), Color(0, 0, 0, 0.45))
	var caixa := Rect2(L / 2 - 110, 150, 220, 110)
	draw_rect(caixa, Color8(14, 12, 10, 245))
	draw_rect(caixa, Color8(150, 120, 70), false, 1.0)
	var y := 172.0
	for t in _caixa.linhas:
		_texto(f, Vector2(caixa.position.x, y), t, caixa.size.x, TAM, Color8(255, 230, 210), false, HORIZONTAL_ALIGNMENT_CENTER)
		y += 16
	for i in (2 if _caixa.skill >= 0 else 1):
		var b := _rect_botao(i)
		var linha := 1 if b.has_point(_mouse) else 0
		draw_texture_rect_region(_tex.btn_vazio, b, Rect2(0, 29 * linha, 108, 29))
		_texto(f, Vector2(b.position.x, b.position.y + 19), DicaItem.t(228 if i == 0 else 229), b.size.x, TAM,
			Color8(255, 230, 210), false, HORIZONTAL_ALIGNMENT_CENTER)


func _rect_botao(i: int) -> Rect2:
	if _caixa.get("skill", -1) < 0:
		return Rect2(L / 2 - 37, 222, 74, 29)
	return Rect2(L / 2 - 80 + 86 * i, 222, 74, 29)


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, negrito := false,
		al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string_outline(f, p, t, al, largura, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, largura, tam, cor)
	if negrito:
		draw_string(f, p + Vector2(0.5, 0), t, al, largura, tam, cor)


# --- mouse -------------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
		_mouse = ev.position
		clique(ev.position)
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()


func clique(p: Vector2) -> void:
	if not _caixa.is_empty():
		for i in (2 if _caixa.skill >= 0 else 1):
			if _rect_botao(i).has_point(p):
				confirmar(i == 0)
		return
	if Rect2(611, 9, 13, 14).has_point(p):
		alternar()
		return
	for e in entradas:
		if _rect_icone(e).has_point(p):
			escolher(e)
			return


func tecla_enter_esc(enter: bool) -> bool:
	if _caixa.is_empty():
		return false
	confirmar(enter)
	return true
