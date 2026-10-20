extends SceneTree
# Confere a caixa de informacao do item (DicaItem) sem tela: linhas e numeros contra as contas do cliente S6.
# Uso: $G --headless --script res://testes/dica.gd   (termina com "falhas: 0")

var falhas := 0


func item(g: int, n: int, extra := {}) -> Dictionary:
	var it := {"grupo": g, "numero": n, "nivel": 0, "sorte": false, "skill": false, "exc": 0, "opcao": 0,
		"anc": 0, "durabilidade": 0}
	it.merge(extra, true)
	return it


func confere(nome: String, it: Dictionary, esperado: Array) -> void:
	var l := DicaItem.linhas(it)
	var textos := []
	for x in l:
		textos.append(x.t)
	print("--- %s" % nome)
	for x in l:
		print("  %s%s" % [x.t, "  [fundo vermelho]" if x.has("fundo") else ""])
	for e in esperado:
		if e not in textos:
			falhas += 1
			print("  FALHA: faltou \"%s\"" % e)


func _init() -> void:
	DicaItem.eu = {"nivel": 50, "classe": 4, "forca": 100, "agilidade": 30, "vitalidade": 25, "energia": 20,
		"comando": 0}   # Dark Knight nivel 50
	confere("Kris +0", item(0, 0, {"durabilidade": 20}), ["Kris", "One-Handed Damage: 6 ~ 11", "Attack speed: 50",
		"Durability: [20/20]", "Strength Requirement: 27", "Agility Requirement: 27"])
	# +9 com skill, sorte e opcao +12, excelente: dano + 2% e velocidade
	var sd := item(0, 16, {"nivel": 9, "skill": true, "sorte": true, "opcao": 3, "exc": 0x0C, "durabilidade": 120})
	# dano: 82 + 27 (+9) + 82*25/82+5 = 30 -> 139 ~ 147; forca: 20 + 160*(82+25+27)*3/100 = 663 (+12 da opcao)
	confere("Excellent Sword of Destruction +9", sd, ["Excellent Sword of Destruction +9",
		"One-Handed Damage: 139 ~ 147", "Strength Requirement: 675", "(lacking 575)", "Cyclone Cutting skill (Mana:9)",
		"Luck (success rate of Jewel of Soul +25%)", "Luck (critical damage rate +5%)", "Additional Dmg +12",
		"Increase Damage +2%", "Increase Attacking(Wizardry)speed +7"])
	confere("Skull Staff +3 (Dark Knight nao usa)", item(5, 0, {"nivel": 3, "durabilidade": 23}),
		["Can be equipped by Dark Wizard", "Wizardry Dmg 13% rise"])
	confere("Cape of Emperor +0", item(12, 40, {"durabilidade": 220}), ["Defense: 45", "Increase 39% of Damage",
		"Absorb 24% of Damage", "Durability: [220/220]", "Minimum Level Requirement: 400", "(lacking 350)",
		"Can be equipped by Lord Emperor"])
	confere("Wings of Dragon +11 HP e opcao de dano", item(12, 5, {"nivel": 11, "exc": 0x21, "opcao": 2, "durabilidade": 200}),
		["Increase 43% of Damage", "Absorb 47% of Damage", "Additional Dmg +8", "HP +105 increased"])
	confere("Dragon Armor +0 excelente", item(8, 1, {"exc": 0x21, "durabilidade": 83}), [
		"Increases acquisition rate of Zen after hunting monsters +30%", "Increase Max HP +4%"])
	confere("Ring of Ice", item(13, 8, {"durabilidade": 50}), ["Ice Resistance: 1", "Durability: [50/50]"])
	confere("Jewel of Bless", item(14, 13, {"durabilidade": 1}), ["Jewel of Bless",
		"It is used to increase your item level up to 6"])
	confere("Large Healing Potion x3", item(14, 3, {"durabilidade": 3}), ["Number of items: 3"])

	# set ancient: Dragon Helm do set 11 (discriminador 1) com bonus +5; vestido com mais uma peca do set
	var elmo := item(7, 1, {"anc": 0x05, "durabilidade": 68})
	var nome_set: String = DicaItem._extra.sets["11"].nome
	DicaItem.equipados = [elmo, item(10, 1, {"anc": 0x01})]
	confere("Ancient %s Dragon Helm" % nome_set, elmo, ["%s Dragon Helm" % nome_set, "Increase stamina +5",
		"Set Item option info"])
	var linhas := DicaItem.linhas(elmo)
	var acesas := linhas.filter(func(x): return x.has("cor") and x.cor == DicaItem.AZUL and x.t.begins_with("Increase"))
	if acesas.size() < 2:   # o bonus +5 e a 1a opcao do set (2 pecas)
		falhas += 1
		print("  FALHA: com 2 pecas vestidas a 1a opcao do set devia acender (%d azuis)" % acesas.size())
	DicaItem.equipados = []
	# harmony: opcao 2 (Max. attack increase) nivel 5 na espada +9; opcao 380; sockets
	var b := PackedByteArray([0, 0, 0, 0, 0, 0, 0x25, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
	confere("Harmony", item(0, 16, {"nivel": 9, "durabilidade": 120, "bytes": b}), ["Max. attack increase +8"])
	b = PackedByteArray([0, 0, 0, 0, 0, 0x08, 0, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF])
	confere("Opcao 380", item(0, 22, {"durabilidade": 120, "bytes": b}), ["Additional Damage +200",
		"Attack sucess rate increase +10"])
	b = PackedByteArray([0, 0, 0, 0, 0, 0, 0xFF, 102, 0xFE, 1, 0xFF, 0xFF])
	confere("Sockets", item(0, 26, {"durabilidade": 120, "bytes": b}), ["Socket Item option info",
		"Socket 1: Fire(Maximum attack/Wizardry increase +35)", "Socket 2: No item application",
		"Socket 3: Fire(Attack speed increase +7)"])
	# preco de venda: um terco da compra; gasta, perde ate 60%
	var kris := item(0, 0, {"durabilidade": 20})
	var compra := ItensMU.preco(kris)
	var cheia := ItensMU.preco_venda(kris)
	kris.durabilidade = 10
	var gasta := ItensMU.preco_venda(kris)
	print("--- Kris: compra %d, venda %d, venda gasta pela metade %d" % [compra, cheia, gasta])
	if absi(cheia - compra / 3) > compra / 100 + 10 or gasta >= cheia:
		falhas += 1
		print("  FALHA: preco de venda")
	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
