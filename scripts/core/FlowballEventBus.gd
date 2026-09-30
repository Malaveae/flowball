extends Node

# =============================================================================
# FLOWBALL WORLD ARCHIVE — Event Bus
# =============================================================================
# Singleton autoload for decoupled communication between gameplay and
# presentation layers (scoreboard, UI, cameras, VFX).
# No gameplay logic lives here — only event relay.
# =============================================================================

signal set_piece_changed(piece_number: int, label: String, distance: float)
signal attempt_started(attempt_number: int, selected_foot: String)
signal power_phase_entered
signal power_updated(power_normalized: float)
signal plant_phase_entered
signal plant_updated(has_marker: bool, aim_target: float)
signal contact_phase_entered
signal shot_calculated(shot_params)
signal shot_executed(launch_data)
signal shot_result(outcome: String, summary: String, data: Dictionary)
signal feedback_displayed(report)
signal phase_changed(from_phase: String, to_phase: String)
signal stats_updated(goals: int, attempts: int, misses: int, max_misses: int)
