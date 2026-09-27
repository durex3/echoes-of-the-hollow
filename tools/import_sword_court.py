"""Copy the supplied sword atlas unchanged; create editable native frame regions."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[1]
relative='Twin Sword PNG/Cast Spell 102-DownCut All.png'
source=ROOT/'artifacts/downloads/cast spell 102'/relative
destination=ROOT/'assets/effects/royal_sword.png'
shutil.copyfile(source,destination)
note=ROOT/'assets/licenses/royal_sword_source.txt'
note.write_text('Cast Spell : Summon Sword — IceButMelted\n'
    'Source: https://icebutmelted.itch.io/cast-spell-summon-sword\n'
    'User-supplied cast spell 102, 2026-09-27. No license file in supplied folder.\n'
    'Author-page terms checked 2026-09-27 allow personal/commercial projects and modification; standalone resale or redistribution is prohibited.\n'
    'This is a project provenance note, not a license file from the archive.\n'
    'The DownCut All PNG is copied unchanged. Native atlas regions omit blank cells 0, 32 and 33.\n'
    'Source summon/hover frames form the projectile; settled release cells 21-22 and disappear cells 23-31 form harmless contact feedback.\n'
    'Large baked swing cells 18-20 are excluded from runtime clips to preserve the projectile silhouette.\n',encoding='utf-8')
manifest_path=ROOT/'assets/manifest.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))
for path,original in [(destination,relative),(note,'Project-authored provenance note')]:
    entry={'file':path.relative_to(ROOT).as_posix(),'source_pack':'Cast Spell : Summon Sword by IceButMelted',
        'source_relative_path':original,'source_url':'https://icebutmelted.itch.io/cast-spell-summon-sword',
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'license_status':'Author permits game use and modification, no standalone resale or redistribution; see assets/licenses/royal_sword_source.txt.'}
    manifest=[item for item in manifest if item['file']!=entry['file']];manifest.append(entry)
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=['[gd_resource type="SpriteFrames" load_steps=33 format=3]',
    '[ext_resource type="Texture2D" path="res://assets/effects/royal_sword.png" id="1"]']
for i in range(1,32):
    lines+= [f'[sub_resource type="AtlasTexture" id="frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i*128}, 0, 128, 128)']
clips=[]
for name,frames in [('summon',range(1,13)),('hover',range(13,18)),('fly',[17]),('impact',range(21,23)),('fade',range(23,32))]:
    entries=', '.join('{"duration": 1.0, "texture": SubResource("frame_%d")}'%i for i in frames)
    clips.append('{"name": &"%s", "speed": 20.0, "loop": false, "frames": [%s]}'%(name,entries))
lines+=['[resource]','animations = ['+',\n'.join(clips)+']']
(ROOT/'features/combat/royal_sword_frames.tres').write_text('\n\n'.join(lines)+'\n',encoding='utf-8')
print('Source unchanged:',hashlib.sha256(source.read_bytes()).hexdigest())
