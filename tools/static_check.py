"""Dependency-free project conventions and resource integrity checks."""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
required = ['project.godot', 'README.md', 'AGENTS.md', 'CHANGELOG.md',
            'docs/architecture.md', 'docs/development-workflow.md', 'docs/testing.md',
            'docs/game-design.md', 'docs/roadmap.md', 'docs/skill-map.md',
            'tests/test_runner.tscn', 'assets/manifest.json']
for relative in required:
    if not (ROOT / relative).is_file():
        errors.append(f'Missing required file: {relative}')
for folder in ['app', 'core', 'features', 'tests']:
    for path in (ROOT / folder).rglob('*'):
        if path.suffix not in ['.gd', '.tscn', '.tres']:
            continue
        body = path.read_text(encoding='utf-8')
        relative = path.relative_to(ROOT)
        if not body.endswith('\n'):
            errors.append(f'Missing final newline: {relative}')
        if not re.fullmatch(r'[a-z0-9_]+', path.stem):
            errors.append(f'Non-snake-case filename: {relative}')
        for reference in re.findall(r'(?:path=|preload\(|load\()"res://([^"%]+)"', body):
            if not (ROOT / reference).is_file():
                errors.append(f'Broken resource reference {relative}: {reference}')
        if re.search(r'[A-Z]:[\\/]', body):
            errors.append(f'Absolute machine path in runtime content: {relative}')
        if path.suffix == '.gd':
            for index, line in enumerate(body.splitlines(), 1):
                if line.rstrip() != line:
                    errors.append(f'Trailing whitespace: {relative}:{index}')
                if line.startswith('    '):
                    errors.append(f'Use tabs for GDScript indentation: {relative}:{index}')

# Enemy bodies collide with terrain only; contact and attacks scan the player Hurtbox.
for path in (ROOT / 'features/enemies').glob('*.tscn'):
    body = path.read_text(encoding='utf-8')
    for node in re.split(r'(?=^\[node )', body, flags=re.MULTILINE):
        header = node.split('\n', 1)[0]
        if 'type="CharacterBody2D"' in header and 'groups=["enemies"]' in header:
            if not re.search(r'^collision_layer = 0$', node, re.MULTILINE) or not re.search(r'^collision_mask = 1$', node, re.MULTILINE):
                errors.append(f'Enemy body must scan terrain only: {path.relative_to(ROOT)}')
        elif 'type="Area2D"' in header and 'Hurtbox' not in header:
            if not re.search(r'^collision_layer = 0$', node, re.MULTILINE) or not re.search(r'^collision_mask = 8$', node, re.MULTILINE):
                errors.append(f'Enemy damage area must scan player Hurtbox: {path.relative_to(ROOT)}')
for path in (ROOT / 'features/world/rooms').glob('*.tscn'):
    body = path.read_text(encoding='utf-8')
    for node in re.split(r'(?=^\[node )', body, flags=re.MULTILINE):
        header = node.split('\n', 1)[0]
        if 'groups=["enemies"]' in header and 'instance=' in header:
            if re.search(r'^collision_layer = (?!0$)\d+', node, re.MULTILINE) or re.search(r'^collision_mask = (?!1$)\d+', node, re.MULTILINE):
                errors.append(f'Room overrides enemy terrain-only collision: {path.relative_to(ROOT)}')
manifest = json.loads((ROOT / 'assets/manifest.json').read_text(encoding='utf-8'))
for entry in manifest:
    path = ROOT / entry['file']
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
        errors.append(f'Asset differs from recorded source: {entry["file"]}')
for error in errors:
    print('FAIL:', error)
print(f'STATIC_RESULT: {len(errors)} errors; {len(manifest)} asset hashes verified')
sys.exit(bool(errors))
