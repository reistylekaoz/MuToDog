extends Node3D
# Vitrine dos personagens convertidos (dados/personagens): todos em fila,
# trocando de acao a cada 3 s. No navegador: ?vitrine=1 (ou ?vitrine=parado).
# ?npc=34,35: os monstros pelo numero do OpenMU, montados como no jogo (Boneco.do_npc).
# ?giro=90 vira todos de lado. ?pacote=34,35: baixa antes os pacotes desses mapas (monstros dos mapas novos). ?monta=13,2;13,3;13,4;13,37: um Dark Knight com espada montado em cada (13,37:blue = Fenrir azul).

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
	for n in _param("pacote").split(",", false):
		await PacoteMapa.carregar(self, int(n))
	var nomes: Array = Boneco.info().keys()
	nomes.sort()
	# ?so=a,b,c: so esses, de perto
	var so := _param("so")
	if so != "":
		nomes = Array(so.split(","))
	var npcs := _param("npc")
	if npcs != "":
		add_child(ModelosMU.new())
		nomes = Array(npcs.split(","))
		so = npcs
	var monta := _param("monta")
	var montas: Array = []
	if monta != "":
		add_child(ModelosMU.new())
		montas = Array(monta.split(";"))
		nomes = []
		for m in montas:
			nomes.append("classe_dk")
		so = monta
	var col := mini(8, nomes.size())
	for i in nomes.size():
		var b := Boneco.do_npc(int(nomes[i])) if npcs != "" else Boneco.novo(nomes[i])
		# a malha que brilha somada, como no jogo (Boneco.NPCS, 3o valor)
		for k in Boneco.NPCS:
			var m: Array = Boneco.NPCS[k]
			if b and npcs == "" and m[0] == nomes[i] and m.size() > 2:
				b.somar_malha(m[2])
				break
		if b == null:
			continue
		if not montas.is_empty():
			var mk: String = montas[i].get_slice(":", 0)
			var eq := {0: "0,5", "fenrir": montas[i].get_slice(":", 1) if ":" in montas[i] else "red"}
			eq[7 if mk.begins_with("12,") or mk == "13,30" else 8] = mk   # capa vai no slot da asa
			b.vestir(eq)
		b.rotation_degrees.y = 180 + float(_param("giro"))   # ?giro=90: de lado
		b.position = Vector3((i % col - col / 2.0 + 0.5) * (3.2 if so == "" else 1.8), 0, -(i / col) * 4.0 + 4)
		add_child(b)
		var l := Label3D.new()
		l.text = montas[i] if not montas.is_empty() else nomes[i]
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
		# fora do navegador: -- --npc 69,70 (pra testar sem tela)
		var a := OS.get_cmdline_user_args()
		var i := a.find("--" + nome)
		return a[i + 1] if i >= 0 and i + 1 < a.size() else ""
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
