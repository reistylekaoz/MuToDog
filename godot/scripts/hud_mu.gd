class_name HudMu
extends Control
# A barra de baixo do MU S6 (CNewUIMainFrameWindow do cliente), desenhada em
# coordenadas da tela de referencia 640x480 e esticada na largura da janela:
# moldura em 3 pecas, orbe de vida (x 158) e mana (x 437), SD (x 204) e AG (x 420)
# enchendo de baixo pra cima, numeros com a fonte do cliente, experiencia em 10
# partes (a barra enche a parte atual, o numero da direita diz em qual esta) e os
# botoes da direita. Passar o mouse mostra o valor, como no jogo.

signal botao(qual: String)
signal escolheu_skill(numero: int)
signal usar_atalho(i: int)

const PASTA := "res://dados/hud/"
const TOPO := 429.0            # onde a moldura comeca na tela de 480
const BOTOES := ["loja", "personagem", "inventario", "amigos", "menu"]
const DICAS := {"loja": "MU Item Shop (X)", "personagem": "Personagem (C)", "inventario": "Inventario (I, V)",
	"amigos": "Amigos (F)", "menu": "Menu (U)"}

var vida := 0
var vida_max := 1
var mana := 0
var mana_max := 1
var sd := 0
var sd_max := 1
var ag := 0
var ag_max := 1
var exp_atual := 0
var exp_antes := 0      # experiencia em que o nivel atual comecou
var exp_prox := 1
var veneno := false   # envenenado: o orbe de vida fica verde (IMAGE_GAUGE_GREEN)
var master := false   # classe master no 400: a barra mostra a exp master (Exbar_Master)

# skills (CNewUISkillList): atalhos 1..5 na barra, a atual no quadro verde,
# clique nele abre a lista de todas em cima da barra
var skills: Array = []          # numeros das skills que da pra usar
var atalhos: Array = []         # tecla 1..9,0 -> numero da skill (-1 = vazio)
var skill_atual := -1
var lista_aberta := false
var info_skills := {}
# pocoes (CNewUIItemHotKey): Q W E R -> [item ou {}, quantidade]
var pocoes: Array = [[{}, 0], [{}, 0], [{}, 0], [{}, 0]]
var _extra := 0.0               # quanto a barra sobe quando a lista de skills abre
# Hero->m_pPet: com o Dark Raven vestido as 4 ordens (120 a 123) ficam numa fileira em cima da lista
var comandos_pet := false:
	set(v):
		if v != comandos_pet:
			comandos_pet = v
			_ajustar()

var _tex := {}
var _mouse := Vector2(-1, -1)
var _apertado := ""
var _esc := 1.0
var _icones_master := {}   # skill master -> Magic_Icon (dados/master.json)


func _ready() -> void:
	for n in ["menu1", "menu2", "menu3", "orbe_red", "orbe_green", "orbe_blue", "orbe_sd", "orbe_ag", "exbar", "exbar_master", "numeros",
			"bt1", "bt2", "bt3", "bt4", "bt5", "skill1", "skill2", "skill3", "skillbox2", "skillbox_uso", "master_icones"]:
		_tex[n] = load(PASTA + n + ".png")
	if FileAccess.file_exists("res://dados/skills.json"):
		info_skills = JSON.parse_string(FileAccess.get_file_as_string("res://dados/skills.json"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


# a tela de 640 vira a largura da janela; a barra fica colada embaixo
func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	_extra = (39.0 if skills.size() <= 18 and not comandos_pet else 77.0) if lista_aberta else 0.0
	size = Vector2(640, 51 + _extra)
	position = Vector2(0, v.y - (51.0 + _extra) * _esc)
	queue_redraw()


# ponto da tela de referencia (640x480) -> ponto local deste Control
func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x, y - TOPO, w, h)


func _draw() -> void:
	draw_set_transform(Vector2(0, _extra))
	draw_texture(_tex.menu1, Vector2(0, 0))
	draw_texture(_tex.menu2, Vector2(256, 0))
	draw_texture(_tex.menu3, Vector2(384, 0))
	_orbe(_tex.orbe_green if veneno else _tex.orbe_red, 158, 432, 45, 39, vida, vida_max)
	_numero(158 + 25, 462, vida)
	_orbe(_tex.orbe_blue, 437, 432, 45, 39, mana, mana_max)
	_numero(437 + 30, 462, mana)
	_orbe(_tex.orbe_sd, 204, 431, 16, 39, sd, sd_max)
	_numero(204 + 15, 462, sd)
	_orbe(_tex.orbe_ag, 420, 431, 16, 39, ag, ag_max)
	_numero(420 + 10, 462, ag)
	# experiencia: 10 partes; a barra mostra quanto da parte atual ja foi
	var r := clampf(float(exp_atual - exp_antes) / maxf(exp_prox - exp_antes, 1), 0.0, 1.0)
	var parte := mini(int(r * 10.0), 9)
	var resto := 1.0 if r >= 1.0 else r * 10.0 - parte
	if resto > 0.0:
		draw_texture_rect(_tex.exbar_master if master else _tex.exbar, _r(2, 473, resto * 629.0, 4), false)
	_numero(635, 469, parte)
	for i in BOTOES.size():
		var q: Rect2 = _r(489 + 30 * i, TOPO, 30, 41)
		var linha := 0
		if _apertado == BOTOES[i] and q.has_point(_mouse):
			linha = 2
		elif q.has_point(_mouse):
			linha = 1
		var t: Texture2D = _tex["bt%d" % [5, 1, 2, 3, 4][i]]
		draw_texture_rect_region(t, q, Rect2(0, 41 * linha, 30, 41))
	# pocoes nas casas Q W E R
	for i in 4:
		if not pocoes[i][0].is_empty():
			ItensMU.desenhar(self, pocoes[i][0], _r(10 + i * 38, 443, 20, 20))
			_numero(30 + i * 38, 457, pocoes[i][1])
	# atalhos de skill 1..5 e a skill atual
	for i in 5:
		var n: int = atalhos[i] if i < atalhos.size() else -1
		if n < 0 or not usavel(n):
			continue
		var q := _r(222 + 32 * i, 431, 32, 38)
		if n == skill_atual:
			draw_texture_rect(_tex.skillbox_uso, q, false)
		_icone_skill(n, _r(228 + 32 * i, 437, 20, 28))
	if skill_atual >= 0:
		_icone_skill(skill_atual, _r(392, 437, 20, 28))
	if lista_aberta:
		for i in skills.size():
			var q := _caixa_lista(i)
			draw_texture_rect(_tex.skillbox_uso if skills[i] == skill_atual else _tex.skillbox2, q, false)
			_icone_skill(skills[i], Rect2(q.position + Vector2(6, 6), Vector2(20, 28)))
			var k := atalhos.find(skills[i])
			if k >= 0:
				_numero(q.position.x + 26, q.position.y + TOPO + 26, (k + 1) % 10)
		# RenderPetSkill: x 353, y 352
		if comandos_pet:
			for i in Pets.COMANDOS:
				var q := _caixa_pet(i)
				draw_texture_rect(_tex.skillbox_uso if Pets.COMANDO + i == skill_atual else _tex.skillbox2, q, false)
				_icone_skill(Pets.COMANDO + i, Rect2(q.position + Vector2(6, 6), Vector2(20, 28)))
				var k := atalhos.find(Pets.COMANDO + i)
				if k >= 0:
					_numero(q.position.x + 26, q.position.y + TOPO + 26, (k + 1) % 10)
	# dica em cima da barra (RenderTipText, y 418)
	var d := dica()
	if d != "":
		var f := get_theme_default_font()
		var tam := f.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		var x := clampf(_mouse.x - tam.x / 2.0, 2.0, 638.0 - tam.x)
		var dy := 418.0 - TOPO - (_extra if lista_aberta else 0.0)
		draw_rect(Rect2(x - 3, dy - 10, tam.x + 6, 13), Color(0, 0, 0, 0.75))
		draw_string(f, Vector2(x, dy), d, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1))


# orbe que enche de baixo pra cima (RenderLifeMana): a parte vazia some por cima
func _orbe(t: Texture2D, x: float, y: float, w: float, h: float, v: int, m: int) -> void:
	var falta := clampf(float(m - v) / maxf(m, 1), 0.0, 1.0)
	if falta >= 1.0:
		return
	draw_texture_rect_region(t, _r(x, y + falta * h, w, h - falta * h), Rect2(0, falta * h, w, h - falta * h))


# RenderNumber: digitos de 12x14 na tira newui_number1, centrados em x, passo 80%
func _numero(x: float, y: float, n: int) -> void:
	var s := str(maxi(n, 0))
	var w := 12.0 * 0.7
	var h := 16.0 * 0.7
	x -= w * s.length() / 2.0
	for c in s:
		var d := c.unicode_at(0) - 48
		draw_texture_rect_region(_tex.numeros, _r(x, y, w, h), Rect2(d * 12, 0, 12, 14))
		x += w * 0.8


# lista de skills: a mesma arrumacao do cliente (alterna direita e esquerda de x 385)
func _caixa_lista(i: int) -> Rect2:
	var x := 385.0
	var y := 390.0 - (38.0 if i >= 18 else 0.0)
	if i < 14:
		x = 385.0 + (i / 2) * 32 if i % 2 == 0 else 385.0 - (i / 2 + 1) * 32
	elif i < 18:
		x = 385.0 - 8 * 32 - (i - 14) * 32
	else:
		x = 385.0 - 12 * 32 + (i - 17) * 32
	return _r(x, y, 32, 38)


func _caixa_pet(i: int) -> Rect2:
	return _r(353.0 + 32.0 * i, 352.0, 32, 38)


# da pra usar agora: aprendida, ou ordem do corvo com o corvo vestido
func usavel(n: int) -> bool:
	return n in skills or (Pets.e_comando(n) and comandos_pet)


# icone da skill nas folhas newui_skill (20 x 28 cada), como o RenderSkillIcon
const ICONE_ESPECIAL := {232: [2, 7, 2], 238: [2, 3, 8], 234: [2, 9, 2], 235: [2, 0, 8], 236: [2, 1, 8],
	237: [2, 2, 8], 230: [2, 2, 3], 233: [2, 8, 2], 225: [2, 11, 3],
	76: [3, 4, 0]}   # 76 Plasma Storm (Fenrir): newui_command


func _icone_skill(n: int, r: Rect2) -> void:
	# skill master (300+): folha da arvore (new_Master_Icon) pelo Magic_Icon do skill_eng
	if n >= JanelaMaster.SKILL_MASTER:
		if _icones_master.is_empty():
			var d := ItensMU._json("res://dados/master.json")
			for k in d.get("skills", {}):
				_icones_master[int(k)] = int(d.skills[k][2])
		var ic: int = _icones_master.get(n, 0)
		draw_texture_rect_region(_tex.master_icones, r, Rect2((ic % 25) * 20, (ic / 25) * 28, 20, 28))
		return
	var c: Array
	if Pets.e_comando(n):
		c = [3, n - Pets.COMANDO, 0]   # newui_command, um ao lado do outro
	elif ICONE_ESPECIAL.has(n):
		c = ICONE_ESPECIAL[n]
	elif n in [221, 222]:
		c = [2, n - 221 + 8, 3]
	elif n in [223, 224]:
		c = [2, (n - 223 + 6) % 8, 3]
	elif n >= 57:
		c = [2, (n - 57) % 8, (n - 57) / 8]
	else:
		c = [1, (n - 1) % 8, (n - 1) / 8]
	draw_texture_rect_region(_tex["skill%d" % c[0]], r, Rect2(c[1] * 20, c[2] * 28, 20, 28))


func nome_skill(n: int) -> String:
	if Pets.e_comando(n):
		return Pets.dica_comando(n)
	var i: Array = info_skills.get(str(n), ["Skill %d" % n, 0, 0, 0, 0, 0])
	var t: String = i[0]
	if i[4] > 0:
		t += "  ·  mana %d" % i[4]
	if i[5] > 0:
		t += "  ·  AG %d" % i[5]
	return t


func _skill_em(p: Vector2) -> int:
	if lista_aberta:
		for i in skills.size():
			if _caixa_lista(i).has_point(p):
				return skills[i]
		if comandos_pet:
			for i in Pets.COMANDOS:
				if _caixa_pet(i).has_point(p):
					return Pets.COMANDO + i
	for i in 5:
		if i < atalhos.size() and usavel(atalhos[i]) and _r(222 + 32 * i, 431, 32, 38).has_point(p):
			return atalhos[i]
	return -1


func skill_sob_mouse() -> int:
	return _skill_em(_mouse)


func dica() -> String:
	var p := _mouse
	var sk := _skill_em(p)
	if sk >= 0:
		return nome_skill(sk) + ("  (numero no teclado: atalho)" if lista_aberta else "")
	if _r(392, 437, 20, 28).has_point(p):
		return (nome_skill(skill_atual) + "  ·  " if skill_atual >= 0 else "") + "clique: todas as skills"
	for i in 4:
		if _r(10 + i * 38, 443, 20, 20).has_point(p) and not pocoes[i][0].is_empty():
			return "%s (%s)" % [ItensMU.nome(pocoes[i][0]), "QWER"[i]]
	if _r(158, 432, 45, 39).has_point(p):
		return "Vida %d / %d" % [vida, vida_max]
	if _r(437, 432, 45, 39).has_point(p):
		return "Mana %d / %d" % [mana, mana_max]
	if _r(204, 431, 16, 39).has_point(p):
		return "SD %d / %d" % [sd, sd_max]
	if _r(420, 431, 16, 39).has_point(p):
		return "AG %d / %d" % [ag, ag_max]
	if _r(2, 470, 629, 10).has_point(p):
		return "%s %s / %s" % ["Master Exp" if master else "Exp", ItemChao._milhar(exp_atual), ItemChao._milhar(exp_prox)]
	var b := _botao_em(p)
	return DICAS.get(b, "")


func _botao_em(p: Vector2) -> String:
	for i in BOTOES.size():
		if _r(489 + 30 * i, TOPO, 30, 41).has_point(p):
			return BOTOES[i]
	return ""


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position - Vector2(0, _extra)
		queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		_mouse = ev.position - Vector2(0, _extra)
		for i in 4:
			if _r(10 + i * 38, 443, 20, 20).has_point(_mouse):
				usar_atalho.emit(i)
		accept_event()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position - Vector2(0, _extra)
		if ev.pressed:
			var sk := _skill_em(_mouse)
			if sk >= 0:
				escolheu_skill.emit(sk)
				if lista_aberta:
					lista_aberta = false
					_ajustar()
				accept_event()
				return
			if _r(386, 431, 32, 40).has_point(_mouse):
				lista_aberta = not lista_aberta
				_ajustar()
				accept_event()
				return
		if ev.pressed:
			_apertado = _botao_em(_mouse)
		else:
			var b := _botao_em(_mouse)
			if b != "" and b == _apertado:
				botao.emit(b)
			_apertado = ""
		queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-1, -1)
		_apertado = ""
		queue_redraw()


func atualizar() -> void:
	queue_redraw()


func fechar_lista() -> void:
	if lista_aberta:
		lista_aberta = false
		_ajustar()
