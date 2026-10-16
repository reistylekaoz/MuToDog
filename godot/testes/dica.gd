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
	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
