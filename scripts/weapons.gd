class_name Weapons
extends RefCounted
## Weapon stats, procedural meshes and the poses their attacks are animated with.
## Weapon local space: grip at the origin, blade extends along +Y.
## Attached to a hand rotated -90 deg on X, so with the arm hanging the blade points forward.
## Pose angles are degrees (Euler YXZ). See Humanoid for joint conventions.

const PLAYER_WEAPONS := ["longsword", "greataxe", "twinfangs"]

const STATS := {
    "fists": {
        "name": "Bare Fists", "desc": "Nothing but bone and spite.",
        "light": 8.0, "heavy": 16.0, "light_dur": 0.4, "heavy_dur": 0.75,
        "light_hit": 0.16, "heavy_hit": 0.42, "light_cost": 8.0, "heavy_cost": 18.0,
        "range": 1.6, "arc": 0.35, "poise": 6.0, "heavy_poise": 14.0, "trail": Color(0.8, 0.8, 0.9, 0.0),
    },
    "longsword": {
        "name": "Hunter's Longsword", "desc": "A balanced blade. Quick cuts, a solid overhead strike.",
        "light": 24.0, "heavy": 46.0, "light_dur": 0.55, "heavy_dur": 0.95,
        "light_hit": 0.22, "heavy_hit": 0.5, "light_cost": 12.0, "heavy_cost": 26.0,
        "range": 2.5, "arc": 0.1, "poise": 14.0, "heavy_poise": 34.0, "trail": Color(0.75, 0.85, 1.0, 0.55),
    },
    "greataxe": {
        "name": "Ashen Greataxe", "desc": "Slow and brutal. Every swing breaks a guard.",
        "light": 36.0, "heavy": 68.0, "light_dur": 0.85, "heavy_dur": 1.35,
        "light_hit": 0.4, "heavy_hit": 0.78, "light_cost": 19.0, "heavy_cost": 34.0,
        "range": 2.9, "arc": -0.1, "poise": 30.0, "heavy_poise": 60.0, "trail": Color(1.0, 0.6, 0.35, 0.55),
    },
    "twinfangs": {
        "name": "Twin Fangs", "desc": "A pair of curved daggers. Fast, relentless, short reach.",
        "light": 14.0, "heavy": 30.0, "light_dur": 0.34, "heavy_dur": 0.72,
        "light_hit": 0.12, "heavy_hit": 0.36, "light_cost": 8.0, "heavy_cost": 22.0,
        "range": 2.0, "arc": -0.3, "poise": 6.0, "heavy_poise": 18.0, "trail": Color(0.85, 0.4, 0.45, 0.5),
    },
}

## Arm guard stance per weapon (absolute joint rotations, merged over the body stance).
const STANCE := {
    "fists": {"arm_r": Vector3(35, 0, 12), "fore_r": Vector3(110, 0, 0), "arm_l": Vector3(40, 0, -12), "fore_l": Vector3(115, 0, 0)},
    "longsword": {"arm_r": Vector3(20, 0, 8), "fore_r": Vector3(35, 0, 0), "hand_r": Vector3(-25, 0, 0),
        "arm_l": Vector3(12, 0, -10), "fore_l": Vector3(25, 0, 0)},
    "greataxe": {"arm_r": Vector3(30, -20, 0), "fore_r": Vector3(45, 0, 0), "hand_r": Vector3(-35, 0, 0),
        "arm_l": Vector3(42, 28, 0), "fore_l": Vector3(55, 0, 0)},
    "twinfangs": {"arm_r": Vector3(25, 0, 12), "fore_r": Vector3(75, 0, 0), "hand_r": Vector3(-65, 0, 0),
        "arm_l": Vector3(25, 0, -12), "fore_l": Vector3(75, 0, 0), "hand_l": Vector3(-65, 0, 0)},
}

## Attack poses: [windup, strike, follow-through]. Turned into timed animations by Humanoid.make_attack.
const ATTACKS := {
    "fists": {
        "light_a": [{"arm_r": Vector3(25, 0, 15), "fore_r": Vector3(130, 0, 0), "chest": Vector3(0, -25, 0)},
            {"arm_r": Vector3(88, 0, 0), "fore_r": Vector3(5, 0, 0), "chest": Vector3(0, 20, 0), "lift": Vector3(0, -0.04, 0)},
            {"arm_r": Vector3(80, 0, 0), "fore_r": Vector3(15, 0, 0), "chest": Vector3(0, 15, 0)}],
        "light_b": [{"arm_l": Vector3(25, 0, -15), "fore_l": Vector3(130, 0, 0), "chest": Vector3(0, 25, 0)},
            {"arm_l": Vector3(88, 0, 0), "fore_l": Vector3(5, 0, 0), "chest": Vector3(0, -20, 0), "lift": Vector3(0, -0.04, 0)},
            {"arm_l": Vector3(80, 0, 0), "fore_l": Vector3(15, 0, 0), "chest": Vector3(0, -15, 0)}],
        "heavy": [{"arm_r": Vector3(170, 0, 15), "fore_r": Vector3(60, 0, 0), "chest": Vector3(15, -15, 0)},
            {"arm_r": Vector3(70, 0, 5), "fore_r": Vector3(20, 0, 0), "chest": Vector3(-20, 10, 0), "spine": Vector3(-15, 0, 0), "lift": Vector3(0, -0.1, 0)},
            {"arm_r": Vector3(50, 0, 5), "fore_r": Vector3(25, 0, 0), "chest": Vector3(-15, 10, 0), "spine": Vector3(-15, 0, 0)}],
    },
    "longsword": {
        "light_a": [{"arm_r": Vector3(85, -45, 0), "fore_r": Vector3(20, 0, 0), "hand_r": Vector3(-80, 0, 0),
                "chest": Vector3(0, -40, 0), "head": Vector3(0, 30, 0), "lift": Vector3(0, -0.05, 0)},
            {"arm_r": Vector3(88, 0, 0), "fore_r": Vector3(5, 0, 0), "hand_r": Vector3(-85, 0, 0), "chest": Vector3(0, 5, 0)},
            {"arm_r": Vector3(85, 50, 0), "fore_r": Vector3(25, 0, 0), "hand_r": Vector3(-70, 0, 0),
                "chest": Vector3(0, 40, 0), "head": Vector3(0, -30, 0)}],
        "light_b": [{"arm_r": Vector3(80, 50, 0), "fore_r": Vector3(25, 0, 0), "hand_r": Vector3(-80, 0, 0),
                "chest": Vector3(0, 35, 0), "head": Vector3(0, -25, 0), "lift": Vector3(0, -0.05, 0)},
            {"arm_r": Vector3(88, 0, 0), "fore_r": Vector3(5, 0, 0), "hand_r": Vector3(-85, 0, 0), "chest": Vector3(0, 0, 0)},
            {"arm_r": Vector3(82, -50, 0), "fore_r": Vector3(20, 0, 0), "hand_r": Vector3(-75, 0, 0),
                "chest": Vector3(0, -40, 0), "head": Vector3(0, 30, 0)}],
        "heavy": [{"arm_r": Vector3(175, 0, 10), "fore_r": Vector3(10, 0, 0), "hand_r": Vector3(-10, 0, 0),
                "arm_l": Vector3(170, 0, -10), "fore_l": Vector3(20, 0, 0), "chest": Vector3(15, 0, 0), "spine": Vector3(10, 0, 0),
                "thigh_l": Vector3(25, 0, 0), "shin_l": Vector3(-20, 0, 0), "lift": Vector3(0, 0.03, 0)},
            {"arm_r": Vector3(60, 0, 5), "fore_r": Vector3(5, 0, 0), "hand_r": Vector3(-75, 0, 0),
                "arm_l": Vector3(55, 0, -5), "fore_l": Vector3(15, 0, 0), "chest": Vector3(-20, 0, 0), "spine": Vector3(-20, 0, 0),
                "thigh_l": Vector3(50, 0, 0), "shin_l": Vector3(-50, 0, 0), "thigh_r": Vector3(-25, 0, 0), "shin_r": Vector3(-30, 0, 0),
                "lift": Vector3(0, -0.15, 0)},
            {"arm_r": Vector3(45, 0, 5), "fore_r": Vector3(5, 0, 0), "hand_r": Vector3(-70, 0, 0),
                "arm_l": Vector3(42, 0, -5), "fore_l": Vector3(15, 0, 0), "chest": Vector3(-20, 0, 0), "spine": Vector3(-20, 0, 0),
                "thigh_l": Vector3(50, 0, 0), "shin_l": Vector3(-50, 0, 0), "thigh_r": Vector3(-25, 0, 0), "shin_r": Vector3(-30, 0, 0),
                "lift": Vector3(0, -0.15, 0)}],
    },
    "greataxe": {
        "light_a": [{"arm_r": Vector3(80, -60, 0), "arm_l": Vector3(75, -30, 0), "fore_r": Vector3(25, 0, 0), "fore_l": Vector3(40, 0, 0),
                "hand_r": Vector3(-80, 0, 0), "chest": Vector3(0, -55, 0), "head": Vector3(0, 40, 0), "lift": Vector3(0, -0.08, 0)},
            {"arm_r": Vector3(85, 0, 0), "arm_l": Vector3(80, 25, 0), "fore_r": Vector3(10, 0, 0), "fore_l": Vector3(30, 0, 0),
                "hand_r": Vector3(-85, 0, 0), "chest": Vector3(0, 5, 0)},
            {"arm_r": Vector3(80, 65, 0), "arm_l": Vector3(80, 85, 0), "fore_r": Vector3(15, 0, 0), "fore_l": Vector3(30, 0, 0),
                "hand_r": Vector3(-75, 0, 0), "chest": Vector3(0, 55, 0), "head": Vector3(0, -40, 0), "lift": Vector3(0, -0.08, 0)}],
        "light_b": [{"arm_r": Vector3(80, 60, 0), "arm_l": Vector3(80, 85, 0), "fore_r": Vector3(15, 0, 0), "fore_l": Vector3(30, 0, 0),
                "hand_r": Vector3(-80, 0, 0), "chest": Vector3(0, 50, 0), "head": Vector3(0, -35, 0), "lift": Vector3(0, -0.08, 0)},
            {"arm_r": Vector3(85, 0, 0), "arm_l": Vector3(80, 25, 0), "fore_r": Vector3(10, 0, 0), "fore_l": Vector3(30, 0, 0),
                "hand_r": Vector3(-85, 0, 0), "chest": Vector3(0, 0, 0)},
            {"arm_r": Vector3(80, -60, 0), "arm_l": Vector3(75, -30, 0), "fore_r": Vector3(25, 0, 0), "fore_l": Vector3(40, 0, 0),
                "hand_r": Vector3(-75, 0, 0), "chest": Vector3(0, -50, 0), "head": Vector3(0, 35, 0)}],
        "heavy": [{"arm_r": Vector3(185, 0, 10), "arm_l": Vector3(180, 0, -10), "fore_r": Vector3(25, 0, 0), "fore_l": Vector3(30, 0, 0),
                "hand_r": Vector3(-5, 0, 0), "chest": Vector3(22, 0, 0), "spine": Vector3(12, 0, 0), "head": Vector3(-15, 0, 0),
                "thigh_l": Vector3(30, 0, 0), "shin_l": Vector3(-25, 0, 0), "lift": Vector3(0, 0.05, 0)},
            {"arm_r": Vector3(55, 0, 5), "arm_l": Vector3(50, 0, -5), "fore_r": Vector3(5, 0, 0), "fore_l": Vector3(10, 0, 0),
                "hand_r": Vector3(-80, 0, 0), "chest": Vector3(-28, 0, 0), "spine": Vector3(-25, 0, 0),
                "thigh_l": Vector3(60, 0, 0), "shin_l": Vector3(-60, 0, 0), "thigh_r": Vector3(-30, 0, 0), "shin_r": Vector3(-35, 0, 0),
                "lift": Vector3(0, -0.22, 0)},
            {"arm_r": Vector3(40, 0, 5), "arm_l": Vector3(38, 0, -5), "fore_r": Vector3(5, 0, 0), "fore_l": Vector3(10, 0, 0),
                "hand_r": Vector3(-80, 0, 0), "chest": Vector3(-28, 0, 0), "spine": Vector3(-25, 0, 0),
                "thigh_l": Vector3(60, 0, 0), "shin_l": Vector3(-60, 0, 0), "thigh_r": Vector3(-30, 0, 0), "shin_r": Vector3(-35, 0, 0),
                "lift": Vector3(0, -0.22, 0)}],
    },
    "twinfangs": {
        "light_a": [{"arm_r": Vector3(30, 0, 15), "fore_r": Vector3(120, 0, 0), "hand_r": Vector3(-60, 0, 0), "chest": Vector3(0, -30, 0)},
            {"arm_r": Vector3(90, 0, 0), "fore_r": Vector3(0, 0, 0), "hand_r": Vector3(-90, 0, 0), "chest": Vector3(0, 20, 0), "lift": Vector3(0, -0.06, 0)},
            {"arm_r": Vector3(85, 15, 0), "fore_r": Vector3(10, 0, 0), "hand_r": Vector3(-85, 0, 0), "chest": Vector3(0, 15, 0)}],
        "light_b": [{"arm_l": Vector3(30, 0, -15), "fore_l": Vector3(120, 0, 0), "hand_l": Vector3(-60, 0, 0), "chest": Vector3(0, 30, 0)},
            {"arm_l": Vector3(90, 0, 0), "fore_l": Vector3(0, 0, 0), "hand_l": Vector3(-90, 0, 0), "chest": Vector3(0, -20, 0), "lift": Vector3(0, -0.06, 0)},
            {"arm_l": Vector3(85, -15, 0), "fore_l": Vector3(10, 0, 0), "hand_l": Vector3(-85, 0, 0), "chest": Vector3(0, -15, 0)}],
        "heavy": [{"arm_r": Vector3(60, -20, 70), "arm_l": Vector3(60, 20, -70), "fore_r": Vector3(10, 0, 0), "fore_l": Vector3(10, 0, 0),
                "hand_r": Vector3(-80, 0, 0), "hand_l": Vector3(-80, 0, 0), "body": Vector3(0, 60, 0), "lift": Vector3(0, -0.1, 0),
                "thigh_l": Vector3(30, 0, 0), "shin_l": Vector3(-40, 0, 0)},
            {"arm_r": Vector3(80, 0, 75), "arm_l": Vector3(80, 0, -75), "fore_r": Vector3(0, 0, 0), "fore_l": Vector3(0, 0, 0),
                "hand_r": Vector3(-90, 0, 0), "hand_l": Vector3(-90, 0, 0), "body": Vector3(0, -200, 0), "lift": Vector3(0, 0.05, 0)},
            {"arm_r": Vector3(70, 0, 50), "arm_l": Vector3(70, 0, -50), "fore_r": Vector3(10, 0, 0), "fore_l": Vector3(10, 0, 0),
                "hand_r": Vector3(-80, 0, 0), "hand_l": Vector3(-80, 0, 0), "body": Vector3(0, -360, 0), "lift": Vector3(0, -0.08, 0)}],
    },
}

static func stats(id: String) -> Dictionary:
    return STATS.get(id, STATS["fists"])

static func _mat(c: Color, metal := 0.0, rough := 0.6, kind := "metal") -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.albedo_texture = Tex.detail(kind)
    m.metallic = metal
    m.roughness = rough
    m.emission_enabled = true
    m.emission = Color.BLACK
    return m

## Builds a weapon. Returns {node, prims (2D raster primitives), tip, base, mats}.
## prims: [kind, a, b, radius, color] in weapon-local space.
static func build(id: String) -> Dictionary:
    var root := Node3D.new()
    var prims: Array = []
    var mats: Array = []
    var steel := _mat(Color(0.72, 0.73, 0.76), 0.95, 0.22)
    var dark := _mat(Color(0.12, 0.09, 0.07), 0.0, 0.8, "leather")
    var iron := _mat(Color(0.3, 0.29, 0.28), 0.8, 0.5)
    var wood := _mat(Color(0.3, 0.2, 0.12), 0.0, 0.85, "leather")
    var rust := _mat(Color(0.42, 0.28, 0.2), 0.6, 0.7)
    var pale := _mat(Color(0.78, 0.76, 0.7), 0.85, 0.3)
    mats = [steel, dark, iron, wood, rust, pale]
    var tip := Vector3(0, 1, 0)
    var base := Vector3(0, 0.2, 0)
    match id:
        "longsword":
            _cyl(root, prims, Vector3(0, -0.1, 0), Vector3(0, 0.1, 0), 0.022, dark)
            _sph(root, prims, Vector3(0, -0.12, 0), 0.032, iron)
            _box(root, prims, Vector3(0, 0.115, 0), Vector3(0.24, 0.035, 0.045), iron)
            _box(root, prims, Vector3(0, 0.6, 0), Vector3(0.055, 0.95, 0.014), steel)
            _box(root, prims, Vector3(0, 1.1, 0), Vector3(0.03, 0.1, 0.012), steel)
            tip = Vector3(0, 1.14, 0)
            base = Vector3(0, 0.25, 0)
        "greataxe":
            _cyl(root, prims, Vector3(0, -0.55, 0), Vector3(0, 0.95, 0), 0.03, wood)
            _box(root, prims, Vector3(0, 0.76, -0.15), Vector3(0.03, 0.4, 0.3), iron)
            _box(root, prims, Vector3(0, 0.76, -0.31), Vector3(0.025, 0.48, 0.06), steel)
            _box(root, prims, Vector3(0, 0.78, 0.09), Vector3(0.03, 0.08, 0.16), iron)
            _sph(root, prims, Vector3(0, 0.97, 0), 0.04, iron)
            tip = Vector3(0, 0.98, -0.34)
            base = Vector3(0, 0.55, -0.1)
        "twinfangs", "fang_l":
            _cyl(root, prims, Vector3(0, -0.07, 0), Vector3(0, 0.07, 0), 0.02, dark)
            _box(root, prims, Vector3(0, 0.085, 0), Vector3(0.12, 0.025, 0.03), iron)
            _box(root, prims, Vector3(0, 0.25, -0.01), Vector3(0.045, 0.32, 0.012), steel)
            var curve := _box(root, prims, Vector3(0, 0.44, -0.04), Vector3(0.035, 0.14, 0.011), steel)
            curve.rotation.x = deg_to_rad(-20)
            tip = Vector3(0, 0.5, -0.07)
            base = Vector3(0, 0.12, 0)
        "rusty_blade":
            _cyl(root, prims, Vector3(0, -0.08, 0), Vector3(0, 0.08, 0), 0.022, dark)
            _box(root, prims, Vector3(0, 0.095, 0), Vector3(0.16, 0.03, 0.04), rust)
            _box(root, prims, Vector3(0, 0.42, 0), Vector3(0.06, 0.62, 0.014), rust)
            var shard := _box(root, prims, Vector3(0.012, 0.76, 0), Vector3(0.035, 0.1, 0.013), rust)
            shard.rotation.z = deg_to_rad(25)
            tip = Vector3(0, 0.78, 0)
            base = Vector3(0, 0.2, 0)
        "great_club":
            var c := _cyl(root, prims, Vector3(0, -0.3, 0), Vector3(0, 1.0, 0), 0.07, wood)
            (c.mesh as CylinderMesh).top_radius = 0.13
            for k in 3:
                var band := _cyl(root, prims, Vector3(0, 0.45 + k * 0.2, 0), Vector3(0, 0.5 + k * 0.2, 0), 0.115 + k * 0.012, iron)
                band.name = "band%d" % k
            for k in 4:
                var a := k * PI / 2.0
                _sph(root, prims, Vector3(cos(a) * 0.12, 0.85, sin(a) * 0.12), 0.035, iron)
            tip = Vector3(0, 1.0, 0)
            base = Vector3(0, 0.4, 0)
        "warden_sword":
            _cyl(root, prims, Vector3(0, -0.3, 0), Vector3(0, 0.12, 0), 0.03, dark)
            _sph(root, prims, Vector3(0, -0.33, 0), 0.05, pale)
            _box(root, prims, Vector3(0, 0.14, 0), Vector3(0.42, 0.06, 0.07), pale)
            _box(root, prims, Vector3(0, 0.82, 0), Vector3(0.13, 1.35, 0.025), pale)
            var rune := _mat(Color(0.1, 0.1, 0.12), 0.5, 0.4)
            rune.emission = Color(0.55, 0.75, 1.0)
            rune.emission_energy_multiplier = 1.5
            rune.set_meta("rune", true)
            mats.append(rune)
            _box(root, prims, Vector3(0, 0.75, 0), Vector3(0.03, 1.05, 0.03), rune)
            tip = Vector3(0, 1.5, 0)
            base = Vector3(0, 0.35, 0)
        "cane":
            _cyl(root, prims, Vector3(0, -0.85, 0), Vector3(0, 0.15, 0), 0.02, wood)
            _sph(root, prims, Vector3(0, 0.17, 0), 0.04, iron)
            tip = Vector3(0, -0.85, 0)
            base = Vector3(0, 0, 0)
    return {"node": root, "prims": prims, "tip": tip, "base": base, "mats": mats}

static func _cyl(root: Node3D, prims: Array, a: Vector3, b: Vector3, r: float, m: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = r
    cm.bottom_radius = r
    cm.height = a.distance_to(b)
    cm.radial_segments = 10
    mi.mesh = cm
    mi.material_override = m
    mi.position = (a + b) * 0.5
    var d := (b - a).normalized()
    if absf(d.dot(Vector3.UP)) < 0.999:
        mi.basis = Basis(Quaternion(Vector3.UP, d))
    root.add_child(mi)
    prims.append(["seg", a, b, r, (m as StandardMaterial3D).albedo_color])
    return mi

static func _sph(root: Node3D, prims: Array, c: Vector3, r: float, m: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = 10
    sm.rings = 6
    mi.mesh = sm
    mi.material_override = m
    mi.position = c
    root.add_child(mi)
    prims.append(["seg", c, c, r, (m as StandardMaterial3D).albedo_color])
    return mi

static func _box(root: Node3D, prims: Array, c: Vector3, size: Vector3, m: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = m
    mi.position = c
    root.add_child(mi)
    var col := (m as StandardMaterial3D).albedo_color
    if m.has_meta("rune"):
        col = Color(0.55, 0.75, 1.0)
    # 2D: a capsule along the longest axis
    var ax := Vector3.UP
    var half := size.y * 0.5
    var r := (size.x + size.z) * 0.25
    if size.x >= size.y and size.x >= size.z:
        ax = Vector3.RIGHT
        half = size.x * 0.5
        r = (size.y + size.z) * 0.25
    elif size.z >= size.y and size.z >= size.x:
        ax = Vector3.BACK
        half = size.z * 0.5
        r = (size.x + size.y) * 0.25
    half = maxf(half - r, 0.0)
    prims.append(["seg", c - ax * half, c + ax * half, r, col])
    return mi
