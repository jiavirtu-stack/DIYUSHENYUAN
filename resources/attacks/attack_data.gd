extends Resource
class_name AttackData

@export var display_name := "轻斩"
@export_range(0.0, 1.0, 0.01) var windup := 0.16
@export_range(0.03, 0.5, 0.01) var active_duration := 0.10
@export_range(0.05, 1.0, 0.01) var recovery := 0.27
@export_range(1.0, 80.0, 0.5) var damage := 12.0
@export_range(0.4, 3.0, 0.05) var reach := 1.25
@export_range(0.2, 1.2, 0.05) var hit_radius := 0.58
@export_range(0.0, 14.0, 0.1) var knockback := 3.2
@export_range(0.0, 1.0, 0.01) var combo_buffer_open := 0.30
@export_range(0.0, 1.5, 0.01) var combo_buffer_close := 0.48
@export_range(0.0, 1.5, 0.01) var dodge_cancel_open := 0.30


func total_duration() -> float:
	return windup + active_duration + recovery
