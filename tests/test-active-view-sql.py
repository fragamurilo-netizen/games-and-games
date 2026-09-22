"""Execute the production aggregation expressions offline, using SQLite CASE semantics."""
import pathlib
import re
import sqlite3
import sys

root = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[1]
learning = (root / 'inc/ads-center/includes/class-goac-learning.php').read_text()
economics = (root / 'inc/ads/economics.php').read_text()
driver = re.search(r"function driver_viewability_sql\(\).*?return '([^']+)'", learning, re.S).group(1)
numerator = re.search(r'(SUM\(CASE[^\n]+\)) viewability_weighted', economics).group(1)
denominator = re.search(r'(SUM\(CASE[^\n]+\)) viewability_impressions', economics).group(1)
expressions = {'Data Lab': driver, 'Economics': f'{numerator}/NULLIF({denominator},0)'}
fixtures = [
    ([(.8, 1, 1000), (.2, .1, 1000)], 820 / 1100),
    ([(.8, 1, 1000), (.2, .1, 1000), (1, None, 5000), (None, .5, 3000), (1, 0, 100)], 820 / 1100),
    ([(.5, None, 100)], None),
    ([(.5, 0, 100)], None),
    ([(.5, 1.5, 100)], None),
    ([(1, 1, 0)], None),
    ([], None),
]
checks = 0
for name, expression in expressions.items():
    for values, expected in fixtures:
        with sqlite3.connect(':memory:') as db:
            db.execute('CREATE TABLE rows (viewability REAL, measurability REAL, impressions REAL)')
            db.executemany('INSERT INTO rows VALUES (?,?,?)', values)
            actual = db.execute(f'SELECT {expression} FROM rows').fetchone()[0]
        assert (actual is None if expected is None else actual is not None and abs(actual - expected) < 1e-10), (name, values, expected, actual)
        checks += 1
print(f'{checks} production SQL fixture checks passed; no ad request or Google API call.')
