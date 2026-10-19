#!/usr/bin/env python3
"""Build a macOS .icns from a 1024px PNG without iconutil (works on Linux).

Usage: make_icns.py icon-1024.png out.icns
"""
import io
import struct
import sys

from PIL import Image

# (OSType, pixel size) — PNG-encoded entries understood by macOS 10.7+.
ENTRIES = [
    ("icp4", 16), ("ic11", 32),    # 16pt @1x/@2x
    ("icp5", 32), ("ic12", 64),    # 32pt @1x/@2x
    ("ic07", 128), ("ic13", 256),  # 128pt @1x/@2x
    ("ic08", 256), ("ic14", 512),  # 256pt @1x/@2x
    ("ic09", 512), ("ic10", 1024), # 512pt @1x/@2x
]


def main(src, dst):
    master = Image.open(src).convert("RGBA")
    if master.size != (1024, 1024):
        sys.exit(f"{src}: expected 1024x1024, got {master.size}")
    chunks = b""
    for ostype, px in ENTRIES:
        img = master if px == 1024 else master.resize((px, px), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, "PNG", optimize=True)
        data = buf.getvalue()
        chunks += ostype.encode() + struct.pack(">I", len(data) + 8) + data
    with open(dst, "wb") as f:
        f.write(b"icns" + struct.pack(">I", len(chunks) + 8) + chunks)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
