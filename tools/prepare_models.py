"""Extract Cactus model zips into an adb-pushable layout.

Usage: python tools/prepare_models.py <staging_dir>
Expects in <staging_dir>: gemma3-1b.zip, whisper-base-int8.zip
Produces: <staging_dir>/models/gemma3-1b/..., <staging_dir>/models/whisper-base/...
"""
import sys
import zipfile
from pathlib import Path

MODELS = {"gemma3-1b.zip": "gemma3-1b", "whisper-base-int8.zip": "whisper-base"}


def main(staging: Path) -> None:
    for zname, dname in MODELS.items():
        src = staging / zname
        if not src.exists():
            print(f"skip {zname}: not found")
            continue
        out = staging / "models" / dname
        out.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(src) as z:
            members = [m for m in z.namelist()
                       if not m.startswith("__MACOSX/") and not m.endswith("/")]
            for m in members:
                target = out / Path(m).name  # flatten: config.txt must be top-level
                target.write_bytes(z.read(m))
        assert (out / "config.txt").exists(), f"{dname}: config.txt missing"
        print(f"{dname}: {len(members)} files -> {out}")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
