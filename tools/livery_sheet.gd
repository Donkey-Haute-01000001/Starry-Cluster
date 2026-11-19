extends SceneTree
## Renders every ship sprite in every livery to a contact sheet.
## xvfb-run godot --rendering-driver opengl3 -s tools/livery_sheet.gd -- --out=PATH

var _out := "user://livery_sheet.png"


class Cell extends Node2D:
	var rel := ""
	func _draw() -> void:
		Art.draw_fit(self, rel, 92.0)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	var data = load("res://scripts/data.gd").new()
	var ships := ["crossbow", "bison", "pointbreak", "hull", "northstar", "endra", "mjolnir_mark_v", "trident"]
	var facs := ["", "charter", "navy", "pirate", "tally", "dynasty", "karabey", "league", "faithful", "nomad"]
	root.size = Vector2i(110 * facs.size() + 20, 104 * ships.size() + 40)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07)
	bg.size = Vector2(root.size)
	root.add_child.call_deferred(bg)
	for j in facs.size():
		var l := Label.new()
		l.text = facs[j] if facs[j] != "" else "original"
		l.position = Vector2(20 + j * 110, 6)
		root.add_child.call_deferred(l)
		for i in ships.size():
			var c := Cell.new()
			c.rel = "ships/%s.png" % ships[i]
			c.position = Vector2(70 + j * 110, 84 + i * 104)
			c.rotation = -PI / 2
			c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if facs[j] != "":
				c.material = Art.livery(data.liveries[facs[j]], i, Art.main_hue(c.rel))
			root.add_child.call_deferred(c)
	_snap.call_deferred()


func _snap() -> void:
	for k in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out)
	quit()
