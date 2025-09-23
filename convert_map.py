import os
import sys
import json
import argparse
import glob


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))


def convert(src_path, dst_path):
    src = load_json(src_path)
    tile = int(src.get("tile_size", 32))
    gw = int(src.get("grid_width", 50))
    gh = int(src.get("grid_height", 30))
    layers = src.get("layers", {})
    out = {
        "version": 1,
        "tile_size": tile,
        "grid_width": gw,
        "grid_height": gh,
        "visual_blocks": sorted([[x, y] for [x, y, t] in layers.get("blocks", [])]),
        "collision_layer_1": sorted([[x, y] for [x, y] in layers.get("collision_layer_1", [])]),
        "collision_layer_2": sorted([[x, y] for [x, y] in layers.get("collision_layer_2", [])]),
        "pickups": sorted([[x, y, t] for [x, y, t] in layers.get("pickups", [])]),
    }
    save_json(dst_path, out)


def resolve_src_path(src_arg: str | None, id_arg: str | None) -> str:
    saved_dir = os.path.join("saved_maps")
    if id_arg:
        ident = str(id_arg)
        if ident.isdigit():
            ident2 = ident[-2:].zfill(2)
            candidate = os.path.join(saved_dir, f"map_{ident2}.json")
            if os.path.exists(candidate):
                return candidate
            ident4 = ident[-4:].zfill(4)
            candidate4 = os.path.join(saved_dir, f"map_{ident4}.json")
            if os.path.exists(candidate4):
                return candidate4
    if src_arg:
        if "*" in src_arg or "?" in src_arg:
            matches = sorted(glob.glob(src_arg))
            if not matches:
                raise FileNotFoundError(f"No files match pattern: {src_arg}")
            return matches[-1]
        base = os.path.basename(src_arg)
        root, ext = os.path.splitext(base)
        if not ext and root.isdigit():
            ident2 = root[-2:].zfill(2)
            candidate = os.path.join(saved_dir, f"map_{ident2}.json")
            if os.path.exists(candidate):
                return candidate
            ident4 = root[-4:].zfill(4)
            candidate4 = os.path.join(saved_dir, f"map_{ident4}.json")
            if os.path.exists(candidate4):
                return candidate4
        if os.path.exists(src_arg):
            return src_arg
        candidate = os.path.join(saved_dir, src_arg)
        if os.path.exists(candidate):
            return candidate
    raise FileNotFoundError("Provide --id XX or a valid src path (file, digits, or glob pattern)")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("src", nargs="?", help="path, digits like 01 or 1283, or glob like saved_maps/map_*.json")
    p.add_argument("--id", "-i", help="two-digit or four-digit map id like 01 or 1283")
    p.add_argument("--out", "-o", default=os.path.join("test_proj", "maps", "map.json"))
    args = p.parse_args()
    src_path = resolve_src_path(args.src, args.id)
    convert(src_path, args.out)
    print(f"Converted {src_path} -> {args.out}")


if __name__ == "__main__":
    sys.exit(main() or 0)


