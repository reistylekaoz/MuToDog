extends SceneTree
# Confere a rodada 19 sem servidor: o Kanturu. O mapa 39 (pasta mundo40) em pacote a parte, com a Maya, a
# grade da torre aberta (atributos_sucesso.png), as musicas e os sons; os pacotes C1 D1 que chegam (00 a 07, os
# do OpenMU daqui gravados em dados/gravacao_r19.txt) e os que saem (D1 00, D1 01); a janela do Gateway
# (frases por estado, Enter aceso ou apagado, Refresh travado 3 s); a conferencia do equipamento antes do Enter;
# o painel da luta (textos, relogio com a conta do original), a Maya subindo, o resultado e a troca de grade.
# Uso: $G --headless --path . --script res://testes/rodada19.gd   (termina com "falhas: 0")

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


func _initialize() -> void:
	# mapa, pacote e arquivos
	confere("39 usa mundo40, em pacote a parte", PacoteMapa.mundo_do_mapa(39) == 40 and 40 in PacoteMapa.FORA)
	for f in ["mundo40/objetos.json", "mundo40/musica.mp3", "mundo40/musica_maya.mp3", "mundo40/musica_nightmare.mp3",
			"mundo40/atributos_sucesso.png", "mundo40/sons/maya_intro.wav", "mundo40/sons/maya_death.wav",
			"mundo40/sons/maya_storm.wav", "mundo40/sons/kan_boss_disfield.wav", "mundo40/efeitos/mayastone01.glb",
			"hud/kanturu/info.png", "hud/kanturu/sucesso.png", "hud/kanturu/falha.png", "hud/kanturu/msg_fundo.png"]:
		confere("arquivo " + f, FileAccess.file_exists("res://dados/" + f))
	confere("mundo40 esconde a lista do original", Ambiente.ESCONDER.get(40) == [1, 32, 45, 47, 48, 51, 52, 53, 54, 57, 58, 70])

	# pacotes que chegam
	var cli := ClienteMU.new()
	for s in ["kanturu_info", "kanturu_entrada", "kanturu_estado", "kanturu_resultado", "kanturu_tempo",
			"kanturu_maya", "kanturu_contagem"]:
		cli.connect(s, guarda(s))
	cli._tratar(PackedByteArray([0xC1, 0x0C, 0xD1, 0x00, 2, 1, 1, 0, 0, 0, 0, 0]))
	confere("D1 00: Maya, espera 1, pode entrar, 0 pessoas", ultimo.get("kanturu_info", []) == [2, 1, true, 0, 0])
	cli._tratar(PackedByteArray([0xC1, 0x05, 0xD1, 0x01, 1]))
	confere("D1 01: entrou", ultimo.get("kanturu_entrada", []) == [1])
	cli._tratar(PackedByteArray([0xC1, 0x06, 0xD1, 0x03, 2, 4]))
	confere("D1 03: Maya de pe (2, 4)", ultimo.get("kanturu_estado", []) == [2, 4])
	cli._tratar(PackedByteArray([0xC1, 0x08, 0xD1, 0x05, 0xA0, 0xBB, 0x0D, 0x00]))
	confere("D1 05: 900000 ms", ultimo.get("kanturu_tempo", []) == [900000])
	cli._tratar(PackedByteArray([0xC1, 0x07, 0xD1, 0x06, 0, 0, 1]))
	confere("D1 06: chuva de pedras", ultimo.get("kanturu_maya", []) == [1])
	cli._tratar(PackedByteArray([0xC1, 0x06, 0xD1, 0x07, 0x28, 0x01]))
	confere("D1 07: 40 monstros, 1 pessoa", ultimo.get("kanturu_contagem", []) == [40, 1])
	cli._tratar(PackedByteArray([0xC1, 0x05, 0xD1, 0x04, 1]))
	confere("D1 04: venceu", ultimo.get("kanturu_resultado", []) == [1])
	ultimo.erase("kanturu_info")
	cli._tratar(PackedByteArray([0xC1, 0x08, 0xD1, 0x00, 2, 1, 1, 0]))
	confere("D1 00 curto e ignorado", not ultimo.has("kanturu_info"))

	# o que sai
	var con := ConFalsa.new()
	cli.con = con
	cli.kanturu_pedir_info()
	cli.kanturu_entrar()
	confere("sai C1 D1 00 e C1 D1 01", con.enviados[0] == PackedByteArray([0xC1, 4, 0xD1, 0x00])
		and con.enviados[1] == PackedByteArray([0xC1, 4, 0xD1, 0x01]))

	# a conferencia do equipamento
	var asa := {"grupo": 12, "numero": 36}
	var pend := {"grupo": 13, "numero": 38}
	confere("sem asa nem montaria: voar", JanelaKanturu.recusa({11: pend}, false) == "voar")
	confere("Uniria: uniria", JanelaKanturu.recusa({7: asa, 8: {"grupo": 13, "numero": 2}, 11: pend}, false) == "uniria")
	confere("anel de transformacao: anel", JanelaKanturu.recusa({7: asa, 10: {"grupo": 13, "numero": 10}, 11: pend}, false) == "anel")
	confere("sem pingente: pingente", JanelaKanturu.recusa({7: asa, 10: {"grupo": 13, "numero": 9}}, false) == "pingente")
	confere("asa e pingente: pode", JanelaKanturu.recusa({7: asa, 11: pend}, false) == "")
	confere("Dinorant e pingente: pode", JanelaKanturu.recusa({8: {"grupo": 13, "numero": 3}, 10: pend}, false) == "")
	confere("torre aberta: entra sem conferir", JanelaKanturu.recusa({}, true) == "")
	confere("frases da caixa", JanelaKanturu.texto_caixa("voar") == DicaItem.t(2176)
		and JanelaKanturu.texto_caixa(0) == DicaItem.t(2170) and JanelaKanturu.texto_caixa(2) == DicaItem.t(2172))

	# a janela do Gateway
	var j := JanelaKanturu.new()
	root.add_child(j)
	await process_frame
	var pediu := []
	var entrou := []
	j.atualizar.connect(func(): pediu.append(1))
	j.entrar.connect(func(): entrou.append(1))
	j.info(2, 1, true, 0, 0)
	confere("Maya na espera: \"%s\", 1 frase, Enter aceso" % j.assunto, j.visible and j.assunto == DicaItem.t(2163)
		and j.frases == [DicaItem.t(2164)] and j.pode)
	j.info(2, 7, false, 5, 0)
	confere("segunda espera com 5: 2 frases, Enter apagado", j.frases == [DicaItem.t(2165, [5]), DicaItem.t(2167, [10])] and not j.pode)
	j.info(2, 9, false, 3, 0)
	confere("luta da mao direita", j.assunto == DicaItem.t(2152) and j.frases == [DicaItem.t(2153, [3]), DicaItem.t(2155, [3])])
	j.info(4, 1, true, 0, 7200)
	confere("torre aberta: 2 horas", j.assunto == DicaItem.t(2149) and j.frases[1] == DicaItem.t(2151, [2]))
	j.info(1, 1, false, 0, 600)
	confere("espera do evento: 10 minutos", j.frases[0] == DicaItem.t(2159, [10]))
	confere("quebra a 52 letras", JanelaKanturu.quebrar(DicaItem.t(2150)).all(func(l): return l.length() <= 52))
	j.clicar(0)
	j.clicar(0)
	confere("Refresh pede uma vez e trava", pediu == [1] and j.refresh_travado)
	j.clicar(1)
	confere("Enter apagado nao entra", entrou.is_empty() and j.visible)
	j.info(2, 1, true, 0, 0)
	j.clicar(1)
	confere("Enter aceso entra e fecha", entrou == [1] and not j.visible)

	# painel, Maya, resultado e grade com o mapa de verdade
	var s := Som.new()
	root.add_child(s)
	var m := Node3D.new()
	m.set_script(load("res://scripts/mundo.gd"))
	m.modo_jogo = true
	m.numero = 40
	root.add_child(m)
	await process_frame
	await process_frame
	var k := Kanturu.new()
	root.add_child(k)
	await process_frame
	k.som = s
	k.mapa(39, m)
	confere("Maya achada e escondida embaixo", k._maya != null and is_equal_approx(k._maya.position.z, Kanturu.ALTURA_MAYA + Kanturu.BAIXO))
	k.mudar(2, 2)
	for i in 60:
		await create_timer(0.1).timeout
		if not k._maya_subindo:
			break
	confere("aviso da luta: a Maya sobe ate -749,5", not k._maya_subindo and is_equal_approx(k._maya.position.z, Kanturu.ALTURA_MAYA))
	s.atualizar(39, false, 0)
	confere("som: musica da Maya", s._faixa.ends_with("mundo40/musica_maya.mp3"))
	k.mudar(2, 4)
	k.tempo(900000)
	confere("luta: painel ligado, relogio 15:00 (a conta do original da 0)", k.mostrando and k.relogio() == Vector2i(15, 0))
	k.tempo(125000)
	confere("125 s: 2 min e 5 s (125 %% 120)", k.relogio() == Vector2i(2, 5))
	k.tempo(45000)
	confere("ultimo minuto: segundos em 0", k.relogio() == Vector2i(0, 0))
	k.fim(1)
	confere("vitoria fora do Nightmare nao aparece", k.resultado == -1)
	k.mudar(3, 3)
	s.atualizar(39, false, 0)
	confere("Nightmare: painel e musica dele", k.mostrando and s._faixa.ends_with("musica_nightmare.mp3"))
	k.fim(1)
	confere("vitoria no Nightmare aparece", k.resultado == 1)
	var antes: bool = m.anda(80, 145)
	k.mudar(4, 1)
	confere("torre aberta: painel some, barreira em 80,145 abre (antes %s)" % antes, not k.mostrando and k._sucesso_mapa
		and not antes and m.anda(80, 145))
	k.mudar(1, 1)
	confere("espera: grade do mapa de volta", not k._sucesso_mapa and not m.anda(80, 145))
	k.mapa(38)
	s.atualizar(38, false, 0)
	confere("fora do 39: nada aparece, musica comum", not k.mostrando and s.kanturu == 0 and not s._faixa.ends_with("musica_maya.mp3"))
	print("falhas: %d" % falhas)
	quit(1 if falhas > 0 else 0)
