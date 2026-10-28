extends SceneTree
# Confere a rodada 24 sem servidor: a tela de login do S6 (LoginCena). O caminho da camera (CWScript74 com os
# 10 pontos), o tour (passa por todos e volta pro primeiro, o giro anda no maximo 1 grau por quadro, a camera fica
# acima do chao do World74 o caminho inteiro), a janela (posicao a 2/3, caixas, OK que so manda quando ligado,
# Cancel que limpa), as texturas e o mapa convertido (tile 10 transparente, musica do login).
# Uso: $G --headless --path . --script res://testes/rodada24.gd   (termina com "falhas: 0")

var falhas := 0


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _initialize() -> void:
	for f in ["janela", "caixa", "ok", "cancelar", "logo", "logo_g"]:
		confere("textura login/%s" % f, ResourceLoader.exists("res://dados/login/%s.png" % f))
	for f in ["altura.png", "mapa.png", "objetos.json", "musica.mp3", "caminho.json", "tiles/10.png"]:
		confere("mundo74/%s" % f, ResourceLoader.exists("res://dados/mundo74/" + f) or FileAccess.file_exists("res://dados/mundo74/" + f))
	var t10 := (load("res://dados/mundo74/tiles/10.png") as Texture2D).get_image()
	confere("tile 10 do login e o AlphaTile01 (transparente)", t10.get_pixel(t10.get_width() / 2, t10.get_height() / 2).a < 0.5)
	confere("74 esconde os objetos do Imperial 4 (79 a 86, 129 a 132)", Ambiente.ESCONDER.get(74, []).has(129))
	confere("74 vai em pacote a parte no navegador", PacoteMapa.FORA.has(74))

	var pontos := LoginCena.ler_caminho("res://dados/mundo74/caminho.json")
	confere("caminho com 10 pontos", pontos.size() == 10)
	confere("primeiro ponto 24200, 2500, demora 0, acel 18, nivel 8", pontos.size() > 0 and pontos[0] == [24200.0, 2500.0, 0.0, 18.0, 8.0])

	var tela := LoginCena.new()
	tela.size = Vector2(800, 600)
	get_root().add_child(tela)
	await process_frame
	tela.set_process(false)
	tela._ajustar()
	var o: Vector2 = tela.janela()
	confere("janela 329 x 245 no meio, a 2/3 da altura", o == Vector2(roundf((tela.size.x - 329) / 2.0), roundf((tela.size.y - 245) * 2.0 / 3.0)))
	confere("conta e senha em cima das caixas (115, 108 e 133)", tela.campo_conta.position == o + Vector2(115, 108) and tela.campo_senha.position == o + Vector2(115, 133))
	confere("senha escondida, conta ate 10 letras", tela.campo_senha.secret and tela.campo_conta.max_length == 10)

	# tour: 25 quadros por segundo
	tela.iniciar_tour(0)
	confere("comeca no ultimo ponto olhando pro primeiro", tela._atual == Vector2(24500, 2900) and tela._alvo == 0)
	var vistos := {}
	var giro_max := 0.0
	var menor_folga := 99999.0
	var mundo := Node3D.new()
	mundo.set_script(load("res://scripts/mundo.gd"))
	mundo.numero = 74
	var alt: Image = (load("res://dados/mundo74/altura.png") as Texture2D).get_image()
	var antes: float = tela._angulo
	var voltou := false
	for q in 25 * 60 * 4:
		tela.passo_tour(1.0)
		vistos[tela._alvo] = true
		var d := absf(fposmod(tela._angulo - antes + 180.0, 360.0) - 180.0)
		giro_max = maxf(giro_max, d)
		antes = tela._angulo
		if q % 10 == 0:
			var c: Transform3D = tela.camera()
			var p := c.origin * 100.0
			var x := clampi(int(p.x / 100.0), 0, 255)
			var y := clampi(int(-p.z / 100.0), 0, 255)
			menor_folga = minf(menor_folga, p.y - alt.get_pixel(x, y).r * 255.0 * 1.5)
		if vistos.size() == 10 and tela._alvo == 1:
			voltou = true
	confere("passou pelos 10 pontos e voltou pro comeco", vistos.size() == 10 and voltou)
	confere("giro de no maximo 1 grau por quadro (%.2f)" % giro_max, giro_max <= 1.001)
	confere("camera acima do chao o caminho inteiro (menor folga %d)" % menor_folga, menor_folga > 100.0)
	confere("nivel da distancia entre 7 e 8", tela._nivel >= 7.0 and tela._nivel <= 8.0)
	mundo.free()
	var c0: Transform3D = tela.camera()
	confere("camera olha pra baixo (17,5 graus abaixo do horizonte)", is_equal_approx(snappedf(rad_to_deg(asin(-(c0.basis * Vector3(0, 0, -1)).y)), 0.1), 17.5))

	# botoes
	var mandou := [0]
	tela.ok.connect(func(): mandou[0] += 1)
	tela.clicar("ok")
	confere("OK manda", mandou[0] == 1)
	tela.botao.disabled = true
	tela.clicar("ok")
	confere("OK desligado enquanto conecta", mandou[0] == 1)
	tela.campo_conta.text = "test0"
	tela.campo_senha.text = "x"
	var cancelou := [0]
	tela.cancelou.connect(func(): cancelou[0] += 1)
	tela.clicar("cancelar")
	# CLoginWin::CancelLogin: liga de novo no connect server e esconde o login (os campos ficam)
	confere("Cancel volta pra escolha do servidor", cancelou[0] == 1 and tela.campo_conta.text == "test0")
	var b: Dictionary = tela._botoes()
	confere("OK e Cancel lado a lado embaixo das caixas", b.ok.position == o + Vector2(150, 172) and b.cancelar.position.x - b.ok.position.x == 61)
	tela.free()

	# pacotes que sobravam no medir.py
	var cli := ClienteMU.new()
	var visto := {}
	cli.guilda_criar_dialogo.connect(func(): visto["55"] = true)
	cli.bau_fechou.connect(func(): visto["82"] = true)
	cli._tratar(PackedByteArray([0xC1, 3, 0x55]))
	confere("C1 55 abre a parte do nome e da marca da guilda", visto.has("55"))
	cli._tratar(PackedByteArray([0xC1, 3, 0x82]))
	confere("C1 82 fecha o bau", visto.has("82"))
	cli._tratar(PackedByteArray([0xC1, 5, 0xDE, 0x00, 0x0B]))
	confere("C1 DE 00 troca as classes liberadas (Summoner, DL e RF)", cli.liberadas == 0x0B)
	cli.free()
	var j := JanelaCriarGuilda.new()
	get_root().add_child(j)
	j.abrir()
	j.ir(JanelaCriarGuilda.MARCA)
	confere("janela de guilda vai pra marca", j.passo == JanelaCriarGuilda.MARCA)
	j.free()
	print("falhas: %d" % falhas)
	quit()
