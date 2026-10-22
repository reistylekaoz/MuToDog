extends Control
# Launcher do MU estudo no PC. A cada abertura:
# 1. le https://<SITE>/jogo/pc/versao.json (o que esta no ar: arquivo, tamanho, sha256);
# 2. baixa pra pasta jogo/ (do lado do exe) so o que falta ou mudou, e apaga pacote velho;
# 3. abre o mesmo exe com --main-pack jogo/jogo.pck, com MU_SITE e MU_CHAVE no ambiente
#    (o jogo conecta no OpenMU do site pelo WebSocket, igual ao navegador).
# Sem internet e com uma versao baixada, abre a que tem.
# A chave (chave.txt, fora do git) entra no export; o site confere pelo sha256 (mu-estudo/web/auth.php).
# Teste no Linux: MU_LAUNCHER_PASTA=<pasta> godot --path launcher (MU_LAUNCHER_NAO_ABRIR=1 so baixa).

const SITE := "mu-estudo.integraction.com.br"
const VERSAO_LAUNCHER := 1

var chave := ""
var pasta := ""
var titulo: Label
var estado: Label
var barra: ProgressBar
var detalhe: Label
var botao: Button
var http: HTTPRequest
var _baixando := ""
var _feito := 0
var _total := 0


func _ready() -> void:
	chave = FileAccess.get_file_as_string("res://chave.txt").strip_edges()
	pasta = OS.get_environment("MU_LAUNCHER_PASTA")
	if pasta == "":
		pasta = OS.get_executable_path().get_base_dir().path_join("jogo")
	_montar_tela()
	http = HTTPRequest.new()
	http.download_chunk_size = 1 << 18
	http.timeout = 60
	add_child(http)
	_atualizar()


func _montar_tela() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 32)
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	titulo = Label.new()
	titulo.text = "MU Estudo"
	titulo.add_theme_font_size_override("font_size", 30)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	v.add_child(titulo)
	estado = Label.new()
	estado.add_theme_font_size_override("font_size", 17)
	estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(estado)
	barra = ProgressBar.new()
	barra.custom_minimum_size = Vector2(0, 22)
	barra.show_percentage = true
	v.add_child(barra)
	detalhe = Label.new()
	detalhe.add_theme_color_override("font_color", Color(0.6, 0.6, 0.68))
	detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(detalhe)
	botao = Button.new()
	botao.text = "Tentar de novo"
	botao.custom_minimum_size = Vector2(180, 36)
	botao.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	botao.visible = false
	botao.pressed.connect(func():
		botao.visible = false
		_atualizar())
	v.add_child(botao)


func _process(_d: float) -> void:
	if _baixando != "" and _total > 0:
		barra.value = 100.0 * (_feito + http.get_downloaded_bytes()) / _total
		detalhe.text = "%s · %s de %s" % [_baixando, _mb(_feito + http.get_downloaded_bytes()), _mb(_total)]


func _mb(b: int) -> String:
	return "%.1f MB" % (b / 1048576.0)


func _url(nome: String) -> String:
	return "https://%s/jogo/pc/%s" % [SITE, nome]


func _cabecalho() -> PackedStringArray:
	return PackedStringArray(["X-Mu-Chave: " + chave, "Cache-Control: no-cache"])


func _atualizar() -> void:
	estado.text = "Procurando atualização..."
	barra.value = 0
	detalhe.text = ""
	DirAccess.make_dir_recursive_absolute(pasta.path_join("mapas"))
	var local := _ler_json(pasta.path_join("versao.json"))
	http.download_file = ""
	http.request(_url("versao.json?t=%d" % Time.get_unix_time_from_system()), _cabecalho())
	var r: Array = await http.request_completed
	var no_ar = null
	if r[0] == HTTPRequest.RESULT_SUCCESS and r[1] == 200:
		no_ar = JSON.parse_string(r[3].get_string_from_utf8())
	if not no_ar is Dictionary:
		var motivo := "sem internet" if r[0] != HTTPRequest.RESULT_SUCCESS else "o site respondeu %d" % r[1]
		if FileAccess.file_exists(pasta.path_join("jogo.pck")):
			estado.text = "Não deu pra procurar atualização (%s). Abrindo a versão que já está aqui." % motivo
			await get_tree().create_timer(2.5).timeout
			_abrir()
		else:
			_falhou("Não deu pra baixar o jogo (%s)." % motivo)
		return
	var baixar := []
	var antes := {}
	for a in local.get("arquivos", []):
		antes[a.nome] = a.sha256
	var nomes := {}
	_total = 0
	for a in no_ar.get("arquivos", []):
		nomes[a.nome] = true
		var arq: String = pasta.path_join(a.nome)
		if antes.get(a.nome, "") != a.sha256 or not FileAccess.file_exists(arq) \
				or FileAccess.get_size(arq) != int(a.tam):
			baixar.append(a)
			_total += int(a.tam)
	# pacote que saiu do ar (mapa juntado, modelo trocado) sai daqui tambem
	for a in DirAccess.get_files_at(pasta.path_join("mapas")):
		if not nomes.has("mapas/" + a):
			DirAccess.remove_absolute(pasta.path_join("mapas").path_join(a))
	_feito = 0
	for i in baixar.size():
		var a: Dictionary = baixar[i]
		estado.text = "Atualizando pra versão %s (%d de %d)" % [no_ar.get("versao", "?"), i + 1, baixar.size()]
		var destino: String = pasta.path_join(a.nome)
		var parte := destino + ".parte"
		http.download_file = parte
		_baixando = a.nome
		http.request(_url(a.nome), _cabecalho())
		r = await http.request_completed
		_baixando = ""
		http.download_file = ""
		if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200 or FileAccess.get_sha256(parte) != a.sha256:
			DirAccess.remove_absolute(parte)
			_falhou("O download de %s falhou (%s, %s). O que já baixou fica guardado." % [a.nome, r[0], r[1]])
			_gravar_versao(no_ar, local, antes, baixar.slice(0, i))
			return
		DirAccess.remove_absolute(destino)
		DirAccess.rename_absolute(parte, destino)
		_feito += int(a.tam)
	_gravar_versao(no_ar, local, antes, baixar)
	barra.value = 100
	estado.text = "Versão %s pronta." % no_ar.get("versao", "?")
	detalhe.text = "Nada novo pra baixar." if baixar.is_empty() else "Baixou %d arquivo(s), %s." % [baixar.size(), _mb(_total)]
	if int(no_ar.get("launcher", VERSAO_LAUNCHER)) > VERSAO_LAUNCHER:
		detalhe.text += " Tem um launcher novo no app arquivos (este segue funcionando)."
		await get_tree().create_timer(3.0).timeout
	_abrir()


# grava o que esta no disco: o que ja tinha e continua igual + o que baixou agora
func _gravar_versao(no_ar: Dictionary, _local: Dictionary, antes: Dictionary, baixados: Array) -> void:
	var novos := {}
	for a in baixados:
		novos[a.nome] = true
	var lista := []
	for a in no_ar.get("arquivos", []):
		if novos.has(a.nome) or antes.get(a.nome, "") == a.sha256:
			lista.append(a)
	var f := FileAccess.open(pasta.path_join("versao.json"), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"versao": no_ar.get("versao", ""), "arquivos": lista}, "\t"))


func _ler_json(arq: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(arq)) if FileAccess.file_exists(arq) else null
	return d if d is Dictionary else {}


func _falhou(texto: String) -> void:
	estado.text = texto
	detalhe.text = "Confira a internet e clique em Tentar de novo."
	botao.visible = true


func _abrir() -> void:
	if OS.get_environment("MU_LAUNCHER_NAO_ABRIR") != "":
		print("TESTE launcher pronto")
		get_tree().quit()
		return
	OS.set_environment("MU_SITE", SITE)
	OS.set_environment("MU_CHAVE", chave)
	OS.set_environment("MU_PACOTES", pasta.path_join("mapas"))
	var pid := OS.create_process(OS.get_executable_path(), ["--main-pack", pasta.path_join("jogo.pck")])
	if pid <= 0:
		_falhou("Não consegui abrir o jogo.")
		return
	get_tree().quit()
