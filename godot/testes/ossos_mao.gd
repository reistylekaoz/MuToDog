extends SceneTree
# Onde ficam as maos (ossos 33 e 42) e as armas de cada slot no mundo, sem tela:
# $G --headless --script res://testes/ossos_mao.gd -- classe_dk "0=0,5;1=0,5"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var b := Boneco.novo(a[0] if a.size() > 0 else "classe_dk")
	root.add_child(ModelosMU.new())
	root.add_child(b)
	b.tocar("parado")
	await process_frame
	var eq := {}
	if a.size() > 1:
		for par in a[1].split(";", false):
			eq[int(par.get_slice("=", 0))] = par.get_slice("=", 1)
	b.vestir(eq)
	for i in 300:
		await process_frame
	var e := b.esqueleto
	for o in ["osso33", "osso42", "osso47"]:
		var p := e.to_global(e.get_bone_global_pose(e.find_bone(o)).origin)
		# x > 0 = lado direito do boneco (ele olha pra -Z; a direita dele e +X)
		print("TESTE %s %s" % [o, p])
	for s in [0, 1]:
		if b._pecas.has(s):
			var at: BoneAttachment3D = b._pecas[s]
			var arma: Node3D = at.get_child(0).get_child(0)
			var aabb := AABB()
			for m: MeshInstance3D in arma.find_children("*", "MeshInstance3D", true, false):
				aabb = aabb.merge(m.global_transform * m.get_aabb()) if aabb.size != Vector3.ZERO else m.global_transform * m.get_aabb()
			print("TESTE slot %d %s osso %s centro %s" % [s, b._equip[s], at.bone_name, aabb.get_center()])
	quit()
