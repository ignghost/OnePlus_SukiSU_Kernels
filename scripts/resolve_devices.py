#!/usr/bin/env python3
import argparse, json, sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML is required.", file=sys.stderr)
    sys.exit(1)

p = argparse.ArgumentParser()
p.add_argument("--mode", required=True)
p.add_argument("--device", default="")
p.add_argument("--devices", default="")
p.add_argument("--config", required=True)
a = p.parse_args()

data = yaml.safe_load(Path(a.config).read_text())
db = data.get("devices", {})

if a.mode == "Single Device":
    selected = [a.device.strip().lower()]
elif a.mode == "Multiple Devices":
    selected = [x.strip().lower() for x in a.devices.split(",") if x.strip()]
elif a.mode == "All Supported Devices":
    selected = [k for k, v in db.items() if v.get("status") == "supported"]
else:
    print(f"Unsupported build mode: {a.mode}", file=sys.stderr)
    sys.exit(1)

selected = list(dict.fromkeys(selected))
unknown = [x for x in selected if x not in db]
unsupported = [x for x in selected if x in db and db[x].get("status") != "supported"]

if unknown:
    print("Unknown device ID(s): " + ", ".join(unknown), file=sys.stderr)
    sys.exit(1)

if unsupported:
    print("Device(s) are not marked supported yet: " + ", ".join(unsupported), file=sys.stderr)
    print("Set status: supported only after source/branch/defconfig verification.", file=sys.stderr)
    sys.exit(1)

if not selected:
    print("No devices selected.", file=sys.stderr)
    sys.exit(1)

print("Resolved devices:")
for d in selected:
    print(f"  - {d}")

matrix = json.dumps(selected, separators=(",", ":"))
github_output = Path(__import__("os").environ["GITHUB_OUTPUT"])
with github_output.open("a") as f:
    f.write(f"matrix={matrix}\n")
