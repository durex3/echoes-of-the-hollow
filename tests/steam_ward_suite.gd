extends Node
## Real input, physics overlap, pause lifecycle and isolated persistence contracts.

func key(code: Key, down := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	return event

func run(h: Node, game: Node) -> void:
	var player: Player = game.player
	var ward: SteamWard = player.steam_ward
	Session.flags.erase("cistern_restored")
	Session.abilities.erase("steam_ward")
	game.load_room("echo_vault","checkpoint")
	player.revive(Vector2(180,608))
	await h.frames(4)
	await h.press("steam_ward",2)
	h.check(ward.active_left == 0 and not game.ui.ward_label.visible, "Locked ward cannot activate and hides its HUD row")
	Session.unlock("steam_ward")
	Input.parse_input_event(key(KEY_L))
	await h.frames(3)
	Input.parse_input_event(key(KEY_L,false))
	h.check(ward.active_left > 1.4 and ward.cooldown_left > 4.9 and player.health.invulnerability_left == 0, "Physical L activates 1.5 second ward with five second cooldown and no invulnerability")
	var active := ward.active_left
	var cooldown := ward.cooldown_left
	get_tree().paused = true
	await h.frames(8)
	h.check(ward.active_left == active and ward.cooldown_left == cooldown, "Pause freezes both ward timers")
	game.resume()
	await h.frames(92)
	h.check(ward.active_left == 0 and ward.cooldown_left > 3.2 and not ward.absorb(), "Unused ward expires after 1.5 seconds while activation cooldown continues")
	await h.press("steam_ward",2)
	h.check(ward.active_left == 0, "Cooldown rejects another activation")
	await h.frames(210)
	Input.action_press("steam_ward")
	await h.frames(308)
	h.check(ward.active_left == 0 and ward.cooldown_left == 0, "Holding ward beyond cooldown never repeatedly activates it")
	Input.action_release("steam_ward")
	await h.frames(2)
	await h.press("steam_ward",2)
	h.check(ward.active_left > 0, "Fresh press after cooldown activates again")
	cooldown = ward.cooldown_left
	game.load_room("ember_quay","checkpoint")
	h.check(ward.active_left == 0 and ward.cooldown_left == cooldown, "Room transition cancels charge without resetting cooldown")
	game.load_room("echo_vault","checkpoint")
	player.revive(Vector2(180,608))
	get_tree().paused = true
	Input.action_press("steam_ward")
	game.resume()
	await h.frames(3)
	h.check(ward.active_left == 0, "Held menu input cannot activate ward on resume")
	Input.action_release("steam_ward")
	await h.frames(2)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	pad.pressed = true
	Input.parse_input_event(pad)
	await h.frames(3)
	pad.pressed = false
	Input.parse_input_event(pad)
	h.check(ward.active_left > 0 and game.ui.ward_label.text.contains("LB / L1"), "Mapped shoulder button activates ward and updates device hint")
	ward.cancel(true)
	# Old L/LB rebinds keep their original actions and receive unused ward defaults.
	var legacy := ConfigFile.new()
	legacy.set_value("meta","version",1)
	legacy.set_value("input","bindings",{"jump":{"key":KEY_L},"attack":{"button":JOY_BUTTON_LEFT_SHOULDER}})
	h.check(SettingsRepository.valid(legacy), "Legacy settings using new default keys are still valid")
	Session.bindings.apply(legacy.get_value("input","bindings"))
	h.check(Session.bindings.hint("jump",false) == "L" and Session.bindings.hint("attack",true) == "LB / L1" and Session.bindings.hint("steam_ward",false) != "L" and Session.bindings.hint("steam_ward",true) != "LB / L1", "Legacy input migration preserves both old bindings and assigns free ward controls")
	h.check(Session.save_settings() == OK, "Migrated settings persist without input conflicts")
	Session.load_settings()
	h.check(Session.bindings.hint("jump",false) == "L", "Reload retains legacy controls after migration")
	Session.bindings.apply({})
	h.check(Session.bindings.rebind("steam_ward",key(KEY_U)).is_empty(), "Ward supports standard input rebinding")
	Session.bindings.observe(key(KEY_U))
	Input.parse_input_event(key(KEY_L))
	await h.frames(2)
	Input.parse_input_event(key(KEY_L,false))
	h.check(ward.active_left == 0, "Previous key no longer activates rebound ward")
	Input.parse_input_event(key(KEY_U))
	await h.frames(2)
	Input.parse_input_event(key(KEY_U,false))
	h.check(ward.active_left > 0 and game.ui.ward_label.text.begins_with("U /"), "Rebound physical key and ward HUD agree")
	Session.bindings.apply({})
	ward.cancel(true)
	await h.frames(2)
	# Native Area2D tests use the same SteamVent scene as authored rooms.
	var vent := preload("res://features/world/steam_vent.tscn").instantiate() as SteamVent
	game.room.add_child(vent)
	vent.position = Vector2(180,608)
	player.revive(vent.position)
	await h.frames(3)
	await h.press("steam_ward",2)
	h.check(ward.active_left > 0 and player.health.current == player.health.maximum, "Resting vent never consumes ward")
	vent.phase = SteamVent.Phase.WARNING
	vent.elapsed = 0
	await h.frames(3)
	h.check(ward.active_left > 0, "Warning vent never consumes ward")
	Session.set_language("zh_CN")
	await h.frames(2)
	await h.shot("91_ward_active_zh")
	vent.phase = SteamVent.Phase.ACTIVE
	vent.elapsed = 0
	await h.frames(2)
	h.check(ward.active_left == 0 and ward.feedback_left > 0 and player.health.current == player.health.maximum and player.health.invulnerability_left == 0, "Actual steam overlap consumes charge and deals no damage or global invulnerability")
	await h.shot("92_ward_blocked_zh")
	await h.frames(40)
	h.check(player.health.current == player.health.maximum, "Remaining ticks of the same plume cannot immediately damage protected player")
	# A different emitter remains dangerous during the same active plume.
	var other := preload("res://features/world/steam_vent.tscn").instantiate() as SteamVent
	game.room.add_child(other)
	other.position = vent.position
	other.phase = SteamVent.Phase.ACTIVE
	await h.frames(4)
	h.check(player.health.current == player.health.maximum-1, "Consumed ward does not protect against a second vent")
	other.queue_free()
	await h.frames(20)
	h.check(vent.protected_ids.is_empty(), "Vent phase transition clears protection for the next cycle")
	player.revive(vent.position)
	vent.phase = SteamVent.Phase.ACTIVE
	vent.elapsed = 0
	await h.frames(3)
	h.check(player.health.current == player.health.maximum-1, "Next plume damages an uncharged player normally")
	vent.deactivate()
	player.revive(vent.position)
	ward.activate()
	await h.frames(3)
	h.check(ward.active_left > 0 and player.health.current == player.health.maximum, "Disabled vents do not consume charge or hurt player")
	vent.enabled = true
	vent.phase = SteamVent.Phase.ACTIVE
	vent.elapsed = 0
	player.health.invulnerability_left = 0.5
	await h.frames(3)
	h.check(ward.active_left > 0, "Existing damage invulnerability does not waste a ward charge")
	vent.deactivate()
	player.health.invulnerability_left = 0
	var hit := (player.get_node("Hurtbox") as Hurtbox).receive_hit(1,player.position+Vector2(20,0))
	h.check(not hit and ward.active_left == 0 and player.health.current == player.health.maximum, "Enemy hurtbox damage consumes ward without health loss or hurt reaction")
	player.health.invulnerability_left = 0
	player.health.take_damage(99,player.position)
	h.check(ward.active_left == 0, "Death cancels ward immediately")
	await h.frames(65)
	h.check(ward.cooldown_left == 0 and ward.active_left == 0, "Checkpoint revival restores a ready inactive ward")
	# New acquisition, failure feedback and shrine retry all use real interaction wiring.
	Session.abilities.erase("steam_ward")
	Session.flags.erase("cistern_heart")
	game.load_room("echo_vault","checkpoint")
	player.revive(Vector2(755,320))
	player.health.current -= 2
	var max_hp := Session.maximum_health()
	var save_path: String = Session.save_path
	Session.save_path = "user://missing_ward_test_directory/save.json"
	await h.frames(3)
	await h.press("interact",2)
	h.check("steam_ward" in Session.abilities and player.health.current == max_hp and Session.maximum_health() == max_hp and "cistern_heart" not in Session.flags, "New reward heals without granting legacy vitality")
	h.check(not game.ui.reward_notice.save_succeeded and not game.room.get_node("Interactions/Heart").visible, "Failed save keeps earned skill in session, hides reward and reports failure")
	Session.save_path = save_path
	game._on_interaction(game.room.get_node("Interactions/Shrine"))
	h.check(Session.restore() and "steam_ward" in Session.abilities, "Shrine retry persists skill after initial save failure")
	game.ui.reward_notice.present("steam_ward",true)
	await h.frames(3)
	h.check(not game.ui.reward_notice.get_global_rect().intersects(game.ui.ward_label.get_global_rect()), "Reward card leaves the unlocked skill status row unobstructed")
	await h.shot("93_ward_reward_zh")
	Session.set_language("en")
	Session.bindings.gamepad = true
	Session.bindings.changed.emit()
	await h.frames(3)
	h.check(game.ui.reward_notice.detail_label.text.contains("LB / L1") and game.ui.ward_label.get_minimum_size().x < 600, "English reward and HUD fit gamepad controls")
	await h.shot("94_ward_reward_en_pad")
	game.ui.reward_notice.remaining = 0
	await h.press("steam_ward",2)
	await h.frames(95)
	h.check(ward.cooldown_left > 0 and ward.active_left == 0 and game.ui.ward_label.text.contains("%ds" % ceili(ward.cooldown_left)), "HUD displays remaining cooldown from actual timer")
	await h.shot("95_ward_cooldown_en")
	get_tree().paused = true
	game.ui.show_menu("pause")
	(game.ui.menu.get_node("SettingsButton") as Button).pressed.emit()
	await h.frames(2)
	game.ui.settings_panel.binding_buttons["steam_ward"].grab_focus()
	await h.frames(3)
	h.check(game.ui.settings_panel.binding_buttons.has("steam_ward"), "Settings exposes a focusable skill binding row")
	await h.shot("96_ward_settings")
	game.ui.settings_panel.close()
	game.resume()
	var old := Session.snapshot()
	old.abilities.erase("steam_ward")
	old.flags.append("cistern_heart")
	var migrated: Dictionary = SaveRepository.migrate(old)
	h.check("steam_ward" not in old.abilities and migrated.abilities.count("steam_ward") == 1 and "cistern_heart" in migrated.flags and SaveRepository.migrate(migrated) == migrated, "Legacy heart migration is additive, pure and idempotent")
	h.check(SaveRepository.write(Session.save_path,old) == OK and Session.restore() and Session.maximum_health() == max_hp+1 and "steam_ward" in Session.abilities, "Valid legacy save restores earned HP and adds skill")
	game.load_room("echo_vault","checkpoint")
	h.check(not game.room.get_node("Interactions/Heart").visible, "Migrated legacy reward cannot be collected twice")
	old.version = 999
	h.check("steam_ward" not in SaveRepository.migrate(old).abilities, "Future save is never migrated into a skill grant")
	old.version = 2
	old.checkpoint_room = "invalid"
	h.check("steam_ward" not in SaveRepository.migrate(old).abilities, "Invalid save is never migrated into a skill grant")
	Session.flags.erase("cistern_heart")
	Session.bindings.apply({})
	Session.bindings.observe(key(KEY_A))
	Session.set_language("en")
	player.revive(Vector2(180,608))
	await h.frames(3)
	await combat_blocks(h,game)

func combat_blocks(h: Node, game: Node) -> void:
	var player: Player = game.player
	var ward: SteamWard = player.steam_ward
	var hurt := player.get_node("Hurtbox") as Hurtbox
	var events := {"blocked":0,"damaged":0,"impact":0}
	var on_block := func() -> void: events.blocked += 1
	var on_damage := func(_amount: int, _origin: Vector2) -> void: events.damaged += 1
	ward.damage_blocked.connect(on_block)
	player.health.damaged.connect(on_damage)
	# Let the actual duelist acquire, retreat, warn and strike, without forcing its FSM.
	game.load_room("cistern_archive","entry")
	for vent: SteamVent in game.room.get_node("Hazards").get_children():
		vent.deactivate()
	player.revive(Vector2(610,480))
	game.ui.reward_notice.remaining = 0
	game.ui.toast_left = 0
	game.ui.set_text(game.ui.toast,"")
	var rose: RoseSentinel = game.room.get_node("Enemies/RoseSentinel")
	rose.impact.connect(func(_at: Vector2, _killed: bool) -> void: events.impact += 1)
	await h.frames(20)
	Session.set_language("zh_CN")
	await h.press("steam_ward",2)
	for tick: int in range(70):
		if events.blocked > 0:
			break
		await h.frames(1)
	h.check(events.blocked == 1 and ward.active_left == 0 and player.health.current == player.health.maximum, "Ward blocks the actual pink knight slash and consumes exactly one charge")
	h.check(events.damaged == 0 and events.impact == 0 and player.state != Player.State.HURT and player.health.invulnerability_left == 0, "Blocked slash causes no damage signals, hit flash, knockback or global invulnerability")
	h.check(rose.attack_box.hit_ids.has(hurt.get_instance_id()), "Blocked knight slash records its target as handled for the entire swing")
	await h.shot("97_ward_rose_block_zh")
	# Hold the real attack box overlapped beyond the visual feedback duration.
	rose.set_physics_process(false)
	await h.frames(25)
	h.check(player.health.current == player.health.maximum and events.blocked == 1, "Same active slash cannot hurt on later frames after the shield disappears")
	rose.attack_box.begin_swing()
	rose.attack_box.active = true
	await h.frames(2)
	h.check(player.health.current == player.health.maximum-1 and events.damaged == 1, "A subsequent swing damages normally while the shield is cooling down")
	# A second enemy uses its own native attack timing and overlap.
	game.load_room("valve_gallery","entry")
	for vent: SteamVent in game.room.get_node("Hazards").get_children():
		vent.deactivate()
	player.revive(Vector2(920,352))
	var chest: WingedChest = game.room.get_node("Enemies/WingedChest")
	await h.frames(5)
	await h.press("steam_ward",2)
	await h.frames(65)
	h.check(events.blocked == 2 and player.health.current == player.health.maximum and ward.active_left == 0, "Ward blocks real winged chest pounce for the entire bite")
	h.check(chest.contact_box.hit_ids.has(hurt.get_instance_id()) and player.health.invulnerability_left == 0, "Blocked pounce also consumes its carried body contact without global immunity")
	player.position.x -= 100
	await h.frames(4)
	h.check(not chest.shared_pounce_contact, "Separating after the pounce restores ordinary contact handling")
	chest.target = null
	player.position = chest.position
	await h.frames(3)
	h.check(player.health.current == player.health.maximum - 1, "Touching the chest again after separation still causes contact damage")
	# Real swept projectile is consumed on shield contact, with no damage feedback.
	game.load_room("echo_vault","checkpoint")
	player.revive(Vector2(180,608))
	await h.frames(3)
	await h.press("steam_ward",2)
	var bolt := preload("res://features/combat/ink_bolt.tscn").instantiate() as InkBolt
	bolt.position = player.position+Vector2(45,-24)
	bolt.direction = Vector2.LEFT
	bolt.impact.connect(func(_at: Vector2, _killed: bool) -> void: events.impact += 1)
	var previous_impacts: int = events.impact
	game.room.projectiles.add_child(bolt)
	await h.frames(18)
	h.check(not is_instance_valid(bolt) and events.blocked == 3 and player.health.current == player.health.maximum, "Ward blocks and consumes a real swept ink bolt")
	h.check(events.impact == previous_impacts, "Blocked projectile does not emit damage impact feedback")
	# No blanket invulnerability: two distinct impacts in one tick consume only one charge.
	ward.cancel(true)
	ward.activate()
	var first := hurt.resolve_hit(3,player.position)
	var second := hurt.resolve_hit(1,player.position)
	h.check(first == Hurtbox.HitResult.BLOCKED and second == Hurtbox.HitResult.DAMAGED and player.health.current == player.health.maximum-1, "One shield absorbs the complete first hit but not a second distinct hit in the same tick")
	ward.cancel(true)
	ward.activate()
	var before: int = events.blocked
	h.check(hurt.resolve_hit(1,player.position) == Hurtbox.HitResult.IGNORED and ward.active_left > 0 and events.blocked == before, "Damage invulnerability ignores enemy hits without consuming a fresh shield")
	player.health.invulnerability_left = 0
	h.check(hurt.resolve_hit(0,player.position) == Hurtbox.HitResult.IGNORED and hurt.resolve_hit(-1,player.position) == Hurtbox.HitResult.IGNORED and ward.active_left > 0, "Zero and negative damage cannot consume shield")
	ward.advance(ward.config.active_seconds)
	h.check(hurt.resolve_hit(1,player.position) == Hurtbox.HitResult.DAMAGED, "An expired shield cannot block a later enemy hit")
	ward.damage_blocked.disconnect(on_block)
	player.health.damaged.disconnect(on_damage)
	player.revive(Vector2(180,608))
	Session.set_language("en")
	await h.frames(3)
