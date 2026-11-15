extends SceneTree

## One-shot tool: rasterize assets/drawables/icon.svg -> icon.png (192x192)
## for the Android launcher icon (export preset references res://icon.png).
## Run AFTER --import:
##   godot --headless --path . --script tools/gen_icon.gd

func _init():
	var tex: Texture2D = load("res://assets/drawables/icon.svg")
	if tex == null:
		printerr("ICON FAIL: cannot load icon.svg")
		quit(1)
		return
	var img: Image = tex.get_image()
	img.resize(192, 192, Image.INTERPOLATE_LANCZOS)
	var err = img.save_png("res://icon.png")
	if err != OK:
		printerr("ICON FAIL: save_png err=%d" % err)
		quit(1)
		return
	print("ICON OK: icon.png 192x192")
	quit(0)
