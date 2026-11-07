extends Node3D

const JOBS := ["전사", "성기사", "암살자", "마법사", "궁수"]
const DAMAGE := [18, 14, 23, 20, 16]
var job := 0
var level := 1
var xp := 0
var hp := 100
var max_hp := 100
var damage := 18
var player: CharacterBody3D
var enemies: Array[CharacterBody3D] = []
var move_dir := Vector2.ZERO
var cooldown := 0.0
var status: Label
var notice: Label

func _ready() -> void:
    _make_world()
    _make_player()
    _make_ui()
    for i in range(4):
        _spawn_enemy(Vector3(randf_range(-7, 7), 0.65, randf_range(-7, 7)))
    _refresh()

func _make_world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.025, 0.02, 0.04)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.5, 0.45, 0.6)
    env.ambient_light_energy = 0.8
    world.environment = env
    add_child(world)
    var floor := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(24, 24)
    floor.mesh = plane
    var stone := StandardMaterial3D.new()
    stone.albedo_color = Color(0.13, 0.12, 0.16)
    floor.material_override = stone
    add_child(floor)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.1
    add_child(sun)
    var camera := Camera3D.new()
    camera.position = Vector3(0, 13, 11)
    camera.rotation_degrees = Vector3(-48, 0, 0)
    camera.current = true
    add_child(camera)
    for i in range(4):
        _wall(Vector3(-9 + i * 6, 1, -10), Vector3(6, 2, 0.5))
        _wall(Vector3(-9 + i * 6, 1, 10), Vector3(6, 2, 0.5))
        _wall(Vector3(-10, 1, -9 + i * 6), Vector3(0.5, 2, 6))
        _wall(Vector3(10, 1, -9 + i * 6), Vector3(0.5, 2, 6))

func _wall(pos: Vector3, size: Vector3) -> void:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.2, 0.17, 0.23)
    node.material_override = mat
    add_child(node)

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0, 0.8, 0)
    var mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.42
    capsule.height = 1.6
    mesh.mesh = capsule
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.15, 0.55, 0.95)
    mesh.material_override = mat
    player.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.42
    shape.height = 1.6
    collision.shape = shape
    player.add_child(collision)
    add_child(player)

func _make_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(12, 12)
    panel.custom_minimum_size = Vector2(360, 100)
    layer.add_child(panel)
    status = Label.new()
    status.add_theme_font_size_override("font_size", 20)
    panel.add_child(status)
    notice = Label.new()
    notice.position = Vector2(400, 18)
    notice.add_theme_font_size_override("font_size", 22)
    layer.add_child(notice)
    var jobs := HBoxContainer.new()
    jobs.position = Vector2(12, 125)
    layer.add_child(jobs)
    for i in range(JOBS.size()):
        var b := Button.new()
        b.text = JOBS[i]
        b.pressed.connect(_choose_job.bind(i))
        jobs.add_child(b)
    var controls := HBoxContainer.new()
    controls.position = Vector2(12, 600)
    layer.add_child(controls)
    var dirs := [["↑", Vector2(0, -1)], ["←", Vector2(-1, 0)], ["↓", Vector2(0, 1)], ["→", Vector2(1, 0)]]
    for item in dirs:
        var b := Button.new()
        b.text = item[0]
        b.custom_minimum_size = Vector2(68, 68)
        b.button_down.connect(_start_move.bind(item[1]))
        b.button_up.connect(_end_move)
        controls.add_child(b)
    var hit := Button.new()
    hit.text = "공격"
    hit.custom_minimum_size = Vector2(100, 68)
    hit.pressed.connect(_attack)
    controls.add_child(hit)
    var heal := Button.new()
    heal.text = "물약"
    heal.custom_minimum_size = Vector2(90, 68)
    heal.pressed.connect(_potion)
    controls.add_child(heal)

func _choose_job(index: int) -> void:
    job = index
    damage = DAMAGE[index]
    notice.text = JOBS[index] + " 선택!"

func _start_move(dir: Vector2) -> void:
    move_dir = dir

func _end_move() -> void:
    move_dir = Vector2.ZERO

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    player.velocity.x = move_dir.x * 5.0
    player.velocity.z = move_dir.y * 5.0
    player.move_and_slide()
    cooldown = maxf(0.0, cooldown - delta)
    for enemy in enemies:
        if is_instance_valid(enemy):
            var direction := player.global_position - enemy.global_position
            direction.y = 0
            if direction.length() > 1.35:
                enemy.position += direction.normalized() * delta * 1.25
            elif randf() < delta * 0.4:
                hp = maxi(0, hp - 3)
                _refresh()

func _attack() -> void:
    if cooldown > 0.0:
        return
    cooldown = 0.5
    var target: CharacterBody3D = null
    var nearest := 2.8
    for enemy in enemies:
        if is_instance_valid(enemy):
            var d := player.global_position.distance_to(enemy.global_position)
            if d < nearest:
                nearest = d
                target = enemy
    if target == null:
        notice.text = "몬스터가 공격 범위 밖에 있습니다."
        return
    target.set_meta("hp", int(target.get_meta("hp")) - damage)
    if int(target.get_meta("hp")) <= 0:
        enemies.erase(target)
        target.queue_free()
        xp += 25
        if xp >= level * 50:
            xp = 0
            level += 1
            max_hp += 10
            hp = max_hp
            damage += 3
            notice.text = "레벨 업! Lv." + str(level)
        else:
            notice.text = "몬스터 처치! 경험치 +25"
        _refresh()

func _potion() -> void:
    hp = mini(max_hp, hp + 35)
    _refresh()
    notice.text = "생명력을 회복했습니다."

func _spawn_enemy(pos: Vector3) -> void:
    var enemy := CharacterBody3D.new()
    enemy.position = pos
    enemy.set_meta("hp", 35)
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.55
    sphere.height = 1.1
    mesh.mesh = sphere
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.8, 0.12, 0.16)
    mesh.material_override = mat
    enemy.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.55
    collision.shape = shape
    enemy.add_child(collision)
    add_child(enemy)
    enemies.append(enemy)

func _refresh() -> void:
    if is_instance_valid(status):
        status.text = "경환이가만든게임\n직업: " + JOBS[job] + "  Lv." + str(level) + "\nHP " + str(hp) + "/" + str(max_hp) + "   공격력 " + str(damage) + "   XP " + str(xp)
