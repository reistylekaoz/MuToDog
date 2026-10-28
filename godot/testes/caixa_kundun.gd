extends SceneTree
# Box of Kundun +1..+5 (14,11 nivel 8 a 12): modelo do bau dourado (MagicBox08, chaves "14,11+8".."+12" nos dois
# modelos.json e no atlas de icones) e o "(Tier N)" do excelente que saiu dela (o servidor manda 0xE0 | tier no
# byte 11 de item sem socket). Uso: $G --headless --path . --script res://testes/caixa_kundun.gd

var falhas := 0


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _bytes(exc: int, b7: int, b11: int) -> PackedByteArray:
	# Kris (0,0) +3 com exc e os bytes de socket pedidos
	return PackedByteArray([0, 3 << 3, 20, exc, 0, 0, 0, b7, 0xFF, 0xFF, 0xFF, b11])


func _initialize() -> void:
	var it := ClienteMU.item_de(_bytes(0x21, 0xFF, 0xE3), 0)
	confere("tier 3 lido do byte 11", it.tier == 3)
	confere("nome com (Tier 3) na frente", ItensMU.tier(it) == "(Tier 3) ")
	confere("item comum sem tier", ClienteMU.item_de(_bytes(0x21, 0xFF, 0xFF), 0).tier == 0)
	confere("item de socket nao vira tier", ClienteMU.item_de(_bytes(0x21, 0xFE, 0xE3), 0).tier == 0)
	var sem_exc := ClienteMU.item_de(_bytes(0, 0xFF, 0xE2), 0)
	confere("sem excelente nao escreve tier", ItensMU.tier(sem_exc) == "")
	var icones: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/icones.json"))
	var chao: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/modelos/modelos.json"))
	var inv: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dados/itens/modelos.json"))
	for n in range(8, 13):
		var k := "14,11+%d" % n
		confere(k + " no atlas, no chao e no inventario", icones.has(k) and chao.has(k) and inv.has(k))
	confere("chave_nivel da caixa +1", ItensMU.chave_nivel({"grupo": 14, "numero": 11, "nivel": 8}) == "14,11+8")
	confere("brilho da caixa +3 (nivel 10) = 5", BrilhoMU.nivel_visivel("14,11", 10) == 5)
	confere("nome da caixa no chao", ItensMU.nome({"grupo": 14, "numero": 11, "nivel": 10}).ends_with(" +3")
		and not ItensMU.nome({"grupo": 14, "numero": 11, "nivel": 10}).begins_with("Box of Luck"))
	print("falhas: %d" % falhas)
	quit(falhas)
