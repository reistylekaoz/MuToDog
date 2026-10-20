class_name Minimapa
extends Control
# Minimapa do Tab (CNewUIMiniMap do S6): a tela inteira acima da barra escurece (85%) e
# mostra o mini_map.ozt do mapa centrado em mim, 800 pixels (na tela de 640) para os 256
# tiles, com os NPCs e portais do Minimap_WorldN.bmd. No S6 o mapa gira 45 graus (a camera
# e fixa); aqui gira com a camera, pra cima no minimapa ser pra frente na tela.
# A mais: abre com o mapa inteiro (zoom 400), os spots de monstro do OpenMU (cor pelo nivel perto do meu), a roda aproxima e o
# botao direito anda ate o ponto (o caminho vai em trechos, como no clique do chao).
# Dados: ferramentas/dados_minimapa.py -> dados/minimapa.json e dados/minimapa/mapa<N>.png

signal andar(tile: Vector2i)

const ALTO := 430.0                         # a area do minimapa na tela de 640 x 480
# m_Lenth: pixels pros 256 tiles (o S6 vai de 800 a 1800); 400 e 600 a mais, pra ver os spots
const ZOOM := [400.0, 600.0, 800.0, 1000.0, 1200.0, 1400.0, 1600.0, 1800.0]

var jogo: Node                              # jogo.gd: eu, mundo, mapa_atual, meu_nivel
var _dados := {}
var _tex := {}
var _mapa_tex: Texture2D
var _mapa := -1
var _zoom := 0
var _u := 1.0                               # pixels da tela por pixel do S6
var _mouse := Vector2(-100, -100)
var _destino := Vector2i(-1, -1)


func _ready() -> void:
	for n in ["mm_canto", "mm_linha", "mm_eu", "mm_portal", "mm_npc", "mm_fechar"]:
		_tex[n] = load(Inventario.PASTA + n + ".png")
	if FileAccess.file_exists("res://dados/minimapa.json"):
		_dados = JSON.parse_string(FileAccess.get_file_as_string("res://dados/minimapa.json"))
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true   # o mapa girado nao passa pra baixo da barra
	get_viewport().size_changed.connect(_ajustar)
	_ajustar()
	visible = false


func _ajustar() -> void:
	var v := get_viewport_rect().size
	var barra := 51.0 * v.x / 640.0
	position = Vector2.ZERO
	size = Vector2(v.x, v.y - barra)
	_u = minf(v.x / 640.0, size.y / ALTO)
	queue_redraw()


# abre no mapa de agora; sem mini_map no cliente S6 nao abre (m_bSuccess)
func alternar(mapa: int) -> bool:
	if visible:
		visible = false
		return true
	if _mapa != mapa:
		_mapa = mapa
		var p := "res://dados/minimapa/mapa%d.png" % mapa
		_mapa_tex = load(p) if ResourceLoader.exists(p) else null
		_destino = Vector2i(-1, -1)
	if _mapa_tex == null:
		return false
	visible = true
	queue_redraw()
	return true


func _process(_d: float) -> void:
	if visible:
		if _destino.x >= 0 and jogo and jogo.eu and jogo.eu.tile == _destino:
			_destino = Vector2i(-1, -1)
		queue_redraw()


# tile -> tela: a imagem tem a coluna no Y do tile e a linha no X (como no Render do
# S6: Tx sai do PositionY, Ty do PositionX); gira com a camera
func _base() -> Transform2D:
	var k: float = ZOOM[_zoom] / 256.0 * _u
	var cam := get_viewport().get_camera_3d()
	var frente := Vector2(0, -1)
	var direita := Vector2(1, 0)
	if cam:
		var f := -cam.global_transform.basis.z
		var r := cam.global_transform.basis.x
		frente = Vector2(f.x, f.z).normalized() if Vector2(f.x, f.z).length() > 0.01 else Vector2(0, -1)
		direita = Vector2(r.x, r.z).normalized()
	# tile x+1 = (1, 0, 0) no Godot; tile y+1 = (0, 0, -1) (mundo.no_tile)
	var tx: Vector2 = Vector2(direita.dot(Vector2(1, 0)), -frente.dot(Vector2(1, 0))) * k
	var ty: Vector2 = Vector2(direita.dot(Vector2(0, -1)), -frente.dot(Vector2(0, -1))) * k
	var eu_t := Vector2(jogo.eu.tile) + Vector2(0.5, 0.5) if jogo and jogo.eu else Vector2(128, 128)
	var centro := size / 2.0
	return Transform2D(tx, ty, centro - tx * eu_t.x - ty * eu_t.y)


func _cor_nivel(nivel: int) -> Color:
	var meu: int = jogo.meu_nivel if jogo else 1
	if nivel > meu + 10:
		return Color(1, 0.3, 0.25)
	if nivel > meu - 5:
		return Color(1, 0.85, 0.3)
	return Color(0.45, 1, 0.45)


func _draw() -> void:
	if _mapa_tex == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85))
	var t := _base()
	var f := get_theme_default_font()
	# a imagem: pixel (u, v) = tile (v / 2, u / 2), entao eixo u da imagem = tile y
	draw_set_transform_matrix(Transform2D(t.y / 2.0, t.x / 2.0, t.origin))
	draw_texture_rect(_mapa_tex, Rect2(0, 0, 512, 512), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var m: Dictionary = _dados.get(str(_mapa), {})
	var dica := ""
	var dica_em := Vector2.ZERO
	# spots: area fraca na cor do nivel, nome e nivel no meio
	for s in m.get("spots", []):
		var pts := PackedVector2Array([t * Vector2(s[0], s[1]), t * Vector2(s[2] + 1, s[1]),
			t * Vector2(s[2] + 1, s[3] + 1), t * Vector2(s[0], s[3] + 1)])
		var nv: int = s[4][-1][1]
		var cor := _cor_nivel(nv)
		draw_colored_polygon(pts, Color(cor, 0.07))
		pts.append(pts[0])
		draw_polyline(pts, Color(cor, 0.35), 1.0)
	for s in m.get("spots", []):
		var c := t * Vector2((s[0] + s[2] + 1) / 2.0, (s[1] + s[3] + 1) / 2.0)
		var nomes := []
		for mo in s[4]:
			nomes.append("%s %d" % [mo[0], mo[1]])
		var txt := " · ".join(nomes)
		var tam := 9.0 * _u
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam)).x
		var p := c - Vector2(w / 2.0, -tam / 3.0)
		draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam), 3, Color(0, 0, 0, 0.9))
		draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam), _cor_nivel(s[4][-1][1]))
		if Rect2(p - Vector2(0, tam), Vector2(w, tam * 1.3)).has_point(_mouse):
			var linhas := []
			for mo in s[4]:
				linhas.append("%s (nivel %d) · %d no mapa" % mo)
			dica = "\n".join(linhas)
			dica_em = c
	# NPCs (15) e portais (30, virados pelo giro do bmd)
	for mk in m.get("marcas", []):
		var c := t * Vector2(mk[1] + 0.5, mk[2] + 0.5)
		var lado := (15.0 if mk[0] == 1 else 30.0) * _u
		var giro := deg_to_rad(-float(mk[3])) + t.x.angle()
		draw_set_transform(c, giro if mk[0] == 2 else 0.0)
		draw_texture_rect(_tex.mm_npc if mk[0] == 1 else _tex.mm_portal, Rect2(-lado / 2, -lado / 2, lado, lado), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		if c.distance_to(_mouse) < lado / 2.0:
			dica = mk[4]
			dica_em = c
	# para onde estou indo
	if _destino.x >= 0:
		var d := t * (Vector2(_destino) + Vector2(0.5, 0.5))
		draw_line(size / 2.0, d, Color(1, 0.9, 0.4, 0.5), 1.5)
		draw_circle(d, 4.0 * _u, Color(1, 0.9, 0.4))
		draw_arc(d, 7.0 * _u, 0, TAU, 20, Color(1, 0.9, 0.4, 0.6), 1.5)
	var eu_l := 12.0 * _u
	draw_texture_rect(_tex.mm_eu, Rect2(size / 2.0 - Vector2(eu_l, eu_l) / 2.0, Vector2(eu_l, eu_l)), false)
	_moldura()
	var fechar := _rect_fechar()
	var linha := 1 if fechar.has_point(_mouse) else 0
	draw_texture_rect_region(_tex.mm_fechar, fechar, Rect2(0, 29 * linha, 36, 29))
	var ajuda := "Botao direito: andar ate la · roda: zoom · Tab ou Esc: fechar"
	var ta := int(9 * _u)
	draw_string_outline(f, Vector2(0, size.y - 12 * _u), ajuda, HORIZONTAL_ALIGNMENT_CENTER, size.x, ta, 3, Color(0, 0, 0, 0.9))
	draw_string(f, Vector2(0, size.y - 12 * _u), ajuda, HORIZONTAL_ALIGNMENT_CENTER, size.x, ta, Color(0.85, 0.85, 0.9))
	if dica != "":
		_dica(f, dica, dica_em)


func _rect_fechar() -> Rect2:
	return Rect2(size.x - 40 * _u, 8 * _u, 30 * _u, 25 * _u)


# cantos e linhas do mini_map_ui (35 de canto, 6 de linha)
func _moldura() -> void:
	var c := 35.0 * _u
	var l := 6.0 * _u
	var lin: Texture2D = _tex.mm_linha
	draw_texture_rect(lin, Rect2(0, 0, size.x, l), true)
	draw_texture_rect(lin, Rect2(0, size.y - l, size.x, l), true)
	draw_set_transform(Vector2(l, 0), PI / 2)
	draw_texture_rect(lin, Rect2(0, 0, size.y, l), true)
	draw_set_transform(Vector2(size.x, 0), PI / 2)
	draw_texture_rect(lin, Rect2(0, 0, size.y, l), true)
	for k in 4:
		var x := 0.0 if k % 2 == 0 else size.x
		var y := 0.0 if k < 2 else size.y
		draw_set_transform(Vector2(x, y), 0, Vector2(1 if k % 2 == 0 else -1, 1 if k < 2 else -1))
		draw_texture_rect(_tex.mm_canto, Rect2(0, 0, c, c), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _dica(f: Font, txt: String, em: Vector2) -> void:
	var tam := int(9 * _u)
	var linhas := txt.split("\n")
	var w := 0.0
	for li in linhas:
		w = maxf(w, f.get_string_size(li, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x)
	var h := linhas.size() * tam * 1.3
	var r := Rect2(em - Vector2(w / 2 + 4, h + 12 * _u), Vector2(w + 8, h + 4))
	draw_rect(r, Color(0, 0, 0, 0.7))
	for i in linhas.size():
		draw_string(f, r.position + Vector2(4, tam * (1.1 + 1.3 * i)), linhas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color.WHITE)


# tela -> tile (o contrario do _base)
func tile_em(tela: Vector2) -> Vector2i:
	var p := _base().affine_inverse() * tela
	return Vector2i(floori(p.x), floori(p.y))


func ir_para(tile: Vector2i) -> void:
	_destino = tile
	andar.emit(tile)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_mouse = ev.position
	elif ev is InputEventMouseButton and ev.pressed:
		_mouse = ev.position
		if ev.button_index == MOUSE_BUTTON_LEFT and _rect_fechar().has_point(ev.position):
			visible = false
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			var t := tile_em(ev.position)
			if t.x >= 0 and t.y >= 0 and t.x < 256 and t.y < 256:
				ir_para(t)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = mini(_zoom + 1, ZOOM.size() - 1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = maxi(_zoom - 1, 0)
	accept_event()
	queue_redraw()
