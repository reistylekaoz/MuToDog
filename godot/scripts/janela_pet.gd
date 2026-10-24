class_name JanelaPet
extends Control
# Janela do pet do cliente S6 (CNewUIPetInfoWindow), 190x429, aberta pelo botao Pet da janela C: fica a esquerda
# dela no lugar da mochila. Duas abas (Dark Horse e Dark Raven) com a ficha do pet vestido (Pets.vestidos, do C1 A9):
# nivel, vida em barra, exp, dano e velocidade; o corvo ainda mostra o carisma pedido e as 4 ordens.
# O dano soma o que o cliente soma (CalcDamage): o Earthshake no cavalo e o % do cetro da mao direita no corvo.

const PASTA := "res://dados/hud/"
const L := 190.0
const A := 429.0
const CAVALO := 0
const CORVO := 1
const TERREMOTO := [150, 225]   # GetSkillDamage(AT_SKILL_EARTHSHAKE): 150 de dano, maximo = min + min / 2

var aba := CAVALO
var inventario: Control          # a mochila: a mao direita (slot 0) da o % do cetro
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


func _ready() -> void:
	for n in ["inv_fundo", "inv_topo", "inv_esq", "inv_dir", "inv_baixo", "inv_sair", "pet_aba", "pet_vida_fundo",
			"pet_vida", "skill3", "skillbox2", "tab_ce", "tab_cd", "tab_be", "tab_bd", "tab_c", "tab_b", "tab_e", "tab_d"]:
		_tex[n] = load(PASTA + n + ".png")
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


# a esquerda da janela C (a mochila sai pra dar lugar)
func _ajustar() -> void:
	var v := get_viewport_rect().size
	var barra := 51.0 * v.x / 640.0
	_esc = minf(v.x / 640.0, (v.y - barra) / A)
	scale = Vector2(_esc, _esc)
	size = Vector2(L, A)
	position = Vector2(v.x - L * _esc * 2.0, 0)
	queue_redraw()


func alternar() -> void:
	visible = not visible
	_ajustar()
	print("TESTE janela pet aberta %s aba %d" % [visible, aba])


func _process(_dt: float) -> void:
	if visible:
		queue_redraw()


func _abas() -> Array:
	return [Rect2(12, 48, 56, 22), Rect2(68, 48, 56, 22)]


func _sair() -> Rect2:
	return Rect2(13, 392, 36, 29)


# CalcDamage
func dano(f: Dictionary) -> Vector2i:
	if f.tipo == 1:
		return Vector2i(f.dano_min + TERREMOTO[0], f.dano_max + TERREMOTO[1])
	var por := 0
	if inventario and inventario.itens.has(0):
		por = DicaItem.magia(inventario.itens[0])
	return Vector2i(f.dano_min + f.dano_min * por / 100, f.dano_max + f.dano_max * por / 100)


func _draw() -> void:
	draw_texture_rect(_tex.inv_fundo, Rect2(0, 0, L, A), false)
	draw_texture_rect(_tex.inv_topo, Rect2(0, 0, 190, 64), false)
	draw_texture_rect(_tex.inv_esq, Rect2(0, 64, 21, A - 64 - 45), false)
	draw_texture_rect(_tex.inv_dir, Rect2(L - 21, 64, 21, A - 64 - 45), false)
	draw_texture_rect(_tex.inv_baixo, Rect2(0, A - 45, 190, 45), false)
	var f := get_theme_default_font()
	_texto(f, Vector2(60, 13), DicaItem.t(1217), 70, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	# as abas (newui_guild_tab04: em cima a solta, embaixo a escolhida)
	var r := _abas()
	for i in 2:
		draw_texture_rect_region(_tex.pet_aba, r[i], Rect2(0, 22 * (1 if i == aba else 0), 56, 22))
		var cor := Color.WHITE if i == aba or r[i].has_point(_mouse) else Color8(170, 170, 170)
		_texto(f, r[i].position + Vector2(0, 5), DicaItem.t(1187 if i == CAVALO else 1214), 56, cor, HORIZONTAL_ALIGNMENT_CENTER, false, 9)
	var k := Pets.CAVALO if aba == CAVALO else Pets.CORVO
	if not Pets.vestidos.has(k):
		var t := DicaItem.t(1233) % DicaItem.t(1187) if aba == CAVALO else DicaItem.t(1169)
		_texto(f, Vector2(15, 100), t, 160, Color8(255, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, true)
	else:
		_ficha(f, Pets.calcular(Pets.vestidos[k]))
	var s := _sair()
	draw_texture_rect_region(_tex.inv_sair, s, Rect2(0, 29 * (1 if s.has_point(_mouse) else 0), 36, 29))


# RenderDarkHorseInfo e RenderDarkSpiritInfo
func _ficha(f: Font, p: Dictionary) -> void:
	var corvo := aba == CORVO
	_texto(f, Vector2(60, 25), DicaItem.t(1214 if corvo else 1187), 70, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var x := 12.0
	var y := 75.0
	_quadro(Rect2(x, y, 168, 121 if corvo else 105), 60, 20)
	if corvo:
		_quadro(Rect2(x, 196, 168, 195), 60, 20)
	var amarelo := Color8(255, 255, 0)
	_texto(f, Vector2(x + 2, y + 8), DicaItem.t(200, [p.nivel]), 56, amarelo, HORIZONTAL_ALIGNMENT_CENTER, true)
	_texto(f, Vector2(x + 10, y + 28), DicaItem.t(358, [p.vida, 255]), 0, Color.WHITE)
	draw_texture_rect(_tex.pet_vida_fundo, Rect2(x + 7, y + 40, 151, 12), false)
	var vida: int = mini(p.vida, 255) * 147 / 255
	if vida > 0:
		draw_texture_rect_region(_tex.pet_vida, Rect2(x + 9, y + 42, vida, 8), Rect2(0, 0, vida, 8))
	var d := dano(p)
	_texto(f, Vector2(x + 10, y + 59), DicaItem.t(357, [p.exp, p.exp_prox]), 0, Color.WHITE)
	_texto(f, Vector2(x + 10, y + 72), DicaItem.t(203, [d.x, d.y, p.sucesso]), 0, Color.WHITE)
	_texto(f, Vector2(x + 10, y + 85), DicaItem.t(64, [p.vel]), 0, Color.WHITE)
	if not corvo:
		return
	_texto(f, Vector2(x + 10, y + 98), DicaItem.t(698, [185 + p.nivel * 15]), 0, Color.WHITE)
	_texto(f, Vector2(x + 2, 196 + 8), DicaItem.t(1218), 56, amarelo, HORIZONTAL_ALIGNMENT_CENTER, true)
	for i in Pets.COMANDOS:
		var by := 196.0 + 28 + i * 40
		draw_texture_rect(_tex.skillbox2, Rect2(x + 10, by, 32, 38), false)
		draw_texture_rect_region(_tex.skill3, Rect2(x + 17, by + 6, 19, 27), Rect2(1 + i * 20, 0, 19, 27))
		_texto(f, Vector2(x + 52, by + 17), DicaItem.t(1219 + i), 0, Color.WHITE)
	# a dica da ordem com o mouse em cima (a mesma da lista de skills)
	for i in Pets.COMANDOS:
		var q := Rect2(x + 10, 196.0 + 28 + i * 40, 32, 38)
		if q.has_point(_mouse):
			var t := DicaItem.t(1223 + i)
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			var px := clampf(_mouse.x - w / 2, 2, L - w - 6)
			draw_rect(Rect2(px - 2, q.position.y - 15, w + 4, 13), Color(0, 0, 0, 0.85))
			draw_string(f, Vector2(px, q.position.y - 5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)


# RenderGroupBox: fundo escuro com a aba do titulo e a moldura de cantos
func _quadro(r: Rect2, tw: float, th: float) -> void:
	var fundo := Color(0, 0, 0, 0.6)
	draw_rect(Rect2(r.position.x + 3, r.position.y + 2, tw - 8, th), fundo)
	draw_rect(Rect2(r.position.x + 3, r.position.y + 2 + th, r.size.x - 7, r.size.y - th - 7), fundo)
	var x := r.position.x
	var y := r.position.y
	draw_texture_rect(_tex.tab_ce, Rect2(x, y, 14, 14), false)
	draw_texture_rect(_tex.tab_cd, Rect2(x + tw - 14, y, 14, 14), false)
	draw_texture_rect(_tex.tab_cd, Rect2(x + r.size.x - 14, y + th, 14, 14), false)
	draw_texture_rect(_tex.tab_be, Rect2(x, y + r.size.y - 14, 14, 14), false)
	draw_texture_rect(_tex.tab_bd, Rect2(x + r.size.x - 14, y + r.size.y - 14, 14, 14), false)
	draw_texture_rect(_tex.tab_c, Rect2(x + 6, y, tw - 12, 14), false)
	draw_texture_rect(_tex.tab_d, Rect2(x + tw - 14, y + 6, 14, th - 6), false)
	draw_texture_rect(_tex.tab_c, Rect2(x + tw - 5, y + th, r.size.x - tw - 6, 14), false)
	draw_texture_rect(_tex.tab_d, Rect2(x + r.size.x - 14, y + th + 6, 14, r.size.y - th - 14), false)
	draw_texture_rect(_tex.tab_b, Rect2(x + 6, y + r.size.y - 14, r.size.x - 12, 14), false)
	draw_texture_rect(_tex.tab_e, Rect2(x, y + 6, 14, r.size.y - 14), false)


# y do original e o topo da linha; aqui vira a base (+10)
func _texto(f: Font, p: Vector2, t: String, largura: float, cor: Color, al := HORIZONTAL_ALIGNMENT_LEFT, negrito := false, tam := 10) -> void:
	var b := p + Vector2(0, 10)
	if negrito:
		draw_string(f, b + Vector2(0.5, 0), t, al, largura if largura > 0 else -1.0, tam, cor)
	draw_string(f, b, t, al, largura if largura > 0 else -1.0, tam, cor)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_mouse = ev.position
		if ev.pressed:
			var r := _abas()
			for i in 2:
				if r[i].has_point(ev.position):
					aba = i
			if _sair().has_point(ev.position):
				alternar()
		accept_event()
	elif ev is InputEventMouseButton:
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
