class_name NetworkConfig
extends Resource

# Mobile/slow connections (56k era!)
# Standard home internet (~10 Mbps)
# LAN/fiber, esports-grade (128 tick)
enum NetworkPreset { CUSTOM, LOW_BANDWIDTH, BROADBAND, COMPETITIVE }

@export_group("Server")
@export_range(10, 128, 1, "suffix:Hz", "or_greater") var server_tick_rate: int = 60
@export_range(1, 100) var max_players: int = 16
@export var enable_interest_management: bool = true
@export_range(10.0, 200.0, 5.0, "suffix:m") var relevancy_radius: float = 100.0
@export_group("Bandwidth")
@export_range(10, 128, 1, "suffix:Hz") var client_update_rate: int = 30
@export_range(10, 128, 1, "suffix:Hz") var input_send_rate: int = 60
@export var enable_delta_compression: bool = true
@export var enable_quantization: bool = true
@export_range(8, 16, 1, "suffix:bits") var position_precision_bits: int = 16
@export_range(8, 12, 1, "suffix:bits") var rotation_precision_bits: int = 10
@export_group("Prediction")
@export var enable_client_prediction: bool = true
@export_range(0.001, 0.1, 0.001, "suffix:m") var prediction_error_threshold: float = 0.01
@export_range(1, 100) var max_pending_inputs: int = 30  # ~500ms at 60Hz input
@export_group("Interpolation")
@export_range(0.01, 0.5, 0.01, "suffix:sec") var interpolation_delay: float = 0.1
@export var adaptive_buffering: bool = true
@export_range(0.0, 0.5, 0.01, "suffix:sec") var extrapolation_limit: float = 0.25
@export_range(5.0, 30.0, 1.0) var interpolation_speed: float = 15.0
@export_group("Lag Compensation")
@export var enable_lag_compensation: bool = true
@export_range(0.1, 2.0, 0.1, "suffix:sec") var lag_comp_history_duration: float = 1.0
@export var lag_comp_hitscan_only: bool = true
@export_range(64, 256, 1) var max_snapshot_history: int = 128
@export_group("Anti-Cheat")
@export_range(1.0, 3.0, 0.1) var max_speed_tolerance: float = 1.5
@export_range(0.1, 2.0, 0.1, "suffix:m") var speed_violation_dist_threshold: float = 0.5
@export_range(10, 100) var max_violations_kick: int = 50
@export_range(5, 50) var max_violations_rubberband: int = 10
@export_range(10.0, 100.0) var aim_suspicion_threshold: float = 20.0
@export_range(10.0, 180.0) var aim_snap_threshold_deg: float = 45.0
@export_range(1.0, 5.0, 0.1, "suffix:m") var shot_origin_tolerance: float = 3.0
@export var active_preset: NetworkPreset = NetworkPreset.BROADBAND

var frame_duration_ms: float = 16.67
var snapshot_buffer_size: int = 3


func _calculate_derived_values() -> void:
	## Recalculate values that depend on tick rate
	frame_duration_ms = 1000.0 / float(maxi(server_tick_rate, 1))
	snapshot_buffer_size = ceili(interpolation_delay * float(maxi(client_update_rate, 1)))


func refresh_derived_values() -> void:
	## Recalculate derived values after all explicit settings are applied.
	_calculate_derived_values()


func apply_preset(preset: NetworkPreset, recalculate_derived: bool = true) -> void:
	## Apply predefined network configuration preset.
	active_preset = preset
	match preset:
		NetworkPreset.LOW_BANDWIDTH:
			server_tick_rate = 20
			client_update_rate = 10
			input_send_rate = 20
			interpolation_delay = 0.2
			enable_lag_compensation = false
			position_precision_bits = 12
			GameManager.get_core_system("logger").info(
				"[Network] Applied LOW_BANDWIDTH preset (20Hz server)", "Core"
			)

		NetworkPreset.BROADBAND:
			server_tick_rate = 60
			client_update_rate = 30
			input_send_rate = 60
			interpolation_delay = 0.1
			enable_lag_compensation = true
			position_precision_bits = 14
			GameManager.get_core_system("logger").info(
				"[Network] Applied BROADBAND preset (60Hz server)", "Core"
			)

		NetworkPreset.COMPETITIVE:
			server_tick_rate = 128
			client_update_rate = 64
			input_send_rate = 128
			interpolation_delay = 0.05
			enable_lag_compensation = true
			position_precision_bits = 16
			GameManager.get_core_system("logger").info(
				"[Network] Applied COMPETITIVE preset (128Hz server)", "Core"
			)

	if recalculate_derived:
		_calculate_derived_values()


func get_config_summary() -> String:
	## Returns human-readable summary of current configuration
	var summary: String = "Network Configuration:"
	summary += "\n\tServer Tick: %d Hz" % server_tick_rate
	summary += "\n\tClient Update: %d Hz" % client_update_rate
	summary += "\n\tInput Rate: %d Hz" % input_send_rate
	summary += "\n\tInterpolation Delay: %.3f sec" % interpolation_delay
	summary += "\n\tPrediction: %s" % ("Enabled" if enable_client_prediction else "Disabled")
	summary += "\n\tLag Compensation: %s" % ("Enabled" if enable_lag_compensation else "Disabled")
	summary += "\n\tDelta Compression: %s" % ("Enabled" if enable_delta_compression else "Disabled")
	return summary
