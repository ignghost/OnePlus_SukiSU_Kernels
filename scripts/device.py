#!/usr/bin/env python3
import argparse
from pathlib import Path
import yaml

p=argparse.ArgumentParser()
p.add_argument("--device",required=True)
p.add_argument("--config",required=True)
p.add_argument("--output",required=True)
a=p.parse_args()

db=yaml.safe_load(Path(a.config).read_text())["devices"]
x=db.get(a.device)
if not x:
    raise SystemExit(f"Unknown device: {a.device}")
if x.get("status") != "supported":
    raise SystemExit(f"{a.device} is not currently supported/verified.")
for k in ("manifest_branch","manifest"):
    if not x.get(k):
        raise SystemExit(f"{a.device}: missing {k}")

with open(a.output,"w") as f:
    f.write(f"DEVICE_ID={a.device}\n")
    f.write(f"DEVICE_NAME={x['name']}\n")
    f.write(f"CPU={x['cpu']}\n")
    f.write(f"MANIFEST_BRANCH={x['manifest_branch']}\n")
    f.write(f"MANIFEST={x['manifest']}\n")
    f.write(f"ARTIFACT_NAME={a.device}-sukisu-susfs\n")
