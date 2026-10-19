#!/usr/bin/env python3
"""Link wrapper for macOS builds.

Recent macOS SDKs no longer ship AGL.framework, but Qt's framework metadata
still passes "-framework AGL". AGL is legacy and not used by this application,
so strip it before invoking the real compiler driver.
"""

import os
import sys

def main():
    args = sys.argv[1:]
    if not args:
        sys.stderr.write("usage: link-macos.py <compiler> [args...]\n")
        return 1

    filtered = []
    i = 0
    while i < len(args):
        if args[i] == "-framework" and i + 1 < len(args) and args[i + 1] == "AGL":
            i += 2
            continue
        filtered.append(args[i])
        i += 1

    os.execvp(filtered[0], filtered)
    return 1

if __name__ == "__main__":
    sys.exit(main())
