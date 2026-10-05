"""Export SYRI's existing logo and Flutter Material icons as reusable PNG/ICO files.

Run with a Python installation containing Pillow. This renders the icon glyphs
from the same Material Icons font and Flutter icon definitions used by the app.
"""

from __future__ import annotations

import re
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
FLUTTER = Path(r"C:\Users\GAMING\develop\flutter")
FONT = FLUTTER / "bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
ICONS_DART = FLUTTER / "packages/flutter/lib/src/material/icons.dart"
OUT = ROOT / "Exported Icons"
SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
ACTIVE_SUBCATEGORIES = {
    "news": "News",
    "alerts": "Alerts",
    "weather": "Weather",
    "territory": "Territory",
    "sea": "Waters",
    "transport": "Transport",
}
ACCENT_COLORS = {
    "greenAccent": "#69F0AE", "orangeAccent": "#FFAB40",
    "redAccent": "#FF5252", "blueGrey": "#607D8B",
    "deepOrangeAccent": "#FF6E40", "lightBlueAccent": "#40C4FF",
    "tealAccent": "#64FFDA", "lightGreenAccent": "#B2FF59",
    "amber": "#FFC107", "purpleAccent": "#E040FB",
    "blueAccent": "#448AFF", "pinkAccent": "#FF4081",
    "amberAccent": "#FFD740", "cyanAccent": "#18FFFF",
}


def save_png_ico(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path.with_suffix(".png"))
    image.save(path.with_suffix(".ico"), format="ICO", sizes=SIZES)


def render_glyph(codepoint: int, color: str) -> Image.Image:
    canvas = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(str(FONT), 420)
    glyph = chr(codepoint)
    bbox = draw.textbbox((0, 0), glyph, font=font)
    x = (512 - (bbox[2] - bbox[0])) / 2 - bbox[0]
    y = (512 - (bbox[3] - bbox[1])) / 2 - bbox[1]
    draw.text((x, y), glyph, font=font, fill=color)
    return canvas.resize((256, 256), Image.Resampling.LANCZOS)


def subcategory_artwork(source: str):
    """Read the current category picker choices, excluding retired categories."""
    section = source.split("List<(String, String, IconData, Color)> _subcategoryChoices(", 1)[1]
    section = section.split("bool _subcategoryActive(", 1)[0]
    category_pattern = re.compile(r"'([a-z]+)'\s*=>\s*const\s*\[(.*?)\],", re.S)
    item_pattern = re.compile(
        r"\(\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*Icons\.(\w+)\s*,\s*"
        r"(?:Colors\.(\w+)|Color\(0x([0-9a-fA-F]{8})\)|(mint))\s*,?\s*\)",
        re.S,
    )
    for category_id, contents in category_pattern.findall(section):
        if category_id not in ACTIVE_SUBCATEGORIES:
            continue
        for sub_id, label, glyph, named_color, hex_color, mint_color in item_pattern.findall(contents):
            color = "#C7F36A" if mint_color else (ACCENT_COLORS[named_color] if named_color else f"#{hex_color[2:]}")
            yield ACTIVE_SUBCATEGORIES[category_id], sub_id, label, glyph, color


def main() -> None:
    if not FONT.is_file() or not ICONS_DART.is_file():
        raise FileNotFoundError("Flutter's Material icon font or definitions were not found")

    definitions = {
        name: int(codepoint, 16)
        for name, codepoint in re.findall(
            r"static const IconData (\w+)\s*=\s*IconData\(\s*0x([0-9a-fA-F]+)",
            ICONS_DART.read_text(encoding="utf-8"),
        )
    }
    used = set()
    for source in (ROOT / "lib").glob("*.dart"):
        used.update(re.findall(r"\bIcons\.([A-Za-z_]\w*)", source.read_text(encoding="utf-8")))
    missing = sorted(used - definitions.keys())
    if missing:
        raise ValueError(f"Flutter icon definitions missing: {missing}")

    brand = Image.open(ROOT / "assets/syri_brand.png").convert("RGBA")
    save_png_ico(brand, OUT / "Official Logo" / "SYRI-official-logo")
    for size in (2048, 4096):
        brand.resize((size, size), Image.Resampling.LANCZOS).save(
            OUT / "Official Logo" / f"SYRI-official-logo-{size}.png",
            optimize=True,
        )
    launcher = Image.open(
        ROOT / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
    ).convert("RGBA")
    save_png_ico(launcher.resize((256, 256), Image.Resampling.LANCZOS), OUT / "Official Logo" / "SYRI-Android-launcher")
    for name in ("Icon-192", "Icon-512", "Icon-maskable-192", "Icon-maskable-512"):
        shutil.copy2(ROOT / "web/icons" / f"{name}.png", OUT / "Official Logo" / f"{name}.png")

    for name in sorted(used):
        save_png_ico(render_glyph(definitions[name], "#FFFFFF"), OUT / "Material Icons" / name)

    categories = {
        "News": ("newspaper_outlined", "#91B5FF"),
        "Alerts": ("warning_amber_rounded", "#FF7478"),
        "Weather": ("cloud_outlined", "#66D9FF"),
        "Territory": ("layers_outlined", "#FFD36A"),
        "Waters": ("water_outlined", "#52D9FF"),
        "Transport": ("commute", "#C7F36A"),
        "Cameras": ("videocam_outlined", "#D7A6FF"),
        "Channels": ("live_tv_rounded", "#FFA967"),
    }
    for label, (name, color) in categories.items():
        save_png_ico(render_glyph(definitions[name], color), OUT / "Categories" / label)

    subcategories = list(subcategory_artwork((ROOT / "lib/main.dart").read_text(encoding="utf-8")))
    index = ["SYRI category and subcategory icons", ""]
    for category, sub_id, label, name, color in subcategories:
        if name not in definitions:
            raise ValueError(f"Missing subcategory icon: {name}")
        filename = re.sub(r"[^A-Za-z0-9_-]+", "-", sub_id).strip("-")
        save_png_ico(render_glyph(definitions[name], color), OUT / "Subcategories" / category / filename)
        index.append(f"{category} / {label} ({sub_id}): Subcategories/{category}/{filename}.png and .ico")
    (OUT / "ICON_INDEX.txt").write_text("\n".join(index) + "\n", encoding="utf-8")

    navigation = {
        "Map": ("map_outlined", "#C7F36A"),
        "Events": ("dynamic_feed", "#FFFFFF"),
        "Settings": ("settings_outlined", "#FFFFFF"),
        "Donate": ("volunteer_activism_outlined", "#FF7478"),
    }
    for label, (name, color) in navigation.items():
        save_png_ico(render_glyph(definitions[name], color), OUT / "Navigation" / label)

    channels = OUT / "Channel Logos"
    channels.mkdir(parents=True, exist_ok=True)
    for source in (ROOT / "assets/channel_logos").iterdir():
        if source.is_file():
            shutil.copy2(source, channels / source.name)

    (OUT / "README.txt").write_text(
        "SYRI artwork export\n\n"
        "Official Logo contains the exact app logo and launcher assets.\n"
        "The 2048 and 4096 pixel official logos are enlarged from the exact 512 pixel app logo.\n"
        "Categories, Subcategories and Navigation contain SYRI-coloured Material icon glyphs.\n"
        "See ICON_INDEX.txt for every active subcategory's icon file.\n"
        "Material Icons contains every Material icon referenced in the Flutter app, "
        "in transparent white PNG and multi-size ICO formats.\n"
        "Channel Logos are third-party broadcaster artwork included in the app; "
        "their brands remain the property of their respective owners.\n"
        "PNG files are 256x256 pixels except for the original web and brand assets. "
        "ICO files contain sizes from 16 to 256 pixels.\n",
        encoding="utf-8",
    )
    print(f"Exported {len(used)} Material glyphs, {len(subcategories)} named subcategories and brand/category/navigation artwork to {OUT}")


if __name__ == "__main__":
    main()
