"""Apply the authored line edits, with exact before/after hashes and a path allowlist.
This is a transport mechanism for a locally validated changeset, not generated game code.
No credentials, player saves, production releases or other branches are modified.
"""
from pathlib import Path, PurePosixPath
import base64
import hashlib
import json
import lzma

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = "80d32c1756cbbc6ef52f19007a77220b5ea2259ce7ce622d0d2ae258620b90d6"
parts = sorted((ROOT / ".ci/depth-edits").glob("part-*.b64"))
assert len(parts) == 6, "Incomplete source transport"
encoded = "".join(p.read_text().strip() for p in parts)
compressed = base64.b64decode(encoded, validate=True)
assert hashlib.sha256(compressed).hexdigest() == EXPECTED, "Source transport checksum mismatch"
edits = json.loads(lzma.decompress(compressed))
assert len(edits) == 39, "Unexpected file count"
allowed_prefixes = ("mais-uma-rodada/scripts/", "mais-uma-rodada/tests/", "mais-uma-rodada/data/")
allowed_exact = {"mais-uma-rodada/project.godot", "mais-uma-rodada/export_presets.cfg", "docs/DEPTH-0.5.0.md"}
prepared = []
seen = set()
for item in edits:
    name = item["path"]
    path = PurePosixPath(name)
    assert not path.is_absolute() and ".." not in path.parts
    assert name in allowed_exact or name.startswith(allowed_prefixes), name
    assert name not in seen, "Duplicate source path"
    seen.add(name)
    file = ROOT / name
    assert not file.is_symlink(), "Symlink source not allowed"
    old = file.read_bytes() if file.exists() else b""
    digest = hashlib.sha256(old).hexdigest()
    if digest == item["after"]:
        prepared.append((file, old))
        continue
    assert digest == item["before"], "Base source changed: " + name
    lines = old.decode("utf-8").splitlines(keepends=True)
    previous = len(lines) + 1
    for start, end, value in reversed(item["edits"]):
        assert 0 <= start <= end <= len(lines) and end <= previous, name
        lines[start:end] = value.splitlines(keepends=True)
        previous = start
    new = "".join(lines).encode("utf-8")
    assert hashlib.sha256(new).hexdigest() == item["after"], "Result checksum mismatch: " + name
    prepared.append((file, new))
# No partial writes before ALL originals and outputs have been checked.
for file, content in prepared:
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_bytes(content)
validation = ROOT / "validation"
validation.mkdir(exist_ok=True)
(validation / "source-files.json").write_text(json.dumps([{k: item[k] for k in ("path", "before", "after")} for item in edits], indent=2))
(validation / "source-paths.txt").write_text("\n".join(item["path"] for item in edits) + "\n")
print("DEPTH_SOURCE_APPLIED", len(prepared), "files, all hashes verified")
