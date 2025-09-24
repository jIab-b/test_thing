import os
import sys
import time
import json
import base64
import argparse
from pathlib import Path

import pygame
import requests


def load_env():
    env = {}
    try:
        from dotenv import load_dotenv
        load_dotenv()
    except Exception:
        pass
    env["PIXELAB_API_KEY"] = os.getenv("PIXELAB_API_KEY", "")
    env["PIXELAB_API_BASE"] = os.getenv("PIXELAB_API_BASE", "").rstrip("/")
    return env


class PixelabClient:
    def __init__(self, base_url: str, api_key: str):
        self.base_url = base_url
        self.api_key = api_key

    def _headers(self):
        h = {"Accept": "application/json"}
        if self.api_key:
            h["Authorization"] = f"Bearer {self.api_key}"
        return h

    def _decode_image(self, resp: requests.Response) -> bytes:
        ct = resp.headers.get("Content-Type", "")
        if "application/json" in ct:
            js = resp.json()
            data = js.get("image") or js.get("png") or js.get("data")
            if not data and isinstance(js.get("images"), list) and js["images"]:
                data = js["images"][0]
            if not data:
                raise RuntimeError("No image in response")
            return base64.b64decode(data)
        return resp.content

    def generate(self, width: int, height: int, prompt: str) -> bytes:
        url = self.base_url + "/v1/images/generate"
        payload = {"prompt": prompt, "width": int(width), "height": int(height)}
        r = requests.post(url, headers=self._headers(), json=payload, timeout=180)
        if r.status_code == 404:
            url = self.base_url + "/v1/generate"
            r = requests.post(url, headers=self._headers(), json=payload, timeout=180)
        r.raise_for_status()
        return self._decode_image(r)

    def inpaint(self, image_png: bytes, mask_png: bytes, prompt: str) -> bytes:
        url = self.base_url + "/v1/images/inpaint"
        files = {
            "image": ("image.png", image_png, "image/png"),
            "mask": ("mask.png", mask_png, "image/png"),
        }
        data = {"prompt": prompt}
        r = requests.post(url, headers=self._headers(), data=data, files=files, timeout=240)
        if r.status_code == 404:
            url = self.base_url + "/v1/inpaint"
            r = requests.post(url, headers=self._headers(), data=data, files=files, timeout=240)
        r.raise_for_status()
        return self._decode_image(r)


def parse_grid(s):
    p = s.lower().split("x")
    if len(p) != 2:
        raise ValueError("grid must be WxH")
    return int(p[0]), int(p[1])


def ensure_dir(path):
    d = os.path.dirname(os.path.abspath(path))
    if d and not os.path.exists(d):
        os.makedirs(d, exist_ok=True)


def load_json(path):
    if not os.path.exists(path):
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path, data):
    ensure_dir(path)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))


class Selection:
    def __init__(self):
        self.active = False
        self.start_cell = None
        self.end_cell = None

    def rect_cells(self):
        if not self.start_cell or not self.end_cell:
            return None
        x0, y0 = self.start_cell
        x1, y1 = self.end_cell
        x0, x1 = sorted([x0, x1])
        y0, y1 = sorted([y0, y1])
        w = max(1, x1 - x0 + 1)
        h = max(1, y1 - y0 + 1)
        return x0, y0, w, h


def make_blank_png(width: int, height: int, color=(0, 0, 0, 0)) -> bytes:
    surf = pygame.Surface((width, height), flags=pygame.SRCALPHA)
    surf.fill(color)
    return pygame.image.tobytes(surf, "RGBA")


def surface_to_png_bytes(surf: pygame.Surface) -> bytes:
    w, h = surf.get_size()
    data = pygame.image.tobytes(surf, "RGBA")
    try:
        from PIL import Image
        import io
        im = Image.frombytes("RGBA", (w, h), data)
        buf = io.BytesIO()
        im.save(buf, format="PNG")
        return buf.getvalue()
    except Exception:
        arr = pygame.surfarray.array3d(surf)
        import tempfile
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".bmp")
        tmp.close()
        pygame.image.save(surf, tmp.name)
        b = Path(tmp.name).read_bytes()
        os.unlink(tmp.name)
        return b


def bytes_to_surface(png_bytes: bytes) -> pygame.Surface:
    import io
    return pygame.image.load(io.BytesIO(png_bytes)).convert_alpha()


def world_to_screen(x, y, tile, cam, zoom):
    return int((x * tile - cam[0]) * zoom), int((y * tile - cam[1]) * zoom)


def screen_to_cell(mx, my, tile, cam, zoom, gw, gh):
    wx = cam[0] + mx / max(zoom, 1e-6)
    wy = cam[1] + my / max(zoom, 1e-6)
    cx = max(0, min(gw - 1, int(wx // tile)))
    cy = max(0, min(gh - 1, int(wy // tile)))
    return cx, cy


def draw_grid(screen, tile, cam, zoom):
    grid_color = (180, 188, 200)
    step = int(tile * zoom)
    if step >= 8:
        x0 = -int(cam[0] * zoom) % max(step, 1)
        y0 = -int(cam[1] * zoom) % max(step, 1)
        for x in range(x0, screen.get_width(), step):
            pygame.draw.line(screen, grid_color, (x, 0), (x, screen.get_height()), 1)
        for y in range(y0, screen.get_height(), step):
            pygame.draw.line(screen, grid_color, (0, y), (screen.get_width(), y), 1)


def draw_sidebar(screen, rect, font, state):
    pygame.draw.rect(screen, (245, 246, 250), rect)
    pad = 12
    x = rect.x + pad
    y = rect.y + pad
    def put(text, color=(40,40,48)):
        nonlocal y
        t = font.render(text, True, color)
        screen.blit(t, (x, y))
        y += t.get_height() + 10
    put("Pixelab")
    put(f"Mode: {state['mode'].upper()} (1/2)")
    put(f"Block layer: {state['layer']} (L)")
    put("Prompt (P to edit):")
    prompt_preview = state["prompt"] if len(state["prompt"]) <= 36 else state["prompt"][:33] + "..."
    put(prompt_preview, (70,70,90))
    put("Drag select  |  RMB pan")
    put("G generate   |  I inpaint")
    put("S save       |  O load")


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--grid", "-g", default="120x68")
    parser.add_argument("--tile", "-t", type=int, default=32)
    parser.add_argument("--file", "-f", default="")
    parser.add_argument("--map", "-m", default="1283")
    parser.add_argument("--out", "-o", default="")
    a = parser.parse_args()

    gw, gh = parse_grid(a.grid)
    tile = max(8, int(a.tile))
    saved_dir = os.path.join("saved_maps")
    os.makedirs(saved_dir, exist_ok=True)
    map_name = str(a.map)
    if map_name.isdigit():
        map_name = map_name[-4:].zfill(4)
    dst_file = a.file if a.file else os.path.join(saved_dir, f"map_{map_name}.json")
    if a.out:
        dst_file = a.out

    data = load_json(dst_file)
    if data:
        layers = data.get("layers", {})
        gw = int(data.get("grid_width", gw))
        gh = int(data.get("grid_height", gh))
        tile = int(data.get("tile_size", tile))
    else:
        layers = {}

    pygame.init()
    screen = pygame.display.set_mode((1280, 720))
    pygame.display.set_caption("Map Pixel Editor")
    clock = pygame.time.Clock()
    font = pygame.font.SysFont("consolas", 16)

    blocks = {}
    pickups = {}
    col1 = set()
    col2 = set()
    patches = []

    if layers:
        for p in layers.get("blocks", []):
            if isinstance(p, list) and len(p) >= 3:
                blocks[(int(p[0]), int(p[1]))] = int(p[2])
        for p in layers.get("pickups", []):
            if isinstance(p, list) and len(p) >= 3:
                pickups[(int(p[0]), int(p[1]))] = int(p[2])
        for p in layers.get("collision_layer_1", []):
            if isinstance(p, list) and len(p) == 2:
                col1.add((int(p[0]), int(p[1])))
        for p in layers.get("collision_layer_2", []):
            if isinstance(p, list) and len(p) == 2:
                col2.add((int(p[0]), int(p[1])))
        for p in layers.get("patches", []):
            if isinstance(p, dict):
                patches.append(p)

    cam = [0, 0]
    zoom = 1.0
    selection = Selection()
    editing_prompt = False
    prompt = "lush forest ruins top-down tiles"
    mode = "generate"
    max_gen_px = 400
    max_inp_px = 200
    rdrag = False
    last_mouse = None
    layer_mode = 0

    env = load_env()
    client = PixelabClient(env.get("PIXELAB_API_BASE", ""), env.get("PIXELAB_API_KEY", ""))

    running = True
    last_cell = None

    def draw_scene():
        screen.fill((236, 240, 244))
        for (x, y), t in blocks.items():
            c = [(170,170,170), (220,180,180), (180,220,180), (180,180,230), (230,230,180)][t % 5]
            px, py = world_to_screen(x, y, tile, cam, zoom)
            pygame.draw.rect(screen, c, (px, py, int(tile * zoom), int(tile * zoom)))
        for (x, y) in col1:
            px, py = world_to_screen(x, y, tile, cam, zoom)
            pygame.draw.rect(screen, (210,80,80), (px, py, int(tile * zoom), int(tile * zoom)))
        for (x, y) in col2:
            px, py = world_to_screen(x, y, tile, cam, zoom)
            pygame.draw.rect(screen, (70,130,230), (px, py, int(tile * zoom), int(tile * zoom)))
        for p in patches:
            fp = p.get("file", "")
            if fp and os.path.exists(fp):
                try:
                    s = bytes_to_surface(Path(fp).read_bytes())
                except Exception:
                    s = None
                if s:
                    w_cells = int(p.get("w", 1))
                    h_cells = int(p.get("h", 1))
                    s2 = pygame.transform.smoothscale(s, (int(w_cells * tile * zoom), int(h_cells * tile * zoom)))
                    px, py = world_to_screen(int(p.get("x", 0)), int(p.get("y", 0)), tile, cam, zoom)
                    screen.blit(s2, (px, py))
        draw_grid(screen, tile, cam, zoom)
        rect = selection.rect_cells()
        if rect:
            x0, y0, w, h = rect
            px, py = world_to_screen(x0, y0, tile, cam, zoom)
            pygame.draw.rect(screen, (30, 120, 255), (px, py, int(w*tile*zoom), int(h*tile*zoom)), 2)
        sidebar = pygame.Rect(screen.get_width() - 280, 0, 280, screen.get_height())
        draw_sidebar(screen, sidebar, font, {
            "mode": mode,
            "prompt": prompt + ("_" if editing_prompt else ""),
            "layer": layer_mode,
        })
        pygame.display.flip()

    def capture_region_surface(x, y, w, h):
        surf = pygame.Surface((w * tile, h * tile), flags=pygame.SRCALPHA)
        for p in patches:
            fp = p.get("file", "")
            if not fp or not os.path.exists(fp):
                continue
            px0 = int(p.get("x", 0))
            py0 = int(p.get("y", 0))
            pw = int(p.get("w", 1))
            ph = int(p.get("h", 1))
            rx0 = max(x, px0)
            ry0 = max(y, py0)
            rx1 = min(x + w, px0 + pw)
            ry1 = min(y + h, py0 + ph)
            if rx1 <= rx0 or ry1 <= ry0:
                continue
            sub = bytes_to_surface(Path(fp).read_bytes())
            sub = pygame.transform.smoothscale(sub, (pw * tile, ph * tile))
            offx = (rx0 - x) * tile
            offy = (ry0 - y) * tile
            srcx = (rx0 - px0) * tile
            srcy = (ry0 - py0) * tile
            rect = pygame.Rect(srcx, srcy, (rx1 - rx0) * tile, (ry1 - ry0) * tile)
            surf.blit(sub, (offx, offy), rect)
        return surf

    def save_patch_image(img_bytes, x, y, w, h):
        out_dir = Path("test_proj/assets/tilesets/generated_patches")
        out_dir.mkdir(parents=True, exist_ok=True)
        name = f"patch_{int(time.time()*1000)}.png"
        fp = out_dir / name
        fp.write_bytes(img_bytes)
        patches.append({"file": str(fp), "x": x, "y": y, "w": w, "h": h})

    def do_generate(rect):
        if not env.get("PIXELAB_API_BASE"):
            return
        x0, y0, w, h = rect
        max_cells_w = max(1, max_gen_px // tile)
        max_cells_h = max(1, max_gen_px // tile)
        for yy in range(y0, y0 + h, max_cells_h):
            for xx in range(x0, x0 + w, max_cells_w):
                cw = min(max_cells_w, x0 + w - xx)
                ch = min(max_cells_h, y0 + h - yy)
                img = client.generate(cw * tile, ch * tile, prompt)
                save_patch_image(img, xx, yy, cw, ch)

    def do_inpaint(rect):
        if not env.get("PIXELAB_API_BASE"):
            return
        x0, y0, w, h = rect
        max_cells_w = max(1, max_inp_px // tile)
        max_cells_h = max(1, max_inp_px // tile)
        for yy in range(y0, y0 + h, max_cells_h):
            for xx in range(x0, x0 + w, max_cells_w):
                cw = min(max_cells_w, x0 + w - xx)
                ch = min(max_cells_h, y0 + h - yy)
                surf = capture_region_surface(xx, yy, cw, ch)
                init_png = surface_to_png_bytes(surf)
                mask_surf = pygame.Surface((cw * tile, ch * tile), flags=pygame.SRCALPHA)
                mask_surf.fill((255,255,255,255))
                mask_png = surface_to_png_bytes(mask_surf)
                img = client.inpaint(init_png, mask_png, prompt)
                save_patch_image(img, xx, yy, cw, ch)

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if editing_prompt:
                    if event.key == pygame.K_RETURN:
                        editing_prompt = False
                    elif event.key == pygame.K_BACKSPACE:
                        prompt = prompt[:-1]
                    else:
                        if event.unicode and event.unicode.isprintable():
                            prompt += event.unicode
                else:
                    if event.key == pygame.K_ESCAPE:
                        running = False
                    elif event.key == pygame.K_1:
                        mode = "generate"
                    elif event.key == pygame.K_2:
                        mode = "inpaint"
                    elif event.key == pygame.K_l:
                        layer_mode = 1 - layer_mode
                    elif event.key == pygame.K_q:
                        zoom = min(4.0, zoom * 1.1)
                    elif event.key == pygame.K_e:
                        zoom = max(0.25, zoom / 1.1)
                    elif event.key == pygame.K_a:
                        cam[0] -= 500 * clock.get_time() / 1000.0 / max(zoom, 1e-6)
                    elif event.key == pygame.K_d:
                        cam[0] += 500 * clock.get_time() / 1000.0 / max(zoom, 1e-6)
                    elif event.key == pygame.K_w:
                        cam[1] -= 500 * clock.get_time() / 1000.0 / max(zoom, 1e-6)
                    elif event.key == pygame.K_s:
                        out = {
                            "version": 3,
                            "tile_size": tile,
                            "grid_width": gw,
                            "grid_height": gh,
                            "layers": {
                                "blocks": sorted([[x, y, t] for ((x, y), t) in blocks.items()]),
                                "pickups": sorted([[x, y, t] for ((x, y), t) in pickups.items()]),
                                "collision_layer_1": sorted([[x, y] for (x, y) in col1]),
                                "collision_layer_2": sorted([[x, y] for (x, y) in col2]),
                                "patches": patches,
                            }
                        }
                        save_json(dst_file, out)
                    elif event.key == pygame.K_o:
                        d = load_json(dst_file)
                        if d:
                            nonlocal_tile = int(d.get("tile_size", tile))
                            nonlocal_gw = int(d.get("grid_width", gw))
                            nonlocal_gh = int(d.get("grid_height", gh))
                            blocks.clear(); pickups.clear(); col1.clear(); col2.clear(); patches.clear()
                            layers = d.get("layers", {})
                            for p in layers.get("blocks", []):
                                if isinstance(p, list) and len(p) >= 3:
                                    blocks[(int(p[0]), int(p[1]))] = int(p[2])
                            for p in layers.get("pickups", []):
                                if isinstance(p, list) and len(p) >= 3:
                                    pickups[(int(p[0]), int(p[1]))] = int(p[2])
                            for p in layers.get("collision_layer_1", []):
                                if isinstance(p, list) and len(p) == 2:
                                    col1.add((int(p[0]), int(p[1])))
                            for p in layers.get("collision_layer_2", []):
                                if isinstance(p, list) and len(p) == 2:
                                    col2.add((int(p[0]), int(p[1])))
                            for p in layers.get("patches", []):
                                if isinstance(p, dict):
                                    patches.append(p)
                            gw = nonlocal_gw
                            gh = nonlocal_gh
                            tile = nonlocal_tile
                    elif event.key == pygame.K_p:
                        editing_prompt = True
                    elif event.key == pygame.K_g:
                        rect = selection.rect_cells()
                        if rect:
                            mode = "generate"
                            do_generate(rect)
                    elif event.key == pygame.K_i:
                        rect = selection.rect_cells()
                        if rect:
                            mode = "inpaint"
                            do_inpaint(rect)
                    elif event.key == pygame.K_LEFTBRACKET:
                        max_gen_px = max(64, max_gen_px - 16)
                    elif event.key == pygame.K_RIGHTBRACKET:
                        max_gen_px = min(1024, max_gen_px + 16)
                    elif event.key == pygame.K_SEMICOLON:
                        max_inp_px = max(64, max_inp_px - 16)
                    elif event.key == pygame.K_QUOTE:
                        max_inp_px = min(1024, max_inp_px + 16)
                    elif event.key == pygame.K_t:
                        tile = max(4, tile - 2)
                    elif event.key == pygame.K_y:
                        tile = min(128, tile + 2)
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:
                    cx, cy = screen_to_cell(*pygame.mouse.get_pos(), tile, cam, zoom, gw, gh)
                    selection.active = True
                    selection.start_cell = (cx, cy)
                    selection.end_cell = (cx, cy)
                    last_cell = (cx, cy)
                elif event.button == 3:
                    rdrag = True
                    last_mouse = pygame.mouse.get_pos()
            elif event.type == pygame.MOUSEBUTTONUP:
                if event.button == 1:
                    selection.active = False
                elif event.button == 3:
                    rdrag = False
                    last_mouse = None
            elif event.type == pygame.MOUSEMOTION:
                if selection.active:
                    cx, cy = screen_to_cell(*pygame.mouse.get_pos(), tile, cam, zoom, gw, gh)
                    if last_cell != (cx, cy):
                        sx, sy = selection.start_cell if selection.start_cell else (cx, cy)
                        cap_px = max_gen_px if mode == "generate" else max_inp_px
                        cap_cells = max(1, cap_px // tile)
                        dx = cx - sx
                        dy = cy - sy
                        if dx >= 0:
                            dx = min(dx, cap_cells - 1)
                        else:
                            dx = max(dx, -cap_cells + 1)
                        if dy >= 0:
                            dy = min(dy, cap_cells - 1)
                        else:
                            dy = max(dy, -cap_cells + 1)
                        nx = sx + dx
                        ny = sy + dy
                        selection.end_cell = (nx, ny)
                        last_cell = (cx, cy)
                if rdrag:
                    mx, my = pygame.mouse.get_pos()
                    if last_mouse is not None:
                        dx = mx - last_mouse[0]
                        dy = my - last_mouse[1]
                        cam[0] -= dx / max(zoom, 1e-6)
                        cam[1] -= dy / max(zoom, 1e-6)
                    last_mouse = (mx, my)

        draw_scene()
        clock.tick(120)

    pygame.quit()


if __name__ == "__main__":
    try:
        run()
    except Exception as e:
        print(str(e))
        sys.exit(1)


