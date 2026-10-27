"""Check literal res:// references in project text assets and scripts."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
files = [p for p in root.rglob("*") if p.is_file() and p.suffix in {".gd", ".tscn", ".tres", ".godot", ".import"} and ".godot" not in p.parts]
missing = []
for file in files:
    text = file.read_text(encoding="utf-8", errors="ignore")
    for path in re.findall(r"res://[A-Za-z0-9_./ -]+", text):
        path = path.rstrip(".,)")
        if "<" in path or ">" in path:
            continue
        if not (root / path[6:]).exists():
            missing.append((file.relative_to(root), path))
if missing:
    for source, path in missing:
        print(f"MISSING {source}: {path}")
    raise SystemExit(1)
print(f"RES_PATH_SCAN_OK: checked {len(files)} text files")
