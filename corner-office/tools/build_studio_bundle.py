"""Package the existing Fight Studio, byte-for-byte, for offline Android playback.
No second renderer. Deterministic gzip payload is consumed by FightReplayView.
"""
from pathlib import Path
import base64
import gzip
import json
import re

ROOT = Path(__file__).resolve().parents[1]
STUDIO = ROOT / 'prototypes/fight-lab'
def safe_json(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).replace('<', '\\u003c')

def build():
    html = (STUDIO / 'broadcast.html').read_text(encoding='utf-8')
    css = (STUDIO / 'broadcast.css').read_text(encoding='utf-8')
    def font(match):
        data = (STUDIO / match[1]).resolve().read_bytes()
        return 'url(data:font/ttf;base64,' + base64.b64encode(data).decode() + ')'
    css = re.sub(r"url\('([^']+)'\)", font, css)
    html = html.replace('<link rel="stylesheet" href="broadcast.css">', '<style>' + css + '</style>')
    payload = ''
    for key, filename in [('catalog', 'fight_visuals.json'), ('arenas', 'arena_profiles.json')]:
        data = json.loads((ROOT / 'game/content' / filename).read_text(encoding='utf-8'))
        payload += f'<script id="co-{key}" type="application/json">{safe_json(data)}</script>'
    payload += '<script id="co-replay" type="application/json">__CO_REPLAY_JSON__</script>'
    html = html.replace('<script src="broadcast.js">', payload + '<script src="broadcast.js">')
    def script(match):
        code = (STUDIO / match[1]).resolve().read_text(encoding='utf-8')
        return '<script>' + code.replace('</script', '<\\/script') + '</script>'
    html = re.sub(r'<script src="([^"]+)"></script>', script, html)
    target = ROOT / 'game/presentation/fight/studio.cobundle'
    packed = bytearray(gzip.compress(html.encode('utf-8'), mtime=0))
    packed[9] = 255  # Stable gzip OS byte across Python 3.11–3.13 / Windows / Linux.
    target.write_bytes(packed)
    print(f'Original Fight Studio bundled offline: {target.stat().st_size} bytes')
    return html

if __name__ == '__main__':
    build()
