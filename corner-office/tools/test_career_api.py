"""Isolated HTTP/save integration test. Never reads or resets a player's career."""
from pathlib import Path
import argparse
import hashlib
import json
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    with tempfile.TemporaryDirectory(prefix='co-api-test-') as folder:
        save = Path(folder) / 'career.json'
        with (Path(folder) / 'server.log').open('w', encoding='utf-8') as log:
            server = subprocess.Popen([sys.executable, str(root / 'tools/fight_lab_server.py'), '--godot', args.godot, '--port', str(port), '--data-dir', folder], stdout=log, stderr=log)
            try:
                base = f'http://127.0.0.1:{port}'
                for _ in range(100):
                    try:
                        urllib.request.urlopen(base + '/api/status', timeout=1).close()
                        break
                    except OSError:
                        if server.poll() is not None: raise AssertionError('Server did not start')
                        time.sleep(.05)
                def call(action, status=200, origin=None, **params):
                    headers = {'Content-Type': 'application/json'}
                    if origin: headers['Origin'] = origin
                    request = urllib.request.Request(base + '/api/career', json.dumps({'action': action, **params}).encode(), headers)
                    try: response = urllib.request.urlopen(request, timeout=90)
                    except urllib.error.HTTPError as error: response = error
                    data = json.loads(response.read())
                    assert response.status == status, (action, response.status, data)
                    if status == 200: assert data.get('ok'), (action, data.get('error'), data.get('reasons'))
                    return data
                assert not call('state')['has_save']
                world = call('new', seed=44, mode='regional_promoter')['world']
                assert len(world['fighters']) >= 100
                def digest(): return hashlib.sha256(save.read_bytes()).hexdigest()
                before = digest()
                call('new', status=409, seed=88)
                call('advance_week', status=403, origin='https://example.com')
                call('negotiate', status=400, signing_bonus=-1)
                call('state')
                assert digest() == before, 'Reads and rejected input must preserve save'
                event_id = call('create_event', name='API mixed card', days=42)['event_id']
                groups = {}
                for f in world['fighters']:
                    if f['organization_id'] == world['organization']['id']: groups.setdefault(f['division'], []).append(f['id'])
                booked = 0
                for i in range(0, 12, 2):
                    for ids in groups.values():
                        if i+1 >= len(ids) or booked >= 6: continue
                        params = dict(event_id=event_id, red=ids[i], blue=ids[i+1])
                        before = digest()
                        quote = call('evaluate', **params)['quote']
                        assert quote['eligible'] and len(quote['acceptance']) == 2
                        assert digest() == before, 'Quotes must not mutate save/RNG'
                        for premium in [1.0, 1.5, 2.0]:
                            result = call('propose', premium=premium, **params)
                            if result['proposal']['outcome'] == 'accepted': booked += 1; break
                assert booked == 6
                call('announce', event_id=event_id)
                world = call('advance_event', event_id=event_id)['world']
                event = next(e for e in world['events'] if e['id'] == event_id)
                assert event['status'] == 'completed' and len(event['fights']) == 6
                before = digest()
                for bout in event['fights']:
                    replay = call('replay', fight_id=bout['id'])['replay']
                    assert replay['source'] == 'simulation' and replay['organization_id'] == world['organization']['id']
                    assert replay['result']['method'] == bout['method']
                assert digest() == before, 'Replays are read-only'
                assert call('state')['world']['organization']['cash'] == world['organization']['cash']
                print('API passed: generated career, six mixed bouts, finance, six immutable replays, save reload and rejected requests.')
            finally:
                server.terminate()
                try: server.wait(timeout=10)
                except subprocess.TimeoutExpired: server.kill(); server.wait()

if __name__ == '__main__': main()
