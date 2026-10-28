class_name Boneco
extends Node3D
# Um modelo do MU animado (dados/personagens/<nome>.glb, feito pelo conversor).
# O GLB vem nas coordenadas do MU (Z pra cima, 100 por tile) com 1 s por quadro;
# aqui ele fica em pe, na escala do mundo, e anda na velocidade do cliente
# (PlaySpeed x 25 quadros por segundo).

const PASTA := "res://dados/personagens/"
# PlaySpeed padrao do cliente S6 (ZzzOpenData.cpp)
const VELOCIDADE := {
	"monstro": {"parado": 0.25, "parado2": 0.2, "anda": 0.34, "ataque": 0.33, "ataque2": 0.33, "golpe": 0.5, "morre": 0.55,
		"ataque3": 0.33, "ataque4": 0.33, "ataque5": 0.33},
	"jogador": {"parado": 0.28, "parado_f": 0.28, "voa": 0.28, "nada": 0.35, "nada_corre": 0.35, "anda": 0.3, "anda_f": 0.3, "corre": 0.3,
		"soco": 0.35, "espada": 0.35, "golpe": 0.4, "morre": 0.45,
		"espada_s1": 0.3, "espada_s2": 0.3, "espada_s3": 0.3, "espada_s4": 0.3, "espada_s5": 0.3,
		"giro": 0.4, "furia": 0.3, "estocada": 0.3, "arco": 0.3, "magia": 0.3, "magia2": 0.3,
		"magia_arma": 0.3, "cura": 0.25, "raio": 0.3, "inferno": 0.3, "fogo_inferno": 0.3,
		"teleporte": 0.3, "nova_carga": 0.5, "nova": 0.3, "lua": 0.3, "destruicao": 0.3, "magia_cheia": 0.3,
		"flecha_infinita": 0.33, "fenrir_skill": 0.37, "um_corte": 0.4, "canhao": 0.2, "tempestade": 0.55,
		"golpe_chama": 0.69, "golpe_dl": 0.25, "teleporte_dl": 0.28, "terremoto_cavalo": 0.3, "vitalidade": 0.34,
		"monta_parado": 0.28, "monta_parado_a": 0.28, "monta_corre": 0.34, "monta_corre_a": 0.34, "monta_ataque": 0.35,
		"cavalo_parado": 0.3, "cavalo_corre": 0.33, "cavalo_ataque": 0.28,
		"fenrir_parado": 0.28, "fenrir_parado_a": 0.28, "fenrir_anda": 0.3, "fenrir_anda_a": 0.3,
		"fenrir_corre": 0.34, "fenrir_corre_a": 0.34, "fenrir_ataque": 0.3, "fenrir_ataque_a": 0.3,
		"parado_espada": 0.26, "parado_2maos": 0.24, "parado_2maos2": 0.24, "parado_lanca": 0.24, "parado_foice": 0.28,
		"parado_arco": 0.22, "parado_besta": 0.22, "parado_varinha": 0.3, "voa_besta": 0.28, "anda_varinha": 0.44, "corre_varinha": 0.76,
		"espada2": 0.35, "espada_e1": 0.35, "espada_e2": 0.35, "golpe_2maos1": 0.35, "golpe_2maos2": 0.35, "golpe_2maos3": 0.35,
		"golpe_2maos2b": 0.35, "golpe_lanca": 0.35, "golpe_foice1": 0.35, "golpe_foice2": 0.35, "golpe_foice3": 0.35,
		"besta": 0.3, "arco_voa": 0.3, "besta_voa": 0.3, "magia_arma2": 0.3},
	"npc": {},
}
# acao pedida -> a que existe no modelo (o jogador nao tem "ataque", tem "soco")
const TROCA := {"ataque": ["ataque", "soco", "parado"], "ataque2": ["ataque2", "ataque", "soco"],
	"golpe": ["golpe", "parado"], "morre": ["morre", "golpe", "parado"], "anda": ["anda", "parado"],
	"corre": ["corre", "anda"], "parado2": ["parado2", "parado"], "ataque3": ["ataque3", "ataque"],
	"ataque4": ["ataque4", "ataque"], "ataque5": ["ataque5", "ataque"]}
const NAO_REPETE := ["morre", "golpe", "ataque", "ataque2", "ataque3", "ataque4", "ataque5", "soco", "espada", "espada_s1", "espada_s2",
	"espada_s3", "espada_s4", "espada_s5", "giro", "furia", "estocada", "arco", "magia", "magia2", "magia_arma",
	"cura", "raio", "inferno", "fogo_inferno", "monta_ataque", "cavalo_ataque", "fenrir_ataque", "fenrir_ataque_a",
	"espada2", "espada_e1", "espada_e2", "golpe_2maos1", "golpe_2maos2", "golpe_2maos3", "golpe_2maos2b", "golpe_lanca",
	"golpe_foice1", "golpe_foice2", "golpe_foice3", "besta", "arco_voa", "besta_voa", "magia_arma2",
	"teleporte", "nova_carga", "nova", "lua", "destruicao", "magia_cheia", "flecha_infinita", "fenrir_skill", "um_corte",
	"canhao", "tempestade", "golpe_chama", "golpe_dl", "teleporte_dl", "terremoto_cavalo", "vitalidade"]

# numero do monstro/NPC no OpenMU -> [modelo, escala], tirado do CreateMonster
# do cliente S6 (ZzzCharacter.cpp). Lorencia, Dungeon, Devias, Noria, Lost Tower e Atlans.
const NPCS := {
	0: ["monster01_sem0", 0.8], 1: ["monster02_sem0", 0.85], 2: ["monster03", 0.5], 3: ["monster10", 0.4],
	4: ["monster01", 1.15], 6: ["monster05", 0.85], 7: ["monster06", 1.6], 14: ["esqueleto1", 0.95],
	226: ["treinador", 1.0], 229: ["marlon", 1.0], 230: ["alex", 1.0], 236: ["esqueleto2", 1.0],
	240: ["baz", 1.0], 247: ["guarda_besta", 1.0], 248: ["martin", 1.0], 249: ["placa", 1.0], 250: ["harold", 1.0],
	251: ["hanzo", 0.95], 253: ["amy", 1.0], 254: ["pasi", 1.0], 255: ["lumen", 1.0],
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
	69: ["monster51", 1, 0], 70: ["monster52", 1.3, -2], 71: ["monster53", 1.1, 1], 72: ["monster54", 1.45],
	73: ["monster55", 0.8], 74: ["monster53", 1.3, 1], 75: ["monster55", 1], 77: ["monster56", 1],
	200: ["npc_ball01", 1.8], 204: ["npc_object82", 1], 205: ["npc_object57", 1], 206: ["npc_object57", 1],
	207: ["npc_object57", 1], 208: ["npc_object57", 1], 209: ["npc_object57", 1], 216: ["npc_npccrown", 1],
	217: ["npc_npccheckfloor", 1], 218: ["npc_npccheckfloor", 1], 220: ["monster78", 1.1], 223: ["npc_npcsenatus", 1.1],
	224: ["npc_npcclerk", 1], 239: ["npc_tournament01", 1], 290: ["monster82", 1.2], 291: ["monster83", 1.8],
	292: ["monster84", 1.4], 293: ["monster85", 1.4], 294: ["monster86", 0.7], 295: ["monster88", 2],
	304: ["monster101", 1.4], 305: ["monster102", 1.35], 306: ["monster103", 1.1], 307: ["monster104", 1.15],
	308: ["monster105", 1.2], 309: ["monster106", 1.8], 310: ["monster99", 1.2], 311: ["monster98", 1.2],
	312: ["monster97", 1.2], 313: ["monster96", 1.25], 314: ["monster99", 1.6], 315: ["monster96", 1.65],
	316: ["monster92", 1.25], 317: ["monster95", 1.3], 340: ["monster93", 1.5], 341: ["monster95", 1.3],
	344: ["monster92", 1.25], 345: ["monster94", 1.25], 348: ["monster100", 1], 349: ["monster90", 2],
	350: ["monster107", 0.95], 351: ["monster108", 0.8], 352: ["monster109", 1.3], 353: ["monster110", 1.3],
	354: ["monster111", 1.3], 355: ["monster112", 1.1], 356: ["monster113", 1.2, 1], 357: ["monster114", 1.2],
	358: ["monster115", 1], 359: ["monster116", 1.3], 360: ["monster117", 1.3], 367: ["npc_to3gate", 4.76],
	369: ["npc_os", 1], 370: ["npc_je", 1], 376: ["npc_npcpharmercy1", 1], 377: ["npc_npcpharmercy2", 1],
	407: ["npc_werequarrel", 1.9], 415: ["npc_silvia", 1], 416: ["npc_rhea", 1], 417: ["npc_marce", 1.05],
	418: ["monster129", 0.95], 419: ["monster130", 0.76], 420: ["monster131", 0.95], 421: ["monster132", 0.88],
	422: ["monster133", 0.95], 423: ["monster134", 0.1615], 424: ["monster135", 1.14], 425: ["monster136", 1.235],
	441: ["monster137", 1], 442: ["monster138", 1], 443: ["monster139", 1], 444: ["monster140", 1.1],
	445: ["monster141", 1.1], 446: ["monster142", 1.3], 447: ["monster143", 0.95], 448: ["monster144", 0.95],
	449: ["monster145", 0.95], 452: ["npc_goblinmaster", 1.1], 453: ["npc_seedgoblin", 0.9], 454: ["monster146", 1.2, 1],
	455: ["monster147", 1.7], 456: ["monster148", 1], 457: ["monster149", 1, 1], 458: ["monster150", 1.5, 1],
	479: ["npc_titus", 1.1], 480: ["monster158", 1, 0], 481: ["monster158", 1, 0], 482: ["monster159", 1, 0],
	483: ["monster159", 1, 0], 484: ["monster160", 0.7], 485: ["monster160", 0.7], 486: ["monster161", 1, 2],
	487: ["monster162", 1, 2], 488: ["monster162", 1, 2], 489: ["monster164", 1], 490: ["monster163", 1],
	491: ["monster163", 1], 492: ["npc_gambler_moss", 0.8], 545: ["npc_unitedmarketplace_christine", 1.1], 546: ["npc_unitedmarkedplace_raul", 1],
	549: ["monster194", 1.35], 550: ["monster195", 1.2], 551: ["monster196", 1.4], 552: ["monster197", 1.75],
	553: ["monster198", 1.15], 554: ["monster199", 1.3], 555: ["monster200", 1.5, 1], 556: ["monster201", 1.35],
	557: ["monster202", 1.5], 558: ["monster203", 1.1], 559: ["monster204", 1.56], 562: ["monster206", 1.9],
	563: ["monster207", 1.1], 564: ["monster208", 1.3, 1], 565: ["monster209", 1.8, 1], 569: ["monster210", 1],
	570: ["monster211", 0.58], 571: ["monster212", 0.64], 572: ["monster213", 1.5], 573: ["monster214", 1.5],
	574: ["monster215", 1.25, 3], 575: ["monster216", 1.45, 3], 576: ["monster217", 1.55, 0], 577: ["npc_unitedmarketplace_christine", 1.1],
	578: ["npc_volvo", 0.9],
	# Chaos Castle (pares: arqueira ou mago, sorteado como no cliente; SORTEIO), Illusion Temple
	# (w_CursedTemple.cpp), Papai Noel pequeno (textura da cor em TEXTURA_NPC), boneco de neve, David
	163: ["monster72_crossbow20", 0.9], 165: ["monster72_crossbow20", 0.9], 167: ["monster72_crossbow20", 0.9],
	169: ["monster72_crossbow20", 0.9], 171: ["monster72_crossbow20", 0.9], 173: ["monster72_crossbow20", 0.9],
	427: ["monster72_crossbow20", 0.9], 380: ["npc_songsom", 1, -3], 381: ["npc_allied", 1.2], 382: ["npc_illusion", 1.2],
	# Illusion Temple: os espiritos (raio, gelo e veneno dos 6 templos) e os jogadores de cada equipe
	# (o servidor manda o jogador com a aparencia 404 ou 405: o cliente desenha o player.bmd com a roupa
	# unitedsoldier ou illusionist, CursedTemple::CreateCharacter)
	386: ["monster124", 1], 387: ["monster125", 1], 388: ["monster126", 1], 389: ["monster124", 1], 390: ["monster125", 1], 391: ["monster126", 1], 392: ["monster124", 1], 393: ["monster125", 1], 394: ["monster126", 1],
	395: ["monster124", 1], 396: ["monster125", 1], 397: ["monster126", 1], 398: ["monster124", 1], 399: ["monster125", 1], 400: ["monster126", 1], 401: ["monster124", 1], 402: ["monster125", 1], 403: ["monster126", 1],
	404: ["templo_aliado", 1], 405: ["templo_ilusao", 1],
	383: ["npc_songko", 1.8, -3], 384: ["npc_songk2", 1.5, -3], 467: ["npc_snowman", 1, -3], 477: ["xmas_snowman", 1.3, -3],
	468: ["npc_xmassanta", 0.43], 469: ["npc_xmassanta", 0.43], 470: ["npc_xmassanta", 0.43], 471: ["npc_xmassanta", 0.43],
	472: ["npc_xmassanta", 0.43], 473: ["npc_xmassanta", 0.43], 474: ["npc_xmassanta", 0.43], 475: ["npc_xmassanta", 0.43],
	579: ["npc_burial", 0.95],
	# os que faltavam (Blood Castle, Devil Square, Chaos Castle, Kalima, Kanturu, Raklion, Imperial Fortress,
	# Doppelganger, invasoes douradas): ferramentas/monstros_novos.py
	19: ["monster13", 1.1], 43: ["monster03", 0.7], 44: ["monster32", 0.9], 50: ["monster39", 1.8],
	53: ["monster40", 1.8, 2], 54: ["monster41_crossbow07", 1.1], 64: ["monster47_bow04", 1.2], 65: ["monster48", 1.3],
	66: ["monster49", 1.7], 67: ["monster28", 1.6], 78: ["monster20", 0.8], 79: ["monster32", 0.9],
	80: ["monster37_staff08", 1.4], 81: ["monster35", 1], 82: ["monster43", 1.8, 2],
	83: ["monster42_crossbow07_crossbow17", 1.4], 84: ["monster48", 1.1], 85: ["monster47_bow04", 1.1],
	86: ["monster60_axe09_axe09", 1], 87: ["monster59", 0.8], 88: ["monster58_mace07", 1.19],
	89: ["monster63_staff01", 1.2], 90: ["monster48", 1.1], 91: ["monster47_bow04", 1.1],
	92: ["monster60_axe09_axe09", 1], 93: ["monster59", 0.8], 94: ["monster58_mace07", 1.19],
	95: ["monster63_staff01", 1.2], 96: ["monster48", 1.1], 97: ["monster47_bow04", 1.1],
	98: ["monster60_axe09_axe09", 1], 99: ["monster59", 0.8], 111: ["monster58_mace07", 1.19],
	112: ["monster63_staff01", 1.2], 113: ["monster48", 1.1], 114: ["monster47_bow04", 1.1],
	115: ["monster60_axe09_axe09", 1], 116: ["monster59", 0.8], 117: ["monster58_mace07", 1.19],
	118: ["monster63_staff01", 1.2], 119: ["monster48", 1.1], 120: ["monster47_bow04", 1.1],
	121: ["monster60_axe09_axe09", 1], 122: ["monster59", 0.8], 123: ["monster58_mace07", 1.19],
	124: ["monster63_staff01", 1.2], 125: ["monster48", 1.1], 126: ["monster47_bow04", 1.1],
	127: ["monster60_axe09_axe09", 1], 128: ["monster59", 0.8], 129: ["monster58_mace07", 1.19],
	130: ["monster63_staff01", 1.2], 131: ["monster62", 0.8], 132: ["monster61", 0.8], 133: ["monster61", 0.8],
	134: ["monster61", 0.8], 135: ["monster49", 1.7], 136: ["monster48", 1.3], 137: ["monster47_bow04", 1.2],
	138: ["monster48", 1.1], 139: ["monster47_bow04", 1.1], 140: ["monster60_axe09_axe09", 1], 141: ["monster59", 0.8],
	142: ["monster58_mace07", 1.19], 143: ["monster63_staff01", 1.2], 144: ["monster64", 1.2, 1],
	145: ["monster68_spear11", 1.5, 0], 146: ["monster66", 0.8], 147: ["monster67", 1.4, 1],
	148: ["monster68_spear11", 1, 0], 149: ["monster69", 1.2, 3], 150: ["monster33", 0.12],
	151: ["monster41_crossbow07", 1.1], 152: ["skill_hellgate", 1], 153: ["skill_hellgate", 1],
	154: ["skill_hellgate", 1], 155: ["skill_hellgate", 1], 156: ["skill_hellgate", 1], 157: ["skill_hellgate", 1],
	158: ["skill_hellgate", 1], 160: ["monster70_sword14_sword14", 1.2], 161: ["monster70_sword14_sword14", 1],
	162: ["monster71_sword17_sword17", 0.9], 164: ["monster71_sword17_sword17", 0.9],
	166: ["monster71_sword17_sword17", 0.9], 168: ["monster71_sword17_sword17", 0.9],
	170: ["monster71_sword17_sword17", 0.9], 172: ["monster71_sword17_sword17", 0.9], 174: ["monster64", 1.2, 1],
	175: ["monster68_spear11", 1.5, 0], 176: ["monster66", 0.8], 177: ["monster67", 1.4, 1],
	178: ["monster68_spear11", 1, 0], 179: ["monster69", 1.2, 3], 180: ["monster70_sword14_sword14", 1.2],
	181: ["monster70_sword14_sword14", 1], 182: ["monster64", 1.2, 1], 183: ["monster68_spear11", 1.5, 0],
	184: ["monster66", 0.8], 185: ["monster67", 1.4, 1], 186: ["monster68_spear11", 1, 0], 187: ["monster69", 1.2, 3],
	188: ["monster70_sword14_sword14", 1.2], 189: ["monster70_sword14_sword14", 1], 190: ["monster64", 1.2, 1],
	191: ["monster68_spear11", 1.5, 0], 192: ["monster66", 0.8], 193: ["monster67", 1.4, 1],
	194: ["monster68_spear11", 1, 0], 195: ["monster69", 1.2, 3], 196: ["monster70_sword14_sword14", 1.2],
	197: ["monster70_sword14_sword14", 1], 215: ["npc_npcbarrier", 1.52], 219: ["npc_npcgateswitch", 1.1],
	221: ["npc_model_npc_catapult_att", 0.8], 222: ["npc_model_npc_catapult_def", 0.8], 231: ["npc_deviastrader01", 1],
	232: ["npc_bloodcastle01", 1], 259: ["npc_kalnpc", 1], 260: ["monster64", 1.2, 1], 261: ["monster68_spear11", 1.5, 0],
	262: ["monster66", 0.8], 263: ["monster67", 1.4, 1], 264: ["monster68_spear11", 1, 0], 265: ["monster69", 1.2, 3],
	266: ["monster70_sword14_sword14", 1.2], 267: ["monster70_sword14_sword14", 1], 268: ["monster64", 1.2, 1],
	269: ["monster68_spear11", 1.5, 0], 270: ["monster66", 0.8], 271: ["monster67", 1.4, 1],
	272: ["monster68_spear11", 1, 0], 273: ["monster69", 1.2, 3], 274: ["monster70_sword14_sword14", 1.2],
	275: ["monster65_staff12", 2], 277: ["monster74", 1], 278: ["monster87", 1, 3], 283: ["monster75", 1],
	285: ["monster75", 1], 286: ["monster77", 1], 287: ["monster78", 1], 288: ["monster80", 1],
	331: ["monster67", 1.4, 1], 332: ["monster68_spear11", 1, 0], 333: ["monster66", 0.8], 334: ["monster64", 1.2, 1],
	335: ["monster69", 1.2, 3], 336: ["monster68_spear11", 1.5, 0], 337: ["monster70_sword14_sword14", 1.2],
	338: ["monster70_sword14_sword14", 1], 361: ["monster122", 1.6], 362: ["monster119", 2.28], 363: ["monster120", 2.28],
	368: ["npc_elpis", 2.5], 408: ["npc_cry2doorhead", 1.2], 409: ["monster92", 1.25], 410: ["monster94", 1.25],
	411: ["monster95", 1.3], 412: ["monster127", 1.5], 426: ["monster71_sword17_sword17", 0.9], 428: ["monster48", 1.1],
	429: ["monster47_bow04", 1.1], 430: ["monster60_axe09_axe09", 1], 431: ["monster59", 0.8],
	432: ["monster58_mace07", 1.19], 433: ["monster63_staff01", 1.2], 434: ["monster113", 1.2], 435: ["monster107", 0.95],
	436: ["monster92", 1.25], 437: ["monster95", 1.3], 438: ["monster115", 1], 439: ["monster117", 1.3],
	440: ["monster93", 1.5], 459: ["monster151", 2, -3], 460: ["monster152", 0.3], 461: ["monster153", 0.3],
	462: ["monster154", 0.3], 476: ["monster156", 1.7], 504: ["monster165", 1.4], 505: ["jerinteu", 1.45],
	506: ["monster167", 1.45], 507: ["monster168", 1.25], 508: ["monster169", 1.55], 509: ["monster170", 1.3],
	510: ["monster171", 1.35], 511: ["monster172", 1.35], 512: ["monster173", 1.27], 513: ["monster174", 1.25],
	514: ["monster175", 1.35], 515: ["monster176", 1], 516: ["monster177", 1.55], 517: ["monster178", 1.25],
	518: ["monster179", 1.2], 519: ["monster180", 0.9], 520: ["monster181", 1.1], 521: ["monster182", 1.1],
	524: ["monster184", 1.25], 525: ["monster185", 1.25], 526: ["monster186", 0.6], 527: ["monster187", 1.25],
	528: ["monster188", 1.25], 529: ["monster191", 1], 530: ["monster190", 0.8], 531: ["monster146", 1.2],
	532: ["monster07", 0.6], 533: ["monster192", 1.1], 541: ["npc_doppelgangerbox", 2.3],
	542: ["npc_doppelgangerbox", 3.3],
}
# modelo sorteado a cada um que nasce (CreateMonster com rand): Chaos Castle pares
const _CC_PAR := [["monster72_crossbow20", 0.9], ["monster73_staff06", 0.9]]
const SORTEIO := {163: _CC_PAR, 165: _CC_PAR, 167: _CC_PAR, 169: _CC_PAR, 171: _CC_PAR, 173: _CC_PAR, 427: _CC_PAR}
# textura trocada na malha 0 (o cliente poe o numero da cor no nome: xmassanta1 a 8)
const TEXTURA_NPC := {468: "xmassanta1", 469: "xmassanta2", 470: "xmassanta3", 471: "xmassanta4",
	472: "xmassanta5", 473: "xmassanta6", 474: "xmassanta7", 475: "xmassanta8"}
# transparencia (AlphaTarget): o Ghost da Dungeon
const TRANSPARENTES := {11: 0.4}
# fogo e fumaca saindo do corpo (MoveCharacter do cliente): [tipo, osso ("corpo" = osso ao
# acaso, "pes" = em volta dos pes), quantas no ar, cor (opcional: a do fogo no comeco, ou a da
# fumaca, que sai a 0,45 dela)]. "faisca" = Spark03 parada que pisca; "agua" = Waterfall2 caindo
const PARTICULAS := {
	35: [["fogo", "corpo", 60]], 40: [["fogo", 2, 12]], 59: [["fogo", 6, 24], ["fogo", 13, 24]],
	10: [["fumaca", "pes", 4]], 12: [["fumaca", "pes", 4]], 51: [["fumaca", "pes", 4]],
	# Tarkan: Beam Knight com chama nas maos (ossos 62 e 77), Death Beam Knight pegando fogo (asas e
	# corpo); areia levantando em volta de quem anda (MonsterMoveSandSmoke, 1 por quadro andando)
	61: [["fogo", 62, 6], ["fogo", 77, 6], ["areia", "pes", 20]], 63: [["fogo", "corpo", 70]],
	57: [["areia", "pes", 20]], 58: [["areia", "pes", 20]], 60: [["areia", "pes", 20]], 62: [["areia", "pes", 20]],
	# Icarus: faiscas do Alquamos, fogo na cabeca do Great Drakan
	69: [["faisca", "corpo", 15, Color(0.5, 0.6, 0.7)]], 75: [["fogo", 18, 24]],
	# Terra das Provas: Fire Golem com fogo e fumaca nas maos e no olho, fumaca verde do Poison Golem
	291: [["fogo", 34, 24], ["fogo", 45, 24], ["fogo", 48, 12], ["fumaca", 34, 30], ["fumaca", 45, 30],
		["fumaca", 48, 12], ["fumaca", 46, 12]],
	293: [["fumaca", 53, 2, Color(0.4, 1, 0.7)], ["fumaca", 54, 2, Color(0.4, 1, 0.7)], ["fumaca", 55, 2, Color(0.4, 1, 0.7)]],
	294: [["areia", "pes", 3]],
	# Aida: agua caindo do Blue Golem, faiscas verdes do Death Rider, fogo vermelho do Hell Maine
	305: [["agua", 12, 30], ["agua", 20, 30], ["agua", 6, 30]], 551: [["agua", 12, 30], ["agua", 20, 30], ["agua", 6, 30]],
	306: [["faisca", 6, 30, Color(0.3, 1, 0.3)]], 550: [["faisca", 6, 30, Color(0.3, 1, 0.3)]],
	309: [["fogo", 20, 32, Color(1, 0.12, 0.08)], ["fogo", 39, 32, Color(1, 0.12, 0.08)]],
	# Crywolf: poeira de quem anda
	310: [["areia", "pes", 3]], 313: [["areia", "pes", 6]], 314: [["areia", "pes", 3]], 315: [["areia", "pes", 6]],
	316: [["areia", "pes", 3]], 317: [["areia", "pes", 3]], 341: [["areia", "pes", 3]], 344: [["areia", "pes", 3]],
	345: [["areia", "pes", 3]], 349: [["areia", "pes", 3]],
	# Kanturu: fumaca do Berserker e do Dreadfear, faiscas do Iron Rider, nevoa azul da Persona
	350: [["fumaca", 9, 16]], 553: [["fumaca", 9, 16]],
	352: [["faisca", 52, 20, Color(0.8, 1, 0.8)], ["faisca", 47, 20, Color(0.8, 1, 0.8)]],
	354: [["areia", "pes", 2]], 355: [["areia", "pes", 2]], 554: [["areia", "pes", 2]],
	357: [["areia", "pes", 20]], 556: [["areia", "pes", 20]],
	358: [["fumaca", "pes", 10, Color(0.43, 0.51, 0.85)]],
	360: [["fumaca", 71, 13], ["fumaca", 68, 13], ["fumaca", 50, 13], ["fumaca", 47, 13]],
	# Elbeland
	422: [["fogo", 30, 54]], 423: [["areia", "pes", 20]],
	# Pantano: fumaca colorida das Shadows, verde do Ghost Napin, fogo do Blaze e do Ice Napin
	444: [["fumaca", "corpo", 20, Color(1, 0.1, 0.1)]], 445: [["fumaca", "corpo", 20, Color(0.3, 0.6, 1)]],
	446: [["fumaca", "corpo", 20, Color(0.5, 1, 0.5)]], 559: [["fumaca", "corpo", 20, Color(1, 1, 1)]],
	448: [["fumaca", 21, 25, Color(0.4, 1, 0.4)], ["fumaca", 37, 25, Color(0.4, 1, 0.4)],
		["fumaca", 65, 25, Color(0.4, 1, 0.4)], ["fumaca", 66, 25, Color(0.4, 1, 0.4)],
		["fumaca", 77, 25, Color(0.4, 1, 0.4)], ["fumaca", 78, 25, Color(0.4, 1, 0.4)], ["fumaca", 79, 25, Color(0.4, 1, 0.4)]],
	449: [["fogo", 10, 20], ["fogo", 61, 20], ["fogo", 72, 20], ["fogo", 21, 20], ["fogo", 122, 15], ["fogo", 116, 15]],
	558: [["fogo", 10, 20, Color(0.25, 0.6, 0.7)], ["fogo", 61, 20, Color(0.25, 0.6, 0.7)],
		["fogo", 72, 20, Color(0.25, 0.6, 0.7)], ["fogo", 21, 20, Color(0.25, 0.6, 0.7)],
		["fogo", 122, 15, Color(0.25, 0.6, 0.7)], ["fogo", 116, 15, Color(0.25, 0.6, 0.7)]],
	# Raklion: fumaca fria do Iron Knight
	458: [["fumaca", 20, 3, Color(0.3, 0.6, 1)], ["fumaca", 37, 3, Color(0.3, 0.6, 1)], ["fumaca", 45, 3, Color(0.3, 0.6, 1)], ["fumaca", 51, 3, Color(0.3, 0.6, 1)]],
	565: [["fumaca", 20, 3, Color(0.3, 0.6, 1)], ["fumaca", 37, 3, Color(0.3, 0.6, 1)], ["fumaca", 45, 3, Color(0.3, 0.6, 1)], ["fumaca", 51, 3, Color(0.3, 0.6, 1)]],
	# Vulcanus: Slaughterer, Assassins (vermelho e verde) e Lava Giants (laranja e roxo)
	484: [["fumaca", 6, 4]], 485: [["fumaca", 6, 4]],
	486: [["fumaca", 37, 5, Color(1, 0.2, 0.1)], ["fumaca", 11, 5, Color(1, 0.2, 0.1)], ["fumaca", 70, 5, Color(1, 0.2, 0.1)], ["fumaca", 65, 5, Color(1, 0.2, 0.1)]],
	487: [["fumaca", 37, 5, Color(0.3, 1, 0.3)], ["fumaca", 11, 5, Color(0.3, 1, 0.3)], ["fumaca", 70, 5, Color(0.3, 1, 0.3)], ["fumaca", 65, 5, Color(0.3, 1, 0.3)]],
	488: [["fumaca", 37, 5, Color(0.3, 1, 0.3)], ["fumaca", 11, 5, Color(0.3, 1, 0.3)], ["fumaca", 70, 5, Color(0.3, 1, 0.3)], ["fumaca", 65, 5, Color(0.3, 1, 0.3)]],
	489: [["fumaca", 7, 4, Color(1, 0.5, 0.15)]], 490: [["fumaca", 7, 4, Color(0.6, 0.2, 1)]], 491: [["fumaca", 7, 4, Color(0.6, 0.2, 1)]],
	# Karutan: poeira do Gollock
	572: [["areia", "pes", 20]],
}
# NPC que fica no ar (CreateMonster: Position[2] = chao + 140): a Lala da Noria
const FLUTUA := {242: 1.4, 200: 0.3}   # a bola do Battle Soccer fica 30 acima do chao (MoveCharacter: Height + 30)
# cor do corpo (BodyLight): o Poison Bull nasce envenenado (eDeBuff_Poison = 0,3 1 0,5);
# Alpha Crust verde agua, Dark Phoenix sem luz do chao, os Hero de Crywolf azulados
const TINTA := {8: Color(0.3, 1, 0.5), 74: Color(0.1, 1.0, 0.8), 77: Color(0.6, 0.6, 0.6),
	314: Color(0.5, 0.5, 0.6), 315: Color(0.5, 0.5, 0.8), 359: Color(0.9, 0.9, 1.0)}
# cor de uma malha so (o cliente troca a BodyLight antes de cada RenderMesh): {malha: cor}
const TINTA_MALHA := {
	75: {0: Color(0.1, 0.1, 0.1), 1: Color(1, 0.1, 0.1), 2: Color(0.1, 0.1, 0.1), 3: Color(0.1, 0.1, 0.1), 4: Color(0.1, 0.1, 0.1)},
	290: {1: Color(0.6, 0.4, 0.4)}, 294: {0: Color(0.5, 0.6, 0.8), 1: Color(0.5, 0.8, 0.6)}, 293: {1: Color(0.1, 1, 0.1)},
}
# alfa de uma malha so (o manto das Shadows do Pantano)
const ALFA_MALHA := {444: {3: 0.7}, 445: {3: 0.7}, 446: {4: 0.7}}
# textura correndo na malha (BlendMeshTexCoordU/V e StreamMesh): {malha: UV por segundo}
const CORRE := {71: {1: Vector2(-0.4, 0)}, 74: {1: Vector2(-0.4, 0)}, 77: {0: Vector2(0, 0.1)},
	291: {0: Vector2(0.2, 0.2)}, 293: {1: Vector2(0.2, 0.2)}, 305: {0: Vector2(-0.3, -0.3)}, 551: {0: Vector2(-0.3, -0.3)},
	306: {3: Vector2(-0.6, -0.6)}, 550: {3: Vector2(-0.6, -0.6)}, 345: {2: Vector2(0.5, 0)}}
# malha que so desenha somada com o brilho pulsando: [malha, base, amp, w], luz = base + amp * sin(w t)
const SOMADAS := {
	351: [[2, 0.5, 0.5, 2.0], [3, 0.5, 0.5, 2.0]], 345: [[2, 0.3, 0.0, 0.0]], 291: [[0, 0.9, 0.4, 1.2]],
	480: [[0, 0.6, 0.4, 4.0]], 481: [[0, 0.6, 0.4, 4.0]], 482: [[0, 0.6, 0.4, 4.0]], 483: [[0, 0.6, 0.4, 4.0]],
}
# passada somada por cima da malha normal (scripts/camada.gdshader): [malhas (-1 = todas),
# textura ("" = a da malha), jeito ("" = UV da malha, "chrome", "chrome2" e "metal" = presa na normal),
# cor, pulso [base, amp, w] (opcional), UV correndo por segundo (opcional)]
const CAMADAS := {
	# douradas das invasoes (RenderCharacter: RENDER_METAL e RENDER_CHROME por cima, na cor dos
	# monstros, OtherModelColors 1 0,5 0); Golden Titan e Golden Soldier so o metal com Shiny02;
	# Balrog, Silver Valkyrie, Zaikan (brilho 0,5) e Metal Balrog (RENDER_EXTRA) so o cromo
	43: [[-1, "shiny01", "metal", Color(1, 0.5, 0)], [-1, "chrome01", "chrome", Color(1, 0.5, 0)]],
	78: [[-1, "shiny01", "metal", Color(1, 0.5, 0)], [-1, "chrome01", "chrome", Color(1, 0.5, 0)]],
	79: [[-1, "shiny01", "metal", Color(1, 0.5, 0)], [-1, "chrome01", "chrome", Color(1, 0.5, 0)]],
	80: [[-1, "shiny01", "metal", Color(1, 0.5, 0)], [-1, "chrome01", "chrome", Color(1, 0.5, 0)]],
	81: [[-1, "shiny01", "metal", Color(1, 0.5, 0)], [-1, "chrome01", "chrome", Color(1, 0.5, 0)]],
	82: [[-1, "shiny01", "metal", Color(1, 0.5, 0)], [-1, "chrome01", "chrome", Color(1, 0.5, 0)]],
	83: [[-1, "shiny01", "metal", Color(1, 0.5, 0)], [-1, "chrome01", "chrome", Color(1, 0.5, 0)]],
	53: [[-1, "shiny02", "metal", Color(1, 0.5, 0)]], 54: [[-1, "shiny02", "metal", Color(1, 0.5, 0)]],
	38: [[-1, "chrome01", "chrome", Color(1, 0.2, 0)]], 52: [[-1, "chrome01", "chrome", Color(1, 1, 1)]],
	59: [[-1, "chrome01", "chrome", Color(0.5, 0.25, 0)]], 67: [[-1, "chrome01", "chrome", Color(0.8, 0.8, 1)]],
	72: [[-1, "bab2", "chrome", Color(0.9, 0.8, 1.0)]],
	73: [[[1, 2], "", "chrome", Color(0.2, 0.2, 0.8)], [[1, 2], "", "chrome2", Color(1, 1, 1)]],
	75: [[[1, 2], "", "chrome", Color(1.0, 0.1, 0.1)]],
	77: [[-1, "", "chrome", Color(1.0, 0.5, 0.0), [0.65, 0.35, 1.0]]],
	292: [[0, "", "chrome", Color(0.8, 0.6, 1.0)]],
	295: [[4, "", "chrome", Color(1.0, 0.5, 0.0)], [[0, 1, 3], "", "chrome", Color(0.75, 0.65, 0.5)],
		[0, "bossmap1_r", "", Color(1, 1, 1), [0.6, 0.3, 1.2]]],
	305: [[0, "", "chrome", Color(0.9, 0.9, 0.9)]], 551: [[0, "", "chrome", Color(0.9, 0.9, 0.9)]],
	306: [[3, "", "chrome", Color(0.9, 0.9, 0.9)]], 550: [[3, "", "chrome", Color(0.9, 0.9, 0.9)]],
	309: [[0, "", "chrome", Color(1, 0, 0)], [2, "", "chrome", Color(0.5, 0, 0)]],
	314: [[-1, "chrome01", "chrome", Color(0.5, 0.5, 0.6)]],
	315: [[-1, "chrome01", "chrome", Color(0.5, 0.5, 0.8)]],
	349: [[-1, "chrome03", "chrome2", Color(1, 1, 1)]],
	350: [[0, "buserbody_r", "", Color(1, 1, 1), [1, 1, 2]], [1, "busersword_r", "", Color(1, 1, 1), [1, 1, 2]]],
	553: [[0, "buserbody_r", "", Color(1, 1, 1), [1, 1, 2]], [1, "busersword_r", "", Color(1, 1, 1), [1, 1, 2]]],
	353: [[1, "", "", Color(1, 1, 1), [1, 0, 0], Vector2(0, 0.5)], [3, "chrome01", "chrome", Color(1, 1, 1)],
		[4, "", "", Color(1, 1, 1), [0.5, 0.5, 1]]],
	354: [[0, "bladeeff2_r", "", Color(1, 1, 1), [1, 1, 2]]],
	355: [[1, "", "", Color(1, 1, 1), [0.5, 0.5, 2]], [1, "chrome02", "chrome2", Color(1, 1, 1)]],
	554: [[1, "", "", Color(1, 1, 1), [0.5, 0.5, 2]], [1, "chrome02", "chrome2", Color(1, 1, 1)]],
	358: [[0, "prsona_r", "", Color(1, 1, 1), [0.5, 0.5, 2]], [2, "prsonass_r", "", Color(1, 1, 1), [0.5, 0.5, 2]]],
	359: [[2, "illumi_r", "", Color(1, 1, 1), [1, 1, 2]], [3, "", "", Color(1, 1, 1), [0.5, 0.5, 2]]],
	444: [[4, "red_shadows", "", Color(2, 2, 2), [0.6, 0.5, 2]]],
	445: [[4, "blue_shadows", "", Color(2, 2, 2), [0.6, 0.5, 2]]],
	446: [[0, "green_shadows", "", Color(2, 2, 2), [0.6, 0.5, 2]]],
	455: [[1, "chrome06", "chrome", Color(1, 1, 1)]], 562: [[1, "chrome06", "chrome", Color(1, 1, 1)]],
	456: [[[1, 3], "", "", Color(1, 1, 1)], [3, "chrome01", "chrome", Color(1, 1, 1)]],
	563: [[[1, 3], "", "", Color(1, 1, 1)], [3, "chrome01", "chrome", Color(1, 1, 1)]],
	458: [[0, "icenightlight", "", Color(1, 1, 1), [0.6, 0.4, 10]]], 565: [[0, "icenightlight", "", Color(1, 1, 1), [0.6, 0.4, 10]]],
	484: [[0, "bugbear_r", "", Color(1, 1, 1), [0.5, 0.5, 3]]], 485: [[0, "bugbear_r", "", Color(1, 1, 1), [0.5, 0.5, 3]]],
	486: [[1, "pk_mon03_red", "", Color(1, 1, 1), [0.6, 0.3, 5]], [3, "pk_mon02_fire", "", Color(1, 1, 1), [0.6, 0.3, 5]]],
	487: [[1, "pk_mon03_green", "", Color(1, 1, 1), [0.6, 0.3, 5]], [3, "pk_mon02_green", "", Color(1, 1, 1), [0.6, 0.3, 5]]],
	488: [[1, "pk_mon03_green", "", Color(1, 1, 1), [0.6, 0.3, 5]], [3, "pk_mon02_green", "", Color(1, 1, 1), [0.6, 0.3, 5]]],
	489: [[0, "lavagiantaa_e", "", Color(1, 1, 1), [0.5, 1.5, 1]]],
	490: [[0, "lavagiantba_e", "", Color(1, 1, 1), [0.5, 1.5, 1]]], 491: [[0, "lavagiantba_e", "", Color(1, 1, 1), [0.5, 1.5, 1]]],
	570: [[0, "bonese", "", Color(1, 1, 1), [0.5, 1, 2]]],
	573: [[0, "kryptaball2", "", Color(1, 1, 1), [1, 1, 2]]],
	575: [[0, "bora_golem_effect", "", Color(1, 1, 1), [1, 1, 2]], [1, "bora_golem2_effect", "", Color(1, 1, 1), [1, 1, 2]]],
	576: [[2, "king_golem01_effect", "", Color(1, 1, 1), [1, 1, 2]], [3, "king_golem02_effect", "", Color(1, 1, 1), [1, 1, 2]],
		[1, "king_golem03_effect", "", Color(1, 1, 1), [1, 1, 2]]],
}
# raio azul entre ossos, refeito todo quadro (BITMAP_JOINT_THUNDER subtipo 7): [largura em m, pares]
const RAIOS := {
	70: [0.14, [[2, 3], [3, 4], [4, 5], [2, 10], [10, 11], [2, 18], [18, 22], [22, 23], [23, 24], [24, 25], [18, 31], [31, 32], [32, 33], [33, 34]]],
	73: [0.2, [[13, 14], [14, 15], [15, 16], [22, 23]]],
}
# luz que o monstro pinta no chao em volta (AddTerrainLight): [cor (negativa escurece), raio em
# tiles, pisca (falta = sim)]. Death Gorgon vermelha piscando; Zaikan e Death Beam Knight escurecem
# (-1,3); os golens e bruxas de Aida e da Terra das Provas com luz fixa
const LUZ_CHAO := {35: [Color(0.55, 0.11, 0), 2], 59: [Color(-1.3, -1.3, -1.3), 3], 63: [Color(-1.3, -1.3, -1.3), 3],
	291: [Color(1.0, 0.2, 0.1), 3, false], 304: [Color(0.7, 0.1, 0.1), 3, false], 552: [Color(0.7, 0.1, 0.1), 3, false],
	305: [Color(0, 0, 0.7), 3, false], 551: [Color(0, 0, 0.7), 3, false], 309: [Color(1.0, 0, 0), 3, false]}
# olhos que deixam rastro de luz (MoveEye + CreateJoint BITMAP_JOINT_ENERGY 2 e 3): [osso direito, esquerdo]
const OLHOS := {57: [8, 9], 58: [24, 25], 59: [24, 25], 60: [11, 12], 61: [8, 9], 62: [8, 9], 63: [8, 9],
	349: [9, 10], 351: [16, 17], 576: [9, 9]}
# monstro que e um jogador vestido (Cursed Wizard: Legendary +9, cajado e escudo)
const VESTIDOS := {
	# Doppelganger (GMDoppelGanger1.cpp): a ilusao de cada classe com o conjunto e a arma
	534: ["classe_elf", {0: "4,15", 1: "4,17", 2: "7,13", 3: "8,13", 4: "9,13", 5: "10,13", 6: "11,13"}],
	535: ["classe_dk", {0: "0,13", 2: "7,1", 3: "8,1", 4: "9,1", 5: "10,1", 6: "11,1"}],
	536: ["classe_dw", {0: "5,9", 1: "6,15", 2: "7,18", 3: "8,18", 4: "9,18", 5: "10,18", 6: "11,18"}],
	537: ["classe_mg", {0: "0,31", 3: "8,15", 4: "9,15", 5: "10,15", 6: "11,15"}],
	538: ["classe_dl", {0: "2,10", 1: "6,7", 2: "7,27", 3: "8,27", 4: "9,27", 5: "10,27", 6: "11,27"}],
	539: ["classe_sum", {0: "5,18", 2: "7,40", 3: "8,40", 4: "9,40", 5: "10,40", 6: "11,40"}],
	34: ["classe_dw", {0: "5,5", 1: "6,14", 2: "7,3", 3: "8,3", 4: "9,3", 5: "10,3", 6: "11,3",
		"niveis": {0: 9, 1: 9, 2: 9, 3: 9, 4: 9, 5: 9, 6: 9}}],
	# Elf Soldier (MakeElfHelper): Red Spirit +13 e Wings of Spirits, parada voando
	257: ["classe_elf", {2: "7,24", 3: "8,24", 4: "9,24", 5: "10,24", 6: "11,24", 7: "12,3",
		"niveis": {2: 13, 3: 13, 4: 13, 5: 13, 6: 13}}],
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
	# Icarus
	69: [["flare01", 0.6, [10, 18, 37, 38, 51, 52, 58, 59, 66], Vector3.ZERO, Color(0.68, 0.77, 0.85)]],
	70: [["flare01", 0.8, [20], Vector3.ZERO, Color(1, 1, 1)]],
	71: [["eye01", 2.0, [26], Vector3(5, 0, 0), "olho"], ["eye01", 2.0, [27], Vector3(-5, 0, 0), "olho"]],
	74: [["eye01", 2.0, [26], Vector3(5, 0, 0), "olho"], ["eye01", 2.0, [27], Vector3(-5, 0, 0), "olho"]],
	73: [["flare01", 0.8, [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 52, 53, 54, 55, 56, 57, 58],
		Vector3.ZERO, Color(0.1, 0.1, 1.0)]],
	# Terra das Provas
	290: [["flare01", 0.5, [29, 30], Vector3.ZERO, Color(0.9, 0.2, 0.1)]],
	294: [["flare01", 0.7, [18, 19], Vector3.ZERO, Color(0.9, 0.2, 0.1)]],
	295: [["flare01", 0.5, [8, 9], Vector3(0, -2, 0), Color(1.8, 0.4, 0.2)]],
	# Aida
	304: [["impack03", 0.8, [76, 110], Vector3.ZERO, Color(1.25, 0.7, 1.25)], ["impack03", 1.1, [107], Vector3.ZERO, Color(1.25, 0.7, 1.25)],
		["impack03", 1.0, [108], Vector3.ZERO, Color(1.25, 0.7, 1.25)], ["impack03", 1.7, [109], Vector3.ZERO, Color(1.25, 0.7, 1.25)],
		["shiny02", 4.0, [0], Vector3(0, 0, -65), Color(0.7, 0.5, 0.7)]],
	552: [["impack03", 0.8, [76, 110], Vector3.ZERO, Color(1.25, 0.7, 1.25)], ["impack03", 1.1, [107], Vector3.ZERO, Color(1.25, 0.7, 1.25)],
		["impack03", 1.0, [108], Vector3.ZERO, Color(1.25, 0.7, 1.25)], ["impack03", 1.7, [109], Vector3.ZERO, Color(1.25, 0.7, 1.25)],
		["shiny02", 4.0, [0], Vector3(0, 0, -65), Color(0.7, 0.5, 0.7)]],
	306: [["impack03", 3.0, [6], Vector3(60, -30, 0), Color(0, 0.25, 0)]],
	550: [["impack03", 3.0, [6], Vector3(60, -30, 0), Color(0, 0.25, 0)]],
	308: [["impack03", 0.4, [37, 38, 39, 40, 44, 45], Vector3.ZERO, Color(0.4, 0.85, 0.5)]],
	309: [["impack03", 0.3, [9, 10], Vector3.ZERO, Color(0.95, 0, 0)], ["impack03", 1.0, [33, 34, 35], Vector3.ZERO, Color(0.95, 0, 0)]],
	# Crywolf
	312: [["flare01", 1.0, [28], Vector3.ZERO, Color(0, 1.3, 0.26)], ["shiny02", 0.5, [27, 29], Vector3.ZERO, Color(2, 2, 2)]],
	313: [["flare01", 3.5, [6], Vector3.ZERO, Color(1.8, 0.4, 0.2)]],
	315: [["flare01", 3.5, [6], Vector3.ZERO, Color(1.8, 0.4, 0.2)]],
	345: [["bowe", 1.5, [27], Vector3.ZERO, Color(1, 1, 1)], ["flare01", 3.8, [27], Vector3.ZERO, Color(0.9, 0.9, 2.1)],
		["shockwave", 0.85, [27], Vector3.ZERO, Color(0.3, 0.3, 0.7)], ["shiny02", 0.8, [28], Vector3.ZERO, Color(0.45, 0.35, 1.1)],
		["flare01", 1.5, [28], Vector3.ZERO, Color(0.3, 0.3, 0.7)]],
	# Kanturu
	356: [["flare01", 3.0, [7], Vector3(19, -2, 0), Color(0.4, 0.6, 0.8)], ["flare01", 1.0, [7], Vector3(19, -2, 0), Color(0.27, 0.45, 0.72)]],
	555: [["flare01", 3.0, [7], Vector3(19, -2, 0), Color(0.4, 0.6, 0.8)], ["flare01", 1.0, [7], Vector3(19, -2, 0), Color(0.27, 0.45, 0.72)]],
	358: [["flare01", 2.0, [73], Vector3.ZERO, Color(0.43, 0.51, 0.85)]],
	360: [["impack03", 0.5, [9, 10], Vector3.ZERO, Color(0.25, 0.7, 0.6)]],
	# Pantano
	441: [["flare01", 2.0, [15], Vector3.ZERO, Color(2, 1.2, 0.2)]], 557: [["flare01", 2.0, [15], Vector3.ZERO, Color(2, 1.2, 0.2)]],
	442: [["flare01", 2.0, [15], Vector3.ZERO, Color(2, 0, 0)]], 443: [["flare01", 2.0, [15], Vector3.ZERO, Color(0.4, 1.4, 2)]],
	447: [["flare01", 2.2, [7, 4, 5, 10, 22, 11, 23, 12, 24, 34, 39], Vector3.ZERO, Color(0.1, 0.2, 1)]],
	449: [["flare01", 4.0, [10, 61, 72, 21], Vector3.ZERO, Color(1, 0.2, 0)], ["flare01", 1.0, [122, 116], Vector3.ZERO, Color(1, 0.2, 0)]],
	558: [["flare01", 4.0, [10, 61, 72, 21], Vector3.ZERO, Color(1, 1, 1)], ["flare01", 1.0, [122, 116], Vector3.ZERO, Color(1, 1, 1)]],
	# Vulcanus
	480: [["lightmarks", 0.6, [9], Vector3.ZERO, Color(0.1, 0.4, 0.5)]], 481: [["lightmarks", 0.6, [9], Vector3.ZERO, Color(0.1, 0.4, 0.5)]],
	482: [["lightmarks", 0.6, [9], Vector3.ZERO, Color(0.1, 0.4, 0.5)]], 483: [["lightmarks", 0.6, [9], Vector3.ZERO, Color(0.1, 0.4, 0.5)]],
	489: [["lightmarks", 1.9, [3], Vector3.ZERO, Color(0.9, 0.4, 0.1)], ["lightmarks", 0.9, [37, 43], Vector3.ZERO, Color(0.9, 0.4, 0.1)]],
	490: [["lightmarks", 1.9, [3], Vector3.ZERO, Color(0.5, 0.1, 0.9)], ["lightmarks", 0.9, [37, 43], Vector3.ZERO, Color(0.5, 0.1, 0.9)]],
	491: [["lightmarks", 1.9, [3], Vector3.ZERO, Color(0.5, 0.1, 0.9)], ["lightmarks", 0.9, [37, 43], Vector3.ZERO, Color(0.5, 0.1, 0.9)]],
	# Karutan
	569: [["flare01", 1.5, [15], Vector3.ZERO, Color(0.55, 0.22, 0.11)]],
	570: [["flare01", 2.0, [8], Vector3.ZERO, Color(0.55, 0.22, 0.11)]],
	576: [["shiny05", 0.7, [9, 88, 89], Vector3.ZERO, Color(0.55, 0.22, 0.55)],
		["shiny05", 1.0, [33, 34, 58, 59], Vector3.ZERO, Color(0.55, 0.22, 0.55)], ["flare02", 0.2, [9], Vector3.ZERO, Color(0.3, 0.02, 0.1)]],
}
# malha que o cliente desenha somada com luz 0 (some): a Hydra so acende a 5 no ataque
const APAGADAS := {49: 5}
# classe do OpenMU (classes.json) >> 2 -> corpo padrao da classe
const CLASSES := ["classe_dw", "classe_dk", "classe_elf", "classe_mg", "classe_dl", "classe_sum", "classe_rf"]

static var _info := {}
static var no_caos := false   # dentro do Chaos Castle: asa e pet somem e a arma e a do castelo

var anim: AnimationPlayer
var nome_modelo := ""
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
			if numero == 257:
				RastroOlho.em_volta(j)
				j.altura += 0.7   # BoundingBoxMax[2] += 70: voando, o clique pega mais alto
		return j
	var m: Array = SORTEIO[numero].pick_random() if SORTEIO.has(numero) else NPCS.get(numero, [])
	if m.is_empty():
		return null
	var b := novo(m[0], m[1])
	if b and m.size() > 2:
		b.somar_malha(m[2])
	if b and TEXTURA_NPC.has(numero):
		var tx := EfeitoMU.textura(TEXTURA_NPC[numero])
		b.mudar_malha(0, func(mt: BaseMaterial3D) -> void: mt.albedo_texture = tx)
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
		var lc: Array = LUZ_CHAO[numero]
		b.luz_chao(lc[0], lc[1], lc[2] if lc.size() > 2 else true)
	if b and TRANSPARENTES.has(numero):
		b.transparente(TRANSPARENTES[numero])
	if b and PARTICULAS.has(numero):
		for pt in PARTICULAS[numero]:
			b.particulas(pt[0], pt[1], pt[2], pt[3] if pt.size() > 3 else null)
	if b and SOMADAS.has(numero):
		for e in SOMADAS[numero]:
			b.somar_malha(e[0])
			b._pulsam.append([b._superficie(e[0]), e[1], e[2], e[3], null])
	if b and TINTA_MALHA.has(numero):
		for k in TINTA_MALHA[numero]:
			b.mudar_malha(k, func(m: BaseMaterial3D) -> void: m.albedo_color *= TINTA_MALHA[numero][k])
	if b and ALFA_MALHA.has(numero):
		for k in ALFA_MALHA[numero]:
			b.mudar_malha(k, Boneco._com_alfa.bind(ALFA_MALHA[numero][k]))
	if b and CORRE.has(numero):
		for k in CORRE[numero]:
			var mc := b.mudar_malha(k, func(_m: BaseMaterial3D) -> void: pass)
			if mc:
				b._correm.append([mc, CORRE[numero][k]])
	if b and CAMADAS.has(numero):
		for c in CAMADAS[numero]:
			b.camada(c[0], c[1], c[2], c[3], c[4] if c.size() > 4 else [1, 0, 0], c[5] if c.size() > 5 else Vector2.ZERO)
	if b and RAIOS.has(numero):
		b.raios(RAIOS[numero][0], RAIOS[numero][1])
	if b and OLHOS.has(numero):
		for k in (1 if OLHOS[numero][0] == OLHOS[numero][1] else 2):
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
	b.nome_modelo = nome
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


# as poses da foto da carta (saudar, aplaudir... AT_GREETING1 a AT_RUSH1): ficam num GLB a parte (emotes_jogador,
# esqueleto do player.bmd e uma malha so) pra nao pesar os 7 modelos de classe; a foto junta ao boneco
static var _emotes: AnimationLibrary


func com_emotes() -> int:
	if anim == null or familia != "jogador":
		return 0
	if _emotes == null:
		var cena = load(PASTA + "emotes_jogador.glb") if ResourceLoader.exists(PASTA + "emotes_jogador.glb") else null
		if cena == null:
			return 0
		var no: Node = cena.instantiate()
		var ap := no.find_children("*", "AnimationPlayer", true, false)
		if not ap.is_empty():
			_emotes = (ap[0] as AnimationPlayer).get_animation_library("")
		no.free()
	if _emotes == null:
		return 0
	var lib := anim.get_animation_library("")
	var n := 0
	for nome in _emotes.get_animation_list():
		if not lib.has_animation(nome):
			_emotes.get_animation(nome).loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(nome, _emotes.get_animation(nome))
			n += 1
	return n


# BlendMesh do cliente: a malha n desenha somada (brilha), como gelo, asa de besouro e o caldeirao do Goblin;
# n = -1: as da arma que o conversor marcou "soma:" (cajado do Lizard King, besta da Valkyrie); -2: todas;
# -3: as de textura *_R (a pele de luz: aneis da estatua e cestos do Illusion Temple, asa do boneco de neve)
func somar_malha(n: int) -> void:
	var i := 0
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if (i == n or n == -2 or (n == -1 and orig and orig.resource_name.begins_with("soma:"))
					or (n == -3 and orig and "_r." in orig.resource_name.to_lower())) and orig:
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


# cor do corpo pelos debuffs (RenderPartObjectEffect: BodyLight do veneno, gelo, atordoado) e a meia
# transparencia da invisibilidade; branco e 1 voltam o material de antes
func tinta_buff(cor: Color, alfa := 1.0) -> void:
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var k := "sem_buff_%d" % s
			if not mi.has_meta(k):
				mi.set_meta(k, mi.get_surface_override_material(s))
			var orig = mi.get_meta(k)
			if cor == Color(1, 1, 1) and alfa >= 1.0:
				mi.set_surface_override_material(s, orig)
				mi.remove_meta(k)
				continue
			var base := (orig if orig else mi.mesh.surface_get_material(s)) as BaseMaterial3D
			if base == null:
				continue
			var m := base.duplicate() as BaseMaterial3D
			m.albedo_color = Color(base.albedo_color.r * cor.r, base.albedo_color.g * cor.g, base.albedo_color.b * cor.b,
				base.albedo_color.a * alfa)
			if alfa < 1.0:
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			mi.set_surface_override_material(s, m)


# AddTerrainLight em volta do monstro: um disco deitado no chao que soma (ou subtrai) a cor,
# caindo em linha reta ate o raio, como a luz pintada nos vertices do terreno
func luz_chao(cor: Color, raio: float, pisca := true) -> void:
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
	if not menos and pisca:
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
func particulas(tipo: String, onde, n: int, cor = null) -> void:
	var c: CPUParticles3D
	if tipo == "faisca" or tipo == "agua":
		c = _particula_nova(tipo)
	else:
		var tex: Texture2D = load(Ambiente.PASTA + ("fogo.png" if tipo == "fogo" else "fumaca.png"))
		c = Ambiente.fogo(tex) if tipo == "fogo" else Ambiente.fumaca(tex)
	if cor is Color:
		var g := c.color_ramp.duplicate() as Gradient
		g.set_color(0, cor * (0.45 if tipo == "fumaca" else 1.0))
		c.color_ramp = g
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


# BITMAP_SPARK + 1 (faisca parada que pisca, 5 quadros) e BITMAP_WATERFALL_2 subtipo 1 (gota
# que cai 3 a 5 por quadro, 30 quadros, escala 0,6 a 1,1, girando)
func _particula_nova(tipo: String) -> CPUParticles3D:
	var c := CPUParticles3D.new()
	c.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	c.emission_box_extents = Vector3(0.1, 0.1, 0.1)
	c.angle_min = 0.0
	c.angle_max = 360.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1))
	g.set_color(1, Color(0, 0, 0))
	c.color_ramp = g
	if tipo == "faisca":
		c.lifetime = 0.4
		c.initial_velocity_min = 0.0
		c.initial_velocity_max = 0.3
		c.spread = 180.0
		c.gravity = Vector3(0, -0.3, 0)
		c.scale_amount_min = 1.0
		c.scale_amount_max = 1.4
		c.mesh = Ambiente._quad_somado(EfeitoMU.textura("spark03"), 0.32)
	else:
		c.lifetime = 1.2
		c.direction = Vector3.DOWN
		c.initial_velocity_min = 0.75
		c.initial_velocity_max = 1.25
		c.gravity = Vector3.ZERO
		c.scale_amount_min = 0.6
		c.scale_amount_max = 1.1
		g.set_color(0, Color(0.7, 0.7, 0.7))
		c.mesh = Ambiente._quad_somado(EfeitoMU.textura("waterfall2"), 0.64)
	return c


# [MeshInstance3D, superficie] da malha n, na ordem do somar_malha
func _superficie(n: int) -> Array:
	var i := 0
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if i == n:
				return [mi, s]
			i += 1
	return []


# copia o material da malha n (o somado, se ja tiver), muda com f e poe de volta
func mudar_malha(n: int, f: Callable) -> BaseMaterial3D:
	var a := _superficie(n)
	if a.is_empty():
		return null
	var mi: MeshInstance3D = a[0]
	var orig := (mi.get_surface_override_material(a[1]) if mi.get_surface_override_material(a[1]) else mi.mesh.surface_get_material(a[1])) as BaseMaterial3D
	if orig == null:
		return null
	var m := orig.duplicate() as BaseMaterial3D
	f.call(m)
	mi.set_surface_override_material(a[1], m)
	return m


static func _com_alfa(m: BaseMaterial3D, a: float) -> void:
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.albedo_color.a = a


const SHADER_CAMADA := preload("res://scripts/camada.gdshader")


# RenderMesh de novo por cima, somado (camada.gdshader): a passada vai no next_pass do material
# de cada malha pedida (no navegador uma copia da MeshInstance com esqueleto nao desenha)
func camada(malhas, tex: String, jeito: String, cor: Color, pulso: Array, corre: Vector2) -> Array[ShaderMaterial]:
	var quais: Array = malhas if malhas is Array else [malhas]
	var feitas: Array[ShaderMaterial] = []
	var i := 0
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			if malhas is int and malhas == -1 or i in quais:
				var orig := mi.mesh.surface_get_material(s)
				# o material de troca (mudar_malha, somar_malha) ja e so desta malha; o do modelo e copiado
				var base := mi.get_surface_override_material(s)
				if base == null:
					base = _copia_passadas(orig)
				if base:
					mi.set_surface_override_material(s, base)
					var t: Texture2D = EfeitoMU.textura(tex) if tex != "" else (orig.albedo_texture if orig is BaseMaterial3D else null)
					var m := ShaderMaterial.new()
					m.shader = SHADER_CAMADA
					m.set_shader_parameter("tex", t)
					m.set_shader_parameter("cor", cor)
					m.set_shader_parameter("modo", 1 if jeito == "chrome" else 2 if jeito == "chrome2" else 3 if jeito == "metal" else 0)
					m.set_shader_parameter("corre", corre)
					m.set_shader_parameter("pulso", Vector3(pulso[0], pulso[1], pulso[2]))
					var fim: Material = base
					while fim.next_pass:
						fim = fim.next_pass
					fim.next_pass = m
					feitas.append(m)
			i += 1
	return feitas


# copia do material com as passadas dele (o original e dividido com os outros do mesmo modelo)
static func _copia_passadas(mat: Material) -> Material:
	if mat == null:
		return null
	var c := mat.duplicate() as Material
	var x := c
	while x.next_pass:
		x.next_pass = x.next_pass.duplicate()
		x = x.next_pass
	return c


var _raios: Array = []           # [largura, pares de ossos]
var _raio_mi: MeshInstance3D


# BITMAP_JOINT_THUNDER subtipo 7 entre pares de ossos: fita somada azul, refeita todo quadro
# com o meio tremendo
func raios(largura: float, pares: Array) -> void:
	_raios = [largura, pares]
	_raio_mi = MeshInstance3D.new()
	_raio_mi.top_level = true
	_raio_mi.mesh = ImmediateMesh.new()
	_raio_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_raio_mi.material_override = EfeitoMU._material("jointthunder01", Color(0.5, 0.5, 1.0), 1)
	add_child(_raio_mi)


func _desenhar_raios() -> void:
	var im := _raio_mi.mesh as ImmediateMesh
	im.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null or not visible:
		return
	var olho := cam.global_position
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var meia: float = _raios[0] * 0.5
	for par in _raios[1]:
		var a := esqueleto.find_bone("osso%d" % par[0])
		var b := esqueleto.find_bone("osso%d" % par[1])
		if a < 0 or b < 0:
			continue
		var pa := esqueleto.to_global(esqueleto.get_bone_global_pose(a).origin)
		var pb := esqueleto.to_global(esqueleto.get_bone_global_pose(b).origin)
		var tam := pa.distance_to(pb)
		var pts: Array[Vector3] = [pa]
		for k in range(1, 4):
			pts.append(pa.lerp(pb, k / 4.0) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * tam * 0.12)
		pts.append(pb)
		for k in pts.size() - 1:
			var p0: Vector3 = pts[k]
			var p1: Vector3 = pts[k + 1]
			var lado := (p1 - p0).cross(olho - p0).normalized() * meia
			var u0 := float(k) / (pts.size() - 1)
			var u1 := float(k + 1) / (pts.size() - 1)
			for v in [[p0 - lado, u0, 0.0], [p0 + lado, u0, 1.0], [p1 + lado, u1, 1.0],
					[p0 - lado, u0, 0.0], [p1 + lado, u1, 1.0], [p1 - lado, u1, 0.0]]:
				im.surface_set_uv(Vector2(v[1], v[2]))
				im.surface_add_vertex(v[0])
	im.surface_end()


var _pulsam: Array = []   # [[mi, superficie], base, amp, w, cor original] das malhas somadas que pulsam
var _correm: Array = []   # [material, UV por segundo]
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
	var chave := _chave_montado(a)
	if chave != "":
		montaria.tocar(MONTADO[_jeito_montaria][chave][1])
	var real := resolver(a)
	if real == "":
		return
	if a in ["ataque", "arco"]:
		_golpes += 1
	_bater_asa(real.begins_with("voando"))
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


# a acao que tocar(a) toca agora (sem tocar): montado, voando, nadando, com a arma, feminina ou a parecida
func resolver(a: String) -> String:
	var chave := _chave_montado(a)
	if chave != "":
		a = MONTADO[_jeito_montaria][chave][0]
		if (not _equip.get(0, "").is_empty() or not _equip.get(1, "").is_empty()) and tem(a + "_a"):
			a += "_a"
	elif not montado():
		a = _postura(a)
	if feminino and tem(a + "_f"):
		a += "_f"
	if tem(a):
		return a
	for t in TROCA.get(a, [a, "parado"]):
		if tem(t):
			return t
	return ""


func _chave_montado(a: String) -> String:
	if not montado():
		return ""
	var m: Dictionary = MONTADO[_jeito_montaria]
	return a if m.has(a) else ("ataque" if a in NAO_REPETE and a not in ["morre", "golpe"] else "")


# laminas de duas maos com pose propria (Dark Reign Blade, Rune Blade, Explosion Blade, Sword Dancer)
const LAMINAS_2 := ["0,21", "0,23", "0,25", "0,31"]
var _golpes := 0   # SwordCount: alterna os golpes da arma


# pose do jogador a pe (SetPlayerStop, SetPlayerWalk e SetPlayerAttack do cliente): fora da zona
# segura, com asa ou capa, parado e andando viram voo; com arma na mao, a pose e o golpe da arma
func _postura(a: String) -> String:
	if familia != "jogador":
		return a
	var besta := _besta(_equip.get(0, ""))
	var arco := _arco(_equip.get(1, ""))
	var asa: bool = _equip.get(7, "") != ""
	if asa and not _costas and a in ["parado", "anda", "corre"]:
		return ("voa" if a == "parado" else "voando") + ("_besta" if besta else "")
	if nadar and NADO.has(a):
		return NADO[a]
	var d: String = _equip.get(0, "")
	var e: String = _equip.get(1, "")
	var g := int(d.get_slice(",", 0)) if d != "" else -1
	var ge := int(e.get_slice(",", 0)) if e != "" else -1
	var duas := ItensMU.duas_maos(d)
	if a in ["ataque", "arco"]:
		if d == "" and e == "":
			return "soco" if a == "ataque" else a
		if arco or besta:
			return ("arco" if arco else "besta") + ("_voa" if asa else "")
		if a == "arco":
			return a
		if g >= 0 and g <= 2:
			if d in LAMINAS_2:
				return "golpe_2maos2b"
			if duas:
				return "golpe_2maos%d" % (_golpes % 3 + 1)
			if ge >= 0 and ge <= 2:
				return ["espada", "espada_e1", "espada2", "espada_e2"][_golpes % 4]
			return ["espada", "espada2"][_golpes % 2]
		if ge >= 0 and ge <= 2:
			return ["espada_e1", "espada_e2"][randi() % 2]
		if g == 5:
			return ["magia_arma", "magia_arma2"][randi() % 2] if duas else ["espada", "espada2"][randi() % 2]
		if d in ["3,1", "3,2"]:
			return "golpe_lanca"
		if g == 3:
			return "golpe_foice%d" % (_golpes % 3 + 1)
		return "soco"
	if _costas or not a in ["parado", "anda", "corre"]:
		return a
	var k := ""
	if g >= 0 and g <= 2:
		if d in LAMINAS_2:
			k = "2maos2"
		elif duas:
			k = "2maos"
		elif a == "corre" and ge >= 0 and ge <= 2:
			k = "" if nome_modelo == "classe_rf" else "2espadas"
		else:
			k = "espada"
	elif g == 3:
		if d in ["3,1", "3,2"]:
			k = "foice" if a == "anda" and d == "3,2" else "lanca"   # o cliente compara a Dragon Lance errado no andar
		elif a == "parado" and not duas:
			k = "espada"
		else:
			k = "lanca" if a == "corre" else "foice"
	elif d.begins_with("5,") and int(d.get_slice(",", 1)) in range(14, 21):
		k = "varinha"
	elif g == 5:
		k = ("lanca" if a == "corre" else "foice") if duas else "espada"
	elif arco:
		k = "arco"
	elif besta:
		k = "besta"
	return a + "_" + k if k != "" else a


static func _arco(k: String) -> bool:
	if not k.begins_with("4,"):
		return false
	var n := int(k.get_slice(",", 1))
	return n <= 6 or n == 17 or (n >= 20 and n <= 24)


static func _besta(k: String) -> bool:
	if not k.begins_with("4,"):
		return false
	var n := int(k.get_slice(",", 1))
	return (n >= 8 and n <= 14) or n == 16 or n == 18 or n == 19


# flechas e virotes: sempre nas costas (o cliente nao desenha municao na mao)
static func _municao(k: String) -> bool:
	return k in ["4,7", "4,15"]


# asa bate rapido voando (PlaySpeed 1,0) e devagar parada (0,25)
func _bater_asa(rapido: bool) -> void:
	if not _pecas.has(7) or Capa.TIPOS.has(_equip.get(7, "")) or not is_instance_valid(_pecas[7]):
		return
	var ap := (_pecas[7] as Node).find_children("*", "AnimationPlayer", true, false)
	if not ap.is_empty():
		ap[0].speed_scale = 4.0 if rapido else 1.0


# a pose de parado/andando de novo (trocou arma, asa ou entrou/saiu da zona segura)
func _repor() -> void:
	var base := pedida if pedida != "" else "parado"
	if base in ["parado", "anda", "corre"]:
		tocar(base)


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
	if no_caos:
		equip = ChaosCastle.vestido_no_caos(nome_modelo, equip)
	var niveis: Dictionary = equip.get("niveis", {})
	var cor: String = equip.get("fenrir", "red")
	if cor != _fenrir and _equip.get(8, "") == "13,37" and equip.get(8, "") == "13,37":
		_equip.erase(8)   # troca de cor: monta de novo (tirando o Fenrir, o laco abaixo desmonta)
	_fenrir = cor
	var antes := [_equip.get(0, ""), _equip.get(1, ""), _equip.get(7, "")]
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
		if k != "" and not (s == 1 and k == Pets.CORVO):   # o Dark Raven voa sozinho (Corvo), nao vai na mao
			_por(s, k)
	if antes != [_equip.get(0, ""), _equip.get(1, ""), _equip.get(7, "")]:
		_repor()


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
		var costas := _costas or _municao(k)
		at.bone_name = "osso47" if costas else OSSO_MAO[s]
		var enc := Node3D.new()
		enc.transform = _encaixe(k, s == 1, nome_modelo == "classe_rf", costas)
		at.add_child(enc)
		enc.add_child(no)
		_pecas[s] = at
		BrilhoMU.aplicar(no, k, _niveis.get(s, 0))
		if not _municao(k):
			_rastros[s] = RastroArma.na_arma(no)
	elif s == 7 and Capa.TIPOS.has(k):
		# capa: os panos presos nas costas; Cape of Emperor e Overrule tambem desenham o
		# modelo do item no osso 19 (a gola), as outras nao
		var suporte := Node3D.new()
		add_child(suporte)
		for i in Capa.TIPOS[k].size():
			suporte.add_child(Capa.nova(esqueleto, k, i))
		if Capa.GOLA.has(k):
			var e: Array = Capa.GOLA[k]
			var at := BoneAttachment3D.new()
			at.bone_name = "osso19"
			esqueleto.add_child(at)
			var enc := Node3D.new()
			enc.transform = ModelosMU.transf_mu(e[0], e[1], e[2], e[3], e[4], e[5])
			at.add_child(enc)
			enc.add_child(no)
			_voar(no, 0.25)
			suporte.tree_exiting.connect(at.queue_free)
		else:
			no.free()
		_pecas[s] = suporte
	elif s == 7:
		# o cliente poe a origem da asa no osso 47 (costas) mais 15 pra cima no osso,
		# mas com o giro do boneco (RenderLinkObject sem Link); _process segue o osso
		modelo.add_child(no)
		_voar(no, 0.25)
		_pecas[s] = no
		_bater_asa(acao.begins_with("voando"))
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
		EfeitoMontaria.ligar(b, cfg[2], _fenrir)
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


# onde o cliente poe a arma no osso. Na mao (RenderLinkObject sem Link) e o osso da mao direto: o
# modelo da arma ja vem feito pra mao. Nas costas (com Link) entra o giro e o deslocamento de cada
# tipo (besta, os arcos e escudos com encaixe proprio) e a arma da esquerda gira mais.
const ENCAIXE := {"4,20": [-60, 0, -80, -5, 20, 0], "4,23": [-60, 0, -80, -5, 20, -5], "4,24": [90, 0, -80, 10, 20, -5],
	"5,9": [110, 180, 90, -10, 5, -10], "5,8": [70, 0, 90, -10, 5, 10], "6,16": [30, 0, 90, -20, 0, -20],
	"6,14": [50, 0, 90, -28, 0, -25], "6,15": [50, 0, 90, -28, 0, -25], "6,6": [30, 0, 90, -15, 0, -25]}
# armas comuns que o Rage Fighter segura mais pra frente e menor (IsRagefighterCommonWeapon)
const ARMAS_RF := ["0,0", "0,1", "1,0", "1,1", "1,3", "2,0", "2,1", "2,2", "2,3", "2,4"]


static func _encaixe(k: String, esquerda: bool, rf := false, costas := true) -> Transform3D:
	rf = rf and k in ARMAS_RF
	if not costas:
		# o Rage Fighter desenha as armas comuns a 0,9 (_KnightScale)
		return Transform3D().scaled_local(Vector3.ONE * 0.9) if rf else Transform3D()
	var g := int(k.get_slice(",", 0))
	var e: Array
	if _besta(k):
		e = [0, 20, 180, -10, 8, 40]
	elif ENCAIXE.has(k):
		e = ENCAIXE[k]
	elif g == 6:
		e = [70, 0, 90, -10, 0, 0]
	elif g == 4:
		e = [70, 0, 90, -10, 5, 10]
	else:
		e = [70, 0, 90, -20, 5, 40]
	var t := ModelosMU.transf_mu(e[0], e[1], e[2], e[3], e[4], e[5])
	if rf:
		t.origin += Vector3(0, 10, 25)
	# arma na mao esquerda (menos escudo e o Arrow Viper Bow): o cliente gira mais e desloca
	if esquerda and g != 6 and k != "4,20":
		if rf:
			t.origin.y += 7
		t = t * ModelosMU.transf_mu(145, 0, 265 if rf else 275, 0, 10, -30)
	if rf:
		t = t.scaled_local(Vector3.ONE * 0.9)
	return t


# marca da guilda no braco direito (RenderGuild): RenderPlane3D(5, 7) preso no osso 26 (o ombro), girado (80, 45, 135) e
# deslocado (20, -5, -10); o Rage Fighter desce (5, 0, -21). A cor 0 da marca e transparente.
var _marca: BoneAttachment3D


func por_marca(tex: Texture2D) -> void:
	if _marca:
		_marca.queue_free()
		_marca = null
	if tex == null or esqueleto == null or esqueleto.find_bone("osso26") < 0:
		return
	var w := 5.0
	var h := 7.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := [Vector3(-w, -w, -h), Vector3(w, w, -h), Vector3(w, w, h), Vector3(-w, -w, h)]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[i])
		st.add_vertex(v[i])
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.name = "marca_guilda"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var t := ModelosMU.transf_mu(80, 45, 135, 20, -5, -10)
	if nome_modelo == "classe_rf":
		t.origin = Vector3(5, 0, -21)
	mi.transform = t
	_marca = BoneAttachment3D.new()
	_marca.bone_name = "osso26"
	esqueleto.add_child(_marca)
	_marca.add_child(mi)


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
	if not _pulsam.is_empty() or not _correm.is_empty():
		_t += d
		for p in _pulsam:
			if p[0].is_empty():
				continue
			var m := p[0][0].get_surface_override_material(p[0][1]) as BaseMaterial3D
			if m == null:
				continue
			if p[4] == null:
				p[4] = m.albedo_color
			var k: float = maxf(p[1] + p[2] * sin(_t * p[3]), 0.0)
			var c0: Color = p[4]
			m.albedo_color = Color(c0.r * k, c0.g * k, c0.b * k, c0.a)
		for c in _correm:
			c[0].uv1_offset += Vector3(c[1].x, c[1].y, 0) * d
	if not _raios.is_empty() and esqueleto:
		_desenhar_raios()
	if not _luzes.is_empty():
		if _pulsam.is_empty() and _correm.is_empty():
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


const GOLPES := ["ataque", "soco", "espada", "espada_s1", "espada_s2", "espada_s3", "espada_s4", "espada_s5", "giro", "furia", "estocada",
	"espada2", "espada_e1", "espada_e2", "golpe_2maos1", "golpe_2maos2", "golpe_2maos3", "golpe_2maos2b", "golpe_lanca",
	"golpe_foice1", "golpe_foice2", "golpe_foice3", "um_corte", "lua", "destruicao", "golpe_dl"]


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
	_repor()


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
	else:
		_repor()
	for s in OSSO_MAO:
		if _pecas.has(s):
			var k: String = _equip.get(s, "")
			var costas := sim or _municao(k)
			_pecas[s].bone_name = "osso47" if costas else OSSO_MAO[s]
			_pecas[s].get_child(0).transform = _encaixe(k, s == 1, nome_modelo == "classe_rf", costas)
