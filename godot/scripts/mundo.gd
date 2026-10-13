extends Node3D
# Mundo do MU montado a partir do que o conversor gerou em dados/mundo<N>/.
# Tudo do mapa fica dentro de "mu", que esta nas coordenadas do MU
# (Z pra cima, 100 unidades por tile); o Godot ve 1 tile = 1 metro.

const TILES := 256
var numero := 1
var pasta := ""
var mu: Node3D
var altura: Image
var camera: Camera3D
# camera no jeito do MU: alvo em tiles, giro e inclinacao em graus, distancia em metros
var alvo := Vector2(138, 124)
var giro := -45.0
var inclinacao := 48.0
var distancia := 12.0


func _ready() -> void:
	_ler_parametros()
	pasta = "res://dados/mundo%d/" % numero
	mu = Node3D.new()
	mu.name = "MU"
	mu.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2) * 0.01, Vector3.ZERO)
	add_child(mu)
	_ambiente()
	altura = (load(pasta + "altura.png") as Texture2D).get_image()
	_terreno()
	var n := _objetos()
	camera = Camera3D.new()
	camera.far = 500.0
	camera.fov = 35.0
	add_child(camera)
	# neblina so de perto (vista de cima fica limpa)
	$WorldEnvironment.environment.fog_enabled = distancia < 40.0
	_mirar()
	print("TESTE mundo %d · objetos %d" % [numero, n])


# ?mundo=1&x=138&y=124&giro=-45&inclinacao=48&dist=12 (navegador) ou -- --x 138 ... (headless)
func _ler_parametros() -> void:
	var p := {}
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search")
		for par in str(q).trim_prefix("?").split("&", false):
			var kv := par.split("=")
			if kv.size() == 2:
				p[kv[0]] = kv[1]
	var a := OS.get_cmdline_user_args()
	for i in range(0, a.size() - 1):
		if a[i].begins_with("--"):
			p[a[i].substr(2)] = a[i + 1]
	numero = int(p.get("mundo", numero))
	alvo = Vector2(float(p.get("x", alvo.x)), float(p.get("y", alvo.y)))
	giro = float(p.get("giro", giro))
	inclinacao = float(p.get("inclinacao", inclinacao))
	distancia = float(p.get("dist", distancia))


func _ambiente() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.03)
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55, -35, 0)
	sol.light_energy = 0.8
	add_child(sol)


# altura do MU (unidades) no ponto em tiles
func altura_em(x: float, y: float) -> float:
	var ix := clampi(int(x), 0, TILES - 1)
	var iy := clampi(int(y), 0, TILES - 1)
	return altura.get_pixel(ix, iy).r * 255.0 * 1.5


func _terreno() -> void:
	var mapa := (load(pasta + "mapa.png") as Texture2D).get_image()
	var luz := (load(pasta + "luz.png") as Texture2D).get_image()
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string(pasta + "tiles.json"))
	var imgs: Array[Image] = []
	var repete := PackedFloat32Array()
	repete.resize(32)
	repete.fill(4.0)
	var por_indice := {}
	for t in lista:
		por_indice[int(t.i)] = t
	var primeira: Image = null
	for i in 32:
		var img: Image = null
		if por_indice.has(i):
			img = (load(pasta + "tiles/%d.png" % i) as Texture2D).get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.generate_mipmaps()
			repete[i] = float(por_indice[i].repete)
			if primeira == null:
				primeira = img
		imgs.append(img)
	for i in 32:
		if imgs[i] == null:
			imgs[i] = primeira
	var arr := Texture2DArray.new()
	arr.create_from_images(imgs)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in TILES:
		for x in TILES:
			var c := luz.get_pixel(x, y)
			c.a = mapa.get_pixel(x, y).b
			st.set_color(c)
			st.set_uv(Vector2(x, y))
			st.add_vertex(Vector3(x * 100.0, y * 100.0, altura_em(x, y)))
	for y in TILES - 1:
		for x in TILES - 1:
			var i := y * TILES + x
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + TILES + 1)
			st.add_index(i)
			st.add_index(i + TILES + 1)
			st.add_index(i + TILES)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/terreno.gdshader")
	mat.set_shader_parameter("mapa", ImageTexture.create_from_image(mapa))
	mat.set_shader_parameter("tiles", arr)
	mat.set_shader_parameter("repete", repete)
	mat.set_shader_parameter("brilho", 1.6)
	var mi := MeshInstance3D.new()
	mi.name = "Terreno"
	mi.mesh = st.commit()
	mi.material_override = mat
	mu.add_child(mi)


func _objetos() -> int:
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string(pasta + "objetos.json"))
	var cenas := {}
	var raiz := Node3D.new()
	raiz.name = "Objetos"
	mu.add_child(raiz)
	for o in lista:
		# marcadores de luz e de pose: o cliente original nao desenha
		if mundo_invisivel(o.m):
			continue
		if not cenas.has(o.m):
			cenas[o.m] = load(pasta + "modelos/%s.glb" % o.m)
		var cena: PackedScene = cenas[o.m]
		if cena == null:
			continue
		var n := cena.instantiate() as Node3D
		var q := Quaternion(o.q[0], o.q[1], o.q[2], o.q[3])
		n.transform = Transform3D(Basis(q) * float(o.s), Vector3(o.p[0], o.p[1], o.p[2]))
		raiz.add_child(n)
	return raiz.get_child_count()


func mundo_invisivel(m: String) -> bool:
	return numero == 1 and (m.begins_with("light0") or m == "posebox01")


func _mirar() -> void:
	var a := Vector3(alvo.x, altura_em(alvo.x, alvo.y) / 100.0, -alvo.y)
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(inclinacao)).rotated(Vector3.UP, deg_to_rad(giro))
	camera.position = a + dir * distancia
	camera.look_at(a, Vector3.UP)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			distancia = maxf(3.0, distancia * 0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distancia = minf(80.0, distancia * 1.1)
		_mirar()


func _process(dt: float) -> void:
	var m := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): m.y += 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): m.y -= 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): m.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): m.x += 1
	var g := 0.0
	if Input.is_key_pressed(KEY_Q): g -= 1
	if Input.is_key_pressed(KEY_E): g += 1
	if m == Vector2.ZERO and g == 0.0:
		return
	giro += g * 60.0 * dt
	# andar relativo a camera: pra frente e pra onde ela olha no chao
	var f := Vector2(-sin(deg_to_rad(giro)), -cos(deg_to_rad(giro)))
	var d := Vector2(cos(deg_to_rad(giro)), -sin(deg_to_rad(giro)))
	var passo := (f * m.y + d * m.x) * 15.0 * dt
	alvo += Vector2(passo.x, -passo.y)
	_mirar()
