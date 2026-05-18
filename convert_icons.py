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
    ICON_SRC = SCRIPT_DIR / "icon"  # Fallback
ICON_OUT = SCRIPT_DIR / "icons"
MOB_DROP = SCRIPT_DIR / "mob_drop_item.txt"
CHEST_DROP = SCRIPT_DIR / "special_item_group.txt"
INDEX_HTML = SCRIPT_DIR / "index.html"
ICON_FILE_INDEXES = {}

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

def extract_icon_vnums_from_html(filepath):
    vnums = set()
    if not filepath.exists():
        return vnums
    html = filepath.read_text(encoding="utf-8", errors="replace")
    vnums.update(re.findall(r"icons/(\d+)\.png", html))
    return vnums

ITEM_LIST_PATH = SCRIPT_DIR / "item_list.txt"

def load_item_list_mapping(filepath):
    """Load vnum -> icon path mapping from item_list.txt"""
    mapping = {}
    if not filepath.exists():
        print(f"UYARI: {filepath.name} bulunamadi, icon mapping yapilamiyor.")
        return mapping
    
    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            # Drop comments and empty lines
            if line.strip().startswith("//") or not line.strip():
                continue
            
            # Split by any whitespace
            parts = line.strip().split()
            if len(parts) >= 3:
                vnum_str = parts[0]
                icon_path = parts[2]
                if vnum_str.isdigit() and "icon" in icon_path.lower():
                    # Clean up backslashes and quotes if any
                    icon_path = icon_path.replace("\\", "/").strip('"').strip("'")
                    mapping[int(vnum_str)] = icon_path
    return mapping

def convert_tga_to_png(vnum, src_dir, out_dir, mapping):
    """Convert a TGA icon to PNG using item_list mapping. Returns True if successful."""
    vnum_int = int(vnum)
    png_path = out_dir / f"{vnum}.png"
    
    if png_path.exists():
        return True  # Already converted
        
    icon_subpath = mapping.get(vnum_int)
    # If not in mapping, try fallback logic to base vnum in mapping
    if not icon_subpath:
        base10 = vnum_int - (vnum_int % 10)
        icon_subpath = mapping.get(base10)
    
    # If still not found, try raw fallback
    if not icon_subpath:
        padded = str(base10).zfill(5) if 'base10' in locals() else str(vnum_int).zfill(5)
        icon_subpath = f"icon/item/{padded}.tga"
        
    tga_path = src_dir / icon_subpath

    # Try one final raw fallback if the composed path doesn't exist
    if not tga_path.exists():
        nested_mapped_path = src_dir / "icon" / icon_subpath
        raw_base_path = src_dir / "icon/item" / f"{str(vnum_int - (vnum_int%10)).zfill(5)}.tga"
        if nested_mapped_path.exists():
             tga_path = nested_mapped_path
        elif raw_base_path.exists():
             tga_path = raw_base_path
        else:
             tga_path = find_icon_by_vnum(src_dir, vnum_int)
             if not tga_path:
                 return False
    
    try:
        img = Image.open(tga_path)
        # Convert to RGBA if needed
        if img.mode != "RGBA":
            img = img.convert("RGBA")
        
        # WE DO NOT RESIZE. Metin2 slot heights are 32x32, 32x64, 32x96. We keep original aspect ratio.
        img.save(png_path, "PNG")
        return True
    except Exception as e:
        print(f"  HATA: {vnum} -> {e}")
        return False

def find_icon_by_vnum(src_dir, vnum_int):
    """Find icons that are present in nested icon packs but missing from item_list.txt."""
    global ICON_FILE_INDEXES
    src_key = str(src_dir.resolve())
    if src_key not in ICON_FILE_INDEXES:
        ICON_FILE_INDEXES[src_key] = build_icon_file_index(src_dir)

    candidates = [
        f"{vnum_int}.tga",
        f"{vnum_int}.dds",
        f"{vnum_int - (vnum_int % 10)}.tga",
        f"{vnum_int - (vnum_int % 10)}.dds",
        f"{str(vnum_int).zfill(5)}.tga",
        f"{str(vnum_int).zfill(5)}.dds",
        f"{str(vnum_int - (vnum_int % 10)).zfill(5)}.tga",
        f"{str(vnum_int - (vnum_int % 10)).zfill(5)}.dds",
    ]

    for filename in dict.fromkeys(candidates):
        match = ICON_FILE_INDEXES[src_key].get(filename.lower())
        if match:
            return match
    return None

def build_icon_file_index(src_dir):
    index = {}
    roots = [
        src_dir / "icon" / "item",
        src_dir / "icon",
        src_dir,
    ]
    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.suffix.lower() not in (".tga", ".dds"):
                continue
            index.setdefault(path.name.lower(), path)
    return index

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
    vnums.update(extract_icon_vnums_from_html(INDEX_HTML))
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
    
    mapping = load_item_list_mapping(ITEM_LIST_PATH)
    print(f"item_list.txt'den {len(mapping)} icon haritasi yuklendi.")

    for vnum in sorted(vnums, key=int):
        png_path = ICON_OUT / f"{vnum}.png"
        if png_path.exists():
            skipped += 1
            continue
        if convert_tga_to_png(vnum, ICON_SRC, ICON_OUT, mapping):
            converted += 1
        else:
            missing += 1
    
    create_default_icon(ICON_OUT)
    
    print(f"Donusturulen: {converted} | Zaten mevcut: {skipped} | Bulunamayan: {missing}")
    print(f"Iconlar: {ICON_OUT}")

if __name__ == "__main__":
    main()
