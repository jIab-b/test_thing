import os
from io import BytesIO
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from dotenv import load_dotenv
from PIL import Image, ImageDraw
import requests
import fal_client

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent
STATIC_DIR = BASE_DIR / "static"
TILES_DIR = BASE_DIR / "tiles"
TILE_SIZE = 256
ZOOM_LEVEL = 8
FAL_KEY = os.getenv("FAL_KEY") or os.getenv("FAL_API_KEY") or ""
if FAL_KEY:
	fal_client.api_key = FAL_KEY

app = FastAPI()
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


class GenerateIn(BaseModel):
	x: int
	y: int
	z: int
	prompt: str


@app.get("/")
def root():
	return FileResponse(str(STATIC_DIR / "index.html"))


@app.get("/tiles/{z}/{x}/{y}.png")
def get_tile(z: int, x: int, y: int):
	path = TILES_DIR / str(z) / str(x) / f"{y}.png"
	if path.exists():
		return FileResponse(str(path))
	raise HTTPException(status_code=404, detail="not found")


@app.delete("/tiles/{z}/{x}/{y}")
def delete_tile(z: int, x: int, y: int):
	path = TILES_DIR / str(z) / str(x) / f"{y}.png"
	try:
		path.unlink(missing_ok=True)
	except TypeError:
		if path.exists():
			path.unlink()
	return {"ok": True}


def make_checkerboard(size: int, cell: int = 32) -> Image.Image:
	img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	d = ImageDraw.Draw(img)
	for j in range(0, size, cell):
		for i in range(0, size, cell):
			if ((i // cell) + (j // cell)) % 2 == 0:
				d.rectangle([i, j, i + cell, j + cell], fill=(180, 180, 180, 160))
			else:
				d.rectangle([i, j, i + cell, j + cell], fill=(140, 140, 140, 160))
	return img


def build_collage(z: int, x: int, y: int) -> Image.Image:
	canvas = Image.new("RGBA", (TILE_SIZE * 3, TILE_SIZE * 3), (0, 0, 0, 0))
	matte = make_checkerboard(TILE_SIZE)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			src = TILES_DIR / str(z) / str(x + dx) / f"{y + dy}.png"
			pos = ((dx + 1) * TILE_SIZE, (dy + 1) * TILE_SIZE)
			try:
				with Image.open(src) as im:
					canvas.paste(im.convert("RGBA"), pos)
			except Exception:
				canvas.paste(matte, pos)
	canvas.paste(matte, (TILE_SIZE, TILE_SIZE))
	return canvas


def try_fal_upload(png_bytes: bytes) -> Optional[str]:
	try:
		res = fal_client.upload_image(BytesIO(png_bytes))
		if isinstance(res, dict):
			if res.get("url"):
				return res["url"]
			if isinstance(res.get("image"), dict) and res["image"].get("url"):
				return res["image"]["url"]
	except Exception:
		pass
	return None


def fallback_public_upload(png_bytes: bytes) -> Optional[str]:
	try:
		r = requests.post("https://0x0.st", files={"file": ("collage.png", png_bytes, "image/png")}, timeout=60)
		if 200 <= r.status_code < 300:
			u = r.text.strip()
			if u.startswith("http"):
				return u
	except Exception:
		pass
	return None


def extract_result_url(obj) -> Optional[str]:
	if not isinstance(obj, dict):
		return None
	if isinstance(obj.get("image"), dict) and obj["image"].get("url"):
		return obj["image"]["url"]
	if obj.get("image_url"):
		return obj["image_url"]
	if isinstance(obj.get("images"), list) and obj["images"]:
		first = obj["images"][0]
		if isinstance(first, dict) and first.get("url"):
			return first["url"]
	if isinstance(obj.get("output"), list) and obj["output"]:
		first = obj["output"][0]
		if isinstance(first, dict) and first.get("url"):
			return first["url"]
	return None


def call_flash_edit(image_url: str, prompt: str) -> Optional[str]:
	try:
		res = fal_client.subscribe("fal-ai/gemini-flash-edit", arguments={"prompt": prompt, "image_url": image_url})
		if isinstance(res, dict):
			url = extract_result_url(res)
			if url:
				return url
	except Exception:
		pass
	try:
		res = fal_client.subscribe("fal-ai/gemini-flash-edit", {"prompt": prompt, "image_url": image_url})
		if isinstance(res, dict):
			url = extract_result_url(res)
			if url:
				return url
	except Exception:
		pass
	try:
		headers = {"Authorization": f"Key {FAL_KEY}", "Content-Type": "application/json"}
		payloads = [
			{"prompt": prompt, "image_url": image_url},
			{"prompt": prompt, "image_urls": [image_url]},
		]
		for body in payloads:
			resp = requests.post("https://fal.run/fal-ai/gemini-flash-edit", json=body, headers=headers, timeout=120)
			if resp.status_code // 100 == 2:
				try:
					data = resp.json()
				except Exception:
					data = None
				if isinstance(data, dict):
					url = extract_result_url(data)
					if url:
						return url
	except Exception:
		pass
	return None


@app.post("/generate")
def generate(inp: GenerateIn):
	if inp.z != ZOOM_LEVEL:
		raise HTTPException(status_code=400, detail="z must be 8")
	try:
		collage = build_collage(inp.z, inp.x, inp.y)
		buf = BytesIO()
		collage.save(buf, format="PNG")
		png_bytes = buf.getvalue()
		uploaded = try_fal_upload(png_bytes) or fallback_public_upload(png_bytes)
		if not uploaded:
			return JSONResponse({"ok": False, "error": "upload failed"})
		full_prompt = f"{inp.prompt} Only fill the checkerboard center tile; keep all areas outside the checkerboard exactly unchanged; match edges to neighbors; no text."
		out_url = call_flash_edit(uploaded, full_prompt)
		if not out_url:
			return JSONResponse({"ok": False, "error": "model failed"})
		r = requests.get(out_url, timeout=120)
		if r.status_code // 100 != 2:
			return JSONResponse({"ok": False, "error": "download failed"})
		with Image.open(BytesIO(r.content)) as im:
			w, h = im.size
			tile = im.crop((int(w / 3), int(h / 3), int(2 * w / 3), int(2 * h / 3)))
			if tile.size != (TILE_SIZE, TILE_SIZE):
				tile = tile.resize((TILE_SIZE, TILE_SIZE), Image.LANCZOS)
			out_dir = TILES_DIR / str(inp.z) / str(inp.x)
			out_dir.mkdir(parents=True, exist_ok=True)
			out_path = out_dir / f"{inp.y}.png"
			tile.save(out_path)
		return {"ok": True}
	except Exception as e:
		return JSONResponse({"ok": False, "error": str(e)})