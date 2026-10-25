class_name ChaosCastle
extends Node
# Chaos Castle (CSChaosCastle e CNewChaosCastleSystem do S6). Os 7 castelos (mapas 18 a 23 e 53)
# usam a pasta World19. O castelo encolhe em 3 estagios: o C1 9B manda 8, 9 e 10 e o cliente
# poe o "sem chao" nos 4 retangulos da borda (AddTerrainAttributeRange, fixo no cliente; o
# OpenMU so bloqueia do lado dele), o anel de pedra da borda treme 10 quadros soltando fumaca
# e cai 30 quadros acelerando (MoveChaosCastleAllObject), e o anel de dentro aparece no lugar
# (RenderChaosCastleVisual). Dentro do castelo todo mundo perde asa e pet e fica com a arma
# do castelo (ChangeChaosCastleUnit).

const MAPAS := [18, 19, 20, 21, 22, 23, 53]
const QUADRO := 0.04   # o cliente anda a 25 quadros por segundo
# tipos de objeto que caem em cada estagio e os que aparecem no lugar
const CAEM := {1: [0, 1, 2, 3, 4, 5, 13, 14, 15, 16, 17], 2: [30, 31, 32, 33, 34, 35], 3: [24, 25, 26, 27, 28, 29]}
const APARECEM := {1: [30, 31, 32, 33, 34, 35], 2: [24, 25, 26, 27, 28, 29], 3: [18, 19, 20, 21]}
# CreateChaosCastleObject: nascem escondidos (6 a 12 sao as nuvens, nem viram objeto: Ambiente.ESCONDER)
const ESCONDIDOS := [18, 19, 20, 21, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35]
# CNewChaosCastleSystem::SetMatchGameCommand: x, y, largura, altura
const BURACOS := {1: [[23, 75, 22, 2], [43, 77, 2, 32], [23, 107, 20, 2], [23, 77, 2, 30]],
	2: [[25, 77, 18, 2], [41, 79, 2, 28], [25, 105, 16, 2], [25, 79, 2, 26]],
	3: [[27, 79, 14, 2], [39, 81, 2, 24], [27, 103, 12, 2], [27, 81, 2, 22]]}
const SEM_CHAO := 8
# armas do castelo por classe (ChangeChaosCastleUnit): Sword of Destruction nas duas maos,
# Great Reign Crossbow ou Legendary Staff na direita
const ARMAS := {"classe_dk": ["0,16", "0,16"], "classe_mg": ["0,16", "0,16"], "classe_dl": ["0,16", "0,16"],
	"classe_rf": ["0,16", "0,16"], "classe_elf": ["4,19", ""], "classe_dw": ["5,5", ""], "classe_sum": ["5,5", ""]}

var mundo: Node3D
var som: Som
var ativo := false
var estagio := 0
var _caindo: Array = []      # [no, z de partida]
var _t := -1.0               # tempo desde o comeco da queda (-1 parado)
var _vel := 0.0
var _fumacas: Array[CPUParticles3D] = []


static func e_caos(mapa: int) -> bool:
	return mapa in MAPAS


# as armas e o que some dentro do castelo
static func vestido_no_caos(classe: String, equip: Dictionary) -> Dictionary:
	var d := equip.duplicate(true)
	var niveis: Dictionary = d.get("niveis", {}).duplicate()
	for s in [0, 1, 7, 8]:
		d.erase(s)
		niveis.erase(s)
	var a: Array = ARMAS.get(classe, ["", ""])
	for s in 2:
		if a[s] != "":
			d[s] = a[s]
	d["niveis"] = niveis
	return d


func entrar(m: Node3D, mapa: int) -> void:
	_parar()
	mundo = m
	estagio = 0
	ativo = e_caos(mapa)
	if not ativo or mundo == null:
		return
	for par in mundo.nos_objetos:
		if int(par[1].t) in ESCONDIDOS:
			par[0].visible = false


func sair() -> void:
	_parar()
	ativo = false
	mundo = null


# estado 8, 9 ou 10 do C1 9B: estagio 1, 2 ou 3. O OpenMU repete o estado a cada segundo
# enquanto o castelo esta naquele estagio: so o primeiro vale
func encolher(n: int) -> void:
	if not ativo or n <= estagio or n > 3:
		return
	# estagio perdido (entrou no meio): os buracos dele entram sem a queda
	while estagio < n - 1:
		estagio += 1
		_buracos(estagio)
		_trocar_aneis(estagio)
	estagio = n
	_buracos(n)
	print("TESTE caos estagio %d" % n)
	if som:
		som.tocar("parede_cai")
	_parar()
	for par in mundo.nos_objetos:
		var t := int(par[1].t)
		if t in CAEM[n]:
			_caindo.append([par[0], par[0].position.z])
		elif t in APARECEM[n]:
			par[0].visible = true
	_t = 0.0
	_vel = 1.0
	var tex := EfeitoMU.textura("smoke01")
	if tex:
		for c in _caindo.filter(func(c): return (c[0] as Node3D).is_inside_tree()):
			var f := Ambiente.fumaca(tex)
			f.amount = 4
			mundo.add_child(f)
			f.global_position = (c[0] as Node3D).global_position + Vector3(0, 0.3, 0)
			_fumacas.append(f)


func _buracos(n: int) -> void:
	if mundo == null or mundo.atributos.is_empty():
		return
	for r in BURACOS[n]:
		mundo.mudar_atributo(SEM_CHAO, false, r[0], r[1], r[0] + r[2] - 1, r[1] + r[3] - 1)


func _trocar_aneis(n: int) -> void:
	for par in mundo.nos_objetos:
		var t := int(par[1].t)
		if t in CAEM[n]:
			par[0].visible = false
		elif t in APARECEM[n]:
			par[0].visible = true


func _parar() -> void:
	for c in _caindo:
		if is_instance_valid(c[0]):
			c[0].visible = false
	_caindo.clear()
	for f in _fumacas:
		if is_instance_valid(f):
			f.queue_free()
	_fumacas.clear()
	_t = -1.0
	if mundo and is_instance_valid(mundo) and mundo.camera:
		mundo.camera.v_offset = 0.0


func caindo() -> bool:
	return _t >= 0.0


func _process(dt: float) -> void:
	if _t < 0.0 or mundo == null or not is_instance_valid(mundo):
		return
	_t += dt
	var q := _t / QUADRO
	if q < 10.0:
		# 10 quadros tremendo (EarthQuake de -0,3 a -0,1)
		if mundo.camera:
			mundo.camera.v_offset = randf_range(-0.03, 0.03)
		return
	if mundo.camera:
		mundo.camera.v_offset = 0.0
	for f in _fumacas:
		if is_instance_valid(f):
			f.emitting = false
	if q >= 40.0:
		_parar()
		return
	# Position[2] = StartPosition[2] - (30 - ActionTime) * Velocity, a velocidade sobe 0,4 por quadro
	_vel += 0.4 * dt / QUADRO * 6.0
	for c in _caindo:
		if is_instance_valid(c[0]):
			c[0].position.z = c[1] - (q - 10.0) * _vel
