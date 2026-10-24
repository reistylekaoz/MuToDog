class_name DicaItem
extends RefCounted
# Caixa de informacao do item, copiada do RenderItemInfo do cliente S6 (MuMain Engine/Object/ZzzInventory.cpp):
# a mesma ordem, as mesmas cores e os textos do proprio cliente (dados/textos_eng.json = GlobalText do Text_eng.bmd).
# Os numeros saem do Item.bmd (dados/itens_bmd.json, ferramentas/dados_dica.py) com a conta por nivel do cliente,
# que e a mesma do OpenMU (ItemPowerUpFactory e ItemExtensions.CalculateRequirement).

const BRANCO := Color8(255, 255, 255)
const AZUL := Color8(128, 179, 255)
const VERMELHO := Color8(255, 51, 26)
const AMARELO := Color8(255, 204, 26)
const VERDE := Color8(26, 255, 128)
const ROXO := Color8(255, 26, 255)
const FUNDO_VERMELHO := Color8(160, 0, 0)   # TEXT_COLOR_DARKRED: texto branco em fundo vermelho
const CINZA := Color8(150, 150, 150)
const ROSA := Color8(255, 90, 200)          # TEXT_COLOR_REDPURPLE (opcao 380)

# bonus por nivel do item (+0 a +15), cumulativo como no ItemConvert e no OpenMU
const POR_NIVEL := [0, 3, 6, 9, 12, 15, 18, 21, 24, 27, 31, 36, 42, 49, 57, 66]
const POR_NIVEL_ASA3 := [0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 41, 47, 54, 62, 71, 81]

# asas: 1, 2 ou 3 = geracao; capas da 2a geracao contam a parte
const ASA1 := ["12,0", "12,1", "12,2", "12,41"]
const ASA2 := ["12,3", "12,4", "12,5", "12,6", "12,42", "12,49", "13,30"]
const ASA3 := ["12,36", "12,37", "12,38", "12,39", "12,40", "12,43", "12,50"]
# opcao adicional da asa pelos bits 0x10/0x20 do byte excelente (OpenMU Wings.cs BuildOptions)
const OPCAO_ASA := {
	"12,0": {0: "vida"}, "12,1": {0: "magia"}, "12,2": {0: "dano"}, "12,41": {0: "magia"},
	"12,3": {2: "vida", 0: "dano"}, "12,4": {0: "vida", 2: "magia"}, "12,5": {0: "vida", 2: "dano"},
	"12,6": {0: "magia", 2: "dano"}, "12,42": {0: "maldicao", 2: "magia"}, "12,49": {0: "vida", 2: "dano"},
	"13,30": {0: "dano"},
	"12,36": {0: "vida", 3: "dano", 2: "defesa"}, "12,37": {0: "vida", 3: "magia", 2: "defesa"},
	"12,38": {0: "vida", 3: "dano", 2: "defesa"}, "12,39": {0: "vida", 3: "dano", 2: "magia"},
	"12,40": {0: "vida", 3: "dano", 2: "defesa"}, "12,43": {0: "vida", 3: "magia", 2: "maldicao"},
	"12,50": {0: "vida", 3: "dano", 2: "defesa"}}
# skill da arma -> texto do cliente "<Skill> skill (Mana:%d)"
const TEXTO_SKILL := {18: 80, 19: 81, 20: 82, 21: 83, 22: 84, 23: 85, 24: 86, 56: 98, 49: 745, 60: 1210,
	66: 1186, 62: 1189, 76: 1928, 223: 1695, 225: 1789, 260: 3153, 261: 3154}
# nome da classe por evolucao (1, 2, 3): DW DK Elf MG DL Summoner RF
const NOMES_CLASSE := [[20, 25, 1669], [21, 26, 1668], [22, 27, 1670], [23, 23, 1671], [24, 24, 1672],
	[1687, 1688, 1689], [3150, 3150, 3151]]
# pendentes e aneis que usam as opcoes excelentes de ataque
const JOIAS_ATAQUE := ["13,12", "13,13", "13,25", "13,27", "13,28"]

# o personagem que esta jogando (jogo.gd preenche ao entrar): pinta de vermelho o que falta
static var eu := {"nivel": 1, "forca": 0, "agilidade": 0, "vitalidade": 0, "energia": 0, "comando": 0, "classe": 0}
static var _bmd := {}
static var _txt := {}
static var _skills := {}
static var _extra := {}
# os itens que o personagem esta vestindo (inventario.gd preenche): conta as pecas do set ancient
static var equipados := []


static func _carregar() -> void:
	if not _txt.is_empty():
		return
	_bmd = ItensMU._json("res://dados/itens_bmd.json")
	# o JSON chega com float: as contas do cliente sao inteiras (divisao que trunca)
	for k in _bmd:
		var d: Dictionary = _bmd[k]
		for c in d:
			d[c] = d[c].map(func(v): return int(v)) if d[c] is Array else int(d[c])
	_txt = ItensMU._json("res://dados/textos_eng.json")
	_skills = ItensMU._json("res://dados/skills.json")
	# set ancient, harmony, socket e opcao 380 (ferramentas/dados_dica.py)
	_extra = ItensMU._json("res://dados/itens_extra.json")


# texto do cliente, com os argumentos no jeito do printf ("%d", "%s", "%%")
static func t(i: int, args := []) -> String:
	_carregar()
	var s: String = _txt.get(str(i), "?%d" % i)
	return s.replace("%u", "%d") % args if not args.is_empty() else s.replace("%%", "%")


static func _linha(texto: String, cor := BRANCO, negrito := false) -> Dictionary:
	return {"t": texto, "cor": cor, "negrito": negrito}


static func _vazia() -> Dictionary:
	return {"t": ""}


static func _milhar(v: int) -> String:
	var s := str(v)
	var r := ""
	while s.length() > 3:
		r = "," + s.right(3) + r
		s = s.left(s.length() - 3)
	return s + r


# a linha do Item.bmd do item (vazia se o cliente nao conhece)
static func dados_bmd(it: Dictionary) -> Dictionary:
	_carregar()
	return _bmd.get(ItensMU.chave(it), {})


static func asa(k: String) -> int:
	return 1 if k in ASA1 else (2 if k in ASA2 else (3 if k in ASA3 else 0))


# as linhas da caixa; topo = linhas que vem antes do nome (o preco na loja)
static func linhas(it: Dictionary, topo := []) -> Array:
	_carregar()
	var k := ItensMU.chave(it)
	# corvo e cavalo: a ficha do pet (C1 A9) no lugar da caixa normal, quando ja chegou
	if k == Pets.CORVO or k == Pets.CAVALO:
		var lp := Pets.linhas(it, topo)
		if not lp.is_empty():
			return lp
	Pets.onde = []
	var p: Dictionary = _bmd.get(k, {})
	var g: int = it.grupo
	var n: int = it.numero
	var lv: int = clampi(it.get("nivel", 0), 0, 15)
	var geracao := asa(k)
	var exc: int = it.get("exc", 0) if geracao == 0 else 0
	var anc: bool = (it.get("anc", 0) & 3) > 0 and g < 12
	var opcao: int = it.get("opcao", 0)
	var l := [_vazia()]
	if not topo.is_empty():
		l.append_array(topo)
		l.append(_vazia())

	# nome: a cor diz o tipo do item
	var tem_opcao: bool = it.get("skill", false) or it.get("sorte", false) or opcao > 0
	var cor := BRANCO
	if k in ["14,13", "14,14", "12,15", "14,16", "14,22", "14,31", "13,53", "13,52"]:
		cor = AMARELO
	elif geracao > 0:
		cor = AMARELO if lv >= 7 else (AZUL if tem_opcao else BRANCO)
	elif anc:
		cor = VERDE
	elif exc > 0:
		cor = VERDE
	elif lv >= 7:
		cor = AMARELO
	elif tem_opcao:
		cor = AZUL
	var n_set := _set_do_item(it)
	var prefixo: String = (_extra.sets[str(n_set)].nome + " ") if n_set > 0 else ""
	l.append(_linha((t(620) + " " if exc > 0 else "") + prefixo + ItensMU.nome(it), cor, true))

	# o que a joia faz
	var desc := {"14,13": 572, "14,14": 573, "14,16": 621, "12,15": 574}
	if desc.has(k):
		l.append(_linha(t(desc[k])))

	if p.is_empty():
		return _fim(l)

	var nivel_drop: int = maxi(p.nivel, 1)
	# dano
	var num := numeros(it)
	if p.dano_min > 0:
		l.append(_linha("%s: %d ~ %d" % [t(40 + p.duas_maos), num.dano_min, num.dano_max], AZUL if exc > 0 else BRANCO))
	# defesa
	if p.defesa > 0:
		l.append(_linha(t(65, [num.defesa]), AZUL if exc > 0 and g >= 7 and g <= 11 else BRANCO))
	if p.defesa_magica > 0:
		l.append(_linha(t(66, [p.defesa_magica])))
	if p.bloqueio > 0:
		var r: int = p.bloqueio + POR_NIVEL[lv]
		if exc > 0:
			r += p.bloqueio * 25 / nivel_drop + 5
		l.append(_linha(t(67, [r]), AZUL if exc > 0 else BRANCO))
	if p.velocidade > 0:
		l.append(_linha(t(64, [p.velocidade])))
	if p.andar > 0:
		l.append(_linha(t(68, [p.andar])))

	# asas, anjo, imp e montarias
	if geracao == 1:
		l.append_array([_linha(t(577, [12 + lv * 2])), _linha(t(578, [12 + lv * 2])), _linha(t(579))])
	elif k == "13,30" or k == "12,49":
		l.append_array([_linha(t(577, [20 + lv * 2])), _linha(t(578, [10 + lv * (2 if k == "12,49" else 1)]))])
	elif geracao == 2:
		l.append_array([_linha(t(577, [32 + lv])), _linha(t(578, [25 + lv * 2])), _linha(t(579))])
	elif geracao == 3:
		var absorve := 24 if k in ["12,40", "12,50"] else 39
		l.append_array([_linha(t(577, [39 + lv * 2])), _linha(t(578, [absorve + lv * 2])), _linha(t(579))])
	elif k == "13,0":
		l.append_array([_linha(t(578, [20])), _linha(t(739, [50]))])
	elif k == "13,1":
		l.append(_linha(t(576)))
	elif k == "13,3":
		l.append_array([_linha(t(577, [15])), _linha(t(578, [10]))])

	# durabilidade, quantidade ou vida do bicho
	var dur: int = it.get("durabilidade", 0)
	var municao := k in ["4,7", "4,15"]
	if (g == 14 and (n <= 8 or (n >= 35 and n <= 40))) or municao:
		l.append(_linha(t(69, [dur])))
	elif g == 13 and n <= 7:
		l.append(_linha(t(70, [dur])))
	elif (p.durabilidade > 0 or p.durabilidade_magica > 0) and (g < 12 or g == 13 or geracao > 0):
		l.append(_linha(t(71, [dur, dur_maxima(it, p, geracao, exc, anc)])))
	for i in 7:
		if p.resistencias[i] > 0:
			l.append(_linha(t(72, [t(48 + i), lv + 1])))

	# requisitos: vermelho e "(lacking N)" quando o personagem nao tem
	if p.nivel_req > 0:
		_requisito(l, t(76, [p.nivel_req]), p.nivel_req, eu.nivel)
	var base: int = p.nivel + (30 if anc else (25 if exc > 0 else 0))
	var dl: int = base + lv * 3
	var vestivel := g < 12 or g == 13 or geracao > 0
	var forca: int = _req(p.forca, dl, 3, vestivel)
	if forca > 0 and vestivel and opcao > 0:
		forca += opcao * 4   # OpenMU GetRequirement: a opcao adicional pede mais forca
	var energia: int = _req(p.energia, dl, 4, vestivel)
	if g == 5 and n >= 21 and n <= 23 and p.energia > 0:
		energia = 20 + p.energia * (base + lv) * 3 / 100   # livros do Summoner
	elif g == 15 and p.energia > 0:
		energia = 20 + p.energia * p.nivel_req * 4 / 100
	if forca > 0:
		_requisito(l, t(73, [forca]), forca, eu.forca)
	var agilidade := _req(p.agilidade, dl, 3, vestivel)
	if agilidade > 0:
		_requisito(l, t(75, [agilidade]), agilidade, eu.agilidade)
	var vitalidade := _req(p.vitalidade, dl, 3, vestivel)
	if vitalidade > 0:
		_requisito(l, t(1930, [vitalidade]), vitalidade, eu.vitalidade)
	if energia > 0:
		_requisito(l, t(77, [energia]), energia, eu.energia)
	var comando := _req(p.comando, dl, 3, vestivel)
	if comando > 0:
		_requisito(l, t(698, [comando]), comando, eu.comando)

	# quem pode usar (so quando nao sao todas as classes)
	var classes: Array = p.classes
	if classes.count(1) < 7 and g != 14:
		l.append(_vazia())
		var minha: int = eu.classe >> 2
		var passo := 3 if eu.classe & 1 else (2 if eu.classe & 2 else 1)
		for i in 7:
			var c: int = classes[i]
			if c == 0:
				continue
			var ok: bool = i == minha and c <= passo
			var linha := _linha(t(61, [t(NOMES_CLASSE[i][clampi(c, 1, 3) - 1])]))
			if not ok:
				linha["fundo"] = FUNDO_VERMELHO
			l.append(linha)

	# botas e luvas +5, cajado e cetro
	if g == 11 and lv >= 5:
		l.append_array([_vazia(), _linha(t(78), AZUL, true)])
	if g == 10 and lv >= 5:
		l.append_array([_vazia(), _linha(t(93), AZUL, true)])
	if p.magia > 0 and g != 13:
		var qual := 1234 if g == 2 else (1691 if g == 5 and n >= 21 and n <= 29 else 79)
		l.append_array([_vazia(), _linha(t(qual, [magia(it)]), AZUL, true)])

	# opcao 380 e harmony vem antes das opcoes (ZzzInventory.cpp RenderItemInfo)
	l.append_array(_opcao_380(it, k))
	l.append_array(_harmonia(it, lv))

	# opcoes em azul: bonus do ancient, skill, sorte, opcao adicional, excelentes
	var op := _bonus_ancient(it, k, p)
	op.append_array(_opcoes(it, k, p, geracao, exc, lv, opcao))
	if not op.is_empty():
		l.append(_vazia())
		l.append_array(op)

	# no fim: as opcoes do set ancient e os sockets
	l.append_array(_opcoes_set(it, n_set))
	l.append_array(_sockets(it))
	return _fim(l)


# os 12 bytes do item quando vieram do servidor (cliente.gd item_de); sem eles, o valor de "nada"
static func _byte(it: Dictionary, i: int, nada: int) -> int:
	var b = it.get("bytes", null)
	return int(b[i]) if b != null and b.size() > i else nada


# numero do set ancient do item (0 = nao e ancient), CSItemOption::GetSetItemName
static func _set_do_item(it: Dictionary) -> int:
	var d: int = it.get("anc", 0) & 3
	if d == 0 or d == 3:
		return 0
	var sets: Array = _extra.set_do_item.get(ItensMU.chave(it), [])
	if sets.is_empty():
		return 0
	var n := int(sets[d - 1])
	return n if n != 0 and n != 255 and _extra.sets.has(str(n)) else 0


# +5/+10 de forca, agilidade, energia ou vitalidade do ancient (CSItemOption::GetDefaultOptionText)
static func _bonus_ancient(it: Dictionary, k: String, p: Dictionary) -> Array:
	var bonus: int = (it.get("anc", 0) >> 2) & 3
	var texto := {1: 985, 2: 986, 3: 988, 4: 987}
	if bonus == 0 or _set_do_item(it) == 0 or not texto.has(p.tipo_ataque):
		return []
	var l := [_linha(t(texto[p.tipo_ataque], [bonus * 5]), AZUL)]
	if k in ["13,8", "13,9", "13,12", "13,13"] or (it.grupo == 13 and it.numero >= 21 and it.numero <= 28):
		l.append(_linha(t(1165), AZUL))
	return l


static func _opcao_380(it: Dictionary, k: String) -> Array:
	if not (_byte(it, 5, 0) & 0x08) or not _extra.op380.has(k):
		return []
	var o: Array = _extra.op380[k]
	var l := [_vazia()]
	for i in 2:
		var tipo := int(o[i * 2])
		if tipo >= 1 and tipo <= 8:
			var txt := 2183 + tipo
			l.append(_linha(t(txt) if tipo == 7 else t(txt, [int(o[i * 2 + 1])]), ROSA, true))
	l.append(_vazia())
	return l


# Jewel of Harmony: byte 6 = opcao << 4 | nivel (so em item sem socket)
static func _harmonia(it: Dictionary, lv: int) -> Array:
	var b := _byte(it, 6, 0)
	var opcao := b >> 4
	var nivel := b & 0x0F
	var g: int = it.grupo
	if opcao == 0 or _tem_socket(it) or g > 11 or nivel > 13:
		return []
	var tipo := 0 if g <= 4 else (1 if g == 5 else 2)
	if opcao > (10 if tipo == 0 else 8):
		return []
	var h: Dictionary = _extra.harmonia[tipo][opcao - 1]
	var v := int(h.nivel[nivel])
	var txt := "%s +%d%s" % [h.nome, v, "%" if tipo == 2 and opcao == 7 else ""]
	return [_vazia(), _linha(txt, AMARELO if lv >= nivel else CINZA, true), _vazia()]


static func _tem_socket(it: Dictionary) -> bool:
	return it.has("bytes") and _byte(it, 7, 0xFF) != 0xFF


# texto de uma opcao do set (CSItemOption::getExplainText): o numero e a posicao em AT_SET_OPTION_*
static func _texto_set(op: int, v: int) -> String:
	if op <= 6:
		return t(950 + op, [v])
	if op == 7:
		return t(632, [v])
	if op <= 20:
		return t(949 + op, [v])
	if op <= 23:
		return t([970, 984, 983][op - 21], [v])
	if op <= 35:
		return t(971 + op - 24).trim_prefix("%s ") % [v]
	return ""


# CSItemOption::RenderSetOptionListInItem: todas as opcoes do set; acesas (azul, verde ou amarelo) so com o item
# vestido e pecas bastantes do mesmo set vestidas; o resto em cinza
static func _opcoes_set(it: Dictionary, n_set: int) -> Array:
	if n_set == 0:
		return []
	var s: Dictionary = _extra.sets[str(n_set)]
	var vestido := false
	var pecas := 0
	for e in equipados:
		if is_same(e, it):
			vestido = true
		if _set_do_item(e) == n_set:
			pecas += 1
	var completo: bool = pecas >= int(s.itens)
	var l := [_vazia(), _linha(t(1089) + " " + t(159), AMARELO), _vazia()]
	var lista := []   # [opcao, valor, acesa, cor]
	for o in mini(int(s.itens) - 1, 6):
		lista.append([s.padrao[o][0], s.padrao[o][1], completo or o < pecas - 1, AZUL])
	for o in 2:
		lista.append([s.ext[o][0], s.ext[o][1], completo or pecas >= 2, VERDE])
	for o in 5:
		lista.append([s.full[o][0], s.full[o][1], completo, AMARELO])
	for x in lista:
		var op := int(x[0])
		var v := int(x[1])
		if op == 255 or v == 0:
			continue
		var txt := _texto_set(op, v)
		if txt != "":
			l.append(_linha(txt, x[3] if vestido and x[2] else CINZA))
	return l


# CSocketItemMgr::AttachToolTipForSocketItem: bytes 7 a 11 (0xFF sem socket, 0xFE vazio,
# senao semente = b % 50 e nivel da esfera = b / 50 + 1); byte 6 = bonus do conjunto
static func _sockets(it: Dictionary) -> Array:
	if not _tem_socket(it):
		return []
	var l := [_vazia(), _linha(t(2650) + " " + t(159), ROXO), _vazia()]
	for i in 5:
		var b := _byte(it, 7 + i, 0xFF)
		if b == 0xFF:
			break
		if b == 0xFE:
			l.append(_linha(t(2655, [i + 1, t(2652)]), CINZA))
			continue
		var o: Dictionary = _extra.socket[0][b % 50]
		var txt := "%s(%s %s)" % [t(2640 + int(o.cat) - 1), o.nome, _valor_socket(int(o.tipo), int(o.valores[mini(b / 50, 4)]))]
		l.append(_linha(t(2655, [i + 1, txt]), AZUL))
	var bonus := _byte(it, 6, 0xFF)
	if bonus < 50:
		var o: Dictionary = _extra.socket[1][bonus]
		if int(o.valores[0]) > 0:
			l.append_array([_vazia(), _linha(t(2656), ROXO), _vazia(),
				_linha("%s %s" % [o.nome, _valor_socket(int(o.tipo), int(o.valores[0]))], AZUL)])
	return l


# CSocketItemMgr::CalcSocketOptionValue: 1 e 2 = o valor (2 em %), 3 = nivel / valor, 4 e 5 = vida e mana maxima / valor
static func _valor_socket(tipo: int, v: int) -> String:
	var n := v
	if v > 0:
		match tipo:
			3: n = int(eu.get("nivel", 1)) / v
			4: n = int(eu.get("vida_max", 0)) / v
			5: n = int(eu.get("mana_max", 0)) / v
	return ("+%d%%" if tipo == 2 else "+%d") % n



# dano e defesa do item com o bonus do nivel, do excelente e do ancient (os mesmos numeros da caixa)
static func numeros(it: Dictionary) -> Dictionary:
	_carregar()
	var k := ItensMU.chave(it)
	var p: Dictionary = _bmd.get(k, {})
	var r := {"dano_min": 0, "dano_max": 0, "defesa": 0}
	if p.is_empty():
		return r
	var g: int = it.grupo
	var lv: int = clampi(it.get("nivel", 0), 0, 15)
	var geracao := asa(k)
	var exc: int = it.get("exc", 0) if geracao == 0 else 0
	var anc: bool = (it.get("anc", 0) & 3) > 0 and g < 12
	var nivel_drop: int = maxi(p.nivel, 1)
	if p.dano_min > 0:
		var soma: int = POR_NIVEL[lv]
		if exc > 0:
			soma += p.dano_min * 25 / nivel_drop + 5
		if anc:
			soma += 5 + (p.nivel + 30) / 40
		r.dano_max = p.dano_max + soma
		r.dano_min = mini(p.dano_min + soma, r.dano_max)
	if p.defesa > 0:
		var d: int = p.defesa
		if g == 6:
			d += lv
		else:
			d += (POR_NIVEL_ASA3 if geracao == 3 else POR_NIVEL)[lv]
		if exc > 0 and g >= 7 and g <= 11:
			d += p.defesa * 12 / nivel_drop + nivel_drop / 5 + 4
		if anc and g >= 7 and g <= 11:
			d += 2 + d * 3 / (p.nivel + 30) + (p.nivel + 30) / 30
		r.defesa = d
	return r

# MagicPower do item: % de magia do cajado (ou do ataque do pet, no cetro); 0 se nao tem
static func magia(it: Dictionary) -> int:
	_carregar()
	var k := ItensMU.chave(it)
	var p: Dictionary = _bmd.get(k, {})
	if p.is_empty() or p.magia <= 0 or it.grupo == 13:
		return 0
	var lv: int = clampi(it.get("nivel", 0), 0, 15)
	var exc: int = it.get("exc", 0) if asa(k) == 0 else 0
	var m: int = p.magia + POR_NIVEL[lv]
	if exc > 0:
		m += p.magia * 25 / maxi(p.nivel, 1) + 5
	if (it.get("anc", 0) & 3) > 0 and it.grupo < 12:
		m += 2 + (p.nivel + 30) / 60
	m /= 2
	if it.grupo != 2:
		m += lv * 2
	return m


static func _fim(l: Array) -> Array:
	while not l.is_empty() and l[-1].t == "":
		l.pop_back()
	return l


static func _req(valor: int, dl: int, mult: int, vestivel: bool) -> int:
	if valor <= 0:
		return 0
	return 20 + valor * dl * mult / 100 if vestivel else valor


static func _requisito(l: Array, texto: String, pede: int, tem: int) -> void:
	if tem < pede:
		l.append(_linha(texto, VERMELHO))
		l.append(_linha(t(74, [pede - tem]), VERMELHO))
	else:
		l.append(_linha(texto))


# CalcMaxDurability do cliente
static func dur_maxima(it: Dictionary, p: Dictionary, geracao: int, exc: int, anc: bool) -> int:
	var m: int = p.durabilidade_magica if it.grupo == 5 else p.durabilidade
	for i in clampi(it.get("nivel", 0), 0, 15):
		m = mini(m + (8 if i >= 14 else (7 if i >= 13 else (6 if i >= 12 else (5 if i >= 11 else (4 if i >= 10 else (3 if i >= 9 else (2 if i >= 4 else 1))))))), 255)
	if anc:
		m += 20
	elif exc > 0 and geracao == 0:
		m += 15
	return m


static func _opcoes(it: Dictionary, k: String, p: Dictionary, geracao: int, exc: int, lv: int, opcao: int) -> Array:
	var g: int = it.grupo
	var n: int = it.numero
	var l := []
	if it.get("skill", false) and p.skill > 0:
		var s: Array = _skills.get(str(p.skill), ["Skill %d" % p.skill, 0, 0, 0, 0])
		var mana: int = int(s[4])
		l.append(_linha(t(TEXTO_SKILL[p.skill], [mana]) if TEXTO_SKILL.has(p.skill) else "%s skill (Mana:%d)" % [s[0], mana], AZUL))
	if it.get("sorte", false):
		l.append_array([_linha(t(87), AZUL), _linha(t(94), AZUL)])
	if opcao > 0:
		var qual := ""
		if geracao > 0:
			qual = OPCAO_ASA.get(k, {}).get((it.get("exc", 0) >> 4) & 3, OPCAO_ASA.get(k, {}).get(0, ""))
		elif g <= 4 and k not in ["4,7", "4,15"]:
			qual = "dano"
		elif g == 5:
			qual = "maldicao" if n >= 21 and n <= 23 else "magia"
		elif g == 6:
			qual = "bloqueio"
		elif g >= 7 and g <= 11:
			qual = "defesa"
		elif g == 13 and n >= 8:
			qual = "vida"
		match qual:
			"dano": l.append(_linha(t(88, [opcao * 4]), AZUL))
			"magia": l.append(_linha(t(89, [opcao * 4]), AZUL))
			"maldicao": l.append(_linha(t(1697, [opcao * 4]), AZUL))
			"bloqueio": l.append(_linha(t(90, [opcao * 5]), AZUL))
			"defesa": l.append(_linha(t(91, [opcao * 4]), AZUL))
			"vida": l.append(_linha(t(92, [opcao]), AZUL))
	if geracao == 2:
		var b: int = it.get("exc", 0)
		if b & 1: l.append(_linha(t(740, [50 + lv * 5]), AZUL))
		if b & 2: l.append(_linha(t(741, [50 + lv * 5]), AZUL))
		if b & 4: l.append(_linha(t(742, [3]), AZUL))
		if b & 8: l.append(_linha(t(954, [10 + lv * 5]), AZUL))
	elif geracao == 3:
		var b: int = it.get("exc", 0)
		if b & 1: l.append(_linha(t(742, [5]), AZUL))
		if b & 2: l.append(_linha(t(1673, [5]), AZUL))
		if b & 4: l.append(_linha(t(1674, [5]), AZUL))
		if b & 8: l.append(_linha(t(1675, [5]), AZUL))
	elif exc > 0:
		var ataque := g <= 5 or k in JOIAS_ATAQUE
		var magia := g == 5
		var textos := [635, 634, 633, 632 if magia else 630, 631 if magia else 629, 628] if ataque else [622, 623, 624, 625, 626, 627]
		var args := [[], [], [7], [2], [], []] if ataque else [[], [], [], [], [], []]
		for i in range(5, -1, -1):
			if exc & (1 << i):
				l.append(_linha(t(textos[i], args[i]), AZUL))
	return l


# Cada janela ganha uma camada filha por cima de tudo (z_index), pra caixa nao ficar embaixo da janela vizinha.
class Camada extends Control:
	var l := []
	var item := Rect2()
	var fonte: Font

	func _draw() -> void:
		if l.is_empty() or fonte == null:
			return
		var inv := get_global_transform().affine_inverse()
		var tela := Rect2(inv * Vector2.ZERO, inv.basis_xform(get_viewport_rect().size))
		DicaItem.desenhar(self, fonte, l, item, tela)


static func _camada(janela: Control) -> Camada:
	var c := janela.get_node_or_null("Dica") as Camada
	if c == null:
		c = Camada.new()
		c.name = "Dica"
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.z_index = 100
		c.z_as_relative = false
		janela.add_child(c)
	return c


# a janela chama no _draw: mostra a caixa do item (rect do item no espaco da janela)
static func mostrar(janela: Control, f: Font, l: Array, item: Rect2) -> void:
	var c := _camada(janela)
	if c.l != l or c.item != item:
		c.l = l
		c.item = item
		c.fonte = f
		c.queue_redraw()


static func esconder(janela: Control) -> void:
	var c := janela.get_node_or_null("Dica") as Camada
	if c and not c.l.is_empty():
		c.l = []
		c.queue_redraw()


# desenha a caixa centrada embaixo do item (em cima, se nao couber); tela = area visivel no espaco de ci
static func desenhar(ci: CanvasItem, f: Font, l: Array, item: Rect2, tela: Rect2, tam := 9) -> void:
	var alt_linha := tam * 1.25
	var larg := 0.0
	var alt := 0.0
	for x in l:
		if x.t == "":
			alt += alt_linha * 0.5
		else:
			larg = maxf(larg, f.get_string_size(x.t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + (1.0 if x.get("negrito", false) else 0.0))
			alt += alt_linha
	larg += 10
	alt += 4
	var pos := Vector2(item.get_center().x - larg / 2, item.end.y + 2)
	if pos.y + alt > tela.end.y - 2:
		pos.y = item.position.y - alt - 2
	pos.x = clampf(pos.x, tela.position.x + 2, tela.end.x - larg - 2)
	pos.y = clampf(pos.y, tela.position.y + 2, maxf(tela.position.y + 2, tela.end.y - alt - 2))
	var caixa := Rect2(pos, Vector2(larg, alt))
	ci.draw_rect(caixa, Color(0, 0, 0, 0.8))
	ci.draw_rect(caixa.grow(0.5), Color(1, 1, 1, 0.55), false, 1.0)
	var y := pos.y + 2
	for x in l:
		if x.t == "":
			y += alt_linha * 0.5
			continue
		if x.has("fundo"):
			var w := f.get_string_size(x.t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
			ci.draw_rect(Rect2(pos.x + (larg - w) / 2 - 1, y + 1, w + 2, alt_linha - 1), x.fundo)
		var base := Vector2(pos.x, y + tam + 1)
		ci.draw_string(f, base, x.t, HORIZONTAL_ALIGNMENT_CENTER, larg, tam, x.cor)
		if x.get("negrito", false):
			ci.draw_string(f, base + Vector2(0.6, 0), x.t, HORIZONTAL_ALIGNMENT_CENTER, larg, tam, x.cor)
		y += alt_linha
