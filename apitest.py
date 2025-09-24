import os
import sys
import json
import base64
import io
from pathlib import Path

import requests
from requests.exceptions import SSLError


def load_env():
    try:
        from dotenv import load_dotenv
        load_dotenv(dotenv_path=Path(__file__).resolve().parent / ".env")
    except Exception:
        pass


def decode_image(resp: requests.Response) -> bytes:
    ct = resp.headers.get("Content-Type", "")
    if ct.startswith("image/"):
        return resp.content
    if "application/json" in ct:
        js = resp.json()
        data = js.get("image") or js.get("png") or js.get("data")
        if not data and isinstance(js.get("images"), list) and js["images"]:
            data = js["images"][0]
        if not data:
            raise RuntimeError("no image in JSON response")
        return base64.b64decode(data)
    raise RuntimeError(f"unsupported content-type {ct}")


def _post_json(url: str, headers: dict, payload: dict):
    print(f"POST {url} {payload}")
    r = requests.post(url, headers=headers, json=payload, timeout=180)
    print(f"RESP {r.status_code} {r.headers.get('Content-Type','')} {len(r.content)}")
    return r


def test_generate(base: str, key: str, gen_path: str, gen_fallback: str) -> bytes:
    url = base.rstrip("/") + gen_path
    h = {"Authorization": f"Bearer {key}", "Accept": "application/json"}
    payload = {"prompt": "small pixel grass tile", "width": 64, "height": 64}
    try:
        r = _post_json(url, h, payload)
    except SSLError as e:
        for alt in ("https://api.pixellab.ai", "https://api.pixelab.app"):
            aurl = alt.rstrip("/") + gen_path
            try:
                r = _post_json(aurl, h, payload)
                base = alt
                break
            except SSLError:
                continue
        else:
            raise e
    if r.status_code == 404:
        url2 = base.rstrip("/") + gen_fallback
        r = _post_json(url2, h, payload)
    if r.status_code >= 400:
        print(r.text[:1000])
        raise RuntimeError(f"generate failed {r.status_code}")
    img = decode_image(r)
    if not img:
        raise RuntimeError("empty image")
    Path("apitest_generate.png").write_bytes(img)
    print("generate ok -> apitest_generate.png")
    return img


def test_inpaint(base: str, key: str, inp_path: str, inp_fallback: str, init_png: bytes) -> bytes:
    try:
        from PIL import Image
    except Exception:
        print("Pillow missing, skipping inpaint test")
        return b""
    img = Image.open(io.BytesIO(init_png)).convert("RGBA")
    w, h = img.size
    m = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    buf = io.BytesIO()
    m.save(buf, format="PNG")
    mask_png = buf.getvalue()
    url = base.rstrip("/") + inp_path
    hds = {"Authorization": f"Bearer {key}", "Accept": "application/json"}
    data = {"prompt": "add subtle detail"}
    files = {"image": ("image.png", init_png, "image/png"), "mask": ("mask.png", mask_png, "image/png")}
    print(f"POST {url} inpaint w={w} h={h}")
    try:
        r = requests.post(url, headers=hds, data=data, files=files, timeout=240)
        print(f"RESP {r.status_code} {r.headers.get('Content-Type','')} {len(r.content)}")
    except SSLError as e:
        for alt in ("https://api.pixellab.ai", "https://api.pixelab.app"):
            aurl = alt.rstrip("/") + inp_path
            try:
                print(f"POST {aurl} inpaint w={w} h={h}")
                r = requests.post(aurl, headers=hds, data=data, files=files, timeout=240)
                print(f"RESP {r.status_code} {r.headers.get('Content-Type','')} {len(r.content)}")
                base = alt
                break
            except SSLError:
                continue
        else:
            raise e
    if r.status_code == 404:
        url2 = base.rstrip("/") + inp_fallback
        print(f"POST {url2} inpaint w={w} h={h}")
        r = requests.post(url2, headers=hds, data=data, files=files, timeout=240)
        print(f"RESP {r.status_code} {r.headers.get('Content-Type','')} {len(r.content)}")
    if r.status_code >= 400:
        print(r.text[:1000])
        raise RuntimeError(f"inpaint failed {r.status_code}")
    out = decode_image(r)
    if not out:
        raise RuntimeError("empty inpaint image")
    Path("apitest_inpaint.png").write_bytes(out)
    print("inpaint ok -> apitest_inpaint.png")
    return out


def main():
    load_env()
    base = os.getenv("PIXELAB_API_BASE", "").rstrip("/")
    key = os.getenv("PIXELAB_API_KEY", "")
    gen_path = os.getenv("PIXELAB_GENERATE_PATH", "/v1/images/generate")
    gen_fallback = os.getenv("PIXELAB_GENERATE_FALLBACK", "/v1/generate")
    inp_path = os.getenv("PIXELAB_INPAINT_PATH", "/v1/images/inpaint")
    inp_fallback = os.getenv("PIXELAB_INPAINT_FALLBACK", "/v1/inpaint")
    if not base or not key:
        print("missing PIXELAB_API_BASE or PIXELAB_API_KEY in .env")
        return 1
    print(f"BASE={base}")
    print(f"KEY={key}")
    gen_img = test_generate(base, key, gen_path, gen_fallback)
    test_inpaint(base, key, inp_path, inp_fallback, gen_img)
    return 0


if __name__ == "__main__":
    sys.exit(main())


