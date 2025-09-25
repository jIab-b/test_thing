Run

- python -m venv venv && venv\Scripts\pip install -r map_base/requirements.txt
- venv\Scripts\uvicorn map_base.main:app --reload

Open http://127.0.0.1:8000/ and use the top bar to select layer, block type, zoom controls, and save/load. Maps are saved under map_base/data/{name}.json with layers: block (coll), blue spawn, red spawn, health refill, attack refill.
