"""Local Corner Office server: Godot owns combat, career rules and saves.
python tools/fight_lab_server.py --godot /path/to/godot --port 8768
"""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit
import argparse
import json
import math
import os
import shutil
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
LOCK = threading.Lock()
ACTIONS = {'state', 'new', 'create_event', 'evaluate', 'propose', 'remove_bout',
           'announce', 'reschedule', 'advance_week', 'advance_event', 'negotiate', 'replay'}


def validate_career(config):
    if config.get('action') not in ACTIONS:
        raise ValueError('Ação desconhecida.')
    for key in ('event_id', 'fight_id', 'fighter_id', 'red', 'blue', 'name'):
        if key in config and (not isinstance(config[key], str) or len(config[key]) > 100):
            raise ValueError('Identificador ou nome inválido.')
    for key, maximum in [('seed', 2147483647), ('days', 120), ('show_money', 10000000), ('signing_bonus', 10000000)]:
        if key in config and (type(config[key]) is not int or not 0 <= config[key] <= maximum):
            raise ValueError('Valor numérico inválido.')
    if 'mode' in config and config['mode'] not in ('flagship', 'regional_promoter'):
        raise ValueError('Modo de carreira inválido.')
    if 'premium' in config and (type(config['premium']) not in (int, float) or not math.isfinite(config['premium']) or not 1 <= config['premium'] <= 2):
        raise ValueError('Multiplicador de bolsa inválido.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN') or shutil.which('godot'))
    parser.add_argument('--port', type=int, default=8768)
    parser.add_argument('--data-dir', type=Path, default=ROOT / '.local')
    args = parser.parse_args()
    if not args.godot or not Path(args.godot).is_file():
        parser.error('Use --godot com o caminho do Godot 4.4.1.')
    godot = str(Path(args.godot).resolve())
    args.data_dir.mkdir(parents=True, exist_ok=True)
    save_path = args.data_dir.resolve() / 'career.json'
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
            path = unquote(urlsplit(self.path).path)
            if any(part.startswith('.') for part in path.split('/') if part):
                return self.reply(404, {'error': 'Rota inexistente.'})
            if path == '/api/status':
                return self.reply(200, {'engine': 'godot', 'version': 1, 'career': True})
            return super().do_GET()

        def do_POST(self):
            if self.path not in ('/api/simulate', '/api/career'):
                return self.reply(404, {'error': 'Rota inexistente.'})
            origin = self.headers.get('Origin')
            if origin and origin not in {f'http://127.0.0.1:{args.port}', f'http://localhost:{args.port}'}:
                return self.reply(403, {'error': 'Origem inválida.'})
            career = self.path == '/api/career'
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 4096:
                    raise ValueError('Configuração inválida.')
                config = json.loads(self.rfile.read(length))
                if not isinstance(config, dict):
                    raise ValueError('Configuração inválida.')
                if career:
                    validate_career(config)
                else:
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
            except (ValueError, TypeError) as error:
                return self.reply(400, {'error': str(error)})
            if not LOCK.acquire(blocking=False):
                return self.reply(409, {'error': 'Uma simulação está sendo calculada. Tente novamente em instantes.'})
            try:
                if career and config['action'] == 'new' and save_path.exists() and config.get('replace') is not True:
                    return self.reply(409, {'error': 'Já existe uma carreira. Use Nova carreira para substituir.'})
                with tempfile.TemporaryDirectory(prefix='corner-office-') as directory:
                    input_file = Path(directory) / 'input.json'
                    output_file = Path(directory) / 'response.json'
                    working_save = Path(directory) / 'career.json'
                    input_file.write_text(json.dumps(config), encoding='utf-8')
                    script = 'res://tools/career_session.gd' if career else 'res://tools/preview_fight.gd'
                    paths = [str(input_file), str(output_file)]
                    if career:
                        if save_path.exists():
                            shutil.copyfile(save_path, working_save)
                        paths.append(str(working_save))
                    run = subprocess.run([godot, '--headless', '--path', str(ROOT / 'game'), '-s', script, '--', *paths], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=60, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                    if run.returncode or not output_file.exists() or 'SCRIPT ERROR' in run.stderr or 'Parse Error' in run.stderr:
                        print(run.stdout, run.stderr, flush=True)
                        return self.reply(500, {'error': 'O motor não conseguiu validar a operação. Seu save anterior foi preservado.'})
                    result = json.loads(output_file.read_text(encoding='utf-8-sig'))
                    if career and result.get('ok') and config['action'] not in ('state', 'evaluate', 'replay') and working_save.exists():
                        # Same-volume replacement; engine failure never touches the original.
                        pending = save_path.with_suffix('.pending')
                        shutil.copyfile(working_save, pending)
                        if config['action'] == 'new' and save_path.exists():
                            shutil.copyfile(save_path, save_path.with_suffix('.backup.json'))
                        os.replace(pending, save_path)
                    return self.reply(200, result)
            except subprocess.TimeoutExpired:
                return self.reply(504, {'error': 'O motor excedeu o tempo de cálculo. Save anterior preservado.'})
            finally:
                LOCK.release()

    print(f'Carreira: http://127.0.0.1:{args.port}/prototypes/promoter/', flush=True)
    print(f'Fight Studio: http://127.0.0.1:{args.port}/prototypes/fight-lab/', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()
