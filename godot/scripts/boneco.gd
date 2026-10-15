class_name Boneco
extends Node3D
# Um modelo do MU animado (dados/personagens/<nome>.glb, feito pelo conversor).
# O GLB vem nas coordenadas do MU (Z pra cima, 100 por tile) com 1 s por quadro;
# aqui ele fica em pe, na escala do mundo, e anda na velocidade do cliente
# (PlaySpeed x 25 quadros por segundo).

const PASTA := "res://dados/personagens/"
# PlaySpeed padrao do cliente S6 (ZzzOpenData.cpp)
const VELOCIDADE := {
	"monstro": {"parado": 0.25, "parado2": 0.2, "anda": 0.34, "ataque": 0.33, "ataque2": 0.33, "golpe": 0.5, "morre": 0.55},
	"jogador": {"parado": 0.28, "parado_f": 0.28, "voa": 0.28, "anda": 0.3, "anda_f": 0.3, "corre": 0.3,
		"soco": 0.35, "espada": 0.35, "golpe": 0.4, "morre": 0.45,
		"espada_s1": 0.3, "espada_s2": 0.3, "espada_s3": 0.3, "espada_s4": 0.3, "espada_s5": 0.3,
		"giro": 0.4, "furia": 0.3, "estocada": 0.3, "arco": 0.3, "magia": 0.3, "magia2": 0.3,
		"magia_arma": 0.3, "cura": 0.25, "raio": 0.3, "inferno": 0.3, "fogo_inferno": 0.3},
	"npc": {},
}
# acao pedida -> a que existe no modelo (o jogador nao tem "ataque", tem "soco")
const TROCA := {"ataque": ["ataque", "soco", "parado"], "ataque2": ["ataque2", "ataque", "soco"],
	"golpe": ["golpe", "parado"], "morre": ["morre", "golpe", "parado"], "anda": ["anda", "parado"],
	"corre": ["corre", "anda"], "parado2": ["parado2", "parado"]}
const NAO_REPETE := ["morre", "golpe", "ataque", "ataque2", "soco", "espada", "espada_s1", "espada_s2",
	"espada_s3", "espada_s4", "espada_s5", "giro", "furia", "estocada", "arco", "magia", "magia2", "magia_arma",
	"cura", "raio", "inferno", "fogo_inferno"]

# numero do monstro/NPC no OpenMU -> [modelo, escala], tirado do CreateMonster
# do cliente S6 (ZzzCharacter.cpp). So a Lorencia por enquanto.
const NPCS := {
	0: ["monster01_sem0", 0.8], 1: ["monster02_sem0", 0.85], 2: ["monster03", 0.5], 3: ["monster10", 0.4],
	4: ["monster01", 1.15], 6: ["monster05", 0.85], 7: ["monster06", 1.6], 14: ["esqueleto1", 0.95],
	226: ["treinador", 1.0], 229: ["marlon", 1.0], 230: ["alex", 1.0], 236: ["esqueleto2", 1.0],
	240: ["baz", 1.0], 247: ["guarda_besta", 1.0], 248: ["martin", 1.0], 249: ["placa", 1.0], 250: ["harold", 1.0],
	251: ["hanzo", 0.95], 253: ["amy", 1.0], 254: ["pasi", 1.0], 255: ["lumen", 1.0], 257: ["espirito", 1.0],
	371: ["leo", 1.0], 375: ["leo", 1.0], 543: ["duprian", 1.0], 547: ["julia", 1.0], 568: ["zyro", 0.8],
	# Devias e Noria (CreateMonster do cliente S6: modelo, escala e, em 3o, a malha que brilha somada)
	20: ["monster14", 1.4], 21: ["monster15", 0.95], 22: ["monster16", 1.0, 0], 23: ["monster17", 1.15],
	24: ["monster18", 1.0], 25: ["monster19", 1.1, 2], 26: ["monster20", 0.8], 27: ["monster21", 1.1],
	28: ["monster22", 0.8, 1], 29: ["monster23", 0.95], 30: ["monster24", 0.75], 31: ["monster25", 1.3],
	32: ["monster26", 1.0], 33: ["monster20_chefe", 1.2],
	233: ["mensageiro", 1.0, 2], 235: ["sevina", 1.0], 237: ["charon", 1.0],
	238: ["goblin_caos", 1.0, 1], 241: ["mestre_guilda", 1.0], 242: ["lala", 1.0, 1], 243: ["eo", 1.0],
	244: ["caren", 1.0], 245: ["izabel", 1.0], 246: ["zienna", 1.0], 256: ["lahap", 1.0], 379: ["fogos", 1.0],
	385: ["mirage", 0.95], 406: ["devin", 1.0], 450: ["cerejeira", 1.0], 451: ["cerejeira_arvore", 1.0], 478: ["lahap", 1.0],
	522: ["jerinteu", 1.0], 540: ["lugard", 1.0], 544: ["vanert", 1.0], 566: ["felicia", 1.0],
}
# classe do OpenMU (classes.json) >> 2 -> corpo padrao da classe
const CLASSES := ["classe_dw", "classe_dk", "classe_elf", "classe_mg", "classe_dl", "classe_sum", "classe_rf"]

static var _info := {}

var anim: AnimationPlayer
var familia := "npc"
var acao := ""
var feminino := false
var altura := 1.9
var ritmo := {}   # acao -> PlaySpeed proprio do modelo
var _fila := ""
var modelo: Node3D
var esqueleto: Skeleton3D
var _equip := {}      # slot do inventario -> "grupo,numero" do que esta vestido
var _niveis := {}     # slot -> nivel do item (+0 a +15), pro brilho
var _pecas := {}      # slot -> no posto no boneco
var _rastros := {}    # slot da mao -> RastroArma
var _costas := false  # zona segura: arma nas costas


static func info() -> Dictionary:
	if _info.is_empty() and FileAccess.file_exists(PASTA + "personagens.json"):
		_info = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "personagens.json"))
	return _info


static func do_npc(numero: int) -> Boneco:
	var m: Array = NPCS.get(numero, [])
	if m.is_empty():
		return null
	var b := novo(m[0], m[1])
	if b and m.size() > 2:
		b.somar_malha(m[2])
	return b


static func da_classe(classe: int) -> Boneco:
	var b := novo(CLASSES[clampi(classe >> 2, 0, CLASSES.size() - 1)])
	if b:
		b.feminino = (classe >> 2) in [2, 5]
	return b


static func novo(nome: String, escala := 1.0) -> Boneco:
	var cena = load(PASTA + nome + ".glb") if ResourceLoader.exists(PASTA + nome + ".glb") else null
	if cena == null:
		return null
	var b := Boneco.new()
	b.name = nome
	b.altura = 1.9 * escala
	b.familia = "monstro" if nome.begins_with("monster") else ("jogador" if info().get(nome, {}).has("soco") else "npc")
	var modelo: Node3D = cena.instantiate()
	# em pe e de frente pra -Z (o MU desenha de frente pra -Y)
	modelo.rotation_degrees = Vector3(-90, 180, 0)
	modelo.scale = Vector3.ONE * 0.01 * escala
	b.add_child(modelo)
	b.modelo = modelo
	var ossos := modelo.find_children("*", "Skeleton3D", true, false)
	if not ossos.is_empty():
		b.esqueleto = ossos[0]
	var achou := modelo.find_children("*", "AnimationPlayer", true, false)
	if not achou.is_empty():
		b.anim = achou[0]
		b.anim.animation_finished.connect(b._acabou)
		for n in b.anim.get_animation_list():
			var a := b.anim.get_animation(n)
			a.loop_mode = Animation.LOOP_NONE if n in NAO_REPETE else Animation.LOOP_LINEAR
			# o conversor fecha o laco com o quadro 0 no fim; quem morre para no penultimo
			if n == "morre":
				a.length = maxf(a.length - 1.0, 0.1)
	return b


# BlendMesh do cliente: a malha n desenha somada (brilha), como gelo, asa de besouro e o caldeirao do Goblin
func somar_malha(n: int) -> void:
	var i := 0
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if i == n and orig:
				var m := orig.duplicate() as BaseMaterial3D
				m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(s, m)
			i += 1


func tem(a: String) -> bool:
	return anim != null and anim.has_animation(a)


# toca a acao (com troca pra parecida se o modelo nao tiver); depois de uma
# que nao repete, volta pro "parado" (menos morrer, que fica no chao)
func tocar(a: String, depois := "parado") -> void:
	if anim == null:
		return
	if feminino and tem(a + "_f"):
		a += "_f"
	var real := a
	if not tem(real):
		real = ""
		for t in TROCA.get(a, [a, "parado"]):
			if tem(t):
				real = t
				break
	if real == "":
		return
	var vel: float = ritmo.get(real, VELOCIDADE[familia].get(real.trim_suffix("_f"), 0.25))
	anim.play(real, 0.12, vel * 25.0)
	acao = real
	# rastro da arma (CreateWeaponBlur): golpe comum em blur01 na cor do nivel, skill de espada no motion_blur_r
	if not _rastros.is_empty() and real.trim_suffix("_f") in GOLPES and tem_arma_de_corte():
		if real.begins_with("espada_s"):
			rastro(0.5, Color(1, 1, 1), "motion_blur_r")
		else:
			var nv: int = _niveis.get(0, 0)
			var c := Color(1, 0.6, 0.2) if nv >= 7 else Color(0.2, 0.4, 1) if nv >= 5 else Color(1, 0.2, 0.2) if nv >= 3 else Color(0.8, 0.8, 0.8)
			rastro(0.45, c)
	_fila = depois if real in NAO_REPETE and real != "morre" else ""


func _acabou(_n: StringName) -> void:
	if _fila != "":
		var f := _fila
		_fila = ""
		tocar(f)


# --- equipamento -----------------------------------------------------------------
# slots do inventario: 0 mao direita, 1 mao esquerda, 2 elmo, 3 armadura, 4 calca,
# 5 luvas, 6 botas, 7 asa, 8 ajudante. Peca de armadura troca a parte padrao da classe
# (as malhas helmclass02, armorclass02...); arma vai presa no osso da mao (33 e 42 no
# player.bmd; 47, as costas, na zona segura, como o cliente); asa segue o osso 47
# sem girar junto, com a animacao propria; anjo e imp voam do lado.
const PARTE_SLOT := {2: "helm", 3: "armor", 4: "pant", 5: "glove", 6: "boot"}
const OSSO_MAO := {0: "osso33", 1: "osso42"}


# equip: slot -> "grupo,numero"; equip.niveis (opcional): slot -> nivel, pro brilho
func vestir(equip: Dictionary) -> void:
	if esqueleto == null or familia != "jogador":
		return
	var niveis: Dictionary = equip.get("niveis", {})
	for s in 9:
		var k: String = equip.get(s, "")
		var nv: int = niveis.get(s, 0)
		if _equip.get(s, "") == k:
			if _niveis.get(s, 0) != nv:
				_niveis[s] = nv
				if _pecas.has(s) and s <= 6:
					BrilhoMU.aplicar(_pecas[s], k, nv)
			continue
		_equip[s] = k
		_niveis[s] = nv
		_tirar(s)
		if k != "":
			_por(s, k)


func vestido() -> Dictionary:
	var d := _equip.duplicate()
	d["niveis"] = _niveis.duplicate()
	return d


func _tirar(s: int) -> void:
	if _pecas.has(s):
		_pecas[s].queue_free()
		_pecas.erase(s)
	if PARTE_SLOT.has(s):
		_padrao(s, true)


func _padrao(s: int, ver: bool) -> void:
	for m in esqueleto.get_children():
		if m is MeshInstance3D and str(m.name).begins_with(PARTE_SLOT[s]):
			m.visible = ver


func _por(s: int, k: String) -> void:
	var no: Node3D = await ModelosMU.eu.instanciar(k) if ModelosMU.eu else null
	if no == null:
		return
	if not is_instance_valid(self) or _equip.get(s, "") != k or _pecas.has(s):
		no.free()
		return
	if PARTE_SLOT.has(s):
		var suporte := Node3D.new()
		suporte.name = "peca%d" % s
		esqueleto.add_child(suporte)
		for m: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
			var mi := MeshInstance3D.new()
			mi.mesh = m.mesh
			mi.skin = m.skin
			suporte.add_child(mi)
			mi.skeleton = mi.get_path_to(esqueleto)
		no.free()
		_pecas[s] = suporte
		_padrao(s, false)
		BrilhoMU.aplicar(suporte, k, _niveis.get(s, 0))
	elif OSSO_MAO.has(s):
		var at := BoneAttachment3D.new()
		esqueleto.add_child(at)
		at.bone_name = "osso47" if _costas else OSSO_MAO[s]
		var enc := Node3D.new()
		enc.transform = _encaixe(k, s == 1)
		at.add_child(enc)
		enc.add_child(no)
		_pecas[s] = at
		BrilhoMU.aplicar(no, k, _niveis.get(s, 0))
		_rastros[s] = RastroArma.na_arma(no)
	elif s == 7:
		# o cliente poe a origem da asa no osso 47 (costas) mais 15 pra cima no osso,
		# mas com o giro do boneco (RenderLinkObject sem Link); _process segue o osso
		modelo.add_child(no)
		_voar(no, 0.25)
		_pecas[s] = no
		_osso_asa = esqueleto.find_bone("osso47")
		_seguir_asa()
	elif s == 8 and k in ["13,0", "13,1"]:
		# anjo e imp: do lado do ombro, subindo e descendo
		var p := Node3D.new()
		add_child(p)
		p.position = Vector3(0.55, altura * 0.85, 0.2)
		no.rotation_degrees = Vector3(-90, 180, 0)
		no.scale = Vector3.ONE * 0.01
		p.add_child(no)
		_voar(no, 0.5)
		var tw := p.create_tween().set_loops()
		tw.tween_property(p, "position:y", altura * 0.85 + 0.15, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(p, "position:y", altura * 0.85, 1.2).set_trans(Tween.TRANS_SINE)
		_pecas[s] = p
	else:
		no.free()


static func _voar(no: Node, ritmo_mu: float) -> void:
	var ap := no.find_children("*", "AnimationPlayer", true, false)
	if ap.is_empty() or not ap[0].has_animation("voa"):
		return
	ap[0].get_animation("voa").loop_mode = Animation.LOOP_LINEAR
	ap[0].play("voa", -1, ritmo_mu * 25.0)


# onde o cliente poe a arma no osso (RenderLinkObject, caso padrao; igual ao conversor)
static func _encaixe(k: String, esquerda: bool) -> Transform3D:
	var g := int(k.get_slice(",", 0))
	var t: Transform3D
	if g == 6:
		t = ModelosMU.transf_mu(70, 0, 90, -10, 0, 0)
	elif g == 4:
		t = ModelosMU.transf_mu(70, 0, 90, -10, 5, 10)
	else:
		t = ModelosMU.transf_mu(70, 0, 90, -20, 5, 40)
	# segunda arma na mao esquerda: o cliente gira mais e desloca
	if esquerda and g != 6:
		t = t * ModelosMU.transf_mu(145, 0, 275, 0, 10, -30)
	return t


var _osso_asa := -1


func _process(_d: float) -> void:
	if _pecas.has(7):
		_seguir_asa()


func _seguir_asa() -> void:
	if _osso_asa < 0:
		return
	var p := esqueleto.get_bone_global_pose(_osso_asa) * Vector3(0, 0, 15)
	_pecas[7].position = modelo.to_local(esqueleto.to_global(p))


const GOLPES := ["ataque", "soco", "espada", "espada_s1", "espada_s2", "espada_s3", "espada_s4", "espada_s5", "giro", "furia", "estocada"]


# grupos das armas na mao (0 espada, 1 machado, 2 maca, 3 lanca, 4 arco, 5 cajado)
func grupos_arma() -> Array:
	var l := []
	for s in [0, 1]:
		if _equip.has(s):
			l.append(int(str(_equip[s]).get_slice(",", 0)))
	return l


func tem_arma_de_corte() -> bool:
	return grupos_arma().any(func(g): return g <= 3)


func tem_arco() -> bool:
	return 4 in grupos_arma()


# ponta da arma da mao direita (ou da esquerda) no mundo; sem arma, a altura da mao
func ponta_arma() -> Vector3:
	for s in [0, 1]:
		var r: RastroArma = _rastros.get(s)
		if r and is_instance_valid(r) and is_instance_valid(r.arma):
			return r.arma.global_transform * r.ponta
	return global_position + global_basis * Vector3(0.3, altura * 0.65, -0.4)


# copia do modelo da arma (sem o rastro), pro Twisting Slash e o Rageful Blow
func arma_copia() -> Node3D:
	for s in [0, 1]:
		var r: RastroArma = _rastros.get(s)
		if r and is_instance_valid(r) and is_instance_valid(r.arma):
			var c: Node3D = r.arma.duplicate()
			for x in c.get_children():
				if x is RastroArma:
					x.free()
			c.transform = Transform3D.IDENTITY
			return c
	return null


# rastro das armas na mao por alguns segundos (golpe e skill de arma)
func rastro(segundos: float, cor := Color(1, 1, 1), tex := "blur01") -> void:
	for s in _rastros:
		if is_instance_valid(_rastros[s]):
			_rastros[s].ligar(segundos, cor, tex)


func arma_nas_costas(sim: bool) -> void:
	if sim == _costas:
		return
	_costas = sim
	for s in OSSO_MAO:
		if _pecas.has(s):
			_pecas[s].bone_name = "osso47" if sim else OSSO_MAO[s]
