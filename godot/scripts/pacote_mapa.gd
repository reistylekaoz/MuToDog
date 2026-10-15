class_name PacoteMapa
extends RefCounted
# Mapas que no navegador nao vao no pck principal (cada um soma uns 8 MB): o export
# Web grava mapas/mundo<N>.pck do lado do index.html (testes/exportar_web.sh) e o
# jogo baixa so quando o personagem entra. No PC exportado (testes/exportar_windows.sh)
# esses mapas e os modelos dos itens vao em pacotes na pasta mapas/ do lado do openmu.exe
# (cada zip da entrega cabe nos 50 MB do app arquivos) e montar_pc() monta todos na
# partida. Nos testes headless os dados estao no projeto e nada e carregado.
# Uso: await PacoteMapa.carregar(no_qualquer, numero_do_mundo)

const FORA := [2, 3, 4, 5, 8, 9]
static var _prontos := {}


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


static func carregar(pai: Node, numero: int) -> bool:
	if not precisa(numero):
		return true
	var http := HTTPRequest.new()
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
