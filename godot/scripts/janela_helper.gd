class_name JanelaHelper
extends Loja
# Configuracao do MU Helper (tecla Z) desenhada como o CNewUIMuHelper do S6 (NewUIMuHelper.cpp): moldura do
# inventario (190 x 429), tres abas (newui_guild_tab04: Hunting, Obtaining, Other Settings), caixas com a
# moldura de tabela (newui_item_table), caixas de marcar do Option, botoes do proprio cliente (Setting do
# newui_Bt_clearness_illusion, Save Setting e Initialization do Ingame_Bt03, + e - do alcance com o numero
# do icon_Rank) e os textos 3500 a 3593 do Text.bmd. Cada posicao abaixo e a do cliente.
# O botao Setting abre a janela de lado (CNewUIMuHelperExt, coluna 2): condicao da skill, recuperacao e grupo.
# Clicar num quadro de skill abre a coluna de skills a esquerda (CNewUIMuHelperSkillList); botao direito
# esvazia o quadro. O que aparece muda com a classe, como o RegisterBtnCharacter/RegisterBoxCharacter.
# Salvar manda pro servidor (C2 AE) e ele devolve na proxima entrada.

signal salvar(dados: PackedByteArray)

enum { DW, DK, ELF, MG, DL, SUM, RF }

const BRANCO := Color(1, 1, 1)
const OURO := Color(1, 0.71, 0)        # 0xFF00B4FF do RenderText (ABGR)
const TAM := 8                         # g_hFont do cliente na tela de 640
const L_SKILL := 32.0
const A_SKILL := 38.0

var helper: MuHelper
var skills_de: Callable      # () -> Array dos numeros das minhas skills
var info_de: Callable        # numero -> [nome, alcance, tipo, ...]
var icone_de: Callable       # numero -> [textura, regiao] (HudMu.icone_skill)
var classe_de: Callable      # () -> classe base (0 DW, 1 DK, 2 Elf, 3 MG, 4 DL, 5 Summoner, 6 RF)
var aba := 0
var sub := ""                # janela de lado aberta: skill1, skill2, pocao, grupo ("" = fechada)
var lista_slot := -1         # quadro de skill com a coluna aberta (0 a 2 ataque, 3 a 5 buff)
var _areas: Array = []       # [Rect2, Callable]
var _lista_rects: Array = [] # [Rect2, numero] da coluna de skills
var _apertado := Rect2()
var _extra := -1             # linha escolhida na lista de itens extras
var _campos := {}            # nome -> LineEdit


func _ready() -> void:
	super._ready()
	for n in ["helper_opcao", "helper_menos", "helper_numero", "helper_texto", "helper_ajuste", "helper_bt",
			"cha_mais", "opc_check", "pet_aba", "skillbox", "skillbox_uso", "opc_vol_fundo", "opc_vol_cor"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	for i in 9:
		_tex["r%d" % i] = load(Inventario.PASTA + "crywolf/r%d.png" % i)
	# caixas de digitar do cliente: imagem branca e letra preta (SetBackColor 255 e SetTextColor 0)
	_novo_campo("longe", Rect2(140, 137, 20, 15), 2, true)
	_novo_campo("int1", Rect2(140, 174, 20, 15), 3, true)
	_novo_campo("int2", Rect2(140, 226, 20, 15), 3, true)
	_novo_campo("item", Rect2(34, 216, 94, 15), 14, false)
	_novo_campo("buff", Rect2(-L + 125, 93, 20, 15), 3, true)
	_campos.item.text_submitted.connect(func(_t): _adicionar_extra())


func _novo_campo(nome: String, r: Rect2, maximo: int, numero: bool) -> void:
	var e := LineEdit.new()
	e.position = r.position + Vector2(1, 0)
	e.size = r.size - Vector2(2, 0)
	e.custom_minimum_size = e.size
	e.max_length = maximo
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER if numero else HORIZONTAL_ALIGNMENT_LEFT
	e.add_theme_font_size_override("font_size", 9)
	e.add_theme_color_override("font_color", Color.BLACK)
	e.add_theme_color_override("caret_color", Color.BLACK)
	e.add_theme_color_override("selection_color", Color(0.5, 0.6, 0.9, 0.6))
	for st in ["normal", "focus", "read_only"]:
		var s := StyleBoxEmpty.new()
		s.content_margin_left = 1
		s.content_margin_right = 1
		e.add_theme_stylebox_override(st, s)
	e.visible = false
	if numero:
		e.text_changed.connect(func(t: String):
			var so := ""
			for ch in t:
				if ch >= "0" and ch <= "9":
					so += ch
			if so != t:
				e.text = so
				e.caret_column = so.length()
			_ler_campo(nome))
	add_child(e)
	_campos[nome] = e


func _ler_campo(nome: String) -> void:
	var v := int(_campos[nome].text)
	var c := helper.c
	match nome:
		"longe": c.segundos_longe = clampi(v, 0, 15)
		"int1": c.intervalo[1] = clampi(v, 0, 999)
		"int2": c.intervalo[2] = clampi(v, 0, 999)
		"buff": c.buff_intervalo = clampi(v, 0, 999)


func _encher_campos() -> void:
	var c := helper.c
	_campos.longe.text = str(c.segundos_longe)
	_campos.int1.text = str(c.intervalo[1])
	_campos.int2.text = str(c.intervalo[2])
	_campos.buff.text = str(c.buff_intervalo)


# na direita, como o inventario (o inventario fecha quando ela abre)
func _ajustar() -> void:
	super._ajustar()
	position.x = get_viewport_rect().size.x - L * _esc


func alternar() -> void:
	visible = not visible
	sub = ""
	lista_slot = -1
	_extra = -1
	if visible:
		_encher_campos()
	queue_redraw()


func _classe() -> int:
	return int(classe_de.call()) if classe_de.is_valid() else DK


# a janela de lado e a coluna de skills ficam fora do retangulo da janela, mas respondem ao mouse
func _has_point(p: Vector2) -> bool:
	if Rect2(0, 0, L, A).has_point(p):
		return true
	if sub != "" and Rect2(-L, 0, L, A).has_point(p):
		return true
	for e in _lista_rects:
		if e[0].has_point(p):
			return true
	return false


# --- desenho --------------------------------------------------------------------

func _draw() -> void:
	_areas.clear()
	var f := get_theme_default_font()
	var c := helper.c
	var k := _classe()
	_janela(0.0)
	_texto(f, Vector2(0, 22), DicaItem.t(3536), L, 10, BRANCO)
	_texto(f, Vector2(0.5, 22), DicaItem.t(3536), L, 10, BRANCO)
	# abas (CNewUIRadioGroupButton em 10,48 de 56 x 22; a escolhida e a metade de baixo)
	for i in 3:
		var r := Rect2(10 + 56 * i, 48, 56, 22)
		draw_texture_rect_region(_tex.pet_aba, r, Rect2(0, 22 * (1 if i == aba else 0), 56, 22))
		_texto(f, r.position + Vector2(0, 15), DicaItem.t([3500, 3501, 3590][i]), 56, TAM,
			BRANCO if i == aba else Color(0.7, 0.7, 0.7))
		_areas.append([r, func():
			aba = i
			lista_slot = -1])
	for n in ["longe", "int1", "int2", "item"]:
		_campos[n].visible = false
	_campos.buff.visible = false
	if aba == 0:
		_aba_caca(f, c, k)
	elif aba == 1:
		_aba_itens(f, c)
	else:
		_moldura(Rect2(12, 73, 165, 50))
		_moldura(Rect2(12, 120, 165, 222))
		_check(f, 18, 80, DicaItem.t(3591), c.amigo, func(): c.amigo = not c.amigo)
		_check(f, 18, 97, DicaItem.t(3592), c.guilda, func(): c.guilda = not c.guilda)
		_check(f, 18, 125, DicaItem.t(3593), c.defesa, func(): c.defesa = not c.defesa)
	if aba != 0:
		_moldura(Rect2(12, 340, 165, 46))
		_texto(f, Vector2(20, 356), DicaItem.t(3537), 150, TAM, BRANCO, HORIZONTAL_ALIGNMENT_LEFT)
		_texto(f, Vector2(20, 374), DicaItem.t(3538), 150, TAM, OURO, HORIZONTAL_ALIGNMENT_LEFT)
	_areas.append([Rect2(169, 7, 13, 12), func(): fechar.emit()])
	# rodape: fechar, Initialization e Save Setting
	_sair(Rect2(20, 388, 36, 29), func(): fechar.emit())
	_bt(f, "helper_bt", Rect2(65, 388, 52, 26), DicaItem.t(3504), func():
		helper.c = MuHelper.padrao()
		_padrao_skills()
		_encher_campos())
	_bt(f, "helper_bt", Rect2(120, 388, 52, 26), DicaItem.t(3503), func():
		for n in ["longe", "int1", "int2", "buff"]:
			_ler_campo(n)
		salvar.emit(helper.serializar()))
	if sub != "":
		_janela_lado(f, c, k)
	_lista_rects.clear()
	if lista_slot >= 0:
		_coluna_skills()


func _janela(x: float) -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(x, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(x, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(x, 64, 21, A - 64 - 45), false)
	draw_texture_rect(_tex.inv_dir, Rect2(x + L - 21, 64, 21, A - 64 - 45), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(x, A - 45, 190, 45), false)


func _aba_caca(f: Font, c: Dictionary, k: int) -> void:
	_moldura(Rect2(12, 73, 68, 50))
	_moldura(Rect2(75, 73, 102, 50))
	_moldura(Rect2(12, 120, 165, 39))
	_moldura(Rect2(12, 156, 165, 135))
	_moldura(Rect2(12, 288, 165, 69))
	_alcance(f, "caca", 0)
	# recuperacao: pocao pra todos; Elf tem Auto Heal e Summoner Drain Life embaixo
	_check(f, 79, 80, DicaItem.t(3507), c.pocao, func(): c.pocao = not c.pocao)
	if k == ELF:
		_check(f, 79, 97, DicaItem.t(3516), c.cura, func(): c.cura = not c.cura)
	elif k == SUM:
		_check(f, 79, 97, DicaItem.t(3517), c.drenar, func(): c.drenar = not c.drenar)
	_ajuste(f, Rect2(132, 79 if k == SUM else 84, 38, 24), "pocao")
	_check(f, 18, 122, DicaItem.t(3508), c.contra_longe, func(): c.contra_longe = not c.contra_longe)
	_check(f, 18, 137, DicaItem.t(3509), c.voltar, func(): c.voltar = not c.voltar)
	_linha(f, 110, 141, DicaItem.t(3527))
	_campo_em("longe", Rect2(140, 137, 20, 15))
	_linha(f, 162, 141, "s")
	# skills
	_linha(f, 18, 160, DicaItem.t(3529))
	_quadro(0, Vector2(17, 171))
	_linha(f, 59, 160, DicaItem.t(3530))
	_quadro(1, Vector2(61, 171))
	_skill_ativa(f, c, 1, 174)
	if k != DL:
		_linha(f, 59, 212, DicaItem.t(3531))
		_quadro(2, Vector2(61, 222))
		_skill_ativa(f, c, 2, 226)
	if k == DK:
		_check(f, 18, 226, DicaItem.t(3512), c.combo, func(): c.combo = not c.combo)
	elif k == DW or k == ELF:
		_check(f, 18, 218, DicaItem.t(3515), c.grupo, func(): c.grupo = not c.grupo)
		_ajuste(f, Rect2(17, 234, 38, 24), "grupo")
	elif k == DL:
		_check(f, 18, 218, DicaItem.t(3514), c.corvo, func(): c.corvo = not c.corvo)
		for m in [[1, 30, 235, 3534], [0, 94, 235, 3533], [2, 30, 250, 3535]]:
			_radio(f, m[1], m[2], DicaItem.t(m[3]), c.corvo_modo == m[0], func(): c.corvo_modo = m[0])
	_check(f, 18, 266, "Basic Attack Fallback", c.golpe_comum, func(): c.golpe_comum = not c.golpe_comum)
	# buffs
	_check(f, 18, 291, DicaItem.t(3513), c.buff_duracao, func(): c.buff_duracao = not c.buff_duracao)
	for i in 3:
		_quadro(3 + i, Vector2(21 + 34 * i, 308))


# Delay e Con da skill 2 ou 3 (um tira o outro) e o Setting que abre a condicao do lado
func _skill_ativa(f: Font, c: Dictionary, i: int, y: float) -> void:
	_check(f, 94, y, DicaItem.t(3510), c.por_tempo[i], func():
		c.por_tempo[i] = not c.por_tempo[i]
		if c.por_tempo[i]:
			c.por_condicao[i] = false
			if sub == "skill%d" % i:
				sub = "")
	_campo_em("int%d" % i, Rect2(140, y, 20, 15))
	_linha(f, 162, y + 4, "s")
	_check(f, 94, y + 17, DicaItem.t(3511), c.por_condicao[i], func():
		c.por_condicao[i] = not c.por_condicao[i]
		if c.por_condicao[i]:
			c.por_tempo[i] = false
		elif sub == "skill%d" % i:
			sub = "")
	_ajuste(f, Rect2(132, y + 17, 38, 24), "skill%d" % i, func():
		c.por_tempo[i] = false
		c.por_condicao[i] = true)


func _aba_itens(f: Font, c: Dictionary) -> void:
	_moldura(Rect2(12, 73, 68, 50))
	_moldura(Rect2(75, 73, 102, 50))
	_moldura(Rect2(12, 120, 165, 30))
	_moldura(Rect2(12, 147, 165, 195))
	_moldura(Rect2(16, 235, 158, 75))
	_alcance(f, "pegar", 1)
	_check(f, 79, 80, DicaItem.t(3518), c.reparar, func(): c.reparar = not c.reparar)
	_check(f, 17, 125, DicaItem.t(3519), c.pegar_tudo, func():
		c.pegar_tudo = not c.pegar_tudo
		if c.pegar_tudo:
			c.pegar_escolhidos = false)
	_check(f, 17, 152, DicaItem.t(3520), c.pegar_escolhidos, func():
		c.pegar_escolhidos = not c.pegar_escolhidos
		if c.pegar_escolhidos:
			c.pegar_tudo = false)
	for o in [[22, 170, 3521, "joia"], [85, 170, 3522, "set"], [22, 185, 3523, "zen"], [85, 185, 3524, "exc"],
			[22, 200, 3525, "extra"]]:
		var chave: String = o[3]
		_check(f, o[0], o[1], DicaItem.t(o[2]), c[chave], func(): c[chave] = not c[chave])
	_campo_em("item", Rect2(34, 216, 94, 15))
	_bt(f, "helper_ajuste", Rect2(132, 208, 38, 24), DicaItem.t(3505), _adicionar_extra)
	# lista dos nomes (CUIExtraItemListBox de 160 x 70 em 20,238)
	for i in mini(c.extras.size(), 5):
		var r := Rect2(20, 239 + 14 * i, 150, 14)
		if i == _extra:
			draw_rect(r, Color(0.35, 0.3, 0.2, 0.8))
		_texto(f, r.position + Vector2(3, 10), c.extras[i], r.size.x - 6, TAM, BRANCO, HORIZONTAL_ALIGNMENT_LEFT)
		_areas.append([r, func(): _extra = i])
	if c.extras.size() > 5:
		_texto(f, Vector2(20, 306), "+%d" % (c.extras.size() - 5), 150, 8, Color(0.7, 0.7, 0.7), HORIZONTAL_ALIGNMENT_RIGHT)
	_bt(f, "helper_ajuste", Rect2(132, 309, 38, 24), DicaItem.t(3506), func():
		if _extra >= 0 and _extra < c.extras.size():
			c.extras.remove_at(_extra)
		_extra = -1)


# Range, a linha embaixo, o numero do icon_Rank e o + e o - ao lado
func _alcance(f: Font, chave: String, _a: int) -> void:
	_linha(f, 18, 78, DicaItem.t(3526))
	_linha(f, 18, 83, "________")
	var v: int = clampi(int(helper.c[chave]), 0, 8)
	draw_texture_rect(_tex["r%d" % v], Rect2(29, 92, 15, 19), false)
	_bt_2(Rect2(56, 78, 16, 15), "cha_mais", func(): helper.c[chave] = clampi(int(helper.c[chave]) + 1, 1, 8))
	_bt_2(Rect2(56, 97, 16, 15), "helper_menos", func(): helper.c[chave] = clampi(int(helper.c[chave]) - 1, 1, 8))


# --- janela de lado (CNewUIMuHelperExt) ------------------------------------------

func _janela_lado(f: Font, c: Dictionary, k: int) -> void:
	var x := -L
	_janela(x)
	var titulo := 0
	if sub.begins_with("skill"):
		titulo = 3552
		var i := int(sub.substr(5))
		_painel(f, x + 12, 55, 165, 45, DicaItem.t(3543))
		_radio(f, x + 17, 78, DicaItem.t(3555), not c.atacando[i], func(): c.atacando[i] = false)
		_radio(f, x + 17, 93, DicaItem.t(3556), c.atacando[i], func(): c.atacando[i] = true)
		_painel(f, x + 12, 120, 165, 45, DicaItem.t(3544))
		for q in 4:
			_radio(f, x + 17 + 78 * (q / 2), 143 + 15 * (q % 2), DicaItem.t(3557 + q), c.quantos[i] == q,
				func(): c.quantos[i] = q, 78.0)
	elif sub == "pocao":
		titulo = 3553
		_painel(f, x + 12, 55, 165, 45, DicaItem.t(3545))
		_barra(f, x + 32, 80, "pocao_pct", DicaItem.t(3547))
		if k == ELF or k == SUM:
			_painel(f, x + 12, 120, 165, 45, DicaItem.t(3546 if k == ELF else 3517))
			_barra(f, x + 32, 145, "cura_pct" if k == ELF else "drenar_pct", DicaItem.t(3547))
	elif sub == "grupo":
		titulo = 3554
		var y := 55.0
		if k == ELF:
			_painel(f, x + 12, 55, 165, 70, DicaItem.t(3548))
			_check(f, x + 17, 78, DicaItem.t(3539), c.cura_grupo, func(): c.cura_grupo = not c.cura_grupo)
			_barra(f, x + 32, 100, "grupo_pct", DicaItem.t(3550))
			y = 145.0
		_painel(f, x + 12, y, 165, 45, DicaItem.t(3549))
		_check(f, x + 17, y + 23, DicaItem.t(3540), c.buff_grupo, func(): c.buff_grupo = not c.buff_grupo)
		_texto(f, Vector2(x + 40, y + 51), DicaItem.t(3551), 84, TAM, BRANCO, HORIZONTAL_ALIGNMENT_LEFT)
		_campo_em("buff", Rect2(x + 125, y + 38, 20, 15))
		_linha(f, x + 146, y + 42, "s")
	_texto(f, Vector2(x, 22), DicaItem.t(titulo), L, 10, BRANCO)
	_texto(f, Vector2(x + 0.5, 22), DicaItem.t(titulo), L, 10, BRANCO)
	_sair(Rect2(x + 20, 388, 36, 29), func(): sub = "")
	_areas.append([Rect2(x + 169, 7, 13, 12), func(): sub = ""])
	_bt(f, "helper_bt", Rect2(x + 65, 388, 52, 26), DicaItem.t(3504), func(): _padrao_lado())
	_bt(f, "helper_bt", Rect2(x + 120, 388, 52, 26), DicaItem.t(3503), func():
		_ler_campo("buff")
		sub = "")


func _padrao_lado() -> void:
	var p := MuHelper.padrao()
	var c := helper.c
	if sub.begins_with("skill"):
		var i := int(sub.substr(5))
		c.atacando[i] = p.atacando[i]
		c.quantos[i] = p.quantos[i]
	elif sub == "pocao":
		for n in ["pocao_pct", "cura_pct", "drenar_pct"]:
			c[n] = p[n]
	else:
		for n in ["cura_grupo", "grupo_pct", "buff_grupo", "buff_intervalo"]:
			c[n] = p[n]
		_campos.buff.text = str(c.buff_intervalo)


# RenderBackPane: aba do titulo de 65 colada na caixa
func _painel(f: Font, x: float, y: float, w: float, h: float, titulo: String) -> void:
	draw_rect(Rect2(x + 3, y + 2, 65 - 7, 18), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(x + 3, y + 20, w - 7, h - 7), Color(0, 0, 0, 0.4))
	draw_texture_rect(_tex.tab_ce, Rect2(x, y, 14, 14), false)
	draw_texture_rect(_tex.tab_cd, Rect2(x + 65 - 14, y, 14, 14), false)
	draw_texture_rect(_tex.tab_c, Rect2(x + 6, y, 65 - 12, 14), false)
	draw_texture_rect(_tex.tab_d, Rect2(x + 65 - 14, y + 6, 14, 14), false)
	draw_texture_rect(_tex.tab_cd, Rect2(x + w - 14, y + 18, 14, 14), false)
	draw_texture_rect(_tex.tab_be, Rect2(x, y + h + 18 - 14, 14, 14), false)
	draw_texture_rect(_tex.tab_bd, Rect2(x + w - 14, y + h + 18 - 14, 14, 14), false)
	draw_texture_rect(_tex.tab_c, Rect2(x + 2 + 65 - 14, y + 18, w - 12 - 65 + 14, 14), false)
	draw_texture_rect(_tex.tab_d, Rect2(x + w - 14, y + 24, 14, h - 14), false)
	draw_texture_rect(_tex.tab_b, Rect2(x + 6, y + h + 18 - 14, w - 12, 14), false)
	draw_texture_rect(_tex.tab_e, Rect2(x, y + 6, 14, h), false)
	_texto(f, Vector2(x + 10, y + 15), titulo, 60, TAM, BRANCO, HORIZONTAL_ALIGNMENT_LEFT)


# RenderHpLevel: a barra de volume do Option em 10 passos, o texto embaixo
func _barra(f: Font, x: float, y: float, chave: String, rotulo: String) -> void:
	var r := Rect2(x, y, 124, 16)
	draw_texture_rect(_tex.opc_vol_fundo, r, false)
	var n := clampi(int(helper.c[chave]) / 10, 0, 10)
	if n > 0:
		draw_texture_rect_region(_tex.opc_vol_cor, Rect2(x, y, 12.4 * n, 16), Rect2(0, 0, 12.4 * n, 16))
	_texto(f, Vector2(x, y + 28), rotulo, 124, TAM, BRANCO)
	_areas.append([r, func(): helper.c[chave] = clampi(int(ceil((_mouse.x - x) / 12.4)), 1, 10) * 10])


# --- coluna de skills (CNewUIMuHelperSkillList) ---------------------------------

func _quadro(slot: int, p: Vector2) -> void:
	var r := Rect2(p, Vector2(L_SKILL, A_SKILL))
	draw_texture_rect(_tex.skillbox_uso if slot == lista_slot else _tex.skillbox, r, false)
	var n := _skill_do_quadro(slot)
	if n > 0 and icone_de.is_valid():
		var ic: Array = icone_de.call(n)
		draw_texture_rect_region(ic[0], Rect2(p + Vector2(6, 5), Vector2(20, 28)), ic[1])
	_areas.append([r, func(): lista_slot = -1 if lista_slot == slot else slot])


func _skill_do_quadro(slot: int) -> int:
	return int(helper.c.skills[slot]) if slot < 3 else int(helper.c.buffs[slot - 3])


func _coluna_skills() -> void:
	var buff := lista_slot >= 3
	var tipos := [10] if buff else [0, 3, 4, 5]
	var l := []
	for n in skills_de.call():
		if n not in l and int(info_de.call(n)[2]) in tipos:
			l.append(n)
	var y0 := 293.0 if buff else 171.0
	var por_coluna := 5 if buff else 10
	for i in l.size():
		var col := i / por_coluna
		var linha := i % por_coluna
		var desvio := (linha + 1) / 2
		var y := y0 - desvio * A_SKILL if linha % 2 == 0 else y0 + desvio * A_SKILL
		var r := Rect2(-L_SKILL - col * L_SKILL, y, L_SKILL, A_SKILL)
		draw_texture_rect(_tex.skillbox, r, false)
		if icone_de.is_valid():
			var ic: Array = icone_de.call(l[i])
			draw_texture_rect_region(ic[0], Rect2(r.position + Vector2(6, 5), Vector2(20, 28)), ic[1])
		if r.has_point(_mouse):
			draw_rect(r.grow(-1), Color(1, 0.85, 0.4, 0.8), false, 1.0)
		_lista_rects.append([r, l[i]])


func _escolher(n: int) -> void:
	if lista_slot < 3:
		helper.c.skills[lista_slot] = n
	else:
		helper.c.buffs[lista_slot - 3] = n
	lista_slot = -1


# --- pecas ----------------------------------------------------------------------

func _linha(f: Font, x: float, y: float, t: String) -> void:
	_texto(f, Vector2(x, y + 9), t, -1, TAM, BRANCO, HORIZONTAL_ALIGNMENT_LEFT)


# caixa de marcar do Option (15 x 15, marcada em cima) com o texto ao lado
func _check(f: Font, x: float, y: float, rotulo: String, ligado: bool, ao_clicar: Callable, largura := 160.0) -> void:
	draw_texture_rect_region(_tex.opc_check, Rect2(x, y, 15, 15), Rect2(0, 0 if ligado else 15, 15, 15))
	_rotulo(f, x, y, rotulo, largura, ao_clicar)


# bolinha do MacroUI_OptionButton (uma escolha do grupo)
func _radio(f: Font, x: float, y: float, rotulo: String, ligado: bool, ao_clicar: Callable, largura := 160.0) -> void:
	draw_texture_rect_region(_tex.helper_opcao, Rect2(x, y, 15, 15), Rect2(0, 0 if ligado else 16, 16, 16))
	_rotulo(f, x, y, rotulo, largura, ao_clicar)


# texto ao lado da caixa (ate a largura dada, a letra encolhe pra caber) e a area do clique
func _rotulo(f: Font, x: float, y: float, rotulo: String, largura: float, ao_clicar: Callable) -> void:
	var tam := TAM
	while tam > 7 and f.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > largura - 17:
		tam -= 1
	_texto(f, Vector2(x + 16, y + 11), rotulo, -1, tam, BRANCO, HORIZONTAL_ALIGNMENT_LEFT)
	var w := f.get_string_size(rotulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 17
	_areas.append([Rect2(x, y, w, 15), ao_clicar])


# botao de 3 estados (normal, mouse em cima, apertado) com o texto no meio
func _bt(f: Font, tex: String, r: Rect2, rotulo: String, ao_clicar: Callable) -> void:
	var t: Texture2D = _tex[tex]
	var e := 2 if _apertado == r else (1 if r.has_point(_mouse) else 0)
	draw_texture_rect_region(t, r, Rect2(0, r.size.y * e, t.get_width(), r.size.y))
	_texto(f, r.position + Vector2(0, r.size.y / 2 + 3), rotulo, r.size.x, TAM, BRANCO)
	_areas.append([r, ao_clicar])


func _ajuste(f: Font, r: Rect2, pagina: String, antes := Callable()) -> void:
	_bt(f, "helper_ajuste", r, DicaItem.t(3502), func():
		if antes.is_valid():
			antes.call()
		sub = "" if sub == pagina else pagina
		if sub == "grupo":
			_campos.buff.text = str(helper.c.buff_intervalo))


# + e - do alcance (2 estados: solto em cima, apertado embaixo)
func _bt_2(r: Rect2, tex: String, ao_clicar: Callable) -> void:
	draw_texture_rect_region(_tex[tex], r, Rect2(0, 15 if _apertado == r else 0, 16, 15))
	_areas.append([r, ao_clicar])


func _sair(r: Rect2, ao_clicar: Callable) -> void:
	draw_texture_rect_region(_tex.inv_sair, r, Rect2(0, 29 if r.has_point(_mouse) else 0, 36, 29))
	_areas.append([r, ao_clicar])


func _campo_em(nome: String, r: Rect2) -> void:
	draw_texture_rect(_tex.helper_texto if nome == "item" else _tex.helper_numero, r, false)
	var e: LineEdit = _campos[nome]
	e.position = r.position + Vector2(1, 0)
	e.visible = true


func _padrao_skills() -> void:
	var l: Array = skills_de.call()
	for n in l:
		if int(info_de.call(n)[2]) in [0, 3, 4, 5]:
			helper.c.skills[0] = n
			return


func _adicionar_extra() -> void:
	var t: String = _campos.item.text.strip_edges()
	if t != "" and helper.c.extras.size() < 12 and t not in helper.c.extras:
		helper.c.extras.append(t)
	_campos.item.text = ""
	queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		if ev.pressed:
			_apertado = Rect2()
			for a in _areas:
				if a[0].has_point(ev.position):
					_apertado = a[0]
					break
			for e in _campos.values():
				if e.has_focus():
					e.release_focus()
		else:
			var feito := false
			for e in _lista_rects:
				if e[0].has_point(ev.position):
					_escolher(e[1])
					feito = true
					break
			if not feito:
				for a in _areas:
					if a[0].has_point(ev.position) and a[0] == _apertado:
						a[1].call()
						break
			_apertado = Rect2()
		queue_redraw()
		accept_event()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		# botao direito no quadro esvazia a skill (e o Combo cai, como no cliente)
		for s in 6:
			var p: Vector2 = [Vector2(17, 171), Vector2(61, 171), Vector2(61, 222), Vector2(21, 308),
				Vector2(55, 308), Vector2(89, 308)][s]
			if aba == 0 and Rect2(p, Vector2(L_SKILL, A_SKILL)).has_point(ev.position):
				if s < 3:
					helper.c.skills[s] = 0
				else:
					helper.c.buffs[s - 3] = 0
				helper.c.combo = false
		queue_redraw()
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()
