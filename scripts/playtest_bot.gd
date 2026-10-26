extends Node

var main = null
var player = null
var joystick = null
var orbit_angle := 0.0
var stages: Array = ["1-1", "2-1", "3-4"]
var runs_per_stage := 3
var results: Array = []

func _ready() -> void:
    main = get_parent()
    player = main.player
    joystick = get_tree().get_first_node_in_group("virtual_joystick")
    Engine.time_scale = 3.0
    call_deferred("_run_all")

func _process(delta: float) -> void:
    if main == null or player == null or joystick == null:
        return
    if main.menu_open or main.shop_open or main.game_over or main.stage_clear:
        return
    if not main.wave_active:
        return
    _steer(delta)

func _steer(delta: float) -> void:
    var position: Vector2 = player.global_position
    var repulsion := Vector2.ZERO
    var nearest_distance := 99999.0
    for enemy in main.enemies.get_children():
        if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
            continue
        var offset: Vector2 = position - enemy.global_position
        var distance := offset.length()
        if distance < nearest_distance:
            nearest_distance = distance
        if distance > 1.0 and distance < 260.0:
            repulsion += offset.normalized() * (1.0 - distance / 260.0)

    orbit_angle += delta * 0.8
    var target := Vector2(640.0, 360.0) + Vector2.from_angle(orbit_angle) * 270.0
    var orbit_direction := (target - position).normalized()
    var direction := orbit_direction * 0.55 + repulsion * 1.3

    if position.x < 100.0:
        direction.x += 1.0
    elif position.x > 1180.0:
        direction.x -= 1.0
    if position.y < 100.0:
        direction.y += 1.0
    elif position.y > 620.0:
        direction.y -= 1.0

    if direction.length_squared() < 0.01:
        direction = orbit_direction
    direction = direction.normalized()
    joystick.set_test_vector(direction)
    if nearest_distance < 105.0 and player.can_dash():
        player.try_dash()

func _run_all() -> void:
    await get_tree().process_frame
    for stage_index in range(stages.size()):
        for run_index in range(runs_per_stage):
            var stage_id := str(stages[stage_index])
            var run_seed := 20261026 + stage_index * 100 + run_index
            seed(run_seed)
            orbit_angle = 0.0
            joystick.set_test_vector(Vector2.ZERO)
            print("PLAYTEST_START stage=%s run=%d seed=%d" % [stage_id, run_index + 1, run_seed])
            main._begin_run(stage_id, false)
            await get_tree().process_frame
            await get_tree().process_frame
            var result := ""
            while result == "":
                if main.stage_clear:
                    result = "clear"
                elif main.game_over:
                    result = "death"
                elif main.shop_open:
                    _handle_shop(stage_id, run_index)
                    if main.shop_open:
                        main._on_next_wave()
                await get_tree().process_frame
            _record_result(stage_id, run_index, result)
    _print_summary()
    DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
    Engine.time_scale = 1.0
    get_tree().quit(0)

func _handle_shop(stage_id: String, run_index: int) -> void:
    var offers_text := _offers_text()
    var buys: Array = []
    for _attempt in range(8):
        var best := _best_offer_index()
        if best < 0:
            break
        var offer: Dictionary = main.shop_offers[best]
        var before_gold: int = main.gold
        var before_build: String = main.weapon_manager.get_build_signature()
        main._on_buy_offer(best)
        if main.gold == before_gold and main.weapon_manager.get_build_signature() == before_build:
            break
        buys.append("%s:%d" % [str(offer["id"]), int(offer["quality"])])

    if buys.is_empty() and (int(main.shop_free_rerolls) > 0 or main.gold >= 8):
        main._on_reroll_shop()
        var best_after := _best_offer_index()
        if best_after >= 0:
            var offer_after: Dictionary = main.shop_offers[best_after]
            var before_gold_after: int = main.gold
            var before_build_after: String = main.weapon_manager.get_build_signature()
            main._on_buy_offer(best_after)
            if main.gold != before_gold_after or main.weapon_manager.get_build_signature() != before_build_after:
                buys.append("%s:%d" % [str(offer_after["id"]), int(offer_after["quality"])])

    print("PLAYTEST_WAVE stage=%s run=%d wave=%d hp=%d/%d gold=%d kills=%d build=%s offers=%s buys=%s" % [
        stage_id,
        run_index + 1,
        main.wave,
        main.player.health,
        main.player.max_health,
        main.gold,
        main.total_kills,
        main.weapon_manager.get_build_signature(),
        offers_text,
        ",".join(buys),
    ])

func _offers_text() -> String:
    var parts: Array = []
    for offer in main.shop_offers:
        var mark := "*" if bool(offer.get("bought", false)) else ""
        parts.append("%s:%d%s" % [str(offer.get("id", "")), int(offer.get("quality", 1)), mark])
    return ",".join(parts)

func _best_offer_index() -> int:
    var best := -1
    var best_score := -1.0
    var weapon_count := 0
    for slot in main.weapon_manager.get_weapon_slots():
        if not slot.is_empty():
            weapon_count += 1
    var health_ratio := float(main.player.health) / float(maxi(1, main.player.max_health))
    for index in range(main.shop_offers.size()):
        var offer: Dictionary = main.shop_offers[index]
        if bool(offer.get("bought", false)):
            continue
        var price := int(offer.get("price", 0))
        if main.gold < price:
            continue
        var kind := str(offer.get("kind", "weapon"))
        var item_id := str(offer.get("id", ""))
        var quality := int(offer.get("quality", 1))
        var owned := 0
        if kind == "weapon":
            if not main.weapon_manager.can_buy_weapon(item_id, quality):
                continue
            owned = main.weapon_manager.get_weapon_quality(item_id)
        else:
            if not main.weapon_manager.can_buy_item(item_id, quality):
                continue
            owned = main.weapon_manager.get_item_quality(item_id)

        var final_quality := quality
        if owned > 0:
            if quality == owned:
                final_quality = mini(4, owned + 1)
            elif quality > owned:
                final_quality = quality

        var health_emergency := item_id == "holy_fire" and health_ratio < 0.6
        if kind == "item" and weapon_count < 5 and not health_emergency:
            if main.gold - price < 18:
                continue

        var score := 0.0
        if kind == "weapon":
            if owned > 0:
                score = 100.0 + float(final_quality) * 15.0 - float(price) * 0.5
            else:
                score = 70.0 + float(final_quality) * 10.0 - float(price) * 0.25
                if weapon_count < 4:
                    score += 65.0
            if item_id in ["vigil", "justice", "maple", "peony"]:
                score += 5.0
        else:
            if owned > 0:
                score = 45.0 + float(final_quality) * 8.0 - float(price) * 0.3
            else:
                score = 30.0 + float(final_quality) * 6.0 - float(price) * 0.2
            if item_id in ["jade", "lucky_cat", "anvil"]:
                score += 6.0
            elif item_id == "holy_fire":
                score += 3.0
        if health_emergency:
            score += 90.0 if health_ratio < 0.35 else 55.0
        if final_quality == 4:
            score += 12.0
        if score > best_score:
            best_score = score
            best = index
    return best

func _record_result(stage_id: String, run_index: int, result: String) -> void:
    var data := {
        "stage": stage_id,
        "run": run_index + 1,
        "result": result,
        "wave": main.wave,
        "gold": main.gold,
        "kills": main.total_kills,
        "hp": main.player.health,
        "max_hp": main.player.max_health,
        "build": main.weapon_manager.get_build_signature(),
    }
    results.append(data)
    print("PLAYTEST_RESULT stage=%s run=%d result=%s wave=%d gold=%d kills=%d hp=%d/%d build=%s" % [
        stage_id,
        run_index + 1,
        result,
        main.wave,
        main.gold,
        main.total_kills,
        main.player.health,
        main.player.max_health,
        main.weapon_manager.get_build_signature(),
    ])

func _print_summary() -> void:
    for stage_id in stages:
        var count := 0
        var clears := 0
        var wave_sum := 0
        var gold_sum := 0
        var kills_sum := 0
        for data in results:
            if str(data["stage"]) != str(stage_id):
                continue
            count += 1
            wave_sum += int(data["wave"])
            gold_sum += int(data["gold"])
            kills_sum += int(data["kills"])
            if str(data["result"]) == "clear":
                clears += 1
        if count == 0:
            continue
        print("PLAYTEST_SUMMARY stage=%s runs=%d clears=%d avg_wave=%.1f avg_gold=%.0f avg_kills=%.0f" % [
            str(stage_id),
            count,
            clears,
            float(wave_sum) / float(count),
            float(gold_sum) / float(count),
            float(kills_sum) / float(count),
        ])
    print("PLAYTEST_DONE")
