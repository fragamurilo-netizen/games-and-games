"""Prepare isolated lighting-only copies of the active PortraitView renderer.
The game source is read, never overwritten. Geometry/identity/detail code is unchanged.
"""
from pathlib import Path
import difflib
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scripts/ui/components/portrait_view.gd'
TARGET = ROOT / 'tools/lighting_runtime'
TARGET.mkdir(exist_ok=True)
OUT = ROOT.parent / 'face-lighting'
OUT.mkdir(exist_ok=True)
original = SOURCE.read_text(encoding='utf-8')
variants = [
    dict(id='01_frontal_suave', label='Frontal suave', light='Vector3(-0.12, -0.18, 0.976)', ambient=0.65, diffuse=0.42, specular=0.55, key_x=0.20, key_y=0.38, warmth=0.03, shade=0.045, rim=0.14, shoulder=0.11, warm_color='Color(1.0, 0.97, 0.92,'),
    dict(id='02_estudio_equilibrado', label='Estúdio equilibrado', light='Vector3(-0.36, -0.32, 0.88)', ambient=0.58, diffuse=0.49, specular=0.60, key_x=0.65, key_y=0.65, warmth=0.045, shade=0.075, rim=0.18, shoulder=0.14, warm_color='Color(1.0, 0.95, 0.87,'),
    dict(id='03_quente_discreta', label='Quente discreta', light='Vector3(-0.24, -0.25, 0.93)', ambient=0.62, diffuse=0.45, specular=0.60, key_x=0.45, key_y=0.55, warmth=0.13, shade=0.065, rim=0.16, shoulder=0.12, warm_color='Color(1.0, 0.87, 0.72,'),
    dict(id='04_lateral_volume', label='Lateral com volume', light='Vector3(-0.63, -0.26, 0.73)', ambient=0.48, diffuse=0.60, specular=0.60, key_x=1.25, key_y=0.55, warmth=0.035, shade=0.11, rim=0.25, shoulder=0.18, warm_color='Color(1.0, 0.96, 0.91,'),
]

def once(text: str, old: str, new: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'Expected one lighting anchor, found {count}: {old!r}')
    return text.replace(old, new, 1)

for index, p in enumerate(variants, 1):
    source = once(original, 'class_name PortraitView', f'class_name LightingPreviewPortrait{index}')
    source = once(source, 'const LIGHT := Vector3(-0.4, -0.5, 0.77)', f'const LIGHT := {p["light"]}')
    source = once(source, 'var lum := 0.56 + 0.5 * diff', f'var lum := {p["ambient"]} + {p["diffuse"]} * diff')
    source = once(source, 'spec *= k[13] *', f'spec *= {p["specular"]} * k[13] *')
    source = once(source, 'var key := _hc + Vector2(-_fw * 0.9, -_fh * 0.9)', f'var key := _hc + Vector2(-_fw * {p["key_x"]}, -_fh * {p["key_y"]})')
    source = once(source, 'var warm := Color(1.0, 0.92, 0.8, 0.1 *', f'var warm := {p["warm_color"]} {p["warmth"]} *')
    source = once(source, 'var shade := 0.12 * smoothstep(0.55, 1.35, fall)', f'var shade := {p["shade"]} * smoothstep(0.55, 1.35, fall)')
    source = once(source, 'Color(0.8, 0.88, 1.0, 0.28 * smoothstep', f'Color(0.8, 0.88, 1.0, {p["rim"]} * smoothstep')
    source = once(source, 'Color(0.8, 0.88, 1.0, 0.22 * (1.0 - smoothstep', f'Color(0.8, 0.88, 1.0, {p["shoulder"]} * (1.0 - smoothstep')
    (TARGET / (p['id'] + '.gd')).write_text(source, encoding='utf-8')
    diff = ''.join(difflib.unified_diff(original.splitlines(True), source.splitlines(True), fromfile='original/portrait_view.gd', tofile=p['id'] + '/portrait_view.gd'))
    (OUT / (p['id'] + '.patch')).write_text(diff, encoding='utf-8')

manifest = dict(source_commit='0721da80a98148912aa954101185cf6531633e5b', source_path=str(SOURCE.relative_to(ROOT)), source_sha256=hashlib.sha256(original.encode()).hexdigest(), renderer='Active 2D PortraitView', variants=variants, notes='Lighting-only copies. Same FaceGen features, geometry, outfit, drawing detail and cache rules. No game production files changed. 3DStudio is NOT the active portrait path and is not used for these images.')
(OUT / 'lighting-parameters.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
print('Prepared four isolated copies of the active 2D renderer.')
