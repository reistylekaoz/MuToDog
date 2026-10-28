extends SceneTree
# Pontos em massa na janela C: o + pede a quantidade (sinal quantos, nao manda mais 1 ponto direto) e a caixa
# de quantos (CaixaMU.campo_numero) vem com 1, aberta, e so aceita digito. O envio (1 no F3 06, mais de 1 no
# /add do OpenMU) e testado contra o servidor: roteiro U:0,250 em testes/rodada_pontos_vivo.sh.
# Uso: $G --headless --path . --script res://testes/pontos_massa.gd

var falhas := 0


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _initialize() -> void:
	var j := JanelaPersonagem.new()
	var pediu := []
	var mandou := []
	j.quantos.connect(func(a): pediu.append(a))
	j.adicionar.connect(func(a): mandou.append(a))
	j.eu = {"classe": 16, "pontos": 0}   # Dark Lord (classe_base 4)
	j._clique(Vector2(168, JanelaPersonagem.ALTURAS[0] + 9))
	confere("sem ponto o + nao faz nada", pediu.is_empty() and mandou.is_empty())
	j.eu.pontos = 500
	j._clique(Vector2(168, JanelaPersonagem.ALTURAS[2] + 9))
	confere("com ponto o + da vitalidade pede quantos (e nao manda 1 direto)", pediu == [2] and mandou.is_empty())
	j._clique(Vector2(168, JanelaPersonagem.ALTURAS[4] + 9))
	confere("comando so no Dark Lord", pediu == [2, 4])
	j.eu.classe = 0
	j._clique(Vector2(168, JanelaPersonagem.ALTURAS[4] + 9))
	confere("Dark Wizard nao tem o + do comando", pediu == [2, 4])
	j.free()
	var c := CaixaMU.new(["STR", "Quantos pontos? (1 a 500)"])
	c.campo_numero("1")
	confere("caixa com campo visivel, aberto e com 1", c._campo.visible and not c._campo.secret and c._campo.text == "1")
	c._campo.text_changed.emit("2a5x0")
	confere("so digito fica no campo", c._campo.text == "250")
	confere("a caixa cresce 2 linhas pro campo", c.altura() == 67.0 + 15.0 * 2 + 50.0)
	var resp := []
	c.respondeu.connect(func(ok, t): resp.append([ok, t]))
	c.responder(true)
	confere("OK devolve o numero digitado", resp == [[true, "250"]])
	c.free()
	print("falhas: %d" % falhas)
	quit(falhas)
