"""Import approved enemy art. PNGs stay byte-identical; native resources stay editable.

Run with --rebuild-frames only when deliberately replacing reviewed SpriteFrames.
Source folders are kept under artifacts/downloads and are never modified.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import struct

ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = ROOT / "artifacts" / "downloads"


def sprite_frames(path, textures, clips, width, height, columns=0, crop=None):
    """clips: name, [(texture key, frame index)], loop; deduplicate AtlasTextures."""
    used = sorted({frame for _, frames, _ in clips for frame in frames})
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(textures) + len(used)} format=3]', ""]
    for key, image in textures.items():
        lines += [f'[ext_resource type="Texture2D" path="res://{image}" id="{key}"]']
    lines.append("")
    for key, index in used:
        col, row = (index % columns, index // columns) if columns else (index, 0)
        x, y, w, h = col * width, row * height, width, height
        if crop and index in crop:
            dx, dy, w, h = crop[index]
            x, y = x + dx, y + dy
        lines += [f'[sub_resource type="AtlasTexture" id="{key}_{index}"]',
                  f'atlas = ExtResource("{key}")', f"region = Rect2({x}, {y}, {w}, {h})", ""]
    lines += ["[resource]", "animations = ["]
    for name, frames, loop in clips:
        refs = ", ".join(f'{{"duration": 1.0, "texture": SubResource("{key}_{index}")}}'
                         for key, index in frames)
        lines.append(f'{{"name": &"{name}", "loop": {str(loop).lower()}, "speed": 10.0, "frames": [{refs}]}},')
    lines += ["]", ""]
    path.write_text("\n".join(lines), encoding="utf-8")


def frames(key, *indices):
    return [(key, index) for index in indices]


def import_pack(folder_name, prefix, sheets, width, height, manifest):
    folder = DOWNLOADS / folder_name
    license_source = folder / "License.txt"
    if "Creative Commons Zero" not in license_source.read_text(encoding="utf-8-sig"):
        raise ValueError(f"CC0 terms missing in {folder_name}")
    url = "https://luizmelo.itch.io/" + folder_name.lower().replace(" ", "-")
    textures = {}
    for sheet, count in sheets.items():
        source = folder / "Sprites" / f"{sheet}.png"
        header = source.read_bytes()[:24]
        if header[:8] != b"\x89PNG\r\n\x1a\n" or struct.unpack(">II", header[16:24]) != (width * count, height):
            raise ValueError(f"Unexpected sheet dimensions: {source}")
        key = sheet.lower()
        target = f"assets/characters/{prefix}_{key}.png"
        shutil.copy2(source, ROOT / target)
        textures[key] = target
        manifest[target] = {"file": target, "source_pack": folder_name,
                            "source_relative_path": f"Sprites/{sheet}.png", "source_url": url,
                            "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                            "license_status": f"CC0; see assets/licenses/{prefix}_license.txt"}
    license_target = f"assets/licenses/{prefix}_license.txt"
    (ROOT / license_target).parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(license_source, ROOT / license_target)
    manifest[license_target] = {"file": license_target, "source_pack": folder_name,
                               "source_relative_path": "License.txt", "source_url": url,
                               "sha256": hashlib.sha256(license_source.read_bytes()).hexdigest(),
                               "license_status": "Original license declaration supplied with pack (CC0)"}
    return textures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rebuild-frames", action="store_true",
                        help="Explicitly overwrite the four reviewed native SpriteFrames resources")
    args = parser.parse_args()
    outputs = ["features/enemies/warden_frames.tres", "features/enemies/rose_frames.tres",
               "features/enemies/furnace_frames.tres", "features/combat/furnace_flame_frames.tres"]
    if not args.rebuild_frames and any((ROOT / path).exists() for path in outputs):
        parser.error("Native frames already exist; edit in Godot or explicitly use --rebuild-frames.")
    manifest_path = ROOT / "assets/manifest.json"
    manifest = {entry["file"]: entry for entry in json.loads(manifest_path.read_text(encoding="utf-8"))}
    king = import_pack("Medieval King Pack 2", "warden",
                       {"Idle": 8, "Run": 8, "Attack1": 4, "Attack3": 4, "Death": 6},
                       160, 111, manifest)
    warrior = import_pack("Medieval Warrior Pack 2", "rose",
                          {"Idle": 8, "Run": 8, "Attack3": 4, "Death": 6},
                          150, 150, manifest)
    # Remove only obsolete manifest records from the earlier, incomplete import.
    for obsolete in ["assets/characters/warden_attack2.png", "assets/characters/rose_attack1.png"]:
        manifest.pop(obsolete, None)
    sprite_frames(ROOT / outputs[0], king, [
        ("idle", frames("idle", *range(8)), True),
        ("walk", frames("run", *range(8)), True),
        ("windup", frames("attack1", 0, 1), False),
        ("strike", frames("attack1", 2), False),
        ("recover", frames("attack1", 3) + frames("idle", 0), False),
        ("rush_windup", frames("attack3", 0, 1), False),
        ("rush_strike", frames("attack3", 2), False),
        ("rush_recover", frames("attack3", 3) + frames("idle", 0), False),
        ("death", frames("death", *range(6)), False),
    ], 160, 111)
    sprite_frames(ROOT / outputs[1], warrior, [
        ("idle", frames("idle", *range(8)), True),
        ("step", frames("run", *range(8)), True),
        ("warning", frames("attack3", 0, 1), False),
        ("strike", frames("attack3", 2), False),
        ("recover", frames("attack3", 3) + frames("idle", 0), False),
        ("death", frames("death", *range(6)), False),
    ], 150, 150)
    pink = {"pink": "assets/characters/rose_sentinel.png"}
    sprite_frames(ROOT / outputs[2], pink, [
        ("idle", frames("pink", *range(6)), True),
        ("wave_warning", frames("pink", 21, 22), False),
        ("wave_cast", frames("pink", 23, 24), False),
        ("wave_recover", frames("pink", 25, 26, 27, 0, 1, 2), False),
        ("takeoff", frames("pink", 14, 15, 16, 17), False),
        ("eruption_warning", frames("pink", 29, 30, 31), False),
        ("eruption_cast", frames("pink", 32, 33, 34, 35), False),
        ("landing", frames("pink", 18, 19), False),
        ("eruption_recover", frames("pink", 28, 0, 1, 2, 3, 4), False),
        ("transition", frames("pink", 29, 30, 31, 32, 33, 34, 35), False),
        ("death", frames("pink", *range(36, 48)), False),
    ], 80, 80, columns=8)
    sprite_frames(ROOT / outputs[3], {"flame": "assets/effects/furnace_flame.png"}, [
        ("wave", frames("flame", 9, 10, 11, 12), True),
        ("eruption", frames("flame", 0, 1, 2, 3, 4), False),
        ("dissipate", frames("flame", 5, 6, 7, 8), False),
    ], 128, 128, columns=5, crop={i: (60, 0, 68, 128) for i in range(9, 13)})
    manifest_path.write_text(json.dumps(list(manifest.values()), ensure_ascii=False, indent=2) + "\n",
                             encoding="utf-8")


if __name__ == "__main__":
    main()
