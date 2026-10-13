class_name Level
extends Node3D
## Builds the whole v1.1 level in code. One 3D world; both camera looks render it.
##
##   z  72 .. 58   The Waking Chapel        (start, intro cutscene, the Veilkeeper)
##   z  58 .. 44   Corridor of Whispers     (tutorial messages)
##   z  44 .. 22   Hall of Arms             (choose a weapon -> the dead rise; gate seals the hall)
##   z  22 .. 12   Vestibule                (first lantern)
##   z  12 ..-30   Ashen Graveyard          (outdoor, husks + a brute)
##   z -30 ..-46   Steps of the Pale Cathedral (stairs up to y=2, second lantern, white fog)
##   z -46 ..-80   Sanctum of the Sundered Gate (boss arena), portal behind it
##
## The player walks "north" (-Z), away from the fixed exploration camera.
## Walls running east-west are cut down to stubs in exploration so they never hide the player.

const FOG_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.85, 0.88, 0.95, 0.75);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * n(p); p *= 2.03; a *= 0.5; } return v; }
void fragment() {
    vec2 uv = UV;
    float f = fbm(uv * vec2(5.0, 3.0) + vec2(TIME * 0.07, -TIME * 0.22));
    f = f * 0.7 + 0.5 * fbm(uv * vec2(9.0, 6.0) - vec2(TIME * 0.11, TIME * 0.05));
    float edge = smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x) * smoothstep(0.0, 0.08, 1.0 - uv.y) * smoothstep(1.0, 0.75, 1.0 - uv.y);
    ALBEDO = tint.rgb * (0.7 + 0.5 * f);
    ALPHA = clamp(f * 1.3 - 0.15, 0.0, 1.0) * edge * tint.a;
}
"""

const PORTAL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 inner : source_color = vec4(0.9, 0.15, 0.1, 1.0);
uniform vec4 outer : source_color = vec4(0.75, 0.85, 1.0, 1.0);
uniform float power = 1.0;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float r = length(p);
    float a = atan(p.y, p.x);
    float swirl = sin(a * 5.0 + r * 14.0 - TIME * 3.0) * 0.5 + 0.5;
    float swirl2 = sin(a * 3.0 - r * 9.0 + TIME * 2.0) * 0.5 + 0.5;
    vec3 c = mix(inner.rgb, outer.rgb, smoothstep(0.1, 0.95, r) * swirl);
    ALBEDO = c * (1.0 + swirl2 * 1.5) * power;
    ALPHA = smoothstep(1.0, 0.85, r) * (0.55 + 0.45 * swirl) * clamp(power, 0.0, 1.0);
}
"""

var mats := {}
var _cut: Array = []
var _flicker: Array = []
var _time := 0.0
var interactables: Array = []
var gates := {}
var fog_body: StaticBody3D
var fog_mesh: MeshInstance3D
var fog_mat: ShaderMaterial
var portal_mat: ShaderMaterial
var portal_light: OmniLight3D
var env: Environment
var moon: DirectionalLight3D

const CHECKPOINTS := {
    "chapel": {"pos": Vector3(0, 0.1, 63.0), "name": "The Waking Chapel"},
    "vestibule": {"pos": Vector3(-1.2, 0.1, 15.0), "lantern": Vector3(-2.6, 0, 16.0), "name": "Vestibule Lantern"},
    "cathedral": {"pos": Vector3(3.0, 2.1, -40.0), "lantern": Vector3(4.6, 2.0, -39.5), "name": "Cathedral Steps Lantern"},
}

const ZONES := [
    ["chapel", "The Waking Chapel", -7.0, 7.0, 58.0, 72.0],
    ["corridor", "Corridor of Whispers", -2.5, 2.5, 44.0, 58.0],
    ["hall", "Hall of Arms", -12.0, 12.0, 22.0, 44.0],
    ["vestibule", "Vestibule of the First Lantern", -5.0, 5.0, 12.0, 22.0],
    ["graveyard", "Ashen Graveyard", -22.0, 22.0, -30.0, 12.0],
    ["steps", "Steps of the Pale Cathedral", -8.0, 8.0, -46.0, -30.0],
    ["arena", "Sanctum of the Sundered Gate", -18.0, 18.0, -90.0, -46.0],
]

const ENEMIES := [
    # [type, position, dormant, tag]
    ["husk", Vector3(-6.0, 0.1, 34.5), true, "hall"],
    ["husk", Vector3(5.5, 0.1, 36.0), true, "hall"],
    ["husk", Vector3(0.5, 0.1, 31.5), true, "hall"],
    ["husk", Vector3(-7.0, 0.1, 3.0), false, "yard"],
    ["husk", Vector3(8.0, 0.1, -3.0), false, "yard"],
    ["husk", Vector3(-12.5, 0.1, -9.0), false, "yard"],
    ["husk", Vector3(-14.0, 0.1, -12.0), false, "yard"],
    ["husk", Vector3(12.0, 0.1, -15.0), false, "yard"],
    ["brute", Vector3(0.0, 0.1, -24.0), false, "yard"],
]

const MESSAGES := [
    [Vector3(0, 0, 60.6), "Welcome, Pale One.\n\nMove with  W A S D  (left stick).\nStand over messages like this one and press  E  (A) to read them."],
    [Vector3(0.6, 0, 54.5), "Press  SPACE  (B) to roll.\n\nA roll grants a brief moment where nothing can touch you.\nRoll THROUGH an attack, not away from it."],
    [Vector3(-0.8, 0, 50.0), "The green bar is your stamina.\n\nRolling and attacking spend it, standing still restores it.\nNever empty it in front of a foe."],
    [Vector3(0.4, 0, 45.6), "Beyond lies the Hall of Arms.\n\nTake up a weapon at one of the altars...\nbut be warned: steel wakes the dead."],
    [Vector3(-2.2, 0, 41.0), "Light attack:  J / Left Mouse  (X)\nHeavy attack:  K / Right Mouse  (Y)\n\nPress attack again as a swing ends to chain a combo."],
    [Vector3(-9.5, 0, 26.0), "Lock on:  Q  (R3)\n\nLocked on, you circle your foe. When its weapon flares red,\nthat is your cue to roll."],
    [Vector3(9.5, 0, 26.0), "Try heavy attack\n\nHeavy blows break a foe's poise.\nA staggered foe is an open foe."],
    [Vector3(2.2, 0, 18.5), "Rest at lanterns with  E .\n\nResting restores your health and Blood Vials,\nand marks where you will wake... but the dead rise again."],
    [Vector3(-1.4, 0, 13.6), "Drink a Blood Vial with  F  (LB).\n\nYou are slow while drinking. Find distance first."],
    [Vector3(1.4, 0, 9.0), "When a foe sees you, the Veil tears\nand the Flesh-World bleeds through.\n\nThat is when the fighting starts."],
    [Vector3(-11.0, 0, -4.0), "Be wary of left"],
    [Vector3(4.0, 0, -27.0), "Big one ahead\n\nIts swings are slow. Roll late, strike after."],
    [Vector3(-3.0, 2.0, -38.5), "Beyond the white fog waits the Pale Warden.\n\nRest first. Then go, and do not hesitate.\nWhen the Warden kneels and its chest burns red... run."],
]

# ------------------------------------------------------------------ public

func build() -> void:
    mats = Tex.world_materials()
    _environment()
    _chapel()
    _corridor()
    _hall()
    _vestibule()
    _graveyard()
    _steps()
    _arena()
    for m: Array in MESSAGES:
        _message(m[0], m[1])
    var gs: Node = get_node("/root/GameState")
    gs.visual_mode_changed.connect(set_world)
    set_world(gs.visual_combat)

func set_world(combat: bool) -> void:
    Tex.set_world(combat)
    for c: Array in _cut:
        var mi: MeshInstance3D = c[0]
        var hgt: float = c[1]
        var k := 1.0 if combat else 0.16
        mi.scale.y = k
        mi.position.y = -hgt * 0.5 * (1.0 - k)
    if env:
        if combat:
            env.fog_light_color = Color(0.12, 0.07, 0.07)
            env.fog_density = 0.022
            env.ambient_light_color = Color(0.42, 0.36, 0.4)
            env.ambient_light_energy = 0.75
            env.adjustment_saturation = 1.05
            env.adjustment_contrast = 1.12
            moon.light_color = Color(0.75, 0.7, 0.85)
        else:
            env.fog_light_color = Color(0.07, 0.08, 0.12)
            env.fog_density = 0.012
            env.ambient_light_color = Color(0.36, 0.4, 0.58)
            env.ambient_light_energy = 1.0
            env.adjustment_saturation = 0.7
            env.adjustment_contrast = 1.0
            moon.light_color = Color(0.55, 0.65, 1.0)

func zone_at(p: Vector3) -> Array:
    for z: Array in ZONES:
        if p.x >= z[2] and p.x <= z[3] and p.z >= z[4] and p.z <= z[5]:
            return z
    return []

func open_gate(gname: String, instant := false) -> void:
    if not gates.has(gname):
        return
    var g: Node3D = gates[gname]
    if g.get_meta("open", false):
        return
    g.set_meta("open", true)
    var target := g.position + Vector3(0, 4.2, 0)
    if instant:
        g.position = target
    else:
        var tw := g.create_tween()
        tw.tween_property(g, "position", target, 2.2).set_trans(Tween.TRANS_SINE)
        get_node("/root/Sfx").play("gate", -2.0)

func set_fog(active: bool) -> void:
    fog_body.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
    (fog_body.get_child(0) as CollisionShape3D).disabled = not active
    fog_mesh.visible = active

func set_portal(on: bool) -> void:
    var tw := create_tween()
    tw.tween_method(_portal_power, 0.0 if on else 1.0, 1.0 if on else 0.0, 2.5)

func _portal_power(v: float) -> void:
    portal_mat.set_shader_parameter("power", v)
    portal_light.light_energy = v * 3.0

func _process(delta: float) -> void:
    _time += delta
    for f: Array in _flicker:
        var l: OmniLight3D = f[0]
        var e: float = f[1]
        var o: float = f[2]
        l.light_energy = e * (0.82 + 0.1 * sin(_time * 9.0 + o) + 0.08 * sin(_time * 23.0 + o * 2.0))

# ------------------------------------------------------------------ primitives

func _box(pos: Vector3, size: Vector3, kind: String, collide := true, cut := false, rot := Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mats[kind] if mats.has(kind) else kind_mat(kind)
    if collide:
        var body := StaticBody3D.new()
        body.collision_layer = 1
        body.collision_mask = 0
        body.position = pos
        body.rotation_degrees = rot
        var cs := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        cs.shape = shape
        body.add_child(cs)
        body.add_child(mi)
        add_child(body)
    else:
        mi.position = pos
        mi.rotation_degrees = rot
        add_child(mi)
    if cut:
        _cut.append([mi, size.y])
    return mi

func _floor(x0: float, x1: float, z0: float, z1: float, top: float, kind: String, thick := 1.0) -> void:
    _box(Vector3((x0 + x1) * 0.5, top - thick * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, thick, z1 - z0), kind)

## Axis aligned wall from (x0,z0) to (x1,z1). East-west walls are cut away in exploration unless keep_full.
func _wall(x0: float, z0: float, x1: float, z1: float, h: float, kind := "brick", base := 0.0, keep_full := false) -> void:
    var t := 0.8
    var ew := absf(z1 - z0) < 0.01
    var size := Vector3(absf(x1 - x0) + t, h, t) if ew else Vector3(t, h, absf(z1 - z0) + t)
    _box(Vector3((x0 + x1) * 0.5, base + h * 0.5, (z0 + z1) * 0.5), size, kind, true, ew and not keep_full)
    # a darker plinth gives walls some weight
    var plinth := size + Vector3(0.12, 0, 0.12)
    plinth.y = 0.35
    _box(Vector3((x0 + x1) * 0.5, base + 0.175, (z0 + z1) * 0.5), plinth, "moss", false)

func _cyl(pos: Vector3, r_bot: float, r_top: float, h: float, kind: String, collide := true, sides := 12) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.bottom_radius = r_bot
    cm.top_radius = r_top
    cm.height = h
    cm.radial_segments = sides
    mi.mesh = cm
    mi.material_override = mats[kind] if mats.has(kind) else kind_mat(kind)
    if collide:
        var body := StaticBody3D.new()
        body.collision_layer = 1
        body.collision_mask = 0
        body.position = pos
        var cs := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = maxf(r_bot, r_top)
        shape.height = h
        cs.shape = shape
        body.add_child(cs)
        body.add_child(mi)
        add_child(body)
    else:
        mi.position = pos
        add_child(mi)
    return mi

var _extra_mats := {}

func kind_mat(kind: String) -> StandardMaterial3D:
    if _extra_mats.has(kind):
        return _extra_mats[kind]
    var m := StandardMaterial3D.new()
    match kind:
        "wax":
            m.albedo_color = Color(0.85, 0.8, 0.68)
            m.roughness = 0.6
        "flame":
            m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            m.albedo_color = Color(1.0, 0.7, 0.3)
            m.emission_enabled = true
            m.emission = Color(1.0, 0.55, 0.2)
            m.emission_energy_multiplier = 4.0
        "pale_flame":
            m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            m.albedo_color = Color(0.8, 0.88, 1.0)
            m.emission_enabled = true
            m.emission = Color(0.7, 0.8, 1.0)
            m.emission_energy_multiplier = 4.0
        "blood":
            m.albedo_color = Color(0.22, 0.01, 0.01)
            m.roughness = 0.08
            m.metallic = 0.3
            m.emission_enabled = true
            m.emission = Color(0.25, 0.0, 0.0)
        "cloth":
            m.albedo_color = Color(0.3, 0.05, 0.06)
            m.albedo_texture = Tex.detail("cloth")
            m.roughness = 1.0
        "moon":
            m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            m.albedo_color = Color(0.85, 0.88, 0.95)
        "bone":
            m.albedo_color = Color(0.7, 0.66, 0.58)
            m.roughness = 0.7
        _:
            m.albedo_color = Color(0.3, 0.3, 0.3)
    _extra_mats[kind] = m
    return m

func _light(pos: Vector3, color: Color, energy: float, rng: float, flicker := true) -> OmniLight3D:
    var l := OmniLight3D.new()
    l.position = pos
    l.light_color = color
    l.light_energy = energy
    l.omni_range = rng
    l.omni_attenuation = 1.2
    l.shadow_enabled = false
    add_child(l)
    if flicker:
        _flicker.append([l, energy, randf() * 10.0])
    return l

# ------------------------------------------------------------------ props

func _torch(pos: Vector3, wall_normal := Vector3.ZERO) -> void:
    if wall_normal == Vector3.ZERO:
        _cyl(Vector3(pos.x, pos.y * 0.5, pos.z), 0.08, 0.05, pos.y, "iron", true, 6)
        _cyl(pos, 0.12, 0.2, 0.18, "iron", false, 8)
    else:
        _box(pos - wall_normal * 0.2 + Vector3(0, -0.15, 0), Vector3(0.08, 0.35, 0.08), "iron", false)
        _cyl(pos + Vector3(0, -0.02, 0), 0.06, 0.1, 0.14, "iron", false, 6)
    var f := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.09
    sm.height = 0.26
    f.mesh = sm
    f.material_override = kind_mat("flame")
    f.position = pos + Vector3(0, 0.15, 0)
    add_child(f)
    _light(pos + Vector3(0, 0.4, 0) + wall_normal * 0.4, Color(1.0, 0.58, 0.28), 2.4, 8.5)

func _candles(pos: Vector3, count := 5, light := true) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(pos.x * 31.0 + pos.z * 17.0)
    for i in count:
        var o := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
        var h := rng.randf_range(0.12, 0.45)
        _cyl(pos + o + Vector3(0, h * 0.5, 0), 0.035, 0.035, h, "wax", false, 6)
        var f := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.025
        sm.height = 0.07
        f.mesh = sm
        f.material_override = kind_mat("flame")
        f.position = pos + o + Vector3(0, h + 0.04, 0)
        add_child(f)
    if light:
        _light(pos + Vector3(0, 0.7, 0), Color(1.0, 0.62, 0.32), 1.5, 5.0)

func _pillar(pos: Vector3, h: float, kind := "moss", broken := false) -> void:
    _box(pos + Vector3(0, 0.25, 0), Vector3(1.5, 0.5, 1.5), kind)
    var ph := h * (0.45 if broken else 1.0)
    _cyl(pos + Vector3(0, 0.5 + ph * 0.5, 0), 0.52, 0.48, ph, kind, true, 10)
    if broken:
        _cyl(pos + Vector3(1.4, 0.45, 0.3), 0.48, 0.48, 1.6, kind, false, 10).rotation_degrees = Vector3(0, 30, 90)
    else:
        _box(pos + Vector3(0, 0.5 + ph + 0.2, 0), Vector3(1.3, 0.4, 1.3), kind)

func _gravestone(pos: Vector3, rot := 0.0, tilt := 0.0, cross := false) -> void:
    if cross:
        _box(pos + Vector3(0, 0.6, 0), Vector3(0.18, 1.2, 0.18), "moss", true, false, Vector3(tilt, rot, 0))
        _box(pos + Vector3(0, 0.85, 0), Vector3(0.7, 0.16, 0.16), "moss", false, false, Vector3(tilt, rot, 0))
    else:
        _box(pos + Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.22), "moss", true, false, Vector3(tilt, rot, 0))
        var top := _cyl(pos + Vector3(0, 1.0, 0), 0.4, 0.4, 0.22, "moss", false, 12)
        top.rotation_degrees = Vector3(90 + tilt, rot, 0)
    _box(pos + Vector3(0, 0.03, 0.55), Vector3(0.9, 0.06, 1.3), "earth", false, false, Vector3(0, rot, 0))

func _dead_tree(pos: Vector3, h: float, seed_v: int) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    _cyl(pos + Vector3(0, h * 0.5, 0), 0.32, 0.14, h, "wood", true, 7)
    for i in 6:
        var y := h * rng.randf_range(0.45, 0.95)
        var len := rng.randf_range(1.2, 2.6)
        var yaw := rng.randf() * 360.0
        var pitch := rng.randf_range(25.0, 65.0)
        var b := _cyl(Vector3.ZERO, 0.1, 0.02, len, "wood", false, 5)
        var dir := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)) * Vector3.UP
        b.basis = Basis(Quaternion(Vector3.UP, dir))
        b.position = pos + Vector3(0, y, 0) + dir * len * 0.5

func _fence(a: Vector3, b: Vector3) -> void:
    var d := b - a
    var n := int(d.length() / 0.35)
    for i in n + 1:
        var p := a + d * (float(i) / maxf(n, 1))
        _box(p + Vector3(0, 0.75, 0), Vector3(0.05, 1.5, 0.05), "iron", false)
        var spike := _cyl(p + Vector3(0, 1.55, 0), 0.05, 0.0, 0.14, "iron", false, 4)
        spike.name = "spike"
    var mid := (a + b) * 0.5
    var yaw := rad_to_deg(atan2(d.x, d.z))
    for y in [0.3, 1.3]:
        _box(mid + Vector3(0, y, 0), Vector3(0.06, 0.06, d.length()), "iron", false, false, Vector3(0, yaw, 0))
    # invisible collision along the fence
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.position = mid + Vector3(0, 0.75, 0)
    body.rotation_degrees = Vector3(0, yaw, 0)
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(0.15, 1.5, d.length())
    cs.shape = shape
    body.add_child(cs)
    add_child(body)

func _banner(pos: Vector3, rot_y := 0.0) -> void:
    _box(pos, Vector3(0.9, 2.2, 0.04), "cloth", false, false, Vector3(0, rot_y, 0))
    _box(pos + Vector3(0, 1.15, 0), Vector3(1.1, 0.08, 0.08), "iron", false, false, Vector3(0, rot_y, 0))

func _coffin(pos: Vector3, rot := 0.0, open := false) -> void:
    _box(pos + Vector3(0, 0.25, 0), Vector3(0.75, 0.5, 2.0), "wood", true, false, Vector3(0, rot, 0))
    if open:
        _box(pos + Vector3(0.7, 0.05, 0.2), Vector3(0.75, 0.08, 2.0), "wood", false, false, Vector3(0, rot + 12, 0))

func _shelf(pos: Vector3, rot := 0.0) -> void:
    _box(pos + Vector3(0, 1.2, 0), Vector3(1.8, 2.4, 0.5), "wood", true, false, Vector3(0, rot, 0))
    var rng := RandomNumberGenerator.new()
    rng.seed = int(pos.x * 13 + pos.z * 7)
    for row in 3:
        for i in 6:
            var c := Color(rng.randf_range(0.15, 0.4), rng.randf_range(0.06, 0.15), rng.randf_range(0.05, 0.1))
            var m := StandardMaterial3D.new()
            m.albedo_color = c
            var bk := MeshInstance3D.new()
            var bm := BoxMesh.new()
            bm.size = Vector3(0.18, rng.randf_range(0.35, 0.5), 0.3)
            bk.mesh = bm
            bk.material_override = m
            var local := Vector3(-0.7 + i * 0.26, 0.55 + row * 0.75, -0.12)
            bk.position = pos + Basis(Vector3.UP, deg_to_rad(rot)) * local
            bk.rotation_degrees = Vector3(0, rot, 0)
            add_child(bk)

func _statue(pos: Vector3, rot := 0.0, h := 2.6) -> void:
    _box(pos + Vector3(0, 0.4, 0), Vector3(1.3, 0.8, 1.3), "marble")
    _cyl(pos + Vector3(0, 0.8 + h * 0.4, 0), 0.55, 0.25, h * 0.8, "marble", false, 10)
    _cyl(pos + Vector3(0, 0.8 + h * 0.86, 0), 0.2, 0.17, 0.35, "marble", false, 10)
    var wing_l := _box(pos + Vector3(-0.45, 0.8 + h * 0.6, 0.2), Vector3(0.12, h * 0.6, 0.7), "marble", false, false, Vector3(0, rot, 25))
    wing_l.name = "wing"
    _box(pos + Vector3(0.45, 0.8 + h * 0.6, 0.2), Vector3(0.12, h * 0.6, 0.7), "marble", false, false, Vector3(0, rot, -25))
    _box(pos + Vector3(0, 0.8 + h * 0.5, -0.4), Vector3(0.08, h * 0.7, 0.08), "marble", false, false, Vector3(-10, rot, 0))

func _message(pos: Vector3, text: String) -> void:
    var it := Interactable.make("message", "Read message", {"text": text}, 1.4)
    it.position = pos
    add_child(it)
    interactables.append(it)
    var q := MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = Vector2(1.5, 0.5)
    q.mesh = qm
    q.rotation_degrees = Vector3(-90, 0, 0)
    q.position = Vector3(0, 0.04, 0)
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.albedo_texture = Tex.rune_texture()
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    m.albedo_color = Color(1.0, 0.75, 0.45, 0.95)
    m.emission_enabled = true
    m.emission = Color(1.0, 0.5, 0.15)
    m.emission_energy_multiplier = 1.5
    q.material_override = m
    q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    it.add_child(q)
    var l := OmniLight3D.new()
    l.light_color = Color(1.0, 0.55, 0.2)
    l.light_energy = 0.7
    l.omni_range = 2.2
    l.position = Vector3(0, 0.4, 0)
    it.add_child(l)

func _lantern(id: String, pos: Vector3) -> void:
    var it := Interactable.make("lantern", "Rest at lantern", {"id": id}, 2.0)
    it.position = pos
    add_child(it)
    interactables.append(it)
    var post := _cyl(pos + Vector3(0, 1.0, 0), 0.07, 0.05, 2.0, "iron", true, 8)
    post.name = "lantern_post"
    _box(pos + Vector3(0, 0.1, 0), Vector3(0.7, 0.2, 0.7), "moss")
    _box(pos + Vector3(0.25, 2.0, 0), Vector3(0.5, 0.05, 0.05), "iron", false)
    var cage := _cyl(pos + Vector3(0.48, 1.72, 0), 0.16, 0.12, 0.42, "iron", false, 6)
    cage.transparency = 0.4
    var f := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.1
    sm.height = 0.22
    f.mesh = sm
    f.material_override = kind_mat("pale_flame")
    f.position = Vector3(0.48, 1.7, 0)
    it.add_child(f)
    var l := _light(pos + Vector3(0.48, 1.8, 0), Color(0.7, 0.8, 1.0), 2.0, 7.0)
    it.set_meta("light", l)
    it.set_meta("flame", f)

func _altar(weapon: String, pos: Vector3) -> void:
    var st: Dictionary = Weapons.stats(weapon)
    var it := Interactable.make("altar", "Take " + String(st["name"]), {"weapon": weapon}, 1.8)
    it.position = pos
    add_child(it)
    interactables.append(it)
    _box(pos + Vector3(0, 0.15, 0), Vector3(1.6, 0.3, 1.6), "marble")
    _box(pos + Vector3(0, 0.65, 0), Vector3(0.9, 0.7, 0.9), "marble")
    _box(pos + Vector3(0, 1.05, 0), Vector3(1.2, 0.12, 1.2), "marble")
    var holder := Node3D.new()
    holder.name = "WeaponDisplay"
    holder.position = Vector3(0, 1.65, 0)
    it.add_child(holder)
    var w := Weapons.build(weapon)
    var wn: Node3D = w["node"]
    wn.rotation_degrees = Vector3(0, 0, 180)
    wn.position = Vector3(0, 0.45 if weapon != "twinfangs" else 0.2, 0)
    holder.add_child(wn)
    if weapon == "twinfangs":
        var w2 := Weapons.build("fang_l")
        var wn2: Node3D = w2["node"]
        wn2.rotation_degrees = Vector3(0, 0, 160)
        wn2.position = Vector3(0.2, 0.2, 0)
        holder.add_child(wn2)
    var tw := holder.create_tween().set_loops()
    tw.tween_property(holder, "rotation:y", TAU, 6.0).from(0.0)
    var l := OmniLight3D.new()
    l.light_color = Color(0.75, 0.82, 1.0)
    l.light_energy = 1.2
    l.omni_range = 3.5
    l.position = Vector3(0, 2.4, 0)
    it.add_child(l)
    it.set_meta("display", holder)

func _gate(gname: String, center: Vector3, width: float) -> void:
    var g := StaticBody3D.new()
    g.collision_layer = 1
    g.position = center
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(width, 4.0, 0.3)
    cs.shape = shape
    cs.position = Vector3(0, 2.0, 0)
    g.add_child(cs)
    var n := int(width / 0.32)
    for i in n:
        var x := -width * 0.5 + (i + 0.5) * width / n
        var bar := MeshInstance3D.new()
        var bm := BoxMesh.new()
        bm.size = Vector3(0.07, 4.0, 0.07)
        bar.mesh = bm
        bar.material_override = mats["iron"]
        bar.position = Vector3(x, 2.0, 0)
        g.add_child(bar)
        _cut.append([bar, 4.0])
    for y in [0.4, 1.6, 2.8]:
        var rail := MeshInstance3D.new()
        var rm := BoxMesh.new()
        rm.size = Vector3(width, 0.1, 0.1)
        rail.mesh = rm
        rail.material_override = mats["iron"]
        rail.position = Vector3(0, y, 0)
        g.add_child(rail)
    add_child(g)
    gates[gname] = g

# ------------------------------------------------------------------ zones

func _environment() -> void:
    env = Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sm := ProceduralSkyMaterial.new()
    sm.sky_top_color = Color(0.02, 0.025, 0.05)
    sm.sky_horizon_color = Color(0.09, 0.08, 0.11)
    sm.ground_bottom_color = Color(0.01, 0.01, 0.015)
    sm.ground_horizon_color = Color(0.06, 0.05, 0.07)
    sm.sun_angle_max = 0.0
    sky.sky_material = sm
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.36, 0.4, 0.58)
    env.ambient_light_energy = 1.0
    env.fog_enabled = true
    env.fog_light_color = Color(0.07, 0.08, 0.12)
    env.fog_density = 0.012
    env.fog_sky_affect = 0.4
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_exposure = 1.1
    env.glow_enabled = true
    env.glow_intensity = 0.9
    env.glow_bloom = 0.08
    env.adjustment_enabled = true
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    moon = DirectionalLight3D.new()
    moon.rotation = Vector3(deg_to_rad(-50), deg_to_rad(32), 0)
    moon.light_color = Color(0.55, 0.65, 1.0)
    moon.light_energy = 0.75
    moon.shadow_enabled = true
    moon.directional_shadow_max_distance = 60.0
    add_child(moon)
    # a huge pale moon low over the cathedral
    var mm := MeshInstance3D.new()
    var sp := SphereMesh.new()
    sp.radius = 14.0
    sp.height = 28.0
    mm.mesh = sp
    mm.material_override = kind_mat("moon")
    mm.position = Vector3(-40, 60, -190)
    mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mm)

func _chapel() -> void:
    _floor(-7, 7, 58, 72, 0.0, "flagstone")
    _wall(-7, 72, 7, 72, 4.5)
    _wall(-7, 58, -7, 72, 4.5)
    _wall(7, 58, 7, 72, 4.5)
    _wall(-7, 58, -1.5, 58, 4.5)
    _wall(1.5, 58, 7, 58, 4.5)
    # the slab the Pale One wakes on
    _box(Vector3(0, 0.4, 65.5), Vector3(1.1, 0.8, 2.3), "marble")
    _box(Vector3(0, 0.85, 64.5), Vector3(0.6, 0.1, 0.35), "cloth", false)
    # the Veilkeeper's chair
    _box(Vector3(2.4, 0.25, 65.2), Vector3(0.7, 0.5, 0.7), "wood")
    _box(Vector3(2.75, 0.95, 65.2), Vector3(0.1, 1.4, 0.75), "wood", false)
    # the blood pool the beast crawls out of
    var pool := _cyl(Vector3(-2.3, 0.015, 63.8), 1.4, 1.4, 0.03, "blood", false, 24)
    pool.name = "BloodPool"
    _box(Vector3(-2.3, 0.0, 63.8), Vector3(3.2, 0.02, 3.2), "flagstone", false)
    for p: Vector3 in [Vector3(-5.6, 0, 70.5), Vector3(5.6, 0, 70.5), Vector3(-1.4, 0, 67.6), Vector3(1.4, 0, 67.6), Vector3(4.2, 0, 61.5)]:
        _candles(p, 6)
    _shelf(Vector3(-6.3, 0, 66.0), 90)
    _shelf(Vector3(6.3, 0, 68.5), -90)
    _coffin(Vector3(-5.2, 0, 60.8), 90, true)
    _banner(Vector3(-3.5, 2.6, 58.5))
    _banner(Vector3(3.5, 2.6, 58.5))
    _torch(Vector3(-6.4, 2.4, 63.0), Vector3(1, 0, 0))
    _torch(Vector3(6.4, 2.4, 63.0), Vector3(-1, 0, 0))

func _corridor() -> void:
    _floor(-2.5, 2.5, 44, 58, 0.0, "flagstone")
    _wall(-2.5, 44, -2.5, 58, 4.0)
    _wall(2.5, 44, 2.5, 58, 4.0)
    for z in [55.0, 49.0]:
        _torch(Vector3(-2.0, 2.3, z), Vector3(1, 0, 0))
        _torch(Vector3(2.0, 2.3, z + 2.5), Vector3(-1, 0, 0))
    _candles(Vector3(1.6, 0, 47.0), 4, false)
    _candles(Vector3(-1.6, 0, 52.5), 3, false)
    _coffin(Vector3(-1.75, 0, 56.5), 0)

func _hall() -> void:
    _floor(-12, 12, 22, 44, 0.0, "flagstone")
    _box(Vector3(0, 0.005, 28), Vector3(16, 0.01, 6), "marble", false)
    _wall(-12, 44, -2.5, 44, 5.0)
    _wall(2.5, 44, 12, 44, 5.0)
    _wall(-12, 22, -12, 44, 5.0)
    _wall(12, 22, 12, 44, 5.0)
    _wall(-12, 22, -2.2, 22, 5.0)
    _wall(2.2, 22, 12, 22, 5.0)
    _gate("hall", Vector3(0, 0, 22), 4.4)
    for p: Vector3 in [Vector3(-8, 0, 39), Vector3(8, 0, 39), Vector3(-8, 0, 31), Vector3(8, 0, 31)]:
        _pillar(p, 4.5, "brick")
    _altar("longsword", Vector3(0, 0, 25.6))
    _altar("greataxe", Vector3(-5.0, 0, 27.2))
    _altar("twinfangs", Vector3(5.0, 0, 27.2))
    for x in [-9.0, -3.0, 3.0, 9.0]:
        _banner(Vector3(x, 2.8, 22.5))
    _torch(Vector3(-11.4, 2.5, 35.0), Vector3(1, 0, 0))
    _torch(Vector3(11.4, 2.5, 35.0), Vector3(-1, 0, 0))
    _torch(Vector3(-11.4, 2.5, 26.0), Vector3(1, 0, 0))
    _torch(Vector3(11.4, 2.5, 26.0), Vector3(-1, 0, 0))
    # weapon racks and remains of those who came before
    for z in [41.0, 37.0, 33.0]:
        _box(Vector3(-11.3, 1.0, z), Vector3(0.3, 2.0, 1.6), "wood", true)
        _box(Vector3(11.3, 1.0, z), Vector3(0.3, 2.0, 1.6), "wood", true)
    for p: Vector3 in [Vector3(-3.5, 0, 38), Vector3(4.0, 0, 33.5), Vector3(-9.5, 0, 29.5)]:
        _box(p + Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.3), "bone", false, false, Vector3(0, p.x * 20.0, 0))
        _box(p + Vector3(0.3, 0.05, 0.2), Vector3(0.12, 0.1, 0.7), "bone", false, false, Vector3(0, p.z * 15.0, 0))

func _vestibule() -> void:
    _floor(-5, 5, 12, 22, 0.0, "flagstone")
    _wall(-5, 12, -5, 22, 4.5)
    _wall(5, 12, 5, 22, 4.5)
    _wall(-5, 12, -3, 12, 4.5)
    _wall(3, 12, 5, 12, 4.5)
    _lantern("vestibule", CHECKPOINTS["vestibule"]["lantern"])
    _candles(Vector3(4.0, 0, 20.8), 5)
    _coffin(Vector3(3.8, 0, 15.0), 0, false)

func _graveyard() -> void:
    _floor(-22, 22, -30, 12, 0.0, "earth")
    # cobbled path up the middle
    _box(Vector3(0, 0.01, -9), Vector3(4.2, 0.03, 42), "cobble", false)
    _box(Vector3(-9, 0.01, -9), Vector3(14, 0.03, 3.0), "cobble", false)
    _wall(-22, -30, -22, 12, 3.2, "moss")
    _wall(22, -30, 22, 12, 3.2, "moss")
    _wall(-22, 12, -5, 12, 3.2, "moss")
    _wall(5, 12, 22, 12, 3.2, "moss")
    _wall(-22, -30, -3, -30, 3.2, "moss", 0.0, true)
    _wall(3, -30, 22, -30, 3.2, "moss", 0.0, true)
    var rng := RandomNumberGenerator.new()
    rng.seed = 2024
    for i in 46:
        var p := Vector3(rng.randf_range(-20.5, 20.5), 0, rng.randf_range(-27.5, 9.5))
        if absf(p.x) < 3.2 or (absf(p.z + 9.0) < 2.4 and p.x < 0.0 and p.x > -16.5):
            continue
        if p.x < -11.0 and p.x > -19.0 and p.z < -10.0 and p.z > -18.5:
            continue
        if p.x > 11.0 and p.x < 19.0 and p.z > 1.0 and p.z < 8.5:
            continue
        _gravestone(p, rng.randf_range(-15, 15), rng.randf_range(-12, 12), rng.randf() < 0.3)
    # mausoleum (west) and crypt (east)
    _box(Vector3(-15, 2.2, -14.5), Vector3(7, 4.4, 4.5), "brick")
    _box(Vector3(-15, 4.6, -14.5), Vector3(7.6, 0.4, 5.1), "moss")
    _box(Vector3(-15, 1.3, -12.2), Vector3(1.8, 2.6, 0.2), "wood", false)
    _statue(Vector3(-11.2, 0, -11.5), 0, 2.2)
    _box(Vector3(15, 1.6, 5), Vector3(6, 3.2, 4.5), "moss")
    _box(Vector3(15, 3.35, 5), Vector3(6.6, 0.3, 5.0), "brick")
    for x in [-3.2, 3.2]:
        for z in [7.0, -6.0, -20.0]:
            _torch(Vector3(x, 1.6, z))
    _dead_tree(Vector3(-18, 0, 8), 7.0, 1)
    _dead_tree(Vector3(18, 0, -8), 8.0, 2)
    _dead_tree(Vector3(-7.5, 0, -24), 6.5, 3)
    _dead_tree(Vector3(9.5, 0, 9.5), 6.0, 4)
    _dead_tree(Vector3(19, 0, -25), 7.5, 5)
    _fence(Vector3(-3.3, 0, 10.5), Vector3(-3.3, 0, 4.0))
    _fence(Vector3(3.3, 0, 10.5), Vector3(3.3, 0, 2.0))
    _fence(Vector3(3.3, 0, -12.0), Vector3(3.3, 0, -18.0))
    _fence(Vector3(-3.3, 0, -24.0), Vector3(-3.3, 0, -28.5))
    _pillar(Vector3(8.0, 0, -9.0), 4.0, "moss", true)
    _pillar(Vector3(-7.0, 0, -18.5), 4.0, "moss", true)
    _coffin(Vector3(13.0, 0, -21.0), 30, true)
    _coffin(Vector3(-17.0, 0, 0.0), -20, false)

func _steps() -> void:
    # stairs: visual steps, one smooth invisible ramp for collision
    _wall(-3, -36, -3, -30, 3.2, "moss")
    _wall(3, -36, 3, -30, 3.2, "moss")
    for i in 8:
        var top := (i + 1) * 0.25
        _box(Vector3(0, top * 0.5, -30.0 - i * 0.75 - 0.375), Vector3(6, top, 0.75), "moss", false)
    var ramp := StaticBody3D.new()
    ramp.collision_layer = 1
    var ang := atan2(2.0, 6.0)
    ramp.rotation = Vector3(ang, 0, 0)
    ramp.position = Vector3(0, 1.0, -33.0) - Vector3(0, cos(ang), sin(ang)) * 0.2
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(6, 0.4, sqrt(40.0) + 0.6)
    cs.shape = sh
    ramp.add_child(cs)
    add_child(ramp)
    # cathedral approach plateau
    _box(Vector3(0, 0.75, -41.0), Vector3(16, 2.5, 10), "brick")
    _box(Vector3(0, 2.005, -41.0), Vector3(16, 0.01, 10), "flagstone", false)
    _wall(-8, -46, -8, -36, 3.5, "brick", 2.0)
    _wall(8, -46, 8, -36, 3.5, "brick", 2.0)
    _wall(-8, -36, -3, -36, 3.5, "brick", 2.0)
    _wall(3, -36, 8, -36, 3.5, "brick", 2.0)
    _wall(-8, -46, -3.2, -46, 3.5, "brick", 2.0)
    _wall(3.2, -46, 8, -46, 3.5, "brick", 2.0)
    _lantern("cathedral", CHECKPOINTS["cathedral"]["lantern"])
    _statue(Vector3(-6.0, 2.0, -44.0), 0, 2.6)
    _statue(Vector3(6.0, 2.0, -44.0), 0, 2.6)
    _torch(Vector3(-3.6, 3.8, -45.4), Vector3(0, 0, 1))
    _torch(Vector3(3.6, 3.8, -45.4), Vector3(0, 0, 1))
    _candles(Vector3(-6.5, 2.0, -38.0), 6)
    # the white fog
    var fog := Interactable.make("fog", "Traverse the white fog", {}, 2.2)
    fog.position = Vector3(0, 2.0, -45.6)
    add_child(fog)
    interactables.append(fog)
    fog_body = StaticBody3D.new()
    fog_body.collision_layer = 1
    fog_body.position = Vector3(0, 4.0, -46.0)
    var fcs := CollisionShape3D.new()
    var fsh := BoxShape3D.new()
    fsh.size = Vector3(6.6, 4.0, 0.4)
    fcs.shape = fsh
    fog_body.add_child(fcs)
    add_child(fog_body)
    fog_mesh = MeshInstance3D.new()
    var fq := QuadMesh.new()
    fq.size = Vector2(6.6, 4.2)
    fog_mesh.mesh = fq
    fog_mat = ShaderMaterial.new()
    var fsd := Shader.new()
    fsd.code = FOG_SHADER
    fog_mat.shader = fsd
    fog_mesh.material_override = fog_mat
    fog_mesh.position = Vector3(0, 4.05, -46.0)
    fog_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(fog_mesh)
    var fog2 := MeshInstance3D.new()
    fog2.mesh = fq
    fog2.material_override = fog_mat
    fog2.position = Vector3(0, 4.05, -46.15)
    fog2.rotation_degrees = Vector3(0, 180, 0)
    fog_mesh.add_child(fog2)
    fog2.position = Vector3(0, 0, -0.15)

func _arena() -> void:
    var c := Vector3(0, 2, -63)
    _box(Vector3(0, 0.75, -64.5), Vector3(36, 2.5, 37), "marble")
    _box(Vector3(0, 2.005, -63), Vector3(14, 0.01, 14), "flagstone", false)
    var segs := 22
    var r := 16.5
    for i in segs:
        var a := TAU * i / segs
        var dir := Vector3(sin(a), 0, cos(a))
        if i == 0 or i == segs / 2:
            continue  # entrance (south) and the Sundered Gate (north)
        var p := c + dir * r
        var length := TAU * r / segs + 0.4
        var south := dir.z > 0.2
        _box(p + Vector3(0, 3.0, 0), Vector3(length, 6.0, 1.0), "brick", true, south, Vector3(0, rad_to_deg(a), 0))
        if i % 2 == 1:
            _box(p + Vector3(0, 3.2, 0) - dir * 0.7, Vector3(0.9, 6.4, 0.9), "moss", true, south, Vector3(0, rad_to_deg(a), 0))
    # entrance walls connecting the fog gap to the ring
    _wall(-3.2, -46, -3.2, -47.8, 4.0, "brick", 2.0)
    _wall(3.2, -46, 3.2, -47.8, 4.0, "brick", 2.0)
    # inner ring of pillars, some broken
    for i in 10:
        var a := TAU * (i + 0.5) / 10.0
        var p := c + Vector3(sin(a), 0, cos(a)) * 11.5
        _pillar(p, 6.5, "marble", i % 3 == 1)
    # a sigil where the Warden kneels
    var sig := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 3.6
    tm.outer_radius = 3.9
    tm.rings = 48
    sig.mesh = tm
    var sm := StandardMaterial3D.new()
    sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sm.albedo_color = Color(0.5, 0.65, 1.0)
    sm.emission_enabled = true
    sm.emission = Color(0.4, 0.55, 1.0)
    sig.material_override = sm
    sig.scale = Vector3(1, 0.05, 1)
    sig.position = c + Vector3(0, 0.02, 0)
    add_child(sig)
    for i in 8:
        var a := TAU * i / 8.0
        _candles(c + Vector3(sin(a), 0, cos(a)) * 14.6, 5, i % 2 == 0)
    _light(c + Vector3(0, 9, 0), Color(0.6, 0.7, 1.0), 1.6, 26.0, false)
    # the Sundered Gate: alcove, portcullis and the rift itself
    _floor(-3.5, 3.5, -88, -79, 2.0, "marble")
    _wall(-3.5, -88, -3.5, -79.5, 6.0, "brick", 2.0)
    _wall(3.5, -88, 3.5, -79.5, 6.0, "brick", 2.0)
    _wall(-3.5, -88, 3.5, -88, 6.0, "brick", 2.0, true)
    _gate("arena", Vector3(0, 2.0, -79.6), 5.6)
    var ring := MeshInstance3D.new()
    var rt := TorusMesh.new()
    rt.inner_radius = 1.9
    rt.outer_radius = 2.2
    rt.rings = 40
    ring.mesh = rt
    ring.material_override = mats["marble"]
    ring.rotation_degrees = Vector3(90, 0, 0)
    ring.position = Vector3(0, 4.4, -85.0)
    add_child(ring)
    var disc := MeshInstance3D.new()
    var dq := QuadMesh.new()
    dq.size = Vector2(4.0, 4.0)
    disc.mesh = dq
    portal_mat = ShaderMaterial.new()
    var psd := Shader.new()
    psd.code = PORTAL_SHADER
    portal_mat.shader = psd
    portal_mat.set_shader_parameter("power", 0.0)
    disc.material_override = portal_mat
    disc.position = Vector3(0, 4.4, -85.0)
    add_child(disc)
    portal_light = _light(Vector3(0, 4.4, -84.0), Color(1.0, 0.4, 0.35), 0.0, 9.0, false)
    var portal := Interactable.make("portal", "Enter the Sundered Gate", {}, 2.6)
    portal.position = Vector3(0, 2.0, -84.0)
    portal.enabled = false
    add_child(portal)
    interactables.append(portal)
