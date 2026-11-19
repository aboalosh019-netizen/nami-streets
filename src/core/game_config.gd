extends Node

const BASE_WIDTH: int = 640
const BASE_HEIGHT: int = 360

enum ControlMode {
    BASIC,
    PRO
}

var control_mode: ControlMode = ControlMode.BASIC
var debug_overlay_enabled: bool = true
