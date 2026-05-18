from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
ICONS_DIR = ROOT / "icons"


def is_light_background(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a == 0:
        return True
    mx = max(r, g, b)
    mn = min(r, g, b)
    # Metin2 icons often arrive with white/cream matte backgrounds. Only remove
    # low-saturation bright pixels that are connected to the outer edge.
    return mx >= 210 and mn >= 165 and (mx - mn) <= 70


def clean_icon(path: Path) -> bool:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    changed = False
    while queue:
        x, y = queue.popleft()
        if (x, y) in visited:
            continue
        visited.add((x, y))
        if not is_light_background(pixels[x, y]):
            continue

        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)
        changed = True

        if x > 0:
            queue.append((x - 1, y))
        if x + 1 < width:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y + 1 < height:
            queue.append((x, y + 1))

    if changed:
        image.save(path, "PNG")
    return changed


def main() -> int:
    changed = 0
    total = 0
    for path in sorted(ICONS_DIR.glob("*.png")):
        if path.name == "default.png":
            continue
        total += 1
        if clean_icon(path):
            changed += 1
    print(f"Icon arka plan temizligi: {changed}/{total} PNG guncellendi.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
