#!/usr/bin/env python3
# Renders app/res/moonlight-macos.svg into app/moonlight.icns
# Requires PyQt5 (brew install pyqt@5) and iconutil (ships with macOS)

import os
import shutil
import subprocess
import sys
import tempfile

from PyQt5.QtCore import QRectF, Qt
from PyQt5.QtGui import QGuiApplication, QImage, QPainter
from PyQt5.QtSvg import QSvgRenderer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "app", "res", "moonlight-macos.svg")
OUTPUT = os.path.join(ROOT, "app", "moonlight.icns")

app = QGuiApplication(sys.argv[:1] + ["-platform", "offscreen"])
renderer = QSvgRenderer(SOURCE)
if not renderer.isValid():
    sys.exit(f"Unable to load {SOURCE}")

iconset = os.path.join(tempfile.mkdtemp(), "moonlight.iconset")
os.makedirs(iconset)

for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        px = size * scale
        image = QImage(px, px, QImage.Format_ARGB32_Premultiplied)
        image.fill(Qt.transparent)
        painter = QPainter(image)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setRenderHint(QPainter.SmoothPixmapTransform)
        renderer.render(painter, QRectF(0, 0, px, px))
        painter.end()
        suffix = "@2x" if scale == 2 else ""
        image.save(os.path.join(iconset, f"icon_{size}x{size}{suffix}.png"))

subprocess.check_call(["iconutil", "-c", "icns", iconset, "-o", OUTPUT])
shutil.rmtree(os.path.dirname(iconset))
print(f"Wrote {OUTPUT}")
