extends Node
# Fica no exe do launcher e quase nunca muda: baixa o launcher.pck do site (se o sha256 do
# versao.json mudou), monta ele por cima do que veio no exe e abre o launcher.tscn dele.
# Sem internet usa o launcher.pck que ja tem; sem nenhum, o launcher que veio no exe.

const SITE := "mu-estudo.integraction.com.br"


func _ready() -> void:
	var pasta := OS.get_environment("MU_LAUNCHER_PASTA")
	if pasta == "":
		pasta = OS.get_executable_path().get_base_dir().path_join("jogo")
	DirAccess.make_dir_recursive_absolute(pasta)
	var pck := pasta.path_join("launcher.pck")
	var chave := FileAccess.get_file_as_string("res://chave.txt").strip_edges()
	var cab := PackedStringArray(["X-Mu-Chave: " + chave, "Cache-Control: no-cache"])
	var http := HTTPRequest.new()
	http.timeout = 20
	add_child(http)
	http.request("https://%s/jogo/pc/versao.json?t=%d" % [SITE, Time.get_unix_time_from_system()], cab)
	var r: Array = await http.request_completed
	var no_ar = JSON.parse_string(r[3].get_string_from_utf8()) if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200 else null
	if no_ar is Dictionary:
		for a in no_ar.get("arquivos", []):
			if a.nome == "launcher.pck" and (not FileAccess.file_exists(pck) or FileAccess.get_sha256(pck) != a.sha256):
				http.download_file = pck + ".parte"
				http.request("https://%s/jogo/pc/launcher.pck" % SITE, cab)
				r = await http.request_completed
				if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200 and FileAccess.get_sha256(pck + ".parte") == a.sha256:
					DirAccess.remove_absolute(pck)
					DirAccess.rename_absolute(pck + ".parte", pck)
				else:
					DirAccess.remove_absolute(pck + ".parte")
	if FileAccess.file_exists(pck):
		print("TESTE boot launcher.pck %s" % ("ok" if ProjectSettings.load_resource_pack(pck, true) else "falhou"))
	get_tree().change_scene_to_file.call_deferred("res://launcher.tscn")
