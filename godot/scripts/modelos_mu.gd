class_name ModelosMU
extends Node
# Modelos dos itens (conversor modelos -> dados/modelos/<nome>.glb e modelos.json).
# No PC e nos testes os GLB estao importados no projeto; no navegador eles nao vao no
# pck (50 MB): cada um e baixado de modelos/<nome>.glb so quando aparece e fica guardado.
# Uso: var no := await ModelosMU.eu.instanciar("0,1") (null se o item nao tem modelo).

const PASTA := "res://dados/modelos/"
static var eu: ModelosMU
static var pasta_web := "modelos"   # o modo polido (Polido) troca por modelos_hd

var mapa := {}          # "grupo,numero" -> [glb, tipo, rotacao no chao, altura no chao, escala no chao]
var _prontos := {}      # glb -> Node3D modelo (duplicado a cada uso)
var _pedidos := {}      # glb -> true enquanto baixa
signal _chegou(glb: String)


func _ready() -> void:
	eu = self
	if FileAccess.file_exists(PASTA + "modelos.json"):
		mapa = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "modelos.json"))


func info(chave: String) -> Array:
	return mapa.get(chave, [])


func instanciar(chave: String) -> Node3D:
	var i := info(chave)
	if i.is_empty():
		return null
	var glb: String = i[0]
	if not _prontos.has(glb):
		await _carregar(glb)
	var m: Node3D = _prontos.get(glb)
	return m.duplicate() if m else null


func _carregar(glb: String) -> void:
	if _pedidos.has(glb):
		while not _prontos.has(glb):
			var veio: String = await _chegou
			if veio == glb:
				break
		return
	_pedidos[glb] = true
	var no: Node3D = null
	# modo polido fora do navegador: os GLB de testes/exportar_polido.sh ficam em build/<pasta_web>/
	var arq_fora := ProjectSettings.globalize_path("res://build/%s/%s.glb" % [pasta_web, glb])
	if pasta_web != "modelos" and not OS.has_feature("web") and FileAccess.file_exists(arq_fora):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(arq_fora, st) == OK:
			no = doc.generate_scene(st)
	elif ResourceLoader.exists(PASTA + glb + ".glb"):
		no = load(PASTA + glb + ".glb").instantiate()
	elif OS.has_feature("web"):
		var http := HTTPRequest.new()
		add_child(http)
		# HTTPRequest quer o endereco inteiro: modelos/ fica do lado do index.html
		var base := str(JavaScriptBridge.eval("location.href")).get_slice("?", 0).get_base_dir()
		http.request("%s/%s/%s.glb" % [base, pasta_web, glb])
		var r: Array = await http.request_completed
		http.queue_free()
		if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200:
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_buffer(r[3], "", st) == OK:
				no = doc.generate_scene(st)
		else:
			push_warning("modelo %s: %s %s" % [glb, r[0], r[1]])
	if no:
		_nomear_binds(no)
	_prontos[glb] = no
	_chegou.emit(glb)


# skin com os ossos pelo nome (osso<i>): a peca vai pro esqueleto de outro modelo
static func _nomear_binds(no: Node) -> void:
	for m: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		var sk := m.get_node_or_null(m.skeleton) as Skeleton3D
		if m.skin == null or sk == null:
			continue
		m.skin = m.skin.duplicate()
		for b in m.skin.get_bind_count():
			if m.skin.get_bind_name(b) == &"" and m.skin.get_bind_bone(b) >= 0:
				m.skin.set_bind_name(b, sk.get_bone_name(m.skin.get_bind_bone(b)))


# rotacao do MU (graus, AngleQuaternion do cliente) como Basis
static func giro_mu(ax: float, ay: float, az: float) -> Basis:
	var hx := deg_to_rad(ax) * 0.5
	var hy := deg_to_rad(ay) * 0.5
	var hz := deg_to_rad(az) * 0.5
	var sx := sin(hx)
	var cx := cos(hx)
	var sy := sin(hy)
	var cy := cos(hy)
	var sz := sin(hz)
	var cz := cos(hz)
	var q := Quaternion(sx * cy * cz - cx * sy * sz, cx * sy * cz + sx * cy * sz,
		cx * cy * sz - sx * sy * cz, cx * cy * cz + sx * sy * sz)
	return Basis(q.normalized())


static func transf_mu(ax: float, ay: float, az: float, tx: float, ty: float, tz: float) -> Transform3D:
	return Transform3D(giro_mu(ax, ay, az), Vector3(tx, ty, tz))
