class_name ArtFX
extends RefCounted

const GLOW_PX := 128

static var _glow_texture: ImageTexture
static var _additive: CanvasItemMaterial

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

## 性能：替代逐实例 ShaderMaterial 的闪光叠层。
## 逐实例 ShaderMaterial 会让每个敌人都成为唯一材质 → Compatibility 下必然断批，
## 且每帧 set_shader_parameter 也是纯浪费。这里改用「共享 additive 材质 + 同纹理叠层」：
## 所有叠层共用 ArtFX.additive_material() 与同一张纹理，可合批；不闪时 visible=false 完全不参与绘制。
static func add_flash_overlay(art: Sprite2D, texture: Texture2D) -> Sprite2D:
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.material = additive_material()
    sprite.z_index = 0
    sprite.z_as_relative = true
    sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
    sprite.visible = false
    art.add_child(sprite)
    return sprite

## 驱动叠层闪光；alpha <= 0 时彻底隐藏，避免每帧提交一个透明 quad。
static func drive_flash_overlay(overlay: Sprite2D, strength: float, peak := 0.75) -> void:
    if overlay == null:
        return
    if strength > 0.001:
        overlay.visible = true
        overlay.modulate.a = clampf(strength, 0.0, 1.0) * peak
    elif overlay.visible:
        overlay.modulate.a = 0.0
        overlay.visible = false

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
