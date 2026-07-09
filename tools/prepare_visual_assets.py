"""Prepare JARVIS visual reference assets.

The source reference is a rectangular generated image. This script crops around
the central orb, avoids the bottom-right sparkle mark, and creates square
derivatives that can guide app icon and preview work. The app itself still draws
the orb natively, so missing assets should not block development.
"""

from __future__ import annotations

from pathlib import Path
import json


REPO_ROOT = Path(__file__).resolve().parents[1]
SOURCE = REPO_ROOT / "assets" / "visual_reference" / "jarvis_orb_reference_original.jpg"
SQUARE = REPO_ROOT / "assets" / "visual_reference" / "jarvis_orb_square_crop.png"
ICON = REPO_ROOT / "assets" / "visual_reference" / "jarvis_orb_clean_icon_reference.png"
PREVIEW = REPO_ROOT / "preview" / "windows_jarvis_preview" / "assets" / "jarvis_orb_reference.png"
IOS_ORB_DIR = REPO_ROOT / "ios" / "JarvisXR" / "JarvisXR" / "Assets.xcassets" / "JarvisOrb.imageset"
IOS_ORB = IOS_ORB_DIR / "jarvis-orb.png"
IOS_ORB_CONTENTS = IOS_ORB_DIR / "Contents.json"


def main() -> int:
    if not SOURCE.exists():
        print(f"Missing source image: {SOURCE}")
        print("Copy the attached Gemini reference image to that path, then rerun this script.")
        return 0

    try:
        from PIL import Image, ImageEnhance, ImageFilter
    except ImportError:
        print("Pillow is not installed, so image derivatives were not generated.")
        print("Install with: python -m pip install Pillow")
        print("The native app and Windows preview still work because the orb is drawn in code.")
        return 0

    SQUARE.parent.mkdir(parents=True, exist_ok=True)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    IOS_ORB_DIR.mkdir(parents=True, exist_ok=True)

    image = Image.open(SOURCE).convert("RGB")
    width, height = image.size

    # The reference orb is centered inside the icon shape while the watermark is
    # far to the lower-right. Bias the crop to the icon and away from that mark.
    crop_size = min(height, int(width * 0.64))
    center_x = int(width * 0.50)
    center_y = int(height * 0.50)
    left = max(0, min(width - crop_size, center_x - crop_size // 2))
    top = max(0, min(height - crop_size, center_y - crop_size // 2))
    crop = image.crop((left, top, left + crop_size, top + crop_size))

    crop = ImageEnhance.Contrast(crop).enhance(1.08)
    crop = ImageEnhance.Color(crop).enhance(1.04)
    crop.save(SQUARE)

    icon = crop.resize((1024, 1024), Image.Resampling.LANCZOS)
    icon = ImageEnhance.Contrast(icon).enhance(1.10)
    icon.save(ICON)
    icon.save(IOS_ORB)
    IOS_ORB_CONTENTS.write_text(json.dumps({
        "images": [
            {
                "filename": IOS_ORB.name,
                "idiom": "universal",
                "scale": "1x",
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }, indent=2) + "\n", encoding="utf-8")

    preview = crop.resize((512, 512), Image.Resampling.LANCZOS)
    preview = preview.filter(ImageFilter.UnsharpMask(radius=1.2, percent=110, threshold=3))
    preview.save(PREVIEW)

    print("JARVIS visual assets prepared.")
    print(f"Source: {SOURCE} ({width}x{height})")
    print(f"Crop box: left={left}, top={top}, size={crop_size}")
    print(f"Square crop: {SQUARE}")
    print(f"Clean icon reference: {ICON}")
    print(f"iOS orb asset: {IOS_ORB}")
    print(f"Windows preview asset: {PREVIEW}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
