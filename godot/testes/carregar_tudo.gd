extends SceneTree
# carrega todo script de scripts/ e diz quais nao compilam (erro de parse sai no log do Godot)
func _init() -> void:
	var ruins := 0
	for pasta in ["res://scripts/", "res://scripts/rede/"]:
		for f in DirAccess.get_files_at(pasta):
			if f.ends_with(".gd"):
				var s = load(pasta + f)
				if s == null or not (s as GDScript).can_instantiate():
					print("RUIM ", f)
					ruins += 1
	print("scripts ruins: %d" % ruins)
	quit()
