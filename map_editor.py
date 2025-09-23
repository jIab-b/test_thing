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

    blocks = {}
    pickups = {}
    col1 = set()
    col2 = set()

    if data:
        layers = data.get("layers", {})
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

    cam = [0, 0]
    zoom = 1.0
    layer_names = ["BLOCKS", "COL1", "COL2", "PICKUPS"]
    layer_index = 0
    block_type = 1
    pickup_type = 1

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
        colors = {
            "BLOCKS": [(200, 200, 200), (240, 180, 180), (180, 240, 180), (180, 180, 240), (240, 240, 180)],
            "PICKUPS": [(255, 200, 0), (0, 200, 255), (255, 0, 200), (0, 255, 120), (255, 120, 0)]
        }
        for (x, y), t in blocks.items():
            c = colors["BLOCKS"][t % len(colors["BLOCKS"])]
            px, py = world_to_screen(x, y)
            pygame.draw.rect(screen, c, (px, py, int(tile * zoom), int(tile * zoom)))
        for (x, y) in col1:
            px, py = world_to_screen(x, y)
            pygame.draw.rect(screen, (220, 60, 60), (px, py, int(tile * zoom), int(tile * zoom)))
        for (x, y) in col2:
            px, py = world_to_screen(x, y)
            pygame.draw.rect(screen, (60, 120, 220), (px, py, int(tile * zoom), int(tile * zoom)))
        for (x, y), t in pickups.items():
            c = colors["PICKUPS"][t % len(colors["PICKUPS"])]
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
        info = f"{os.path.basename(dst_file)} | {layer_names[layer_index]} | block {block_type} | pickup {pickup_type} | cam {cam[0]:.0f},{cam[1]:.0f} zoom {zoom:.2f} | WASD pan, QE zoom, B/P layer, F1/F2/F3/F4 layers, 1-5 type, S save, O load"
        text = font.render(info, True, (240, 240, 240))
        screen.blit(text, (8, 8))
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
                elif event.key == pygame.K_b:
                    layer_index = 0
                elif event.key == pygame.K_p:
                    layer_index = 3
                elif event.key in (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5):
                    n = int(event.unicode)
                    if layer_names[layer_index] == "BLOCKS":
                        block_type = n
                    elif layer_names[layer_index] == "PICKUPS":
                        pickup_type = n
                elif event.key == pygame.K_o:
                    d = load_json(dst_file)
                    if d:
                        nonlocal_tile = int(d.get("tile_size", tile))
                        nonlocal_gw = int(d.get("grid_width", gw))
                        nonlocal_gh = int(d.get("grid_height", gh))
                        blocks.clear(); pickups.clear(); col1.clear(); col2.clear()
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
                            "blocks": sorted([[x, y, t] for ((x, y), t) in blocks.items()]),
                            "pickups": sorted([[x, y, t] for ((x, y), t) in pickups.items()]),
                            "collision_layer_1": sorted([[x, y] for (x, y) in col1]),
                            "collision_layer_2": sorted([[x, y] for (x, y) in col2])
                        }
                    }
                    save_json(dst_file, out)
            elif event.type == pygame.MOUSEBUTTONDOWN:
                cx, cy = screen_to_cell(*pygame.mouse.get_pos())
                lname = layer_names[layer_index]
                if event.button == 1:
                    if lname == "BLOCKS":
                        blocks[(cx, cy)] = block_type
                    elif lname == "COL1":
                        col1.add((cx, cy))
                    elif lname == "COL2":
                        col2.add((cx, cy))
                    elif lname == "PICKUPS":
                        pickups[(cx, cy)] = pickup_type
                    last_cell = (cx, cy)
                elif event.button == 3:
                    if lname == "BLOCKS":
                        blocks.pop((cx, cy), None)
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
                            if lname == "BLOCKS":
                                blocks[(cx, cy)] = block_type
                            elif lname == "COL1":
                                col1.add((cx, cy))
                            elif lname == "COL2":
                                col2.add((cx, cy))
                            elif lname == "PICKUPS":
                                pickups[(cx, cy)] = pickup_type
                        elif buttons[2]:
                            if lname == "BLOCKS":
                                blocks.pop((cx, cy), None)
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


