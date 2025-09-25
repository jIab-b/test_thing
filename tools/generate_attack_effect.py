import os
import argparse
import base64
import json
import pathlib
import time
import zipfile
import io
import random
import requests
def preview_pygame(frames_dir: pathlib.Path, size: int) -> None:
    import pygame
    pygame.init()
    screen = pygame.display.set_mode((size * 2, size * 2))
    clock = pygame.time.Clock()
    files = sorted([p for p in frames_dir.iterdir() if p.suffix.lower() == ".png"])
    imgs = [pygame.image.load(str(p)).convert_alpha() for p in files]
    idx = 0
    running = True
    last_switch = 0
    frame_ms = max(30, int(1000 / max(1, len(imgs))))
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                running = False
        now = pygame.time.get_ticks()
        if now - last_switch >= frame_ms:
            idx = (idx + 1) % len(imgs)
            last_switch = now
        screen.fill((10, 10, 20))
        img = imgs[idx]
        rect = img.get_rect(center=(size, size))
        screen.blit(img, rect)
        pygame.display.flip()
        clock.tick(60)
    pygame.quit()



def _mask_large_values(x):
    if isinstance(x, dict):
        out = {}
        for k, v in x.items():
            if isinstance(v, str) and (k.lower() == "base64" or len(v) > 512):
                out[k] = f"<omitted {len(v)} chars>"
            else:
                out[k] = _mask_large_values(v)
        return out
    if isinstance(x, list):
        return [_mask_large_values(v) for v in x]
    return x

def _print_api_response(label: str, resp) -> None:
    try:
        ct = resp.headers.get("Content-Type", "")
        print(label, resp.status_code)
        if "json" in ct:
            try:
                obj = resp.json()
                obj = _mask_large_values(obj)
                print(json.dumps(obj))
            except Exception:
                print(resp.text[:1000])
        elif "text" in ct or ct == "":
            print(resp.text[:2000])
        else:
            print(f"<binary {ct} {len(resp.content)} bytes>")
    except Exception:
        pass

def b64_image(path: str) -> dict:
    with open(path, "rb") as f:
        return {
            "type": "base64",
            "base64": base64.b64encode(f.read()).decode("utf-8"),
            "format": "png",
        }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--name")
    p.add_argument("--description")
    p.add_argument("--action", default="slash")
    p.add_argument("--size", type=int, default=64)
    p.add_argument("--n_frames", type=int, default=4)
    p.add_argument("--reference_png")
    p.add_argument("--no_reference", action="store_true")
    p.add_argument("--template", default="fireball")
    p.add_argument("--directions", default="south")
    p.add_argument("--view", default="side")
    p.add_argument("--replay_dir")
    p.add_argument("--no_preview", action="store_true")
    args = p.parse_args()

    token = os.environ.get("PIXELLAB_API_TOKEN", "").strip()
    if not token:
        raise SystemExit("Set PIXELLAB_API_TOKEN")

    def rand_code() -> str:
        alphabet = "abcdefghjkmnpqrstuvwxyz"  # avoid visually confusing chars
        return "".join(random.choice(alphabet) for _ in range(4))

    if args.replay_dir:
        out_dir = pathlib.Path(args.replay_dir)
        if not out_dir.exists():
            raise SystemExit("replay_dir does not exist")
        if not args.no_preview:
            preview_pygame(out_dir, args.size)
        print(str(out_dir))
        return

    if args.no_reference:
        char_payload = {
            "description": args.description or "energy slash effect",
            "image_size": {"width": args.size, "height": args.size},
            "view": args.view.replace("_", " ") if "_" in args.view else args.view,
            "async_mode": True,
        }
        r = requests.post(
            "https://api.pixellab.ai/v2/create-character-with-4-directions",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            data=json.dumps(char_payload),
            timeout=120,
        )
        _print_api_response("POST /v2/create-character-with-4-directions", r)
        r.raise_for_status()
        data = r.json()
        job_id = data.get("background_job_id")
        character_id = data.get("character_id")
        if not job_id or not character_id:
            raise SystemExit("Character creation did not return IDs")
        while True:
            jr = requests.get(
                f"https://api.pixellab.ai/v2/background-jobs/{job_id}",
                headers={"Authorization": f"Bearer {token}"},
                timeout=30,
            )
            _print_api_response("GET /v2/background-jobs/{job_id}", jr)
            jr.raise_for_status()
            j = jr.json()
            if j.get("status") in ("completed", "failed"):
                if j.get("status") == "failed":
                    raise SystemExit("Character job failed")
                break
            time.sleep(5)
        anim_payload = {
            "character_id": character_id,
            "template_animation_id": args.template,
            "directions": [d.strip() for d in args.directions.split(",") if d.strip()],
            "async_mode": True,
        }
        ar = requests.post(
            "https://api.pixellab.ai/v2/animate-character",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            data=json.dumps(anim_payload),
            timeout=120,
        )
        _print_api_response("POST /v2/animate-character", ar)
        ar.raise_for_status()
        adata = ar.json()
        job_ids = adata.get("background_job_ids", [])
        if not job_ids:
            raise SystemExit("No animation jobs returned")
        for jid in job_ids:
            while True:
                jr = requests.get(
                    f"https://api.pixellab.ai/v2/background-jobs/{jid}",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=30,
                )
                _print_api_response("GET /v2/background-jobs/{jid}", jr)
                jr.raise_for_status()
                j = jr.json()
                if j.get("status") in ("completed", "failed"):
                    if j.get("status") == "failed":
                        raise SystemExit("Animation job failed")
                    break
                time.sleep(5)
        while True:
            zr = requests.get(
                f"https://api.pixellab.ai/v2/characters/{character_id}/zip",
                headers={"Authorization": f"Bearer {token}"},
                timeout=120,
            )
            _print_api_response("GET /v2/characters/{character_id}/zip", zr)
            if zr.status_code == 423:
                time.sleep(5)
                continue
            zr.raise_for_status()
            break
        buf = io.BytesIO(zr.content)
        with zipfile.ZipFile(buf) as zf:
            code = rand_code()
            base = args.name or args.template
            out_dir = pathlib.Path("test_proj/effects") / f"{base}_{code}"
            out_dir.mkdir(parents=True, exist_ok=True)
            dir_choices = [d.strip() for d in args.directions.split(",") if d.strip()]
            chosen_dir = dir_choices[0] if dir_choices else "south"
            frames = []
            prefix = f"animations/{args.template}/{chosen_dir}/"
            for n in zf.namelist():
                if n.startswith(prefix) and n.lower().endswith(".png"):
                    frames.append(n)
            frames.sort()
            if not frames:
                raise SystemExit("No frames found in zip")
            for i, n in enumerate(frames):
                data = zf.read(n)
                (out_dir / f"frame_{i:03d}.png").write_bytes(data)
            if not args.no_preview:
                preview_pygame(out_dir, args.size)
            print(str(out_dir))
    else:
        if not args.reference_png:
            raise SystemExit("--reference_png is required unless --no_reference is used")
        payload = {
            "description": args.description or "energy slash effect",
            "action": args.action,
            "view": args.view.replace("_", " ") if "_" in args.view else args.view,
            "direction": (args.directions.split(",")[0] or "south"),
            "image_size": {"width": args.size, "height": args.size},
            "reference_image": b64_image(args.reference_png),
            "n_frames": args.n_frames,
        }
        r = requests.post(
            "https://api.pixellab.ai/v2/animate-with-text",
            headers={
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
            },
            data=json.dumps(payload),
            timeout=120,
        )
        _print_api_response("POST /v2/animate-with-text", r)
        r.raise_for_status()
        data = r.json()
        images = data.get("images", [])
        if not images:
            raise SystemExit("No images in response")
        code = rand_code()
        base = args.name or args.action
        out_dir = pathlib.Path("test_proj/effects") / f"{base}_{code}"
        out_dir.mkdir(parents=True, exist_ok=True)
        for i, img in enumerate(images):
            raw = base64.b64decode(img["base64"])
            (out_dir / f"frame_{i:03d}.png").write_bytes(raw)
        if not args.no_preview:
            preview_pygame(out_dir, args.size)
        print(str(out_dir))


if __name__ == "__main__":
    main()


