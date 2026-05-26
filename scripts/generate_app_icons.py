#!/usr/bin/env python3
"""Generate platform app icons from the Zentra logo (bg removal + resize)."""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = (
    Path.home()
    / ".cursor/projects/home-foisal-Desktop-cursor-zentra-wallet/assets"
    / "zentra-717d6775-ec94-4a39-86a1-fa5bf5166330.png"
)

# Android launcher (px)
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# iOS AppIcon.appiconset: filename -> pixel size
IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

MACOS_ICONS = {
    "app_icon_16.png": 16,
    "app_icon_32.png": 32,
    "app_icon_64.png": 64,
    "app_icon_128.png": 128,
    "app_icon_256.png": 256,
    "app_icon_512.png": 512,
    "app_icon_1024.png": 1024,
}

WEB_ICONS = {
    "Icon-192.png": 192,
    "Icon-512.png": 512,
}

WINDOWS_ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)

# Fraction of the square canvas occupied by the logo (higher = less side padding).
DEFAULT_FILL = 0.94


def remove_black_background(
    img: Image.Image,
    *,
    ring_lo: int = 95,
    ring_hi: int = 170,
    shadow_th: int = 86,
    ring_pad: float = 1.0,
    protect_pct: float = 0.12,
    num_angles: int = 720,
) -> Image.Image:
    """Remove outer black + soft shadow; keep chrome ring and all interior art."""
    rgba = img.convert("RGBA")
    pixels = rgba.load()
    w, h = rgba.size
    cx, cy = w / 2.0, h / 2.0

    def is_ring_pixel(r: int, g: int, b: int) -> bool:
        level = max(r, g, b)
        return ring_lo <= level <= ring_hi

    ring_r = [0.0] * num_angles
    for y in range(h):
        for x in range(w):
            r, g, b, _a = pixels[x, y]
            if not is_ring_pixel(r, g, b):
                continue
            angle = math.atan2(y - cy, x - cx)
            bucket = int((angle + math.pi) / (2 * math.pi) * num_angles) % num_angles
            dist = math.hypot(x - cx, y - cy)
            ring_r[bucket] = max(ring_r[bucket], dist)

    positive = sorted(v for v in ring_r if v > 0)
    protect_r = positive[int(len(positive) * protect_pct)] if positive else 0.0

    for y in range(h):
        for x in range(w):
            dist = math.hypot(x - cx, y - cy)
            if dist < protect_r:
                continue
            angle = math.atan2(y - cy, x - cx)
            bucket = int((angle + math.pi) / (2 * math.pi) * num_angles) % num_angles
            if dist <= ring_r[bucket] + ring_pad:
                continue
            r, g, b, _a = pixels[x, y]
            if max(r, g, b) <= shadow_th:
                pixels[x, y] = (r, g, b, 0)

    return rgba


def tighten_logo(img: Image.Image, fill: float = DEFAULT_FILL) -> Image.Image:
    """Crop to visible logo, then scale up so side padding is minimal."""
    alpha = img.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        return img

    cropped = img.crop(bbox)
    cw, ch = cropped.size
    side = max(img.width, img.height)
    target_span = int(side * fill)
    scale = target_span / max(cw, ch)
    new_w = max(1, int(round(cw * scale)))
    new_h = max(1, int(round(ch * scale)))
    scaled = cropped.resize((new_w, new_h), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(scaled, ((side - new_w) // 2, (side - new_h) // 2), scaled)
    return canvas


def resize_icon(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.Resampling.LANCZOS)


def maskable_variant(img: Image.Image, size: int, scale: float = 0.72) -> Image.Image:
    """Web maskable icon: logo scaled into center safe zone."""
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * scale)
    logo = resize_icon(img, inner)
    offset = (size - inner) // 2
    canvas.paste(logo, (offset, offset), logo)
    return canvas


def save_png(path: Path, img: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, format="PNG", optimize=True)


def flatten_on_black(img: Image.Image) -> Image.Image:
    """Opaque square icon (required for iOS App Store marketing icon)."""
    base = Image.new("RGBA", img.size, (0, 0, 0, 255))
    base.paste(img, (0, 0), img)
    return base.convert("RGB")


def write_windows_ico(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # Base image must be >= largest ICO size or Pillow drops bigger entries.
    sizes = list(WINDOWS_ICO_SIZES)
    frames = {s: resize_icon(img, s) for s in sizes}
    largest = max(sizes)
    append = [frames[s] for s in sizes if s != largest]
    frames[largest].save(
        path,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=append,
    )


def generate_all(source: Path, root: Path, fill: float) -> None:
    raw = Image.open(source)
    logo = tighten_logo(remove_black_background(raw), fill=fill)

    # Keep master asset in repo
    assets_dir = root / "assets" / "brand"
    save_png(assets_dir / "zentra_logo_1024.png", resize_icon(logo, 1024))

    android_base = root / "android" / "app" / "src" / "main" / "res"
    for folder, px in ANDROID_SIZES.items():
        save_png(android_base / folder / "ic_launcher.png", resize_icon(logo, px))

    ios_dir = root / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, px in IOS_ICONS.items():
        icon = resize_icon(logo, px)
        # App Store marketing icon must be opaque (no alpha).
        if name == "Icon-App-1024x1024@1x.png":
            icon = flatten_on_black(icon)
        save_png(ios_dir / name, icon)

    mac_dir = root / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, px in MACOS_ICONS.items():
        save_png(mac_dir / name, resize_icon(logo, px))

    web_dir = root / "web" / "icons"
    for name, px in WEB_ICONS.items():
        save_png(web_dir / name, resize_icon(logo, px))
    save_png(web_dir / "Icon-maskable-192.png", maskable_variant(logo, 192))
    save_png(web_dir / "Icon-maskable-512.png", maskable_variant(logo, 512))
    save_png(root / "web" / "favicon.png", resize_icon(logo, 48))

    write_windows_ico(logo, root / "windows" / "runner" / "resources" / "app_icon.ico")

    print(f"Generated icons from {source}")
    print(f"  Master: {assets_dir / 'zentra_logo_1024.png'}")
    print(f"  Android: {len(ANDROID_SIZES)} densities")
    print(f"  iOS: {len(IOS_ICONS)} files")
    print(f"  macOS: {len(MACOS_ICONS)} files")
    print(f"  Web: {len(WEB_ICONS) + 3} files")
    print(f"  Windows: app_icon.ico ({len(WINDOWS_ICO_SIZES)} sizes)")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument(
        "--fill",
        type=float,
        default=DEFAULT_FILL,
        help="Logo fill ratio in square canvas (0.9–0.98, higher = less side space)",
    )
    args = parser.parse_args()

    if not args.source.is_file():
        print(f"Source image not found: {args.source}", file=sys.stderr)
        return 1

    generate_all(args.source, args.root, args.fill)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
