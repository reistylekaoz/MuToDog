extends SceneTree
# Efeitos do Fenrir sem tela (scripts/efeito_montaria.gd): soma as pecas vivas andando, correndo e parado.
# $G --headless --path . -s testes/montaria.gd   (pegadas "chao" so andando e correndo)
func _initialize() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	current_scene = raiz
	root.add_child(ModelosMU.new())
	var b := Boneco.novo("classe_dk")
	raiz.add_child(b)
	var m := Boneco.novo("montaria_fenrir_blue", 0.9)
	m.ritmo = Boneco.RITMO_MONTARIA["fenrir"]
	b.add_child(m)
	b.montaria = m
	b._jeito_montaria = "fenrir"
	EfeitoMontaria.ligar(m, "fenrir", "blue")
	b._montar()
	for i in 300:
		if b.montaria:
			break
		await process_frame
	printerr("TESTE montaria ", b.montaria)
	for acao in ["anda", "corre", "parado"]:
		b.tocar(acao)
		var conta := {}
		for i in 150:
			await process_frame
			for e in raiz.get_children():
				if e is EfeitoMU:
					for p in e.pecas:
						var k: String = "chao" if p.get("deitado", false) else ("modelo" if p.has("mats") else "sprite")
						conta[k] = conta.get(k, 0) + 1
		printerr("TESTE %s (soma de pecas vivas em 150 quadros): %s, acao montaria %s" % [acao, conta, b.montaria.acao])
	quit()
