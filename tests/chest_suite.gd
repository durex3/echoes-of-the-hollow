extends Node
## Real chest scene, physical overlap and mapped sword input; isolated fixtures.

func setup(h: Node, game: Node, at := Vector2(920,352)) -> WingedChest:
	game.load_room("valve_gallery","entry")
	game.ui.reward_notice.remaining = 0
	game.ui.set_text(game.ui.toast, "")
	for vent: SteamVent in game.room.get_node("Hazards").get_children():
		vent.enabled = false
	game.player.revive(at)
	await h.frames(4)
	return game.room.get_node("Enemies/WingedChest") as WingedChest

func run(h: Node, game: Node) -> void:
	var player: Player = game.player
	var chest: WingedChest = await setup(h,game,Vector2(716,352))
	h.check(chest.target == player and chest.state == WingedChest.State.IDLE, "Gallery uses the new chest and injects its target outside the safe lesson")
	Session.set_language("zh_CN")
	await h.frames(3)
	h.check(game.ui.prompt.text.contains("飞翼宝箱"), "Chest lesson is visible in Chinese before entering attack range")
	await h.shot("81_chest_lesson_zh")
	Session.set_language("en")
	player.revive(Vector2(920,352))
	await h.frames(4)
	h.check(chest.state == WingedChest.State.WARNING and not chest.attack_box.active, "Chest gives harmless warning before its bite")
	var direction := chest.facing
	var frozen := chest.timer
	get_tree().paused = true
	await h.frames(8)
	h.check(chest.timer == frozen, "Pause freezes chest warning timer")
	get_tree().paused = false
	player.revive(Vector2(1030,352))
	await h.frames(3)
	h.check(chest.facing == direction and player.health.current == player.health.maximum, "Chest warning locks direction even when player crosses behind")
	game.camera.position = Vector2(955,285)
	game.camera.reset_smoothing()
	await h.shot("82_chest_warning")
	# Wait for real active and recovery phases instead of forcing FSM state.
	for frame: int in range(50):
		if chest.state == WingedChest.State.LUNGE:
			break
		await h.frames(1)
	var start := chest.position
	await h.frames(8)
	h.check(chest.attack_box.active and chest.position.x < start.x-20, "Chest pounces in its locked direction through real physics")
	await h.shot("83_chest_bite")
	await h.frames(18)
	h.check(chest.state == WingedChest.State.RECOVER and not chest.attack_box.active, "Missed chest bite exposes a harmless recovery window")
	await h.shot("84_chest_recovery")
	chest = await setup(h,game)
	var full := player.health.current
	await h.frames(66)
	h.check(player.health.current == full-1 and chest.state == WingedChest.State.RECOVER, "Actual pounce overlap damages exactly once and then recovers")
	# Input-driven jump over the locked bite, with normal player collision and health.
	chest = await setup(h,game)
	await h.frames(30)
	Input.action_press("jump")
	await h.frames(35)
	Input.action_release("jump")
	h.check(player.health.current == player.health.maximum and chest.state == WingedChest.State.RECOVER, "A real jump dodges the new enemy pounce")
	# A real sword hit interrupts windup before the attack is enabled.
	chest = await setup(h,game,Vector2(951,352))
	player.facing = 1
	await h.press("attack",10)
	h.check(chest.health.current == 2 and chest.state == WingedChest.State.RECOVER and not chest.attack_box.active, "Sword interrupts chest warning and cancels bite damage")
	# Solid world cover prevents acquisition, and blocks a committed pounce.
	chest = await setup(h,game,Vector2(110,480))
	var cover := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8,100)
	shape.shape = rect
	cover.add_child(shape)
	game.room.add_child(cover)
	cover.position = Vector2(950,310)
	player.revive(Vector2(900,352))
	await h.frames(5)
	h.check(not chest.can_see_target() and chest.state == WingedChest.State.IDLE, "World wall blocks chest detection")
	cover.position.x = 700
	await h.frames(4)
	cover.position.x = 950
	await h.frames(70)
	h.check(chest.position.x >= 968 and not chest.attack_box.active and player.health.current == player.health.maximum, "Committed chest pounce stops at solid wall without damaging through it")
	# At an authored ledge, a locked attack must stop before leaving support.
	chest = await setup(h,game,Vector2(110,480))
	chest.position = Vector2(644,352)
	player.revive(Vector2(620,352))
	await h.frames(70)
	h.check(chest.position.x >= 623 and absf(chest.position.y-352)<2 and not chest.attack_box.active, "Chest edge probe stops its pounce on the authored gallery ledge")
	# Null/dead target cancels an already prepared attack.
	chest = await setup(h,game)
	chest.target = null
	await h.frames(2)
	h.check(chest.state == WingedChest.State.RECOVER and not chest.attack_box.active, "Removed target cancels a pending chest bite")
	chest = await setup(h,game)
	player.health.take_damage(99,player.position)
	await h.frames(2)
	h.check(chest.state == WingedChest.State.RECOVER and not chest.attack_box.active, "Player death cancels a pending chest bite")
	await h.frames(65)
	chest = await setup(h,game)
	chest.health.take_damage(99,player.position)
	await h.frames(2)
	h.check(not chest.attack_box.active and chest.state == WingedChest.State.DEAD, "Chest death immediately disables its attack")
	await h.frames(30)
	h.check(not is_instance_valid(chest), "Defeated chest releases its scene after the fade")
	Session.flags.erase("flow_seal")
	chest = await setup(h,game,Vector2(951,352))
	player.facing = 1
	for swing: int in range(3):
		await h.press("attack",26)
	await h.frames(25)
	h.check(player.health.current<player.health.maximum,"Repeated stationary sword presses leave the surviving chest an actual counterattack")
	for swing: int in range(3):
		if game.room.is_cleared():
			break
		player.facing = signf(chest.position.x-player.position.x)
		await h.press("attack",26)
	h.check(game.room.is_cleared() and player.health.current>0,"Mapped sword attacks still finish the chest after its counter, without damage immunity")
	player.revive(Vector2(1100,352))
	await h.frames(4)
	await h.press("interact",2)
	h.check(game.room.room_id == "sluice_shaft" and "flow_seal" not in Session.flags, "Gallery leads deeper into the shaft rather than awarding a shallow seal")
	game.load_room("ember_quay","checkpoint")
	await h.frames(3)
