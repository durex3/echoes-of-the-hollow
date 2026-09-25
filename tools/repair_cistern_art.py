"""Bounded correction of 0.10.1 art nodes; never regenerates terrain cells."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def repair(room_id):
    path = ROOT / 'features/world/rooms' / (room_id + '.tscn')
    text = path.read_text(encoding='utf-8')
    terrain_before = re.search(r'\[node name="Terrain"[^\[]+', text).group()
    blocks = re.split(r'(?=\[node )', text)
    water_count = 0
    for i, block in enumerate(blocks):
        if 'type="Sprite2D" parent="CastleArt"' not in block:
            continue
        if re.search(r'region_rect = Rect2\((992, 384, 32, 96|896, 384, 128, 128)\)', block):
            block = re.sub(r'name="[^"]+"', f'name="Water{water_count:02}"', block, count=1)
            block = re.sub(r'region_rect = Rect2\([^\n]+', 'region_rect = Rect2(928, 384, 64, 96)', block)
            block = re.sub(r'^scale = .*\n', '', block, flags=re.M)
            block = block.replace('centered = false', 'scale = Vector2(2, 1)\ncentered = false')
            if room_id == 'ember_quay':
                block = re.sub(r'position = Vector2\((\d+), 416\)', r'position = Vector2(\1, 448)', block)
            water_count += 1
        if 'region_rect = Rect2(52, 28, 44, 36)' in block:
            block = re.sub(r'position = Vector2\((\d+), 436\)', r'position = Vector2(\1, 444)', block)
        if 'region_rect = Rect2(108, 36, 22, 28)' in block:
            block = re.sub(r'position = Vector2\((\d+), 444\)', r'position = Vector2(\1, 452)', block)
        blocks[i] = block
    text = ''.join(blocks)
    if room_id == 'ember_quay' and 'name="DeckBacking00"' not in text:
        backing = ''
        for index, x in enumerate(range(224, 576, 32)):
            backing += f'''[node name="DeckBacking{index:02}" type="Sprite2D" parent="CastleArt"]
position = Vector2({x}, 480)
texture = ExtResource("2_28qw1")
centered = false
region_enabled = true
region_rect = Rect2({800 + index % 2 * 32}, 64, 32, 32)

'''
        text = text.replace('[node name="Terrain"', backing + '[node name="Terrain"', 1)
    assert re.search(r'\[node name="Terrain"[^\[]+', text).group() == terrain_before
    path.write_text(text, encoding='utf-8', newline='\n')
    print(f'{room_id}: repaired {water_count} water instances; terrain unchanged')


if __name__ == '__main__':
    for room in ('ember_quay', 'valve_gallery', 'cistern_archive'):
        repair(room)
