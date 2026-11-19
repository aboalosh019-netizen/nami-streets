extends Node

enum GameState {
    MAIN_MENU,
    PLAYING,
    PAUSED
}

var current_state: GameState = GameState.MAIN_MENU


func change_state(new_state: GameState) -> void:
    if current_state == new_state:
        return

    current_state = new_state
    print("[GAME STATE] ", GameState.keys()[current_state])


func is_playing() -> bool:
    return current_state == GameState.PLAYING
