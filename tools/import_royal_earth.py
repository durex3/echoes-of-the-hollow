"""Import the supplied Pimen sheet without changing source pixels or frame geometry.

Uses Pillow only for this offline art conversion; the game has no dependency on it.
"""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'artifacts/python_deps'))
from PIL import Image

source = ROOT / 'artifacts/downloads/Earth Effect 02/Earth Wall.png'
destination = ROOT / 'assets/effects/royal_earth_wall.png'
expected_source = 'b267243c8c4c557a75b11203c58ed5f8f449409be6210939f6ed68293a2cc5b6'
assert hashlib.sha256(source.read_bytes()).hexdigest() == expected_source, 'Unexpected source sheet'
image = Image.open(source).convert('RGBA')
assert image.size == (192, 192)
palette = {
    (52, 28, 39, 255): (32, 39, 51, 255),
    (77, 43, 50, 255): (53, 64, 76, 255),
    (122, 72, 65, 255): (85, 97, 109, 255),
    (173, 119, 87, 255): (153, 159, 152, 255),
    (192, 148, 115, 255): (208, 184, 130, 255),
    (0, 0, 0, 0): (0, 0, 0, 0),
}
image.putdata([palette[pixel] for pixel in image.get_flattened_data()])
image.save(destination)
manifest_path = ROOT / 'assets/manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
entry = {
    'file': destination.relative_to(ROOT).as_posix(),
    'source_pack': 'Earth Spell Effect 02 by Pimen',
    'source_relative_path': 'Earth Effect 02/Earth Wall.png',
    'source_url': 'https://pimen.itch.io/earth-spell-effect-2',
    'source_sha256': expected_source,
    'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
    'modifications': 'Five-color remap to cool stone and warm highlights. Dimensions, alpha, anchors and frame geometry unchanged.',
    'license_status': 'Author-page terms allow use and modification in personal/commercial projects; no standalone resale or redistribution. See assets/licenses/royal_earth_source.txt.',
}
manifest = [item for item in manifest if item['file'] != entry['file']]
manifest.append(entry)
note = ROOT / 'assets/licenses/royal_earth_source.txt'
note_entry = {
    'file': note.relative_to(ROOT).as_posix(),
    'source_pack': 'Project provenance note for Earth Spell Effect 02 by Pimen',
    'source_relative_path': 'Author-page terms paraphrased; not an archive license file',
    'source_url': entry['source_url'],
    'sha256': hashlib.sha256(note.read_bytes()).hexdigest(),
    'license_status': 'Project-authored attribution, permitted uses and restrictions summary.',
}
manifest = [item for item in manifest if item['file'] != note_entry['file']]
manifest.append(note_entry)
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Imported', entry['file'], entry['sha256'])
