class_name BikeUpgradeApplier
extends RefCounted

const UpgradeCatalogScript = preload("res://src/economy/upgrade_catalog.gd")
const BikeDrivetrainConfigScript = preload("res://src/bike/systems/bike_drivetrain_config.gd")
const BikePhysicsConfigScript = preload("res://src/bike/physics/bike_physics_config.gd")

const META_BASE_DRIVETRAIN: StringName = &"nami_base_drivetrain_config"
const META_BASE_PHYSICS: StringName = &"nami_base_physics_config"


static func apply_economy_state(bike: Node, economy_state: RefCounted) -> Dictionary:
    if bike == null or economy_state == null:
        return {}
    if not economy_state.has_method("get_active_modifiers"):
        return {}
    var mods: Dictionary = economy_state.get_active_modifiers()
    var applied: Dictionary = apply_modifiers(bike, mods)
    if "active_bike_id" in economy_state:
        _apply_visual_model(bike, str(economy_state.get("active_bike_id")))
    return applied


static func apply_bike_profile(bike: Node, bike_id: String, upgrade_levels: Dictionary = {}) -> Dictionary:
    var mods: Dictionary = UpgradeCatalogScript.get_effective_modifiers(bike_id, upgrade_levels)
    var applied: Dictionary = apply_modifiers(bike, mods)
    _apply_visual_model(bike, bike_id)
    return applied


static func apply_modifiers(bike: Node, mods: Dictionary) -> Dictionary:
    if bike == null or mods.is_empty():
        return {}

    var torque_mult: float = maxf(0.1, float(mods.get("torque_mult", 1.0)))
    var max_speed_mult: float = maxf(0.1, float(mods.get("max_speed_mult", 1.0)))
    var brake_mult: float = maxf(0.1, float(mods.get("brake_mult", 1.0)))
    var suspension_mult: float = maxf(0.1, float(mods.get("suspension_mult", 1.0)))
    var wheelie_mult: float = maxf(0.1, float(mods.get("wheelie_torque_mult", 1.0)))

    # 1. Apply physics & suspension upgrades on an isolated copy of the base config
    if "config" in bike:
        var base_phys: Resource = _get_or_store_base_physics(bike)
        var phys_cfg: Resource = base_phys.duplicate(true)
        var damp_mult: float = sqrt(suspension_mult)

        phys_cfg.set("front_stiffness", float(base_phys.get("front_stiffness")) * suspension_mult)
        phys_cfg.set("rear_stiffness", float(base_phys.get("rear_stiffness")) * suspension_mult)
        phys_cfg.set("front_compression_damping", float(base_phys.get("front_compression_damping")) * damp_mult)
        phys_cfg.set("rear_compression_damping", float(base_phys.get("rear_compression_damping")) * damp_mult)
        phys_cfg.set("front_rebound_damping", float(base_phys.get("front_rebound_damping")) * damp_mult)
        phys_cfg.set("rear_rebound_damping", float(base_phys.get("rear_rebound_damping")) * damp_mult)

        bike.set("config", phys_cfg)
        _sync_wheel_if_cached(bike.get("front_wheel"), phys_cfg, true)
        _sync_wheel_if_cached(bike.get("rear_wheel"), phys_cfg, false)

    # 2. Apply drivetrain, gearing, brakes & lean upgrades on an isolated copy
    var controller: Node = bike.get_node_or_null("BikeController")
    if controller != null:
        var base_dt: Resource = _get_or_store_base_drivetrain(controller)
        var dt_cfg: Resource = base_dt.duplicate(true)

        dt_cfg.set("base_drive_force", float(base_dt.get("base_drive_force")) * torque_mult)
        dt_cfg.set("rear_brake_force", float(base_dt.get("rear_brake_force")) * brake_mult)
        dt_cfg.set("front_brake_force", float(base_dt.get("front_brake_force")) * brake_mult)
        dt_cfg.set("lean_back_torque", float(base_dt.get("lean_back_torque")) * wheelie_mult)

        var base_speeds: PackedFloat32Array = base_dt.get("gear_max_speeds")
        var scaled_speeds := PackedFloat32Array()
        scaled_speeds.resize(base_speeds.size())
        for i in range(base_speeds.size()):
            scaled_speeds[i] = base_speeds[i] * max_speed_mult
        dt_cfg.set("gear_max_speeds", scaled_speeds)

        controller.set("drivetrain_config", dt_cfg)
        var drivetrain = controller.get("drivetrain")
        if drivetrain != null and drivetrain.has_method("configure"):
            var prev_gear: int = int(drivetrain.get("current_gear"))
            drivetrain.configure(dt_cfg)
            if drivetrain.has_method("set_gear"):
                drivetrain.set_gear(prev_gear)

    return mods.duplicate()


static func _get_or_store_base_physics(bike: Node) -> Resource:
    if bike.has_meta(META_BASE_PHYSICS):
        var stored = bike.get_meta(META_BASE_PHYSICS)
        if stored is Resource:
            return stored as Resource

    var current = bike.get("config")
    var base_copy: Resource = (current as Resource).duplicate(true) if current is Resource else BikePhysicsConfigScript.new()
    bike.set_meta(META_BASE_PHYSICS, base_copy)
    return base_copy


static func _get_or_store_base_drivetrain(controller: Node) -> Resource:
    if controller.has_meta(META_BASE_DRIVETRAIN):
        var stored = controller.get_meta(META_BASE_DRIVETRAIN)
        if stored is Resource:
            return stored as Resource

    var current = controller.get("drivetrain_config")
    var base_copy: Resource = (current as Resource).duplicate(true) if current is Resource else BikeDrivetrainConfigScript.new()
    controller.set_meta(META_BASE_DRIVETRAIN, base_copy)
    return base_copy


static func _sync_wheel_if_cached(wheel: Variant, phys_cfg: Resource, is_front: bool) -> void:
    if wheel == null or not (wheel is Object):
        return
    var prefix: String = "front_" if is_front else "rear_"
    if "stiffness" in wheel:
        wheel.set("stiffness", float(phys_cfg.get(prefix + "stiffness")))
    if "compression_damping" in wheel:
        wheel.set("compression_damping", float(phys_cfg.get(prefix + "compression_damping")))
    if "rebound_damping" in wheel:
        wheel.set("rebound_damping", float(phys_cfg.get(prefix + "rebound_damping")))

static func _apply_visual_model(bike: Node, bike_id: String) -> void:
    if bike == null or bike_id.is_empty():
        return
    var vis: Node = bike.get_node_or_null("BikeVisual")
    if vis != null and vis.has_method("set_bike_model"):
        vis.call("set_bike_model", bike_id)
