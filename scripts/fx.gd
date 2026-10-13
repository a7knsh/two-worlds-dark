class_name Fx
extends RefCounted
## One-shot visual effects. Everything frees itself.

static func _root() -> Node:
    return Engine.get_main_loop().current_scene

static func burst(pos: Vector3, color: Color, amount := 16, speed := 4.0, size := 0.07, life := 0.5,
        gravity := -9.0, spread := 180.0, dir := Vector3.UP) -> void:
    var p := CPUParticles3D.new()
    p.emitting = false
    p.one_shot = true
    p.explosiveness = 0.95
    p.amount = amount
    p.lifetime = life
    p.direction = dir
    p.spread = spread
    p.initial_velocity_min = speed * 0.4
    p.initial_velocity_max = speed
    p.gravity = Vector3(0, gravity, 0)
    p.scale_amount_min = 0.5
    p.scale_amount_max = 1.0
    var mesh := SphereMesh.new()
    mesh.radius = size
    mesh.height = size * 2.0
    mesh.radial_segments = 6
    mesh.rings = 3
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = color
    m.vertex_color_use_as_albedo = true
    mesh.material = m
    p.mesh = mesh
    var grad := Gradient.new()
    grad.set_color(0, color)
    grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
    p.color_ramp = grad
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _root().add_child(p)
    p.global_position = pos
    p.emitting = true
    p.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)

static func sparks(pos: Vector3) -> void:
    burst(pos, Color(1.0, 0.7, 0.3), 12, 6.0, 0.035, 0.35, -12.0)

static func blood(pos: Vector3, dir: Vector3) -> void:
    burst(pos, Color(0.4, 0.02, 0.02), 12, 4.0, 0.035, 0.55, -14.0, 50.0, (dir + Vector3.UP * 0.6).normalized())

static func ash(pos: Vector3, amount := 40, color := Color(0.75, 0.72, 0.68)) -> void:
    burst(pos, color, amount, 1.6, 0.05, 1.8, 0.8, 70.0)

static func heal(pos: Vector3) -> void:
    burst(pos, Color(1.0, 0.75, 0.4), 24, 1.8, 0.04, 1.0, 1.5, 40.0)

## Expanding flat ring on the ground (shockwaves, landing slams, the blood nova).
static func ring(pos: Vector3, radius: float, color: Color, dur := 0.5) -> void:
    var mi := MeshInstance3D.new()
    var tm := TorusMesh.new()
    tm.inner_radius = 0.85
    tm.outer_radius = 1.0
    tm.rings = 32
    tm.ring_segments = 6
    mi.mesh = tm
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.albedo_color = color
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _root().add_child(mi)
    mi.global_position = pos + Vector3(0, 0.08, 0)
    mi.scale = Vector3(0.2, 0.3, 0.2)
    var tw := mi.create_tween().set_parallel(true)
    tw.tween_property(mi, "scale", Vector3(radius, 0.3, radius), dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
    tw.tween_property(m, "albedo_color:a", 0.0, dur)
    tw.chain().tween_callback(mi.queue_free)

## A glowing disc that grows during a windup (telegraph for area attacks).
static func telegraph(parent: Node3D, radius: float, color: Color, dur: float) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = 1.0
    cm.bottom_radius = 1.0
    cm.height = 0.02
    cm.radial_segments = 32
    mi.mesh = cm
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    m.albedo_color = Color(color.r, color.g, color.b, 0.0)
    mi.material_override = m
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    mi.position = Vector3(0, 0.06, 0)
    mi.scale = Vector3(radius * 0.2, 1, radius * 0.2)
    var tw := mi.create_tween().set_parallel(true)
    tw.tween_property(mi, "scale", Vector3(radius, 1, radius), dur)
    tw.tween_property(m, "albedo_color:a", color.a, dur)
    tw.chain().tween_callback(mi.queue_free)
    return mi
