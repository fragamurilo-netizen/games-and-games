"""Local Fight Studio server. POST simulations use the Godot engine, never JS combat.
python tools/fight_lab_server.py --godot /path/to/godot --port 8768
"""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
LOCK = threading.Lock()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN') or shutil.which('godot'))
    parser.add_argument('--port', type=int, default=8768)
    args = parser.parse_args()
    if not args.godot or not Path(args.godot).is_file():
        parser.error('Use --godot com o caminho do Godot 4.4.1.')
    godot = str(Path(args.godot).resolve())
    profiles = json.loads((ROOT / 'game/content/combat_profiles.json').read_text(encoding='utf-8'))['fighters']
    orgs = {x['id']: x for x in json.loads((ROOT / 'game/content/organizations.json').read_text(encoding='utf-8'))}
    styles = json.loads((ROOT / 'game/content/fight_tuning.json').read_text(encoding='utf-8'))['styles']

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *a, **kw):
            super().__init__(*a, directory=str(ROOT), **kw)

        def reply(self, status, value):
            body = json.dumps(value, ensure_ascii=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path == '/api/status':
                return self.reply(200, {'engine': 'godot', 'version': 1})
            return super().do_GET()

        def do_POST(self):
            if self.path != '/api/simulate':
                return self.reply(404, {'error': 'Rota inexistente.'})
            origin = self.headers.get('Origin')
            if origin and origin not in {f'http://127.0.0.1:{args.port}', f'http://localhost:{args.port}'}:
                return self.reply(403, {'error': 'Origem inválida.'})
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 4096:
                    raise ValueError('Configuração inválida.')
                config = json.loads(self.rfile.read(length))
                if not isinstance(config, dict):
                    raise ValueError('Configuração inválida.')
                if any(config.get(k) not in profiles for k in ['red', 'blue']) or config['red'] == config['blue']:
                    raise ValueError('Escolha dois atletas diferentes.')
                if config.get('organization') not in orgs:
                    raise ValueError('Organização inválida.')
                if type(config.get('seed')) is not int or not 0 <= config['seed'] <= 2147483647:
                    raise ValueError('Seed deve ser um inteiro entre 0 e 2147483647.')
                limit = 3 if orgs[config['organization']]['ruleset_id'] == 'shinsei_ring' else 5
                if type(config.get('rounds')) is not int or not 1 <= config['rounds'] <= limit:
                    raise ValueError(f'Esta organização aceita de 1 a {limit} rounds.')
                for key in ['red_style', 'blue_style']:
                    if config.get(key) and config[key] not in styles:
                        raise ValueError('Base marcial inválida.')
            except (ValueError, TypeError):
                return self.reply(400, {'error': 'Confira os atletas, rounds, organização, bases e seed.'})
            if not LOCK.acquire(blocking=False):
                return self.reply(409, {'error': 'Uma luta está sendo calculada. Tente novamente em instantes.'})
            try:
                with tempfile.TemporaryDirectory(prefix='corner-fight-') as directory:
                    input_file = Path(directory) / 'input.json'
                    output_file = Path(directory) / 'replay.json'
                    input_file.write_text(json.dumps(config), encoding='utf-8')
                    run = subprocess.run([godot, '--headless', '--path', str(ROOT / 'game'), '-s', 'res://tools/preview_fight.gd', '--', str(input_file), str(output_file)], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=45, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                    if run.returncode or not output_file.exists() or 'SCRIPT ERROR' in run.stderr:
                        print(run.stdout, run.stderr, flush=True)
                        return self.reply(500, {'error': 'O motor não conseguiu validar a luta. Consulte o terminal do servidor.'})
                    return self.reply(200, json.loads(output_file.read_text(encoding='utf-8')))
            except subprocess.TimeoutExpired:
                return self.reply(504, {'error': 'O motor excedeu o tempo de cálculo.'})
            finally:
                LOCK.release()

    print(f'Fight Studio: http://127.0.0.1:{args.port}/prototypes/fight-lab/', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()
