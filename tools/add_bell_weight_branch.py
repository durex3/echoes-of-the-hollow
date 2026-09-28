"""One-time native scene authoring; refuses to touch an already expanded map."""
from pathlib import Path
import base64
import struct

root = Path(__file__).resolve().parents[1]
rooms = root / "features/world/rooms"
machine_path = rooms / "bell_weight_chamber.tscn"
atrium_path = rooms / "broken_bell_atrium.tscn"
gallery_path = rooms / "hanging_gallery.tscn"


def tiles(width: int, rows: list[int]) -> str:
    data = bytearray()
    for x in range(width // 32):
        for row in rows:
            atlas_x = 25 + x % 2
            atlas_y = 0 if row == rows[0] else 2
            data.extend(struct.pack("<iii", x, row, atlas_x | atlas_y << 16))
    return base64.b64encode(data).decode("ascii")


def bridge_tiles(start: int, end: int, row: int) -> str:
    data = bytearray()
    for x in range(start, end):
        data.extend(struct.pack("<iii", x, row, (25 + x % 2)))
    return base64.b64encode(data).decode("ascii")


def add_before(path: Path, anchor: str, addition: str, guard: str) -> None:
    source = path.read_text(encoding="utf-8")
    if guard in source or source.count(anchor) != 1:
        raise RuntimeError(f"Refusing to rewrite authored map: {path}")
    path.write_text(source.replace(anchor, addition + "\n" + anchor), encoding="utf-8")


if machine_path.exists():
    raise RuntimeError("Refusing to overwrite the authored bell weight chamber")
for existing, guard in [(atrium_path, "EastWeight"), (gallery_path, "WestWeight")]:
    if guard in existing.read_text(encoding="utf-8"):
        raise RuntimeError(f"Refusing to rewrite authored map: {existing}")

machine = f'''[gd_scene format=4]

[ext_resource type="Script" path="res://features/world/room.gd" id="1"]
[ext_resource type="Script" path="res://features/world/bell_court_landmarks.gd" id="2"]
[ext_resource type="TileSet" path="res://features/world/cistern_tileset.tres" id="3"]
[ext_resource type="Script" path="res://features/world/interaction.gd" id="4"]
[ext_resource type="PackedScene" path="res://features/enemies/bell_invoker.tscn" id="5"]
[ext_resource type="PackedScene" path="res://features/world/resonant_slab.tscn" id="6"]

[sub_resource type="RectangleShape2D" id="boundary"]
size = Vector2(32, 512)

[node name="BellWeightChamber" type="Node2D"]
script = ExtResource("1")
room_id = "bell_weight_chamber"
display_name = "承钟机室"
bounds = Rect2(0, 0, 1152, 384)

[node name="Sky" type="Node2D" parent="."]
script = ExtResource("2")
room_width = 1152.0
room_height = 384.0
theme = "gallery"
z_index = -20

[node name="Terrain" type="TileMapLayer" parent="."]
tile_map_data = PackedByteArray("{tiles(1152, [10, 11])}")
tile_set = ExtResource("3")

[node name="ReturnBridge" type="TileMapLayer" parent="."]
enabled = false
tile_map_data = PackedByteArray("{bridge_tiles(3, 33, 8)}")
tile_set = ExtResource("3")

[node name="Spawns" type="Node2D" parent="."]

[node name="entry" type="Marker2D" parent="Spawns"]
position = Vector2(96, 320)

[node name="bridge" type="Marker2D" parent="Spawns"]
position = Vector2(160, 256)

[node name="Interactions" type="Node2D" parent="."]

[node name="West" type="Node2D" parent="Interactions"]
position = Vector2(48, 320)
script = ExtResource("4")
kind = "exit"
target_room = "broken_bell_atrium"
target_spawn = "machine"
prompt = "向西 · 中庭上层"

[node name="EastWeight" type="Node2D" parent="Interactions"]
position = Vector2(1056, 320)
script = ExtResource("4")
kind = "reward"
stable_id = "east_weight_restored"
prompt = "启动东承重 · 开启上层回桥"

[node name="BridgeReturn" type="Node2D" parent="Interactions"]
position = Vector2(128, 256)
script = ExtResource("4")
kind = "exit"
required_flag = "east_weight_restored"
target_room = "broken_bell_atrium"
target_spawn = "machine_bridge"
prompt = "沿东回桥返回中庭"

[node name="Enemies" type="Node2D" parent="."]

[node name="FirstInvoker" parent="Enemies" instance=ExtResource("5")]
position = Vector2(416, 320)

[node name="SecondInvoker" parent="Enemies" instance=ExtResource("5")]
position = Vector2(800, 320)

[node name="Hazards" type="Node2D" parent="."]

[node name="ResonantSlab" parent="Hazards" instance=ExtResource("6")]
position = Vector2(864, 320)

[node name="Decor" type="Node2D" parent="."]
z_index = -2

[node name="WestBoundary" type="StaticBody2D" parent="."]
position = Vector2(-32, -64)

[node name="Collision" type="CollisionShape2D" parent="WestBoundary"]
position = Vector2(16, 256)
shape = SubResource("boundary")

[node name="EastBoundary" type="StaticBody2D" parent="."]
position = Vector2(1152, -64)

[node name="Collision" type="CollisionShape2D" parent="EastBoundary"]
position = Vector2(16, 256)
shape = SubResource("boundary")
'''
machine_path.write_text(machine, encoding="utf-8")

add_before(
    atrium_path,
    '[node name="Enemies" type="Node2D" parent="."',
    '''[node name="machine" type="Marker2D" parent="Spawns"]
position = Vector2(704, 256)

[node name="machine_bridge" type="Marker2D" parent="Spawns"]
position = Vector2(576, 256)

[node name="gallery_bridge" type="Marker2D" parent="Spawns"]
position = Vector2(320, 256)

[node name="EastWeight" type="Node2D" parent="Interactions"]
position = Vector2(752, 256)
script = ExtResource("4_hc07k")
kind = "exit"
target_room = "bell_weight_chamber"
target_spawn = "entry"
prompt = "向东 · 承钟机室"

[node name="WestBridgeReturn" type="Node2D" parent="Interactions"]
position = Vector2(256, 256)
script = ExtResource("4_hc07k")
kind = "exit"
required_flag = "west_weight_restored"
target_room = "hanging_gallery"
target_spawn = "bridge"
prompt = "沿西回桥返回悬铃回廊"
''',
    "EastWeight",
)

add_before(
    gallery_path,
    '[node name="Enemies" type="Node2D" parent="."',
    f'''[node name="BridgeTerrain" type="TileMapLayer" parent="."]
enabled = false
tile_map_data = PackedByteArray("{bridge_tiles(3, 33, 8)}")
tile_set = ExtResource("3_mynta")

[node name="bridge" type="Marker2D" parent="Spawns"]
position = Vector2(960, 256)

[node name="WestWeight" type="Node2D" parent="Interactions"]
position = Vector2(96, 320)
script = ExtResource("4_atsdi")
kind = "reward"
stable_id = "west_weight_restored"
prompt = "启动西承重 · 开启上层回桥"

[node name="BridgeReturn" type="Node2D" parent="Interactions"]
position = Vector2(1040, 256)
script = ExtResource("4_atsdi")
kind = "exit"
required_flag = "west_weight_restored"
target_room = "broken_bell_atrium"
target_spawn = "gallery_bridge"
prompt = "沿西回桥返回中庭"
''',
    "WestWeight",
)
print("Added native bell weight room and two authored bridge layers")
