import os
import io
import json
import time
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel
import logging
from PIL import Image
import pixellab


def load_env():
    try:
        from dotenv import load_dotenv
        project_root = Path(__file__).resolve().parents[1]
        load_dotenv(dotenv_path=project_root / ".env")
    except Exception:
        pass
    return {
        "PIXELAB_API_KEY": os.getenv("PIXELAB_API_KEY", ""),
        "PIXELAB_API_BASE": os.getenv("PIXELAB_API_BASE", "").rstrip("/"),
        "PIXELAB_GEN_MAX_PX": int(os.getenv("PIXELAB_GEN_MAX_PX", "400") or 400),
        "PIXELAB_INP_MAX_PX": int(os.getenv("PIXELAB_INP_MAX_PX", "200") or 200),
        "PIXELAB_GENERATE_PATH": os.getenv("PIXELAB_GENERATE_PATH", "/v1/images/generate"),
        "PIXELAB_GENERATE_FALLBACK": os.getenv("PIXELAB_GENERATE_FALLBACK", "/v1/generate"),
        "PIXELAB_INPAINT_PATH": os.getenv("PIXELAB_INPAINT_PATH", "/v1/images/inpaint"),
        "PIXELAB_INPAINT_FALLBACK": os.getenv("PIXELAB_INPAINT_FALLBACK", "/v1/inpaint"),
    }




class GenerateBody(BaseModel):
    x: int
    y: int
    w: int
    h: int
    prompt: str


class InpaintBody(BaseModel):
    x: int
    y: int
    w: int
    h: int
    prompt: str | None = None


class DeleteBody(BaseModel):
    x: int
    y: int
    w: int
    h: int


app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

root = Path(__file__).resolve().parent
static_dir = root / "static"
gen_dir = root / "generated"
gen_dir.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")
app.mount("/generated", StaticFiles(directory=str(gen_dir)), name="generated")

env = load_env()
px = pixellab.Client(secret=env["PIXELAB_API_KEY"])
logger = logging.getLogger("web_map")
logging.basicConfig(level=logging.INFO)
print(f"PIXELAB_API_BASE={env.get('PIXELAB_API_BASE','')}")
print(f"PIXELAB_API_KEY={env.get('PIXELAB_API_KEY','')}")
print(f"PIXELAB_GENERATE_PATH={env.get('PIXELAB_GENERATE_PATH','')}")
print(f"PIXELAB_INPAINT_PATH={env.get('PIXELAB_INPAINT_PATH','')}")

state_path = Path("saved_maps/map_web.json")
if state_path.exists():
    state = json.load(open(state_path, "r", encoding="utf-8"))
else:
    state = {
        "version": 3,
        "tile_size": 32,
        "grid_width": 120,
        "grid_height": 68,
        "layers": {
            "blocks": [],
            "pickups": [],
            "collision_layer_1": [],
            "collision_layer_2": [],
            "patches": [],
        },
    }


def save_state():
    state_path.parent.mkdir(parents=True, exist_ok=True)
    json.dump(state, open(state_path, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))


@app.get("/")
def index():
    index_path = static_dir / "index.html"
    if not index_path.exists():
        raise HTTPException(500, "index.html not found")
    return FileResponse(str(index_path))


@app.get("/favicon.ico")
def favicon():
    icon = static_dir / "favicon.ico"
    if icon.exists():
        return FileResponse(str(icon))
    # Return a 1x1 transparent PNG if no favicon present
    from PIL import Image
    import io
    buf = io.BytesIO()
    Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(buf, format="PNG")
    buf.seek(0)
    return Response(content=buf.getvalue(), media_type="image/png")


@app.get("/api/state")
def get_state():
    return state


class SetStateBody(BaseModel):
    data: dict


@app.post("/api/state")
def set_state(b: SetStateBody):
    global state
    state = b.data
    save_state()
    return {"ok": True}


def compose_region(x: int, y: int, w: int, h: int) -> bytes:
    tile = int(state.get("tile_size", 32))
    img = Image.new("RGBA", (w * tile, h * tile), (0, 0, 0, 0))
    for p in state.get("layers", {}).get("patches", []):
        fp = p.get("file", "")
        if not fp:
            continue
        src_path = Path(fp)
        if not src_path.is_absolute():
            src_path = gen_dir / Path(fp).name
        if not src_path.exists():
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
        sub = Image.open(src_path).convert("RGBA").resize((pw * tile, ph * tile), Image.NEAREST)
        srcx = (rx0 - px0) * tile
        srcy = (ry0 - py0) * tile
        box = (srcx, srcy, srcx + (rx1 - rx0) * tile, srcy + (ry1 - ry0) * tile)
        crop = sub.crop(box)
        ox = (rx0 - x) * tile
        oy = (ry0 - y) * tile
        img.paste(crop, (ox, oy), crop)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def save_patch(img_bytes: bytes, x: int, y: int, w: int, h: int) -> dict:
    name = f"patch_{int(time.time()*1000)}_{x}_{y}_{w}_{h}.png"
    path = gen_dir / name
    with open(path, "wb") as f:
        f.write(img_bytes)
    rec = {"file": str(path), "url": f"/generated/{name}", "x": x, "y": y, "w": w, "h": h}
    state["layers"]["patches"].append(rec)
    save_state()
    return rec


@app.post("/api/generate")
def api_generate(b: GenerateBody):
    if not env["PIXELAB_API_KEY"]:
        raise HTTPException(400, "Pixelab API not configured: set PIXELAB_API_KEY in .env at project root")
    tile = int(state.get("tile_size", 32))
    cap = int(env["PIXELAB_GEN_MAX_PX"]) // tile
    cap = max(1, cap)
    out = []
    for yy in range(b.y, b.y + b.h, cap):
        for xx in range(b.x, b.x + b.w, cap):
            cw = min(cap, b.x + b.w - xx)
            ch = min(cap, b.y + b.h - yy)
            try:
                logger.info(f"Pixellab pixflux {cw*tile}x{ch*tile}")
                resp = px.generate_image_pixflux(
                    description=b.prompt,
                    image_size={"width": cw * tile, "height": ch * tile},
                )
                im = resp.image.pil_image()
                buf = io.BytesIO()
                im.save(buf, format="PNG")
                img = buf.getvalue()
            except Exception as e:
                logger.exception("Pixelab generate exception")
                raise HTTPException(400, f"Pixelab generate exception: {str(e)}")
            rec = save_patch(img, xx, yy, cw, ch)
            out.append(rec)
    return {"patches": out}


@app.post("/api/inpaint")
def api_inpaint(b: InpaintBody):
    if not env["PIXELAB_API_KEY"]:
        raise HTTPException(400, "Pixelab API not configured: set PIXELAB_API_KEY in .env at project root")
    tile = int(state.get("tile_size", 32))
    cap = int(env["PIXELAB_INP_MAX_PX"]) // tile
    cap = max(1, cap)
    prompt = b.prompt or ""
    out = []
    for yy in range(b.y, b.y + b.h, cap):
        for xx in range(b.x, b.x + b.w, cap):
            cw = min(cap, b.x + b.w - xx)
            ch = min(cap, b.y + b.h - yy)
            init_png = compose_region(xx, yy, cw, ch)
            try:
                mask = Image.new("RGBA", (cw * tile, ch * tile), (255, 255, 255, 255))
                init_img = Image.open(io.BytesIO(init_png)).convert("RGBA")
                logger.info(f"Pixellab bitforge inpaint {cw*tile}x{ch*tile}")
                resp = px.generate_image_bitforge(
                    description=prompt,
                    image_size={"width": cw * tile, "height": ch * tile},
                    inpainting_image=init_img,
                    mask_image=mask,
                )
                im = resp.image.pil_image()
                outbuf = io.BytesIO()
                im.save(outbuf, format="PNG")
                img = outbuf.getvalue()
            except Exception as e:
                logger.exception("Pixelab inpaint exception")
                raise HTTPException(400, f"Pixelab inpaint exception: {str(e)}")
            rec = save_patch(img, xx, yy, cw, ch)
            out.append(rec)
    return {"patches": out}


@app.post("/api/delete")
def api_delete(b: DeleteBody):
    x0, y0, w, h = b.x, b.y, b.w, b.h
    patches_list = state.get("layers", {}).get("patches", [])
    keep = []
    removed = []
    for p in patches_list:
        px0 = int(p.get("x", 0)); py0 = int(p.get("y", 0)); pw = int(p.get("w", 1)); ph = int(p.get("h", 1))
        inter = not (px0+pw <= x0 or x0+w <= px0 or py0+ph <= y0 or y0+h <= py0)
        if inter:
            removed.append(p)
            # best-effort delete file
            try:
                fp = p.get("file", "")
                if fp and Path(fp).exists():
                    Path(fp).unlink(missing_ok=True)
            except Exception:
                pass
        else:
            keep.append(p)
    state["layers"]["patches"] = keep
    save_state()
    return {"removed": [r.get("file", "") for r in removed], "left": len(keep)}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)


