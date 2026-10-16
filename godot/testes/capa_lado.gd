extends SceneTree
# Onde a capa fica em relacao ao corpo, sem tela (o boneco olha pra -Z; atras = +Z):
# $G --headless --script res://testes/capa_lado.gd -- classe_dl 12,40 [giro em graus]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var b := Boneco.novo(a[0] if a.size() > 0 else "classe_dl")
	root.add_child(ModelosMU.new())
	root.add_child(b)
	b.rotation_degrees.y = float(a[2]) if a.size() > 2 else 0.0
	b.tocar("parado")
	await process_frame
	b.vestir({7: a[1] if a.size() > 1 else "13,30"})
	for i in 200:
		await process_frame
	var e := b.esqueleto
	print("TESTE basis esqueleto %s" % e.global_transform.basis)
	var peito := e.to_global(e.get_bone_global_pose(e.find_bone("osso17")).origin)
	print("TESTE peito %s; atras do boneco = %s" % [peito, b.global_transform.basis.z])
	for c in b._pecas[7].find_children("*", "Capa", true, false):
		var cp: Capa = c
		var u := cp._unidade()
		var meio := cp._p[cp._p.size() / 2] * u
		var fim := cp._p[cp._p.size() - 1] * u
		print("TESTE pano %s meio %s fim %s" % [cp._cfg[0], meio, fim])
	quit()
