class_name Humanoid
extends Node3D
## A procedural, articulated character with two looks:
##   Flesh (combat): a jointed 3D model made of primitive meshes, animated per joint.
##   Veil (explore): a pixel-art sprite sheet, rasterised at startup FROM THE SAME RIG and poses,
##                   so both worlds always show the same animation.
##
## Joint conventions (model faces -Z, angles in degrees, Euler order YXZ):
##   arm/thigh  +X swings the limb forward (90 = pointing forward, 180 = straight up)
##   fore       +X bends the elbow,  shin -X bends the knee
##   spine/chest -X leans forward,  chest +Y twists to the left
##   arm_r +Z / arm_l -Z raises the arm out to the side
##   "lift" is a position offset of the whole body (metres, unscaled), "body" rotates the whole body
##   around its centre (rolls, spins, falling over).

const JOINTS := ["body", "hips", "spine", "chest", "neck", "head", "arm_l", "fore_l", "hand_l",
    "arm_r", "fore_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const POSE_KEYS := ["lift", "body", "hips", "spine", "chest", "neck", "head", "arm_l", "fore_l", "hand_l",
    "arm_r", "fore_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const COLS := 6
const HOLD := ["death", "lie", "kneel", "sit", "crawl_hold"]
const ROWS := {
    "hunter": ["idle", "walk", "roll", "p_light_a", "p_light_b", "p_heavy", "hurt", "death", "heal", "rise", "interact", "lie"],
    "husk": ["idle", "walk", "husk_swing", "husk_lunge", "hurt", "death", "rise"],
    "brute": ["idle", "walk", "brute_smash", "brute_sweep", "hurt", "stagger", "death"],
    "warden": ["idle", "walk", "kneel"],
    "keeper": ["sit"],
    "beast": ["idle"],
}

static var LIB := {}

var build := "hunter"
var s := 1.0
var weapon_id := ""
var offhand_id := ""
var rig: Node3D
var body: Node3D
var j := {}
var stance := {}
var sprite: Sprite3D
var rows: Array = []
var ppm := 18.0
var mats: Array = []
var weapon_mats: Array = []
var prims: Array = []
var weapon_node: Node3D
var offhand_node: Node3D
var tip_node: Node3D
var base_node: Node3D
var _body_base := Vector3.ZERO
var _hip_h := 0.95

var anim := "idle"
var anim_t := 0.0
var anim_dur := 1.0
var anim_speed := 1.0
var _from := {}
var _cur := {}
var _blend := 1.0
var _blend_time := 0.1
var _loco_w := 1.0
var move_speed := 0.0
var velocity := Vector3.ZERO
var face_yaw := 0.0
var _phase := 0.0
var _time := 0.0
var _cape := 0.0
var world_combat := false
var frozen := false

var trail_on := false
var trail_color := Color(0.8, 0.85, 1.0, 0.5)
var _trail: Array = []
var _trail_mesh: ImmediateMesh
var _trail_mi: MeshInstance3D

var flash_color := Color(1, 0.2, 0.1)
var _flash := 0.0
var glow_color := Color(1.0, 0.35, 0.1)
var glow_amount := 0.0
var _eye_mats: Array = []

# ------------------------------------------------------------------ construction

static func create(p_build: String, p_weapon := "", p_scale := 1.0, p_offhand := "") -> Humanoid:
    var h := Humanoid.new()
    h.build = p_build
    h.weapon_id = p_weapon
    h.offhand_id = p_offhand
    h.s = p_scale
    h._setup()
    return h

func _setup() -> void:
    _lib()
    rig = Node3D.new()
    rig.name = "Rig"
    rig.scale = Vector3(s, s, s)
    add_child(rig)
    match build:
        "hunter":
            _build_hunter()
        "husk":
            _build_husk(false)
        "beast":
            _build_husk(true)
        "brute":
            _build_brute()
        "warden":
            _build_warden()
        "keeper":
            _build_keeper()
    _equip_nodes()
    _trail_mesh = ImmediateMesh.new()
    _trail_mi = MeshInstance3D.new()
    _trail_mi.mesh = _trail_mesh
    _trail_mi.top_level = true
    _trail_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var tm := StandardMaterial3D.new()
    tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    tm.cull_mode = BaseMaterial3D.CULL_DISABLED
    tm.vertex_color_use_as_albedo = true
    _trail_mi.material_override = tm
    add_child(_trail_mi)
    ppm = 12.0 if s > 1.6 else 18.0
    rows = ROWS.get(build, ["idle"])
    sprite = Sprite3D.new()
    sprite.name = "Sprite"
    sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    sprite.shaded = true
    sprite.pixel_size = 1.0 / ppm
    sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(sprite)
    _make_sheet()
    _apply(_pose_now(0.0))

func _ready() -> void:
    var gs: Node = get_node("/root/GameState")
    gs.visual_mode_changed.connect(set_world)
    set_world(gs.visual_combat)

func set_world(combat: bool) -> void:
    world_combat = combat
    rig.visible = combat
    sprite.visible = not combat
    _trail_mi.visible = combat

## Swap the held weapon (player picks one at an altar). Regenerates the sprite sheet.
func set_weapon(id: String, offhand := "") -> void:
    if weapon_node:
        _remove_prims_of(weapon_node)
        weapon_node.queue_free()
        weapon_node = null
    if offhand_node:
        _remove_prims_of(offhand_node)
        offhand_node.queue_free()
        offhand_node = null
    weapon_id = id
    offhand_id = offhand
    stance = _base_stance()
    _equip_nodes()
    _make_sheet()

func _remove_prims_of(n: Node3D) -> void:
    prims = prims.filter(func(p: Array) -> bool: return p[0] != n)
    mats = mats.filter(func(m: StandardMaterial3D) -> bool: return not weapon_mats.has(m))

func _equip_nodes() -> void:
    weapon_mats.clear()
    tip_node = null
    base_node = null
    if weapon_id != "" and weapon_id != "fists":
        var w := Weapons.build(weapon_id)
        weapon_node = w["node"]
        weapon_node.rotation.x = deg_to_rad(-90)
        weapon_node.position = Vector3(0, -0.07, 0)
        j["hand_r"].add_child(weapon_node)
        for p: Array in w["prims"]:
            prims.append([weapon_node, p[1], p[2], p[3], p[4], false])
        tip_node = Node3D.new()
        tip_node.position = w["tip"]
        weapon_node.add_child(tip_node)
        base_node = Node3D.new()
        base_node.position = w["base"]
        weapon_node.add_child(base_node)
        for m: StandardMaterial3D in w["mats"]:
            if not m.has_meta("rune"):
                weapon_mats.append(m)
                mats.append(m)
    if offhand_id != "":
        var w2 := Weapons.build(offhand_id)
        offhand_node = w2["node"]
        offhand_node.rotation.x = deg_to_rad(-90)
        offhand_node.position = Vector3(0, -0.07, 0)
        j["hand_l"].add_child(offhand_node)
        for p: Array in w2["prims"]:
            prims.append([offhand_node, p[1], p[2], p[3], p[4], false])
        for m: StandardMaterial3D in w2["mats"]:
            weapon_mats.append(m)
            mats.append(m)
    stance = _base_stance()

# ------------------------------------------------------------------ geometry helpers

func _mat(c: Color, kind := "cloth", metal := 0.0, rough := 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.albedo_texture = Tex.detail(kind)
    m.metallic = metal
    m.roughness = rough
    m.emission_enabled = true
    m.emission = Color.BLACK
    mats.append(m)
    return m

func _glow_mat(c: Color, energy := 3.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.emission_enabled = true
    m.emission = c
    m.emission_energy_multiplier = energy
    _eye_mats.append(m)
    return m

func _joint(jname: String, parent: String, pos: Vector3) -> Node3D:
    var n := Node3D.new()
    n.name = jname
    n.position = pos
    (rig if parent == "" else j[parent] as Node3D).add_child(n)
    j[jname] = n
    return n

func _cap(jn: String, a: Vector3, b: Vector3, r: float, m: StandardMaterial3D) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CapsuleMesh.new()
    cm.radius = r
    cm.height = a.distance_to(b) + r * 2.0
    cm.radial_segments = 12
    cm.rings = 4
    mi.mesh = cm
    mi.material_override = m
    mi.position = (a + b) * 0.5
    var d := b - a
    if d.length() > 0.001 and absf(d.normalized().dot(Vector3.UP)) < 0.999:
        mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
    (j[jn] as Node3D).add_child(mi)
    prims.append([j[jn], a, b, r, m.albedo_color, false])
    return mi

func _cyl(jn: String, a: Vector3, b: Vector3, ra: float, rb: float, m: StandardMaterial3D, sides := 12) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.bottom_radius = ra
    cm.top_radius = rb
    cm.height = a.distance_to(b)
    cm.radial_segments = sides
    mi.mesh = cm
    mi.material_override = m
    mi.position = (a + b) * 0.5
    var d := b - a
    if absf(d.normalized().dot(Vector3.UP)) < 0.999:
        mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
    (j[jn] as Node3D).add_child(mi)
    var rr := (ra + rb) * 0.5
    var hgt := a.distance_to(b)
    if hgt < rr * 0.6:
        var mid := (a + b) * 0.5
        var th := maxf(hgt * 0.5, 0.025)
        prims.append([j[jn], mid - Vector3(rr - th, 0, 0), mid + Vector3(rr - th, 0, 0), th, m.albedo_color, false])
        prims.append([j[jn], mid - Vector3(0, 0, rr - th), mid + Vector3(0, 0, rr - th), th, m.albedo_color, false])
    else:
        prims.append([j[jn], a, b, rr, m.albedo_color, false])
    return mi

func _sph(jn: String, c: Vector3, r: float, m: StandardMaterial3D, sc := Vector3.ONE) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    sm.radial_segments = 14
    sm.rings = 8
    mi.mesh = sm
    mi.material_override = m
    mi.position = c
    mi.scale = sc
    (j[jn] as Node3D).add_child(mi)
    var ry := r * sc.y
    var rr := r * (sc.x + sc.z) * 0.5
    var half := maxf(ry - rr, 0.0)
    prims.append([j[jn], c - Vector3(0, half, 0), c + Vector3(0, half, 0), rr, m.albedo_color, false])
    return mi

func _box(jn: String, c: Vector3, size: Vector3, m: StandardMaterial3D, rot := Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = m
    mi.position = c
    mi.rotation_degrees = rot
    (j[jn] as Node3D).add_child(mi)
    var bas := Basis.from_euler(rot * (PI / 180.0))
    var ax := Vector3.UP
    var half := size.y * 0.5
    var r := (size.x + size.z) * 0.25
    if size.x > size.y and size.x >= size.z:
        ax = Vector3.RIGHT
        half = size.x * 0.5
        r = (size.y + size.z) * 0.25
    elif size.z > size.y and size.z > size.x:
        ax = Vector3.BACK
        half = size.z * 0.5
        r = (size.x + size.y) * 0.25
    ax = bas * ax
    half = maxf(half - r, 0.0)
    prims.append([j[jn], c - ax * half, c + ax * half, r, m.albedo_color, false])
    return mi

func _eye(jn: String, c: Vector3, r: float, col: Color) -> void:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = r
    sm.height = r * 2.0
    mi.mesh = sm
    mi.material_override = _glow_mat(col)
    mi.position = c
    (j[jn] as Node3D).add_child(mi)
    prims.append([j[jn], c, c, maxf(r, 0.035), col, true])

## Standard skeleton. w = limb thickness, al = arm length, ll = leg length.
func _skeleton(w: float, al: float, ll: float, sh: float, c: Dictionary) -> void:
    _hip_h = 0.1 + 0.85 * ll
    _body_base = Vector3(0, _hip_h - 0.35, 0)
    body = _joint("body", "", _body_base)
    _joint("hips", "body", Vector3(0, 0.35, 0))
    _joint("spine", "hips", Vector3(0, 0.1, 0))
    _joint("chest", "spine", Vector3(0, 0.2, 0))
    _joint("neck", "chest", Vector3(0, 0.25, 0))
    _joint("head", "neck", Vector3(0, 0.09, 0))
    for side in ["l", "r"]:
        var sx := -1.0 if side == "l" else 1.0
        _joint("arm_" + side, "chest", Vector3(sx * sh, 0.19, 0))
        _joint("fore_" + side, "arm_" + side, Vector3(0, -0.28 * al, 0))
        _joint("hand_" + side, "fore_" + side, Vector3(0, -0.26 * al, 0))
        _joint("thigh_" + side, "hips", Vector3(sx * 0.1 * maxf(w, 1.0), -0.02, 0))
        _joint("shin_" + side, "thigh_" + side, Vector3(0, -0.43 * ll, 0))
        _joint("foot_" + side, "shin_" + side, Vector3(0, -0.42 * ll, 0))
        _cap("arm_" + side, Vector3.ZERO, Vector3(0, -0.26 * al, 0), 0.062 * w, c["sleeve"])
        _cap("fore_" + side, Vector3.ZERO, Vector3(0, -0.24 * al, 0), 0.052 * w, c["sleeve"])
        _box("hand_" + side, Vector3(0, -0.05, 0), Vector3(0.075, 0.1, 0.06) * w, c["hand"])
        _cap("thigh_" + side, Vector3.ZERO, Vector3(0, -0.41 * ll, 0), 0.085 * w, c["legs"])
        _cap("shin_" + side, Vector3.ZERO, Vector3(0, -0.4 * ll, 0), 0.07 * w, c["boots"])
        _box("foot_" + side, Vector3(0, -0.04, -0.05), Vector3(0.11 * w, 0.08, 0.24), c["boots"])
    _sph("hips", Vector3(0, 0.0, 0), 0.15, c["torso"], Vector3(1.2 * w, 0.75, 0.85 * w))
    _cap("spine", Vector3(0, 0.0, 0), Vector3(0, 0.18, 0), 0.14 * w, c["torso"])
    _sph("chest", Vector3(0, 0.12, 0), 0.2, c["torso"], Vector3(1.15 * maxf(w, 0.85), 1.0, 0.8 * maxf(w, 0.85)))
    _cap("neck", Vector3.ZERO, Vector3(0, 0.08, 0), 0.055 * w, c["skin"])
    _sph("head", Vector3(0, 0.11, 0), 0.115, c["skin"], Vector3(0.95, 1.08, 1.0))

func _build_hunter() -> void:
    var c := {
        "torso": _mat(Color(0.13, 0.11, 0.1), "leather"),
        "sleeve": _mat(Color(0.12, 0.1, 0.09), "leather"),
        "hand": _mat(Color(0.07, 0.06, 0.05), "leather"),
        "legs": _mat(Color(0.1, 0.09, 0.09), "cloth"),
        "boots": _mat(Color(0.08, 0.065, 0.05), "leather"),
        "skin": _mat(Color(0.72, 0.6, 0.52), "skin"),
    }
    _skeleton(1.0, 1.0, 1.0, 0.21, c)
    var hat := _mat(Color(0.07, 0.065, 0.065), "leather")
    var scarf := _mat(Color(0.38, 0.06, 0.06), "cloth")
    var metal := _mat(Color(0.55, 0.53, 0.5), "metal", 0.85, 0.35)
    # tricorn-style hunter hat + scarf mask
    _cyl("head", Vector3(0, 0.17, 0), Vector3(0, 0.2, 0), 0.25, 0.24, hat, 16)
    _cyl("head", Vector3(0, 0.19, 0), Vector3(0, 0.33, 0), 0.13, 0.11, hat, 14)
    _box("head", Vector3(0, 0.045, -0.06), Vector3(0.21, 0.1, 0.1), scarf)
    _cap("neck", Vector3(-0.04, 0.02, 0.0), Vector3(0.04, 0.02, 0.0), 0.085, scarf)
    # long coat: chest plate, belt and two swinging tails
    _box("chest", Vector3(0, 0.05, -0.12), Vector3(0.3, 0.3, 0.04), c["torso"])
    _cyl("hips", Vector3(0, 0.0, 0), Vector3(0, 0.07, 0), 0.19, 0.19, _mat(Color(0.2, 0.14, 0.09), "leather"))
    _box("hips", Vector3(0, 0.035, -0.19), Vector3(0.07, 0.06, 0.02), metal)
    _joint("coat_f", "hips", Vector3(0, -0.02, -0.1))
    _joint("coat_b", "hips", Vector3(0, -0.02, 0.12))
    _box("coat_f", Vector3(0, -0.3, 0), Vector3(0.36, 0.58, 0.03), c["torso"])
    _box("coat_b", Vector3(0, -0.33, 0), Vector3(0.4, 0.64, 0.03), c["torso"])
    # shoulder mantle (cape)
    _joint("cape1", "chest", Vector3(0, 0.24, 0.12))
    _joint("cape2", "cape1", Vector3(0, -0.32, 0))
    _box("cape1", Vector3(0, -0.16, 0), Vector3(0.48, 0.34, 0.035), hat)
    _box("cape2", Vector3(0, -0.13, 0), Vector3(0.44, 0.28, 0.03), hat)
    _sph("arm_l", Vector3(0, -0.02, 0), 0.085, metal, Vector3(1.1, 0.8, 1.1))
    stance = _base_stance()

func _build_husk(beast: bool) -> void:
    var skin_col := Color(0.42, 0.42, 0.36) if not beast else Color(0.22, 0.05, 0.05)
    var c := {
        "torso": _mat(skin_col, "skin"),
        "sleeve": _mat(skin_col, "skin"),
        "hand": _mat(skin_col * 0.8, "skin"),
        "legs": _mat(Color(0.2, 0.18, 0.15), "cloth"),
        "boots": _mat(skin_col * 0.7, "skin"),
        "skin": _mat(skin_col, "skin"),
    }
    _skeleton(0.72, 1.35 if beast else 1.05, 1.0, 0.19, c)
    var rag := _mat(Color(0.24, 0.2, 0.16), "cloth")
    _joint("coat_f", "hips", Vector3(0, -0.02, -0.08))
    _joint("coat_b", "hips", Vector3(0, -0.02, 0.1))
    _box("coat_f", Vector3(0, -0.2, 0), Vector3(0.26, 0.4, 0.02), rag)
    _box("coat_b", Vector3(0, -0.22, 0), Vector3(0.3, 0.44, 0.02), rag)
    _box("chest", Vector3(0.05, 0.02, 0.0), Vector3(0.36, 0.22, 0.3), rag, Vector3(0, 0, 12))
    var eye := Color(1.0, 0.75, 0.3) if not beast else Color(1.0, 0.1, 0.05)
    _eye("head", Vector3(-0.045, 0.12, -0.1), 0.022, eye)
    _eye("head", Vector3(0.045, 0.12, -0.1), 0.022, eye)
    if beast:
        for side in ["l", "r"]:
            for k in 3:
                _box("hand_" + side, Vector3((k - 1) * 0.03, -0.14, -0.02), Vector3(0.018, 0.14, 0.018), c["hand"], Vector3(-15, 0, 0))
        for k in 5:
            _box("spine", Vector3(0, 0.05 + k * 0.08, 0.13), Vector3(0.03, 0.08, 0.06), c["hand"], Vector3(30, 0, 0))
    stance = _base_stance()

func _build_brute() -> void:
    var plate := _mat(Color(0.26, 0.24, 0.22), "metal", 0.7, 0.55)
    var c := {
        "torso": _mat(Color(0.2, 0.16, 0.13), "leather"),
        "sleeve": _mat(Color(0.35, 0.3, 0.27), "skin"),
        "hand": _mat(Color(0.16, 0.13, 0.1), "leather"),
        "legs": _mat(Color(0.15, 0.13, 0.11), "cloth"),
        "boots": plate,
        "skin": _mat(Color(0.35, 0.3, 0.27), "skin"),
    }
    _skeleton(1.55, 1.0, 0.95, 0.27, c)
    _sph("chest", Vector3(0, 0.12, -0.03), 0.23, plate, Vector3(1.35, 1.05, 0.95))
    _sph("arm_l", Vector3(-0.02, 0.0, 0), 0.13, plate, Vector3(1.2, 0.9, 1.2))
    _sph("arm_r", Vector3(0.02, 0.0, 0), 0.13, plate, Vector3(1.2, 0.9, 1.2))
    _cyl("head", Vector3(0, -0.02, 0), Vector3(0, 0.27, 0), 0.15, 0.14, plate, 12)
    _box("head", Vector3(0, 0.12, -0.14), Vector3(0.18, 0.025, 0.03), _glow_mat(Color(1.0, 0.45, 0.15), 2.0))
    prims.append([j["head"], Vector3(-0.07, 0.12, -0.14), Vector3(0.07, 0.12, -0.14), 0.02, Color(1.0, 0.45, 0.15), true])
    _joint("coat_f", "hips", Vector3(0, -0.02, -0.12))
    _joint("coat_b", "hips", Vector3(0, -0.02, 0.13))
    _box("coat_f", Vector3(0, -0.22, 0), Vector3(0.4, 0.42, 0.04), plate)
    _box("coat_b", Vector3(0, -0.24, 0), Vector3(0.44, 0.46, 0.04), c["torso"])
    stance = _base_stance()

func _build_warden() -> void:
    var bone := _mat(Color(0.7, 0.68, 0.64), "metal", 0.3, 0.5)
    var dark := _mat(Color(0.1, 0.09, 0.1), "cloth")
    var c := {
        "torso": bone,
        "sleeve": _mat(Color(0.18, 0.16, 0.17), "cloth"),
        "hand": bone,
        "legs": _mat(Color(0.14, 0.12, 0.13), "cloth"),
        "boots": bone,
        "skin": _mat(Color(0.2, 0.2, 0.22), "metal", 0.5, 0.5),
    }
    _skeleton(1.4, 1.05, 1.0, 0.25, c)
    _sph("chest", Vector3(0, 0.13, -0.02), 0.22, bone, Vector3(1.25, 1.0, 0.9))
    for side in ["l", "r"]:
        _cyl("fore_" + side, Vector3(0, -0.06, 0), Vector3(0, -0.22, 0), 0.085, 0.07, bone, 8)
        _cyl("shin_" + side, Vector3(0, -0.04, 0), Vector3(0, -0.3, 0), 0.11, 0.09, bone, 8)
    var core := _glow_mat(Color(0.55, 0.75, 1.0), 4.0)
    var core_mi := MeshInstance3D.new()
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 0.04
    core_mesh.height = 0.08
    core_mi.mesh = core_mesh
    core_mi.material_override = core
    core_mi.position = Vector3(0, 0.14, -0.185)
    (j["chest"] as Node3D).add_child(core_mi)
    prims.append([j["chest"], Vector3(0, 0.14, -0.2), Vector3(0, 0.14, -0.2), 0.05, Color(0.55, 0.75, 1.0), true])
    for side in ["l", "r"]:
        var sx := -1.0 if side == "l" else 1.0
        _sph("arm_" + side, Vector3(sx * 0.03, 0.0, 0), 0.12, bone, Vector3(1.3, 0.85, 1.25))
        _sph("arm_" + side, Vector3(sx * 0.06, 0.05, 0), 0.09, bone, Vector3(1.2, 0.7, 1.1))
    # great helm with a crown of horns
    _sph("head", Vector3(0, 0.12, 0), 0.135, bone, Vector3(1.0, 1.15, 1.05))
    _box("head", Vector3(0, 0.12, -0.135), Vector3(0.13, 0.014, 0.02), _glow_mat(Color(0.55, 0.75, 1.0), 3.0))
    prims.append([j["head"], Vector3(-0.06, 0.12, -0.14), Vector3(0.06, 0.12, -0.14), 0.018, Color(0.55, 0.75, 1.0), true])
    for k in 7:
        var a := deg_to_rad(-75.0 + k * 25.0)
        var base := Vector3(sin(a) * 0.12, 0.24, -cos(a) * 0.08)
        var top := base + Vector3(sin(a) * 0.08, 0.18 + 0.06 * float(k == 3), -cos(a) * 0.04)
        _cyl("head", base, top, 0.025, 0.004, bone, 6)
    # tassets and a long torn cape
    _joint("coat_f", "hips", Vector3(0, -0.02, -0.13))
    _joint("coat_b", "hips", Vector3(0, -0.02, 0.14))
    var cape := _mat(Color(0.2, 0.06, 0.06), "cloth")
    _box("coat_f", Vector3(0, -0.24, 0), Vector3(0.22, 0.5, 0.025), cape)
    _box("coat_f", Vector3(0, -0.06, -0.01), Vector3(0.36, 0.14, 0.04), bone)
    _box("coat_b", Vector3(0, -0.28, 0), Vector3(0.36, 0.56, 0.03), dark)
    for side in [-1.0, 1.0]:
        _box("hips", Vector3(side * 0.2, -0.12, 0), Vector3(0.05, 0.3, 0.26), bone, Vector3(0, 0, side * 12.0))
    _joint("cape1", "chest", Vector3(0, 0.26, 0.15))
    _joint("cape2", "cape1", Vector3(0, -0.5, 0))
    _joint("cape3", "cape2", Vector3(0, -0.5, 0))
    _box("cape1", Vector3(0, -0.25, 0), Vector3(0.44, 0.52, 0.025), cape)
    _box("cape2", Vector3(0, -0.25, 0), Vector3(0.4, 0.52, 0.025), cape)
    _box("cape3", Vector3(0.04, -0.18, 0), Vector3(0.3, 0.38, 0.025), cape)
    stance = _base_stance()

func _build_keeper() -> void:
    var robe := _mat(Color(0.12, 0.11, 0.13), "cloth")
    var c := {
        "torso": robe,
        "sleeve": robe,
        "hand": _mat(Color(0.55, 0.5, 0.45), "skin"),
        "legs": robe,
        "boots": _mat(Color(0.08, 0.07, 0.07), "leather"),
        "skin": _mat(Color(0.5, 0.45, 0.42), "skin"),
    }
    _skeleton(1.0, 1.0, 1.0, 0.2, c)
    var hood := _mat(Color(0.08, 0.075, 0.09), "cloth")
    _sph("head", Vector3(0, 0.13, 0.02), 0.155, hood, Vector3(1.0, 1.1, 1.15))
    _box("head", Vector3(0, 0.08, -0.13), Vector3(0.14, 0.16, 0.02), _mat(Color(0.02, 0.02, 0.02), "cloth"))
    _eye("head", Vector3(-0.035, 0.11, -0.14), 0.012, Color(0.7, 0.8, 1.0))
    _eye("head", Vector3(0.035, 0.11, -0.14), 0.012, Color(0.7, 0.8, 1.0))
    _joint("coat_f", "hips", Vector3(0, -0.02, -0.1))
    _joint("coat_b", "hips", Vector3(0, -0.02, 0.12))
    _box("coat_f", Vector3(0, -0.3, 0), Vector3(0.42, 0.62, 0.03), robe)
    _box("coat_b", Vector3(0, -0.3, 0), Vector3(0.44, 0.62, 0.03), robe)
    _joint("cape1", "chest", Vector3(0, 0.22, 0.13))
    _joint("cape2", "cape1", Vector3(0, -0.4, 0))
    _box("cape1", Vector3(0, -0.2, 0), Vector3(0.5, 0.42, 0.03), hood)
    _box("cape2", Vector3(0, -0.2, 0), Vector3(0.46, 0.42, 0.03), hood)
    stance = _base_stance()

func _base_stance() -> Dictionary:
    var st := {}
    match build:
        "hunter":
            st = {"spine": Vector3(-4, 0, 0), "thigh_l": Vector3(8, 0, -3), "shin_l": Vector3(-14, 0, 0),
                "thigh_r": Vector3(-4, 0, 3), "shin_r": Vector3(-8, 0, 0), "arm_l": Vector3(8, 0, -8), "fore_l": Vector3(15, 0, 0),
                "arm_r": Vector3(8, 0, 8), "fore_r": Vector3(15, 0, 0)}
        "husk", "beast":
            st = {"spine": Vector3(-22, 0, 0), "chest": Vector3(-14, 0, 6), "neck": Vector3(12, 0, 0), "head": Vector3(18, 0, -8),
                "arm_l": Vector3(18, 0, -6), "fore_l": Vector3(25, 0, 0), "arm_r": Vector3(25, 0, 10), "fore_r": Vector3(40, 0, 0),
                "hand_r": Vector3(-40, 0, 0), "thigh_l": Vector3(14, 0, -4), "shin_l": Vector3(-24, 0, 0),
                "thigh_r": Vector3(-6, 0, 4), "shin_r": Vector3(-16, 0, 0), "lift": Vector3(0, -0.04, 0)}
            if build == "beast":
                st["spine"] = Vector3(-45, 0, 0)
                st["arm_l"] = Vector3(40, 0, -10)
                st["arm_r"] = Vector3(40, 0, 10)
                st["fore_r"] = Vector3(30, 0, 0)
                st["hand_r"] = Vector3.ZERO
        "brute":
            st = {"thigh_l": Vector3(10, 0, -9), "shin_l": Vector3(-18, 0, 0), "thigh_r": Vector3(-4, 0, 9), "shin_r": Vector3(-12, 0, 0),
                "arm_l": Vector3(35, 25, -10), "fore_l": Vector3(50, 0, 0), "arm_r": Vector3(25, -10, 15), "fore_r": Vector3(55, 0, 0),
                "hand_r": Vector3(-30, 0, 0), "spine": Vector3(-8, 0, 0), "lift": Vector3(0, -0.03, 0)}
        "warden":
            st = {"thigh_l": Vector3(12, 0, -6), "shin_l": Vector3(-16, 0, 0), "thigh_r": Vector3(-6, 0, 6), "shin_r": Vector3(-10, 0, 0),
                "arm_r": Vector3(18, 0, 14), "fore_r": Vector3(30, 0, 0), "hand_r": Vector3(-40, 0, 0),
                "arm_l": Vector3(10, 0, -16), "fore_l": Vector3(20, 0, 0), "spine": Vector3(-6, 0, 0)}
        "keeper":
            st = {"spine": Vector3(-18, 0, 0), "head": Vector3(-10, 0, 0)}
    if build == "hunter" and Weapons.STANCE.has(weapon_id if weapon_id != "" else "fists"):
        var ws: Dictionary = Weapons.STANCE[weapon_id if weapon_id != "" else "fists"]
        for k: String in ws:
            st[k] = ws[k]
    return st

# ------------------------------------------------------------------ animation library

static func _lib() -> void:
    if not LIB.is_empty():
        return
    var Z := Vector3.ZERO
    LIB["idle"] = {"loop": true, "keys": [[0.0, {}], [1.0, {}]]}
    LIB["walk"] = {"loop": true, "keys": [[0.0, {}], [1.0, {}]]}
    LIB["roll"] = {"loop": false, "keys": [
        [0.0, {"body": Z, "lift": Vector3(0, -0.12, 0), "spine": Vector3(-30, 0, 0), "thigh_l": Vector3(40, 0, 0), "shin_l": Vector3(-60, 0, 0),
            "thigh_r": Vector3(30, 0, 0), "shin_r": Vector3(-60, 0, 0), "arm_l": Vector3(60, 0, -20), "arm_r": Vector3(60, 0, 20)}],
        [0.2, {"body": Vector3(-90, 0, 0), "lift": Vector3(0, -0.06, 0), "spine": Vector3(-50, 0, 0), "head": Vector3(-30, 0, 0),
            "thigh_l": Vector3(100, 0, 0), "shin_l": Vector3(-130, 0, 0), "thigh_r": Vector3(100, 0, 0), "shin_r": Vector3(-130, 0, 0),
            "arm_l": Vector3(100, 0, -20), "arm_r": Vector3(100, 0, 20), "fore_l": Vector3(90, 0, 0), "fore_r": Vector3(90, 0, 0)}],
        [0.5, {"body": Vector3(-220, 0, 0), "lift": Vector3(0, 0.02, 0), "spine": Vector3(-50, 0, 0), "head": Vector3(-30, 0, 0),
            "thigh_l": Vector3(110, 0, 0), "shin_l": Vector3(-135, 0, 0), "thigh_r": Vector3(110, 0, 0), "shin_r": Vector3(-135, 0, 0),
            "arm_l": Vector3(100, 0, -20), "arm_r": Vector3(100, 0, 20), "fore_l": Vector3(90, 0, 0), "fore_r": Vector3(90, 0, 0)}],
        [0.8, {"body": Vector3(-340, 0, 0), "lift": Vector3(0, -0.08, 0), "spine": Vector3(-25, 0, 0),
            "thigh_l": Vector3(70, 0, 0), "shin_l": Vector3(-100, 0, 0), "thigh_r": Vector3(40, 0, 0), "shin_r": Vector3(-80, 0, 0)}],
        [1.0, {"body": Vector3(-360, 0, 0), "lift": Vector3(0, -0.06, 0), "thigh_l": Vector3(25, 0, 0), "shin_l": Vector3(-40, 0, 0)}]]}
    LIB["hurt"] = {"loop": false, "keys": [[0.0, {}],
        [0.2, {"spine": Vector3(14, 0, 0), "chest": Vector3(14, 0, 10), "head": Vector3(22, 0, 0), "arm_l": Vector3(40, 0, -45),
            "fore_l": Vector3(30, 0, 0), "lift": Vector3(0, -0.04, 0), "thigh_r": Vector3(-20, 0, 0)}],
        [0.55, {"spine": Vector3(8, 0, 0), "chest": Vector3(6, 0, 4), "head": Vector3(10, 0, 0), "arm_l": Vector3(30, 0, -25)}],
        [1.0, {}]]}
    LIB["stagger"] = {"loop": false, "keys": [[0.0, {}],
        [0.15, {"spine": Vector3(22, 0, -8), "chest": Vector3(18, 15, 10), "head": Vector3(28, 0, 0), "arm_l": Vector3(70, 0, -70),
            "arm_r": Vector3(60, 0, 70), "fore_l": Vector3(20, 0, 0), "fore_r": Vector3(20, 0, 0), "lift": Vector3(0, -0.06, 0),
            "thigh_l": Vector3(-20, 0, 0), "thigh_r": Vector3(30, 0, 0), "shin_r": Vector3(-40, 0, 0)}],
        [0.5, {"spine": Vector3(-35, 0, 0), "chest": Vector3(-15, 0, 0), "head": Vector3(-20, 0, 0), "arm_l": Vector3(20, 0, -20),
            "arm_r": Vector3(15, 0, 20), "fore_r": Vector3(20, 0, 0), "hand_r": Vector3(-20, 0, 0), "lift": Vector3(0, -0.22, 0),
            "thigh_l": Vector3(70, 0, 0), "shin_l": Vector3(-90, 0, 0), "thigh_r": Vector3(10, 0, 0), "shin_r": Vector3(-80, 0, 0)}],
        [0.82, {"spine": Vector3(-35, 0, 0), "chest": Vector3(-15, 0, 0), "head": Vector3(-20, 0, 0), "arm_l": Vector3(20, 0, -20),
            "arm_r": Vector3(15, 0, 20), "fore_r": Vector3(20, 0, 0), "hand_r": Vector3(-20, 0, 0), "lift": Vector3(0, -0.22, 0),
            "thigh_l": Vector3(70, 0, 0), "shin_l": Vector3(-90, 0, 0), "thigh_r": Vector3(10, 0, 0), "shin_r": Vector3(-80, 0, 0)}],
        [1.0, {}]]}
    LIB["death"] = {"loop": false, "keys": [[0.0, {}],
        [0.3, {"spine": Vector3(-20, 0, 0), "chest": Vector3(10, 0, 8), "head": Vector3(-25, 0, 0), "thigh_l": Vector3(40, 0, 0),
            "shin_l": Vector3(-80, 0, 0), "thigh_r": Vector3(30, 0, 0), "shin_r": Vector3(-70, 0, 0), "lift": Vector3(0, -0.25, 0),
            "arm_l": Vector3(20, 0, -15), "arm_r": Vector3(25, 0, 15), "fore_r": Vector3(10, 0, 0), "hand_r": Vector3(-10, 0, 0)}],
        [0.7, {"body": Vector3(84, 0, 0), "spine": Vector3(5, 0, 0), "head": Vector3(10, 0, 15), "thigh_l": Vector3(15, 0, -8),
            "shin_l": Vector3(-20, 0, 0), "thigh_r": Vector3(5, 0, 8), "shin_r": Vector3(-10, 0, 0), "lift": Vector3(0, -0.47, 0),
            "arm_l": Vector3(120, 0, -40), "arm_r": Vector3(100, 0, 50), "fore_r": Vector3(10, 0, 0), "hand_r": Vector3(-10, 0, 0)}],
        [1.0, {"body": Vector3(88, 0, 0), "spine": Vector3(5, 0, 0), "head": Vector3(15, 0, 25), "thigh_l": Vector3(10, 0, -8),
            "shin_l": Vector3(-15, 0, 0), "thigh_r": Vector3(0, 0, 8), "shin_r": Vector3(-5, 0, 0), "lift": Vector3(0, -0.5, 0),
            "arm_l": Vector3(150, 0, -40), "arm_r": Vector3(110, 0, 55), "fore_r": Vector3(10, 0, 0), "hand_r": Vector3(-10, 0, 0)}]]}
    LIB["heal"] = {"loop": false, "keys": [[0.0, {}],
        [0.3, {"arm_l": Vector3(150, 25, -20), "fore_l": Vector3(120, 0, 0), "head": Vector3(28, 0, 0), "chest": Vector3(10, 0, 0)}],
        [0.72, {"arm_l": Vector3(150, 25, -20), "fore_l": Vector3(120, 0, 0), "head": Vector3(28, 0, 0), "chest": Vector3(10, 0, 0)}],
        [1.0, {}]]}
    var lie := {"body": Vector3(86, 0, 0), "lift": Vector3(0, -0.48, 0), "arm_l": Vector3(10, 0, -10), "arm_r": Vector3(10, 0, 10),
        "fore_l": Vector3(5, 0, 0), "fore_r": Vector3(5, 0, 0), "hand_r": Vector3(0, 0, 0), "thigh_l": Vector3(0, 0, 0),
        "shin_l": Vector3(0, 0, 0), "thigh_r": Vector3(0, 0, 0), "shin_r": Vector3(0, 0, 0), "head": Vector3(-5, 0, 0)}
    LIB["lie"] = {"loop": false, "keys": [[0.0, lie], [1.0, lie]]}
    var kneel := {"thigh_r": Vector3(90, 0, 6), "shin_r": Vector3(-90, 0, 0), "thigh_l": Vector3(-8, 0, -6), "shin_l": Vector3(-95, 0, 0),
        "lift": Vector3(0, -0.42, 0), "spine": Vector3(-20, 0, 0), "head": Vector3(-25, 0, 0), "arm_r": Vector3(40, 0, 6),
        "fore_r": Vector3(45, 0, 0), "hand_r": Vector3(-170, 0, 0), "arm_l": Vector3(45, 0, -5), "fore_l": Vector3(50, 0, 0)}
    LIB["kneel"] = {"loop": false, "keys": [[0.0, kneel], [1.0, kneel]]}
    LIB["rise"] = {"loop": false, "keys": [[0.0, lie],
        [0.35, {"body": Vector3(25, 0, 0), "lift": Vector3(0, -0.45, 0), "thigh_l": Vector3(95, 0, 0), "shin_l": Vector3(-150, 0, 0),
            "thigh_r": Vector3(80, 0, 0), "shin_r": Vector3(-90, 0, 0), "spine": Vector3(-25, 0, 0), "arm_r": Vector3(40, 0, 10),
            "arm_l": Vector3(40, 0, -10), "head": Vector3(-15, 0, 0)}],
        [0.7, kneel], [1.0, {}]]}
    LIB["interact"] = {"loop": false, "keys": [[0.0, {}],
        [0.4, {"arm_r": Vector3(75, 0, 0), "fore_r": Vector3(10, 0, 0), "hand_r": Vector3(-60, 0, 0), "spine": Vector3(-25, 0, 0),
            "lift": Vector3(0, -0.12, 0), "thigh_l": Vector3(40, 0, 0), "shin_l": Vector3(-50, 0, 0)}],
        [0.7, {"arm_r": Vector3(75, 0, 0), "fore_r": Vector3(10, 0, 0), "hand_r": Vector3(-60, 0, 0), "spine": Vector3(-25, 0, 0),
            "lift": Vector3(0, -0.12, 0), "thigh_l": Vector3(40, 0, 0), "shin_l": Vector3(-50, 0, 0)}],
        [1.0, {}]]}
    LIB["roar"] = {"loop": false, "keys": [[0.0, {}],
        [0.2, {"spine": Vector3(-28, 0, 0), "chest": Vector3(-10, 0, 0), "arm_r": Vector3(30, 0, 40), "arm_l": Vector3(30, 0, -40),
            "lift": Vector3(0, -0.12, 0), "head": Vector3(-20, 0, 0)}],
        [0.4, {"chest": Vector3(28, 0, 0), "spine": Vector3(12, 0, 0), "head": Vector3(32, 0, 0), "arm_r": Vector3(60, 0, 75),
            "arm_l": Vector3(60, 0, -75), "fore_r": Vector3(25, 0, 0), "fore_l": Vector3(25, 0, 0), "lift": Vector3(0, 0.02, 0)}],
        [0.85, {"chest": Vector3(30, 0, 0), "spine": Vector3(14, 0, 0), "head": Vector3(35, 0, 0), "arm_r": Vector3(65, 0, 80),
            "arm_l": Vector3(65, 0, -80), "fore_r": Vector3(30, 0, 0), "fore_l": Vector3(30, 0, 0), "lift": Vector3(0, 0.02, 0)}],
        [1.0, {}]]}
    var sit := {"thigh_l": Vector3(88, 0, -4), "shin_l": Vector3(-88, 0, 0), "thigh_r": Vector3(88, 0, 4), "shin_r": Vector3(-88, 0, 0),
        "lift": Vector3(0, -0.45, 0), "spine": Vector3(-16, 0, 0), "head": Vector3(-12, 0, 0), "arm_l": Vector3(45, 0, -8),
        "fore_l": Vector3(45, 0, 0), "arm_r": Vector3(35, 0, 8), "fore_r": Vector3(50, 0, 0)}
    LIB["sit"] = {"loop": false, "keys": [[0.0, sit], [1.0, sit]]}
    LIB["talk"] = {"loop": false, "keys": [[0.0, sit],
        [0.3, sit.merged({"head": Vector3(5, -10, 0), "arm_r": Vector3(70, 20, 20), "fore_r": Vector3(40, 0, 0)}, true)],
        [0.7, sit.merged({"head": Vector3(0, -10, 0), "arm_r": Vector3(65, 20, 20), "fore_r": Vector3(45, 0, 0)}, true)],
        [1.0, sit]]}
    var crawl := {"spine": Vector3(-65, 0, 0), "chest": Vector3(-15, 0, 0), "head": Vector3(55, 0, 0), "arm_r": Vector3(95, 0, 15),
        "arm_l": Vector3(95, 0, -15), "fore_r": Vector3(10, 0, 0), "fore_l": Vector3(10, 0, 0), "thigh_l": Vector3(70, 0, -10),
        "shin_l": Vector3(-110, 0, 0), "thigh_r": Vector3(50, 0, 10), "shin_r": Vector3(-100, 0, 0), "lift": Vector3(0, -0.45, 0)}
    LIB["crawl"] = {"loop": true, "keys": [[0.0, crawl],
        [0.5, crawl.merged({"arm_r": Vector3(70, 0, 15), "arm_l": Vector3(115, 0, -15), "chest": Vector3(-15, 12, 0)}, true)],
        [1.0, crawl]]}
    LIB["reach"] = {"loop": false, "keys": [[0.0, crawl],
        [0.6, {"spine": Vector3(-30, 0, 0), "head": Vector3(25, 0, 0), "arm_r": Vector3(115, 0, 5), "fore_r": Vector3(5, 0, 0),
            "arm_l": Vector3(60, 0, -20), "lift": Vector3(0, -0.15, 0), "thigh_l": Vector3(40, 0, 0), "shin_l": Vector3(-60, 0, 0)}],
        [1.0, {"spine": Vector3(-25, 0, 0), "head": Vector3(25, 0, 0), "arm_r": Vector3(118, 0, 5), "fore_r": Vector3(0, 0, 0),
            "arm_l": Vector3(70, 0, -20), "lift": Vector3(0, -0.1, 0), "thigh_l": Vector3(40, 0, 0), "shin_l": Vector3(-60, 0, 0)}]]}
    LIB["crawl_hold"] = {"loop": false, "keys": [[0.0, crawl], [1.0, crawl]]}

## Build a timed attack animation from [windup, strike, follow] poses. f = moment of impact (0..1).
static func make_attack(aname: String, poses: Array, f: float) -> void:
    _lib()
    var follow: Dictionary = poses[2]
    LIB[aname] = {"loop": false, "keys": [
        [0.0, {}], [f * 0.72, poses[0]], [f, poses[1]], [f + (1.0 - f) * 0.3, follow], [f + (1.0 - f) * 0.62, follow], [1.0, {}]]}

## Arbitrary keyed animation: keys = [[t, pose], ...]
static func make_anim(aname: String, keys: Array, loop := false) -> void:
    _lib()
    LIB[aname] = {"loop": loop, "keys": keys}

# ------------------------------------------------------------------ playback

func play(aname: String, dur := 1.0, blend := 0.1) -> void:
    if not LIB.has(aname):
        aname = "idle"
    # remove full turns so a finished roll/spin does not unwind
    if _cur.has("body"):
        var b: Vector3 = _cur["body"]
        _cur["body"] = Vector3(wrapf(b.x, -180, 180), wrapf(b.y, -180, 180), wrapf(b.z, -180, 180))
    _from = _cur.duplicate()
    _blend = 0.0 if blend > 0.0 else 1.0
    _blend_time = maxf(blend, 0.001)
    anim = aname
    anim_t = 0.0
    anim_dur = maxf(dur, 0.01)

func is_loop() -> bool:
    return LIB[anim]["loop"]

func anim_progress() -> float:
    return clampf(anim_t / anim_dur, 0.0, 1.0)

func _sample(aname: String, t: float) -> Dictionary:
    var keys: Array = LIB[aname]["keys"]
    var i := 0
    while i < keys.size() - 2 and t > keys[i + 1][0]:
        i += 1
    var ka: Array = keys[i]
    var kb: Array = keys[mini(i + 1, keys.size() - 1)]
    var span: float = kb[0] - ka[0]
    var w := 1.0 if span <= 0.0001 else clampf((t - ka[0]) / span, 0.0, 1.0)
    w = w * w * (3.0 - 2.0 * w)
    var pa: Dictionary = ka[1]
    var pb: Dictionary = kb[1]
    var out := {}
    for k: String in POSE_KEYS:
        var base: Vector3 = stance.get(k, Vector3.ZERO)
        var va: Vector3 = pa.get(k, base)
        var vb: Vector3 = pb.get(k, base)
        out[k] = va.lerp(vb, w)
    return out

func _pose_now(delta: float) -> Dictionary:
    var t := anim_t / anim_dur
    if LIB[anim]["loop"]:
        t = fposmod(t, 1.0)
    else:
        t = minf(t, 1.0)
    var pose := _sample(anim, t)
    # locomotion + breathing layer
    var loco_target := 1.0 if anim == "idle" or anim == "walk" else 0.0
    _loco_w = move_toward(_loco_w, loco_target, delta * 8.0)
    var amt := clampf(move_speed / (3.2 * s), 0.0, 1.5) * _loco_w
    if amt > 0.01:
        _add_loco(pose, _phase, amt)
    var br := sin(_time * 1.7) * _loco_w
    pose["chest"] = pose["chest"] + Vector3(br * 1.8, 0, 0)
    pose["arm_l"] = pose["arm_l"] + Vector3(0, 0, -absf(br) * 2.0)
    if _blend < 1.0:
        var w := _blend * _blend * (3.0 - 2.0 * _blend)
        for k: String in POSE_KEYS:
            if _from.has(k):
                pose[k] = (_from[k] as Vector3).lerp(pose[k], w)
    return pose

func _add_loco(pose: Dictionary, ph: float, a: float) -> void:
    var sn := sin(ph)
    var cs := cos(ph)
    pose["thigh_l"] += Vector3(32.0 * a * sn, 0, 0)
    pose["thigh_r"] += Vector3(-32.0 * a * sn, 0, 0)
    pose["shin_l"] += Vector3(-(45.0 * maxf(0.0, cs) + 6.0) * a, 0, 0)
    pose["shin_r"] += Vector3(-(45.0 * maxf(0.0, -cs) + 6.0) * a, 0, 0)
    pose["arm_l"] += Vector3(-24.0 * a * sn, 0, 0)
    pose["arm_r"] += Vector3(10.0 * a * sn, 0, 0)
    pose["chest"] += Vector3(0, 7.0 * a * sn, 0)
    pose["spine"] += Vector3(-7.0 * a, 0, 0)
    pose["lift"] += Vector3(0, 0.035 * a * (absf(cs) - 0.6), 0)

func _apply(pose: Dictionary) -> void:
    _cur = pose
    for k: String in JOINTS:
        (j[k] as Node3D).rotation = (pose[k] as Vector3) * (PI / 180.0)
    body.position = _body_base + (pose["lift"] as Vector3)
    _apply_panels(pose)

func _apply_panels(pose: Dictionary) -> void:
    var tl: float = (pose["thigh_l"] as Vector3).x
    var tr: float = (pose["thigh_r"] as Vector3).x
    if j.has("coat_f"):
        (j["coat_f"] as Node3D).rotation.x = deg_to_rad(maxf(0.0, maxf(tl, tr)) * 0.85)
        (j["coat_b"] as Node3D).rotation.x = deg_to_rad(minf(0.0, minf(tl, tr)) * 0.85 - 4.0)
    if j.has("cape1"):
        var flare := -(10.0 + _cape)
        (j["cape1"] as Node3D).rotation.x = deg_to_rad(flare - (pose["chest"] as Vector3).x - (pose["spine"] as Vector3).x)
        (j["cape2"] as Node3D).rotation.x = deg_to_rad(-6.0 - _cape * 0.4 + sin(_time * 2.3) * 3.0)
        if j.has("cape3"):
            (j["cape3"] as Node3D).rotation.x = deg_to_rad(-4.0 - _cape * 0.3 + sin(_time * 2.9 + 1.0) * 4.0)

func _process(delta: float) -> void:
    if frozen:
        return
    _time += delta
    anim_t += delta * anim_speed
    if _blend < 1.0:
        _blend = minf(1.0, _blend + delta / _blend_time)
    if not LIB[anim]["loop"] and anim_t >= anim_dur and not HOLD.has(anim):
        play("idle", 1.0, 0.15)
    var stride := 1.7 * s
    _phase = fposmod(_phase + delta * TAU * move_speed / stride, TAU)
    var hv := Vector2(velocity.x, velocity.z).length()
    _cape = lerpf(_cape, clampf(hv / 6.0, 0.0, 1.0) * 45.0, 1.0 - exp(-4.0 * delta))
    rig.rotation.y = face_yaw
    _apply(_pose_now(delta))
    _update_fx(delta)
    if not world_combat:
        _update_sprite()

func _update_fx(delta: float) -> void:
    if _flash > 0.0 or glow_amount > 0.0 or _flash_was_on:
        _flash = maxf(0.0, _flash - delta * 4.0)
        var em := flash_color * _flash
        for m: StandardMaterial3D in mats:
            m.emission = em
        var gem := em + glow_color * glow_amount * 2.0
        for m: StandardMaterial3D in weapon_mats:
            m.emission = gem
        sprite.modulate = Color.WHITE.lerp(flash_color, _flash * 0.8).lerp(glow_color, glow_amount * 0.55)
        _flash_was_on = _flash > 0.0 or glow_amount > 0.0
    # weapon trail
    if trail_on and tip_node != null and world_combat:
        _trail.append([base_node.global_position, tip_node.global_position, _time])
    while _trail.size() > 0 and _time - (_trail[0][2] as float) > 0.13:
        _trail.pop_front()
    _trail_mesh.clear_surfaces()
    if _trail.size() >= 2:
        _trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
        for p: Array in _trail:
            var age := clampf((_time - (p[2] as float)) / 0.13, 0.0, 1.0)
            var c := trail_color
            c.a *= (1.0 - age)
            _trail_mesh.surface_set_color(c)
            _trail_mesh.surface_add_vertex(p[0])
            _trail_mesh.surface_set_color(c)
            _trail_mesh.surface_add_vertex(p[1])
        _trail_mesh.surface_end()

var _flash_was_on := false

func flash(c := Color(1, 0.2, 0.1), strength := 1.0) -> void:
    flash_color = c
    _flash = strength
    _flash_was_on = true

func set_eye_color(c: Color) -> void:
    for m: StandardMaterial3D in _eye_mats:
        m.albedo_color = c
        m.emission = c

func _update_sprite() -> void:
    var row := rows.find(anim)
    var col := 0
    if anim == "idle" or anim == "walk" or row < 0:
        if move_speed > 0.3 and rows.has("walk"):
            row = rows.find("walk")
            col = int(_phase / TAU * COLS) % COLS
        else:
            row = maxi(rows.find("idle"), 0)
            if not rows.has("idle"):
                row = 0
            col = int(_time * 3.0) % COLS
    else:
        var t := anim_progress()
        if LIB[anim]["loop"]:
            t = fposmod(anim_t / anim_dur, 1.0)
        col = mini(int(t * COLS), COLS - 1)
    sprite.frame = clampi(row * COLS + col, 0, sprite.hframes * sprite.vframes - 1)
    var cam := get_viewport().get_camera_3d()
    if cam:
        var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
        var side := fwd.dot(cam.global_transform.basis.x)
        if side < -0.15:
            sprite.flip_h = true
        elif side > 0.15:
            sprite.flip_h = false

# ------------------------------------------------------------------ pixel sprite generation

func _make_sheet() -> void:
    var gs: Node = Engine.get_main_loop().root.get_node("GameState")
    var key := "sheet_%s_%s_%s_%.2f" % [build, weapon_id, offhand_id, s]
    var fw := int(ceilf(3.6 * s * ppm))
    var fh := int(ceilf(3.3 * s * ppm))
    var tex: ImageTexture
    if gs.cache.has(key):
        tex = gs.cache[key]
    else:
        var atlas := Image.create(fw * COLS, fh * rows.size(), false, Image.FORMAT_RGBA8)
        atlas.fill(Color(0, 0, 0, 0))
        var saved_anim := anim
        for r in rows.size():
            var rname: String = rows[r]
            for c in COLS:
                var pose: Dictionary
                if rname == "walk":
                    pose = _sample("idle", 0.0)
                    _add_loco(pose, float(c) / COLS * TAU, 1.0)
                elif rname == "idle":
                    pose = _sample("idle", 0.0)
                    pose["chest"] = pose["chest"] + Vector3(sin(float(c) / COLS * TAU) * 3.0, 0, 0)
                    pose["lift"] = pose["lift"] + Vector3(0, sin(float(c) / COLS * TAU) * 0.012, 0)
                else:
                    var aname := rname if LIB.has(rname) else "idle"
                    pose = _sample(aname, (float(c) + 0.5) / COLS)
                _apply(pose)
                var frame := _raster(fw, fh)
                atlas.blit_rect(frame, Rect2i(0, 0, fw, fh), Vector2i(c * fw, r * fh))
        anim = saved_anim
        tex = ImageTexture.create_from_image(atlas)
        gs.cache[key] = tex
    sprite.texture = tex
    sprite.hframes = COLS
    sprite.vframes = rows.size()
    sprite.position.y = (fh * 0.5 - 3.0) / ppm

func _xf(n: Node3D) -> Transform3D:
    var t := n.transform
    var p := n.get_parent()
    while p != rig and p != null:
        t = (p as Node3D).transform * t
        p = p.get_parent()
    return t

func _raster(fw: int, fh: int) -> Image:
    var view := Basis(Vector3.RIGHT, deg_to_rad(14.0)) * Basis(Vector3.UP, deg_to_rad(-70.0))
    var ox := fw * 0.5
    var oy := fh - 3.0
    var k := s * ppm
    var n := fw * fh
    var colbuf := PackedColorArray()
    colbuf.resize(n)
    colbuf.fill(Color(0, 0, 0, 0))
    var zbuf := PackedFloat32Array()
    zbuf.resize(n)
    zbuf.fill(-1e9)
    var xf_cache := {}
    for p: Array in prims:
        var node: Node3D = p[0]
        if not node.is_inside_tree() and node.get_parent() == null:
            continue
        var t: Transform3D
        if xf_cache.has(node):
            t = xf_cache[node]
        else:
            t = _xf(node)
            xf_cache[node] = t
        var a3 := view * (t * (p[1] as Vector3))
        var b3 := view * (t * (p[2] as Vector3))
        var r: float = maxf((p[3] as float) * k, 0.55)
        var glow: bool = p[5]
        var base_c: Color = p[4]
        var ax := ox + a3.x * k
        var ay := oy - a3.y * k
        var bx := ox + b3.x * k
        var by := oy - b3.y * k
        var dx := bx - ax
        var dy := by - ay
        var len2 := dx * dx + dy * dy
        var x0 := maxi(int(floorf(minf(ax, bx) - r)), 0)
        var x1 := mini(int(ceilf(maxf(ax, bx) + r)), fw - 1)
        var y0 := maxi(int(floorf(minf(ay, by) - r)), 0)
        var y1 := mini(int(ceilf(maxf(ay, by) + r)), fh - 1)
        var r2 := r * r
        var depth_shade := clampf(0.86 + (a3.z + b3.z) * 0.5 * 0.5, 0.62, 1.08)
        for y in range(y0, y1 + 1):
            var py := y + 0.5
            for x in range(x0, x1 + 1):
                var px := x + 0.5
                var tt := 0.0
                if len2 > 0.0001:
                    tt = clampf(((px - ax) * dx + (py - ay) * dy) / len2, 0.0, 1.0)
                var qx := ax + dx * tt
                var qy := ay + dy * tt
                var ex := px - qx
                var ey := py - qy
                var d2 := ex * ex + ey * ey
                if d2 > r2:
                    continue
                var z := lerpf(a3.z, b3.z, tt) + sqrt(r2 - d2) / k + (0.08 if glow else 0.0)
                var idx := y * fw + x
                if z <= zbuf[idx]:
                    continue
                zbuf[idx] = z
                if glow:
                    colbuf[idx] = Color(base_c.r, base_c.g, base_c.b, 1.0)
                else:
                    var lit := depth_shade * (0.9 - 0.22 * ey / r - 0.08 * ex / r) * 1.55
                    colbuf[idx] = Color(base_c.r * lit + 0.035, base_c.g * lit + 0.035, base_c.b * lit + 0.045, 1.0)
    # outline + inner depth edges
    var img := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
    var outline := Color(0.025, 0.02, 0.035, 1.0)
    for y in fh:
        for x in fw:
            var idx := y * fw + x
            var c := colbuf[idx]
            if c.a > 0.0:
                var z := zbuf[idx]
                var edge := false
                if x > 0 and colbuf[idx - 1].a > 0.0 and zbuf[idx - 1] - z > 0.14:
                    edge = true
                elif x < fw - 1 and colbuf[idx + 1].a > 0.0 and zbuf[idx + 1] - z > 0.14:
                    edge = true
                elif y > 0 and colbuf[idx - fw].a > 0.0 and zbuf[idx - fw] - z > 0.14:
                    edge = true
                elif y < fh - 1 and colbuf[idx + fw].a > 0.0 and zbuf[idx + fw] - z > 0.14:
                    edge = true
                if edge:
                    c = c.darkened(0.55)
                # rim highlight on the top edge of the silhouette
                if y > 0 and colbuf[idx - fw].a == 0.0:
                    c = c.lightened(0.18)
                img.set_pixel(x, y, c)
            else:
                if (x > 0 and colbuf[idx - 1].a > 0.0) or (x < fw - 1 and colbuf[idx + 1].a > 0.0) \
                        or (y > 0 and colbuf[idx - fw].a > 0.0) or (y < fh - 1 and colbuf[idx + fw].a > 0.0):
                    img.set_pixel(x, y, outline)
    return img
