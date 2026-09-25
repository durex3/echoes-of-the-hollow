"""Import the unused course swordsman and author an explicit reviewed frame map."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT.parent / 'Godot 4《类银河恶魔城锻造坊》资源目录(1)'
relative = 'ch_06_boss_battles/ch_06_boss_battles/sprites/nega_pink_box.png'
target = ROOT / 'assets/characters/rose_sentinel.png'
frames = ROOT / 'features/enemies/rose_frames.tres'
if target.exists() or frames.exists():
    raise SystemExit('Already imported. Edit native resources; do not regenerate.')
shutil.copyfile(PACK / relative, target)
manifest_path = ROOT / 'assets/manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest.append({'file': target.relative_to(ROOT).as_posix(), 'source_pack': PACK.name,
                 'source_relative_path': relative,
                 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                 'license_status': manifest[0]['license_status']})
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
clips = {'idle': list(range(6)), 'step': list(range(6,14)), 'warning': [21,22],
         'strike': [23,24], 'recover': [25,26,27], 'death': list(range(36,48))}
indices = sorted(set(sum(clips.values(), [])))
out = [f'[gd_resource type="SpriteFrames" load_steps={len(indices)+2} format=3]',
       '[ext_resource type="Texture2D" path="res://assets/characters/rose_sentinel.png" id="1"]']
for n in indices:
    out.append(f'[sub_resource type="AtlasTexture" id="f{n}"]\natlas = ExtResource("1")\nregion = Rect2({n%8*80}, {n//8*80}, 80, 80)')
out.append('[resource]\nanimations = [')
for name, indices in clips.items():
    entries = ', '.join('{"duration": 1.0, "texture": SubResource("f%d")}' % n for n in indices)
    loop = 'true' if name in ('idle','step') else 'false'
    out.append(f'{{"name": &"{name}", "loop": {loop}, "speed": 12.0, "frames": [{entries}]}},')
out.append(']')
frames.write_text('\n\n'.join(out)+'\n',encoding='utf-8')
