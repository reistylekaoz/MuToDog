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
var giro := 45.0  # o MU usa -45; o Murilo pediu o mapa 90 graus no sentido horario (16/10)
var inclinacao := 48.0
var distancia := 12.0
# no jogo (jogo.gd): a camera segue o personagem e o mapa diz onde da pra andar
var modo_jogo := false
# camera parada (tela de escolha de personagem): o transform pronto, a abertura e o fundo
var camera_fixa: Transform3D
var fixa := false
var fixa_fov := 35.0
var fixa_longe := 500.0
var seguir: Node3D
var tem_dados := true
var atributos := PackedByteArray()
var grade := AStarGrid2D.new()
var mapa_img: Image
var ambiente: Ambiente
var _lista_objetos: Array = []
# [no, objeto do json] de cada objeto desenhado (o Ambiente acha porta, brilho e fogo por aqui)
var nos_objetos: Array = []
# material do GLB -> o mesmo com a luz do MU (objeto.gdshader), um por textura
var materiais := {}
# o cliente nao tem esse fator; aqui ele acerta o tom com o jogo original (teclas - e =)
var brilho := 2.0
signal brilho_mudou(v: float)
var _luz_tex: Texture2D
var arquivo_luz := "luz.png"   # TerrainLight do mapa; o Crywolf troca pela 1 ou 2


func _ready() -> void:
	if not modo_jogo:
		_ler_parametros()
		await PacoteMapa.carregar(self, numero)
	pasta = "res://dados/mundo%d/" % numero
	mu = Node3D.new()
	mu.name = "MU"
	mu.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2) * 0.01, Vector3.ZERO)
	add_child(mu)
	_ambiente()
	var n := 0
	tem_dados = ResourceLoader.exists(pasta + "altura.png")
	if tem_dados:
		altura = (load(pasta + "altura.png") as Texture2D).get_image()
		_terreno()
		n = _objetos()
		ambiente = Ambiente.new()
		ambiente.name = "Ambiente"
		add_child(ambiente)
		ambiente.montar(self, mapa_img, (load(pasta + "luz.png") as Texture2D).get_image(), _lista_objetos)
		if numero in Ambiente.SEM_CHAO:
			mu.get_node("Terreno").visible = false
		if Ambiente.CEU.has(numero):
			$WorldEnvironment.environment.background_color = Ambiente.CEU[numero]
			$WorldEnvironment.environment.fog_light_color = Ambiente.CEU[numero]
	else:
		# mapa ainda nao convertido: chao liso com grade, so pra ver quem esta onde
		altura = Image.create(TILES, TILES, false, Image.FORMAT_L8)
		_chao_liso()
	_grade()
	camera = Camera3D.new()
	camera.far = 500.0
	camera.fov = 35.0
	add_child(camera)
	# neblina so de perto (vista de cima fica limpa)
	$WorldEnvironment.environment.fog_enabled = distancia < 40.0
	_mirar()
	print("TESTE mundo %d · objetos %d · fogos %d · grama %d" % [numero, n, ambiente.fogos if ambiente else 0, ambiente.gramas if ambiente else 0])


# ?mundo=1&x=138&y=124&giro=45&inclinacao=48&dist=12 (navegador) ou -- --x 138 ... (headless)
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
	brilho = float(p.get("brilho", brilho))


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
	# bilinear entre os vertices (o vertice (x, y) do terreno fica no canto do tile)
	var x0 := clampi(int(floor(x)), 0, TILES - 1)
	var y0 := clampi(int(floor(y)), 0, TILES - 1)
	var x1 := mini(x0 + 1, TILES - 1)
	var y1 := mini(y0 + 1, TILES - 1)
	var fx := clampf(x - x0, 0.0, 1.0)
	var fy := clampf(y - y0, 0.0, 1.0)
	var a := lerpf(altura.get_pixel(x0, y0).r, altura.get_pixel(x1, y0).r, fx)
	var b := lerpf(altura.get_pixel(x0, y1).r, altura.get_pixel(x1, y1).r, fx)
	return lerpf(a, b, fy) * 255.0 * 1.5


func _chao_liso() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(TILES, TILES)
	pm.subdivide_width = TILES - 1
	pm.subdivide_depth = TILES - 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.17, 0.18)
	pm.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "ChaoLiso"
	mi.mesh = pm
	mi.position = Vector3(TILES / 2.0, 0, -TILES / 2.0)
	add_child(mi)


# onde da pra andar: atributo do terreno (EncTerrain.att) no alfa do mapa.png;
# 4 = parede, 8 = sem chao (GameLogic: TerrainAttributeType)
func _grade() -> void:
	atributos.resize(TILES * TILES)
	if tem_dados:
		var mapa := (load(pasta + "mapa.png") as Texture2D).get_image()
		for y in TILES:
			for x in TILES:
				atributos[y * TILES + x] = int(round(mapa.get_pixel(x, y).a * 255.0))
	grade.region = Rect2i(0, 0, TILES, TILES)
	grade.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grade.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grade.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grade.update()
	for y in TILES:
		for x in TILES:
			if not anda(x, y):
				grade.set_point_solid(Vector2i(x, y))


# C1 46 (ChangeTerrainAttributes): liga ou tira o atributo num retangulo e refaz o caminho la
# (o portao e a ponte do Blood Castle, a entrada dos eventos)
func mudar_atributo(atributo: int, tirar: bool, x1: int, y1: int, x2: int, y2: int) -> void:
	for y in range(maxi(y1, 0), mini(y2, TILES - 1) + 1):
		for x in range(maxi(x1, 0), mini(x2, TILES - 1) + 1):
			var i := y * TILES + x
			atributos[i] = (atributos[i] & ~atributo) if tirar else (atributos[i] | atributo)
			grade.set_point_solid(Vector2i(x, y), not anda(x, y))


func anda(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= TILES or y >= TILES:
		return false
	return atributos[y * TILES + x] & 0x0C == 0


# textura da camada 1 no tile (o cliente chama de HeroTile: 4 = chao da taverna na Lorencia)
func camada1(x: int, y: int) -> int:
	if mapa_img == null:
		return -1
	return int(round(mapa_img.get_pixel(clampi(x, 0, TILES - 1), clampi(y, 0, TILES - 1)).r * 255.0))


func zona_segura(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < TILES and y < TILES and atributos[y * TILES + x] & 0x01 != 0


# caminho em tiles (sem o ponto de partida); vazio se nao der
func caminho(de: Vector2i, para: Vector2i) -> Array[Vector2i]:
	var r: Array[Vector2i] = []
	if not grade.region.has_point(de) or not grade.region.has_point(para):
		return r
	var pontos := grade.get_id_path(de, para, true)
	for i in range(1, pontos.size()):
		r.append(pontos[i])
	return r


# centro do tile (coordenada do servidor) no espaco do Godot
func no_tile(x: float, y: float) -> Vector3:
	return Vector3(x + 0.5, altura_em(x + 0.5, y + 0.5) / 100.0, -(y + 0.5))


# tile embaixo do mouse: anda pelo raio da camera ate passar do chao
func tile_na_tela(tela: Vector2) -> Vector2i:
	var o := camera.project_ray_origin(tela)
	var d := camera.project_ray_normal(tela)
	var p := o
	for i in 3000:
		p += d * 0.1
		var tx := p.x
		var ty := -p.z
		if tx < 0 or ty < 0 or tx >= TILES or ty >= TILES:
			if p.y < -5.0:
				break
			continue
		if p.y <= altura_em(tx, ty) / 100.0:
			return Vector2i(int(tx), int(ty))
	return Vector2i(-1, -1)


func _terreno() -> void:
	var mapa := (load(pasta + "mapa.png") as Texture2D).get_image()
	mapa_img = mapa
	var luz := (load(pasta + arquivo_luz) as Texture2D).get_image()
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
	mat.set_shader_parameter("brilho", brilho_mapa())
	if numero == 9:
		mat.set_shader_parameter("agua_vel", 0.025)   # Tarkan: a agua corre na metade
	if ResourceLoader.exists(pasta + "agua/0.png"):
		var quadros: Array[Image] = []
		for i in 32:
			var q := (load(pasta + "agua/%d.png" % i) as Texture2D).get_image()
			q.convert(Image.FORMAT_RGBA8)
			q.generate_mipmaps()
			quadros.append(q)
		var aq := Texture2DArray.new()
		aq.create_from_images(quadros)
		mat.set_shader_parameter("agua_quadros", aq)
		mat.set_shader_parameter("agua_soma", true)
	var mi := MeshInstance3D.new()
	mi.name = "Terreno"
	mi.mesh = st.commit()
	mi.material_override = mat
	mu.add_child(mi)


func _objetos() -> int:
	var lista: Array = JSON.parse_string(FileAccess.get_file_as_string(pasta + "objetos.json"))
	_lista_objetos = lista
	var cenas := {}
	var raiz := Node3D.new()
	raiz.name = "Objetos"
	mu.add_child(raiz)
	for o in lista:
		# marcadores de luz e de pose: o cliente original nao desenha
		if mundo_invisivel(o.m) or int(o.t) in Ambiente.ESCONDER.get(numero, []) or int(o.t) in Ambiente.NUVENS.get(numero, []):
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
		_luz_do_mu(n)
		nos_objetos.append([n, o])
	return raiz.get_child_count()


# troca o material de cada face pelo da luz do MU (objeto.gdshader)
func _luz_do_mu(n: Node) -> void:
	if _luz_tex == null:
		_luz_tex = load(pasta + arquivo_luz) as Texture2D
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if orig == null:
				continue
			if not materiais.has(orig):
				var m := ShaderMaterial.new()
				m.shader = preload("res://scripts/objeto.gdshader")
				m.set_shader_parameter("textura", orig.albedo_texture)
				m.set_shader_parameter("luz_mapa", _luz_tex)
				m.set_shader_parameter("brilho", brilho_mapa())
				if orig.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					m.set_shader_parameter("corte", maxf(orig.alpha_scissor_threshold, 0.25))
				materiais[orig] = m
			mi.set_surface_override_material(i, materiais[orig])


# o brilho escolhido (2,0 na Lorencia) vezes o acerto do mapa: Devias e neve quase branca
# e a luz pintada dela ja e clara, entao com 2,0 estoura (Ambiente.BRILHO_MAPA)
# OpenTerrainLight no meio do jogo (Crywolf pela ocupacao): refaz o chao e troca a luz dos objetos
func trocar_luz(nome: String) -> void:
	if nome == arquivo_luz or not tem_dados or not ResourceLoader.exists(pasta + nome):
		return
	arquivo_luz = nome
	var velho := mu.get_node_or_null("Terreno")
	var visivel: bool = velho == null or velho.visible
	if velho:
		mu.remove_child(velho)
		velho.queue_free()
	_terreno()
	mu.get_node("Terreno").visible = visivel
	_luz_tex = load(pasta + nome) as Texture2D
	for m: ShaderMaterial in materiais.values():
		m.set_shader_parameter("luz_mapa", _luz_tex)


func brilho_mapa() -> float:
	return brilho * float(Ambiente.BRILHO_MAPA.get(numero, 1.0))


func definir_brilho(v: float) -> void:
	brilho = clampf(v, 0.5, 3.0)
	var t := mu.get_node_or_null("Terreno") as MeshInstance3D
	if t:
		t.material_override.set_shader_parameter("brilho", brilho_mapa())
	for g in mu.get_children():
		if g.name.begins_with("Grama"):
			(g as MeshInstance3D).material_override.set_shader_parameter("brilho", brilho_mapa())
	for m: ShaderMaterial in materiais.values():
		m.set_shader_parameter("brilho", brilho_mapa())


# Telhado que some quando o heroi entra na casa (ZzzObject.cpp MoveObject): na Lorencia as pecas
# MODEL_HOUSE_WALL01 + 4 e + 5 (125 e 126) com o heroi no chao de textura 4 (dentro da taverna e das
# casas); em Devias os objetos 81, 82, 96, 98 e 99 no chao 3 ou de 10 em diante. O Alpha do ZzzAI.cpp anda
# 0,05 por quadro do cliente (25 por segundo): 1,25 por segundo. Inteiro, o telhado volta pro material de
# sempre; so no meio do caminho ele usa a copia com alfa (objeto.gdshader + ALPHA).
const TELHADOS := {1: [125, 126], 3: [81, 82, 96, 98, 99]}
var _telhado: Array = []    # [MeshInstance3D, superficie, material de sempre, material com alfa]
var _telhado_nos: Array = []
var _telhado_pronto := false
var _telhado_alfa := 1.0
var _telhado_alvo := 1.0
static var _sh_telhado: Shader


func dentro_de_casa(x: int, y: int) -> bool:
	var c := camada1(x, y)
	if numero == 1:
		return c == 4
	if numero == 3:
		return c == 3 or c >= 10
	return false


func atualizar_telhados(x: int, y: int, dt: float) -> void:
	if not TELHADOS.has(numero):
		return
	if not _telhado_pronto:
		_preparar_telhados()
	if _telhado.is_empty():
		return
	var alvo := 0.0 if dentro_de_casa(x, y) else 1.0
	if alvo != _telhado_alvo:
		_telhado_alvo = alvo
		print("TESTE telhado %s em %d,%d (%d pecas)" % ["some" if alvo == 0.0 else "volta", x, y, _telhado_nos.size()])
	if is_equal_approx(_telhado_alfa, alvo):
		return
	_telhado_alfa = move_toward(_telhado_alfa, alvo, 1.25 * dt)
	var inteiro := _telhado_alfa >= 1.0
	for e in _telhado:
		var mi: MeshInstance3D = e[0]
		mi.set_surface_override_material(e[1], e[2] if inteiro else e[3])
		if not inteiro:
			(e[3] as ShaderMaterial).set_shader_parameter("alfa", _telhado_alfa)
	for n: Node3D in _telhado_nos:
		n.visible = _telhado_alfa >= 0.01


func _preparar_telhados() -> void:
	_telhado_pronto = true
	if _sh_telhado == null:
		var codigo := (preload("res://scripts/objeto.gdshader") as Shader).code
		codigo = codigo.replace("render_mode unshaded, cull_disabled;", "render_mode unshaded, cull_disabled, depth_draw_always;\nuniform float alfa = 1.0;")
		codigo = codigo.replace("ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));", "ALBEDO = pow(clamp(c, 0.0, 1.0), vec3(2.2));\n\tALPHA = alfa;")
		_sh_telhado = Shader.new()
		_sh_telhado.code = codigo
	var tipos: Array = TELHADOS[numero]
	var copias := {}
	for par in nos_objetos:
		if not is_instance_valid(par[0]) or int(par[1].t) not in tipos:
			continue
		_telhado_nos.append(par[0])
		for mi: MeshInstance3D in (par[0] as Node).find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null:
				continue
			for i in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(i) as ShaderMaterial
				if m == null:
					continue
				if not copias.has(m):
					var c := m.duplicate() as ShaderMaterial
					c.shader = _sh_telhado
					copias[m] = c
					materiais[RefCounted.new()] = c   # segue o brilho e a luz do mapa (teclas - e =)
				_telhado.append([mi, i, m, copias[m]])


func mundo_invisivel(m: String) -> bool:
	return numero == 1 and (m.begins_with("light0") or m == "posebox01")


func _mirar() -> void:
	if fixa:
		camera.global_transform = camera_fixa
		camera.fov = fixa_fov
		camera.far = fixa_longe
		return
	var a := Vector3(alvo.x, altura_em(alvo.x, alvo.y) / 100.0, -alvo.y)
	if seguir:
		a = seguir.global_position + Vector3(0, 1.0, 0)
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, -deg_to_rad(inclinacao)).rotated(Vector3.UP, deg_to_rad(giro))
	camera.position = a + dir * distancia
	camera.look_at(a, Vector3.UP)


func _unhandled_input(ev: InputEvent) -> void:
	if fixa:
		return
	if ev is InputEventKey and ev.pressed and ev.keycode in [KEY_MINUS, KEY_EQUAL, KEY_KP_SUBTRACT, KEY_KP_ADD]:
		definir_brilho(brilho + (0.1 if ev.keycode in [KEY_EQUAL, KEY_KP_ADD] else -0.1))
		brilho_mudou.emit(brilho)
		return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			distancia = maxf(3.0, distancia * 0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distancia = minf(80.0, distancia * 1.1)
		_mirar()


func _process(dt: float) -> void:
	if fixa:
		return
	if modo_jogo:
		var g2 := 0.0
		# no jogo Q W E R sao as pocoes (como no MU): a camera gira nas setas
		if Input.is_key_pressed(KEY_LEFT): g2 -= 1
		if Input.is_key_pressed(KEY_RIGHT): g2 += 1
		giro += g2 * 60.0 * dt
		_mirar()
		return
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


# CreateCastleMark: o C1 B9 02 traz a marca 8x8 da guilda dona; o cliente pinta o Flag.tga (64x64, a malha 1 do
# objeto 12 do Valley of Loren, GMBattleCastle RenderBattleCastleObjectMesh) com a marca 32x32 no meio, a borda
# azul degrade e o resto em cinza pela linha. Devolve a imagem pra quem testa.
const COR_MARCA := [Color8(0, 0, 0, 0), Color8(0, 0, 0), Color8(128, 128, 128), Color8(255, 255, 255),
	Color8(255, 0, 0), Color8(255, 128, 0), Color8(255, 255, 0), Color8(128, 255, 0), Color8(0, 255, 0),
	Color8(0, 255, 128), Color8(0, 255, 255), Color8(0, 128, 255), Color8(0, 0, 255), Color8(128, 0, 255),
	Color8(255, 0, 255), Color8(255, 0, 128)]


static func imagem_marca_castelo(marca: PackedByteArray) -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for i in 64:
		for j in 64:
			var c: Color
			if j >= 16 and j < 48 and i >= 16 and i < 48:
				var k := (j - 16) / 4 + ((i - 16) / 4) * 8
				c = COR_MARCA[marca[k] & 15] if k < marca.size() else COR_MARCA[0]
			elif j < 3 or j > 60 or i < 10 or i > 54:
				c = Color8(int(50 + i / 100.0 * 255) & 255, int(50 + i / 100.0 * 160) & 255, 0)
			else:
				c = Color8(i, i, i)
			img.set_pixel(j, i, c)
	return img


func marca_castelo(marca: PackedByteArray) -> int:
	var tex := ImageTexture.create_from_image(imagem_marca_castelo(marca))
	var feitas := 0
	for par in nos_objetos:
		if par[1].m != "object13" or not is_instance_valid(par[0]):
			continue
		for mi: MeshInstance3D in (par[0] as Node).find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or mi.mesh.get_surface_count() < 2:
				continue
			var m := mi.get_surface_override_material(1) as ShaderMaterial
			if m:
				m.set_shader_parameter("textura", tex)
				feitas += 1
	return feitas


# invasao do dragao: o chao escurece em volta do heroi e o vento da grama corre (Bichos._mexer_invasao)
func sombra_dragao(c: Vector2, ligado: bool) -> void:
	var t := mu.get_node_or_null("Terreno") as MeshInstance3D
	if t:
		t.material_override.set_shader_parameter("sombra", Vector3(c.x, c.y, 16.0 if ligado else 0.0))
	for g in mu.get_children():
		if g.name.begins_with("Grama"):
			(g as MeshInstance3D).material_override.set_shader_parameter("vento", 10.0 if ligado else 2.0)
