extends SceneTree
# Twisting Slash: a copia da arma deitada como no RenderWheelWeapon (Angle[1] = 90, giro no eixo de cima, no cabo).
# Carrega armas de verdade, monta como o _giro do efeito_skill e mede a lamina no mundo: tem que ficar deitada
# (quase sem altura) e girar no cabo. Mostra tambem a montagem antiga, que deixava a lamina em pe.
# Uso: $G --headless --path . --script res://testes/giro_espada.gd   (termina com "falhas: 0")

var falhas := 0


func confere(nome: String, ok: bool) -> void:
	print(("  ok    " if ok else "  FALHA ") + nome)
	if not ok:
		falhas += 1


# a lamina: a maior medida da caixa da malha (como o RastroArma), em coordenadas do no da arma
func _lamina(arma: Node3D) -> Array:
	var caixa := AABB()
	var primeiro := true
	for mi: MeshInstance3D in arma.find_children("*", "MeshInstance3D", true, false):
		var c := (arma.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		caixa = c if primeiro else caixa.merge(c)
		primeiro = false
	var eixo := caixa.get_longest_axis_index()
	var a := caixa.get_center()
	var b := a
	a[eixo] = caixa.position[eixo]
	b[eixo] = caixa.end[eixo]
	return [b, a] if a.length() > b.length() else [a, b]


func _montar(arma: Node3D, novo: bool, giro: float) -> Node3D:
	var raiz := Node3D.new()
	var suporte := Node3D.new()
	suporte.add_child(arma)
	suporte.rotation_degrees = Vector3(-90, 0, 0) if novo else Vector3(-90, 180, 0)
	suporte.scale = Vector3.ONE * 0.01
	raiz.add_child(suporte)
	var base := Basis(Vector3.BACK, -PI / 2) if novo else Basis(Vector3.RIGHT, PI / 2)
	raiz.basis = Basis(Vector3.UP, giro) * base
	root.add_child(raiz)
	return raiz


func _initialize() -> void:
	root.add_child(ModelosMU.new())
	await process_frame
	for chave in ["0,1", "0,5", "0,13", "0,18", "3,7"]:
		var m: Node3D = await ModelosMU.eu.instanciar(chave)
		if m == null:
			print("  sem modelo ", chave)
			continue
		for novo in [false, true]:
			var alturas := []
			var dirs := []
			for g in [0.0, 1.0, 2.0]:
				var arma: Node3D = m.duplicate()
				var raiz := _montar(arma, novo, g)
				var l := _lamina(arma)
				var p0: Vector3 = arma.global_transform * l[0]
				var p1: Vector3 = arma.global_transform * l[1]
				var d := (p1 - p0)
				alturas.append(absf(d.y) / d.length())
				dirs.append(Vector2(d.x, d.z).angle())
				raiz.free()
			var deitada: bool = alturas.max() < 0.25
			print("    %s %s: altura da lamina / comprimento %s, direcao no chao %s graus" % [chave, "novo" if novo else "antigo",
				alturas.map(func(x): return snappedf(x, 0.01)), dirs.map(func(x): return roundi(rad_to_deg(x)))])
			if novo:
				confere("%s deitada em todo giro" % chave, deitada)
				var passo := wrapf(dirs[1] - dirs[0], -PI, PI)
				confere("%s gira 1 rad por 1 rad de giro (no eixo de cima)" % chave, absf(absf(passo) - 1.0) < 0.05)
		m.free()
	print("falhas: %d" % falhas)
	quit(falhas)
