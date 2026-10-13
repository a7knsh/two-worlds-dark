class_name Visuals
extends RefCounted
## Procedural placeholder art so the project runs with zero imported assets.
## Every actor has TWO looks: a pixel sprite (exploration) and a 3D model (combat).
## Later you replace these with real pixel sprites and real character models.

static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
    for i in range(x, x + w):
        for j in range(y, y + h):
            img.set_pixel(i, j, c)

static func humanoid_texture(body: Color, accent: Color, skin: Color, weapon: Color) -> ImageTexture:
    var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var outline := Color(0.04, 0.03, 0.05)
    _rect(img, 5, 17, 3, 6, accent)
    _rect(img, 8, 17, 3, 6, accent)
    _rect(img, 5, 22, 3, 1, outline)
    _rect(img, 8, 22, 3, 1, outline)
    _rect(img, 4, 8, 8, 9, body)
    _rect(img, 4, 15, 8, 1, outline)
    _rect(img, 2, 9, 2, 7, body)
    _rect(img, 12, 9, 2, 7, body)
    _rect(img, 5, 2, 6, 6, body)
    _rect(img, 6, 4, 4, 3, skin)
    _rect(img, 7, 5, 1, 1, outline)
    _rect(img, 9, 5, 1, 1, outline)
    _rect(img, 14, 3, 1, 12, weapon)
    _rect(img, 13, 14, 3, 1, outline)
    return ImageTexture.create_from_image(img)

static func make_sprite(tex: Texture2D) -> Sprite3D:
    var s := Sprite3D.new()
    s.texture = tex
    s.pixel_size = 0.075
    s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    s.shaded = true
    s.position.y = 0.9
    return s

static func make_model(body_color: Color, height := 1.0) -> Dictionary:
    var root := Node3D.new()
    var mat := StandardMaterial3D.new()
    mat.albedo_color = body_color
    mat.metallic = 0.6
    mat.roughness = 0.45
    var body := MeshInstance3D.new()
    var cap := CapsuleMesh.new()
    cap.radius = 0.34
    cap.height = 1.5 * height
    body.mesh = cap
    body.material_override = mat
    body.position.y = 0.8 * height
    root.add_child(body)
    var head := MeshInstance3D.new()
    var sph := SphereMesh.new()
    sph.radius = 0.19
    sph.height = 0.38
    head.mesh = sph
    head.material_override = mat
    head.position.y = 1.65 * height
    root.add_child(head)
    var sword := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(0.07, 1.2, 0.03)
    sword.mesh = box
    var smat := StandardMaterial3D.new()
    smat.albedo_color = Color(0.8, 0.8, 0.85)
    smat.metallic = 1.0
    smat.roughness = 0.25
    sword.material_override = smat
    sword.position = Vector3(0.5, 1.0 * height, -0.35)
    sword.rotation.x = deg_to_rad(-35)
    root.add_child(sword)
    return {"node": root, "mat": mat}

static func capsule_collision() -> CollisionShape3D:
    var cs := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.35
    shape.height = 1.7
    cs.shape = shape
    cs.position.y = 0.85
    return cs
