"""Generate reproducible real engine replays (run after Godot --editor --headless --import)."""
from pathlib import Path
import argparse
import json
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCENARIOS = [
    ('sim_pressure', 'Simulação · boxe × jiu-jítsu', dict(seed=0,red='ftr_carter',blue='ftr_moreira',organization='org_crown',rounds=3)),
    ('sim_exchange', 'Simulação · pressão e interrupção', dict(seed=5,red='ftr_carter',blue='ftr_moreira',organization='org_iron',rounds=5)),
    ('sim_women', 'Simulação · Costa × Markovic', dict(seed=3,red='ftr_costa',blue='ftr_markovic',organization='org_shinsei',rounds=3)),
    ('sim_distance', 'Simulação · Arsanov × Sato', dict(seed=32,red='ftr_arsanov',blue='ftr_sato',organization='org_frontline',rounds=3)),
]


def canonical(value):
    """Round floats so fixtures do not depend on the platform's last-digit libm/printf behaviour."""
    if isinstance(value, float):
        return round(value, 6)
    if isinstance(value, list):
        return [canonical(v) for v in value]
    if isinstance(value, dict):
        return {k: canonical(v) for k, v in value.items()}
    return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    index = []
    with tempfile.TemporaryDirectory(prefix='fight-fixtures-') as directory:
        config = Path(directory) / 'config.json'
        for name, title, values in SCENARIOS:
            config.write_text(json.dumps(values), encoding='utf-8')
            result = ROOT / 'game/content/replays' / (name + '.json')
            result.unlink(missing_ok=True)
            run = subprocess.run([args.godot,'--headless','--path',str(ROOT/'game'),'-s','res://tools/preview_fight.gd','--',str(config),str(result)], capture_output=True, text=True, encoding='utf-8', errors='replace')
            # A -s script has no autoloads, so scripts naming EventBus fail to compile in
            # this process only; the fight path does not use them. Any other error is fatal.
            errors = [l for l in run.stderr.splitlines() if 'SCRIPT ERROR' in l and 'Identifier not found: EventBus' not in l and 'Failed to compile depended scripts' not in l]
            if run.returncode or errors or not result.exists():
                raise RuntimeError(run.stdout + run.stderr)
            # Canonical JSON makes comparison independent of Godot dictionary formatting.
            log = canonical(json.loads(result.read_text(encoding='utf-8')))
            log['title'] = title
            result.write_text(json.dumps(log,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n',encoding='utf-8')
            index.append(dict(id=name,title=title,file=name+'.json'))
            print(name, log['result']['method'], log['result']['detail'],len(log['events']))
    (ROOT/'game/content/replays/simulated_index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__':
    main()
