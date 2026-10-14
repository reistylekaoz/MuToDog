class_name EfeitoSkill
extends Node3D
# Efeito simples de skill: bola que voa (magia e flecha), anel que abre no chao
# (area), corte que brilha no alvo (espada) e brilho subindo (cura e buff).
# A cor vem do elemento da skill. Nao e o efeito do cliente: e so pra ver o que saiu.

const FOGO := [4, 5, 10, 13, 14, 55, 236, 61, 74, 78]
const GELO := [7, 39, 51, 12]
const RAIO := [3, 65, 215, 230, 237, 8]
const VENENO := [1, 38, 214]
const CURA := [26, 48, 234]
const BUFF := [27, 28, 16, 64, 233, 218, 217]
const ESPADA := [19, 20, 21, 22, 23, 41, 42, 43, 44, 47, 57, 232, 55, 56, 236]
const FLECHA := [24, 46, 51, 52, 235]


static func cor(n: int) -> Color:
	if n in FOGO:
		return Color(1.0, 0.45, 0.1)
	if n in GELO:
		return Color(0.45, 0.85, 1.0)
	if n in RAIO:
		return Color(0.7, 0.65, 1.0)
	if n in VENENO:
		return Color(0.35, 0.95, 0.3)
	if n in CURA:
		return Color(0.4, 1.0, 0.5)
	if n in BUFF:
		return Color(1.0, 0.85, 0.35)
	if n in ESPADA:
		return Color(0.95, 0.95, 1.0)
	return Color(0.55, 0.65, 1.0)


static func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# de quem soltou (de) pra onde vai (para); area = anel no destino
static func criar(pai: Node3D, n: int, de: Vector3, para: Vector3, area := false) -> void:
	var e := EfeitoSkill.new()
	pai.add_child(e)
	var c := cor(n)
	if n in CURA or n in BUFF:
		e._brilho(para, c)
	elif area:
		e._anel(para, c, 2.5 if n != 41 else 2.0)
	elif n in ESPADA:
		e._corte(para, c)
	else:
		e._bola(de + Vector3.UP * 1.2, para + Vector3.UP * 1.0, c, 0.12 if n in FLECHA else 0.28)
	e.get_tree().create_timer(1.6).timeout.connect(e.queue_free)


func _bola(de: Vector3, para: Vector3, c: Color, raio: float) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = raio
	s.height = raio * 2.0
	s.material = _material(c)
	m.mesh = s
	m.position = de
	add_child(m)
	var tw := create_tween()
	tw.tween_property(m, "position", para, clampf(de.distance_to(para) / 18.0, 0.08, 0.5))
	tw.tween_callback(func(): _anel(para - Vector3.UP, c, 0.9))
	tw.tween_property(m, "scale", Vector3.ONE * 2.5, 0.15)
	tw.parallel().tween_property(s.material, "albedo_color:a", 0.0, 0.15)


func _anel(p: Vector3, c: Color, ate: float) -> void:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.8
	t.outer_radius = 1.0
	t.material = _material(c)
	m.mesh = t
	m.position = p + Vector3.UP * 0.15
	m.scale = Vector3.ONE * 0.3
	add_child(m)
	var tw := create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(ate, 1, ate), 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(t.material, "albedo_color:a", 0.0, 0.5).set_delay(0.15)


func _corte(p: Vector3, c: Color) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.8, 0.12)
	q.material = _material(c)
	m.mesh = q
	m.position = p + Vector3.UP * 1.0
	m.rotation = Vector3(0, randf() * TAU, randf_range(-0.8, 0.8))
	add_child(m)
	var tw := create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(1.6, 3.0, 1), 0.25)
	tw.tween_property(q.material, "albedo_color:a", 0.0, 0.3)


func _brilho(p: Vector3, c: Color) -> void:
	for i in 10:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.07
		s.height = 0.14
		s.material = _material(c)
		m.mesh = s
		var a := TAU * i / 10.0
		m.position = p + Vector3(cos(a) * 0.5, 0.2, sin(a) * 0.5)
		add_child(m)
		var tw := create_tween().set_parallel()
		tw.tween_property(m, "position:y", p.y + 2.2, 0.9).set_delay(i * 0.03)
		tw.tween_property(s.material, "albedo_color:a", 0.0, 0.9).set_delay(i * 0.03)
