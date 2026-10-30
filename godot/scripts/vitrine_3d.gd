class_name Vitrine3D
extends Node
# O item no inventario em 3D, como o cliente (ZzzInventory.cpp RenderItem3D e RenderObjectScreen): o
# icone parado do atlas so serve pro item sem nada vivo. Vai em 3D o item com brilho de nivel (+3 em
# diante, joia conta como +8), o que gira sozinho (gambleItem, 0,2 grau por ms) e o que esta embaixo
# do mouse ou na mao (gira 0,45 grau por ms no eixo Y do MU, o Angle[1] da rotacao do inventario).
# Uma vitrine por janela (filha do CanvasItem): um SubViewport do tamanho da janela pros itens parados
# e outro, maior que a casa, so pro item em foco (ele sai da casa quando gira, como no original).
# O dos parados so redesenha quando algo muda ou, se tem brilho que corre (+7 em diante) ou item que gira,
# 15 vezes por segundo (antes era todo quadro: loja e inventario abertos eram 2 janelas inteiras em 3D por quadro).
# Rotacao do inventario: dados/modelos/inventario.json (ferramentas/inventario_giro.py).

const GIRO_FOCO := 0.45    # graus por ms (SelectedItemTurnSpeed)
const GIRO_SOZINHO := 0.2  # graus por ms (GambleItemTurnSpeed)
const ROT_PADRAO := [270.0, -10.0, 0.0]
const FOLGA_FOCO := 1.8    # o viewport do foco e 1,8 vez a casa
const QUADRO_PARADOS := 66 # ms entre um desenho e outro dos parados que andam (15 por segundo)

static var _rot := {}
static var _giram := {}
static var _lido := false

var ci: CanvasItem
var _vp: SubViewport       # itens parados, em coordenadas da janela
var _vp_foco: SubViewport  # o item em foco, centrado
var _itens := {}           # chave da casa -> {no, giro, anda, gen}
var _foco := {}            # {chave, no, r, gen}
var _gen := 0
var _carregando := {}      # chave do modelo -> true
var _sujo := false         # os parados mudaram: desenhar no proximo quadro
var _ultimo := 0           # ms do ultimo desenho dos parados


static func _ler() -> void:
	if _lido:
		return
	_lido = true
	var c := "res://dados/modelos/inventario.json"
	if FileAccess.file_exists(c):
		var d = JSON.parse_string(FileAccess.get_file_as_string(c))
		if d is Dictionary:
			_rot = d.get("rot", {})
			for k in d.get("giram", []):
				_giram[k] = true


static func gira_sozinho(it: Dictionary) -> bool:
	_ler()
	return _giram.has(ItensMU.chave(it))


# o item precisa do modelo vivo mesmo parado (brilho do nivel ou giro proprio)?
static func vivo(it: Dictionary) -> bool:
	return gira_sozinho(it) or BrilhoMU.nivel_visivel(ItensMU.chave(it), int(it.get("nivel", 0))) >= 3


# a vitrine da janela (nasce no proximo quadro: nao da pra por filho no meio do _draw)
static func de(c: CanvasItem) -> Vitrine3D:
	if c.has_meta("vitrine_3d"):
		var v = c.get_meta("vitrine_3d")
		# ainda nao entrou na arvore (o add_child do quadro passado nao rodou): icone por enquanto
		return v if is_instance_valid(v) and v._vp != null else null
	var v := Vitrine3D.new()
	v.ci = c
	c.set_meta("vitrine_3d", v)
	c.add_child.call_deferred(v, false, Node.INTERNAL_MODE_BACK)
	return null


func _ready() -> void:
	_vp = _novo_vp()
	_vp_foco = _novo_vp()
	ci.draw.connect(_desenhando)


func _novo_vp() -> SubViewport:
	var v := SubViewport.new()
	v.transparent_bg = true
	v.own_world_3d = true
	v.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 1.0
	cam.far = 4000.0
	v.add_child(cam)
	add_child(v)
	return v


# pixels da tela por unidade da janela (a janela tem escala propria e o jogo estica o canvas)
func _px() -> float:
	var s := ci.get_global_transform_with_canvas().get_scale().x * ci.get_viewport().get_final_transform().get_scale().x
	return clampf(s, 0.5, 4.0)


# comeco de um _draw da janela: o que nao for pedido de novo sai no fim do quadro
func _desenhando() -> void:
	_gen += 1
	_limpar.call_deferred(_gen)


func _limpar(g: int) -> void:
	if g != _gen:
		return
	for k in _itens.keys():
		if _itens[k].gen != g:
			if is_instance_valid(_itens[k].no):
				_itens[k].no.queue_free()
			_itens.erase(k)
			_sujo = true
	if not _foco.is_empty() and _foco.gen != g:
		if is_instance_valid(_foco.no):
			_foco.no.queue_free()
		_foco = {}


func _process(_d: float) -> void:
	var ve := ci.is_visible_in_tree()
	_vp_foco.render_target_update_mode = SubViewport.UPDATE_ALWAYS if ve and not _foco.is_empty() else SubViewport.UPDATE_DISABLED
	var t := Time.get_ticks_msec()
	if not ve or _itens.is_empty():
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	elif _sujo or (t - _ultimo >= QUADRO_PARADOS and _itens.values().any(func(e): return e.anda)):
		_sujo = false
		_ultimo = t
		for e in _itens.values():
			if e.giro and is_instance_valid(e.no):
				_girar(e.no, fmod(t * GIRO_SOZINHO, 360.0))
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if not _foco.is_empty() and is_instance_valid(_foco.no):
		_girar(_foco.no, fmod(t * GIRO_FOCO, 360.0))
		# o mouse saiu da casa e a janela nao redesenhou (nem toda janela redesenha quando o mouse sai)
		if ve and not ItensMU.segurando and not _foco.r.has_point(ci.get_local_mouse_position()):
			ci.queue_redraw()


# desenha o item em 3D na casa r; false = ainda nao tem modelo (quem chamou desenha o icone)
func desenhar(it: Dictionary, r: Rect2, cor: Color, foco: bool) -> bool:
	var chave := _chave_modelo(it)
	if chave == "":
		return false
	var nivel := int(it.get("nivel", 0))
	var id := "%s|%d|%d,%d,%d,%d" % [chave, nivel, r.position.x, r.position.y, r.size.x, r.size.y]
	var px := _px()
	if foco:
		if _foco.get("id", "") != id:
			if not _foco.is_empty() and is_instance_valid(_foco.no):
				_foco.no.queue_free()
			_foco = {}
			var no := _montar(chave, it, r.size)
			if no == null:
				return false
			_vp_foco.add_child(no)
			_foco = {"id": id, "no": no}
		_foco.gen = _gen
		_foco.r = r
		var lado := r.size * FOLGA_FOCO
		_vp_foco.size = Vector2i((lado * px).ceil())
		var cam: Camera3D = _vp_foco.get_child(0)
		cam.size = lado.y
		cam.position = Vector3(0, 0, 2000)
		ci.draw_texture_rect(_vp_foco.get_texture(), Rect2(r.get_center() - lado / 2.0, lado), false, cor)
		return true
	if not _itens.has(id):
		var no := _montar(chave, it, r.size)
		if no == null:
			return false
		_vp.add_child(no)
		var gira := gira_sozinho(it)
		_itens[id] = {"no": no, "giro": gira, "anda": gira or BrilhoMU.nivel_visivel(chave.get_slice("+", 0), nivel) >= 7}
		_sujo = true
	var e: Dictionary = _itens[id]
	e.gen = _gen
	var c := r.get_center()
	e.no.position = Vector3(c.x, -c.y, 0)
	var tam := (ci as Control).size if ci is Control else Vector2(640, 480)
	var lado_vp := Vector2i((tam * px).ceil())
	if _vp.size != lado_vp:
		_vp.size = lado_vp
		_sujo = true
	# item novo aparece ja neste quadro (o SubViewport desenha depois do _draw)
	if _sujo:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var cam: Camera3D = _vp.get_child(0)
	cam.size = tam.y
	cam.position = Vector3(tam.x / 2.0, -tam.y / 2.0, 2000)
	ci.draw_texture_rect_region(_vp.get_texture(), r, Rect2(r.position * px, r.size * px), cor)
	return true


func _chave_modelo(it: Dictionary) -> String:
	if ModelosMU.eu == null:
		return ""
	var k := ItensMU.chave_nivel(it)
	if not ModelosMU.eu.info(k).is_empty():
		return k
	k = ItensMU.chave(it)
	return k if not ModelosMU.eu.info(k).is_empty() else ""


# o modelo pronto pra casa de tamanho tam: pivo no meio da caixa, encaixado como o icone do atlas
# (null enquanto o GLB baixa; quando chega, a janela redesenha)
var _modelos := {}   # chave -> Node3D carregado (duplicado a cada uso)


func _montar(chave: String, it: Dictionary, tam: Vector2) -> Node3D:
	if not _modelos.has(chave):
		if not _carregando.has(chave):
			_carregando[chave] = true
			# fora do _draw: no PC o modelo vem do pacote na hora e o queue_redraw no meio do desenho se perde
			_baixar.call_deferred(chave)
		return null
	var m: Node3D = _modelos[chave]
	if m == null:
		return null
	var base := chave.get_slice("+", 0)
	var rot: Array = _rot.get(base, ROT_PADRAO)
	var b0 := ModelosMU.giro_mu(rot[0], rot[1], rot[2])
	var modelo: Node3D = m.duplicate()
	BrilhoMU.aplicar(modelo, base, int(it.get("nivel", 0)))
	# caixa do modelo na rotacao do inventario
	var caixa := AABB()
	var primeira := true
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		var a := Transform3D(b0, Vector3.ZERO) * _relativo(mi, modelo) * mi.get_aabb()
		caixa = a if primeira else caixa.merge(a)
		primeira = false
	if primeira or caixa.size.x <= 0.0 or caixa.size.y <= 0.0:
		modelo.free()
		return null
	var esc := minf(tam.x / caixa.size.x, tam.y / caixa.size.y) / 1.08
	var no := Node3D.new()
	no.scale = Vector3.ONE * esc
	var giro := Node3D.new()
	giro.name = "giro"
	giro.basis = b0
	giro.set_meta("rot", rot)
	no.add_child(giro)
	# o ponto do modelo que cai no meio da caixa fica no pivo
	modelo.position = -(b0.inverse() * caixa.get_center())
	giro.add_child(modelo)
	return no


func _girar(no: Node3D, angulo: float) -> void:
	var g: Node3D = no.get_node_or_null("giro")
	if g:
		var rot: Array = g.get_meta("rot")
		g.basis = ModelosMU.giro_mu(rot[0], angulo, rot[2])


func _baixar(chave: String) -> void:
	var m := await ModelosMU.eu.instanciar(chave)
	if not is_instance_valid(self):
		if m:
			m.free()
		return
	_modelos[chave] = m
	_carregando.erase(chave)
	if is_instance_valid(ci):
		ci.queue_redraw()


static func _relativo(n: Node3D, raiz: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = n
	while p != null and p != raiz:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for m in _modelos.values():
			if is_instance_valid(m):
				m.free()
