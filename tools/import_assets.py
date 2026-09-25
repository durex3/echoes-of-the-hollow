"""Copy only referenced source assets. Never modifies the source pack."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / 'Godot 4《类银河恶魔城锻造坊》资源目录(1)'
FILES = {
    'hero.png': 'characters/hero.png',
    'slime.png': 'characters/slime.png',
    'Metroidvania_Forge_Living_Armor.png': 'characters/living_armor.png',
    'DoomScribe-SpriteSheet.png': 'characters/doom_scribe.png',
    'DoomScribe-AttackSheet.png': 'effects/ink_bolt.png',
    'forgotten_forest_example_tileset.png': 'environment/forest.png',
    'save_point.png': 'props/save_point.png',
    'abilities.png': 'props/abilities.png',
    'weapon_smears.png': 'effects/weapon_smears.png',
    'alagard.ttf': 'fonts/alagard.ttf',
    'forest_01.ogg': 'audio/forest.ogg',
    'dungeon_01.ogg': 'audio/dungeon.ogg',
    'jump.wav': 'audio/jump.wav',
    'attack.wav': 'audio/attack.wav',
    'hit.wav': 'audio/hit.wav',
    'slime_death.wav': 'audio/slime_death.wav',
    'ability_acquire.wav': 'audio/ability_acquire.wav',
    'ui_success_audio.wav': 'audio/save.wav',
}

def main():
    manifest = []
    for filename, relative in FILES.items():
        candidates = list(SOURCE.rglob(filename))
        if len(candidates) != 1:
            raise RuntimeError(f'Expected exactly one source: {filename}')
        source = candidates[0]
        target = ROOT / 'assets' / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_bytes() != source.read_bytes():
            raise RuntimeError(f'Refusing to overwrite modified asset: {target}')
        shutil.copy2(source, target)
        manifest.append({'file': 'assets/' + relative,
                         'source_pack': SOURCE.name,
                         'source_relative_path': source.relative_to(SOURCE).as_posix(),
                         'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                         'license_status': 'Not supplied in extracted chapter pack; verify before distribution.'})
    (ROOT / 'assets' / 'manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Copied and hashed {len(manifest)} assets.')

if __name__ == '__main__':
    main()
