class_name Interactable
extends Node3D
## Anything the player can use with [E]: ground messages, lanterns, weapon altars,
## the fog wall, the Veilkeeper and the Sundered Gate. Main decides what each kind does.

signal activated(it: Interactable)

var kind := ""
var prompt := ""
var data := {}
var radius := 1.8
var enabled := true

static func make(p_kind: String, p_prompt: String, p_data := {}, p_radius := 1.8) -> Interactable:
    var it := Interactable.new()
    it.kind = p_kind
    it.prompt = p_prompt
    it.data = p_data
    it.radius = p_radius
    return it

func _ready() -> void:
    add_to_group("interactable")

func activate() -> void:
    activated.emit(self)
