class_name JanelaPersonagem
extends Control
# Janela do personagem do MU S6 (CNewUICharacterInfoWindow, tecla C): 190 x 429 na tela de 640,
# colada na direita (ou do lado do inventario, se ele estiver aberto). Nome e classe no topo,
# quadro com nivel, pontos e experiencia, e uma caixa por atributo (STR, AGI, STA, ENG e, no
# Dark Lord, Command) com os numeros que o cliente calcula embaixo. Com ponto sobrando, cada
# caixa ganha o botao + que pede ao servidor 1 ponto naquele atributo (C1 F3 06).

signal abrir_quests                # o botao de quest abre a janela T
signal adicionar(atributo: int)   # 0 forca, 1 agilidade, 2 vitalidade, 3 energia, 4 comando

const PASTA := "res://dados/hud/"
const L := 190.0
const A := 429.0
const ALTURAS := [120, 175, 240, 295, 350]     # HEIGHT_STRENGTH ... HEIGHT_CHARISMA
const NOMES_CLASSE := ["Dark Wizard", "Dark Knight", "Fairy Elf", "Magic Gladiator", "Dark Lord", "Summoner", "Rage Fighter"]
const AMARELO := Color8(230, 230, 0)
const LARANJA := Color8(255, 138, 0)
const AZUL := Color8(76, 197, 254)

var eu := {}            # nome, classe, nivel, pontos, exp, exp_prox, forca, agilidade, vitalidade, energia,
                        # comando, vida, vida_max, mana, mana_max
var equip := {}         # slot -> item (sem inventario, nos testes)
var inventario: Control # pra ficar do lado dele quando os dois estao abertos
var esperando := false  # mandei o ponto e o servidor ainda nao respondeu
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)
var _apertado := -1


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "tab_ce", "tab_cd", "tab_be",
			"tab_bd", "tab_c", "tab_b", "tab_e", "tab_d", "cha_caixa", "cha_mais", "cha_quest", "cha_pet", "cha_master"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


func _ajustar() -> void:
	var v := get_viewport_rect().size
	var barra := 51.0 * v.x / 640.0
	_esc = minf(v.x / 640.0, (v.y - barra) / A)
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	var lado := 2.0 if inventario and inventario.visible else 1.0
	position = Vector2(v.x - L * _esc * lado, 0)
	queue_redraw()


func alternar() -> void:
	visible = not visible
	_ajustar()
	print("TESTE janela C aberta %s em %s escala %s pontos %s" % [visible, global_position, _esc, eu.get("pontos")])


func classe_base() -> int:
	return clampi(int(eu.get("classe", 0)) >> 2, 0, 6)


# --- contas do cliente (CHARACTER_MACHINE em ZzzInfomation.cpp) -----------------

func _equip() -> Dictionary:
	return inventario.itens if inventario and "itens" in inventario else equip


func _arma() -> Array:
	var a := [0, 0, 0]   # dano min, dano max, velocidade
	for s in [0, 1]:
		if _equip().has(s):
			var n := DicaItem.numeros(_equip()[s])
			if n.dano_max > a[1]:
				a[0] = n.dano_min
				a[1] = n.dano_max
			var p: Dictionary = DicaItem._bmd.get(ItensMU.chave(_equip()[s]), {})
			a[2] = maxi(a[2], int(p.get("velocidade", 0)))
	return a


func _arco() -> bool:
	for s in [0, 1]:
		if _equip().has(s) and int(_equip()[s].grupo) == 4 and int(_equip()[s].numero) not in [7, 15]:
			return true   # arco ou besta (a flecha e a virote nao contam)
	return false


func dano() -> Vector2i:
	var f: int = eu.get("forca", 0)
	var g: int = eu.get("agilidade", 0)
	var e: int = eu.get("energia", 0)
	var v: int = eu.get("vitalidade", 0)
	var r: Vector2i
	if _arco():
		r = Vector2i(g / 7 + f / 14, g / 4 + f / 8)
	else:
		match classe_base():
			2, 5: r = Vector2i((f + g) / 7, (f + g) / 4)
			1: r = Vector2i(f / 6, f / 4)
			3: r = Vector2i(f / 6 + e / 12, f / 4 + e / 9)
			4: r = Vector2i(f / 7 + e / 14, f / 5 + e / 10)
			6: r = Vector2i(f / 7 + v / 15, f / 5 + v / 12)
			_: r = Vector2i(f / 8, f / 4)
	var a := _arma()
	return r + Vector2i(a[0], a[1])


func taxa_ataque() -> int:
	var n: int = eu.get("nivel", 1)
	var f: int = eu.get("forca", 0)
	var g: int = eu.get("agilidade", 0)
	match classe_base():
		4: return n * 5 + g * 5 / 2 + f / 6 + int(eu.get("comando", 0)) / 10
		6: return n * 3 + g * 5 / 4 + f / 6
	return n * 5 + g * 3 / 2 + f / 4


func defesa() -> int:
	var g: int = eu.get("agilidade", 0)
	var d: int
	match classe_base():
		2: d = g / 10
		1, 5: d = g / 3
		0: d = g / 4
		4: d = g / 7
		6: d = g / 8
		_: d = g / 5
	for s in range(1, 8):
		if _equip().has(s):
			d += DicaItem.numeros(_equip()[s]).defesa
	return d


func taxa_defesa() -> int:
	var g: int = eu.get("agilidade", 0)
	match classe_base():
		2, 5: return g / 4
		4: return g / 7
		6: return g / 10
	return g / 3


func velocidade() -> int:
	var g: int = eu.get("agilidade", 0)
	var por: int = [10, 15, 50, 15, 10, 20, 9][classe_base()]
	return g / por + _arma()[2]


# --- desenho -----------------------------------------------------------------------

func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, 320), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	var c := classe_base()
	_texto(f, Vector2(0, 21), str(eu.get("nome", "")), L, 11, Color8(200, 220, 255), true)
	_texto(f, Vector2(0, 36), "(%s)" % NOMES_CLASSE[c], L, 10, Color(1, 1, 1, 0.8))
	# quadro de cima
	draw_rect(Rect2(12, 48, 160, 66), Color(0, 0, 0, 0.5))
	_moldura(Rect2(12, 48, 165, 71))
	var pontos: int = eu.get("pontos", 0)
	_texto(f, Vector2(18, 67), DicaItem.t(200, [eu.get("nivel", 1)]), 0, 10, AMARELO, true, HORIZONTAL_ALIGNMENT_LEFT)
	if pontos > 0:
		_texto(f, Vector2(110, 67), DicaItem.t(217, [pontos]), 0, 10, LARANJA, true, HORIZONTAL_ALIGNMENT_LEFT)
	_texto(f, Vector2(18, 84), "Exp : %s/%s" % [eu.get("exp", 0), eu.get("exp_prox", 0)], 0, 9, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT)
	var falta: int = maxi(int(eu.get("exp_prox", 0)) - int(eu.get("exp", 0)), 0)
	_texto(f, Vector2(18, 97), "Falta pro nivel: %s" % ItemChao._milhar(falta), 0, 9, AZUL, false, HORIZONTAL_ALIGNMENT_LEFT)
	_texto(f, Vector2(18, 110), "Vida %d/%d  Mana %d/%d" % [eu.get("vida", 0), eu.get("vida_max", 0), eu.get("mana", 0), eu.get("mana_max", 0)],
		0, 9, AZUL, false, HORIZONTAL_ALIGNMENT_LEFT)
	# atributos
	var nomes := [DicaItem.t(166), DicaItem.t(167), DicaItem.t(169), DicaItem.t(168), DicaItem.t(1900)]
	var valores := [eu.get("forca", 0), eu.get("agilidade", 0), eu.get("vitalidade", 0), eu.get("energia", 0), eu.get("comando", 0)]
	for i in (5 if c == 4 else 4):
		var y: float = ALTURAS[i]
		draw_texture_rect(_tex.cha_caixa, Rect2(11, y, 170, 21), false)
		_texto(f, Vector2(12, y + 15), nomes[i], 74, 10, AMARELO, true)
		_texto(f, Vector2(86, y + 15), str(valores[i]), 86, 10, AMARELO, true)
		if pontos > 0:
			var r := Rect2(160, y + 2, 16, 15)
			var fr := 1 if _apertado == i or (r.has_point(_mouse) and esperando) else 0
			draw_texture_rect_region(_tex.cha_mais, r, Rect2(0, 15 * fr, 16, 15),
				Color(1, 1, 1, 0.5) if esperando else (Color(1.2, 1.2, 1.0) if r.has_point(_mouse) else Color.WHITE))
	var linhas := _linhas(c)
	for i in linhas.size():
		var y0: float = ALTURAS[i] + 34
		for j in linhas[i].size():
			_texto(f, Vector2(20, y0 + 13 * j), linhas[i][j], 0, 9, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT)
	# botoes de baixo: fechar, quest, pet, master
	var bx := [13, 50, 87, 124]
	var bt := ["inv_sair", "cha_quest", "cha_pet", "cha_master"]
	for i in 4:
		var r := Rect2(bx[i], 392, 36, 29)
		draw_texture_rect_region(_tex[bt[i]], r, Rect2(0, 29 * (1 if r.has_point(_mouse) else 0), 36, 29))
	if Rect2(13, 392, 36, 29).has_point(_mouse):
		_texto(f, Vector2(_mouse.x - 30, _mouse.y - 6), "Fechar (C)", 0, 9, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT)


func _linhas(c: int) -> Array:
	var d := dano()
	var forca := [DicaItem.t(203, [d.x, d.y, taxa_ataque()])]
	var agi := [DicaItem.t(208, [defesa(), taxa_defesa()]), DicaItem.t(64, [velocidade()])]
	var vit := [DicaItem.t(211, [eu.get("vida", 0), eu.get("vida_max", 0)])]
	var ene := [DicaItem.t(213, [eu.get("mana", 0), eu.get("mana_max", 0)])]
	var e: int = eu.get("energia", 0)
	if c in [0, 3, 5]:
		ene.append(DicaItem.t(216, [e / 9, e / 4]))
	match c:
		1: ene.append(DicaItem.t(582, [200 + e / 10]))
		3: ene.append(DicaItem.t(582, [200]))
		4: ene.append(DicaItem.t(582, [200 + e / 20]))
	return [forca, agi, vit, ene]


func _moldura(r: Rect2) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x - 14
	var y1 := r.end.y - 14
	draw_texture_rect(_tex.tab_c, Rect2(x0 + 14, y0, x1 - x0 - 14, 14), false)
	draw_texture_rect(_tex.tab_b, Rect2(x0 + 14, y1, x1 - x0 - 14, 14), false)
	draw_texture_rect(_tex.tab_e, Rect2(x0, y0 + 14, 14, y1 - y0 - 14), false)
	draw_texture_rect(_tex.tab_d, Rect2(x1, y0 + 14, 14, y1 - y0 - 14), false)
	draw_texture_rect(_tex.tab_ce, Rect2(x0, y0, 14, 14), false)
	draw_texture_rect(_tex.tab_cd, Rect2(x1, y0, 14, 14), false)
	draw_texture_rect(_tex.tab_be, Rect2(x0, y1, 14, 14), false)
	draw_texture_rect(_tex.tab_bd, Rect2(x1, y1, 14, 14), false)


func _texto(f: Font, p: Vector2, t: String, largura: float, tam: int, cor: Color, negrito := false,
		al := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := largura if largura > 0 else -1.0
	draw_string_outline(f, p, t, al, w, tam, 2, Color(0, 0, 0, 0.9))
	draw_string(f, p, t, al, w, tam, cor)
	if negrito:
		draw_string(f, p + Vector2(0.5, 0), t, al, w, tam, cor)


# --- mouse -----------------------------------------------------------------------

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		if ev.pressed:
			_clique(ev.position)
		else:
			_apertado = -1
		accept_event()
		queue_redraw()
	elif ev is InputEventMouseButton:
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		_apertado = -1
		queue_redraw()


func _clique(p: Vector2) -> void:
	if Rect2(13, 392, 36, 29).has_point(p) or Rect2(160, 2, 26, 22).has_point(p):
		alternar()
		return
	if Rect2(50, 392, 36, 29).has_point(p):
		alternar()
		abrir_quests.emit()
		return
	if int(eu.get("pontos", 0)) <= 0 or esperando:
		return
	for i in (5 if classe_base() == 4 else 4):
		if Rect2(160, ALTURAS[i] + 2, 16, 15).has_point(p):
			_apertado = i
			esperando = true
			adicionar.emit(i)
			_desistir()
			return


# o OpenMU so responde F3 06 quando aceita; quando recusa (sem pontos, atributo que a classe
# nao tem) manda so a mensagem azul. Sem resposta em 2 s, o + volta a funcionar.
func _desistir() -> void:
	await get_tree().create_timer(2.0).timeout
	if esperando:
		esperando = false
		queue_redraw()


# resposta do servidor (F3 06): soma 1 no atributo e tira 1 dos pontos
func resposta(ok: bool, atributo: int) -> void:
	esperando = false
	if ok:
		var k: String = ["forca", "agilidade", "vitalidade", "energia", "comando"][clampi(atributo, 0, 4)]
		eu[k] = int(eu.get(k, 0)) + 1
		eu.pontos = maxi(int(eu.get("pontos", 0)) - 1, 0)
	queue_redraw()
