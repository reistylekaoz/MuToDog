extends SceneTree
# Confere a rodada 5 sem servidor: janela de buffs (ordem, icone, dica, tempo) e a caixa da fruta.
# Uso: $G --headless --path . --script res://testes/buffs.gd   (termina com "falhas: 0")

var falhas := 0


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _initialize() -> void:
	JanelaBuffs.carregar()
	confere("buffs.json: 158 buffs", JanelaBuffs.dados.size() == 158)
	confere("nome do 4: Soul Barrier", JanelaBuffs.nome(4) == "Soul Barrier")
	confere("55 e debuff, 1 nao", JanelaBuffs.debuff(55) and not JanelaBuffs.debuff(1))
	var j := JanelaBuffs.new()
	root.add_child(j)
	for b in [55, 1, 28, 61, 84, 4, 201]:
		j.por(b)
	j.por(35, 3725)
	confere("ordem: buffs do maior pro menor, depois debuffs (84 e 28 escondidos, 201 nao existe)", j.lista() == [35, 4, 1, 55, 61])
	confere("tempo 3725 s", JanelaBuffs.tempo(3725) == "1 Hour 2 Minute")
	confere("tempo 30 s", JanelaBuffs.tempo(30) == "Less than 1 minutes")
	var d: Array = j.linhas_dica(35).map(func(x): return x.t)
	print("  dica 35: %s" % [d])
	confere("dica do 35: nome, descricao e tempo", d.size() == 3 and d[0] == "Jack O'Lantern Blessings" and d[2].begins_with("Duration period: 1 Hour"))
	d = j.linhas_dica(11).map(func(x): return x.t)
	confere("descricao com '/' vira 3 linhas", d.size() == 4)
	confere("1 sem tempo na dica", j.linhas_dica(1).size() == 2)
	j.livre = 450
	confere("com uma janela aberta a fila anda pra 125", j._rect(0).position.x == 125)
	j.livre = 640
	confere("9o icone na segunda linha", j._rect(8).position == Vector2(220, 48))
	j.tirar(35)
	confere("tirar", not j.buffs.has(35))

	var c := CaixaFruta.new()
	root.add_child(c)
	var mandou := []
	c.escolheu.connect(func(s, u): mandou.append([s, u]))
	c.abrir(20, 3)
	confere("titulo da fruta +3", c.titulo() == "STR Fruit")
	c.escolher(0)
	c.abrir(21, 0)
	c.escolher(1)
	c.abrir(22, 1)
	c.escolher(2)
	c.escolher(0)
	confere("Create manda 0, Decrease 1, Cancel nada, fechada nao manda", mandou == [[20, 0], [21, 1]])
	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
