class_name PacoteMapa
extends RefCounted
# Mapas que no navegador nao vao no pck principal (cada um soma uns 8 MB): o export
# Web grava mapas/mundo<N>.pck do lado do index.html (testes/exportar_web.sh) e o
# jogo baixa so quando o personagem entra. No PC exportado (testes/exportar_windows.sh)
# esses mapas e os modelos dos itens vao em pacotes na pasta mapas/ do lado do openmu.exe
# (cada zip da entrega cabe nos 50 MB do app arquivos) e montar_pc() monta todos na
# partida. Nos testes headless os dados estao no projeto e nada e carregado.
# Uso: await PacoteMapa.carregar(no_qualquer, numero_do_mundo)

const FORA := [2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 19, 25, 31, 32, 34, 35, 38, 39, 47, 52, 57, 58, 63, 64, 65, 66, 67, 68, 69, 75, 80, 81, 82]
# pacote 0 (mapas/mundo0.pck): os monstros dos eventos (Blood Castle, Kalima, Chaos Castle,
# Imperial Fortress, Doppelganger...), baixado na primeira vez que um deles aparece
const MONSTROS := 0
static var _prontos := {}
static var _tentados := {}
static var _baixando := {}


# mapa do servidor -> pasta World do cliente: o cliente soma 1, mas os 8 Blood Castle (11 a 17
# e o 52) usam o World12 e o Devil Square 5 a 7 (mapa 32) usa o World10 do 1 a 4
# (MapManager::Load do cliente: iMapWorld = WD_11BLOODCASTLE1 + 1)
static func mundo_do_mapa(mapa: int) -> int:
	if mapa in [11, 12, 13, 14, 15, 16, 17, 52]:
		return 12
	if mapa == 32:
		return 10
	if mapa in [18, 19, 20, 21, 22, 23, 53]:
		return 19
	# os 7 Kalimas usam a pasta World25 (iMapWorld = WD_24HELLAS + 1)
	if mapa in [24, 25, 26, 27, 28, 29, 36]:
		return 25
	# os 6 Illusion Temple (45 a 50) usam a pasta World47 (iMapWorld = WD_45CURSEDTEMPLE_LV1 + 2)
	if mapa in [45, 46, 47, 48, 49, 50]:
		return 47
	return mapa + 1


static func tem(numero: int) -> bool:
	return ResourceLoader.exists("res://dados/mundo%d/altura.png" % numero) or (OS.has_feature("web") and numero in FORA)


# PC exportado: monta todo .pck da pasta mapas/ do lado do exe (MU_PACOTES troca a pasta,
# pra testar com --main-pack build/windows/openmu.pck)
static func montar_pc() -> void:
	var pasta := OS.get_environment("MU_PACOTES")
	if pasta == "":
		if OS.has_feature("web") or not OS.has_feature("template"):
			return
		pasta = OS.get_executable_path().get_base_dir().path_join("mapas")
	var arqs := Array(DirAccess.get_files_at(pasta))
	arqs.sort()
	for a in arqs:
		if a.ends_with(".pck"):
			print("TESTE pacote %s %s" % [a, "ok" if ProjectSettings.load_resource_pack(pasta.path_join(a), false) else "falhou"])


static func precisa(numero: int) -> bool:
	return OS.has_feature("web") and numero in FORA and not _prontos.has(numero) \
		and not ResourceLoader.exists("res://dados/mundo%d/altura.png" % numero)


# o pacote dos monstros tambem e o numero 0, que e a Lorencia (vem no principal): o altura.png nao serve de prova
static func precisa_monstros() -> bool:
	return OS.has_feature("web") and not _prontos.has(MONSTROS)


# o modelo desse monstro so vem no pacote dos monstros (que nao foi tentado ou ainda esta baixando:
# quem aparece durante o download tambem espera; se o download falhou, fica o provisorio)
static func falta_monstro(numero: int) -> bool:
	var m: Array = Boneco.NPCS.get(numero, [])
	return not m.is_empty() and precisa_monstros() and (not _tentados.has(MONSTROS) or _baixando.has(MONSTROS)) \
		and not ResourceLoader.exists(Boneco.PASTA + m[0] + ".glb")


# por que o monstro nao tem modelo (log dos testes)
static func porque(numero: int) -> String:
	var m: Array = Boneco.NPCS.get(numero, [])
	return "modelo %s existe=%s pacote_pronto=%s tentado=%s altura0=%s" % [m[0] if not m.is_empty() else "-",
		ResourceLoader.exists(Boneco.PASTA + str(m[0]) + ".glb") if not m.is_empty() else false, _prontos.has(MONSTROS),
		_tentados.has(MONSTROS), ResourceLoader.exists("res://dados/mundo0/altura.png")]


static func carregar(pai: Node, numero: int) -> bool:
	if not (precisa_monstros() if numero == MONSTROS else precisa(numero)):
		return true
	_tentados[numero] = true
	_baixando[numero] = true
	var ok := await _baixar(pai, numero)
	_baixando.erase(numero)
	return ok


static func _baixar(pai: Node, numero: int) -> bool:
	var http := HTTPRequest.new()
	# o padrao le 64 KB por quadro: 21 MB num navegador lento passavam de um minuto
	http.download_chunk_size = 4 * 1024 * 1024
	pai.add_child(http)
	var base := str(JavaScriptBridge.eval("location.href")).get_slice("?", 0).get_base_dir()
	var destino := "user://mundo%d.pck" % numero
	http.request("%s/mapas/mundo%d.pck" % [base, numero])
	var r: Array = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		push_warning("mapa %d: %s %s" % [numero, r[0], r[1]])
		return false
	# no navegador o download_file do HTTPRequest nao grava: o corpo vai pro arquivo aqui
	var f := FileAccess.open(destino, FileAccess.WRITE)
	if f == null:
		push_warning("mapa %d: sem onde gravar (%s)" % [numero, FileAccess.get_open_error()])
		return false
	f.store_buffer(r[3])
	f.close()
	# sem trocar arquivo: o pacote traz project.binary e o cache de uid do projeto
	var ok := ProjectSettings.load_resource_pack(destino, false)
	if ok:
		_prontos[numero] = true
	print("TESTE pacote mapa %d %s" % [numero, "ok" if ok else "falhou"])
	return ok
