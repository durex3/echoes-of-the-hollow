extends Node
## Presentation-only service; gameplay never waits for an audio event.

var music: AudioStreamPlayer
var current_track := ""
var muted := false

func _ready() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.volume_db = -16.0
	add_child(music)
	Session.settings_changed.connect(apply_settings)
	apply_settings()

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, Session.music_volume)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), Session.music_volume == 0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, Session.sfx_volume)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), Session.sfx_volume == 0)

func play_sound(sound: String, pitch := 1.0, gain := 0.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var path := "res://assets/audio/%s.wav" % sound
	if not ResourceLoader.exists(path):
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = load(path) as AudioStream
	voice.bus = "SFX"
	voice.volume_db = -10.0 + gain
	voice.pitch_scale = pitch
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func play_music(track: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if track == current_track:
		return
	current_track = track
	music.stop()
	var stream := load("res://assets/audio/%s.ogg" % track) as AudioStreamOggVorbis
	stream.loop = true
	music.stream = stream
	music.play()

func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)

func stop_all() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null

func _exit_tree() -> void:
	stop_all()
