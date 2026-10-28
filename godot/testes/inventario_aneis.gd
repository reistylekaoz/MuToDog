extends SceneTree
# Arrastar equipamento pro slot (CNewUIMyInventory): o segundo anel entra no slot livre com um anel ja vestido,
# a area de cada slot e (x + 1, y, largura - 4, altura - 4) do slot 0 ao 11 e os aneis ficam como no original
# (10 o direito em x 54, 11 o esquerdo em x 114). Uso: $G --headless --path . --script res://testes/inventario_aneis.gd

var falhas := 0


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _initialize() -> void:
	confere("slots do Ring of Ice em int: 11 esta neles", 11 in ItensMU.slots({"grupo": 13, "numero": 8}))
	var inv := Inventario.new()
	confere("anel 10 em x 54, anel 11 em x 114", inv._equip_em(Vector2(68, 160)) == 10 and inv._equip_em(Vector2(128, 160)) == 11)
	confere("a ponta esquerda dos aneis e deles (58 e 118), nao das luvas e da calca", inv._equip_em(Vector2(58, 160)) == 10 and inv._equip_em(Vector2(118, 160)) == 11)
	confere("luvas e calca seguem nos seus lugares", inv._equip_em(Vector2(30, 180)) == 5 and inv._equip_em(Vector2(95, 180)) == 4)
	var movidos := []
	var avisos := []
	inv.mover.connect(func(de, para): movidos.append([de, para]))
	inv.aviso.connect(func(t): avisos.append(t))
	inv.itens = {10: {"grupo": 13, "numero": 9, "nivel": 0}, 4: {"grupo": 9, "numero": 33, "nivel": 0},
		5: {"grupo": 10, "numero": 33, "nivel": 0}, 20: {"grupo": 13, "numero": 8, "nivel": 0}}
	inv.na_mao = 20
	inv._clique(Vector2(128, 160))
	confere("com o anel no 10, o Ring of Ice arrastado vai pro 11", movidos == [[20, 11]] and avisos.is_empty())
	inv.esperando = -1
	inv.na_mao = 20
	inv._clique(Vector2(68, 160))
	confere("no 10 ocupado avisa que ja tem anel", movidos.size() == 1 and avisos.size() == 1 and "anel" in avisos[0])
	inv.na_mao = 20
	avisos.clear()
	inv._clique(Vector2(30, 180))
	confere("nas luvas ocupadas avisa (e nao manda)", movidos.size() == 1 and avisos.size() == 1)
	inv.free()
	print("falhas: %d" % falhas)
	quit(falhas)
