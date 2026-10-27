class_name Som
extends Node
# Musica e som de fundo do mapa, no jeito do cliente S6 (SceneManager.cpp):
# na zona segura toca a musica da cidade: Lorencia main_theme.mp3 (Pub.mp3 em cima do
# chao da taverna, HeroTile 4), Devias Devias.mp3 (em dados/mundo3, Church.mp3 dentro da igreja,
# x 205..214, y 13..31), Noria Noria.mp3 (dados/mundo4). Fora da zona segura a musica que tocava vai
# ate o fim e nao volta; trocou de mapa, para.
# Vento (aWind.wav): Lorencia menos na taverna, Devias menos no chao 3 e do 10 pra cima
# (dentro das casas), Noria sempre, com a floresta (aForest.wav) de vez em quando.
# Dungeon (Dungeon.mp3 + aDungeon.wav), Lost Tower (lost_tower_a.mp3 + aTower.wav), Atlans
# (atlans.mp3 + aWater.wav) e Tarkan (tarkan.mp3 + desert.wav): musica
# e fundo no mapa todo, sem parar; moram no pacote do mapa (dados/mundo<N>/). Os mapas novos
# (Icarus ate Karutan) seguem o mesmo jeito: musica.mp3 e, quando tem, fundo.wav.

const PASTA := "res://dados/ambiente/"
var musica := AudioStreamPlayer.new()
var vento := AudioStreamPlayer.new()
var floresta := AudioStreamPlayer.new()
var fundo := AudioStreamPlayer.new()
var evento := AudioStreamPlayer.new()
var mudo := false
var _efeitos: Array[AudioStreamPlayer] = []   # sons soltos (dados/sons: subir de nivel, fogos, medalha...)
var _db_efeitos := -6.0
var _faixa := ""
var _mapa := -1
var doppel := false  # Doppelganger com a moldura ligada (CGMDoppelGanger::PlayBGM: sem ela, silencio)
var imperial := -1   # Imperial Fortress: clima do F7 02 (1 chuva, 2 neblina, 3 tempestade; 4 = mapa 72, dentro)
var _fundo_imp := ""
var kanturu := 0     # estado do evento do Kanturu (C1 D1 03): 1 espera, 2 Maya, 3 Nightmare, 4 torre
var crywolf := 0     # estado do Crywolf (C1 BD 00): 2 aviso, 3 pronto, 4 luta, 5 fim
var raklion_chefe := false   # CGM_Raklion::m_bMusicBossMap: liga no READY, desliga no END
var templo := 0      # estado do Illusion Temple (C1 BF 09 + 1): 0 nada, 1 espera, 2 pronto, 3 partida, 4 fim


func _ready() -> void:
	musica.volume_db = -8.0
	vento.volume_db = -14.0
	floresta.volume_db = -12.0
	add_child(musica)
	add_child(vento)
	add_child(floresta)
	fundo.volume_db = -12.0
	add_child(fundo)
	add_child(evento)
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
		fundo.stop()
		vento.stop()
		_faixa = ""
		var pasta := "res://dados/mundo%d/" % PacoteMapa.mundo_do_mapa(mapa)
		if ResourceLoader.exists(pasta + "fundo.wav"):
			var w := load(pasta + "fundo.wav") as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = int(w.get_length() * w.mix_rate)
			fundo.stream = w
			fundo.play()
			print("TESTE fundo %d" % mapa)
	# Crywolf (M34CryWolf1st::ChangeBackGroundMusic): o 2o aviso, o pronto e a luta tem musica propria, o fim
	# fica em silencio (o som da vitoria ou da derrota sai pelo evento), o resto com a do mapa
	if mapa == 34:
		var nomes := {2: "musica_antes.ogg", 3: "musica_pronto.ogg", 4: "musica_luta.ogg", 5: ""}
		var cw: String = nomes.get(crywolf, "musica.mp3")
		if cw == "":
			if _faixa != "":
				musica.stop()
				_faixa = ""
		elif ("res://dados/mundo35/" + cw != _faixa or not musica.playing) and ResourceLoader.exists("res://dados/mundo35/" + cw):
			_faixa = "res://dados/mundo35/" + cw
			musica.stream = load(_faixa)
			musica.play()
			print("TESTE musica crywolf %s" % cw)
		return
	# ninho do Selupan (CGM_Raklion::PlayBGM): Raklion_Hatchery so com a luta marcada, senao nada
	if mapa == 58:
		var rk := "res://dados/mundo59/musica_chefe.mp3" if raklion_chefe else ""
		if rk == "":
			if _faixa != "":
				musica.stop()
				_faixa = ""
		elif rk != _faixa or not musica.playing:
			_faixa = rk
			musica.stream = load(rk)
			musica.play()
			print("TESTE musica raklion chefe")
		return
	# Kanturu 3 (M39Kanturu3rd::ChangeBackGroundMusic): espera e Maya com a da Maya, Nightmare com a dele,
	# o resto (torre aberta, nada) com a da torre
	if mapa == 39:
		var nome := "musica_maya.mp3" if kanturu in [1, 2] else ("musica_nightmare.mp3" if kanturu == 3 else "musica.mp3")
		var kt := "res://dados/mundo40/" + nome
		if (kt != _faixa or not musica.playing) and ResourceLoader.exists(kt):
			_faixa = kt
			musica.stream = load(kt)
			musica.play()
			print("TESTE musica kanturu %s" % nome)
		return
	# Illusion Temple (CursedTemple::PlayBGM): sem estado nao toca nada, na espera cursedtemplewait e do
	# pronto em diante cursedtempleplay (musica_jogo.mp3)
	if mapa >= 45 and mapa <= 50:
		var it := "" if templo == 0 else "res://dados/mundo47/" + ("musica.mp3" if templo == 1 else "musica_jogo.mp3")
		if it == "":
			if _faixa != "":
				musica.stop()
				_faixa = ""
		elif (it != _faixa or not musica.playing) and ResourceLoader.exists(it):
			_faixa = it
			musica.stream = load(it)
			musica.play()
			print("TESTE musica templo %s" % it.get_file())
		return
	# Imperial Fortress (GMEmpireGuardian*::PlayBGM e PlayObjectSound): a mesma musica nos 4 mapas, sempre;
	# o fundo pelo clima (sol, nenhum) e no 72 o de dentro
	if mapa >= 69 and mapa <= 72:
		var im := Imperial.SONS % "musica.mp3"
		if (im != _faixa or not musica.playing) and ResourceLoader.exists(im):
			_faixa = im
			musica.stream = load(im)
			musica.play()
			print("TESTE musica imperial")
		var nomes := {1: "chuva_som.wav", 2: "neblina_som.wav", 3: "tempestade_som.wav", 4: "dentro_som.wav"}
		var fs: String = Imperial.SONS % nomes[imperial] if nomes.has(imperial) else ""
		if fs != _fundo_imp:
			_fundo_imp = fs
			fundo.stop()
			if fs != "" and ResourceLoader.exists(fs):
				var w := (load(fs) as AudioStreamWAV).duplicate() as AudioStreamWAV
				w.loop_mode = AudioStreamWAV.LOOP_FORWARD
				w.loop_end = int(w.get_length() * w.mix_rate)
				fundo.stream = w
				fundo.play()
				print("TESTE fundo imperial %s" % fs.get_file())
		return
	_fundo_imp = ""
	if mapa >= 65 and mapa <= 68:
		var dp := Doppel.SONS % "musica.mp3" if doppel else ""
		if dp == "" or not ResourceLoader.exists(dp):
			if _faixa != "":
				musica.stop()
				_faixa = ""
		elif dp != _faixa or not musica.playing:
			_faixa = dp
			musica.stream = load(dp)
			musica.play()
			print("TESTE musica doppelganger")
		return
	if mapa not in [0, 2, 3] and (_faixa == "" or not musica.playing):
		var mp := "res://dados/mundo%d/musica.mp3" % PacoteMapa.mundo_do_mapa(mapa)
		if ResourceLoader.exists(mp):
			_faixa = mp
			musica.stream = load(mp)
			musica.play()
			print("TESTE musica %d" % mapa)
		return
	var quer := ""
	if seguro:
		match mapa:
			0: quer = "pub" if tile == 4 else "main_theme"
			2: quer = "igreja" if x >= 205 and x <= 214 and y >= 13 and y <= 31 else "devias"
			3: quer = "noria"
	# Devias e Noria baixam em pacote: a musica da cidade mora no mundo do mapa (fora do index.pck)
	var pasta := PASTA if mapa == 0 else "res://dados/mundo%d/" % PacoteMapa.mundo_do_mapa(mapa)
	if quer != "" and (quer != _faixa or not musica.playing) and ResourceLoader.exists(pasta + quer + ".mp3"):
		_faixa = quer
		musica.stream = load(pasta + quer + ".mp3")
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
	fundo.volume_db = floresta.volume_db
	_db_efeitos = -6.0 + linear_to_db(maxf(v_efeitos, 0.001) / 0.8)


# som de uma vez (PlayBuffer do cliente); ate 6 ao mesmo tempo
func tocar(nome: String) -> void:
	var c := nome if nome.begins_with("res://") else "res://dados/sons/%s.wav" % nome
	if mudo or not ResourceLoader.exists(c):
		return
	var p: AudioStreamPlayer = null
	for x in _efeitos:
		if not x.playing:
			p = x
	if p == null:
		if _efeitos.size() >= 6:
			return
		p = AudioStreamPlayer.new()
		add_child(p)
		_efeitos.append(p)
	p.stream = load(c)
	p.volume_db = _db_efeitos
	p.play()


# som que repete ate parar (PlayBuffer com loop: o iBloodCastle.wav durante o castelo)
func laco(nome: String) -> void:
	var c := nome if nome.begins_with("res://") else "res://dados/sons/%s.wav" % nome
	if mudo or not ResourceLoader.exists(c):
		return
	var w := (load(c) as AudioStreamWAV).duplicate() as AudioStreamWAV
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = int(w.get_length() * w.mix_rate)
	evento.stream = w
	evento.volume_db = _db_efeitos
	evento.play()
	print("TESTE laco %s" % nome)


func parar_laco() -> void:
	evento.stop()


func alternar() -> bool:
	mudo = not mudo
	if mudo:
		musica.stop()
		vento.stop()
		floresta.stop()
		fundo.stop()
		_faixa = ""
		_mapa = -1
	return mudo
