#!/usr/bin/env python3
from pathlib import Path
from urllib.request import urlopen

BAR_RAW = "https://raw.githubusercontent.com/beyond-all-reason/Beyond-All-Reason/master/objects3d/Units"
MODELS = {
    "armafus.s3o": "armuwafus.s3o",
    "corafus.s3o": "coruwafus.s3o",
    "legafus.s3o": "leguwafus.s3o",
}

root = Path(__file__).resolve().parents[1]
outdir = root / "objects3d" / "Units"
outdir.mkdir(parents=True, exist_ok=True)

for source, target in MODELS.items():
    data = urlopen(f"{BAR_RAW}/{source}", timeout=60).read()
    if not data.startswith(b"Spring unit"):
        raise RuntimeError(f"{source}: downloaded file is not an S3O")
    path = outdir / target
    path.write_bytes(data)
    print(f"{target}: {len(data)} bytes copied from BAR {source}")
