class_name Polido
# Remasterizacao (01/11/2026). A luz nova vale no jogo desde 02/11 (Option > New lighting, guardado em
# user://opcoes.cfg; ligada no PC, desligada no navegador). No visualizador (?vista=1) so com ?polido:
# ?polido=luz  luz do Godot com sombra, ceu, neblina, brilho (glow) e acerto de cor por cima da luz do MU
# ?polido=hd   texturas ampliadas pela IA (ferramentas/gerar_hd.sh -> dados/hd/). No jogo do PC o HD vem
#              dos hd_*.pck (testes/exportar_hd.sh) montados por cima das originais: nao passa por aqui
# ?polido=tudo os dois
# ?polido=jogo a luz como no jogo (sem o ceu e a neblina de areia), pras fotos de comparacao
# ?heroi=0=0,5;2=7,1;...;niveis=0:13,3:11 poe um Dark Knight vestido no alvo da camera (?heroi_giro=graus)
# Os itens HD vem de modelos_hd/ (ferramentas/glb_hd.py) do lado do index.html.

static var luz := false
static var hd := false
static var _visualizador := false   # ?polido manda; sem ele o visualizador fica no original
static var _ceu := false            # ceu e neblina de areia: so ?polido=luz|tudo
const ARQ := "user://opcoes.cfg"
# a luz nova so nos mapas a ceu aberto (mundo = mapa + 1, dados/mapas.json): Lorencia, Devias, Noria,
# Arena, Tarkan, Icarus, Valley of Loren, Aida, Crywolf, Kanturu I e III, Elvenland, Swamp, LaCleon,
# Santa Village, Vulcanus, tela de login, Loren Market e Karutan. Dungeon, torre, castelo e evento ficam como o cliente.
const ABERTOS := [1, 3, 4, 7, 9, 11, 31, 34, 35, 38, 39, 52, 57, 58, 63, 64, 74, 80, 81, 82]


# a luz nova no jogo: o que o Option guardou (ligada no PC, desligada no navegador)
static func opcao() -> bool:
	var c := ConfigFile.new()
	if c.load(ARQ) == OK:
		return bool(c.get_value("grafico", "luz", not OS.has_feature("web")))
	return not OS.has_feature("web")


# texturas HD no PC (hd_*.pck montados pelo PacoteMapa.montar_pc): ligadas se nada foi guardado
static func opcao_hd() -> bool:
	var c := ConfigFile.new()
	if c.load(ARQ) == OK:
		return bool(c.get_value("grafico", "hd", true))
	return true


static func guardar_opcao_hd(v: bool) -> void:
	var c := ConfigFile.new()
	c.load(ARQ)
	c.set_value("grafico", "hd", v)
	c.save(ARQ)


static func guardar_opcao(v: bool) -> void:
	var c := ConfigFile.new()
	c.load(ARQ)
	c.set_value("grafico", "luz", v)
	c.save(ARQ)


static func ler(p: Dictionary) -> void:
	_visualizador = true
	var m: String = p.get("polido", "")
	luz = m in ["luz", "tudo", "jogo"]
	_ceu = m == "luz" or m == "tudo"
	hd = m == "hd" or m == "tudo"
	if hd:
		ModelosMU.pasta_web = "modelos_hd"
	_foto = str(p.get("foto", ""))


# -- --foto /caminho.png (jogo nativo com tela, Xvfb): grava a tela depois de 8 s e fecha
static var _foto := ""

static func agendar_foto(no: Node) -> void:
	if _foto == "" or OS.has_feature("web"):
		return
	await no.get_tree().create_timer(float(OS.get_environment("ESPERA")) if OS.get_environment("ESPERA") != "" else 8.0).timeout
	await RenderingServer.frame_post_draw
	no.get_viewport().get_texture().get_image().save_png(_foto)
	print("TESTE foto %s" % _foto)
	no.get_tree().quit()


static func caminho_hd(t: Texture2D) -> String:
	if t == null or not t.resource_path.begins_with("res://dados/"):
		return ""
	var p := t.resource_path.replace("res://dados/", "res://dados/hd/")
	return p if ResourceLoader.exists(p) else ""


# no _ready do mundo: o visualizador segue o ?polido, o jogo segue o Option
static func no_mundo(mundo: Node3D) -> void:
	if not _visualizador:
		luz = opcao() and mundo.numero in ABERTOS
		# --foto tambem no jogo (testes/foto_jogo.sh): grava a tela depois de ESPERA s
		var args := OS.get_cmdline_user_args()
		var i := args.find("--foto")
		if i >= 0 and i + 1 < args.size():
			_foto = args[i + 1]
	if luz or hd:
		aplicar(mundo)


# Option > New lighting no meio do jogo: liga ou desliga no mapa aberto
static func trocar(mundo: Node3D, v: bool) -> void:
	guardar_opcao(v)
	v = v and mundo.numero in ABERTOS
	if v == luz:
		return
	luz = v
	if v:
		aplicar(mundo)
	else:
		desfazer(mundo)


# o que a luz nova muda no Environment do mapa (o desligar volta cada um)
const PROPS_ENV := ["background_mode", "sky", "ambient_light_source", "ambient_light_color", "ambient_light_energy",
	"fog_enabled", "fog_light_color", "fog_density", "fog_sky_affect", "tonemap_mode", "tonemap_exposure",
	"glow_enabled", "glow_intensity", "glow_bloom", "glow_hdr_threshold", "glow_blend_mode",
	"adjustment_enabled", "adjustment_contrast", "adjustment_saturation"]
const SH_OBJETO := "res://scripts/objeto.gdshader"
const SH_TERRENO := "res://scripts/terreno.gdshader"
const SH_OBJETO_POLIDO := "res://scripts/objeto_polido.gdshader"
const SH_TERRENO_POLIDO := "res://scripts/terreno_polido.gdshader"


static func aplicar(mundo: Node3D) -> void:
	var objeto_sh: Shader = load(SH_OBJETO_POLIDO) if luz else null
	for orig in mundo.materiais:
		var m: ShaderMaterial = mundo.materiais[orig]
		# so o objeto comum do mapa: efeito somado, agua e telhado seguem com o shader deles
		if objeto_sh and m.shader and m.shader.resource_path == SH_OBJETO:
			_trocar_shader(m, objeto_sh)
		if not orig is BaseMaterial3D:
			continue
		var p := caminho_hd(orig.albedo_texture) if hd else ""
		if p != "":
			m.set_shader_parameter("textura", load(p))
			if ResourceLoader.exists(p.replace(".png", "_n.png")):
				m.set_shader_parameter("normal_tex", load(p.replace(".png", "_n.png")))
				m.set_shader_parameter("usar_normal", true)
	var t := mundo.mu.get_node_or_null("Terreno") as MeshInstance3D
	if t:
		var mat := t.material_override as ShaderMaterial
		if luz and mat.shader.resource_path == SH_TERRENO:
			_trocar_shader(mat, load(SH_TERRENO_POLIDO))
			t.set_meta("malha_original", t.mesh)
			t.mesh = _com_normais(t.mesh)
		if hd:
			_tiles_hd(mundo, mat)
	if luz:
		_luz(mundo)
	print("TESTE polido luz=%s hd=%s mundo=%d" % [luz, hd, mundo.numero])


# volta pro jeito do cliente (Option > New lighting desligado)
static func desfazer(mundo: Node3D) -> void:
	var sh_o: Shader = load(SH_OBJETO)
	for m: ShaderMaterial in mundo.materiais.values():
		if m.shader and m.shader.resource_path == SH_OBJETO_POLIDO:
			_trocar_shader(m, sh_o)
	var t := mundo.mu.get_node_or_null("Terreno") as MeshInstance3D
	if t:
		var mat := t.material_override as ShaderMaterial
		if mat.shader.resource_path == SH_TERRENO_POLIDO:
			_trocar_shader(mat, load(SH_TERRENO))
		if t.has_meta("malha_original"):
			t.mesh = t.get_meta("malha_original")
			t.remove_meta("malha_original")
	var we := mundo.get_node("WorldEnvironment") as WorldEnvironment
	if we.has_meta("antes"):
		var antes: Dictionary = we.get_meta("antes")
		for k in antes:
			we.environment.set(k, antes[k])
		we.remove_meta("antes")
	for sol: DirectionalLight3D in mundo.find_children("*", "DirectionalLight3D", false, false):
		if sol.has_meta("antes"):
			var a: Array = sol.get_meta("antes")
			sol.rotation_degrees = a[0]
			sol.light_color = a[1]
			sol.light_energy = a[2]
			sol.shadow_enabled = false
			sol.remove_meta("antes")
	print("TESTE polido desligado mundo=%d" % mundo.numero)


# troca o shader guardando os valores (o ShaderMaterial pode perder o que o shader novo nao tinha)
static func _trocar_shader(m: ShaderMaterial, sh: Shader) -> void:
	var valores := {}
	for u in m.shader.get_shader_uniform_list():
		valores[u.name] = m.get_shader_parameter(u.name)
	m.shader = sh
	for k in valores:
		m.set_shader_parameter(k, valores[k])


# o chao do MU nao tem normal (era sem luz): gera normal e tangente, com a normal pra cima (Z do MU)
static func _com_normais(mesh: Mesh) -> Mesh:
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	st.generate_tangents()
	var a := st.commit_to_arrays()
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	if n.size() > 0 and n[n.size() / 2].z < 0.0:
		for i in n.size():
			n[i] = -n[i]
		a[Mesh.ARRAY_NORMAL] = n
	var novo := ArrayMesh.new()
	novo.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return novo


static func _tiles_hd(mundo: Node3D, mat: ShaderMaterial) -> void:
	var pasta := "res://dados/hd/mundo%d/tiles/" % mundo.numero
	var velhas := mat.get_shader_parameter("tiles") as Texture2DArray
	if velhas == null or not ResourceLoader.exists(pasta + "0.png"):
		return
	var cores: Array[Image] = []
	var normais: Array[Image] = []
	var tam := Vector2i.ZERO
	for i in velhas.get_layers():
		var c: Image = null
		var n: Image = null
		var arq := pasta + "%d.png" % i
		if ResourceLoader.exists(arq):
			c = (load(arq) as Texture2D).get_image()
			n = (load(arq.replace(".png", "_n.png")) as Texture2D).get_image()
		else:
			c = velhas.get_layer_data(i)
			n = null
		c.decompress()
		c.clear_mipmaps()
		c.convert(Image.FORMAT_RGBA8)
		if tam == Vector2i.ZERO:
			tam = c.get_size()
		if c.get_size() != tam:
			c.resize(tam.x, tam.y, Image.INTERPOLATE_LANCZOS)
		c.generate_mipmaps()
		cores.append(c)
		if n == null:
			n = Image.create(tam.x, tam.y, false, Image.FORMAT_RGBA8)
			n.fill(Color(0.5, 0.5, 1.0))
		n.decompress()
		n.clear_mipmaps()
		n.convert(Image.FORMAT_RGBA8)
		if n.get_size() != tam:
			n.resize(tam.x, tam.y)
		n.generate_mipmaps()
		normais.append(n)
	var ac := Texture2DArray.new()
	ac.create_from_images(cores)
	mat.set_shader_parameter("tiles", ac)
	var an := Texture2DArray.new()
	an.create_from_images(normais)
	mat.set_shader_parameter("tiles_normal", an)
	mat.set_shader_parameter("usar_normal", true)


static func _luz(mundo: Node3D) -> void:
	var we := mundo.get_node("WorldEnvironment") as WorldEnvironment
	var env := we.environment
	if not we.has_meta("antes"):
		var antes := {}
		for k in PROPS_ENV:
			antes[k] = env.get(k)
		we.set_meta("antes", antes)
	_luz_comum(env)
	for sol: DirectionalLight3D in mundo.find_children("*", "DirectionalLight3D", false, false):
		if not sol.has_meta("antes"):
			sol.set_meta("antes", [sol.rotation_degrees, sol.light_color, sol.light_energy])
		# os shaders polidos somam o sol sem olhar a face: no sol = ambiente + sol (~1, o tom do original)
		sol.rotation_degrees = Vector3(-55, -150, 0)
		sol.light_color = Color(1.0, 0.95, 0.86)
		sol.light_energy = 0.25
		sol.shadow_enabled = true
		sol.shadow_blur = 1.5
		sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sol.directional_shadow_max_distance = 45.0
	# o ceu e a neblina de areia so no visualizador da Lorencia; no jogo cada mapa fica com o fundo dele
	if not _ceu:
		return
	var ceu := ProceduralSkyMaterial.new()
	ceu.sky_top_color = Color(0.32, 0.45, 0.68)
	ceu.sky_horizon_color = Color(0.78, 0.74, 0.66)
	ceu.ground_horizon_color = Color(0.6, 0.56, 0.48)
	ceu.ground_bottom_color = Color(0.2, 0.18, 0.15)
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ceu
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.68, 0.55)
	env.fog_density = 0.0025
	env.fog_sky_affect = 0.0


static func _luz_comum(env: Environment) -> void:
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.58, 0.6, 0.68)   # a sombra: ~60% do tom, um pouco fria
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = false


# Dark Knight vestido no alvo da camera, parado (pras fotos de comparacao)
static func heroi(mundo: Node3D, spec: String, giro: float) -> void:
	if ModelosMU.eu == null:
		mundo.add_child(ModelosMU.new())
	var b := Boneco.novo("classe_dk")
	if b == null:
		return
	b.position = mundo.no_tile(mundo.alvo.x, mundo.alvo.y)
	b.rotation_degrees.y = giro
	mundo.add_child(b)
	var eq := {}
	var niveis := {}
	for par in spec.split(";", false):
		var k := par.get_slice("=", 0)
		var v := par.get_slice("=", 1)
		if k == "niveis":
			for nv in v.split(",", false):
				niveis[int(nv.get_slice(":", 0))] = int(nv.get_slice(":", 1))
		else:
			eq[int(k)] = v
	eq["niveis"] = niveis
	b.vestir(eq)
	b.tocar("parado")
	if hd:
		_hd_no(b)
	if OS.get_environment("CAIXA") != "":
		var cx := MeshInstance3D.new()
		cx.mesh = BoxMesh.new()
		cx.position = b.position + Vector3(2, 1.5, 0)
		mundo.add_child(cx)
	print("TESTE heroi %s" % spec)
	await mundo.get_tree().create_timer(3.0).timeout
	for mi: MeshInstance3D in b.find_children("*", "MeshInstance3D", true, false):
		var mt := mi.get_active_material(0) as BaseMaterial3D
		if mt:
			print("TESTE mat %s transp=%d cast=%d" % [mi.name, mt.transparency, mi.cast_shadow])


# corpo do personagem (dados/personagens, importado no projeto): troca a textura pela HD
static func _hd_no(no: Node) -> void:
	for mi: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			var p := caminho_hd(m.albedo_texture) if m else ""
			if p == "":
				continue
			var novo := m.duplicate() as StandardMaterial3D
			novo.albedo_texture = load(p)
			if ResourceLoader.exists(p.replace(".png", "_n.png")):
				novo.normal_enabled = true
				novo.normal_texture = load(p.replace(".png", "_n.png"))
			mi.set_surface_override_material(i, novo)

