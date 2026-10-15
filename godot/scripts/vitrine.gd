extends Node3D
# Vitrine dos personagens convertidos (dados/personagens): todos em fila,
# trocando de acao a cada 3 s. No navegador: ?vitrine=1 (ou ?vitrine=parado).

var bonecos: Array[Boneco] = []
var _t := 0.0
var _i := 0
const CICLO := ["parado", "anda", "ataque", "golpe", "morre"]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.05, 0.05, 0.08))
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, -30, 0)
	add_child(luz)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(amb)
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	chao.mesh = pm
	var mc := StandardMaterial3D.new()
	mc.albedo_color = Color(0.18, 0.2, 0.16)
	pm.material = mc
	add_child(chao)
	var nomes: Array = Boneco.info().keys()
	nomes.sort()
	# ?so=a,b,c: so esses, de perto
	var so := _param("so")
	if so != "":
		nomes = Array(so.split(","))
	var col := mini(8, nomes.size())
	for i in nomes.size():
		var b := Boneco.novo(nomes[i])
		# a malha que brilha somada, como no jogo (Boneco.NPCS, 3o valor)
		for k in Boneco.NPCS:
			var m: Array = Boneco.NPCS[k]
			if b and m[0] == nomes[i] and m.size() > 2:
				b.somar_malha(m[2])
				break
		if b == null:
			continue
		b.rotation_degrees.y = 180
		b.position = Vector3((i % col - col / 2.0 + 0.5) * (3.2 if so == "" else 1.8), 0, -(i / col) * 4.0 + 4)
		add_child(b)
		var l := Label3D.new()
		l.text = nomes[i]
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.01
		l.font_size = 40
		l.outline_size = 8
		l.position = b.position + Vector3(0, -0.3, 1.2)
		add_child(l)
		bonecos.append(b)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 9, 14) if so == "" else Vector3(0, 1.6, 7.0 + col * 0.9)
	cam.rotation_degrees.x = -30 if so == "" else -12
	cam.fov = 60
	add_child(cam)
	_tocar()
	print("TESTE vitrine: %d bonecos" % bonecos.size())


func _param(nome: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var m := str(JavaScriptBridge.eval("location.search")).split(nome + "=")
	return m[1].split("&")[0] if m.size() > 1 else ""


func _tocar() -> void:
	var fixa := _param("vitrine")
	if fixa == "1":
		fixa = ""
	var acao: String = fixa if fixa != "" else CICLO[_i % CICLO.size()]
	for b in bonecos:
		b.tocar(acao)


func _process(dt: float) -> void:
	_t += dt
	if _t > 3.0:
		_t = 0.0
		_i += 1
		_tocar()
