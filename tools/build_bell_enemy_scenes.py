"""One-time native composition of the two minions. Never overwrites saved scenes."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    for kind in ('invoker', 'skimmer'):
        path = ROOT / f'features/enemies/bell_{kind}.tscn'
        if path.exists():
            raise SystemExit('Refusing to overwrite ' + str(path))
    for kind, scale, offset, body, center in [
        ('invoker', '1, 1', '0, -42', '28, 44', '0, -22'),
        ('skimmer', '1.4285714, 1.4285714', '0.5, -10.5', '20, 18', '0, -9'),
    ]:
        text = f'''[gd_scene load_steps=11 format=3]
[ext_resource type="Script" path="res://features/enemies/enemy_stagger.gd" id="stagger"]
[ext_resource type="Script" path="res://features/enemies/bell_{kind}.gd" id="1"]
[ext_resource type="SpriteFrames" path="res://features/enemies/{kind}_frames.tres" id="2"]
[ext_resource type="Resource" path="res://features/enemies/{kind}_config.tres" id="3"]
[ext_resource type="Script" path="res://features/combat/health.gd" id="4"]
[ext_resource type="Script" path="res://features/combat/hurtbox.gd" id="5"]
[ext_resource type="Script" path="res://features/combat/hitbox.gd" id="6"]
[ext_resource type="Script" path="res://features/enemies/bell_frame_strike.gd" id="7"]
[sub_resource type="RectangleShape2D" id="body"]
size = Vector2({body})
[sub_resource type="RectangleShape2D" id="hurt"]
size = Vector2({body})
[node name="Bell{kind.title()}" type="CharacterBody2D" groups=["enemies"]]
collision_layer = 4
collision_mask = 1
script = ExtResource("1")
config = ExtResource("3")
[node name="Stagger" type="Node" parent="."]
script = ExtResource("stagger")
[node name="Sprite" type="AnimatedSprite2D" parent="."]
texture_filter = 1
scale = Vector2({scale})
offset = Vector2({offset})
sprite_frames = ExtResource("2")
animation = &"{'idle' if kind == 'invoker' else 'fly'}"
[node name="Body" type="CollisionShape2D" parent="."]
position = Vector2({center})
shape = SubResource("body")
[node name="Health" type="Node" parent="."]
script = ExtResource("4")
invulnerability_seconds = 0.16
[node name="Hurtbox" type="Area2D" parent="." node_paths=PackedStringArray("health")]
collision_layer = 16
collision_mask = 0
monitoring = false
script = ExtResource("5")
health = NodePath("../Health")
[node name="Shape" type="CollisionShape2D" parent="Hurtbox"]
position = Vector2({center})
shape = SubResource("hurt")
[node name="ContactBox" type="Area2D" parent="."]
position = Vector2({center})
collision_layer = 0
collision_mask = 8
monitorable = false
script = ExtResource("6")
starts_active = true
reset_when_empty = true
[node name="Shape" type="CollisionShape2D" parent="ContactBox"]
shape = SubResource("body")
[node name="Strike" type="Node2D" parent="."]
script = ExtResource("7")
'''
        if kind == 'invoker':
            text += '''[node name="Edge" type="RayCast2D" parent="."]
position = Vector2(22, -12)
target_position = Vector2(0, 48)
collision_mask = 1
'''
        (ROOT / f'features/enemies/bell_{kind}.tscn').write_text(text, encoding='utf-8')


if __name__ == '__main__':
    main()
