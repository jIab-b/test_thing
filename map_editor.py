import os
import sys
import json
import argparse
import pygame


def parse_grid(s):
    parts = s.lower().split("x")
    if len(parts) != 2:
        raise ValueError("grid must be WxH")
    return int(parts[0]), int(parts[1])


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
        json.dump(data, f, ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--grid", "-g", default="120x68")
    parser.add_argument("--tile", "-t", type=int, default=32)
    parser.add_argument("--file", "-f", default="")
    parser.add_argument("--map", "-m", default="1283", help="Map name or ID (e.g., 1283, loads/saves to saved_maps/map_1283.json)")
    args = parser.parse_args()

    gw, gh = parse_grid(args.grid)
    tile = max(8, int(args.tile))
    saved_dir = os.path.join("saved_maps")
    os.makedirs(saved_dir, exist_ok=True)
    map_name = str(args.map)
    if map_name.isdigit():
        map_name = map_name[-4:].zfill(4)
    dst_file = args.file if args.file else os.path.join(saved_dir, f"map_{map_name}.json")

    data = load_json(dst_file)
    if data:
        gw = int(data.get("grid_width", gw))
        gh = int(data.get("grid_height", gh))
        tile = int(data.get("tile_size", tile))

    pygame.init()
    screen = pygame.display.set_mode((1280, 720))
    pygame.display.set_caption("Map Editor")
    clock = pygame.time.Clock()
    font = pygame.font.SysFont("consolas", 16)

    blocks_layers = [{}, {}, {}, {}]
    pickups = {}
    col1 = set()
    col2 = set()

    if data:
        layers = data.get("layers", {})
        if any(k in layers for k in ("blocks_l1", "blocks_l2", "blocks_l3", "blocks_l4")):
            for li, key in enumerate(["blocks_l1", "blocks_l2", "blocks_l3", "blocks_l4"]):
                for p in layers.get(key, []):
                    if isinstance(p, list) and len(p) >= 3:
                        blocks_layers[li][(int(p[0]), int(p[1]))] = int(p[2])
        else:
            for p in layers.get("blocks", []):
                if isinstance(p, list) and len(p) >= 3:
                    blocks_layers[0][(int(p[0]), int(p[1]))] = int(p[2])
        for p in layers.get("pickups", []):
            if isinstance(p, list) and len(p) >= 3:
                pickups[(int(p[0]), int(p[1]))] = int(p[2])
        for p in layers.get("collision_layer_1", []):
            if isinstance(p, list) and len(p) == 2:
                col1.add((int(p[0]), int(p[1])))
        for p in layers.get("collision_layer_2", []):
            if isinstance(p, list) and len(p) == 2:
                col2.add((int(p[0]), int(p[1])))

    cam = [0, 0]
    zoom = 1.0
    layer_names = ["L1", "L2", "L3", "L4", "COL1", "COL2", "PICKUPS"]
    layer_index = 0
    block_type = 1
    pickup_type = 1
    block_palettes = [
        [(200, 200, 200), (240, 180, 180), (180, 240, 180), (180, 180, 240), (240, 240, 180)],
        [(210, 210, 255), (190, 230, 255), (160, 200, 255), (140, 180, 240), (120, 160, 220)],
        [(255, 210, 210), (255, 190, 230), (255, 160, 200), (240, 140, 180), (220, 120, 160)],
        [(210, 255, 210), (190, 255, 190), (160, 240, 170), (140, 220, 150), (120, 200, 130)],
    ]
    dd_layer_open = False
    dd_type_open = False

    def world_to_screen(x, y):
        return int((x * tile - cam[0]) * zoom), int((y * tile - cam[1]) * zoom)

    def screen_to_cell(mx, my):
        wx = cam[0] + mx / max(zoom, 1e-6)
        wy = cam[1] + my / max(zoom, 1e-6)
        cx = max(0, min(gw - 1, int(wx // tile)))
        cy = max(0, min(gh - 1, int(wy // tile)))
        return cx, cy

    def draw():
        screen.fill((16, 18, 22))
        pickup_colors = [(255, 200, 0), (0, 200, 255), (255, 0, 200), (0, 255, 120), (255, 120, 0)]
        for li in range(4):
            for (x, y), t in blocks_layers[li].items():
                col_list = block_palettes[li]
                c = col_list[t % len(col_list)]
                px, py = world_to_screen(x, y)
                pygame.draw.rect(screen, c, (px, py, int(tile * zoom), int(tile * zoom)))
        for (x, y) in col1:
            px, py = world_to_screen(x, y)
            pygame.draw.rect(screen, (220, 60, 60), (px, py, int(tile * zoom), int(tile * zoom)))
        for (x, y) in col2:
            px, py = world_to_screen(x, y)
            pygame.draw.rect(screen, (60, 120, 220), (px, py, int(tile * zoom), int(tile * zoom)))
        for (x, y), t in pickups.items():
            c = pickup_colors[t % len(pickup_colors)]
            px, py = world_to_screen(x, y)
            pygame.draw.rect(screen, c, (px + int(tile * zoom * 0.25), py + int(tile * zoom * 0.25), int(tile * zoom * 0.5), int(tile * zoom * 0.5)))
        grid_color = (40, 46, 54)
        step = int(tile * zoom)
        if step >= 8:
            x0 = -int(cam[0] * zoom) % max(step, 1)
            y0 = -int(cam[1] * zoom) % max(step, 1)
            for x in range(x0, screen.get_width(), step):
                pygame.draw.line(screen, grid_color, (x, 0), (x, screen.get_height()), 1)
            for y in range(y0, screen.get_height(), step):
                pygame.draw.line(screen, grid_color, (0, y), (screen.get_width(), y), 1)
        info = f"{os.path.basename(dst_file)} | {layer_names[layer_index]} | block {block_type} | pickup {pickup_type} | cam {cam[0]:.0f},{cam[1]:.0f} zoom {zoom:.2f} | WASD pan, QE zoom, TAB layer, 1-5 type, S save, O load"
        text = font.render(info, True, (240, 240, 240))
        screen.blit(text, (8, 8))
        ui_y = 32
        layer_box = pygame.Rect(8, ui_y, 110, 24)
        type_box = pygame.Rect(128, ui_y, 110, 24)
        pygame.draw.rect(screen, (50, 56, 64), layer_box)
        pygame.draw.rect(screen, (90, 96, 104), layer_box, 1)
        pygame.draw.rect(screen, (50, 56, 64), type_box)
        pygame.draw.rect(screen, (90, 96, 104), type_box, 1)
        layer_label = font.render(f"Layer: {layer_names[layer_index]}", True, (230, 230, 230))
        type_label = font.render(f"Type: {block_type}", True, (230, 230, 230))
        screen.blit(layer_label, (layer_box.x + 6, layer_box.y + 4))
        screen.blit(type_label, (type_box.x + 6, type_box.y + 4))
        if dd_layer_open:
            dd_rect = pygame.Rect(layer_box.x, layer_box.y + layer_box.h, layer_box.w, 24 * 4)
            pygame.draw.rect(screen, (40, 46, 54), dd_rect)
            pygame.draw.rect(screen, (90, 96, 104), dd_rect, 1)
            for i, name in enumerate(layer_names[:4]):
                r = pygame.Rect(layer_box.x, layer_box.y + layer_box.h + i * 24, layer_box.w, 24)
                pygame.draw.rect(screen, (55, 61, 69), r)
                txt = font.render(name, True, (230, 230, 230))
                screen.blit(txt, (r.x + 6, r.y + 4))
        if dd_type_open:
            dd_rect2 = pygame.Rect(type_box.x, type_box.y + type_box.h, type_box.w, 24 * 5)
            pygame.draw.rect(screen, (40, 46, 54), dd_rect2)
            pygame.draw.rect(screen, (90, 96, 104), dd_rect2, 1)
            for i in range(5):
                r2 = pygame.Rect(type_box.x, type_box.y + type_box.h + i * 24, type_box.w, 24)
                pygame.draw.rect(screen, (55, 61, 69), r2)
                ttxt = font.render(f"{i + 1}", True, (230, 230, 230))
                screen.blit(ttxt, (r2.x + 6, r2.y + 4))
        pygame.display.flip()

    running = True
    last_cell = None
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_q:
                    zoom = min(4.0, zoom * 1.1)
                elif event.key == pygame.K_e:
                    zoom = max(0.25, zoom / 1.1)
                elif event.key == pygame.K_TAB:
                    layer_index = (layer_index + 1) % len(layer_names)
                elif event.key == pygame.K_F1:
                    layer_index = 0
                elif event.key == pygame.K_F2:
                    layer_index = 1
                elif event.key == pygame.K_F3:
                    layer_index = 2
                elif event.key == pygame.K_F4:
                    layer_index = 3
                elif event.key in (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5):
                    n = int(event.unicode)
                    if layer_names[layer_index] in ("L1", "L2", "L3", "L4"):
                        block_type = n
                    elif layer_names[layer_index] == "PICKUPS":
                        pickup_type = n
                elif event.key == pygame.K_o:
                    d = load_json(dst_file)
                    if d:
                        nonlocal_tile = int(d.get("tile_size", tile))
                        nonlocal_gw = int(d.get("grid_width", gw))
                        nonlocal_gh = int(d.get("grid_height", gh))
                        for b in blocks_layers:
                            b.clear()
                        pickups.clear(); col1.clear(); col2.clear()
                        layers = d.get("layers", {})
                        if any(k in layers for k in ("blocks_l1", "blocks_l2", "blocks_l3", "blocks_l4")):
                            for li, key in enumerate(["blocks_l1", "blocks_l2", "blocks_l3", "blocks_l4"]):
                                for p in layers.get(key, []):
                                    if isinstance(p, list) and len(p) >= 3:
                                        blocks_layers[li][(int(p[0]), int(p[1]))] = int(p[2])
                        else:
                            for p in layers.get("blocks", []):
                                if isinstance(p, list) and len(p) >= 3:
                                    blocks_layers[0][(int(p[0]), int(p[1]))] = int(p[2])
                        for p in layers.get("pickups", []):
                            if isinstance(p, list) and len(p) >= 3:
                                pickups[(int(p[0]), int(p[1]))] = int(p[2])
                        for p in layers.get("collision_layer_1", []):
                            if isinstance(p, list) and len(p) == 2:
                                col1.add((int(p[0]), int(p[1])))
                        for p in layers.get("collision_layer_2", []):
                            if isinstance(p, list) and len(p) == 2:
                                col2.add((int(p[0]), int(p[1])))
                        gw = nonlocal_gw
                        gh = nonlocal_gh
                        tile = nonlocal_tile
                elif event.key == pygame.K_s:
                    out = {
                        "version": 2,
                        "tile_size": tile,
                        "grid_width": gw,
                        "grid_height": gh,
                        "layers": {
                            "blocks_l1": sorted([[x, y, t] for ((x, y), t) in blocks_layers[0].items()]),
                            "blocks_l2": sorted([[x, y, t] for ((x, y), t) in blocks_layers[1].items()]),
                            "blocks_l3": sorted([[x, y, t] for ((x, y), t) in blocks_layers[2].items()]),
                            "blocks_l4": sorted([[x, y, t] for ((x, y), t) in blocks_layers[3].items()]),
                            "pickups": sorted([[x, y, t] for ((x, y), t) in pickups.items()]),
                            "collision_layer_1": sorted([[x, y] for (x, y) in col1]),
                            "collision_layer_2": sorted([[x, y] for (x, y) in col2])
                        }
                    }
                    save_json(dst_file, out)
            elif event.type == pygame.MOUSEBUTTONDOWN:
                mx, my = pygame.mouse.get_pos()
                layer_box = pygame.Rect(8, 32, 110, 24)
                type_box = pygame.Rect(128, 32, 110, 24)
                if layer_box.collidepoint(mx, my):
                    dd_layer_open = not dd_layer_open
                    dd_type_open = False
                    continue
                if type_box.collidepoint(mx, my):
                    dd_type_open = not dd_type_open
                    dd_layer_open = False
                    continue
                if dd_layer_open:
                    for i, name in enumerate(layer_names[:4]):
                        r = pygame.Rect(layer_box.x, layer_box.y + layer_box.h + i * 24, layer_box.w, 24)
                        if r.collidepoint(mx, my):
                            layer_index = i
                            dd_layer_open = False
                            break
                if dd_type_open:
                    for i in range(5):
                        r2 = pygame.Rect(type_box.x, type_box.y + type_box.h + i * 24, type_box.w, 24)
                        if r2.collidepoint(mx, my):
                            block_type = i + 1
                            dd_type_open = False
                            break
                cx, cy = screen_to_cell(mx, my)
                lname = layer_names[layer_index]
                if event.button == 1:
                    if lname in ("L1", "L2", "L3", "L4"):
                        li = 0 if lname == "L1" else 1 if lname == "L2" else 2 if lname == "L3" else 3
                        blocks_layers[li][(cx, cy)] = block_type
                    elif lname == "COL1":
                        col1.add((cx, cy))
                    elif lname == "COL2":
                        col2.add((cx, cy))
                    elif lname == "PICKUPS":
                        pickups[(cx, cy)] = pickup_type
                    last_cell = (cx, cy)
                elif event.button == 3:
                    if lname in ("L1", "L2", "L3", "L4"):
                        li = 0 if lname == "L1" else 1 if lname == "L2" else 2 if lname == "L3" else 3
                        blocks_layers[li].pop((cx, cy), None)
                    elif lname == "COL1":
                        if (cx, cy) in col1:
                            col1.remove((cx, cy))
                    elif lname == "COL2":
                        if (cx, cy) in col2:
                            col2.remove((cx, cy))
                    elif lname == "PICKUPS":
                        pickups.pop((cx, cy), None)
                    last_cell = (cx, cy)
            elif event.type == pygame.MOUSEMOTION:
                buttons = pygame.mouse.get_pressed(3)
                if buttons[0] or buttons[2]:
                    cx, cy = screen_to_cell(*pygame.mouse.get_pos())
                    if last_cell != (cx, cy):
                        lname = layer_names[layer_index]
                        if buttons[0]:
                            if lname in ("L1", "L2", "L3", "L4"):
                                li = 0 if lname == "L1" else 1 if lname == "L2" else 2 if lname == "L3" else 3
                                blocks_layers[li][(cx, cy)] = block_type
                            elif lname == "COL1":
                                col1.add((cx, cy))
                            elif lname == "COL2":
                                col2.add((cx, cy))
                            elif lname == "PICKUPS":
                                pickups[(cx, cy)] = pickup_type
                        elif buttons[2]:
                            if lname in ("L1", "L2", "L3", "L4"):
                                li = 0 if lname == "L1" else 1 if lname == "L2" else 2 if lname == "L3" else 3
                                blocks_layers[li].pop((cx, cy), None)
                            elif lname == "COL1":
                                if (cx, cy) in col1:
                                    col1.remove((cx, cy))
                            elif lname == "COL2":
                                if (cx, cy) in col2:
                                    col2.remove((cx, cy))
                            elif lname == "PICKUPS":
                                pickups.pop((cx, cy), None)
                        last_cell = (cx, cy)
                else:
                    last_cell = None

        keys = pygame.key.get_pressed()
        pan = 500 * clock.get_time() / 1000.0 / max(zoom, 1e-6)
        if keys[pygame.K_a]:
            cam[0] -= pan
        if keys[pygame.K_d]:
            cam[0] += pan
        if keys[pygame.K_w]:
            cam[1] -= pan
        if keys[pygame.K_s]:
            cam[1] += pan

        draw()
        clock.tick(120)
    pygame.quit()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(str(e))
        sys.exit(1)


