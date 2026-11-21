#!/usr/bin/env python3
"""Download and validate PandaBase's generated missing-auction-targets Lua file."""

from __future__ import annotations

import argparse
import pathlib
import urllib.request


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()

    request = urllib.request.Request(args.url, headers={"User-Agent": "pqAuction target sync"})
    with urllib.request.urlopen(request, timeout=60) as response:
        if response.status != 200:
            raise RuntimeError(f"PandaBase returned HTTP {response.status}")
        content = response.read()

    try:
        text = content.decode("utf-8")
    except UnicodeDecodeError as error:
        raise RuntimeError("PandaBase response was not UTF-8 Lua") from error
    required = ("ns.AuctionMissing = {", "ns.AuctionMissingMarkets = {")
    if not all(marker in text for marker in required):
        raise RuntimeError("PandaBase response is not a generated auction-targets Lua file")
    if len(text) < 100:
        raise RuntimeError("PandaBase response is unexpectedly short")

    args.output.write_text(text, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
