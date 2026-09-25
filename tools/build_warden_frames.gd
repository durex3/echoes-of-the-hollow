extends SceneTree
## One-time authored frame map. Source image and ordinary armor remain untouched.

func _initialize() -> void:
	var destination := "res://features/enemies/warden_frames.tres"
	if ResourceLoader.exists(destination):
		push_error("Warden frames exist; edit the native resource.")
		quit(1)
		return
	var source := load("res://assets/characters/living_armor.png") as Texture2D
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var clips := {
		"idle": [range(0,14),10.0,true],
		"walk": [range(24,32),10.0,true],
		"windup": [range(34,42),12.0,false],
		"strike": [range(42,45),12.0,false],
		"recover": [range(45,49),6.0,false],
		"death": [range(58,68),18.0,false]
	}
	for name: String in clips:
		var settings: Array = clips[name]
		frames.add_animation(name)
		frames.set_animation_speed(name,settings[1])
		frames.set_animation_loop(name,settings[2])
		for index: int in settings[0]:
			var texture := AtlasTexture.new()
			texture.atlas = source
			texture.region = Rect2((index%10)*64,(index/10)*64,64,64)
			frames.add_frame(name,texture)
	var result := ResourceSaver.save(frames,destination)
	print("WARDEN_FRAMES_CREATED" if result == OK else "WARDEN_FRAMES_FAILED")
	quit(0 if result == OK else 1)
