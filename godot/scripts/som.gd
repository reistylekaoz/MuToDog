class_name Som
extends Node
# Musica e som de fundo do mapa, no jeito do cliente S6 (SceneManager.cpp):
# na zona segura toca a musica da cidade: Lorencia main_theme.mp3 (Pub.mp3 em cima do
# chao da taverna, HeroTile 4), Devias Devias.mp3 (Church.mp3 dentro da igreja,
# x 205..214, y 13..31), Noria Noria.mp3. Fora da zona segura a musica que tocava vai
# ate o fim e nao volta; trocou de mapa, para.
# Vento (aWind.wav): Lorencia menos na taverna, Devias menos no chao 3 e do 10 pra cima
# (dentro das casas), Noria sempre, com a floresta (aForest.wav) de vez em quando.

const PASTA := "res://dados/ambiente/"
var musica := AudioStreamPlayer.new()
var vento := AudioStreamPlayer.new()
var floresta := AudioStreamPlayer.new()
var mudo := false
var _faixa := ""
var _mapa := -1


func _ready() -> void:
	musica.volume_db = -8.0
	vento.volume_db = -14.0
	floresta.volume_db = -12.0
	add_child(musica)
	add_child(vento)
	add_child(floresta)
	var w := load(PASTA + "vento.wav") as AudioStreamWAV
	if w:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)
		vento.stream = w


# mapa = numero do servidor (0 Lorencia, 2 Devias, 3 Noria); tile = textura da camada 1
# embaixo do personagem; x, y = onde ele esta
func atualizar(mapa: int, seguro: bool, tile: int, x := 0, y := 0) -> void:
	if mudo:
		return
	if mapa != _mapa:
		_mapa = mapa
		musica.stop()
		floresta.stop()
		_faixa = ""
	var quer := ""
	if seguro:
		match mapa:
			0: quer = "pub" if tile == 4 else "main_theme"
			2: quer = "igreja" if x >= 205 and x <= 214 and y >= 13 and y <= 31 else "devias"
			3: quer = "noria"
	if quer != "" and (quer != _faixa or not musica.playing) and ResourceLoader.exists(PASTA + quer + ".mp3"):
		_faixa = quer
		musica.stream = load(PASTA + quer + ".mp3")
		musica.play()
		print("TESTE musica %s" % quer)
	# o cliente sorteia 1 em 512 por quadro (25 por segundo): uns 20 s em media
	if mapa == 3 and not floresta.playing and randf() < get_process_delta_time() * 25.0 / 512.0:
		if floresta.stream == null:
			floresta.stream = load(PASTA + "floresta.wav")
		floresta.play()
		print("TESTE floresta")
	var venta := (mapa == 0 and tile != 4) or (mapa == 2 and tile != 3 and tile < 10) or mapa == 3
	if venta and not vento.playing and vento.stream:
		vento.play()
		print("TESTE vento")
	elif not venta and vento.playing:
		vento.stop()


# volume 0..1 do menu (U); 0,8 e o volume de antes do menu
func volumes(v_musica: float, v_efeitos: float) -> void:
	musica.volume_db = -8.0 + linear_to_db(maxf(v_musica, 0.001) / 0.8)
	vento.volume_db = -14.0 + linear_to_db(maxf(v_efeitos, 0.001) / 0.8)
	floresta.volume_db = -12.0 + linear_to_db(maxf(v_efeitos, 0.001) / 0.8)


func alternar() -> bool:
	mudo = not mudo
	if mudo:
		musica.stop()
		vento.stop()
		floresta.stop()
		_faixa = ""
	return mudo
