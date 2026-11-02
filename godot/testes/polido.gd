extends SceneTree
# Luz nova no jogo (Polido, Option > New lighting): liga sozinha nos mapas a ceu aberto, nunca troca
# efeito somado nem agua, e desligar volta shader, malha do chao, Environment e sol do jeito do cliente.
# Uso: $G --headless --path . --script res://testes/polido.gd   (termina com "falhas: 0")
# Mexe em user://opcoes.cfg e devolve o que estava la no fim.

var falhas := 0


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


func _shaders(m: Node3D) -> Dictionary:
	var n := {}
	for mat: ShaderMaterial in m.materiais.values():
		var k := mat.shader.resource_path.get_file() if mat.shader else "?"
		n[k] = n.get(k, 0) + 1
	return n


func _terreno(m: Node3D) -> String:
	var t := m.mu.get_node("Terreno") as MeshInstance3D
	return (t.material_override as ShaderMaterial).shader.resource_path.get_file()


func _mundo(numero: int) -> Node3D:
	var m := Node3D.new()
	m.set_script(load("res://scripts/mundo.gd"))
	m.modo_jogo = true
	m.numero = numero
	root.add_child(m)
	await process_frame
	await process_frame
	return m


func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	var antes := FileAccess.get_file_as_bytes(Polido.ARQ) if FileAccess.file_exists(Polido.ARQ) else PackedByteArray()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Polido.ARQ))
	confere("sem opcao guardada: ligada fora do navegador", Polido.opcao())

	var m := await _mundo(1)
	var n := _shaders(m)
	print("  Lorencia: ", n, " chao ", _terreno(m))
	confere("Lorencia: objetos no shader polido", n.get("objeto_polido.gdshader", 0) > 50)
	confere("Lorencia: nenhum objeto comum sobrou", n.get("objeto.gdshader", 0) == 0)
	confere("Lorencia: chao polido", _terreno(m) == "terreno_polido.gdshader")
	var sol := m.find_children("*", "DirectionalLight3D", false, false)[0] as DirectionalLight3D
	confere("Lorencia: sol com sombra", sol.shadow_enabled)
	var fundo: Color = m.get_node("WorldEnvironment").environment.background_color

	Polido.trocar(m, false)
	n = _shaders(m)
	confere("desligar: objetos de volta", n.get("objeto_polido.gdshader", 0) == 0 and n.get("objeto.gdshader", 0) > 50)
	confere("desligar: chao de volta", _terreno(m) == "terreno.gdshader")
	confere("desligar: sol sem sombra e na energia de antes", not sol.shadow_enabled and is_equal_approx(sol.light_energy, 0.8))
	var env: Environment = m.get_node("WorldEnvironment").environment
	confere("desligar: ambiente de volta", is_equal_approx(env.ambient_light_energy, 0.9) and not env.glow_enabled)
	confere("desligar: guardou no opcoes.cfg", not Polido.opcao())
	Polido.trocar(m, true)
	confere("ligar de novo: polido", _terreno(m) == "terreno_polido.gdshader" and _shaders(m).get("objeto_polido.gdshader", 0) > 50)
	confere("o fundo do mapa nao muda no jogo", env.background_color == fundo)
	m.queue_free()

	var d := await _mundo(2)
	confere("Dungeon (fechado): fica como o cliente", _terreno(d) == "terreno.gdshader" and _shaders(d).get("objeto_polido.gdshader", 0) == 0)
	d.queue_free()

	Polido.guardar_opcao(false)
	var dv := await _mundo(3)
	var outros := _shaders(dv)
	outros.erase("objeto.gdshader")
	Polido.trocar(dv, true)
	var depois := _shaders(dv)
	depois.erase("objeto_polido.gdshader")
	print("  Devias, fora o objeto comum: ", outros)
	confere("Devias: efeito, agua e o resto seguem com o shader deles", outros == depois)
	confere("Devias: ligou", _terreno(dv) == "terreno_polido.gdshader")
	dv.queue_free()

	Polido.guardar_opcao(false)
	var l := await _mundo(1)
	confere("opcao desligada: Lorencia abre como o cliente", _terreno(l) == "terreno.gdshader")
	l.queue_free()

	if antes.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Polido.ARQ))
	else:
		var f := FileAccess.open(Polido.ARQ, FileAccess.WRITE)
		f.store_buffer(antes)
		f.close()
	print("falhas: %d" % falhas)
	quit(1 if falhas else 0)
