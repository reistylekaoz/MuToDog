extends SceneTree
# Confere a rodada 9 sem servidor: os pacotes do Gens que chegam (F9 01 com a contribuicao, F8 02, 04, 0A,
# 07, C2 F8 05) e os que saem (F8 01, 03, 09, 0B), os nomes do Gens e do titulo, a marca e a janela B.
# Uso: $G --headless --path . --script res://testes/rodada9.gd   (termina com "falhas: 0")

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


func le(v: int) -> Array:
	return [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]


func _initialize() -> void:
	var cli := ClienteMU.new()
	for s in ["dialogo_npc", "gens_entrou", "gens_saiu", "gens_premio", "gens_info", "gens_jogadores"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 10, 0xF9, 0x01, 0x1F, 0x02, 0, 0] + le(1234)))
	confere("F9 01: npc 543 com 1234 de contribuicao", ultimo.get("dialogo_npc", []) == [543, 1234])
	cli._tratar(PackedByteArray([0xC1, 6, 0xF9, 0x01, 0x20, 0x02]))
	confere("F9 01 curto: npc 544, contribuicao 0", ultimo.get("dialogo_npc", []) == [544, 0])
	cli._tratar(PackedByteArray([0xC1, 6, 0xF8, 0x02, 0, 2]))
	confere("F8 02: entrou no Vanert", ultimo.get("gens_entrou", []) == [0, 2])
	cli._tratar(PackedByteArray([0xC1, 5, 0xF8, 0x04, 2]))
	confere("F8 04: mestre nao sai", ultimo.get("gens_saiu", []) == [2])
	cli._tratar(PackedByteArray([0xC1, 5, 0xF8, 0x0A, 1]))
	confere("F8 0A: fora do periodo", ultimo.get("gens_premio", []) == [1])
	cli._tratar(PackedByteArray([0xC1, 24, 0xF8, 0x07, 1, 0, 0, 0] + le(7) + le(13) + le(250) + le(250)))
	confere("F8 07: Duprian, posicao 7, titulo 13, 250 e falta 250",
		ultimo.get("gens_info", [{}])[0] == {"gens": 1, "posicao": 7, "titulo": 13, "contribuicao": 250, "falta": 250})
	var p := PackedByteArray([0xC2, 0, 0, 0xF8, 0x05, 2])
	p.append_array([2, 0x84, 0x8E, 0] + le(3) + le(10) + le(900))
	p.append_array([1, 0x00, 0x05, 0] + le(0) + le(14) + le(0))
	p[2] = p.size()
	cli._tratar(p)
	var l: Array = ultimo.get("gens_jogadores", [[]])[0]
	confere("C2 F8 05: 2 jogadores", l.size() == 2)
	confere("C2 F8 05: id 1166 (sem o bit alto) Vanert titulo 10 com 900", l.size() == 2 and l[0].id == 1166 and l[0].gens == 2
		and l[0].titulo == 10 and l[0].contribuicao == 900 and l[0].posicao == 3)
	confere("C2 F8 05: id 5 Duprian Private", l.size() == 2 and l[1].id == 5 and l[1].gens == 1 and l[1].titulo == 14)

	var con := ConFalsa.new()
	cli.con = con
	cli.gens_entrar(1)
	cli.gens_sair()
	cli.gens_pedir_premio(2)
	cli.gens_pedir_info()
	var e: Array = con.enviados
	confere("sai F8 01 Duprian", e.size() == 4 and e[0] == PackedByteArray([0xC1, 5, 0xF8, 0x01, 1]))
	confere("sai F8 03", e.size() == 4 and e[1] == PackedByteArray([0xC1, 4, 0xF8, 0x03]))
	confere("sai F8 09 Vanert", e.size() == 4 and e[2] == PackedByteArray([0xC1, 5, 0xF8, 0x09, 2]))
	confere("sai F8 0B", e.size() == 4 and e[3] == PackedByteArray([0xC1, 4, 0xF8, 0x0B]))

	confere("nome do Gens: Duprian e Vanert", JanelaGens.nome_gens(1) == "Duprian" and JanelaGens.nome_gens(2) == "Vanert")
	print("  titulos: %s / %s" % [JanelaGens.nome_titulo(1), JanelaGens.nome_titulo(14)])
	confere("titulo 1 e 14 tem nome", JanelaGens.nome_titulo(1) != "" and JanelaGens.nome_titulo(14) != ""
		and JanelaGens.nome_titulo(1) != JanelaGens.nome_titulo(14))
	confere("marca do Private no canto (0,0)", JanelaGens.regiao_marca(14) == Rect2(0, 0, 50, 69))
	confere("marca do Grand Duke na 3a linha", JanelaGens.regiao_marca(1) == Rect2(150, 138, 50, 69))
	confere("titulo fora da faixa vale Private", JanelaGens.regiao_marca(0) == Rect2(0, 0, 50, 69))
	var j := JanelaGens.new()
	root.add_child(j)
	j.definir({"gens": 2, "posicao": 3, "titulo": 10, "contribuicao": -5, "falta": 100})
	confere("janela B: contribuicao negativa vira 0", j.gens == 2 and j.titulo == 10 and j.contribuicao == 0)
	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
