"""Import approved Chapter III minions, preserving original PNG bytes and licenses.

Refuses to overwrite authored SpriteFrames. Boss import belongs to the later Boss pass.
"""
from pathlib import Path
import hashlib
import json
import shutil
import struct
from import_external_enemy_assets import sprite_frames, frames

ROOT = Path(__file__).resolve().parents[1]


def main():
    outputs = [ROOT / 'features/enemies/invoker_frames.tres', ROOT / 'features/enemies/skimmer_frames.tres']
    if any(path.exists() for path in outputs):
        raise SystemExit('Frames already exist; edit native resources instead of regenerating.')
    manifest_path = ROOT / 'assets/manifest.json'
    records = json.loads(manifest_path.read_text(encoding='utf-8'))

    def copy(source, destination, pack, relative, url, license_status):
        target = ROOT / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        records.append(dict(file=destination, source_pack=pack, source_relative_path=relative,
                            source_url=url, sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
                            license_status=license_status))

    packs = [
        ('EVil Wizard 2', 'Sprites', 'invoker', 250,
         [('Idle', 8), ('Run', 8), ('Attack1', 8), ('Attack2', 8), ('Take hit', 3), ('Death', 7)],
         'https://luizmelo.itch.io/evil-wizard-2'),
        ('Monsters Creatures Fantasy 2', 'Bat', 'skimmer', 87,
         [('fly', 11), ('attack', 11), ('hurt', 3), ('fly-to-fall', 3), ('fall', 5), ('death', 4)],
         'https://luizmelo.itch.io/monsters-creatures-fantasy-2'),
    ]
    wizard_license = ROOT / 'artifacts/downloads/EVil Wizard 2/License.txt'
    if 'Creative Commons Zero' not in wizard_license.read_text(encoding='utf-8-sig'):
        raise ValueError('Missing original wizard CC0 declaration')
    cached_author = ROOT / 'artifacts/monsters_two_author.html'
    if 'CC0' not in cached_author.read_text(encoding='utf-8'):
        raise ValueError('Missing cached author license evidence for Bat')
    for pack, folder, prefix, size, sheets, url in packs:
        textures = {}
        clips = []
        for name, count in sheets:
            source = ROOT / 'artifacts/downloads' / pack / folder / (name + '.png')
            data = source.read_bytes()
            if data[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', data[16:24]) != (size * count, size):
                raise ValueError('Unexpected sheet: ' + str(source))
            key = name.lower().replace(' ', '_').replace('-', '_')
            destination = f'assets/characters/{prefix}_{key}.png'
            copy(source, destination, pack + ' by LuizMelo', folder + '/' + name + '.png', url,
                 f'CC0; see assets/licenses/{prefix}_license.txt')
            textures[key] = destination
            clips.append((key, frames(key, *range(count)), key in ('idle', 'run', 'fly', 'fall')))
        sprite_frames(outputs[0 if prefix == 'invoker' else 1], textures, clips, size, size)
    copy(wizard_license, 'assets/licenses/invoker_license.txt', 'Evil Wizard 2 by LuizMelo',
         'License.txt', packs[0][-1], 'Original pack CC0 declaration')
    # This is a project provenance note, explicitly not an original pack license file.
    note = ROOT / 'assets/licenses/skimmer_license.txt'
    note.write_text('Monsters Creatures Fantasy 2 / Bat — LuizMelo\n'
                    'Source: https://luizmelo.itch.io/monsters-creatures-fantasy-2\n'
                    'Author page verified 2026-09-27: CC0; commercial and non-commercial use.\n'
                    'The downloaded pack contains no separate license text. This is a project\n'
                    'provenance note, not an original license document. Local author-page evidence:\n'
                    'artifacts/monsters_two_author.html\n'
                    'Evidence SHA-256: ' + hashlib.sha256(cached_author.read_bytes()).hexdigest() + '\n',
                    encoding='utf-8')
    records.append(dict(file='assets/licenses/skimmer_license.txt', source_pack=packs[1][0],
                        source_relative_path='Project-authored provenance note', source_url=packs[1][-1],
                        sha256=hashlib.sha256(note.read_bytes()).hexdigest(),
                        license_status='CC0 as stated on the original author page; provenance note'))
    manifest_path.write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Imported 12 unchanged sheets, two native frame resources and license evidence.')


if __name__ == '__main__':
    main()
