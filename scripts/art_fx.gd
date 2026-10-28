class_name ArtFX
extends RefCounted

const GLOW_PX := 128

static var _glow_texture: ImageTexture
static var _additive: CanvasItemMaterial
static var _flash_shader: Shader

static func glow_texture() -> ImageTexture:
    if _glow_texture == null:
        var image := Image.create(GLOW_PX, GLOW_PX, false, Image.FORMAT_RGBA8)
        image.fill(Color(1.0, 1.0, 1.0, 0.0))
        var center := Vector2(GLOW_PX, GLOW_PX) * 0.5
        for y in range(GLOW_PX):
            for x in range(GLOW_PX):
                var distance := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center) / (float(GLOW_PX) * 0.5)
                var alpha := pow(clampf(1.0 - distance, 0.0, 1.0), 2.4)
                image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
        _glow_texture = ImageTexture.create_from_image(image)
    return _glow_texture

static func additive_material() -> CanvasItemMaterial:
    if _additive == null:
        _additive = CanvasItemMaterial.new()
        _additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
    return _additive

static func flash_material() -> ShaderMaterial:
    if _flash_shader == null:
        _flash_shader = load("res://shaders/sprite_flash.gdshader")
    var material := ShaderMaterial.new()
    material.shader = _flash_shader
    material.set_shader_parameter("flash", 0.0)
    return material

static func add_glow(parent: Node2D, color: Color, radius: float, intensity: float, depth := 0) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.texture = glow_texture()
    sprite.material = additive_material()
    sprite.modulate = Color(color.r, color.g, color.b, intensity)
    sprite.scale = Vector2.ONE * (radius * 2.0 / float(GLOW_PX))
    sprite.z_index = depth
    sprite.z_as_relative = true
    parent.add_child(sprite)
    return sprite

static func add_shadow(parent: Node2D, width: float, height: float, offset_y: float, alpha: float) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.texture = glow_texture()
    sprite.modulate = Color(0.0, 0.0, 0.0, alpha)
    sprite.scale = Vector2(width / float(GLOW_PX), height / float(GLOW_PX))
    sprite.position = Vector2(0.0, offset_y)
    sprite.z_index = -4
    sprite.z_as_relative = true
    parent.add_child(sprite)
    return sprite

static func flash_at(parent: Node, position: Vector2, color: Color, radius: float, life := 0.14) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var sprite := Sprite2D.new()
    sprite.texture = glow_texture()
    sprite.material = additive_material()
    sprite.modulate = Color(color.r, color.g, color.b, 0.85)
    sprite.scale = Vector2.ONE * (radius * 2.0 / float(GLOW_PX))
    sprite.z_index = 60
    parent.add_child(sprite)
    sprite.global_position = position
    var tween := parent.create_tween()
    tween.set_parallel(true)
    tween.tween_property(sprite, "scale", sprite.scale * 1.7, life)
    tween.tween_property(sprite, "modulate:a", 0.0, life)
    tween.finished.connect(sprite.queue_free)

static func trail_at(parent: Node, position: Vector2, color: Color, radius: float, life := 0.18) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var sprite := Sprite2D.new()
    sprite.texture = glow_texture()
    sprite.material = additive_material()
    sprite.modulate = Color(color.r, color.g, color.b, 0.5)
    sprite.scale = Vector2.ONE * (radius * 2.0 / float(GLOW_PX))
    sprite.z_index = 40
    parent.add_child(sprite)
    sprite.global_position = position
    var tween := parent.create_tween()
    tween.set_parallel(true)
    tween.tween_property(sprite, "scale", sprite.scale * 0.4, life)
    tween.tween_property(sprite, "modulate:a", 0.0, life)
    tween.finished.connect(sprite.queue_free)

static func afterimage(parent: Node, texture: Texture2D, position: Vector2, rotation: float, scale: float, color: Color, life := 0.26) -> void:
    if parent == null or not parent.is_inside_tree() or texture == null:
        return
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.material = additive_material()
    sprite.modulate = color
    sprite.rotation = rotation
    sprite.scale = Vector2.ONE * scale
    sprite.z_index = 2
    parent.add_child(sprite)
    sprite.global_position = position
    var tween := parent.create_tween()
    tween.tween_property(sprite, "modulate:a", 0.0, life)
    tween.finished.connect(sprite.queue_free)
