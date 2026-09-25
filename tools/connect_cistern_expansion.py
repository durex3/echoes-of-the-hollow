"""Surgical one-time chapter connection patch; leaves authored Terrain intact."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def change(room_id):
    path = ROOT / f'features/world/rooms/{room_id}.tscn'
    text = path.read_text(encoding='utf-8')
    terrain = re.search(r'\[node name="Terrain"[^\[]+',text).group()
    if 'name="ExpansionMarker"' in text:
        raise SystemExit(f'{room_id} already updated; edit scene directly')
    # Preserve external IDs, replace the old enemy resources and instance overrides.
    for old, new in [('living_armor','rose_sentinel'),('armor_config','rose_config'),('doom_scribe','winged_chest'),('scribe_config','chest_config')]:
        text = text.replace(f'enemies/{old}.',f'enemies/{new}.')
    text = text.replace('name="LivingArmor"','name="RoseSentinel"').replace('name="DoomScribe"','name="WingedChest"')
    script = re.search(r'path="res://features/world/interaction.gd" id="([^"]+)"',text)[1]
    texture = re.search(r'path="res://assets/props/door_and_switch.png" id="([^"]+)"',text)[1]

    def marker(name,x,y):
        return f'\n[node name="{name}" type="Marker2D" parent="Spawns"]\nposition = Vector2({x}, {y})\n'

    def door(name,x,y,target,spawn,prompt,flag=''):
        result = f'\n[node name="{name}" type="Node2D" parent="Interactions"]\nposition = Vector2({x}, {y})\nscript = ExtResource("{script}")\nkind = "exit"\ntarget_room = "{target}"\ntarget_spawn = "{spawn}"\nprompt = "{prompt}"\n'
        if flag:
            result += f'required_flag = "{flag}"\n'
        result += f'\n[node name="ForgeDoor" type="Sprite2D" parent="Interactions/{name}"]\nposition = Vector2(0, -32)\nscale = Vector2(2, 2)\ntexture = ExtResource("{texture}")\nregion_enabled = true\nregion_rect = Rect2(0, 0, 32, 32)\n'
        return result

    if room_id in ('valve_gallery','cistern_archive'):
        # Move rewards into branch depths. Keep the old shortcut for compatible saves.
        text = re.sub(r'\[node name="Seal"[^\[]+', '', text)
    if room_id == 'valve_gallery':
        text += door('ShaftDoor',1100,352,'sluice_shaft','entry','E / DESCEND INTO THE SLUICE SHAFT')
        text += marker('shaft_return',1050,352)
    elif room_id == 'cistern_archive':
        text += door('PumpDoor',1150,480,'pump_chamber','entry','E / DESCEND INTO THE LOWER PUMP')
        text += door('ShaftDoor',862,416,'sluice_shaft','archive_return','E / TAKE THE SLUICE SERVICE PASSAGE','flow_seal')
        text += marker('pump_return',1100,480)+marker('shaft_return',854,416)
        text = text.replace('Dry stone blocks ink. Fight away from the steam.','Pink flame steps back, then slashes. Jump or interrupt it.')
        # Teaching before first duelist, not after the encounter.
        text = text.replace('position = Vector2(770, 480)','position = Vector2(480, 480)')
    elif room_id == 'ember_quay':
        text += door('PumpShortcut',925,480,'pump_chamber','quay_return','E / TAKE THE LOWER PUMP SHORTCUT','pressure_seal')
        text += marker('pump_return',925,480)
        text = text.replace('Two branches, two valve seals. Return here to open the core.','Explore beyond the gallery and archive. Valves open return routes.')
    elif room_id == 'furnace_core':
        text = text.replace('Draw guardians onto dry ground. Restore the core after battle.','Chest bites, pink flame slashes. Use dry ground between steam jets.')
    text += '\n[node name="ExpansionMarker" type="Node" parent="."]\n'
    assert re.search(r'\[node name="Terrain"[^\[]+',text).group() == terrain
    path.write_text(text,encoding='utf-8',newline='\n')


for room in ('ember_quay','valve_gallery','cistern_archive','furnace_core'):
    change(room)
