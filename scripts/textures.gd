class_name Tex
extends RefCounted
## Procedural textures. Every world surface has TWO looks:
##   the Veil  (exploration) - 32px tiles, 4-tone dithered, cold and faded, nearest filtered
##   the Flesh (combat)      - 256px tiles with normal maps, warm and sharp
## Materials are shared per surface kind, so swapping the look is a handful of property sets.
## Generated once per launch and cached in GameState (survives scene reloads).

const HD := 256
const PX := 32
const KINDS := ["flagstone", "brick", "cobble", "earth", "wood", "iron", "marble", "moss"]
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

const RAMPS := {
    "flagstone": [Color(0.09, 0.085, 0.08), Color(0.2, 0.19, 0.17), Color(0.31, 0.29, 0.26), Color(0.42, 0.4, 0.36)],
    "brick": [Color(0.07, 0.065, 0.06), Color(0.18, 0.16, 0.15), Color(0.29, 0.26, 0.23), Color(0.4, 0.36, 0.32)],
    "cobble": [Color(0.06, 0.06, 0.06), Color(0.17, 0.17, 0.16), Color(0.28, 0.27, 0.25), Color(0.38, 0.37, 0.34)],
    "earth": [Color(0.06, 0.05, 0.04), Color(0.13, 0.11, 0.08), Color(0.2, 0.18, 0.12), Color(0.26, 0.25, 0.16)],
    "wood": [Color(0.07, 0.04, 0.025), Color(0.16, 0.1, 0.06), Color(0.25, 0.16, 0.09), Color(0.33, 0.22, 0.13)],
    "iron": [Color(0.05, 0.05, 0.055), Color(0.13, 0.13, 0.14), Color(0.22, 0.22, 0.23), Color(0.33, 0.33, 0.34)],
    "marble": [Color(0.22, 0.22, 0.24), Color(0.42, 0.42, 0.44), Color(0.58, 0.57, 0.58), Color(0.7, 0.69, 0.68)],
    "moss": [Color(0.07, 0.07, 0.06), Color(0.17, 0.17, 0.15), Color(0.27, 0.27, 0.24), Color(0.37, 0.36, 0.32)],
}
const ROUGH := {"flagstone": 0.92, "brick": 0.95, "cobble": 0.85, "earth": 1.0, "wood": 0.8,
    "iron": 0.45, "marble": 0.35, "moss": 0.97}
const NORMAL := {"flagstone": 1.4, "brick": 1.6, "cobble": 1.8, "earth": 1.0, "wood": 0.9,
    "iron": 0.7, "marble": 0.4, "moss": 1.4}

## Returns {kind: StandardMaterial3D}. Call set_world() to switch the look.
static func world_materials() -> Dictionary:
    var gs: Node = Engine.get_main_loop().root.get_node("GameState")
    if gs.cache.has("world_mats"):
        return gs.cache["world_mats"]
    var mats := {}
    for kind: String in KINDS:
        var data := _generate(kind)
        var m := StandardMaterial3D.new()
        m.uv1_triplanar = true
        m.uv1_world_triplanar = true
        m.uv1_scale = Vector3(0.5, 0.5, 0.5)
        m.roughness = ROUGH[kind]
        m.metallic = 0.55 if kind == "iron" else 0.0
        m.normal_enabled = true
        m.normal_texture = data["normal"]
        m.set_meta("hd", data["hd"])
        m.set_meta("px", data["px"])
        m.set_meta("normal_scale", NORMAL[kind])
        mats[kind] = m
    gs.cache["world_mats"] = mats
    set_world(false)
    return mats

static func set_world(combat: bool) -> void:
    var gs: Node = Engine.get_main_loop().root.get_node("GameState")
    if not gs.cache.has("world_mats"):
        return
    for kind: String in gs.cache["world_mats"]:
        var m: StandardMaterial3D = gs.cache["world_mats"][kind]
        if combat:
            m.albedo_texture = m.get_meta("hd")
            m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
            m.normal_scale = m.get_meta("normal_scale")
        else:
            m.albedo_texture = m.get_meta("px")
            m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
            m.normal_scale = 0.15

# ---------------------------------------------------------------- helpers

static func _hash(a: int, b: int) -> float:
    return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)

static func _noise(seed: int, freq: float, octaves: int, ntype := FastNoiseLite.TYPE_SIMPLEX_SMOOTH,
        cell_ret := -1, size := HD) -> PackedByteArray:
    var fn := FastNoiseLite.new()
    fn.seed = seed
    fn.frequency = freq
    fn.noise_type = ntype
    fn.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
    fn.fractal_octaves = maxi(octaves, 1)
    if cell_ret >= 0:
        fn.cellular_return_type = cell_ret as FastNoiseLite.CellularReturnType
        fn.cellular_jitter = 0.9
    var img := fn.get_seamless_image(size, size, false, false, 0.12, true)
    img.convert(Image.FORMAT_L8)
    return img.get_data()

static func _ramp(r: Array, t: float) -> Color:
    t = clampf(t, 0.0, 1.0) * (r.size() - 1)
    var i := mini(int(t), r.size() - 2)
    var a: Color = r[i]
    var b: Color = r[i + 1]
    return a.lerp(b, t - i)

## Brick / slab layout. Returns Vector3(edge_distance, cell_id_a, cell_id_b) in tile units.
static func _bond(u: float, v: float, rows: int, cols: int, jitter: bool) -> Vector3:
    var r := int(floorf(v * rows))
    var off := 0.5 if r % 2 == 1 else 0.0
    if jitter:
        off = _hash(r, 7) * 0.8
    var cu := u * cols + off
    var c := int(floorf(cu)) % cols
    var fu := cu - floorf(cu)
    var fv := v * rows - r
    var d := minf(minf(fu, 1.0 - fu) / cols, minf(fv, 1.0 - fv) / rows)
    return Vector3(d, r, c)

# ---------------------------------------------------------------- generation

static func _generate(kind: String) -> Dictionary:
    var n := HD
    var alb := PackedByteArray()
    alb.resize(n * n * 3)
    var hgt := PackedByteArray()
    hgt.resize(n * n)
    var ramp: Array = RAMPS[kind]
    var fine := _noise(11, 0.09, 3)
    var big := _noise(23, 0.012, 4)
    var cell_f1 := PackedByteArray()
    var cell_edge := PackedByteArray()
    var cell_val := PackedByteArray()
    var grain := PackedByteArray()
    match kind:
        "cobble":
            cell_f1 = _noise(5, 0.04, 1, FastNoiseLite.TYPE_CELLULAR, FastNoiseLite.RETURN_DISTANCE)
            cell_edge = _noise(5, 0.04, 1, FastNoiseLite.TYPE_CELLULAR, FastNoiseLite.RETURN_DISTANCE2_SUB)
            cell_val = _noise(5, 0.04, 1, FastNoiseLite.TYPE_CELLULAR, FastNoiseLite.RETURN_CELL_VALUE)
        "flagstone", "moss":
            cell_edge = _noise(9, 0.025, 1, FastNoiseLite.TYPE_CELLULAR, FastNoiseLite.RETURN_DISTANCE2_SUB)
        "earth":
            cell_edge = _noise(31, 0.11, 1, FastNoiseLite.TYPE_CELLULAR, FastNoiseLite.RETURN_DISTANCE2_SUB)
        "wood":
            var gimg := FastNoiseLite.new()
            gimg.seed = 3
            gimg.frequency = 0.08
            gimg.fractal_octaves = 3
            var gi := gimg.get_seamless_image(n, 16, false, false, 0.12, true)
            gi.resize(n, n, Image.INTERPOLATE_BILINEAR)
            gi.convert(Image.FORMAT_L8)
            grain = gi.get_data()
    for y in n:
        var v := float(y) / n
        for x in n:
            var u := float(x) / n
            var i := y * n + x
            var nf := fine[i] / 255.0
            var nb := big[i] / 255.0
            var tone := 0.5
            var h := 0.5
            var col := Color()
            var use_col := false
            match kind:
                "brick":
                    var b := _bond(u, v, 8, 4, false)
                    var mortar := 0.022
                    var bev := smoothstep(mortar, mortar + 0.02, b.x)
                    var hv := _hash(int(b.y), int(b.z))
                    tone = lerpf(0.12, 0.45 + 0.4 * hv + 0.25 * (nf - 0.5), bev) - 0.15 * nb
                    h = 0.15 + 0.7 * bev + 0.15 * nf
                "flagstone":
                    var b := _bond(u, v, 4, 3, true)
                    var gap := 0.012
                    var bev := smoothstep(gap, gap + 0.025, b.x)
                    var hv := _hash(int(b.y), int(b.z))
                    var crack := 1.0 - smoothstep(0.0, 0.04, cell_edge[i] / 255.0)
                    crack *= 1.0 if hv >= 0.55 else 0.0
                    tone = lerpf(0.05, 0.35 + 0.4 * hv + 0.3 * (nf - 0.5), bev) - 0.4 * crack - 0.15 * nb
                    h = 0.1 + 0.8 * bev - 0.5 * crack + 0.1 * nf
                "cobble":
                    var edge := cell_edge[i] / 255.0
                    var f1 := cell_f1[i] / 255.0
                    var seam := smoothstep(0.02, 0.14, edge)
                    tone = lerpf(0.05, 0.3 + 0.5 * cell_val[i] / 255.0 + 0.2 * (nf - 0.5), seam) - 0.1 * nb
                    h = seam * (1.0 - 0.6 * f1) + 0.08 * nf
                "earth":
                    var pebble := smoothstep(0.25, 0.1, cell_edge[i] / 255.0)
                    tone = 0.2 + 0.55 * nb + 0.25 * (nf - 0.5)
                    h = 0.3 * nb + 0.4 * nf + 0.3 * pebble
                    var grass := smoothstep(0.62, 0.8, nb) * smoothstep(0.5, 0.75, nf)
                    col = _ramp(ramp, tone).lerp(Color(0.22, 0.22, 0.12), grass * 0.8)
                    use_col = true
                "wood":
                    var plank := u * 4.0
                    var pf := plank - floorf(plank)
                    var seam := smoothstep(0.0, 0.04, minf(pf, 1.0 - pf))
                    var pid := int(floorf(plank))
                    var g := grain[i] / 255.0
                    var nail := 1.0 - smoothstep(0.004, 0.012, Vector2(pf - 0.5, fposmod(v + _hash(pid, 3), 0.5) - 0.25).length() / 4.0)
                    tone = lerpf(0.05, 0.4 + 0.35 * _hash(pid, 1) + 0.35 * (g - 0.5), seam) - 0.25 * nail
                    h = 0.2 + 0.6 * seam + 0.2 * g
                "iron":
                    var rust := smoothstep(0.55, 0.75, nb + 0.3 * (nf - 0.5))
                    tone = 0.35 + 0.35 * (nf - 0.5) + 0.2 * nb
                    h = 0.5 + 0.3 * nf + 0.2 * rust
                    col = _ramp(ramp, tone).lerp(Color(0.32, 0.15, 0.07), rust * 0.85)
                    use_col = true
                "marble":
                    var b := _bond(u, v, 2, 2, false)
                    var seam := smoothstep(0.004, 0.012, b.x)
                    var vein := absf(sin((3.0 * u + 2.0 * v) * TAU + nb * 7.0))
                    var vline := 1.0 - smoothstep(0.0, 0.08, vein)
                    tone = (0.62 + 0.25 * (nf - 0.5) - 0.45 * vline) * lerpf(0.2, 1.0, seam)
                    h = 0.3 + 0.6 * seam - 0.2 * vline
                "moss":
                    var b := _bond(u, v, 3, 2, true)
                    var gap := 0.015
                    var bev := smoothstep(gap, gap + 0.035, b.x)
                    var hv := _hash(int(b.y), int(b.z))
                    var crack := (1.0 - smoothstep(0.0, 0.05, cell_edge[i] / 255.0)) * (1.0 if hv >= 0.4 else 0.0)
                    tone = lerpf(0.05, 0.35 + 0.35 * hv + 0.3 * (nf - 0.5), bev) - 0.35 * crack
                    h = 0.1 + 0.75 * bev + 0.15 * nf - 0.4 * crack
                    var moss := smoothstep(0.5, 0.7, nb + 0.25 * (nf - 0.5) + 0.15 * (1.0 - bev))
                    col = _ramp(ramp, tone).lerp(Color(0.13, 0.17, 0.08) * (0.7 + 0.6 * nf), moss)
                    use_col = true
            if not use_col:
                col = _ramp(ramp, tone)
            alb[i * 3] = clampi(int(col.r * 255.0), 0, 255)
            alb[i * 3 + 1] = clampi(int(col.g * 255.0), 0, 255)
            alb[i * 3 + 2] = clampi(int(col.b * 255.0), 0, 255)
            hgt[i] = clampi(int(h * 255.0), 0, 255)

    var hd_img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, alb)
    var px_img := hd_img.duplicate() as Image
    hd_img.generate_mipmaps()
    var nimg := Image.create_from_data(n, n, false, Image.FORMAT_L8, hgt)
    nimg.convert(Image.FORMAT_RGBA8)
    nimg.bump_map_to_normal_map(6.0)
    nimg.generate_mipmaps()
    px_img.resize(PX, PX, Image.INTERPOLATE_LANCZOS)
    _pixelize(px_img)
    return {
        "hd": ImageTexture.create_from_image(hd_img),
        "px": ImageTexture.create_from_image(px_img),
        "normal": ImageTexture.create_from_image(nimg),
    }

## 4-tone ordered dither, hue preserved, graded toward the cold faded Veil palette.
static func _pixelize(img: Image) -> void:
    var w := img.get_width()
    var hh := img.get_height()
    var lo := 10.0
    var hi := 0.0
    for y in hh:
        for x in w:
            var l := img.get_pixel(x, y).get_luminance()
            lo = minf(lo, l)
            hi = maxf(hi, l)
    var span := maxf(hi - lo, 0.01)
    for y in hh:
        for x in w:
            var c := img.get_pixel(x, y)
            var l := maxf(c.get_luminance(), 0.001)
            var t := (l - lo) / span
            var th: float = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0 - 0.5
            var q := clampf(floorf(t * 3.0 + 0.5 + th * 0.9), 0.0, 3.0) / 3.0
            var nl := lo + q * span
            var out := c * (nl / l)
            var grey := out.get_luminance()
            out = out.lerp(Color(grey * 0.82, grey * 0.9, grey * 1.18), 0.45)
            out.a = 1.0
            img.set_pixel(x, y, out)

# ---------------------------------------------------------------- small detail maps (characters, props)

## Neutral grey detail texture for actors; multiply with albedo_color.
static func detail(kind: String) -> ImageTexture:
    var gs: Node = Engine.get_main_loop().root.get_node("GameState")
    var key := "detail_" + kind
    if gs.cache.has(key):
        return gs.cache[key]
    var n := 128
    var img := Image.create(n, n, false, Image.FORMAT_RGB8)
    var fine := _noise(41, 0.12, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, -1, n)
    var big := _noise(43, 0.03, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, -1, n)
    for y in n:
        for x in n:
            var i := y * n + x
            var f := fine[i] / 255.0
            var b := big[i] / 255.0
            var g := 0.8
            match kind:
                "leather":
                    g = 0.72 + 0.22 * f + 0.12 * b - 0.18 * float((x * 7 + y * 3) % 23 == 0)
                "cloth":
                    var weave := 0.5 + 0.5 * sin(x * 1.6) * sin(y * 1.6)
                    g = 0.68 + 0.16 * weave + 0.18 * f + 0.1 * (b - 0.5)
                "metal":
                    var scratch := float(absf(sin(x * 0.31 + y * 0.07 + b * 9.0)) < 0.03)
                    g = 0.75 + 0.12 * f + 0.1 * b + 0.25 * scratch
                "skin":
                    g = 0.85 + 0.1 * f + 0.06 * b
            img.set_pixel(x, y, Color(g, g, g))
    img.generate_mipmaps()
    var tex := ImageTexture.create_from_image(img)
    gs.cache[key] = tex
    return tex

## Glowing scribbled glyphs for the ground messages.
static func rune_texture() -> ImageTexture:
    var gs: Node = Engine.get_main_loop().root.get_node("GameState")
    if gs.cache.has("rune"):
        return gs.cache["rune"]
    var w := 96
    var h := 32
    var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var rng := RandomNumberGenerator.new()
    rng.seed = 77
    var x := 6.0
    while x < w - 10:
        var gw := rng.randi_range(5, 9)
        var pts := []
        for k in rng.randi_range(3, 5):
            pts.append(Vector2(x + rng.randf() * gw, 8 + rng.randf() * 16))
        for k in pts.size() - 1:
            var a: Vector2 = pts[k]
            var b: Vector2 = pts[k + 1]
            var steps := int(a.distance_to(b) * 2.0) + 1
            for s in steps + 1:
                var p := a.lerp(b, float(s) / steps)
                for ox in range(-1, 2):
                    for oy in range(-1, 2):
                        var px := int(p.x) + ox
                        var py := int(p.y) + oy
                        if px >= 0 and px < w and py >= 0 and py < h:
                            var core := ox == 0 and oy == 0
                            var c := img.get_pixel(px, py)
                            var na := maxf(c.a, 1.0 if core else 0.35)
                            img.set_pixel(px, py, Color(1.0, 0.62, 0.25, na))
        x += gw + rng.randi_range(3, 6)
    var tex := ImageTexture.create_from_image(img)
    gs.cache["rune"] = tex
    return tex
