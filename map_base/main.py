from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import os
import json

app = FastAPI()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")
DATA_DIR = os.path.join(BASE_DIR, "data")
os.makedirs(STATIC_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)

app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

class MapPayload(BaseModel):
    tile_size: int
    grid_width: int
    grid_height: int
    layers: dict

@app.get("/")
def index():
    index_path = os.path.join(STATIC_DIR, "index.html")
    if not os.path.exists(index_path):
        raise HTTPException(status_code=404, detail="index.html not found")
    return FileResponse(index_path)

@app.get("/api/map/{name}")
async def load_map(name: str):
    path = os.path.join(DATA_DIR, f"{name}.json")
    if not os.path.exists(path):
        return {"version": 2, "tile_size": 32, "grid_width": 120, "grid_height": 68, "layers": {"block (coll)": [], "blue spawn": [], "red spawn": [], "health refill": [], "attack refill": []}}
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

@app.post("/api/map/{name}")
async def save_map(name: str, payload: MapPayload):
    path = os.path.join(DATA_DIR, f"{name}.json")
    data = payload.model_dump()
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    return {"ok": True}
