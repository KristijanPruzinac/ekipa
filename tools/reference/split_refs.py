"""Split Mobbin-style side-by-side reference screenshots into one file per phone frame.

Method: the gutter between frames is flat background. Sample the background colour
from the image border, mark every column that is ~entirely background as a gutter,
then keep the contiguous non-gutter runs wider than a minimum frame width.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(r"C:\Users\kikom\Pictures\Screenshots")

# (source file, app slug, set slug, [screen names left->right])
JOBS = [
    ("Snimka zaslona 2026-08-18 005116.png", "opal", "highlight", [
        "01-splash-mark", "02-onboarding-closer", "03-home-score",
        "04-today-score-detail", "05-flows-index"]),
    ("Snimka zaslona 2026-08-18 005212.png", "opal", "onboarding", [
        "01-splash-mark", "02-splash-wordmark", "03-story-reveals-its-fire",
        "04-story-closer", "05-story-dimmed-by-noise"]),
    ("Snimka zaslona 2026-08-18 005130.png", "posh", "highlight", [
        "01-splash-black", "02-event-edit", "03-event-overview",
        "04-discover-city-feed", "05-flows-index"]),
    ("Snimka zaslona 2026-08-18 005155.png", "posh", "onboarding", [
        "01-splash-wordmark", "02-hero-secret-rave", "03-hero-yoga-class",
        "04-phone-entry", "05-email-entry-captcha"]),
    ("Snimka zaslona 2026-08-18 005224.png", "polarsteps", "highlight", [
        "01-splash-logo", "02-profile", "03-trip-create",
        "04-trip-map-plan", "05-flows-index"]),
    ("Snimka zaslona 2026-08-18 005238.png", "polarsteps", "onboarding", [
        "01-splash-logo", "02-hero-plan-track-relive", "03-signup-options",
        "04-basics-first-name", "05-basics-last-name"]),
    ("Snimka zaslona 2026-08-18 005253.png", "places", "highlight", [
        "01-splash-wordmark", "02-phone-entry-hero", "03-ai-answer",
        "04-place-detail", "05-flows-index"]),
    ("Snimka zaslona 2026-08-18 005306.png", "places", "onboarding", [
        "01-splash-wordmark", "02-phone-entry-hero", "03-phone-keypad-empty",
        "04-phone-keypad-filled", "05-verify-code"]),
]


def background_colour(a: np.ndarray) -> np.ndarray:
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    colours, counts = np.unique(border.reshape(-1, border.shape[-1]), axis=0, return_counts=True)
    return colours[counts.argmax()]


def runs(mask: np.ndarray):
    """Contiguous True runs as (start, end_exclusive)."""
    out, start = [], None
    for i, v in enumerate(mask):
        if v and start is None:
            start = i
        elif not v and start is not None:
            out.append((start, i))
            start = None
    if start is not None:
        out.append((start, len(mask)))
    return out


def split(path: Path, min_width: int = 150, tol: int = 12, purity: float = 0.995):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    bg = background_colour(a).astype(np.int16)
    near_bg = (np.abs(a - bg).max(axis=2) <= tol)

    col_is_gutter = near_bg.mean(axis=0) >= purity
    segments = [(s, e) for s, e in runs(~col_is_gutter) if e - s >= min_width]

    row_is_gutter = near_bg.mean(axis=1) >= purity
    rows = [(s, e) for s, e in runs(~row_is_gutter) if e - s >= min_width]
    top, bottom = (rows[0][0], rows[-1][1]) if rows else (0, a.shape[0])
    return im, segments, (top, bottom)


def main(write: bool):
    root = Path(__file__).resolve()
    out_root = Path(r"c:\Users\kikom\Documents\GitHub\ekipa\docs\reference")
    for fname, app, group, names in JOBS:
        im, segments, (top, bottom) = split(SRC / fname)
        print(f"\n{app}/{group}  <- {fname}  {im.size}  rows {top}..{bottom}")
        for i, (s, e) in enumerate(segments):
            name = names[i] if i < len(names) else f"{i + 1:02d}-extra"
            print(f"   {name:32s} x {s:5d}..{e:5d}  w={e - s}")
            if write:
                d = out_root / app / group
                d.mkdir(parents=True, exist_ok=True)
                im.crop((s, top, e, bottom)).save(d / f"{name}.png")
        if len(segments) != len(names):
            print(f"   !! expected {len(names)} frames, found {len(segments)}")


if __name__ == "__main__":
    main(write="--write" in sys.argv)
