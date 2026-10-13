class_name Foe
extends CharacterBody3D
## Shared interface for everything the player can hit and lock on to (enemies and the boss).

var hp := 1.0
var max_hp := 1.0
var hit_radius := 0.4
var hit_height := 1.0
var lock_height := 1.2

func is_alive() -> bool:
    return hp > 0.0

func lockable() -> bool:
    return is_alive()

func take_damage(_amount: float, _from: Node3D = null, _poise := 0.0) -> void:
    pass
