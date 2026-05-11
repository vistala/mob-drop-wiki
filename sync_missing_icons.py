"""
Resolve missing wiki item icons.

The script scans index.html for icons/<vnum>.png references that do not exist,
then tries to create them by:
1. running convert_icons.py against known local icon source folders,
2. copying an existing icon from duplicate_items.txt groups,
3. copying an existing icon from item_proto base/upgrade groups.
"""
from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
INDEX_PATH = SCRIPT_DIR / "index.html"
ICONS_DIR = SCRIPT_DIR / "icons"
REPORT_PATH = SCRIPT_DIR / "missing_icons_report.txt"

ICON_SOURCE_CANDIDATES = [
    SCRIPT_DIR,
    REPO_ROOT / "TGA_to_PNG",
    REPO_ROOT / "Harbi2_Files",
    REPO_ROOT / "Harbi2_Files" / "icon",
    REPO_ROOT / "Harbi2_Files" / "pack",
    REPO_ROOT / "BaseFiles",
]

DUPLICATE_FILES = [
    REPO_ROOT / "duplicate_items.txt",
    SCRIPT_DIR / "duplicate_items.txt",
]

ITEM_PROTO_FILES = [
    SCRIPT_DIR / "item_proto.txt",
    SCRIPT_DIR / "global_item_proto.txt",
    REPO_ROOT / "Harbi2_Files" / "srv1" / "share" / "conf" / "item_proto.txt",
    REPO_ROOT / "Harbi2_Files" / "srv1" / "share" / "conf" / "global_item_proto.txt",
]

ITEM_LIST_FILES = [
    SCRIPT_DIR / "item_list.txt",
    REPO_ROOT / "Harbi2_Files" / "srv1" / "share" / "conf" / "item_list.txt",
]


def needed_icon_vnums() -> set[str]:
    if not INDEX_PATH.exists():
        return set()
    html = INDEX_PATH.read_text(encoding="utf-8", errors="replace")
    return set(re.findall(r"icons/(\d+)\.png", html))


def missing_icon_vnums(vnums: set[str]) -> set[str]:
    return {vnum for vnum in vnums if not (ICONS_DIR / f"{vnum}.png").exists()}


def run_convert_icons() -> None:
    converter = SCRIPT_DIR / "convert_icons.py"
    if not converter.exists():
        return
    for source in ICON_SOURCE_CANDIDATES:
        if not source.exists():
            continue
        subprocess.run(
            [sys.executable, str(converter), str(source)],
            cwd=str(SCRIPT_DIR),
            check=False,
        )


def parse_duplicate_groups() -> list[list[str]]:
    groups: list[list[str]] = []
    for path in DUPLICATE_FILES:
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            nums = re.findall(r"\b\d{3,}\b", line)
            unique = list(dict.fromkeys(nums))
            if len(unique) >= 2:
                groups.append(unique)
    return groups


def copy_from_duplicate_groups(missing: set[str]) -> dict[str, str]:
    copied: dict[str, str] = {}
    for group in parse_duplicate_groups():
        existing_sources = [v for v in group if (ICONS_DIR / f"{v}.png").exists()]
        if not existing_sources:
            continue
        source = existing_sources[0]
        source_path = ICONS_DIR / f"{source}.png"
        for vnum in group:
            if vnum not in missing:
                continue
            target_path = ICONS_DIR / f"{vnum}.png"
            shutil.copyfile(source_path, target_path)
            copied[vnum] = source
    return copied


def parse_item_list_groups() -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    for path in ITEM_LIST_FILES:
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("//"):
                continue
            parts = stripped.split()
            if len(parts) >= 3 and parts[0].isdigit():
                icon_path = parts[2].replace("\\", "/").strip("\"'").lower()
                if "icon" in icon_path:
                    groups.setdefault(icon_path, []).append(parts[0])
    return groups


def copy_from_item_list_groups(missing: set[str]) -> dict[str, str]:
    icon_groups = parse_item_list_groups()
    vnum_to_group: dict[str, list[str]] = {}
    for group in icon_groups.values():
        for vnum in group:
            vnum_to_group[vnum] = group

    copied: dict[str, str] = {}
    for vnum in sorted(missing, key=int):
        for candidate in vnum_to_group.get(vnum, []):
            if candidate == vnum:
                continue
            source_path = ICONS_DIR / f"{candidate}.png"
            if source_path.exists():
                shutil.copyfile(source_path, ICONS_DIR / f"{vnum}.png")
                copied[vnum] = candidate
                break
    return copied


def copy_from_numeric_base_groups(missing: set[str]) -> dict[str, str]:
    copied: dict[str, str] = {}
    for vnum in sorted(missing, key=int):
        vint = int(vnum)
        candidates = []
        candidates.append(str(vint - (vint % 10)))
        candidates.append(str(vint - (vint % 100)))
        candidates.extend(str(vint - (vint % 10) + i) for i in range(10))
        for candidate in dict.fromkeys(candidates):
            if candidate == vnum:
                continue
            source_path = ICONS_DIR / f"{candidate}.png"
            if source_path.exists():
                shutil.copyfile(source_path, ICONS_DIR / f"{vnum}.png")
                copied[vnum] = candidate
                break
    return copied


def load_item_proto_names() -> dict[str, str]:
    names: dict[str, str] = {}
    for path in ITEM_PROTO_FILES:
        if not path.exists():
            continue
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0].isdigit():
                names.setdefault(parts[0], parts[1].lower())
    return names


def proto_group_key(name: str) -> str:
    key = re.sub(r"[\W_]+", "_", name.lower()).strip("_")
    key = re.sub(r"(\+?\d+|_p\d+|_lv\d+)$", "", key)
    key = re.sub(r"_(\d+)$", "", key)
    return key


def copy_from_proto_groups(missing: set[str]) -> dict[str, str]:
    names = load_item_proto_names()
    groups: dict[str, list[str]] = {}
    for vnum, name in names.items():
        groups.setdefault(proto_group_key(name), []).append(vnum)

    copied: dict[str, str] = {}
    for vnum in sorted(missing, key=int):
        name = names.get(vnum)
        if not name:
            continue

        candidates: list[str] = []
        candidates.extend(groups.get(proto_group_key(name), []))

        # Metin2 upgrade families often share the base icon by vnum rounded down to 10.
        vint = int(vnum)
        base10 = str(vint - (vint % 10))
        candidates.extend(str(int(base10) + i) for i in range(10))

        for candidate in dict.fromkeys(candidates):
            if candidate == vnum:
                continue
            source_path = ICONS_DIR / f"{candidate}.png"
            if source_path.exists():
                shutil.copyfile(source_path, ICONS_DIR / f"{vnum}.png")
                copied[vnum] = candidate
                break
    return copied


def main() -> int:
    ICONS_DIR.mkdir(exist_ok=True)
    needed = needed_icon_vnums()
    before = missing_icon_vnums(needed)

    run_convert_icons()
    after_convert = missing_icon_vnums(needed)

    item_list_copied = copy_from_item_list_groups(after_convert)
    after_item_list = missing_icon_vnums(needed)

    duplicate_copied = copy_from_duplicate_groups(after_item_list)
    after_duplicates = missing_icon_vnums(needed)

    numeric_copied = copy_from_numeric_base_groups(after_duplicates)
    after_numeric = missing_icon_vnums(needed)

    proto_copied = copy_from_proto_groups(after_numeric)
    unresolved = sorted(missing_icon_vnums(needed), key=int)

    lines = [
        f"Gerekli icon sayisi: {len(needed)}",
        f"Baslangicta eksik: {len(before)}",
        f"TGA donusumuyle cozuldu: {len(before) - len(after_convert)}",
        f"item_list ayni icon yolundan kopyalandi: {len(item_list_copied)}",
        f"Duplicate itemden kopyalandi: {len(duplicate_copied)}",
        f"Sayisal base VNUM'dan kopyalandi: {len(numeric_copied)}",
        f"item_proto grubundan kopyalandi: {len(proto_copied)}",
        f"Cozulemeyen: {len(unresolved)}",
    ]
    if item_list_copied:
        lines += ["", "item_list kopyalari:"]
        lines += [f"{target} <- {source}" for target, source in sorted(item_list_copied.items(), key=lambda x: int(x[0]))]
    if duplicate_copied:
        lines += ["", "Duplicate kopyalari:"]
        lines += [f"{target} <- {source}" for target, source in sorted(duplicate_copied.items(), key=lambda x: int(x[0]))]
    if numeric_copied:
        lines += ["", "Sayisal base kopyalari:"]
        lines += [f"{target} <- {source}" for target, source in sorted(numeric_copied.items(), key=lambda x: int(x[0]))]
    if proto_copied:
        lines += ["", "Proto kopyalari:"]
        lines += [f"{target} <- {source}" for target, source in sorted(proto_copied.items(), key=lambda x: int(x[0]))]
    if unresolved:
        lines += ["", "Cozulemeyenler:"]
        lines += unresolved

    REPORT_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Eksik icon senkronu tamamlandi.")
    for line in lines[:6]:
        print(line)
    print(f"Rapor: {REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
