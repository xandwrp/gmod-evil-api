import importlib.util
import math
import os
import sys

import bpy
from mathutils import Vector

PROJECTS = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FUNGUS = os.path.join(PROJECTS, "gmod-evil-fungus-addon", "tools", "render_thumbnail.py")
CRAWLER = os.path.join(PROJECTS, "gmod-evil-crawling-thing-addon", "tools", "render_assets.py")

CRAWLER_SEED = 777
CRAWLER_T = 11.0
CRAWLER_AT = (85, -55, 0)
CAMERA = dict(at=(-200, 125, 90), look=(40, -20, 42), lens=37, fstop=5.6)
TORCH = dict(energy=2200, cone=60, blend=0.75, at=(-20, 10, 30))
SIZE = (1024, 1024)
EXPOSURE = -0.3


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = dict(zip(argv[::2], argv[1::2]))
    out = os.path.abspath(args.get("--out", "renders"))
    samples = int(args.get("--samples", 256))
    pct = int(args.get("--pct", 100))

    F = load("fungus_thumb", FUNGUS)
    C = load("crawler_assets", CRAWLER)
    S = F.SCALE

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    F.stage(os.path.abspath(args["--map"]))
    center = F.floor_at(*F.SPOT)

    fiber = F.material("Fiber", 0.5, 0.25, 0.1, (0.5, 0.35, 0.2), 0.25)
    flesh = F.material("Flesh", 0.38, 0.45, 0.12, (0.6, 0.2, 0.15), 0.35)
    fill = F.material("Fill", 0.32, 0.55, 0.2, (0.6, 0.2, 0.15), 0.5, blotch=True)
    F.mat_mesh(F.grow_mat(center), fiber)
    body, bvh, frame = F.sleeper(center, F.YAW, fill, flesh)
    F.body_strands(center, frame, bvh, flesh)

    cam_pos = center + Vector(CAMERA["at"])
    origin = F.floor_at(*(center + Vector(CRAWLER_AT) + Vector((0, 0, 40))))
    up = Vector((0, 0, 1))
    fwd = center - origin
    fwd.z = 0
    fwd.normalize()
    creature = C.grow(CRAWLER_SEED)
    skin = C.material_flesh()
    for i, (leg, chain) in enumerate(C.pose(creature, up, fwd, CRAWLER_T, cam_pos, origin)):
        v, f, c = C.tube(chain, leg)
        C.add_mesh("Leg%d" % i, v, f, c, material=skin)

    data = bpy.data.lights.new("Torch", "SPOT")
    data.energy, data.spot_size, data.spot_blend = TORCH["energy"], math.radians(TORCH["cone"]), TORCH["blend"]
    data.shadow_soft_size, data.color = 0.03, (1.0, 0.93, 0.8)
    ob = bpy.data.objects.new("Torch", data)
    scene.collection.objects.link(ob)
    ob.location = (cam_pos + Vector(TORCH["at"])) * S
    target = center + Vector(CAMERA["look"])
    ob.rotation_euler = (target * S - ob.location).to_track_quat("-Z", "Y").to_euler()

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.lens = CAMERA["lens"]
    cam = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam)
    cam.location = cam_pos * S
    cam.rotation_euler = (target * S - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.dof.use_dof = True
    cam_data.dof.focus_distance = (target * S - cam.location).length
    cam_data.dof.aperture_fstop = CAMERA["fstop"]
    scene.camera = cam

    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    try:
        scene.cycles.device = "GPU"
    except TypeError:
        pass
    scene.render.resolution_x, scene.render.resolution_y = SIZE
    scene.render.resolution_percentage = pct
    scene.render.image_settings.file_format = "PNG"
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    scene.view_settings.exposure = EXPOSURE
    scene.render.filepath = os.path.join(out, args.get("--name", "thumbnail") + ".png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
