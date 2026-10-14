class_name Som
extends Node
# Musica e som de fundo do mapa, no jeito do cliente S6 (SceneManager.cpp):
# Lorencia, na zona segura: main_theme.mp3, ou Pub.mp3 em cima do chao da taverna
# (HeroTile 4). Fora da zona segura a musica que tocava vai ate o fim e nao volta.
# Vento (aWind.wav) sem parar na Lorencia, menos dentro da taverna. M liga e desliga.

const PASTA := "res://dados/ambiente/"
var musica := AudioStreamPlayer.new()
var vento := AudioStreamPlayer.new()
var mudo := false
var _faixa := ""


func _ready() -> void:
	musica.volume_db = -8.0
	vento.volume_db = -14.0
	add_child(musica)
	add_child(vento)
	var w := load(PASTA + "vento.wav") as AudioStreamWAV
	if w:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = int(w.get_length() * w.mix_rate)
		vento.stream = w


# mapa = numero do servidor (0 = Lorencia); tile = textura da camada 1 embaixo do personagem
func atualizar(mapa: int, seguro: bool, tile: int) -> void:
	if mudo:
		return
	var quer := ""
	if mapa == 0 and seguro:
		quer = "pub" if tile == 4 else "main_theme"
	if quer != "" and (quer != _faixa or not musica.playing):
		_faixa = quer
		musica.stream = load(PASTA + quer + ".mp3")
		musica.play()
		print("TESTE musica %s" % quer)
	elif mapa != 0 and musica.playing:
		musica.stop()
	var venta := mapa == 0 and tile != 4
	if venta and not vento.playing and vento.stream:
		vento.play()
		print("TESTE vento")
	elif not venta and vento.playing:
		vento.stop()


# volume 0..1 do menu (U); 0,8 e o volume de antes do menu
func volumes(v_musica: float, v_efeitos: float) -> void:
	musica.volume_db = -8.0 + linear_to_db(maxf(v_musica, 0.001) / 0.8)
	vento.volume_db = -14.0 + linear_to_db(maxf(v_efeitos, 0.001) / 0.8)


func alternar() -> bool:
	mudo = not mudo
	if mudo:
		musica.stop()
		vento.stop()
		_faixa = ""
	return mudo
