#!/usr/bin/env python3
import re
import sys
from pathlib import Path


def check(path: Path) -> int:
    errors = []
    warnings = []
    if not path.exists():
        print(f"ERROR: file not found: {path}")
        return 1
    text = path.read_text(encoding="utf-8")
    lower = text.lower()

    required = [
        ("<!doctype html", "HTML doctype"),
        ('name="viewport"', "viewport meta"),
        ("<style", "embedded CSS"),
        ("<script", "embedded JavaScript"),
        ("class=\"slide", "slide elements"),
    ]
    for token, label in required:
        if token not in lower:
            errors.append(f"missing {label}")

    slides = len(re.findall(r'class=["\'][^"\']*\bslide\b', text, flags=re.I))
    if slides < 3:
        errors.append(f"expected at least 3 slides, found {slides}")

    if re.search(r'<script[^>]+src\s*=', text, flags=re.I):
        errors.append("external script dependency found")
    if re.search(r'<link[^>]+href\s*=\s*["\']https?://', text, flags=re.I):
        errors.append("external stylesheet/font dependency found")

    for needle, label in [
        ("ArrowRight", "ArrowRight navigation"),
        ("ArrowLeft", "ArrowLeft navigation"),
        ("PageDown", "PageDown navigation"),
        ("PageUp", "PageUp navigation"),
        ("touchstart", "touch navigation"),
        ("embed", "embed mode"),
        ("progress", "progress indicator"),
    ]:
        if needle not in text:
            warnings.append(f"missing {label}")

    if "overflow:hidden" not in text.replace(" ", ""):
        warnings.append("deck may scroll instead of behaving like full-screen slides")
    if "@media" not in text:
        warnings.append("no responsive media query found")
    if "prefers-reduced-motion" not in text:
        warnings.append("consider adding prefers-reduced-motion support")

    print(f"Slides: {slides}")
    for item in errors:
        print(f"ERROR: {item}")
    for item in warnings:
        print(f"WARN: {item}")
    if not errors:
        print("PASS: structural checks passed")
    return 1 if errors else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: verify_deck.py <deck.html>")
        raise SystemExit(2)
    raise SystemExit(check(Path(sys.argv[1])))
