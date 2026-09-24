"""One-time native scene scaffolding. Refuses to overwrite existing scenes.

After generation, edit .tscn/.tres directly in Godot. This is NOT a build step.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def write(relative, body):
    path = ROOT / relative
    if path.exists():
        raise FileExistsError(f'Refusing to replace authored file: {relative}')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body.strip() + '\n', encoding='utf-8')

def sprite_frames(path, texture, size, columns, clips):
    indices = sorted({i for _, frames, _, _ in clips for i in frames})
    parts = [f'[gd_resource type="SpriteFrames" load_steps={len(indices)+2} format=3]',
             f'[ext_resource type="Texture2D" path="res://{texture}" id="1"]']
    for i in indices:
        parts.append(f'[sub_resource type="AtlasTexture" id="Frame_{i}"]\natlas = ExtResource("1")\nregion = Rect2({i%columns*size[0]}, {i//columns*size[1]}, {size[0]}, {size[1]})')
    animations = []
    for name, frames, fps, loop in clips:
        values = ', '.join('{"duration": 1.0, "texture": SubResource("Frame_%d")}' % i for i in frames)
        animations.append('{"name": &"%s", "speed": %s, "loop": %s, "frames": [%s]}' % (name, fps, str(loop).lower(), values))
    parts.append('[resource]\nanimations = [' + ',\n'.join(animations) + ']')
    write(path, '\n\n'.join(parts))

sprite_frames('features/player/hero_frames.tres', 'assets/characters/hero.png', (80,80), 16, [
    ('idle',range(12),10,True),('run',range(12,20),12,True),
    ('jump',[22],1,True),('fall',[25],1,True),
    ('attack',[27,28,29,30,31,32],20,False),
    ('hurt',[37],1,True),('death',range(50,61),15,False)])
sprite_frames('features/enemies/slime_frames.tres','assets/characters/slime.png',(48,32),6,[
    ('idle',range(6),8,True),('death',range(6,12),12,False)])
sprite_frames('features/world/checkpoint_frames.tres','assets/props/save_point.png',(96,80),1,[
    ('idle',[0],1,True)])

write('features/player/default_player.tres', '''
[gd_resource type="Resource" script_class="PlayerConfig" load_steps=2 format=3]
[ext_resource type="Script" path="res://features/player/player_config.gd" id="1"]
[resource]
script = ExtResource("1")
run_speed = 230.0
jump_height = 102.0
time_to_apex = 0.36
''')

write('features/player/player.tscn', '''
[gd_scene load_steps=12 format=3]
[ext_resource type="Script" path="res://features/player/player.gd" id="1"]
[ext_resource type="Resource" path="res://features/player/default_player.tres" id="2"]
[ext_resource type="SpriteFrames" path="res://features/player/hero_frames.tres" id="3"]
[ext_resource type="Script" path="res://features/combat/health.gd" id="4"]
[ext_resource type="Script" path="res://features/combat/hurtbox.gd" id="5"]
[ext_resource type="Script" path="res://features/combat/hitbox.gd" id="6"]
[ext_resource type="Script" path="res://features/player/slash.gd" id="7"]
[sub_resource type="CapsuleShape2D" id="Body"]
radius = 10.0
height = 42.0
[sub_resource type="RectangleShape2D" id="Hurt"]
size = Vector2(22, 40)
[sub_resource type="RectangleShape2D" id="Attack"]
size = Vector2(48, 44)

[node name="Player" type="CharacterBody2D" groups=["player"]]
process_mode = 1
collision_layer = 2
collision_mask = 1
floor_snap_length = 6.0
script = ExtResource("1")
config = ExtResource("2")

[node name="Collision" type="CollisionShape2D" parent="."]
position = Vector2(0, -21)
shape = SubResource("Body")
[node name="Visual" type="Node2D" parent="."]
[node name="Sprite" type="AnimatedSprite2D" parent="Visual"]
position = Vector2(0, -40)
sprite_frames = ExtResource("3")
animation = &"idle"
[node name="Slash" type="Node2D" parent="Visual"]
visible = false
script = ExtResource("7")
[node name="Health" type="Node" parent="."]
script = ExtResource("4")
maximum = 5
invulnerability_seconds = 0.8
[node name="Hurtbox" type="Area2D" parent="." node_paths=PackedStringArray("health")]
collision_layer = 8
collision_mask = 0
monitoring = false
script = ExtResource("5")
health = NodePath("../Health")
[node name="Shape" type="CollisionShape2D" parent="Hurtbox"]
position = Vector2(0, -21)
shape = SubResource("Hurt")
[node name="AttackBox" type="Area2D" parent="."]
position = Vector2(30, -23)
collision_layer = 0
collision_mask = 16
monitorable = false
script = ExtResource("6")
[node name="Shape" type="CollisionShape2D" parent="AttackBox"]
shape = SubResource("Attack")
''')

write('features/enemies/slime.tscn', '''
[gd_scene load_steps=10 format=3]
[ext_resource type="Script" path="res://features/enemies/slime.gd" id="1"]
[ext_resource type="SpriteFrames" path="res://features/enemies/slime_frames.tres" id="2"]
[ext_resource type="Script" path="res://features/combat/health.gd" id="3"]
[ext_resource type="Script" path="res://features/combat/hurtbox.gd" id="4"]
[ext_resource type="Script" path="res://features/combat/hitbox.gd" id="5"]
[sub_resource type="RectangleShape2D" id="Body"]
size = Vector2(26, 18)
[sub_resource type="RectangleShape2D" id="Hurt"]
size = Vector2(32, 24)
[sub_resource type="RectangleShape2D" id="Contact"]
size = Vector2(29, 20)
[node name="Slime" type="CharacterBody2D" groups=["enemies"]]
collision_layer = 4
collision_mask = 1
script = ExtResource("1")
[node name="Sprite" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -16)
sprite_frames = ExtResource("2")
animation = &"idle"
autoplay = "idle"
[node name="Body" type="CollisionShape2D" parent="."]
position = Vector2(0, -9)
shape = SubResource("Body")
[node name="Health" type="Node" parent="."]
script = ExtResource("3")
maximum = 2
invulnerability_seconds = 0.16
[node name="Hurtbox" type="Area2D" parent="." node_paths=PackedStringArray("health")]
collision_layer = 16
collision_mask = 0
monitoring = false
script = ExtResource("4")
health = NodePath("../Health")
[node name="Shape" type="CollisionShape2D" parent="Hurtbox"]
position = Vector2(0, -12)
shape = SubResource("Hurt")
[node name="Contact" type="Area2D" parent="."]
position = Vector2(0, -10)
collision_layer = 0
collision_mask = 8
monitorable = false
script = ExtResource("5")
[node name="Shape" type="CollisionShape2D" parent="Contact"]
shape = SubResource("Contact")
[node name="Edge" type="RayCast2D" parent="."]
position = Vector2(-20, -10)
target_position = Vector2(0, 28)
collision_mask = 1
''')

tiles = ['[gd_resource type="TileSet" load_steps=3 format=3]',
'[ext_resource type="Texture2D" path="res://assets/environment/forest.png" id="1"]',
'[sub_resource type="TileSetAtlasSource" id="Atlas"]\ntexture = ExtResource("1")\ntexture_region_size = Vector2i(32, 32)']
for y in range(16):
    for x in range(32):
        tiles.append(f'{x}:{y}/0 = 0')
        # Only map-used ground tiles are solid. Scenery shares the atlas but not collision.
        if (y <= 2 and x <= 4) or (y in [6,7] and x<=4):
            tiles.append(f'{x}:{y}/0/physics_layer_0/polygon_0/points = PackedVector2Array(-16,-16,16,-16,16,16,-16,16)')
tiles.append('[resource]\ntile_size = Vector2i(32, 32)\nphysics_layer_0/collision_layer = 1\nsources/0 = SubResource("Atlas")')
write('features/world/forest_tileset.tres', '\n'.join(tiles))

def room(room_id):
    ruins=room_id=='ruins'
    text='''[gd_scene load_steps=8 format=3]
[ext_resource type="Script" path="res://features/world/room.gd" id="1"]
[ext_resource type="Script" path="res://features/world/backdrop.gd" id="2"]
[ext_resource type="TileSet" path="res://features/world/forest_tileset.tres" id="3"]
[ext_resource type="PackedScene" path="res://features/enemies/slime.tscn" id="4"]
[ext_resource type="Script" path="res://features/world/interaction.gd" id="5"]
[ext_resource type="SpriteFrames" path="res://features/world/checkpoint_frames.tres" id="6"]
[sub_resource type="RectangleShape2D" id="Boundary"]
size = Vector2(32, 640)
'''
    title='02 / THE SUNKEN ARCHIVE' if ruins else '01 / THE FORGOTTEN GROVE'
    text+=f'''\n[node name="{room_id.title()}" type="Node2D"]
script = ExtResource("1")
room_id = "{room_id}"
display_name = "{title}"
music_track = "{'dungeon' if ruins else 'forest'}"
[node name="Backdrop" type="Node2D" parent="."]
script = ExtResource("2")
ruins = {str(ruins).lower()}
[node name="Terrain" type="TileMapLayer" parent="."]
tile_set = ExtResource("3")
[node name="Details" type="TileMapLayer" parent="."]
tile_set = ExtResource("3")
collision_enabled = false
[node name="Bounds" type="StaticBody2D" parent="."]
collision_layer = 1
collision_mask = 0
[node name="Left" type="CollisionShape2D" parent="Bounds"]
position = Vector2(-16, 256)
shape = SubResource("Boundary")
[node name="Right" type="CollisionShape2D" parent="Bounds"]
position = Vector2(1296, 256)
shape = SubResource("Boundary")
[node name="Spawns" type="Node2D" parent="."]
[node name="checkpoint" type="Marker2D" parent="Spawns"]
position = Vector2(160, 480)
[node name="entry" type="Marker2D" parent="Spawns"]
position = Vector2(112, 480)
[node name="east" type="Marker2D" parent="Spawns"]
position = Vector2(1130, 480)
[node name="Enemies" type="Node2D" parent="."]
'''
    for index,x in enumerate([560,850] if not ruins else [440,650,1100]):
        text+=f'\n[node name="Slime{index}" parent="Enemies" instance=ExtResource("4")]\nposition = Vector2({x}, 480)\npatrol_distance = 65.0\n'
    text+='\n[node name="Interactions" type="Node2D" parent="."]\n'
    points=[('Shrine','checkpoint',160,480,'','entry','checkpoint','E  /  REST & SAVE')]
    if ruins:
        points += [('WestDoor','exit',48,480,'forest','east','west_door','E  /  RETURN TO THE GROVE'),('Echo','ability',960,352,'','entry','double_jump','E  /  CLAIM THE SKY ECHO')]
    else:
        points += [('EastDoor','exit',1200,480,'ruins','entry','east_door','E  /  ENTER THE ARCHIVE'),('HighShrine','goal',400,224,'','entry','high_shrine','E  /  RESTORE THE HOLLOW')]
    for name,kind,x,y,target,spawn,stable,prompt in points:
        text+=f'''\n[node name="{name}" type="Node2D" parent="Interactions"]
position = Vector2({x}, {y})
script = ExtResource("5")
kind = "{kind}"
stable_id = "{stable}"
target_room = "{target}"
target_spawn = "{spawn}"
prompt = "{prompt}"
'''
        if kind=='checkpoint':
            text+=f'''[node name="Sprite" type="AnimatedSprite2D" parent="Interactions/{name}"]
position = Vector2(0, -20)
scale = Vector2(0.5, 0.5)
sprite_frames = ExtResource("6")
animation = &"idle"
autoplay = "idle"
'''
    write(f'features/world/rooms/{room_id}.tscn',text)

room('forest')
room('ruins')

# Physical keys live exclusively in project settings.
project=ROOT/'project.godot'
body=project.read_text(encoding='utf-8')
assert '[input]' not in body
body+='\n[input]\n'
actions={'move_left':[65,4194321],'move_right':[68,4194323], 'jump':[32], 'attack':[74], 'interact':[69], 'pause':[4194305], 'mute':[77]}
joy={'move_left':13,'move_right':14,'jump':0,'attack':2,'interact':3,'pause':6}
for name,keys in actions.items():
    events=[f'Object(InputEventKey,"physical_keycode":{key})' for key in keys]
    if name in joy:
        events.append(f'Object(InputEventJoypadButton,"button_index":{joy[name]})')
    if name in ['move_left','move_right']:
        events.append(f'Object(InputEventJoypadMotion,"axis":0,"axis_value":{-1.0 if name=="move_left" else 1.0})')
    body+=f'{name}={{\n"deadzone": 0.25,\n"events": [{", ".join(events)}]\n}}\n'
project.write_text(body,encoding='utf-8')
print('Native scenes/resources created. Author these files directly from now on.')
