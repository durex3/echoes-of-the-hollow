"""Import only the approved Chapter II knight; source art is never modified.

Run explicitly after extracting Hero Knight 2 to the candidate downloads folder.
This leaves both Boss frame resources and the player animations untouched.
"""
from pathlib import Path
import hashlib
import json
import shutil
import struct

from import_external_enemy_assets import sprite_frames, frames

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'artifacts/downloads/hero_knight_2_candidate/Hero Knight 2'
URL = 'https://luizmelo.itch.io/hero-knight-2'


def main():
    license_file = SOURCE / 'License.txt'
    if 'Creative Commons Zero (CC-0)' not in license_file.read_text(encoding='utf-8-sig'):
        raise ValueError('Expected original CC0 license declaration')
    manifest_path = ROOT / 'assets/manifest.json'
    records = {r['file']: r for r in json.loads(manifest_path.read_text(encoding='utf-8'))}
    textures = {}
    for name, count in [('Idle', 11), ('Run', 8), ('Attack', 6), ('Take Hit', 4), ('Death', 9)]:
        key = name.lower().replace(' ', '_')
        source = SOURCE / 'Sprites' / (name + '.png')
        data = source.read_bytes()
        if data[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', data[16:24]) != (140 * count, 140):
            raise ValueError('Unexpected sheet: ' + str(source))
        target = 'assets/characters/helm_knight_' + key + '.png'
        shutil.copy2(source, ROOT / target)
        textures[key] = target
        records[target] = {
            'file': target, 'source_pack': 'Hero Knight 2 by LuizMelo',
            'source_relative_path': 'Sprites/' + name + '.png', 'source_url': URL,
            'sha256': hashlib.sha256(data).hexdigest(),
            'license_status': 'CC0; original declaration in assets/licenses/helm_knight_license.txt'
        }
    license_target = 'assets/licenses/helm_knight_license.txt'
    shutil.copy2(license_file, ROOT / license_target)
    records[license_target] = {
        'file': license_target, 'source_pack': 'Hero Knight 2 by LuizMelo',
        'source_relative_path': 'License.txt', 'source_url': URL,
        'sha256': hashlib.sha256(license_file.read_bytes()).hexdigest(),
        'license_status': 'Original CC0 declaration; commercial and non-commercial use permitted'
    }
    sprite_frames(ROOT / 'features/enemies/rose_frames.tres', textures, [
        ('idle', frames('idle', *range(11)), True),
        ('step', frames('run', *range(8)), True),
        ('warning', frames('attack', 0, 1, 2, 3), False),
        ('strike', frames('attack', 4), False),
        ('recover', frames('attack', 5) + frames('idle', 0), False),
        # Skip the baked all-white hit frame; runtime honors reduce-flashes.
        ('hurt', frames('take_hit', 0, 2, 3) + frames('idle', 0), False),
        ('death', frames('death', *range(9)), False),
    ], 140, 140)
    manifest_path.write_text(json.dumps(list(records.values()), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Imported five original sheets, CC0 declaration and Chapter II knight frames.')


if __name__ == '__main__':
    main()
