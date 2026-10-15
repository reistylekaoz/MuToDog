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
	"jogador": {"parado": 0.28, "parado_f": 0.28, "voa": 0.28, "nada": 0.35, "nada_corre": 0.35, "anda": 0.3, "anda_f": 0.3, "corre": 0.3,
		"soco": 0.35, "espada": 0.35, "golpe": 0.4, "morre": 0.45,
		"espada_s1": 0.3, "espada_s2": 0.3, "espada_s3": 0.3, "espada_s4": 0.3, "espada_s5": 0.3,
		"giro": 0.4, "furia": 0.3, "estocada": 0.3, "arco": 0.3, "magia": 0.3, "magia2": 0.3,
		"magia_arma": 0.3, "cura": 0.25, "raio": 0.3, "inferno": 0.3, "fogo_inferno": 0.3,
		"monta_parado": 0.28, "monta_parado_a": 0.28, "monta_corre": 0.34, "monta_corre_a": 0.34, "monta_ataque": 0.35,
		"cavalo_parado": 0.3, "cavalo_corre": 0.33, "cavalo_ataque": 0.28,
		"fenrir_parado": 0.28, "fenrir_parado_a": 0.28, "fenrir_anda": 0.3, "fenrir_anda_a": 0.3,
		"fenrir_corre": 0.34, "fenrir_corre_a": 0.34, "fenrir_ataque": 0.3, "fenrir_ataque_a": 0.3},
	"npc": {},
}
# acao pedida -> a que existe no modelo (o jogador nao tem "ataque", tem "soco")
const TROCA := {"ataque": ["ataque", "soco", "parado"], "ataque2": ["ataque2", "ataque", "soco"],
	"golpe": ["golpe", "parado"], "morre": ["morre", "golpe", "parado"], "anda": ["anda", "parado"],
	"corre": ["corre", "anda"], "parado2": ["parado2", "parado"]}
const NAO_REPETE := ["morre", "golpe", "ataque", "ataque2", "soco", "espada", "espada_s1", "espada_s2",
	"espada_s3", "espada_s4", "espada_s5", "giro", "furia", "estocada", "arco", "magia", "magia2", "magia_arma",
	"cura", "raio", "inferno", "fogo_inferno", "monta_ataque", "cavalo_ataque", "fenrir_ataque", "fenrir_ataque_a"]

# numero do monstro/NPC no OpenMU -> [modelo, escala], tirado do CreateMonster
# do cliente S6 (ZzzCharacter.cpp). Lorencia, Dungeon, Devias, Noria, Lost Tower e Atlans.
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
	# Lost Tower e Atlans
	35: ["monster12_morte", 1.3, 1], 36: ["monster29", 1.2], 37: ["monster27", 1.1], 38: ["monster28", 1.6],
	39: ["monster29", 1.2], 40: ["monster30", 1.3, 3], 41: ["monster31", 1.1],
	45: ["monster34", 0.6], 46: ["monster35", 1.0], 47: ["monster36", 1.1, 0], 48: ["monster37", 1.4],
	49: ["monster38", 1.0], 51: ["monster34", 1.0], 52: ["monster36", 1.4],
	# Dungeon
	5: ["monster02_sem1", 1.1], 8: ["monster01_veneno", 1.0], 9: ["monster05_trovao", 1.1], 10: ["monster04", 0.8],
	11: ["monster08", 1.0], 12: ["monster07", 0.6], 13: ["monster09", 1.1], 15: ["esqueleto2_arco", 1.1],
	16: ["esqueleto3", 1.2], 17: ["monster11", 1.0], 18: ["monster12", 1.5, 1],
	# Tarkan (-2: o corpo inteiro somado, o BlendMesh -2 do Death Beam Knight)
	57: ["monster42", 1.4], 58: ["monster43", 1.8, 2], 59: ["monster43_zaikan", 2.1, 2], 60: ["monster44", 2.2],
	61: ["monster45", 1.5], 62: ["monster46", 1.5], 63: ["monster45", 1.9, -2],
	# mapas novos (Arena ate Karutan): modelo e escala do CreateMonster do cliente, tirados por
	# ferramentas/monstros_cliente.py (case do ZzzCharacter.cpp e dos GM*.cpp de cada mapa)
	69: ["monster51", 1], 70: ["monster52", 1.3], 71: ["monster53", 1.1], 72: ["monster54", 1.45],
	73: ["monster55", 1], 74: ["monster53", 1.1], 75: ["monster55", 1], 77: ["monster56", 1],
	200: ["npc_ball01", 1.8], 204: ["npc_object82", 1], 205: ["npc_object57", 1], 206: ["npc_object57", 1],
	207: ["npc_object57", 1], 208: ["npc_object57", 1], 209: ["npc_object57", 1], 216: ["npc_npccrown", 1],
	217: ["npc_npccheckfloor", 1], 218: ["npc_npccheckfloor", 1], 220: ["monster78", 1.1], 223: ["npc_npcsenatus", 1.1],
	224: ["npc_npcclerk", 1], 239: ["npc_tournament01", 1], 290: ["monster82", 1.2], 291: ["monster83", 1.8],
	292: ["monster84", 1.4], 293: ["monster85", 1.4], 294: ["monster86", 0.7], 295: ["monster88", 2],
	304: ["monster101", 1.4], 305: ["monster102", 1.35], 306: ["monster103", 1.1], 307: ["monster104", 1.15],
	308: ["monster105", 1.2], 309: ["monster106", 1.8], 310: ["monster92", 1.25], 311: ["monster98", 1.2],
	312: ["monster97", 1.2], 313: ["monster96", 1.25], 314: ["monster99", 1.6], 315: ["monster96", 1.25],
	316: ["monster97", 1.2], 317: ["monster98", 1.2], 340: ["monster93", 1.5], 341: ["monster95", 1.3],
	344: ["monster92", 1.25], 345: ["monster94", 1.25], 348: ["monster100", 1], 349: ["monster90", 2],
	350: ["monster107", 0.95], 351: ["monster108", 0.8], 352: ["monster109", 1.3], 353: ["monster110", 1.3],
	354: ["monster111", 1.3], 355: ["monster112", 1.1], 356: ["monster113", 1.2], 357: ["monster114", 1.2],
	358: ["monster115", 1], 359: ["monster116", 1.3], 360: ["monster117", 1.3], 367: ["npc_to3gate", 4.76],
	369: ["npc_os", 1], 370: ["npc_je", 1], 376: ["npc_npcpharmercy1", 1], 377: ["npc_npcpharmercy2", 1],
	407: ["npc_werequarrel", 1.9], 415: ["npc_silvia", 1], 416: ["npc_rhea", 1], 417: ["npc_marce", 1.05],
	418: ["monster129", 1], 419: ["monster130", 0.8], 420: ["monster131", 1], 421: ["monster132", 0.8],
	422: ["monster133", 1], 423: ["monster134", 0.17], 424: ["monster135", 1.2], 425: ["monster136", 1.3],
	441: ["monster137", 1], 442: ["monster138", 1], 443: ["monster139", 1], 444: ["monster140", 1.1],
	445: ["monster141", 1.1], 446: ["monster142", 1.3], 447: ["monster143", 0.95], 448: ["monster144", 0.95],
	449: ["monster145", 0.95], 452: ["npc_goblinmaster", 1.1], 453: ["npc_seedgoblin", 0.9], 454: ["monster146", 1],
	455: ["monster147", 1.7], 456: ["monster148", 1], 457: ["monster149", 1], 458: ["monster150", 1.5],
	479: ["npc_titus", 1.1], 480: ["monster158", 1], 481: ["monster158", 1], 482: ["monster159", 1],
	483: ["monster159", 1], 484: ["monster160", 0.7], 485: ["monster160", 0.7], 486: ["monster161", 1],
	487: ["monster162", 1], 488: ["monster162", 1], 489: ["monster164", 1], 490: ["monster163", 1],
	491: ["monster163", 1], 492: ["npc_gambler_moss", 0.8], 545: ["npc_unitedmarketplace_christine", 1.1], 546: ["npc_unitedmarkedplace_raul", 1],
	549: ["monster194", 1.15], 550: ["monster195", 1.1], 551: ["monster196", 1.35], 552: ["monster197", 1.4],
	553: ["monster198", 0.95], 554: ["monster199", 1.1], 555: ["monster200", 1.2], 556: ["monster201", 1.2],
	557: ["monster202", 1.5], 558: ["monster203", 1.1], 559: ["monster204", 1.56], 562: ["monster206", 1.7],
	563: ["monster207", 1], 564: ["monster208", 1], 565: ["monster209", 1.5], 569: ["monster210", 1],
	570: ["monster211", 0.58], 571: ["monster212", 0.64], 572: ["monster213", 1.5], 573: ["monster214", 1.5],
	574: ["monster215", 1.25], 575: ["monster216", 1.45], 576: ["monster217", 1.55], 577: ["npc_unitedmarketplace_christine", 1.1],
	578: ["npc_volvo", 0.9],
}
# transparencia (AlphaTarget): o Ghost da Dungeon
const TRANSPARENTES := {11: 0.4}
# fogo e fumaca saindo do corpo (MoveCharacter do cliente): [tipo, osso ("corpo" = osso ao
# acaso, "pes" = em volta dos pes), quantas no ar]
const PARTICULAS := {
	35: [["fogo", "corpo", 60]], 40: [["fogo", 2, 12]], 59: [["fogo", 6, 24], ["fogo", 13, 24]],
	10: [["fumaca", "pes", 4]], 12: [["fumaca", "pes", 4]], 51: [["fumaca", "pes", 4]],
	# Tarkan: Beam Knight com chama nas maos (ossos 62 e 77), Death Beam Knight pegando fogo (asas e
	# corpo); areia levantando em volta de quem anda (MonsterMoveSandSmoke, 1 por quadro andando)
	61: [["fogo", 62, 6], ["fogo", 77, 6], ["areia", "pes", 20]], 63: [["fogo", "corpo", 70]],
	57: [["areia", "pes", 20]], 58: [["areia", "pes", 20]], 60: [["areia", "pes", 20]], 62: [["areia", "pes", 20]],
}
# NPC que fica no ar (CreateMonster: Position[2] = chao + 140): a Lala da Noria
const FLUTUA := {242: 1.4}
# cor do corpo (BodyLight): o Poison Bull nasce envenenado (eDeBuff_Poison = 0,3 1 0,5)
const TINTA := {8: Color(0.3, 1, 0.5)}
# luz que o monstro pinta no chao em volta (AddTerrainLight): [cor (negativa escurece), raio em tiles]
# Death Gorgon vermelha piscando; Zaikan e Death Beam Knight escurecem (-1,3)
const LUZ_CHAO := {35: [Color(0.55, 0.11, 0), 2], 59: [Color(-1.3, -1.3, -1.3), 3], 63: [Color(-1.3, -1.3, -1.3), 3]}
# olhos que deixam rastro de luz (MoveEye + CreateJoint BITMAP_JOINT_ENERGY 2 e 3): [osso direito, esquerdo]
const OLHOS := {57: [8, 9], 58: [24, 25], 59: [24, 25], 60: [11, 12], 61: [8, 9], 62: [8, 9], 63: [8, 9]}
# monstro que e um jogador vestido (Cursed Wizard: Legendary +9, cajado e escudo)
const VESTIDOS := {
	34: ["classe_dw", {0: "5,5", 1: "6,14", 2: "7,3", 3: "8,3", 4: "9,3", 5: "10,3", 6: "11,3",
		"niveis": {0: 9, 1: 9, 2: 9, 3: 9, 4: 9, 5: 9, 6: 9}}],
}
# sprites presos nos ossos (RenderLight, RenderEye e o corpo de luz do Shadow no
# RenderCharacter do cliente): [textura, escala, ossos ("todos" = menos 15-20 e 27-32),
# deslocamento no osso, cor (null = RenderLight, que pulsa laranja; "olho" = branco pulsando;
# "menos" = subtrai, a aura escura do Shadow)]
const LUZES := {
	36: [["shiny02", 2.5, "todos", Vector3.ZERO, "menos"]],
	39: [["magic_ground2", 0.8, "todos", Vector3.ZERO, Color(0.2, 0.7, 0.1)]],
	41: [["eye01", 1.0, [22], Vector3(5, 0, 0), "olho"], ["eye01", 1.0, [23], Vector3(-5, 0, 0), "olho"]],
	45: [["spark02", 4.0, [9], Vector3(0, 0, 5), null], ["shiny03", 3.0, [9], Vector3(0, 0, 5), null]],
	51: [["spark02", 4.0, [9], Vector3(0, 0, 5), null], ["shiny03", 3.0, [9], Vector3(0, 0, 5), null]],
	46: [["lightning2", 0.5, [30, 39], Vector3(0, 0, -5), null], ["spark02", 4.0, [30, 39], Vector3(0, 0, -5), null],
		["shiny03", 2.0, [30, 39], Vector3(0, 0, -5), null]],
	48: [["eye01", 1.0, [42], Vector3(5, 0, 0), "olho"], ["eye01", 1.0, [43], Vector3(-5, 0, 0), "olho"],
		["spark02", 2.0, [26, 31, 36, 41], Vector3.ZERO, null], ["shiny03", 1.0, [26, 31, 36, 41], Vector3.ZERO, null]],
	49: [["lightning2", 1.0, [63], Vector3(0, 0, 20), null], ["shiny03", 4.0, [63], Vector3(0, 0, 20), null]],
}
# malha que o cliente desenha somada com luz 0 (some): a Hydra so acende a 5 no ataque
const APAGADAS := {49: 5}
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
var nadar := false    # Atlans fora da cidade: parado flutua, andar e nadar
const NADO := {"parado": "voa", "anda": "nada", "corre": "nada_corre"}
# montarias no slot do ajudante (CreateMount/MoveMount do cliente): item -> [modelo, escala, jeito].
# Fora da zona segura o bicho vai embaixo do jogador e o jogador troca pras acoes de montado
# (SetPlayerStop/SetPlayerWalk); na cidade a montaria some e ele anda a pe.
const MONTARIAS := {"13,2": ["montaria_uniria", 0.9, "monta"], "13,3": ["montaria_dinorant", 0.9, "monta"],
	"13,4": ["montaria_cavalo", 1.0, "cavalo"], "13,37": ["montaria_fenrir_", 0.9, "fenrir"]}   # + red (sem opcao), black, blue ou gold
# acao do jogador -> [acao montado, acao da montaria]; "_a" = com arma na mao
const MONTADO := {
	"monta": {"parado": ["monta_parado", "parado"], "anda": ["monta_corre", "anda"], "corre": ["monta_corre", "anda"], "ataque": ["monta_ataque", "ataque"]},
	"cavalo": {"parado": ["cavalo_parado", "parado"], "anda": ["cavalo_corre", "anda"], "corre": ["cavalo_corre", "anda"], "ataque": ["cavalo_ataque", "ataque"]},
	"fenrir": {"parado": ["fenrir_parado", "parado"], "anda": ["fenrir_anda", "anda"], "corre": ["fenrir_corre", "corre"], "ataque": ["fenrir_ataque", "ataque"]},
}
const RITMO_MONTARIA := {
	"monta": {"parado": 0.34, "anda": 0.34, "ataque": 0.34},
	"cavalo": {"parado": 0.34, "anda": 0.34, "ataque": 0.34},
	"fenrir": {"parado": 0.4, "anda": 1.0, "corre": 0.6, "ataque": 0.4},
}
var montaria: Boneco
var _jeito_montaria := ""
var pedida := ""   # a acao que pediram (antes de virar a de montado)
var _fenrir := "red"


static func info() -> Dictionary:
	if _info.is_empty() and FileAccess.file_exists(PASTA + "personagens.json"):
		_info = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "personagens.json"))
	return _info


static func do_npc(numero: int) -> Boneco:
	if VESTIDOS.has(numero):
		var v: Array = VESTIDOS[numero]
		var j := novo(v[0])
		if j:
			j.vestir(v[1])
		return j
	var m: Array = NPCS.get(numero, [])
	if m.is_empty():
		return null
	var b := novo(m[0], m[1])
	if b and m.size() > 2:
		b.somar_malha(m[2])
	if b and APAGADAS.has(numero):
		b.apagar_malha(APAGADAS[numero])
	if b and LUZES.has(numero):
		for l in LUZES[numero]:
			b.luz_no_osso(l[0], l[1], l[2], l[3], l[4], m[1])
	if b and FLUTUA.has(numero):
		b.modelo.position.y += FLUTUA[numero]
		b.altura += FLUTUA[numero]
	if b and TINTA.has(numero):
		b.tingir(TINTA[numero])
	if b and LUZ_CHAO.has(numero):
		b.luz_chao(LUZ_CHAO[numero][0], LUZ_CHAO[numero][1])
	if b and TRANSPARENTES.has(numero):
		b.transparente(TRANSPARENTES[numero])
	if b and PARTICULAS.has(numero):
		for pt in PARTICULAS[numero]:
			b.particulas(pt[0], pt[1], pt[2])
	if b and OLHOS.has(numero):
		for k in 2:
			var osso := b.esqueleto.find_bone("osso%d" % OLHOS[numero][k]) if b.esqueleto else -1
			if osso >= 0:
				var at := BoneAttachment3D.new()
				b.esqueleto.add_child(at)
				at.bone_idx = osso
				RastroOlho.no_olho(at, 8 if k == 0 else 20)
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
	b.somar_malha(-1)
	return b


# BlendMesh do cliente: a malha n desenha somada (brilha), como gelo, asa de besouro e o caldeirao do Goblin;
# n = -1: as da arma que o conversor marcou "soma:" (cajado do Lizard King, besta da Valkyrie); -2: todas
func somar_malha(n: int) -> void:
	var i := 0
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if (i == n or n == -2 or (n == -1 and orig and orig.resource_name.begins_with("soma:"))) and orig:
				mi.set_surface_override_material(s, _somado(orig))
			i += 1


static func _somado(orig: BaseMaterial3D) -> BaseMaterial3D:
	var m := orig.duplicate() as BaseMaterial3D
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func apagar_malha(n: int) -> void:
	var i := 0
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if i == n:
				var m := StandardMaterial3D.new()
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.albedo_color = Color(0, 0, 0, 0)
				mi.set_surface_override_material(s, m)
			i += 1


func transparente(alfa: float) -> void:
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig := (mi.get_surface_override_material(s) if mi.get_surface_override_material(s) else mi.mesh.surface_get_material(s)) as BaseMaterial3D
			if orig:
				var m := orig.duplicate() as BaseMaterial3D
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				m.albedo_color.a = alfa
				mi.set_surface_override_material(s, m)


var _particulas: Array = []   # [CPUParticles3D, no que ela segue (osso) ou null]
var _areia: CPUParticles3D       # so solta andando
var _chao: ShaderMaterial        # luz no chao que pisca (Death Gorgon)
var _cor_chao := Color()


func tingir(cor: Color) -> void:
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig := (mi.get_surface_override_material(s) if mi.get_surface_override_material(s) else mi.mesh.surface_get_material(s)) as BaseMaterial3D
			if orig:
				var m := orig.duplicate() as BaseMaterial3D
				m.albedo_color = Color(orig.albedo_color.r * cor.r, orig.albedo_color.g * cor.g, orig.albedo_color.b * cor.b, orig.albedo_color.a)
				mi.set_surface_override_material(s, m)


# AddTerrainLight em volta do monstro: um disco deitado no chao que soma (ou subtrai) a cor,
# caindo em linha reta ate o raio, como a luz pintada nos vertices do terreno
func luz_chao(cor: Color, raio: float) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1))
	g.set_color(1, Color(0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var menos := cor.r < 0.0
	var mat := ShaderMaterial.new()
	mat.shader = EfeitoMU.SHADER_MENOS if menos else EfeitoMU.SHADER
	mat.set_shader_parameter("tex", tex)
	mat.set_shader_parameter("modo", 1)
	_cor_chao = Color(absf(cor.r), absf(cor.g), absf(cor.b))
	mat.set_shader_parameter("cor", _cor_chao)
	if not menos:
		_chao = mat
	var q := PlaneMesh.new()
	q.size = Vector2.ONE * raio * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, 0.06, 0)
	add_child(mi)


# fogo (BITMAP_FIRE) e fumaca (BITMAP_SMOKE) do Ambiente, soltos no mundo e seguindo o osso
func particulas(tipo: String, onde, n: int) -> void:
	var tex: Texture2D = load(Ambiente.PASTA + ("fogo.png" if tipo == "fogo" else "fumaca.png"))
	var c := Ambiente.fogo(tex) if tipo == "fogo" else Ambiente.fumaca(tex)
	c.amount = n
	c.local_coords = false
	c.preprocess = 0.0
	add_child(c)
	var segue: Node3D = null
	if tipo == "areia":
		# BITMAP_SMOKE + 1: poeira cor de areia num quadrado de 2 tiles em volta, so andando
		c.position = Vector3(0, 0.05, 0)
		c.emission_box_extents = Vector3(1.0, 0.05, 1.0)
		var g := Gradient.new()
		g.set_color(0, Color(0.45, 0.38, 0.28))
		g.set_color(1, Color(0, 0, 0))
		c.color_ramp = g
		c.lifetime = 1.0
		c.emitting = false
		_areia = c
	elif onde is String and onde == "corpo":
		c.position = Vector3(0, altura * 0.5, 0)
		c.emission_box_extents = Vector3(altura * 0.2, altura * 0.35, altura * 0.2)
	elif onde is String:
		c.position = Vector3(0, 0.1, 0)
		c.emission_box_extents = Vector3(0.32, 0.16, 0.32)
	elif esqueleto and esqueleto.find_bone("osso%d" % onde) >= 0:
		var at := BoneAttachment3D.new()
		esqueleto.add_child(at)
		at.bone_name = "osso%d" % onde
		segue = at
	_particulas.append([c, segue])


var _luzes: Array = []   # [material, cor] das luzes que pulsam
var _t := 0.0


# CreateSprite no osso: o tamanho e o da textura vezes a escala (em unidades do MU),
# sem crescer com o monstro
func luz_no_osso(tex: String, esc: float, ossos, desl: Vector3, cor, escala_monstro: float) -> void:
	if esqueleto == null:
		return
	var t := EfeitoMU.textura(tex)
	if t == null:
		return
	var lista: Array = []
	if ossos is String:
		for i in esqueleto.get_bone_count():
			if not (i >= 15 and i <= 20) and not (i >= 27 and i <= 32):
				lista.append(i)
	else:
		lista = ossos
	var q := QuadMesh.new()
	q.size = Vector2(t.get_width(), t.get_height()) * esc / escala_monstro
	var mat := ShaderMaterial.new()
	mat.shader = EfeitoMU.SHADER_MENOS if cor is String and cor == "menos" else EfeitoMU.SHADER
	mat.set_shader_parameter("tex", t)
	mat.set_shader_parameter("modo", 0)
	mat.set_shader_parameter("cor", cor if cor is Color else Color(1, 1, 1) if cor is String else Color(1, 0.6, 0.4))
	if not (cor is Color) and cor != "menos":
		_luzes.append([mat, cor])
	for i: int in lista:
		var nome := "osso%d" % i
		if esqueleto.find_bone(nome) < 0:
			continue
		var at := BoneAttachment3D.new()
		esqueleto.add_child(at)
		at.bone_name = nome
		var sp := MeshInstance3D.new()
		sp.mesh = q
		sp.material_override = mat
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sp.position = desl
		at.add_child(sp)


func tem(a: String) -> bool:
	return anim != null and anim.has_animation(a)


# toca a acao (com troca pra parecida se o modelo nao tiver); depois de uma
# que nao repete, volta pro "parado" (menos morrer, que fica no chao)
func tocar(a: String, depois := "parado") -> void:
	if anim == null:
		return
	pedida = a
	if montado():
		var m: Dictionary = MONTADO[_jeito_montaria]
		var chave := a if m.has(a) else ("ataque" if a in NAO_REPETE and a not in ["morre", "golpe"] else "")
		if chave != "":
			var ar: String = m[chave][0]
			if (not _equip.get(0, "").is_empty() or not _equip.get(1, "").is_empty()) and tem(ar + "_a"):
				ar += "_a"
			montaria.tocar(m[chave][1])
			a = ar
	elif nadar and familia == "jogador" and NADO.has(a):
		a = NADO[a]
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
	var cor: String = equip.get("fenrir", "red")
	if cor != _fenrir and _equip.get(8, "") == "13,37":
		_equip.erase(8)   # troca de cor: monta de novo
	_fenrir = cor
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
	if s == 8 and montaria:
		montaria = null
		_jeito_montaria = ""
		_montar()
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
	elif s == 7 and Capa.TIPOS.has(k):
		# capa: so o pano preso nas costas (o cliente nao desenha o modelo do item)
		no.free()
		var c := Capa.nova(esqueleto, k)
		var suporte := Node3D.new()
		add_child(suporte)
		suporte.add_child(c)
		_pecas[s] = suporte
	elif s == 7:
		# o cliente poe a origem da asa no osso 47 (costas) mais 15 pra cima no osso,
		# mas com o giro do boneco (RenderLinkObject sem Link); _process segue o osso
		modelo.add_child(no)
		_voar(no, 0.25)
		_pecas[s] = no
		_osso_asa = esqueleto.find_bone("osso47")
		_seguir_asa()
	elif s == 8 and MONTARIAS.has(k):
		no.free()
		var cfg: Array = MONTARIAS[k]
		var b := Boneco.novo(cfg[0] + (_fenrir if k == "13,37" else ""), cfg[1])
		if b == null:
			return
		b.ritmo = RITMO_MONTARIA[cfg[2]]
		add_child(b)
		if k == "13,3":
			b.position.y = -0.3   # Dinorant: o cliente desce 30 (10 em Tarkan)
		montaria = b
		_jeito_montaria = cfg[2]
		_pecas[s] = b
		_montar()
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


func _process(d: float) -> void:
	for pt in _particulas:
		if pt[1]:
			pt[0].global_position = pt[1].global_position
	if _areia:
		_areia.emitting = acao == "anda" or acao == "corre"
	if _chao:
		var k := randf_range(0.2, 0.9) / 0.55   # Luminosity sorteada a cada quadro (0,2..0,9)
		_chao.set_shader_parameter("cor", Color(_cor_chao.r * k, _cor_chao.g * k, _cor_chao.b * k))
	if not _luzes.is_empty():
		_t += d
		for l in _luzes:
			var k: float = sin(_t * 2.0) * 0.3 + (0.8 if l[1] == "olho" else 0.7)
			l[0].set_shader_parameter("cor", Color(k, k, k) if l[1] == "olho" else Color(k, k * 0.6, k * 0.4))
	if _pecas.has(7) and not Capa.TIPOS.has(_equip.get(7, "")):
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


# entra e sai da agua de Atlans: troca a acao de parado/andar na hora
func nadando(sim: bool) -> void:
	if sim == nadar or familia != "jogador":
		return
	nadar = sim
	print("TESTE nadando %s" % sim)
	var base := acao.trim_suffix("_f")
	for k in NADO:
		if base == k or base == NADO[k]:
			tocar(k)
			return


# montado so fora da zona segura (o cliente esconde a montaria na cidade)
func montado() -> bool:
	return montaria != null and is_instance_valid(montaria) and not _costas and familia == "jogador"


# monta ou desmonta na hora: a montaria aparece ou some e a acao atual troca
func _montar() -> void:
	if montaria and is_instance_valid(montaria):
		montaria.visible = not _costas
	print("TESTE montado %s %s" % [montado(), _jeito_montaria])
	var base := pedida if pedida != "" else "parado"
	if base in ["parado", "anda", "corre"]:
		tocar(base)


func arma_nas_costas(sim: bool) -> void:
	if sim == _costas:
		return
	_costas = sim
	if montaria:
		_montar()
	for s in OSSO_MAO:
		if _pecas.has(s):
			_pecas[s].bone_name = "osso47" if sim else OSSO_MAO[s]
