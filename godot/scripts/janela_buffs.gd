class_name JanelaBuffs
extends Control
# Os buffs e debuffs em mim (CNewUIBuffWindow do cliente S6), na tela de referencia 640x480:
# icones de 20x28 a partir de (220, 15), passo 25 na linha e 33 entre linhas, 8 por linha; com janela aberta na
# direita a fila anda pra esquerda. Ordem: buffs do maior pro menor, depois os debuffs do menor pro maior.
# Mouse em cima: nome em azul, descricao em branco ('/' quebra a linha) e, se o buff tem tempo, quanto falta em roxo.
# Nome, descricao e icone vem do BuffEffect_eng.bmd (ferramentas/dados_buff.py -> dados/buffs.json, hud/buff1 e buff2).

const PASTA := "res://dados/hud/"
# o cliente nao desenha 83, 84, 85 e 120; os outros sao celulas vazias da folha de icones (so o numero escrito)
const ESCONDIDOS := [83, 84, 85, 120, 7, 12, 13, 19, 20, 27, 28, 32, 33, 59, 60, 62, 63, 64, 66, 67, 68, 69, 70]
const BASE := {135: 8, 136: 8, 138: 82, 139: 82, 148: 5, 149: 5, 140: 4, 143: 6, 180: 30}   # o mais forte usa o icone do base
const VIP := 180   # buff do Gold Channel Ticket (so no servidor daqui): icone do Seal of Wealth com "VIP" escrito
# so os buffs de item mostram o tempo (IsBuffTimeVisible do cliente)
const COM_TEMPO := [[29, 31], [35, 54], [78, 80], [82, 82], [87, 97], [99, 103], [112, 114], [119, 119], [121, 121], [180, 180]]

static var dados := {}

var buffs := {}        # efeito -> fim em ms (Time.get_ticks_msec), 0 = sem tempo conhecido
var livre := 640.0     # quanto da tela de 640 as janelas da direita deixam
var _tex := {}
var _esc := 1.0
var _mouse := Vector2(-100, -100)


static func carregar() -> void:
	if dados.is_empty() and FileAccess.file_exists("res://dados/buffs.json"):
		dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/buffs.json"))


static func nome(e: int) -> String:
	carregar()
	return dados.get(str(e), {}).get("nome", "Efeito %d" % e)


static func debuff(e: int) -> bool:
	carregar()
	return dados.get(str(e), {}).get("debuff", false)


func _ready() -> void:
	carregar()
	_tex.buff1 = load(PASTA + "buff1.png")
	_tex.buff2 = load(PASTA + "buff2.png")
	mouse_filter = Control.MOUSE_FILTER_PASS
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


func _ajustar() -> void:
	var v := get_viewport_rect().size
	_esc = v.x / 640.0
	scale = Vector2(_esc, _esc)
	size = Vector2(640, 200)
	position = Vector2.ZERO
	queue_redraw()


func por(e: int, segundos := 0) -> void:
	buffs[e] = Time.get_ticks_msec() + segundos * 1000 if segundos > 0 else 0
	queue_redraw()


func tirar(e: int) -> void:
	buffs.erase(e)
	queue_redraw()


func limpar() -> void:
	buffs.clear()
	queue_redraw()


# os que aparecem, na ordem do cliente
func lista() -> Array:
	var bons := []
	var ruins := []
	for e: int in buffs:
		if e in ESCONDIDOS or not dados.has(str(e)):
			continue
		(ruins if debuff(e) else bons).append(e)
	bons.sort()
	bons.reverse()
	ruins.sort()
	return bons + ruins


func _x0() -> float:
	if livre >= 640.0:
		return 220.0
	if livre >= 450.0:
		return 125.0
	if livre >= 373.0:
		return 86.0
	return 30.0


func _rect(i: int) -> Rect2:
	return Rect2(_x0() + (i % 8) * 25, 15 + (i / 8) * 33, 20, 28)


func _has_point(p: Vector2) -> bool:
	for i in lista().size():
		if _rect(i).has_point(p):
			return true
	return false


static func tempo_visivel(e: int) -> bool:
	for f in COM_TEMPO:
		if e >= f[0] and e <= f[1]:
			return true
	return false


# "1 Hour 20 Minute"; menos de um minuto: o texto 2308 do cliente
static func tempo(segundos: int) -> String:
	if segundos < 60:
		return DicaItem.t(2308)
	var d := segundos / 86400
	var h := (segundos / 3600) % 24
	var m := (segundos / 60) % 60
	var p := []
	if d > 0:
		p.append("%d %s" % [d, DicaItem.t(2298)])
	if h > 0:
		p.append("%d %s" % [h, DicaItem.t(2299)])
	if m > 0:
		p.append("%d %s" % [m, DicaItem.t(2300)])
	return " ".join(p)


func linhas_dica(e: int) -> Array:
	var d: Dictionary = dados.get(str(e), {})
	var l := [{"t": d.get("nome", "Efeito %d" % e), "cor": DicaItem.AZUL, "negrito": true}]
	for t: String in str(d.get("descricao", "")).split("/", false):
		l.append({"t": t.strip_edges(), "cor": DicaItem.BRANCO})
	var fim: int = buffs.get(e, 0)
	if fim > 0 and tempo_visivel(e):
		var falta := maxi((fim - Time.get_ticks_msec()) / 1000, 0)
		l.append({"t": DicaItem.t(2533).replace("%s", tempo(falta)), "cor": DicaItem.ROXO})
	return l


func _process(_dt: float) -> void:
	var agora := Time.get_ticks_msec()
	for e: int in buffs.keys():
		if buffs[e] > 0 and agora > buffs[e] + 3000:
			buffs.erase(e)   # o servidor manda o fim; isto so limpa se o aviso nao veio
	if visible and not buffs.is_empty():
		queue_redraw()


func _draw() -> void:
	var l := lista()
	var sob := -1
	for i in l.size():
		var e: int = BASE.get(l[i], l[i])
		var r := _rect(i)
		var folha: Texture2D = _tex.buff1 if e < 81 else _tex.buff2
		var k := (e - 1) if e < 81 else (e - 81)
		draw_texture_rect_region(folha, r, Rect2((k % 10) * 20, (k / 10) * 28, 20, 28))
		if l[i] == VIP:
			var f := get_theme_default_font()
			var fs := maxi(int(7 * r.size.x / 20.0), 6)
			draw_string_outline(f, Vector2(r.position.x, r.end.y - 2), "VIP", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, 3, Color.BLACK)
			draw_string(f, Vector2(r.position.x, r.end.y - 2), "VIP", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color(1, 0.85, 0.3))
		if r.has_point(_mouse):
			sob = i
	if sob >= 0:
		DicaItem.mostrar(self, get_theme_default_font(), linhas_dica(l[sob]), _rect(sob))
	else:
		DicaItem.esconder(self)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_mouse = Vector2(-100, -100)
		queue_redraw()
