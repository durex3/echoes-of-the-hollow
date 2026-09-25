"""One-time native animation resources, indexed after visual sheet inspection."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def write_frames(relative, texture, animations):
    path = ROOT / relative
    if path.exists():
        raise RuntimeError(f'Refusing to overwrite authored resource: {path}')
    indices = sorted({i for _, _, _, ids in animations for i in ids})
    text = f'[gd_resource type="SpriteFrames" load_steps={len(indices)+2} format=3]\n\n'
    text += f'[ext_resource type="Texture2D" path="res://{texture}" id="1"]\n\n'
    for i in indices:
        text += f'[sub_resource type="AtlasTexture" id="F{i}"]\natlas = ExtResource("1")\nregion = Rect2({i%6*64}, {i//6*64}, 64, 64)\n\n'
    rows = []
    for name, speed, loop, ids in animations:
        frames = ', '.join(f'{{"duration": 1.0, "texture": SubResource("F{i}")}}' for i in ids)
        rows.append(f'{{"name": &"{name}", "speed": {speed}, "loop": {str(loop).lower()}, "frames": [{frames}]}}')
    path.write_text(text + '[resource]\nanimations = [' + ',\n'.join(rows) + ']\n', encoding='utf-8', newline='\n')

if __name__ == '__main__':
    write_frames('features/enemies/scribe_frames.tres', 'assets/characters/doom_scribe.png', [
        ('idle', 8, True, range(8)), ('cast', 8, False, range(8,12)),
        ('release', 8, False, [12,13]), ('hurt', 1, False, [14]),
        ('death', 12, False, range(15,25))])
    write_frames('features/combat/ink_bolt_frames.tres', 'assets/effects/ink_bolt.png', [('fly',12,True,range(8,14))])
