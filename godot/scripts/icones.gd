extends Node
# Gera o atlas dos icones dos itens (o MU desenha o modelo 3D no inventario; aqui
# cada modelo e fotografado uma vez). Roda so no export "Icones" (build/icones),
# aberto pelo testes/icones.mjs, que salva dados/icones.png e dados/icones.json.
# Cada item ocupa largura x altura casas de PX pixels, centrado e encaixado.

const PX := 40

var vp: SubViewport
var cam: Camera3D


func _ready() -> void:
	var modelos: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/itens/modelos.json"))
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/itens_info.json"))
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.position = Vector3(0, 0, 5000)
	cam.near = 1.0
	cam.far = 20000.0
	vp.add_child(cam)
	# prateleiras: itens em linhas de 1024 px
	var chaves := modelos.keys()
	chaves.sort_custom(func(a, b): return _tam(info, a).y > _tam(info, b).y)
	var pos := {}
	var x := 0
	var y := 0
	var alto := 0
	for k in chaves:
		var t := _tam(info, k) * PX
		if x + t.x > 1024:
			x = 0
			y += alto
			alto = 0
		pos[k] = Rect2i(x, y, t.x, t.y)
		x += t.x
		alto = maxi(alto, t.y)
	var atlas := Image.create(1024, y + alto, false, Image.FORMAT_RGBA8)
	var feitos := 0
	var cache := {}
	for k in chaves:
		var r: Rect2i = pos[k]
		var img: Image = await _foto(modelos[k], r.size)
		if img:
			atlas.blit_rect(img, Rect2i(Vector2i.ZERO, r.size), r.position)
			feitos += 1
		cache[k] = [r.position.x, r.position.y, r.size.x, r.size.y]
	print("ICONES %d de %d" % [feitos, chaves.size()])
	var png := Marshalls.raw_to_base64(atlas.save_png_to_buffer())
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.icones_png = '%s'; window.icones_json = '%s';" % [png, JSON.stringify(cache)])
	print("ICONES PRONTO")


func _tam(info: Dictionary, k: String) -> Vector2i:
	var i: Array = info.get(k.get_slice("+", 0), [1, 1])   # variante por nivel (14,11+8) tem o tamanho do item
	return Vector2i(int(i[0]), int(i[1]))


func _foto(modelo: String, tam: Vector2i) -> Image:
	var c := "res://dados/itens/%s.glb" % modelo
	if not ResourceLoader.exists(c):
		return null
	var no: Node3D = load(c).instantiate()
	vp.add_child(no)
	vp.size = tam
	# caixa do modelo (coordenadas do MU ja giradas como no inventario)
	var caixa := AABB()
	var primeira := true
	for m: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		var a := m.global_transform * m.get_aabb()
		caixa = a if primeira else caixa.merge(a)
		primeira = false
	var meio := caixa.get_center()
	cam.position = Vector3(meio.x, meio.y, caixa.end.z + 1000.0)
	cam.far = caixa.size.z + 3000.0
	# ortogonal: size e a altura visivel; encaixa largura e altura com folga
	var asp := float(tam.x) / tam.y
	cam.size = maxf(caixa.size.y, caixa.size.x / asp) * 1.08
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	no.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	return img
