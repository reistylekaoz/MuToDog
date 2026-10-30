extends SceneTree
# Velocidade de ataque (SetAttackSpeed do cliente): golpe e skill do jogador ficam mais curtos com o
# AttackSpeed/MagicSpeed, e a janela C calcula os dois como o OpenMU (agilidade, armas, luva, excelente).
# Uso: $G --headless --path . --script res://testes/velocidade.gd   (termina com "falhas: 0")

var falhas := 0


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _duracao(b: Boneco, acao: String, vel: int) -> float:
	Boneco.vel_ataque = vel
	Boneco.vel_magia = vel
	b.tocar(acao)
	return b.falta_acao()


func _initialize() -> void:
	# PlaySpeed como no ZzzCharacter.cpp
	Boneco.vel_ataque = 0
	confere("espada sem velocidade = 0,25", is_equal_approx(Boneco.ritmo_por_velocidade("espada"), 0.25))
	Boneco.vel_ataque = 100
	confere("espada com 100 = 0,25 + 0,4", is_equal_approx(Boneco.ritmo_por_velocidade("espada"), 0.65))
	Boneco.vel_ataque = 520
	confere("faixa 509-549 sobe 0,0026", is_equal_approx(Boneco.ritmo_por_velocidade("espada"), 0.25 + 520 * 0.0026))
	Boneco.vel_magia = 100
	confere("magia (MagicSpeed2) com 100 = 0,29 + 0,2", is_equal_approx(Boneco.ritmo_por_velocidade("magia"), 0.49))
	confere("cura (MagicSpeed1) com 100 = 0,25 + 0,4", is_equal_approx(Boneco.ritmo_por_velocidade("cura"), 0.65))
	confere("parado nao muda", Boneco.ritmo_por_velocidade("parado") < 0.0)

	var dk := Boneco.da_classe(1 << 2)
	root.add_child(dk)
	var acao := "espada" if dk.tem("espada") else "soco"
	var lenta := _duracao(dk, acao, 0)
	var media := _duracao(dk, acao, 100)
	var rapida := _duracao(dk, acao, 300)
	print("  %s: %.2f s (0) %.2f s (100) %.2f s (300)" % [acao, lenta, media, rapida])
	confere("golpe encurta com a velocidade", lenta > media and media > rapida and rapida > 0.0)
	confere("golpe com 100 = 0,25/0,65 do sem", absf(media / lenta - 0.25 / 0.65) < 0.02)
	var sk := "espada_s1" if dk.tem("espada_s1") else acao
	print("  %s: %.2f s (0) %.2f s (200)" % [sk, _duracao(dk, sk, 0), _duracao(dk, sk, 200)])
	dk.tocar("parado")
	confere("parado nao e golpe (-1)", dk.falta_acao() < 0.0)

	var dw := Boneco.da_classe(0)
	root.add_child(dw)
	var m := "magia" if dw.tem("magia") else "soco"
	print("  DW %s: %.2f s (0) %.2f s (300)" % [m, _duracao(dw, m, 0), _duracao(dw, m, 300)])
	confere("magia encurta com a velocidade", _duracao(dw, m, 300) < _duracao(dw, m, 0))

	# janela C: DK agilidade 300 -> 300/15 = 20 de ataque, 300/20 = 15 de magia
	var j := JanelaPersonagem.new()
	j.eu = {"classe": 1 << 2, "agilidade": 300}
	confere("DK 300 de agilidade: ataque 20", j.vel_ataque() == 20)
	confere("DK 300 de agilidade: magia 15", j.vel_magia() == 15)
	j.eu = {"classe": 0, "agilidade": 300}
	confere("DW 300 de agilidade: magia 30 (a da janela)", j.vel_magia() == 30 and j.velocidade() == 30)
	j.eu = {"classe": 4 << 2, "agilidade": 300}
	confere("DL 300 de agilidade: 30", j.vel_ataque() == 30)
	j.free()
	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
