class_name ItemChao
extends Node3D
# Item caido no chao: o modelo 3D do item deitado como no cliente (rotacao, altura e
# escala do "ground" do MuMain, em ModelosMU); o nome e desenhado pelo TextosMU.
# Sem modelo, fica uma marca que brilha.
# Clique pra pegar.

var id := 0
var tile := Vector2i.ZERO
var dados := {}
var nome := ""


func montar(mundo: Node3D, d: Dictionary, nomes: Dictionary) -> void:
	dados = d
	id = d.id
	tile = Vector2i(d.x, d.y)
	if d.has("zen"):
		nome = "Zen %s" % _milhar(d.zen)
	else:
		# nome do chao no jeito do cliente: "Nome +N" com +Skill, +Option e +Luck colados (textos 176 a 178)
		nome = ItensMU.tier(d) + nomes.get("%d,%d" % [d.grupo, d.numero], "Item %d/%d" % [d.grupo, d.numero])
		if d.grupo == 14 and d.numero == 11 and d.nivel in range(8, 13):
			nome = ItensMU.nome(d)   # Box of Kundun +1 a +5 (nivel 8 a 12), como no chao do original
		elif d.nivel > 0:
			nome += " +%d" % d.nivel
		if d.get("skill", false):
			nome += DicaItem.t(176)
		if int(d.get("opcao", 0)) > 0:
			nome += DicaItem.t(177)
		if d.get("sorte", false):
			nome += DicaItem.t(178)
	var cor := TextosMU._cor_item(d)
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
	_por_modelo(d, marca, tw)
	# item novo cai de cima, como no cliente
	if d.get("novo", false):
		marca.position.y = 1.4
		create_tween().tween_property(marca, "position:y", 0.2, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# como o cliente (ZzzObject.cpp): o item fica 30 acima do chao (arma 70), gira pela
# rotacao do chao, o osso raiz desce bodyHeight e a escala e a do chao ou 0,8 (0,7 de
# lanca a cajado). Zen e um monte de moedas (3 a 12) espalhadas em volta.
func _por_modelo(d: Dictionary, marca: Node3D, tw: Tween) -> void:
	if ModelosMU.eu == null:
		return
	var chave := "14,15" if d.has("zen") else "%d,%d" % [d.grupo, d.numero]
	if not d.has("zen") and not ModelosMU.eu.info("%s+%d" % [chave, d.nivel]).is_empty():
		chave = "%s+%d" % [chave, d.nivel]   # modelo por nivel (ItensMU.chave_nivel)
	var i := ModelosMU.eu.info(chave)
	if i.is_empty():
		return
	var no := await ModelosMU.eu.instanciar(chave)
	if no == null or not is_instance_valid(self):
		if no:
			no.free()
		return
	var g: int = -1 if d.has("zen") else d.grupo
	var escala: float = i[4] if i[4] > 0 else (0.7 if g in [3, 4, 5] else 0.8)
	var base := Node3D.new()
	base.rotation_degrees.x = -90
	base.scale = Vector3.ONE * 0.01 * escala
	base.position.y = (70.0 if g >= 0 and g <= 5 else 30.0) / 100.0
	add_child(base)
	var rot: Array = i[2]
	var giro := Transform3D(ModelosMU.giro_mu(rot[0], rot[1], rot[2]), Vector3.ZERO)
	var moedas := 1
	if d.has("zen"):
		moedas = clampi(int(sqrt(float(d.zen))) / 2, 3, 12)
	for k in moedas:
		var m: Node3D = no if k == 0 else no.duplicate()
		var pe := Node3D.new()
		pe.transform = giro * Transform3D(Basis(), Vector3(0, 0, i[3]))
		if moedas > 1:
			var a := randf() * TAU
			var r := randf() * (moedas + 20)
			pe.transform = Transform3D(Basis(Vector3(0, 0, 1), randf() * TAU), Vector3(cos(a) * r, sin(a) * r, 0)) * pe.transform
		pe.add_child(m)
		base.add_child(pe)
	if not d.has("zen"):
		BrilhoMU.aplicar(base, chave.get_slice("+", 0), d.nivel)
	tw.kill()
	marca.queue_free()
	if d.get("novo", false):
		base.position.y += 1.2
		create_tween().tween_property(base, "position:y", base.position.y - 1.2, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


static func _milhar(v: int) -> String:
	var s := str(v)
	var r := ""
	while s.length() > 3:
		r = "." + s.right(3) + r
		s = s.left(s.length() - 3)
	return s + r
