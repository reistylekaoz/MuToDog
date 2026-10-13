class_name ItemChao
extends Node3D
# Item caido no chao: uma marca que brilha e o nome em cima (zen em dourado,
# joia em azul, excelente em verde, o resto em branco). Clique pra pegar.

var id := 0
var tile := Vector2i.ZERO
var dados := {}
var nome := ""


func montar(mundo: Node3D, d: Dictionary, nomes: Dictionary) -> void:
	dados = d
	id = d.id
	tile = Vector2i(d.x, d.y)
	var cor := Color(0.92, 0.92, 0.95)
	if d.has("zen"):
		nome = "%s Zen" % _milhar(d.zen)
		cor = Color(1.0, 0.82, 0.3)
	else:
		nome = nomes.get("%d,%d" % [d.grupo, d.numero], "Item %d/%d" % [d.grupo, d.numero])
		if d.nivel > 0:
			nome += " +%d" % d.nivel
		if d.grupo == 14 and d.numero in [13, 14, 16, 22, 31, 41, 42, 43, 44] or d.grupo == 12 and d.numero == 15:
			cor = Color(0.5, 0.75, 1.0)
		elif d.exc > 0:
			cor = Color(0.4, 0.95, 0.5)
			nome = "Excelente " + nome
		elif d.nivel >= 7 or d.sorte:
			cor = Color(0.6, 0.85, 1.0)
	position = mundo.no_tile(tile.x, tile.y)
	var marca := MeshInstance3D.new()
	var m: PrimitiveMesh
	if d.has("zen"):
		var c := CylinderMesh.new()
		c.top_radius = 0.16
		c.bottom_radius = 0.16
		c.height = 0.08
		m = c
	else:
		var pr := PrismMesh.new()
		pr.size = Vector3(0.22, 0.3, 0.22)
		m = pr
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = cor * 0.6
	m.material = mat
	marca.mesh = m
	marca.position.y = 0.2
	add_child(marca)
	var tw := create_tween().set_loops()
	tw.tween_property(marca, "rotation:y", TAU, 2.5).from(0.0)
	var l := Label3D.new()
	l.text = nome
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 26
	l.outline_size = 8
	l.modulate = cor
	l.position.y = 0.65
	add_child(l)
	# item novo cai de cima, como no cliente
	if d.get("novo", false):
		marca.position.y = 1.4
		create_tween().tween_property(marca, "position:y", 0.2, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


static func _milhar(v: int) -> String:
	var s := str(v)
	var r := ""
	while s.length() > 3:
		r = "." + s.right(3) + r
		s = s.left(s.length() - 3)
	return s + r
