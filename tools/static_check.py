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
manifest = json.loads((ROOT / 'assets/manifest.json').read_text(encoding='utf-8'))
for entry in manifest:
    path = ROOT / entry['file']
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
        errors.append(f'Asset differs from recorded source: {entry["file"]}')
for error in errors:
    print('FAIL:', error)
print(f'STATIC_RESULT: {len(errors)} errors; {len(manifest)} asset hashes verified')
sys.exit(bool(errors))
