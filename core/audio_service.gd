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

func play_sound(sound: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var path := "res://assets/audio/%s.wav" % sound
	if not ResourceLoader.exists(path):
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = load(path) as AudioStream
	voice.bus = "SFX"
	voice.volume_db = -10.0
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
