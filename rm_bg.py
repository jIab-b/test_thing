import os
from pathlib import Path
from rembg import remove, new_session

VALID_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}


def process_assets(root: Path) -> None:
    if not root.exists() or not root.is_dir():
        print(f"assets directory not found: {root}")
        return
    session = new_session()
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        ext = path.suffix.lower()
        if ext not in VALID_EXTS:
            continue
        try:
            data = path.read_bytes()
            result = remove(data, session=session)
            if ext == ".png":
                tmp = path.with_suffix(".tmp")
                tmp.write_bytes(result)
                os.replace(tmp, path)
                print(f"processed {path}")
            else:
                out_path = path.with_suffix(".png")
                out_path.write_bytes(result)
                path.unlink()
                print(f"processed {path} -> {out_path.name}")
        except Exception as e:
            print(f"failed {path}: {e}")


if __name__ == "__main__":
    assets = Path(__file__).parent / "assets"
    process_assets(assets)


