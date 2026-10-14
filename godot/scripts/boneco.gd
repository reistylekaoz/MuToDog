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
	226: ["treinador", 1.0], 229: ["placa", 1.0], 230: ["alex", 1.0], 236: ["esqueleto2", 1.0],
	240: ["baz", 1.0], 247: ["guarda_besta", 1.0], 248: ["martin", 1.0], 249: ["placa", 1.0], 250: ["harold", 1.0],
	251: ["hanzo", 0.95], 253: ["amy", 1.0], 254: ["pasi", 1.0], 255: ["lumen", 1.0], 257: ["espirito", 1.0],
	371: ["leo", 1.0], 375: ["leo", 1.0], 543: ["duprian", 1.0], 547: ["julia", 1.0], 568: ["zyro", 0.8],
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


static func info() -> Dictionary:
	if _info.is_empty() and FileAccess.file_exists(PASTA + "personagens.json"):
		_info = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "personagens.json"))
	return _info


static func do_npc(numero: int) -> Boneco:
	var m: Array = NPCS.get(numero, [])
	return novo(m[0], m[1]) if not m.is_empty() else null


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
	_fila = depois if real in NAO_REPETE and real != "morre" else ""


func _acabou(_n: StringName) -> void:
	if _fila != "":
		var f := _fila
		_fila = ""
		tocar(f)
