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
	for p in _pontos:
		_numero(cam, p)


func _nome(cam: Camera3D, f: Font, tam: int, e: Entidade) -> void:
	var p := e.global_position + Vector3.UP * (e.altura() + 0.6)
	if cam.is_position_behind(p):
		return
	var s := cam.unproject_position(p)
	var cor := Color8(200, 220, 255)       # jogador comum (SetPlayerColor 3)
	var fundo := Color8(10, 30, 50, 150)
	match e.tipo:
		"eu":
			fundo = Color8(60, 100, 0, 150)
		"npc", "guarda":
			cor = Color8(150, 255, 240)
		"monstro":
			cor = Color8(255, 230, 200)
			fundo = Color8(100, 0, 0, 255)
	_caixa(f, tam, e.nome, s, cor, fundo, false, false)


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
