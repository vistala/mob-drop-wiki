"""
convert_icons.py
Reads mob_drop_item.txt and special_item_group.txt to find all used item vnums,
then converts the corresponding TGA icons to PNG for web display.
"""
import os
import sys
import re
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow kuruluyor...")
    os.system(f"{sys.executable} -m pip install Pillow")
    from PIL import Image

SCRIPT_DIR = Path(__file__).parent
# Accept icon source path as command-line argument
if len(sys.argv) > 1:
    ICON_SRC = Path(sys.argv[1])
else:
    ICON_SRC = SCRIPT_DIR / "icon_source"  # Fallback
ICON_OUT = SCRIPT_DIR / "icons"
MOB_DROP = SCRIPT_DIR / "mob_drop_item.txt"
CHEST_DROP = SCRIPT_DIR / "special_item_group.txt"

def extract_vnums_from_file(filepath):
    """Extract all item vnums from a drop file."""
    vnums = set()
    if not filepath.exists():
        return vnums
    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            stripped = line.strip()
            # Match item lines: index vnum ...
            m = re.match(r"^\d+\s+(\d+)\s+", stripped)
            if m:
                vnums.add(m.group(1))
    return vnums

def find_tga_path(vnum_int, src_dir):
    """Find the TGA file for a vnum, trying base-vnum fallbacks."""
    # Try exact vnum first
    candidates = [vnum_int]
    # Try base vnum (strip upgrade level: 23 -> 20, 2013 -> 2010)
    base10 = vnum_int - (vnum_int % 10)
    if base10 != vnum_int:
        candidates.append(base10)
    # Try base vnum floored to 100 (for some special items)
    base100 = vnum_int - (vnum_int % 100)
    if base100 not in candidates:
        candidates.append(base100)
    
    for candidate in candidates:
        padded = str(candidate).zfill(5)
        tga_path = src_dir / f"{padded}.tga"
        if tga_path.exists():
            return tga_path
    return None

def convert_tga_to_png(vnum, src_dir, out_dir):
    """Convert a TGA icon to PNG. Returns True if successful."""
    vnum_int = int(vnum)
    png_path = out_dir / f"{vnum}.png"
    
    if png_path.exists():
        return True  # Already converted
    
    tga_path = find_tga_path(vnum_int, src_dir)
    if tga_path is None:
        return False
    
    try:
        img = Image.open(tga_path)
        # Convert to RGBA if needed
        if img.mode != "RGBA":
            img = img.convert("RGBA")
        # Resize to 32x32 if needed
        if img.size != (32, 32):
            img = img.resize((32, 32), Image.LANCZOS)
        img.save(png_path, "PNG")
        return True
    except Exception as e:
        print(f"  HATA: {vnum} -> {e}")
        return False

def create_default_icon(out_dir):
    """Create a default fallback icon."""
    default_path = out_dir / "default.png"
    if default_path.exists():
        return
    img = Image.new("RGBA", (32, 32), (30, 30, 50, 200))
    # Draw a simple ? mark area
    from PIL import ImageDraw
    draw = ImageDraw.Draw(img)
    draw.rectangle([2, 2, 29, 29], outline=(80, 80, 120, 200), width=1)
    draw.text((11, 6), "?", fill=(150, 150, 200, 255))
    img.save(default_path, "PNG")

def main():
    print("=== Icon Converter ===")
    
    # Collect all needed vnums
    vnums = set()
    vnums.update(extract_vnums_from_file(MOB_DROP))
    vnums.update(extract_vnums_from_file(CHEST_DROP))
    print(f"Toplam {len(vnums)} benzersiz item vnum bulundu.")
    
    # Check source directory
    if not ICON_SRC.exists():
        print(f"UYARI: Icon kaynak klasoru bulunamadi: {ICON_SRC}")
        print("Icon donusumu atlanacak.")
        ICON_OUT.mkdir(exist_ok=True)
        create_default_icon(ICON_OUT)
        return
    
    ICON_OUT.mkdir(exist_ok=True)
    
    converted = 0
    missing = 0
    skipped = 0
    
    for vnum in sorted(vnums, key=int):
        png_path = ICON_OUT / f"{vnum}.png"
        if png_path.exists():
            skipped += 1
            continue
        if convert_tga_to_png(vnum, ICON_SRC, ICON_OUT):
            converted += 1
        else:
            missing += 1
    
    create_default_icon(ICON_OUT)
    
    print(f"Donusturulen: {converted} | Zaten mevcut: {skipped} | Bulunamayan: {missing}")
    print(f"Iconlar: {ICON_OUT}")

if __name__ == "__main__":
    main()
