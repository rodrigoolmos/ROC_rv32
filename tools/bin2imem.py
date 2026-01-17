#!/usr/bin/env python3
"""Convert a flat little-endian binary into 32-bit word-per-line hex for $readmemh.

- Input: raw bytes (e.g. .bin from objcopy)
- Output: text file with one 8-hex-digit word per line (little-endian packing)

This matches the CPU's 32-bit instruction fetch from word-addressed BRAM.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("bin", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--words", type=int, default=None, help="Optional fixed number of output words")
    args = ap.parse_args()

    data = args.bin.read_bytes()
    # Pad to multiple of 4 bytes
    if len(data) % 4 != 0:
        data += bytes([0] * (4 - (len(data) % 4)))

    words = []
    for i in range(0, len(data), 4):
        b0, b1, b2, b3 = data[i : i + 4]
        word = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        words.append(word)

    if args.words is not None:
        words = words[: args.words]

    args.out.write_text("\n".join(f"{w:08x}" for w in words) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
