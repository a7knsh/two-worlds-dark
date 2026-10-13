class_name Level
extends RefCounted
## Builds the tutorial area in code. One 3D world; both camera looks render it.

static func _noise_texture(base: Color, variance: float, size := 32) -> ImageTexture:
    var rng := RandomNumberGenerator.new()
    rng.seed = 1234
    var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
    for x in size:
        for y in size:
            var v := 1.0 + rng.randf_range(-variance, variance)
            img.set_pixel(x, y, Color(base.r * v, base.g * v, base.b * v, 1.0))
    return ImageTexture.create_from_image(img)

static func _mat(base: Color, uv_scale: float, roughness := 0.95) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_texture = _noise_texture(base, 0.16, 64)
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
    m.roughness = roughness
    return m

static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.position = pos
    var cs := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    cs.shape = shape
    body.add_child(cs)
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    body.add_child(mi)
    parent.add_child(body)
    return body

static func _torch(parent: Node3D, pos: Vector3) -> void:
    var l := OmniLight3D.new()
    l.position = pos
    l.light_color = Color(1.0, 0.62, 0.3)
    l.light_energy = 2.2
    l.omni_range = 9.0
    l.shadow_enabled = false
    parent.add_child(l)
    var post := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 0.06
    cm.bottom_radius = 0.08
    cm.height = pos.y
    post.mesh = cm
    post.position = Vector3(pos.x, pos.y * 0.5, pos.z)
    var pm := StandardMaterial3D.new()
    pm.albedo_color = Color(0.2, 0.12, 0.07)
    post.material_override = pm
    parent.add_child(post)

static func build(parent: Node3D) -> Dictionary:
    # --- environment: dark, foggy, moonlit ---
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.02, 0.025, 0.04)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.3, 0.34, 0.5)
    env.ambient_light_energy = 0.9
    env.fog_enabled = true
    env.fog_light_color = Color(0.07, 0.08, 0.11)
    env.fog_density = 0.014
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled = true
    var we := WorldEnvironment.new()
    we.environment = env
    parent.add_child(we)

    var moon := DirectionalLight3D.new()
    moon.rotation = Vector3(deg_to_rad(-52), deg_to_rad(28), 0)
    moon.light_color = Color(0.55, 0.65, 1.0)
    moon.light_energy = 0.9
    moon.shadow_enabled = true
    parent.add_child(moon)

    # --- ground + perimeter ---
    var ground_mat := _mat(Color(0.26, 0.27, 0.23), 0.35)
    var wall_mat := _mat(Color(0.3, 0.29, 0.3), 0.3)
    _box(parent, Vector3(0, -0.5, -10), Vector3(50, 1, 60), ground_mat)
    _box(parent, Vector3(-25.5, 2, -10), Vector3(1, 5, 60), wall_mat)
    _box(parent, Vector3(25.5, 2, -10), Vector3(1, 5, 60), wall_mat)
    _box(parent, Vector3(0, 2, 20.5), Vector3(52, 5, 1), wall_mat)
    _box(parent, Vector3(0, 2, -40.5), Vector3(52, 5, 1), wall_mat)

    # --- ruins / pillars / gravestones ---
    var stone := _mat(Color(0.36, 0.36, 0.38), 0.5)
    for p: Vector3 in [Vector3(-6, 1.5, 5), Vector3(6, 1.5, 5), Vector3(-6, 1.5, -4), Vector3(6, 1.5, -4),
            Vector3(-12, 1.5, -14), Vector3(12, 1.5, -14), Vector3(0, 1.5, -22)]:
        _box(parent, p, Vector3(1.4, 3.0, 1.4), stone)
    for p: Vector3 in [Vector3(-10, 0.5, 10), Vector3(-8, 0.5, 12), Vector3(9, 0.5, 11), Vector3(14, 0.5, 2),
            Vector3(-15, 0.5, -6), Vector3(16, 0.5, -20)]:
        _box(parent, p, Vector3(0.8, 1.0, 0.25), stone)

    # --- torches ---
    for p: Vector3 in [Vector3(-6, 2.6, 5), Vector3(6, 2.6, 5), Vector3(-6, 2.6, -4), Vector3(6, 2.6, -4)]:
        _torch(parent, p + Vector3(0.0, 0.0, 1.0))

    return {
        "player_start": Vector3(0, 0.1, 15),
        "enemy_spawns": [Vector3(0, 0.1, -8), Vector3(10, 0.1, -16)],
    }
