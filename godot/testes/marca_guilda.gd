extends SceneTree
# Onde a marca da guilda fica no boneco (osso 26, o ombro direito): posicao dos ossos e da marca no corpo.
# Uso: $G --headless --path . --script res://testes/marca_guilda.gd
func _initialize() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var b := Boneco.da_classe(4)
	raiz.add_child(b)
	b.tocar("parado")
	var c := PackedByteArray()
	c.resize(64)
	c.fill(4)
	b.por_marca(Guildas.textura(c))
	await process_frame
	await process_frame
	var sk := b.esqueleto
	var inv := b.global_transform.affine_inverse() * sk.global_transform
	for n in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 20, 22, 26, 33, 42, 47]:
		var i := sk.find_bone("osso%d" % n)
		if i >= 0:
			print("osso%d (idx %d) em %s" % [n, i, inv * sk.get_bone_global_pose(i).origin])
	var mi: MeshInstance3D = b.find_child("marca_guilda", true, false)
	var g := b.global_transform.affine_inverse() * mi.global_transform
	print("marca em %s" % (g * mi.get_aabb().get_center()))
	quit()
