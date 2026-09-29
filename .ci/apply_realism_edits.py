"""Apply reviewed source edits without guessing at concurrent changes.
All source and result hashes are checked before the first write. Pinned older source
may be reused as a transport basis; it is not a merge-resolution heuristic.
"""
from pathlib import Path, PurePosixPath
import base64
import hashlib
import json
import lzma
import subprocess

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = "aa8763afd061bb165b86d0c5cd787ab041a68e69c63b091287cf2372c4fbb721"
PINNED = "6e3f472d6532090e73d799c1f0f6c221e97c0ec7"
parts = sorted((ROOT / ".ci/realism-edits").glob("part-*.b64"))
assert len(parts) == 3, "Incomplete source transport"
compressed = base64.b64decode("".join(p.read_text().strip() for p in parts), validate=True)
assert hashlib.sha256(compressed).hexdigest() == EXPECTED, "Transport checksum mismatch"
edits = json.loads(lzma.decompress(compressed))
assert len(edits) == 75, "Unexpected source file count"
# Formatting-only correction caught by git diff --check, after transport validation.
# This changes two excess EOF newlines, not gameplay. Both versions have pinned hashes.
for item in edits:
    if item["path"] == "mais-uma-rodada/scripts/systems/national_team_manager.gd":
        assert item["after"] == "89b5413d7f62a77b2c96af563c1790961ad8f87ff23aa1d05996b31a69a38eb0"
        assert item["edits"][-1][2].endswith("\treturn results\n\n\n")
        item["edits"][-1][2] = item["edits"][-1][2].rstrip("\n") + "\n"
        item["after"] = "3f71c7325cce13b481ab358099f089bc850f6aa9017aee6d41f361ed0806ddb5"
allowed_prefixes = ("mais-uma-rodada/scripts/", "mais-uma-rodada/tests/", "mais-uma-rodada/data/")
allowed_exact = {"mais-uma-rodada/project.godot", "mais-uma-rodada/export_presets.cfg", "docs/DEPTH-0.5.0.md", "docs/REALISM-0.5.1.md"}
prepared = []
seen = set()
for item in edits:
    name = item["path"]
    path = PurePosixPath(name)
    assert not path.is_absolute() and ".." not in path.parts
    assert name in allowed_exact or name.startswith(allowed_prefixes), name
    assert name not in seen and "\n" not in name and "\r" not in name
    seen.add(name)
    file = ROOT / name
    assert not file.is_symlink() and ROOT in file.resolve().parents
    old = file.read_bytes() if file.exists() else b""
    digest = hashlib.sha256(old).hexdigest()
    if digest == item["after"]:
        prepared.append((file, old))
        continue
    assert digest == item["before"], "Concurrent base source change: " + name
    ref = item.get("basis_ref")
    if ref is not None:
        assert ref == PINNED, "Unapproved source basis"
        basis = subprocess.check_output(["git", "show", ref + ":" + name], cwd=ROOT)
    else:
        basis = old
    assert hashlib.sha256(basis).hexdigest() == item["basis_hash"], "Basis checksum mismatch: " + name
    lines = basis.decode("utf-8").splitlines(keepends=True)
    previous = len(lines) + 1
    for start, end, value in reversed(item["edits"]):
        assert 0 <= start <= end <= len(lines) and end <= previous, name
        lines[start:end] = value.splitlines(keepends=True)
        previous = start
    new = "".join(lines).encode("utf-8")
    assert hashlib.sha256(new).hexdigest() == item["after"], "Output checksum mismatch: " + name
    prepared.append((file, new))
# Commit is a separate CI step and is permitted only after all test gates pass.
for file, content in prepared:
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_bytes(content)
validation = ROOT / "validation"
validation.mkdir(exist_ok=True)
(validation / "source-files.json").write_text(json.dumps([{k: item[k] for k in ("path", "before", "after", "basis_ref", "basis_hash")} for item in edits], indent=2))
(validation / "source-paths.txt").write_text("\n".join(item["path"] for item in edits) + "\n")
print("REALISM_SOURCE_APPLIED", len(prepared), "files, all hashes verified")
