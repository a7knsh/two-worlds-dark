extends Node
## Dev tool: times the procedural asset generation.

func _ready() -> void:
	var t := Time.get_ticks_msec()
	Tex.world_materials()
	print("world textures: %d ms" % (Time.get_ticks_msec() - t))
	t = Time.get_ticks_msec()
	for k in ["leather", "cloth", "metal", "skin"]:
		Tex.detail(k)
	print("detail textures: %d ms" % (Time.get_ticks_msec() - t))
	for b: Array in [["hunter", "", 1.0, ""], ["husk", "rusty_blade", 1.0, ""], ["brute", "great_club", 1.3, ""], ["warden", "warden_sword", 2.2, ""], ["keeper", "cane", 1.0, ""]]:
		t = Time.get_ticks_msec()
		var h := Humanoid.create(b[0], b[1], b[2], b[3])
		h.free()
		print("%s sheet: %d ms" % [b[0], Time.get_ticks_msec() - t])
	get_tree().quit()
