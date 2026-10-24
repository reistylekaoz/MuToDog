extends SceneTree
# Confere a rodada 8 sem servidor: os pacotes de alianca, rival e guerra que chegam (C1 E5, E6, C2 E9,
# C1 EB 01, 60 a 64, F3 23) e os que saem (C1 E5, E6, E9, EB 01, 61), a aba Alliance e o placar.
# Uso: $G --headless --path . --script res://testes/rodada8.gd   (termina com "falhas: 0")

var falhas := 0
var ultimo := {}


class ConFalsa extends Conexao:
	var enviados: Array = []

	func enviar(pacote: PackedByteArray) -> void:
		Cripto.gravar_tamanho(pacote)
		enviados.append(pacote)


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func guarda(sinal: String) -> Callable:
	return func(...a): ultimo[sinal] = a


func nome(n: String, tam: int) -> PackedByteArray:
	var b := n.to_ascii_buffer()
	b.resize(tam)
	return b


func _initialize() -> void:
	var cli := ClienteMU.new()
	for s in ["relacao_pedido", "relacao_resultado", "alianca_lista", "alianca_tirou", "guerra_resultado", "guerra_pedido",
			"guerra_comecou", "guerra_fim", "guerra_placar", "futebol_placar"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 7, 0xE5, 1, 1, 0x04, 0x8E]))
	confere("C1 E5: alianca, entrar, do id 1166", ultimo.get("relacao_pedido", []) == [1, 1, 1166])
	cli._tratar(PackedByteArray([0xC1, 8, 0xE6, 2, 1, 0x16, 0x04, 0x8E]))
	confere("C1 E6: rival, entrar, 0x16 (ja tem rival)", ultimo.get("relacao_resultado", []) == [2, 1, 0x16, 1166])
	# C2 E9: 2 guildas (Lobos 3 membros, Ursos 1)
	var p := PackedByteArray([0xC2, 0, 0, 0xE9, 2, 1, 0, 2])
	for g in [["Lobos", 3], ["Ursos", 1]]:
		p.append(g[1])
		var logo := PackedByteArray()
		logo.resize(32)
		logo[0] = 0x46
		p.append_array(logo)
		p.append_array(nome(g[0], 8))
	p[2] = p.size()
	cli._tratar(p)
	var a: Array = ultimo.get("alianca_lista", [])
	confere("C2 E9: ok, 0 rivais, 2 aliadas", a.size() == 4 and a[0] and a[1] == 0 and a[2] == 2)
	confere("C2 E9: Lobos 3 e Ursos 1 com a logo", a[3].size() == 2 and a[3][0].nome == "Lobos" and a[3][0].membros == 3
		and a[3][1].nome == "Ursos" and a[3][1].logo.size() == 32 and a[3][1].logo[0] == 0x46)
	cli._tratar(PackedByteArray([0xC1, 7, 0xEB, 0x01, 1, 2, 1]))
	confere("C1 EB 01: tirou", ultimo.get("alianca_tirou", []) == [1, 2, 1])
	cli._tratar(PackedByteArray([0xC1, 4, 0x60, 1]))
	confere("C1 60: pedido de guerra mandado", ultimo.get("guerra_resultado", []) == [1])
	p = PackedByteArray([0xC1, 12, 0x61])
	p.append_array(nome("Lobos", 8))
	p.append(1)
	cli._tratar(p)
	confere("C1 61: Lobos chama pro Battle Soccer", ultimo.get("guerra_pedido", []) == ["Lobos", 1])
	p = PackedByteArray([0xC1, 13, 0x62])
	p.append_array(nome("Ursos", 8))
	p.append_array(PackedByteArray([0, 1]))
	cli._tratar(p)
	confere("C1 62: guerra contra Ursos, time 1", ultimo.get("guerra_comecou", []) == ["Ursos", 0, 1])
	cli._tratar(PackedByteArray([0xC1, 6, 0x64, 4, 2, 0]))
	confere("C1 64: placar 4 x 2", ultimo.get("guerra_placar", []) == [4, 2, 0])
	p = PackedByteArray([0xC1, 12, 0x63, 1])
	p.append_array(nome("Ursos", 8))
	cli._tratar(p)
	confere("C1 63: ganhou de Ursos", ultimo.get("guerra_fim", []) == [1, "Ursos"])
	p = PackedByteArray([0xC1, 22, 0xF3, 0x23])
	p.append_array(nome("Lobos", 8))
	p.append(3)
	p.append_array(nome("Ursos", 8))
	p.append(1)
	cli._tratar(p)
	confere("F3 23: Lobos 3 x 1 Ursos", ultimo.get("futebol_placar", []) == ["Lobos", 3, "Ursos", 1])

	# pacotes que saem
	var con := ConFalsa.new()
	cli.con = con
	cli.pedir_relacao(1, 1, 1166)
	cli.responder_relacao(2, 2, true, 1166)
	cli.pedir_alianca()
	cli.tirar_da_alianca("Ursos")
	cli.responder_guerra(false)
	var e: Array = con.enviados
	confere("C1 E5 de 7 com o id BE", e[0] == PackedByteArray([0xC1, 7, 0xE5, 1, 1, 0x04, 0x8E]))
	confere("C1 E6 de 8: rival, sair, aceito", e[1] == PackedByteArray([0xC1, 8, 0xE6, 2, 2, 1, 0x04, 0x8E]))
	confere("C1 E9 de 3", e[2] == PackedByteArray([0xC1, 3, 0xE9]))
	confere("C1 EB 01 de 12 com o nome no 4", e[3].size() == 12 and e[3][3] == 1 and e[3].slice(4, 9).get_string_from_ascii() == "Ursos")
	confere("C1 61 recusa", e[4] == PackedByteArray([0xC1, 4, 0x61, 0]))

	# aba Alliance: a mais nova em cima; o mestre da alianca e a guilda que da o nome
	var j := JanelaGuilda.new()
	j.definir_alianca(a[3])
	confere("aba Alliance: a ultima do pacote fica em cima", j.aliadas.size() == 2 and j.aliadas[0].nome == "Ursos"
		and j.aliadas[0].tex is ImageTexture)
	Guildas.guardar({"id": 9, "tipo": 0, "alianca": "Lobos", "nome": "Lobos", "logo": PackedByteArray()})
	j.guilda = 9
	j.meu_cargo = 128
	j.alianca = "Lobos"
	confere("aba Alliance: mestre de Lobos e mestre da alianca Lobos", j.sou_mestre_da_alianca())
	var tirou := []
	j.tirar_alianca.connect(func(n): tirou.append(n))
	j.em_guilda = true
	j.aba = 2
	j.clicar(Vector2(30, 135))   # primeira linha: Ursos
	j.clicar(Vector2(40, 240))   # Disband alliance
	confere("aba Alliance: escolhe Ursos e tira", tirou == ["Ursos"])
	j.free()
	var pl := PlacarGuerra.new()
	pl.guerra("Lobos", null, 4, "Ursos", null, 2, 1)
	confere("placar: time 1 pinta a minha de azul e a outra de vermelho",
		pl.linhas[0].cor == PlacarGuerra.AZUL and pl.linhas[1].cor == PlacarGuerra.VERMELHO and pl.linhas[1].pontos == 2)
	pl.free()
	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
