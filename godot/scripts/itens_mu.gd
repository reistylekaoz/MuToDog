class_name ItensMU
extends RefCounted
# O que o cliente sabe dos itens: tamanho, onde equipa, nome (dados/itens_info.json
# e itens.json, tirados do OpenMU) e o icone (dados/icones.png, feito pelo
# testes/icones.sh a partir do modelo 3D de cada item).

const JOIAS_ALVO := ["14,13", "14,14", "14,16", "14,42", "14,43", "14,44"]  # vao em cima de outro item

static var _info := {}
static var _nomes := {}
static var _icones := {}
static var _atlas: Texture2D


static func _carregar() -> void:
	if not _info.is_empty():
		return
	_info = _json("res://dados/itens_info.json")
	_nomes = _json("res://dados/itens.json")
	_icones = _json("res://dados/icones.json")
	if ResourceLoader.exists("res://dados/icones.png"):
		_atlas = load("res://dados/icones.png")


static func _json(c: String) -> Dictionary:
	if not FileAccess.file_exists(c):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(c))
	return d if d is Dictionary else {}


static func chave(it: Dictionary) -> String:
	return "%d,%d" % [it.grupo, it.numero]


# [largura, altura, slots, durabilidade, consome, skill, valor, nivel de drop, duas maos]
static func info(it: Dictionary) -> Array:
	_carregar()
	return _info.get(chave(it), [1, 1, [], 0, false, -1, 0, 0])


# arma de duas maos (TwoHand do Item.bmd do cliente): muda a pose de parado, andar e o golpe
static func duas_maos(k: String) -> bool:
	_carregar()
	var i: Array = _info.get(k, [])
	return i.size() > 8 and i[8]


static func tamanho(it: Dictionary) -> Vector2i:
	var i := info(it)
	return Vector2i(int(i[0]), int(i[1]))


static func slots(it: Dictionary) -> Array:
	return info(it)[2]


static func consome(it: Dictionary) -> bool:
	return info(it)[4]


static func nome(it: Dictionary) -> String:
	_carregar()
	var n: String = _nomes.get(chave(it), "Item %s" % chave(it))
	# um numero com nome por nivel (14,7: Potion of Bless +0, Potion of Soul +1)
	if ";" in n:
		var v := n.split(";")
		return v[clampi(it.get("nivel", 0), 0, v.size() - 1)]
	if it.get("nivel", 0) > 0:
		n += " +%d" % it.nivel
	return n


# poções e joias empilham: a "durabilidade" e a quantidade
static func empilha(it: Dictionary) -> bool:
	return it.grupo == 14 and int(info(it)[3]) <= 3 and consome(it)


static func linhas(it: Dictionary) -> Array:
	var l := []
	var cor := Color(1, 1, 1)
	if it.exc > 0:
		cor = Color(0.4, 0.95, 0.5)
	elif it.nivel >= 7 or it.sorte:
		cor = Color(0.6, 0.85, 1.0)
	l.append([("Excelente " if it.exc > 0 else "") + nome(it), cor])
	var i := info(it)
	if empilha(it) or it.grupo == 14:
		if it.durabilidade > 1:
			l.append(["Quantidade: %d" % it.durabilidade, Color(0.85, 0.85, 0.85)])
	elif int(i[3]) > 0:
		l.append(["Durabilidade: %d" % it.durabilidade, Color(0.85, 0.85, 0.85)])
	if it.skill:
		l.append(["Skill da arma", Color(0.6, 0.75, 1.0)])
	if it.sorte:
		l.append(["Sorte (+5% de sucesso na joia, +5% de critico)", Color(0.6, 0.75, 1.0)])
	if it.get("opcao", 0) > 0:
		l.append(["Opcao adicional +%d" % (it.opcao * 4), Color(0.6, 0.75, 1.0)])
	if it.exc > 0:
		l.append(["Opcoes excelentes: %d" % _bits(it.exc), Color(0.4, 0.95, 0.5)])
	if consome(it) and chave(it) not in JOIAS_ALVO:
		l.append(["Botao direito: usar", Color(0.95, 0.8, 0.45)])
	elif not slots(it).is_empty():
		l.append(["Botao direito: equipar ou tirar", Color(0.95, 0.8, 0.45)])
	if chave(it) in JOIAS_ALVO:
		l.append(["Arraste em cima do item pra usar", Color(0.95, 0.8, 0.45)])
	return l


# Preco de compra na loja: a mesma conta do servidor (OpenMU ItemPriceCalculator,
# CalculateFinalBuyingPrice), que e a do cliente (ItemValue no ZzzInfomation.cpp).
const PRECO_FIXO := {"14,13": 9000000, "14,14": 6000000, "12,15": 810000, "14,16": 45000000,
	"14,22": 36000000, "14,31": 60000000, "14,41": 18600, "14,42": 18600, "14,43": 18600, "14,44": 18600,
	"13,15": 33000000, "13,35": 30000, "13,36": 90000, "13,37": 150000, "14,20": 900, "14,9": 750,
	"13,52": 3000000, "13,53": 3000000, "13,29": 5000, "14,28": 600000}
const PRECO_POR_UNIDADE := {"14,35": 2000, "14,36": 4000, "14,37": 6000, "14,38": 2500, "14,39": 5000,
	"14,40": 7500, "13,32": 150, "13,33": 300, "13,34": 3000, "14,29": 30000}
const SOBE_NIVEL := {5: 4, 6: 10, 7: 25, 8: 45, 9: 65, 10: 95, 11: 135, 12: 185, 13: 245, 14: 305, 15: 365}
const PORNIVEL_8 := [10000, 10000, 50000, 100000, 300000, 500000, 800000, 1000000, 1200000]


static func preco(it: Dictionary) -> int:
	var i := info(it)
	var k := chave(it)
	var g: int = it.grupo
	var n: int = it.numero
	var lv: int = it.nivel
	var dur: int = it.durabilidade
	var valor: int = i[6]
	var p := 0
	if valor > 0 and (g == 15 or g == 12):
		return _arredonda(valor)
	var drop: int = int(i[7]) + lv * 3
	if it.exc > 0:
		drop += 25
	if k in PRECO_FIXO:
		p = PRECO_FIXO[k]
	elif k in PRECO_POR_UNIDADE:
		p = PRECO_POR_UNIDADE[k] * dur
	elif k == "4,15" or k == "4,7":   # flechas e virotes: pelo tanto que vem no maco
		var base: int = [70, 1200, 2000, 2800][clampi(lv, 0, 3)] if k == "4,15" else [100, 1400, 2200, 3000][clampi(lv, 0, 3)]
		p = base * dur / maxi(int(i[3]), 1)
	elif k == "14,3" or k == "14,6":
		p = dur * 1500 * (lv + 1)
	elif k == "13,14":
		p = 7500000 if lv == 1 else 180000
	elif k == "14,7":
		p = dur * (900000 if lv == 0 else 450000)
	elif k == "13,11":
		p = 2400000 if lv == 1 else 1000000
	elif k == "13,7":
		p = [1500000, 1200000, 0][mini(lv, 2)]
	elif k == "13,3":
		p = 960000 + (300000 if it.get("opcao", 0) > 0 else 0)
	elif k == "14,17":
		p = PORNIVEL_8[clampi(lv, 0, 7)]
	elif k == "14,18":
		p = [15000, 15000, 75000, 150000, 450000, 750000, 1200000, 1500000][clampi(lv, 0, 7)]
	elif k == "14,19":
		p = 60000 if lv == 1 else (84000 if lv == 2 else (lv - 1) * 60000)
	elif k == "14,21":
		p = dur * 3900 if lv == 3 else 9000
	elif k == "13,18":
		p = 150000 if lv == 1 else 600000 + (lv - 1) * 60000
	elif k == "13,16" or k == "13,17":
		p = PORNIVEL_8[clampi(lv, 0, 8)]
	elif k in ["13,49", "13,50", "13,51"]:
		p = 500000 if lv == 1 else (lv + 1) * 200000
	elif k == "13,20":
		p = 30000 if lv == 0 else 0
	elif k == "13,31":
		p = [30000000, 15000000, 0][mini(lv, 2)]
	elif valor > 0:
		p = valor * valor * 10 / 12
		if g == 14 and n <= 8:   # pocoes e antidoto: dobra por nivel, vezes a quantidade
			p = p * int(pow(2, lv)) / 10 * 10 * maxi(dur, 1)
			return _arredonda(p)
	elif (g == 12 and ((n > 6 and n < 36) or (n > 43 and n != 50))) or g == 13 or g == 15:
		p = drop * drop * drop + 100
	else:
		drop += SOBE_NIVEL.get(lv, 0)
		var asa := g == 12 and (n <= 6 or (n >= 36 and n <= 43) or n == 49 or n == 50)
		if asa:
			p = (drop + 40) * drop * drop * 11 + 40000000
		else:
			p = (drop + 40) * drop * drop / 8 + 100
		if (g < 6 and int(i[0]) < 2) or g == 6:   # arma de uma mao e escudo: 80%
			p = p * 80 / 100
		if it.skill:
			p += int(p * 1.5)
		if it.sorte:
			p += p * 25 / 100
		var o: int = it.get("opcao", 0)
		if o == 1:
			p += int(p * 0.6)
		elif o > 1:
			p += int(p * 0.7 * pow(2, o - 1))
		for x in _bits(it.exc):
			p += p
	return _arredonda(mini(p, 3000000000))


static func _arredonda(p: int) -> int:
	if p >= 1000:
		return p / 100 * 100
	if p >= 100:
		return p / 10 * 10
	return p


static func _bits(v: int) -> int:
	var n := 0
	while v > 0:
		n += v & 1
		v >>= 1
	return n


# desenha o icone do item dentro do retangulo (centrado, sem esticar)
static func desenhar(ci: CanvasItem, it: Dictionary, r: Rect2, cor := Color.WHITE) -> void:
	_carregar()
	var a: Array = _icones.get(chave(it), [])
	if a.is_empty() or _atlas == null:
		ci.draw_rect(r.grow(-2), Color(0.5, 0.5, 0.6, 0.5 * cor.a))
		return
	var src := Rect2(a[0], a[1], a[2], a[3])
	var e := minf(r.size.x / src.size.x, r.size.y / src.size.y)
	var t := src.size * e
	ci.draw_texture_rect_region(_atlas, Rect2(r.position + (r.size - t) / 2.0, t), src, cor)
