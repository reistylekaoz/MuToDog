extends SceneTree
# Confere a rodada 6 sem servidor: pacotes novos (F3 14, grupo, heroi, transformado, senha do bau, Rage Fighter,
# vida da invocacao), a lista do grupo e o teclado da senha do bau.
# Uso: $G --headless --path . --script res://testes/rodada6.gd   (termina com "falhas: 0")

var falhas := 0
var ultimo := {}


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func guarda(sinal: String) -> Callable:
	return func(...a): ultimo[sinal] = a


func _initialize() -> void:
	var cli := ClienteMU.new()
	cli.meu_id = 5
	for s in ["item_melhorado", "grupo", "grupo_saiu", "grupo_vida", "heroi", "bau_trava", "rage_alvos",
			"vida_invocacao", "objeto_entrou", "skill_animacao"]:
		cli.connect(s, guarda(s))
	# F3 14: slot 12, Kris +2 (nivel nos bits 3..6 do byte 1)
	cli._tratar(PackedByteArray([0xC1, 17, 0xF3, 0x14, 12, 0, 2 << 3, 20, 0, 0, 0, 0, 255, 255, 255, 255, 255]))
	confere("F3 14: slot 12, item +2", ultimo.has("item_melhorado") and ultimo.item_melhorado[0] == 12 and ultimo.item_melhorado[1].nivel == 2)
	# C1 42: dois membros com indice e vida (u32 LE)
	var p := PackedByteArray([0xC1, 0, 0x42, 1, 2])
	for m in [["Lider", 0, 132, 132], ["Outro", 1, 35, 125]]:
		var b := PackedByteArray()
		b.resize(24)
		var n: PackedByteArray = m[0].to_ascii_buffer()
		for i in n.size():
			b[i] = n[i]
		b[10] = m[1]
		b.encode_u32(16, m[2])
		b.encode_u32(20, m[3])
		p.append_array(b)
	p[1] = p.size()
	cli._tratar(p)
	var l: Array = ultimo.get("grupo", [[]])[0]
	confere("C1 42: 2 membros, Outro indice 1 com 35/125", l.size() == 2 and l[1].indice == 1 and l[1].vida == 35 and l[1].vida_max == 125)
	cli._tratar(PackedByteArray([0xC1, 6, 0x44, 2, 0x0A, 0x13]))
	confere("C1 44: [[0, 10], [1, 3]]", ultimo.get("grupo_vida", [[]])[0] == [[0, 10], [1, 3]])
	cli._tratar(PackedByteArray([0xC1, 4, 0x43, 1]))
	confere("C1 43: saiu do grupo", ultimo.has("grupo_saiu"))
	cli._tratar(PackedByteArray([0xC1, 7, 0xF3, 0x08, 0x04, 0x8E, 6]))
	confere("F3 08: id 1166 estado 6", ultimo.get("heroi", []) == [1166, 6])
	cli._tratar(PackedByteArray([0xC1, 4, 0x83, 1]))
	confere("C1 83: trancado", ultimo.get("bau_trava", []) == [1])
	cli._tratar(PackedByteArray([0xC1, 16, 0x4B, 0, 7, 1, 0xDD, 2, 0xDF, 2, 0x10, 0x27, 0x10, 0x27, 0x10, 0x27]))
	confere("C1 4B: Dark Side em 733 e 735", ultimo.get("rage_alvos", []) == [263, [733, 735]])
	cli._tratar(PackedByteArray([0xC3, 9, 0x4A, 1, 6, 2, 0, 0x82, 0xE0]))
	confere("C3 4A: animacao 262 de 512 em 736", ultimo.get("skill_animacao", []) == [262, 512, 736])
	cli._tratar(PackedByteArray([0xC1, 5, 0xF3, 0x20, 70]))
	confere("F3 20: 70%", ultimo.get("vida_invocacao", []) == [70])
	# C2 45: id 7 transformado no monstro 14, heroi 1
	var t := PackedByteArray([0xC2, 0, 0, 0x45, 1, 0, 7, 100, 101, 0, 14])
	t.append_array("Tran".to_ascii_buffer())
	t.resize(t.size() + 6)
	t.append_array(PackedByteArray([100, 101, 0x11]))
	var ap := PackedByteArray()
	ap.resize(18)
	ap.fill(0xFF)
	ap[0] = 0
	t.append_array(ap)
	t.append(0)
	t[2] = t.size()
	cli._tratar(t)
	var o: Dictionary = ultimo.get("objeto_entrou", [{}])[0]
	confere("C2 45: id 7, monstro 14, Tran, heroi 1", o.get("id") == 7 and o.get("skin") == 14 and o.get("nome") == "Tran" and o.get("heroi") == 1)

	var g := JanelaGrupo.new()
	root.add_child(g)
	g.meu_nome = "Outro"
	g.definir(l)
	confere("grupo: passo do Outro 3 (35/125)", g.passo_de("Outro") == 3)
	g.vidas([[1, 7]])
	confere("grupo: C1 44 muda o passo pra 7", g.passo_de("Outro") == 7)
	confere("grupo: nao sou lider, X so em mim", not g.sou_lider() and not g.tem_x(0) and g.tem_x(1))
	var tirou := [-1]
	g.tirar.connect(func(i): tirou[0] = i)
	g.clicar(g._x(1).get_center())
	confere("grupo: X manda o meu indice", tirou[0] == 1)
	g.meu_nome = "Lider"
	confere("grupo: lider tem X em todos", g.tem_x(0) and g.tem_x(1))

	var c := CaixaSenha.new()
	root.add_child(c)
	var pedido := []
	c.pronto.connect(func(s, pin, senha): pedido.assign([s, pin, senha]))
	c.abrir(1)
	for d in "1111":
		c.digito(int(d))
	c._ok()
	confere("senha: 4 iguais recusados (442)", c.passo == 0 and c.aviso == DicaItem.t(442))
	for d in "1357":
		c.digito(int(d))
	c._ok()
	for d in "1358":
		c.digito(int(d))
	c._ok()
	confere("senha: repetida diferente volta pro comeco (440)", c.passo == 0 and c.aviso == DicaItem.t(440))
	for vez in 2:
		for d in "1357":
			c.digito(int(d))
		c._ok()
	confere("senha: pede a senha da conta", c.passo == 2 and c.titulo() == DicaItem.t(690))
	c._conta.text = "x"
	c._ok()
	confere("senha: pedido 01 com 1357", pedido == [1, 1357, "x"] and not c.visible)
	c.abrir(0)
	for d in "24680":
		c.digito(int(d))
	confere("senha: so 4 digitos", c.digitos == "2468")
	c._ok()
	confere("senha: pedido 00 com 2468", pedido == [0, 2468, ""])
	confere("senha: teclado embaralhado tem os 10 digitos", c.ordem.size() == 10 and range(10).all(func(x): return x in c.ordem))
	print("falhas: %d" % falhas)
	quit(falhas)
